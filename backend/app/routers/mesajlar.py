"""Mesaj sablonlari + gonderim (P32) — `/mesaj-sablonlari`, `/mesajlar/...`.

RIZA DENETIMI: `amac='pazarlama'` sablonlar YALNIZCA rizasi olan kisilere
gonderilir. Riza kaydi P36'nin isidir; o gelene kadar bu uc PAZARLAMA
gonderimini HIC yapmaz ve atlananlari SAYAR. "Simdilik gonderelim, rizayi
sonra ekleriz" demek, KVKK ihlalini urune yerlestirmek olurdu.

OPERASYONEL finansal bildirim AYRI bir hukuki dayanaktir (KMK yukumluluk)
ve riza gerektirmez — bu ayrim sablonun `amac` alaninda tasinir.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..config import settings
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..mesajlasma import (
    LogEpostaSaglayici,
    LogSmsSaglayici,
    SmtpEpostaSaglayici,
    bilinmeyen_etiketler,
    etiketleri_coz,
    kullanilan_etiketler,
    sms_olc,
)
from ..models import (
    AppUser,
    DuesAssessment,
    FinansalHareket,
    MesajGonderim,
    MesajSablonu,
    Tenant,
    Unit,
    UnitResident,
)
from ..schemas import (
    MesajGonderIstek,
    MesajGonderSonuc,
    MesajGonderimListResponse,
    MesajGonderimOut,
    MesajOnizlemeIstek,
    MesajOnizlemeOut,
    MesajSablonuCreate,
    MesajSablonuListResponse,
    MesajSablonuOut,
    MesajSablonuUpdate,
    SmsOlcumOut,
)

router = APIRouter(tags=["mesajlar"])

_YONETIM = require_role("admin", "yonetici")

#: Toplu gonderimde tek istekte en fazla alici. Sinirsiz birakmak, tek
#: istegin dakikalarca surmesine ve zaman asimiyla YARIM gonderilmis bir
#: kampanyaya yol acardi.
_TOPLU_UST_SINIR = 500


def _saglayici(kanal: str):
    if kanal == "sms":
        # Gercek SMS hesabi [DIŞ]; mimari saglayiciyi YAPILANDIRMA ile
        # degistirebilmeli, bu yuzden gonderim yolu bugun de sonuna kadar
        # calisir ve yalnizca bu sinif degisir.
        return LogSmsSaglayici()
    sunucu = getattr(settings, "smtp_host", None)
    if sunucu:
        return SmtpEpostaSaglayici(
            sunucu,
            int(getattr(settings, "smtp_port", 587) or 587),
            getattr(settings, "smtp_user", None),
            getattr(settings, "smtp_password", None),
            getattr(settings, "smtp_from", None) or "no-reply@localhost",
        )
    return LogEpostaSaglayici()


def _cikti(obj: MesajSablonu) -> MesajSablonuOut:
    return MesajSablonuOut.model_validate(obj).model_copy(update={
        "etiketler": kullanilan_etiketler(f"{obj.konu or ''} {obj.govde}"),
        "bilinmeyen_etiketler": bilinmeyen_etiketler(
            f"{obj.konu or ''} {obj.govde}"
        ),
    })


# ============================== SABLON CRUD ================================= #
@router.get("/mesaj-sablonlari", response_model=MesajSablonuListResponse)
async def sablon_listesi(
    kanal: str | None = Query(None),
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> MesajSablonuListResponse:
    q = select(MesajSablonu)
    if kanal is not None:
        q = q.where(MesajSablonu.kanal == kanal)
    if aktif is not None:
        q = q.where(MesajSablonu.aktif == aktif)
    total = (
        await db.execute(select(func.count()).select_from(q.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            q.order_by(MesajSablonu.kanal, MesajSablonu.ad, MesajSablonu.id)
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    return MesajSablonuListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_cikti(k) for k in kayitlar],
    )


@router.post("/mesaj-sablonlari", response_model=MesajSablonuOut, status_code=201)
async def sablon_olustur(
    body: MesajSablonuCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajSablonuOut:
    obj = MesajSablonu(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MESAJ_SABLON_UPSERT, resource_type="mesaj_sablonu",
        resource_id=obj.id, meta={"kanal": obj.kanal, "ad": obj.ad},
    )
    return _cikti(obj)


@router.patch("/mesaj-sablonlari/{sablon_id}", response_model=MesajSablonuOut)
async def sablon_guncelle(
    sablon_id: uuid.UUID,
    body: MesajSablonuUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajSablonuOut:
    obj = await get_or_404(db, MesajSablonu, sablon_id)
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()
    # BIRLESIK kural: kanal degismez ama konu SMS'e eklenmeye calisilabilir.
    if obj.kanal == "sms" and obj.konu:
        raise APIError(422, "validation_error", "sms_sablonunda_konu_olmaz")
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MESAJ_SABLON_UPSERT, resource_type="mesaj_sablonu",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return _cikti(obj)


@router.delete("/mesaj-sablonlari/{sablon_id}", status_code=204, response_model=None)
async def sablon_sil(
    sablon_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    """Sablonu siler; GECMIS DURUR (gonderim kaydi metni kopyaladi)."""
    obj = await get_or_404(db, MesajSablonu, sablon_id)
    await audit_user(
        db, user, Action.MESAJ_SABLON_SIL, resource_type="mesaj_sablonu",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    await db.delete(obj)
    await db.flush()


# =============================== ONIZLEME =================================== #
async def _degerler(
    db: AsyncSession, tenant: Tenant, user_id: uuid.UUID | None
) -> dict[str, str]:
    """Etiket degerleri. Kisi verilmezse ORNEK degerler doner (onizleme)."""
    from datetime import datetime, timezone

    bugun = datetime.now(timezone.utc).date().strftime("%d.%m.%Y")
    if user_id is None:
        return {
            "adi_soyadi": "Ad Soyad", "adres": "A-12", "site_adi": tenant.ad,
            "tarih": bugun, "bakiye": "1.250,50", "borc": "500,00",
            "aidat_tutari": "750,00", "kiraci_bakiyesi": "0,00",
            "bakiye_detayli": "Aidat: 750,00 · Elektrik: 500,50",
            "borcu_detayli": "Temmuz 2026 aidat: 750,00",
            "odeme_linki": "https://ornek/ode",
        }

    kisi = (
        await db.execute(select(AppUser).where(AppUser.id == user_id))
    ).scalar_one_or_none()
    daire = (
        await db.execute(
            select(Unit.no).join(
                UnitResident,
                (UnitResident.unit_id == Unit.id)
                & (UnitResident.user_id == user_id)
                & (UnitResident.bitis.is_(None)),
            ).limit(1)
        )
    ).scalar_one_or_none()
    borc = int((
        await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0))
            .where(DuesAssessment.hedef_user_id == user_id)
        )
    ).scalar_one())
    odenen = int((
        await db.execute(
            select(func.coalesce(func.sum(FinansalHareket.tutar_kurus), 0))
            .where(FinansalHareket.tip == "tahsilat",
                   FinansalHareket.user_id == user_id)
        )
    ).scalar_one())
    from ..raporlar import kurus_metin

    bakiye = max(borc - odenen, 0)
    return {
        "adi_soyadi": kisi.ad if kisi else "",
        "adres": daire or "",
        "site_adi": tenant.ad,
        "tarih": bugun,
        "bakiye": kurus_metin(bakiye),
        "borc": kurus_metin(borc),
        "aidat_tutari": kurus_metin(borc),
        "kiraci_bakiyesi": kurus_metin(bakiye),
        "bakiye_detayli": f"Toplam borç: {kurus_metin(borc)} · "
                          f"Tahsil edilen: {kurus_metin(odenen)}",
        "borcu_detayli": f"Kalan bakiye: {kurus_metin(bakiye)}",
        # Odeme linki sakinin uygulamadaki "Öde" ekranina isaret eder;
        # tenant basina ayri bir alan ACILMADI (bkz. P30 IBAN kararı).
        # (P120) BIZE AIT OLMAYAN bir alan adi kullaniliyordu — bkz.
        # `Settings.portal_base_url` gerekcesi.
        "odeme_linki": f"{settings.portal_base_url}/ode",
    }


@router.post("/mesajlar/onizleme", response_model=MesajOnizlemeOut)
async def onizleme(
    body: MesajOnizlemeIstek,
    kanal: str = Query("sms", description="sms | eposta"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajOnizlemeOut:
    """Etiketleri COZULMUS onizleme + SMS sayaci.

    Sayac ONIZLEMEDE verilir, kaydetmede degil: kullanici yazarken parca
    sayisinin arttigini GORMELI — kaydettikten sonra ogrenmek gec.
    """
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    degerler = await _degerler(db, tenant, body.user_id)
    govde = etiketleri_coz(body.govde, degerler)
    konu = etiketleri_coz(body.konu, degerler) if body.konu else None
    ham = f"{body.konu or ''} {body.govde}"
    olcum = None
    if kanal == "sms":
        o = sms_olc(govde)
        olcum = SmsOlcumOut(
            karakter=o.karakter, unicode_mi=o.unicode_mi, parca=o.parca,
            kalan=o.kalan, zorlayan=o.zorlayan,
        )
    return MesajOnizlemeOut(
        konu=konu, govde=govde,
        etiketler=kullanilan_etiketler(ham),
        bilinmeyen_etiketler=bilinmeyen_etiketler(ham),
        sms=olcum,
    )


# =============================== GONDERIM =================================== #
async def _alicilar(
    db: AsyncSession, body: MesajGonderIstek
) -> list[uuid.UUID]:
    if body.user_ids:
        return list(dict.fromkeys(body.user_ids))[:_TOPLU_UST_SINIR]

    q = (
        select(UnitResident.user_id)
        .join(Unit, Unit.id == UnitResident.unit_id)
        .where(UnitResident.bitis.is_(None))
    )
    if body.blok:
        q = q.where(Unit.blok == body.blok)
    idler = list(dict.fromkeys((await db.execute(q)).scalars().all()))

    if body.borc_durumu == "borclu":
        borclu = set(
            (await db.execute(
                select(DuesAssessment.hedef_user_id)
                .where(DuesAssessment.hedef_user_id.is_not(None))
                .group_by(DuesAssessment.hedef_user_id)
                .having(func.sum(DuesAssessment.tutar_kurus) > 0)
            )).scalars().all()
        )
        idler = [i for i in idler if i in borclu]
    return idler[:_TOPLU_UST_SINIR]


@router.post("/mesajlar/gonder", response_model=MesajGonderSonuc, status_code=201)
async def gonder(
    body: MesajGonderIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MesajGonderSonuc:
    """Bireysel + toplu gonderim TEK UCTAN.

    Iki ayri uc, ayni riza/gecmis mantigini iki kez yazmak olurdu.

    SESSIZ DUSURME YOK: rizasi olmayan ve adresi olmayan aliciler AYRI
    SAYILIR ve yanitta doner — "gonderdim" deyip 40 kisiyi atlamak,
    yonetimin haberi olmadan bildirimsiz kalmasi demekti.
    """
    sablon = await get_or_404(db, MesajSablonu, body.sablon_id)
    if not sablon.aktif:
        raise APIError(422, "validation_error", "sablon_pasif")

    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    idler = await _alicilar(db, body)
    kisiler = {
        k.id: k for k in (
            await db.execute(select(AppUser).where(AppUser.id.in_(idler)))
        ).scalars().all()
    } if idler else {}

    saglayici = _saglayici(sablon.kanal)
    gonderildi = basarisiz = riza_yok = adres_yok = 0

    for kid in idler:
        kisi = kisiler.get(kid)
        if kisi is None:
            continue
        # PAZARLAMA -> RIZA ZORUNLU (P36 ile GERCEK riza kaydi baglandi).
        # Riza KANAL BAZLIDIR: e-postaya izin veren kisi SMS'e izin vermis
        # sayilmaz — tek bir "pazarlama" bayragi bunu kaybederdi.
        if sablon.amac == "pazarlama":
            izinli = (
                kisi.pazarlama_sms if sablon.kanal == "sms"
                else kisi.pazarlama_eposta
            )
            if not izinli:
                riza_yok += 1
                continue
        hedef = (
            kisi.telefon if sablon.kanal == "sms" else kisi.email
        )
        if not hedef:
            adres_yok += 1
            continue

        degerler = await _degerler(db, tenant, kid)
        govde = etiketleri_coz(sablon.govde, degerler)
        konu = etiketleri_coz(sablon.konu, degerler) if sablon.konu else None
        sonuc = saglayici.gonder(hedef, konu, govde)
        db.add(MesajGonderim(
            tenant_id=user.tenant_id, sablon_id=sablon.id, kanal=sablon.kanal,
            amac=sablon.amac, user_id=kid, hedef=hedef, konu=konu,
            govde=govde, durum=sonuc.durum, hata=sonuc.hata,
            saglayici=sonuc.saglayici, gonderen_user_id=user.id,
        ))
        if sonuc.durum == "basarisiz":
            basarisiz += 1
        else:
            gonderildi += 1

    await db.flush()
    await audit_user(
        db, user, Action.MESAJ_GONDER, resource_type="mesaj_gonderim",
        resource_id=sablon.id,
        meta={"kanal": sablon.kanal, "amac": sablon.amac,
              "gonderildi": gonderildi, "riza_yok": riza_yok,
              "adres_yok": adres_yok, "basarisiz": basarisiz},
    )
    return MesajGonderSonuc(
        gonderildi=gonderildi, basarisiz=basarisiz,
        riza_yok=riza_yok, adres_yok=adres_yok,
    )


@router.get("/mesajlar/gecmis", response_model=MesajGonderimListResponse)
async def gecmis(
    kanal: str | None = Query(None),
    user_id: uuid.UUID | None = Query(None),
    durum: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> MesajGonderimListResponse:
    q = select(MesajGonderim)
    if kanal is not None:
        q = q.where(MesajGonderim.kanal == kanal)
    if user_id is not None:
        q = q.where(MesajGonderim.user_id == user_id)
    if durum is not None:
        q = q.where(MesajGonderim.durum == durum)
    total = (
        await db.execute(select(func.count()).select_from(q.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            q.order_by(MesajGonderim.created_at.desc(), MesajGonderim.id.desc()).limit(limit).offset(offset)
        )).scalars().all()
    )
    idler = {k.user_id for k in kayitlar if k.user_id}
    adlar = dict(
        (await db.execute(
            select(AppUser.id, AppUser.ad).where(AppUser.id.in_(idler))
        )).all()
    ) if idler else {}
    return MesajGonderimListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            MesajGonderimOut.model_validate(k).model_copy(
                update={"user_ad": adlar.get(k.user_id)}
            )
            for k in kayitlar
        ],
    )
