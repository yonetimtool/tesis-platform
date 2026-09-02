"""(P203 §5) FAZLA MESAI — ozet, gidere yazma, aylik personel raporu.

===========================================================================
P192 TEK DEFTER KURALI KORUNDU
===========================================================================
Mesai gideri AYRI BIR TABLOYA YAZILMAZ. `finansal_hareket`e
`tip='gider'` olarak duser — cunku o bir GIDERDIR. Ikinci bir tablo,
"bu ay ne kadar gider yaptik" sorusunu iki yerden toplamak demekti ve
P192 tam olarak bunu ortadan kaldirmisti.

===========================================================================
OTOMATIK YAZMA YOK — ONAYA DUSER
===========================================================================
Istegin acik sarti ve P192 karariyla ayni: hareket
`gerceklesme_durumu='onay_bekliyor'` ile yazilir ve BAKIYEYI DUSURMEZ.
Bir hesaplamanin kasayi kendiliginden azaltmasi, yoneticinin gormedigi
bir sayinin parayi hareket ettirmesi olurdu.

===========================================================================
PLANLANAN vs GERCEKLESEN — DURUSTCE
===========================================================================
Sistemde GERCEK BIR MESAI KAYDI (turnike/QR giris-cikis) YOKTUR. Bu
yuzden hesap PLANLANAN saatler uzerinden yapilir ve yanit bunu ACIKCA
soyler (`kaynak: "plan"`). Yonetici, gidere yazarken saati DUZELTEBILIR
(`gerceklesen_saat`).

Uydurma bir "gerceklesen" uretmek — ornegin devriye okutmalarindan
cikarim yapmak — gelmis bir gorevliyi eksik, gelmemis birini tam
gostermeye acikti ve o sayi PARAYA donusecekti.
"""
from __future__ import annotations

import datetime as dt
import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..mesai import KisiOzeti, ay_araligi, saatlik_ucret
from ..models import (
    AppUser,
    FinansalHareket,
    PersonelKayit,
    Shift,
    Tenant,
    VardiyaPlani,
)
from ..schemas import (
    MesaiGidereYazIstek,
    MesaiKisiOut,
    MesaiOzetOut,
)
from ..vardiya import plan_araligi, saat_farki

router = APIRouter(prefix="/mesai", tags=["mesai"])

_OKUR = require_role("admin", "yonetici", "denetci")
_YAZAR = require_role("admin", "yonetici")

#: Gidere yazilan mesai hareketinin aciklamasinda kullanilan onek.
#: AYNI AY IKI KEZ yazilmasin diye aranan isaret de budur.
ACIKLAMA_ONEKI = "Fazla mesai"


async def _ozet_hesapla(
    db: AsyncSession, tenant: Tenant, yil: int, ay: int
) -> list[KisiOzeti]:
    bas, son = ay_araligi(yil, ay)
    satirlar = (
        await db.execute(
            # (P205 §2) OUTER JOIN: sablonsuz vardiyalar da MESAI
            # URETIR. `join` birakilsaydi serbest yazilan gece
            # vardiyalari ucret hesabindan sessizce DUSERDI.
            select(VardiyaPlani, Shift, AppUser.id, AppUser.ad)
            .outerjoin(Shift, Shift.id == VardiyaPlani.shift_id)
            .join(AppUser, AppUser.id == VardiyaPlani.user_id)
            .where(
                VardiyaPlani.tarih >= bas,
                VardiyaPlani.tarih <= son,
                VardiyaPlani.durum == "planli",
            )
        )
    ).all()

    kisiler: dict[uuid.UUID, KisiOzeti] = {}
    for plan, shift, uid, ad in satirlar:
        k = kisiler.setdefault(uid, KisiOzeti(user_id=str(uid), ad=ad))
        k.ekle(plan.tarih, saat_farki(*plan_araligi(plan, shift)))

    # UCRET personel kaydindan gelir; `app_user_id` bagi yoksa ucret
    # bilinmez ve kisi "tanimsiz" isaretlenir (sifir SAYILMAZ).
    if kisiler:
        kayitlar = (
            await db.execute(
                select(PersonelKayit).where(
                    PersonelKayit.app_user_id.in_(list(kisiler))
                )
            )
        ).scalars().all()
        for p in kayitlar:
            k = kisiler.get(p.app_user_id)
            if k is not None:
                k.saatlik_ucret_kurus = saatlik_ucret(
                    p.saatlik_ucret_kurus, p.maas_kurus
                )
    return sorted(kisiler.values(), key=lambda k: k.ad)


@router.get("/ozet", response_model=MesaiOzetOut)
async def ozet(
    yil: int = Query(..., ge=2000, le=2100),
    ay: int = Query(..., ge=1, le=12),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> MesaiOzetOut:
    """(§5) AYLIK PERSONEL GIDERI OZETI.

    Fazla mesai HAFTA HAFTA hesaplanir (4857 md. 41 haftalik esige
    bakar); ay toplamiyla hesaplamak, bir hafta 60 otekinde 30 saat
    calisan biri icin "fazla mesai yok" derdi.
    """
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    katsayi = float(tenant.mesai_katsayisi or 1.5)
    ozetler = await _ozet_hesapla(db, tenant, yil, ay)

    bas, son = ay_araligi(yil, ay)
    # ZATEN YAZILMIS mesai giderleri: ayni ay iki kez yazilmasin.
    yazilanlar = {
        r[0]
        for r in (
            await db.execute(
                select(FinansalHareket.user_id).where(
                    FinansalHareket.tip == "gider",
                    FinansalHareket.tarih >= bas,
                    FinansalHareket.tarih <= son,
                    FinansalHareket.aciklama.like(f"{ACIKLAMA_ONEKI}%"),
                    FinansalHareket.ters_kayit_id.is_(None),
                )
            )
        ).all()
    }

    return MesaiOzetOut(
        yil=yil,
        ay=ay,
        katsayi=katsayi,
        kaynak="plan",
        kisiler=[
            MesaiKisiOut(
                user_id=k.user_id,
                ad=k.ad,
                toplam_saat=round(k.toplam_saat, 2),
                fazla_saat=round(k.fazla_saat, 2),
                saatlik_ucret_kurus=k.saatlik_ucret_kurus,
                fazla_mesai_kurus=k.fazla_mesai_kurus(katsayi),
                ucret_tanimsiz=k.saatlik_ucret_kurus is None,
                gidere_yazildi=uuid.UUID(k.user_id) in yazilanlar,
            )
            for k in ozetler
        ],
    )


@router.post("/gidere-yaz", response_model=list[uuid.UUID], status_code=201)
async def gidere_yaz(
    body: MesaiGidereYazIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> list[uuid.UUID]:
    """Fazla mesaiyi ONAY BEKLEYEN GIDER olarak deftere yaz.

    TEK DEFTER (P192): `finansal_hareket`, `tip='gider'`.
    OTOMATIK DEGIL: `gerceklesme_durumu='onay_bekliyor'` — bakiyeyi
    DUSURMEZ, yonetici onaylayana kadar.
    """
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    katsayi = float(tenant.mesai_katsayisi or 1.5)
    bas, son = ay_araligi(body.yil, body.ay)
    ozetler = {k.user_id: k for k in await _ozet_hesapla(db, tenant, body.yil, body.ay)}

    olusan: list[uuid.UUID] = []
    for satir in body.satirlar:
        k = ozetler.get(str(satir.user_id))
        if k is None:
            raise APIError(422, "validation_error", "personel_bulunamadi")
        # SAAT DUZELTILEBILIR: sistemde gercek mesai kaydi yok, hesap
        # PLAN uzerinden. Yonetici gercegi biliyorsa onu yazabilmeli.
        saat = satir.gerceklesen_fazla_saat
        if saat is None:
            saat = k.fazla_saat
        if saat <= 0:
            continue
        ucret = k.saatlik_ucret_kurus
        if ucret is None:
            # UCRETI TANIMSIZ KISIYI SESSIZCE ATLAMAK, yoneticiye
            # "yazildi" deyip yazmamak olurdu.
            raise APIError(422, "validation_error", "personel_ucreti_tanimsiz")
        tutar = round(saat * ucret * katsayi)
        hareket = FinansalHareket(
            tenant_id=user.tenant_id,
            kaydeden_user_id=user.id,
            tip="gider",
            yon="cikis",
            tutar_kurus=tutar,
            user_id=satir.user_id,
            tarih=son,
            aciklama=(
                f"{ACIKLAMA_ONEKI} {body.yil}-{body.ay:02d} · "
                f"{k.ad} · {saat:g} saat x {katsayi:g}"
            ),
            durum="onay_bekliyor",
        )
        db.add(hareket)
        await db.flush()
        olusan.append(hareket.id)
        await audit_user(
            db, user, Action.MESAI_GIDERE_YAZ, resource_type="finansal_hareket",
            resource_id=hareket.id,
            meta={
                "user_id": str(satir.user_id),
                "saat": saat,
                "katsayi": katsayi,
                "tutar_kurus": tutar,
                "donem": f"{body.yil}-{body.ay:02d}",
            },
        )
    return olusan
