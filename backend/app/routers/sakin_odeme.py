"""Sakin "Öde" akisi (P30) — havale kodu + kart odemesi.

IKI YOL:
  1. **BANKA HAVALESI** — sitenin anlasmali banka kasasinin IBAN'i + sakine
     ozel BENZERSIZ aciklama kodu. Yonetim ekstreyi yukleyince (P29) kod
     eslestirmeyi KESINLESTIRIR; ad benzerligi/tutar tahminine gerek kalmaz.
  2. **KART** — mevcut `PaymentProvider` soyutlamasi uzerinden. Sahte/manuel
     saglayiciyla BUGUN calisir; gercek anahtarlar (P13) gelince ayni kod
     canliya gecer. AYRI BIR KART ENTEGRASYONU YAZILMADI: iki odeme yolu iki
     tahsilat kaydi bicimi uretirdi.

Basarili her odeme P29 defterine `tahsilat` olarak yazilir — kasa/gelir
yansimasi oradan gelir, burada TEKRARLANMAZ.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..config import settings
from .. import defter
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from .. import odeme_kodu as kod_modulu
from ..models import (
    AppUser,
    DuesAssessment,
    FinansalHareket,
    Kasa,
    UnitResident,
)
from ..payments import get_payment_provider
from ..schemas import KartOdemeBaslat, KartOdemeSonuc, OdemeBilgileri

router = APIRouter(tags=["aidat"])

_RESIDENT = require_role("resident")


async def _kod_ver(db: AsyncSession, user: AppUser) -> str:
    """Kullanicinin kodunu dondur; yoksa URET ve SAKLA.

    Tembel uretim bilincli: her kullaniciya pesin kod uretmek, hicbir zaman
    havale yapmayacak yuz binlerce kaydi doldururdu. Cakisma olasiligi dusuk
    ama SIFIR DEGIL — benzersizlik kisitina guvenip yeniden denenir.
    """
    if user.odeme_kodu:
        return user.odeme_kodu
    for _ in range(5):
        aday = kod_modulu.uret()
        user.odeme_kodu = aday
        try:
            async with db.begin_nested():
                await db.flush()
            return aday
        except IntegrityError:
            user.odeme_kodu = None
            continue
    # Bes denemede cakisma pratikte imkansiz; yine de sessizce bos donmek
    # yerine acikca hata verilir.
    raise APIError(500, "internal", "odeme_kodu_uretilemedi")


async def _borc_kurus(db: AsyncSession, user: AppUser) -> int:
    """Sakinin acik borcu: hedeflenmis tahakkuklar + dairelerinin tahakkuklari
    eksi tahsilatlar.

    HEDEFLENMEMIS (daireye yazilmis) borclar da sayilir: P28 oncesi acilmis
    ve tursuz tahakkuklar daireye yazilidir ve sakin onlari da odemek
    zorundadir.
    """
    daireler = (
        (await db.execute(
            select(UnitResident.unit_id).where(
                UnitResident.user_id == user.id, UnitResident.bitis.is_(None)
            )
        )).scalars().all()
    )
    kosul = DuesAssessment.hedef_user_id == user.id
    if daireler:
        kosul = kosul | (
            (DuesAssessment.unit_id.in_(daireler))
            & (DuesAssessment.hedef_user_id.is_(None))
        )
    borc = (
        await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0))
            # (P192 §6.3) Ters kayit cifti borc DEGILDIR.
            .where(kosul, *defter.gecerli_tahakkuk())
        )
    ).scalar_one()
    # (P192 §1) TEK TANIM: iade/iptal dusulur, yalniz gerceklesmis
    # satirlar sayilir. Burada ayri bir toplam yazmak, sakine panelden
    # farkli bir borc gostermek olurdu.
    odenen = await defter.tahsilat_toplami(db, user_id=user.id)
    return max(int(borc) - odenen, 0)


async def _banka_kasasi(db: AsyncSession) -> Kasa | None:
    """Sitenin anlasmali BANKA kasasi (IBAN'li, aktif).

    Ayri bir "anlasmali IBAN" tenant alani ACILMADI: IBAN zaten P27'nin
    kasa tanimindadir ve iki yerde tutulan IBAN, biri guncellenip digeri
    unutuldugunda parayi YANLIS HESABA yollardi.
    """
    return (
        await db.execute(
            select(Kasa)
            .where(Kasa.banka_mi.is_(True), Kasa.aktif.is_(True),
                   Kasa.iban.is_not(None))
            .order_by(Kasa.kod, Kasa.id)
            .limit(1)
        )
    ).scalar_one_or_none()


@router.get("/me/odeme-bilgileri", response_model=OdemeBilgileri)
async def odeme_bilgileri(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RESIDENT),
) -> OdemeBilgileri:
    """"Öde" ekraninin ihtiyaci olan HER SEY tek yanitta."""
    kasa = await _banka_kasasi(db)
    return OdemeBilgileri(
        iban=kasa.iban if kasa else None,
        banka_adi=kasa.banka_adi if kasa else None,
        odeme_kodu=await _kod_ver(db, user),
        borc_kurus=await _borc_kurus(db, user),
        # Manuel saglayici "kart" degildir: kart secenegini acmak, sakini
        # calismayan bir akisa sokardi.
        kart_aktif=settings.payment_provider != "manual",
    )


@router.post("/me/odeme/kart", response_model=KartOdemeSonuc, status_code=201)
async def kart_odemesi(
    body: KartOdemeBaslat,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RESIDENT),
) -> KartOdemeSonuc:
    """Kart odemesi baslat — MEVCUT saglayici soyutlamasi uzerinden.

    Sahte/manuel saglayici ANINDA basarili doner ve tahsilat P29 defterine
    yazilir; gercek saglayici bir `odeme_url` dondurur ve tahsilat webhook
    ile yazilir (mevcut `/payments/webhook/{saglayici}` yolu).
    """
    daire = (
        await db.execute(
            select(UnitResident.unit_id).where(
                UnitResident.user_id == user.id, UnitResident.bitis.is_(None)
            ).limit(1)
        )
    ).scalar_one_or_none()

    saglayici = get_payment_provider()
    sonuc = saglayici.init_payment(
        tutar_kurus=body.tutar_kurus,
        unit_id=daire,
        idempotency_key=str(uuid.uuid4()),
    )
    hareket_id = None
    if sonuc.durum == "basarili":
        kasa = await _banka_kasasi(db)
        hareket = FinansalHareket(
            tenant_id=user.tenant_id, tip="tahsilat", yon="giris",
            tutar_kurus=body.tutar_kurus,
            # (P192 §2.1) Kasasiz birakilmaz: IBAN'li banka kasasi yoksa
            # varsayilan banka hesabi acilir — aksi halde para defterde
            # gorunur, hicbir kasa bakiyesinde gorunmezdi.
            kasa_id=kasa.id if kasa else await defter.kasa_coz(
                db, user.tenant_id, banka=True
            ),
            user_id=user.id, unit_id=daire, kaydeden_user_id=user.id,
            yontem="kart", provider=saglayici.name,
            provider_ref=sonuc.provider_ref,
            aciklama=f"Kart odemesi ({saglayici.name})",
        )
        db.add(hareket)
        await db.flush()
        await db.refresh(hareket)
        hareket_id = hareket.id
        await audit_user(
            db, user, Action.FINANS_HAREKET_CREATE,
            resource_type="finansal_hareket", resource_id=hareket.id,
            meta={"tip": "tahsilat", "kanal": "kart",
                  "saglayici": saglayici.name},
        )
    return KartOdemeSonuc(
        durum=sonuc.durum,
        odeme_url=getattr(sonuc, "odeme_url", None),
        hareket_id=hareket_id,
    )
