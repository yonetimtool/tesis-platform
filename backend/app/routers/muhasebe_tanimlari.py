"""Muhasebe "TANIMLAR" katmani (P27) — yedi kayit defteri + tenant ayarlari.

  * `/kasalar`              — kasa/banka hesaplari
  * `/gelir-gider-gruplari` — gelir/gider ust kirilimi
  * `/gelir-gider-tanimlari`— gelir/gider kalemleri (P28'in borclandirma TURU)
  * `/firmalar`             — tedarikci/hizmet firmalari
  * `/personel-kayitlari`   — personel (app_user'DAN AYRI, opsiyonel bagli)
  * `/arac-kayitlari`       — KAYITLI araclar (P17 rozetlerinin kaynagi)
  * `/sayaclar/ana` + `/sayaclar/bolum` — ana ve daire sayaclari
  * `/muhasebe-ayarlari`    — evrak seri/sira + para birimi (GOSTERIM)

RBAC: hepsi **admin + yonetici**. Bunlar site YONETIM tanimlaridir; saha ve
sakin ERISEMEZ. (P26'nin daire tip/grup tanimlari saha rollerine OKUMA aciyor
cunku daire listelerinde gorunuyorlar — muhasebe tanimlarinin boyle bir
gorunumu yok.)

SILME KURALI — P26 ile AYNI: bagli kayit varsa 409 VERILMEZ; baglar
`ON DELETE SET NULL` ile bosalir ve yanit KAC kaydin etkilendigini doner.
Istisna `sayac_bolum`: dairesi silinince o da silinir (CASCADE), cunku
dairesiz bir daire sayaci anlamsizdir.
"""
from __future__ import annotations

import uuid
from typing import Any

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, norm_plaka, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    AracKayit,
    Firma,
    GelirGiderGrup,
    GelirGiderTanim,
    Kasa,
    PersonelKayit,
    SayacAna,
    SayacBolum,
    Tenant,
    Unit,
)
from ..schemas import (
    AracKayitCreate,
    AracKayitListResponse,
    AracKayitOut,
    AracKayitUpdate,
    FirmaCreate,
    FirmaListResponse,
    FirmaOut,
    FirmaUpdate,
    GelirGiderGrupCreate,
    GelirGiderGrupListResponse,
    GelirGiderGrupOut,
    GelirGiderGrupUpdate,
    GelirGiderTanimCreate,
    GelirGiderTanimListResponse,
    GelirGiderTanimOut,
    GelirGiderTanimUpdate,
    KasaCreate,
    KasaListResponse,
    KasaOut,
    KasaUpdate,
    MuhasebeAyarOut,
    MuhasebeAyarUpdate,
    PersonelKayitCreate,
    PersonelKayitListResponse,
    PersonelKayitOut,
    PersonelKayitUpdate,
    SayacAnaCreate,
    SayacAnaListResponse,
    SayacAnaOut,
    SayacAnaUpdate,
    SayacBolumCreate,
    SayacBolumListResponse,
    SayacBolumOut,
    SayacBolumOtomatikOlustur,
    SayacBolumUpdate,
    SayacOtomatikSonuc,
)

router = APIRouter(tags=["muhasebe-tanimlari"])

_YONETIM = require_role("admin", "yonetici")


# --------------------------- ortak yardimcilar ------------------------------ #
async def _sayfa(
    db: AsyncSession, model, *, aktif: bool | None, limit: int, offset: int, sirala
):
    """Tanim listelerinin ORTAK sayfalama govdesi (yedi kez tekrarlanmasin)."""
    base = select(model)
    if aktif is not None:
        base = base.where(model.aktif == aktif)
    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(base.order_by(sirala, model.id).limit(limit).offset(offset)))
        .scalars()
        .all()
    )
    return list(kayitlar), total


async def _uygula(obj, veri: dict[str, Any]) -> None:
    for alan, deger in veri.items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()


async def _kaydet(db: AsyncSession, obj):
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


async def _referans_dogrula(db: AsyncSession, model, kimlik, metin: str) -> None:
    """Verilen kayit BU TENANT'ta var mi (yoksa 422 `invalid_reference`).

    Bilesik FK zaten baska tenant'a baglanmayi engelliyor, ama o ihlal
    kullaniciya "veri butunlugu" gibi okunur; burada ONCEDEN olculur.
    """
    if kimlik is None:
        return
    var = (
        await db.execute(select(model.id).where(model.id == kimlik))
    ).scalar_one_or_none()
    if var is None:
        raise APIError(422, "invalid_reference", metin)


# ================================= KASA ===================================== #
@router.get("/kasalar", response_model=KasaListResponse)
async def list_kasalar(
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> KasaListResponse:
    kayitlar, total = await _sayfa(
        db, Kasa, aktif=aktif, limit=limit, offset=offset, sirala=Kasa.kod
    )
    return KasaListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[KasaOut.model_validate(k) for k in kayitlar],
    )


@router.post("/kasalar", response_model=KasaOut, status_code=201)
async def create_kasa(
    body: KasaCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> KasaOut:
    obj = Kasa(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="kasa",
        resource_id=obj.id, meta={"kod": obj.kod},
    )
    return KasaOut.model_validate(obj)


@router.patch("/kasalar/{kasa_id}", response_model=KasaOut)
async def update_kasa(
    kasa_id: uuid.UUID,
    body: KasaUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> KasaOut:
    obj = await get_or_404(db, Kasa, kasa_id)
    veri = body.model_dump(exclude_unset=True)
    await _uygula(obj, veri)
    # BIRLESIK durum kontrolu: `banka_mi` kapatilirken IBAN gonderilmemis
    # olabilir — o zaman DB CHECK'i 500 gibi okunan bir ihlal verirdi.
    if not obj.banka_mi and (obj.iban or obj.banka_adi or obj.sube):
        raise APIError(422, "validation_error", "kasa_banka_alanlari")
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="kasa",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return KasaOut.model_validate(obj)


@router.delete("/kasalar/{kasa_id}", status_code=204, response_model=None)
async def delete_kasa(
    kasa_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    obj = await get_or_404(db, Kasa, kasa_id)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="kasa",
        resource_id=obj.id, meta={"kod": obj.kod},
    )
    await db.delete(obj)
    await db.flush()


# ========================= GELIR/GIDER GRUBU ================================ #
@router.get("/gelir-gider-gruplari", response_model=GelirGiderGrupListResponse)
async def list_gg_gruplari(
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> GelirGiderGrupListResponse:
    kayitlar, total = await _sayfa(
        db, GelirGiderGrup, aktif=aktif, limit=limit, offset=offset,
        sirala=GelirGiderGrup.ad,
    )
    return GelirGiderGrupListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[GelirGiderGrupOut.model_validate(k) for k in kayitlar],
    )


@router.post("/gelir-gider-gruplari", response_model=GelirGiderGrupOut, status_code=201)
async def create_gg_grup(
    body: GelirGiderGrupCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> GelirGiderGrupOut:
    obj = GelirGiderGrup(tenant_id=user.tenant_id, ad=body.ad.strip(), aktif=body.aktif)
    db.add(obj)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="gelir_gider_grup",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    return GelirGiderGrupOut.model_validate(obj)


@router.patch("/gelir-gider-gruplari/{grup_id}", response_model=GelirGiderGrupOut)
async def update_gg_grup(
    grup_id: uuid.UUID,
    body: GelirGiderGrupUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> GelirGiderGrupOut:
    obj = await get_or_404(db, GelirGiderGrup, grup_id)
    veri = body.model_dump(exclude_unset=True)
    if veri.get("ad"):
        veri["ad"] = veri["ad"].strip()
    await _uygula(obj, veri)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="gelir_gider_grup",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return GelirGiderGrupOut.model_validate(obj)


@router.delete("/gelir-gider-gruplari/{grup_id}", status_code=200)
async def delete_gg_grup(
    grup_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> dict[str, int]:
    """Grubu siler; bagli TANIMLAR durur, yalniz gruplari bosalir (SET NULL)."""
    obj = await get_or_404(db, GelirGiderGrup, grup_id)
    etkilenen = (
        await db.execute(
            select(func.count()).select_from(GelirGiderTanim)
            .where(GelirGiderTanim.grup_id == obj.id)
        )
    ).scalar_one()
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="gelir_gider_grup",
        resource_id=obj.id, meta={"ad": obj.ad, "etkilenen": etkilenen},
    )
    await db.delete(obj)
    await db.flush()
    return {"etkilenen_tanim": etkilenen}


# ========================= GELIR/GIDER TANIMI =============================== #
async def _gg_adlarla(
    db: AsyncSession, kayitlar: list[GelirGiderTanim]
) -> list[GelirGiderTanimOut]:
    idler = {k.grup_id for k in kayitlar if k.grup_id}
    adlar: dict[uuid.UUID, str] = {}
    if idler:
        adlar = dict(
            (
                await db.execute(
                    select(GelirGiderGrup.id, GelirGiderGrup.ad)
                    .where(GelirGiderGrup.id.in_(idler))
                )
            ).all()
        )
    return [
        GelirGiderTanimOut.model_validate(k).model_copy(
            update={"grup_ad": adlar.get(k.grup_id)}
        )
        for k in kayitlar
    ]


@router.get("/gelir-gider-tanimlari", response_model=GelirGiderTanimListResponse)
async def list_gg_tanimlari(
    aktif: bool | None = Query(None),
    tip: str | None = Query(None, description="gelir | gider | her_ikisi"),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> GelirGiderTanimListResponse:
    base = select(GelirGiderTanim)
    if aktif is not None:
        base = base.where(GelirGiderTanim.aktif == aktif)
    if tip is not None:
        base = base.where(GelirGiderTanim.tip == tip)
    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            base.order_by(GelirGiderTanim.ad, GelirGiderTanim.id).limit(limit).offset(offset)
        )).scalars().all()
    )
    return GelirGiderTanimListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _gg_adlarla(db, list(kayitlar)),
    )


@router.post(
    "/gelir-gider-tanimlari", response_model=GelirGiderTanimOut, status_code=201
)
async def create_gg_tanim(
    body: GelirGiderTanimCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> GelirGiderTanimOut:
    await _referans_dogrula(db, GelirGiderGrup, body.grup_id, "gelir_gider_grup_yok")
    obj = GelirGiderTanim(
        tenant_id=user.tenant_id, **body.model_dump() | {"ad": body.ad.strip()}
    )
    db.add(obj)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="gelir_gider_tanim",
        resource_id=obj.id, meta={"ad": obj.ad, "tip": obj.tip},
    )
    return (await _gg_adlarla(db, [obj]))[0]


@router.patch("/gelir-gider-tanimlari/{tanim_id}", response_model=GelirGiderTanimOut)
async def update_gg_tanim(
    tanim_id: uuid.UUID,
    body: GelirGiderTanimUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> GelirGiderTanimOut:
    obj = await get_or_404(db, GelirGiderTanim, tanim_id)
    veri = body.model_dump(exclude_unset=True)
    if veri.get("ad"):
        veri["ad"] = veri["ad"].strip()
    await _referans_dogrula(db, GelirGiderGrup, veri.get("grup_id"), "gelir_gider_grup_yok")
    await _uygula(obj, veri)
    # BIRLESIK kural: tip 'gelir'e cevrilirken eski dagitim sekli kalabilir.
    if obj.tip == "gelir" and obj.dagitim_sekli is not None:
        raise APIError(422, "validation_error", "gelir_kaleminde_dagitim_olmaz")
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="gelir_gider_tanim",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return (await _gg_adlarla(db, [obj]))[0]


@router.delete("/gelir-gider-tanimlari/{tanim_id}", status_code=204, response_model=None)
async def delete_gg_tanim(
    tanim_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    obj = await get_or_404(db, GelirGiderTanim, tanim_id)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="gelir_gider_tanim",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    await db.delete(obj)
    await db.flush()


# ================================ FIRMA ===================================== #
@router.get("/firmalar", response_model=FirmaListResponse)
async def list_firmalar(
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> FirmaListResponse:
    kayitlar, total = await _sayfa(
        db, Firma, aktif=aktif, limit=limit, offset=offset, sirala=Firma.ad
    )
    return FirmaListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[FirmaOut.model_validate(k) for k in kayitlar],
    )


@router.post("/firmalar", response_model=FirmaOut, status_code=201)
async def create_firma(
    body: FirmaCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> FirmaOut:
    veri = body.model_dump()
    veri["ad"] = veri["ad"].strip()
    if veri.get("email") is not None:
        veri["email"] = str(veri["email"])
    obj = Firma(tenant_id=user.tenant_id, **veri)
    db.add(obj)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="firma",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    return FirmaOut.model_validate(obj)


@router.patch("/firmalar/{firma_id}", response_model=FirmaOut)
async def update_firma(
    firma_id: uuid.UUID,
    body: FirmaUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> FirmaOut:
    obj = await get_or_404(db, Firma, firma_id)
    veri = body.model_dump(exclude_unset=True)
    if veri.get("ad"):
        veri["ad"] = veri["ad"].strip()
    if veri.get("email") is not None:
        veri["email"] = str(veri["email"])
    await _uygula(obj, veri)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="firma",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return FirmaOut.model_validate(obj)


@router.delete("/firmalar/{firma_id}", status_code=204, response_model=None)
async def delete_firma(
    firma_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    obj = await get_or_404(db, Firma, firma_id)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="firma",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    await db.delete(obj)
    await db.flush()


# ============================== PERSONEL ==================================== #
async def _personel_adlarla(
    db: AsyncSession, kayitlar: list[PersonelKayit]
) -> list[PersonelKayitOut]:
    idler = {k.app_user_id for k in kayitlar if k.app_user_id}
    adlar: dict[uuid.UUID, str] = {}
    if idler:
        adlar = dict(
            (
                await db.execute(
                    select(AppUser.id, AppUser.ad).where(AppUser.id.in_(idler))
                )
            ).all()
        )
    return [
        PersonelKayitOut.model_validate(k).model_copy(
            update={"app_user_ad": adlar.get(k.app_user_id)}
        )
        for k in kayitlar
    ]


@router.get("/personel-kayitlari", response_model=PersonelKayitListResponse)
async def list_personel(
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> PersonelKayitListResponse:
    kayitlar, total = await _sayfa(
        db, PersonelKayit, aktif=aktif, limit=limit, offset=offset,
        sirala=PersonelKayit.ad,
    )
    return PersonelKayitListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _personel_adlarla(db, kayitlar),
    )


@router.post("/personel-kayitlari", response_model=PersonelKayitOut, status_code=201)
async def create_personel(
    body: PersonelKayitCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> PersonelKayitOut:
    await _referans_dogrula(db, AppUser, body.app_user_id, "kullanici_bulunamadi_veya_pasif")
    veri = body.model_dump()
    veri["ad"] = veri["ad"].strip()
    if veri.get("email") is not None:
        veri["email"] = str(veri["email"])
    obj = PersonelKayit(tenant_id=user.tenant_id, **veri)
    db.add(obj)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="personel_kayit",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    return (await _personel_adlarla(db, [obj]))[0]


@router.patch("/personel-kayitlari/{personel_id}", response_model=PersonelKayitOut)
async def update_personel(
    personel_id: uuid.UUID,
    body: PersonelKayitUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> PersonelKayitOut:
    obj = await get_or_404(db, PersonelKayit, personel_id)
    veri = body.model_dump(exclude_unset=True)
    if veri.get("ad"):
        veri["ad"] = veri["ad"].strip()
    if veri.get("email") is not None:
        veri["email"] = str(veri["email"])
    await _referans_dogrula(db, AppUser, veri.get("app_user_id"), "kullanici_bulunamadi_veya_pasif")
    await _uygula(obj, veri)
    # BIRLESIK kural: tarihlerden yalniz biri gonderilmis olabilir.
    if (
        obj.cikis_tarihi is not None
        and obj.giris_tarihi is not None
        and obj.cikis_tarihi < obj.giris_tarihi
    ):
        raise APIError(422, "validation_error", "personel_tarih_sirasi")
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="personel_kayit",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return (await _personel_adlarla(db, [obj]))[0]


@router.delete("/personel-kayitlari/{personel_id}", status_code=204, response_model=None)
async def delete_personel(
    personel_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    obj = await get_or_404(db, PersonelKayit, personel_id)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="personel_kayit",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    await db.delete(obj)
    await db.flush()


# ================================ ARAC ====================================== #
async def _arac_adlarla(
    db: AsyncSession, kayitlar: list[AracKayit]
) -> list[AracKayitOut]:
    u_idler = {k.user_id for k in kayitlar if k.user_id}
    d_idler = {k.unit_id for k in kayitlar if k.unit_id}
    u_ad: dict[uuid.UUID, str] = {}
    d_no: dict[uuid.UUID, str] = {}
    if u_idler:
        u_ad = dict(
            (await db.execute(
                select(AppUser.id, AppUser.ad).where(AppUser.id.in_(u_idler))
            )).all()
        )
    if d_idler:
        d_no = dict(
            (await db.execute(
                select(Unit.id, Unit.no).where(Unit.id.in_(d_idler))
            )).all()
        )
    return [
        AracKayitOut.model_validate(k).model_copy(
            update={"user_ad": u_ad.get(k.user_id), "unit_no": d_no.get(k.unit_id)}
        )
        for k in kayitlar
    ]


@router.get("/arac-kayitlari", response_model=AracKayitListResponse)
async def list_arac_kayitlari(
    aktif: bool | None = Query(None),
    plaka: str | None = Query(None, description="Tam plaka (normalize edilir)"),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> AracKayitListResponse:
    base = select(AracKayit)
    if aktif is not None:
        base = base.where(AracKayit.aktif == aktif)
    if plaka is not None:
        # Arama da NORMALIZE edilir: kullanici "34 ABC 123" yazsa da bulmali.
        base = base.where(AracKayit.plaka == norm_plaka(plaka))
    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            base.order_by(AracKayit.plaka, AracKayit.id).limit(limit).offset(offset)
        )).scalars().all()
    )
    return AracKayitListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _arac_adlarla(db, list(kayitlar)),
    )


@router.post("/arac-kayitlari", response_model=AracKayitOut, status_code=201)
async def create_arac_kayit(
    body: AracKayitCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> AracKayitOut:
    await _referans_dogrula(db, AppUser, body.user_id, "kullanici_bulunamadi_veya_pasif")
    await _referans_dogrula(db, Unit, body.unit_id, "daire_bulunamadi")
    veri = body.model_dump()
    veri["plaka"] = norm_plaka(veri["plaka"])
    obj = AracKayit(tenant_id=user.tenant_id, **veri)
    db.add(obj)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="arac_kayit",
        resource_id=obj.id, meta={"plaka": obj.plaka},
    )
    return (await _arac_adlarla(db, [obj]))[0]


@router.patch("/arac-kayitlari/{arac_id}", response_model=AracKayitOut)
async def update_arac_kayit(
    arac_id: uuid.UUID,
    body: AracKayitUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> AracKayitOut:
    obj = await get_or_404(db, AracKayit, arac_id)
    veri = body.model_dump(exclude_unset=True)
    if veri.get("plaka"):
        veri["plaka"] = norm_plaka(veri["plaka"])
    await _referans_dogrula(db, AppUser, veri.get("user_id"), "kullanici_bulunamadi_veya_pasif")
    await _referans_dogrula(db, Unit, veri.get("unit_id"), "daire_bulunamadi")
    await _uygula(obj, veri)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="arac_kayit",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return (await _arac_adlarla(db, [obj]))[0]


@router.delete("/arac-kayitlari/{arac_id}", status_code=204, response_model=None)
async def delete_arac_kayit(
    arac_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    obj = await get_or_404(db, AracKayit, arac_id)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="arac_kayit",
        resource_id=obj.id, meta={"plaka": obj.plaka},
    )
    await db.delete(obj)
    await db.flush()


# =============================== SAYACLAR =================================== #
@router.get("/sayaclar/ana", response_model=SayacAnaListResponse)
async def list_sayac_ana(
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> SayacAnaListResponse:
    kayitlar, total = await _sayfa(
        db, SayacAna, aktif=aktif, limit=limit, offset=offset, sirala=SayacAna.ad
    )
    sayilar: dict[uuid.UUID, int] = {}
    if kayitlar:
        sayilar = dict(
            (
                await db.execute(
                    select(SayacBolum.ana_sayac_id, func.count())
                    .where(SayacBolum.ana_sayac_id.in_([k.id for k in kayitlar]))
                    .group_by(SayacBolum.ana_sayac_id)
                )
            ).all()
        )
    return SayacAnaListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            SayacAnaOut.model_validate(k).model_copy(
                update={"bolum_sayaci_sayisi": sayilar.get(k.id, 0)}
            )
            for k in kayitlar
        ],
    )


@router.post("/sayaclar/ana", response_model=SayacAnaOut, status_code=201)
async def create_sayac_ana(
    body: SayacAnaCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> SayacAnaOut:
    obj = SayacAna(
        tenant_id=user.tenant_id, **body.model_dump() | {"ad": body.ad.strip()}
    )
    db.add(obj)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="sayac_ana",
        resource_id=obj.id, meta={"ad": obj.ad, "tip": obj.tip},
    )
    return SayacAnaOut.model_validate(obj)


@router.patch("/sayaclar/ana/{sayac_id}", response_model=SayacAnaOut)
async def update_sayac_ana(
    sayac_id: uuid.UUID,
    body: SayacAnaUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> SayacAnaOut:
    obj = await get_or_404(db, SayacAna, sayac_id)
    veri = body.model_dump(exclude_unset=True)
    if veri.get("ad"):
        veri["ad"] = veri["ad"].strip()
    await _uygula(obj, veri)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="sayac_ana",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return SayacAnaOut.model_validate(obj)


@router.delete("/sayaclar/ana/{sayac_id}", status_code=200)
async def delete_sayac_ana(
    sayac_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> dict[str, int]:
    """Ana sayaci siler; DAIRE SAYACLARI DURUR, yalniz baglari bosalir."""
    obj = await get_or_404(db, SayacAna, sayac_id)
    etkilenen = (
        await db.execute(
            select(func.count()).select_from(SayacBolum)
            .where(SayacBolum.ana_sayac_id == obj.id)
        )
    ).scalar_one()
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="sayac_ana",
        resource_id=obj.id, meta={"ad": obj.ad, "etkilenen": etkilenen},
    )
    await db.delete(obj)
    await db.flush()
    return {"etkilenen_bolum_sayaci": etkilenen}


async def _bolum_adlarla(
    db: AsyncSession, kayitlar: list[SayacBolum]
) -> list[SayacBolumOut]:
    d_idler = {k.unit_id for k in kayitlar}
    a_idler = {k.ana_sayac_id for k in kayitlar if k.ana_sayac_id}
    d_no = dict(
        (await db.execute(select(Unit.id, Unit.no).where(Unit.id.in_(d_idler)))).all()
    ) if d_idler else {}
    a_ad = dict(
        (await db.execute(
            select(SayacAna.id, SayacAna.ad).where(SayacAna.id.in_(a_idler))
        )).all()
    ) if a_idler else {}
    return [
        SayacBolumOut.model_validate(k).model_copy(
            update={
                "unit_no": d_no.get(k.unit_id),
                "ana_sayac_ad": a_ad.get(k.ana_sayac_id),
            }
        )
        for k in kayitlar
    ]


@router.get("/sayaclar/bolum", response_model=SayacBolumListResponse)
async def list_sayac_bolum(
    ana_sayac_id: uuid.UUID | None = Query(None),
    unit_id: uuid.UUID | None = Query(None),
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> SayacBolumListResponse:
    base = select(SayacBolum)
    if aktif is not None:
        base = base.where(SayacBolum.aktif == aktif)
    if ana_sayac_id is not None:
        base = base.where(SayacBolum.ana_sayac_id == ana_sayac_id)
    if unit_id is not None:
        base = base.where(SayacBolum.unit_id == unit_id)
    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            base.order_by(SayacBolum.created_at, SayacBolum.id).limit(limit).offset(offset)
        )).scalars().all()
    )
    return SayacBolumListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _bolum_adlarla(db, list(kayitlar)),
    )


@router.post("/sayaclar/bolum", response_model=SayacBolumOut, status_code=201)
async def create_sayac_bolum(
    body: SayacBolumCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> SayacBolumOut:
    await _referans_dogrula(db, Unit, body.unit_id, "daire_bulunamadi")
    await _referans_dogrula(db, SayacAna, body.ana_sayac_id, "ana_sayac_bulunamadi")
    obj = SayacBolum(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="sayac_bolum",
        resource_id=obj.id, meta={"unit_id": str(obj.unit_id)},
    )
    return (await _bolum_adlarla(db, [obj]))[0]


@router.post(
    "/sayaclar/bolum/otomatik", response_model=SayacOtomatikSonuc, status_code=201
)
async def otomatik_bolum_sayaci(
    body: SayacBolumOtomatikOlustur,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> SayacOtomatikSonuc:
    """Bir ana sayac icin TUM AKTIF dairelere sayac uret (P27).

    Elle 200 daire icin sayac acmak gercekci degildir. ZATEN sayaci olan
    daireler ATLANIR — uc YENIDEN CALISTIRILABILIR (yeni daireler eklendikce
    tekrar cagrilir) ve benzersizlik kisitina carpip 409 vermez.
    """
    await _referans_dogrula(db, SayacAna, body.ana_sayac_id, "ana_sayac_bulunamadi")
    daire_idler = (
        (await db.execute(select(Unit.id).where(Unit.aktif.is_(True)))).scalars().all()
    )
    mevcut = set(
        (
            await db.execute(
                select(SayacBolum.unit_id).where(
                    SayacBolum.ana_sayac_id == body.ana_sayac_id
                )
            )
        ).scalars().all()
    )
    olusturulan = 0
    for uid in daire_idler:
        if uid in mevcut:
            continue
        db.add(
            SayacBolum(
                tenant_id=user.tenant_id,
                unit_id=uid,
                ana_sayac_id=body.ana_sayac_id,
            )
        )
        olusturulan += 1
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_CREATE, resource_type="sayac_bolum",
        resource_id=body.ana_sayac_id,
        meta={"otomatik": True, "olusturulan": olusturulan},
    )
    return SayacOtomatikSonuc(
        olusturulan=olusturulan, atlanan=len(daire_idler) - olusturulan
    )


@router.patch("/sayaclar/bolum/{sayac_id}", response_model=SayacBolumOut)
async def update_sayac_bolum(
    sayac_id: uuid.UUID,
    body: SayacBolumUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> SayacBolumOut:
    obj = await get_or_404(db, SayacBolum, sayac_id)
    veri = body.model_dump(exclude_unset=True)
    await _referans_dogrula(
        db, SayacAna, veri.get("ana_sayac_id"), "ana_sayac_bulunamadi"
    )
    await _uygula(obj, veri)
    await _kaydet(db, obj)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_UPDATE, resource_type="sayac_bolum",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return (await _bolum_adlarla(db, [obj]))[0]


@router.delete("/sayaclar/bolum/{sayac_id}", status_code=204, response_model=None)
async def delete_sayac_bolum(
    sayac_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    obj = await get_or_404(db, SayacBolum, sayac_id)
    await audit_user(
        db, user, Action.MUHASEBE_TANIM_DELETE, resource_type="sayac_bolum",
        resource_id=obj.id, meta={"unit_id": str(obj.unit_id)},
    )
    await db.delete(obj)
    await db.flush()


# =========================== MUHASEBE AYARLARI ============================== #
@router.get("/muhasebe-ayarlari", response_model=MuhasebeAyarOut)
async def get_muhasebe_ayarlari(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MuhasebeAyarOut:
    obj = await get_or_404(db, Tenant, user.tenant_id)
    return MuhasebeAyarOut.model_validate(obj)


@router.patch("/muhasebe-ayarlari", response_model=MuhasebeAyarOut)
async def update_muhasebe_ayarlari(
    body: MuhasebeAyarUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> MuhasebeAyarOut:
    """Evrak seri/sira + para birimi.

    `para_birimi` YALNIZ GOSTERIMDIR: depo ve hesaplama ₺ kalir. Cok para
    birimi (kur, ceviri tarihi, raporlama para birimi) AYRI bir karardir ve
    bu alani "destekleniyor" saymak sessiz yanlis toplamlar uretirdi.
    """
    obj = await get_or_404(db, Tenant, user.tenant_id)
    veri = body.model_dump(exclude_unset=True)
    await _uygula(obj, veri)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.MUHASEBE_AYAR_UPDATE, resource_type="tenant",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return MuhasebeAyarOut.model_validate(obj)
