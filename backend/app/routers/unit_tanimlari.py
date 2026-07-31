"""Bagimsiz Bolum TIPLERI ve GRUPLARI (P26) — `/unit-tipleri`, `/unit-gruplari`.

IKI AYRI KAVRAM (bkz. 0016 revizyonu):
  * GRUP — bolumun NE OLDUGU (Daire / Villa / Dukkan / Depo). Raporlama
    kirilimi.
  * TIP  — buyukluk/duzen (1+0, 2+1, dubleks…) + **VARSAYILAN AIDAT TUTARI**.
    Ad SERBEST metindir; sabit bir enum "1+1,5" ya da "stüdyo" diyen siteyi
    disarida birakirdi.

RBAC: yazma admin+yonetici (site yonetimi kendi tip listesini kurar); OKUMA
yonetim + saha, cunku daire listeleri/bina duzenleme ekrani tip/grup adini
gosterir. Sakin bu uclara ERISEMEZ (site yonetim tanimlari).

SILME — REDDETMEZ, KOPARIR: bagli daire varsa silme 409 vermez; `unit`
baglantilari ON DELETE SET NULL ile bosalir ve daireler DURUR. Gerekce:
tanim listesi temizlemek yaygin bir bakimdir ve "once 400 daireyi tek tek
degistir" demek, kullaniciyi tanimi `aktif=false` yapip listede birakmaya
iter — ki bu da ayni karmasayi baska bicimde uretir. Yanit KAC daireyi
etkiledigini doner (`etkilenen_daire`), yani islem sessiz degildir.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..models import AppUser, Unit, UnitGrup, UnitTip
from ..schemas import (
    UnitGrupCreate,
    UnitGrupListResponse,
    UnitGrupOut,
    UnitGrupUpdate,
    UnitTipCreate,
    UnitTipListResponse,
    UnitTipOut,
    UnitTipUpdate,
)

router = APIRouter(tags=["aidat"])

_WRITER = require_role("admin", "yonetici")
# OKUMA saha rollerine de acik: daire listesi + bina duzenleme tip/grup adini
# gosterir; sakin bu tanimlara erisemez.
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")


async def _daire_sayilari(
    db: AsyncSession, sutun, idler: list[uuid.UUID]
) -> dict[uuid.UUID, int]:
    """Tanim basina bagli daire sayisi — TEK sorgu (liste basina N+1 yok)."""
    if not idler:
        return {}
    rows = await db.execute(
        select(sutun, func.count())
        .where(sutun.in_(idler))
        .group_by(sutun)
    )
    return {tid: adet for tid, adet in rows.all()}


# ============================== GRUPLAR ==================================== #
@router.get("/unit-gruplari", response_model=UnitGrupListResponse)
async def list_unit_gruplari(
    aktif: bool | None = Query(None, description="Yalniz aktif/pasif"),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> UnitGrupListResponse:
    base = select(UnitGrup)
    if aktif is not None:
        base = base.where(UnitGrup.aktif == aktif)
    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(base.order_by(UnitGrup.ad).limit(limit).offset(offset)))
        .scalars()
        .all()
    )
    sayilar = await _daire_sayilari(
        db, Unit.unit_grup_id, [k.id for k in kayitlar]
    )
    return UnitGrupListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            UnitGrupOut.model_validate(k).model_copy(
                update={"daire_sayisi": sayilar.get(k.id, 0)}
            )
            for k in kayitlar
        ],
    )


@router.post("/unit-gruplari", response_model=UnitGrupOut, status_code=201)
async def create_unit_grup(
    body: UnitGrupCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> UnitGrupOut:
    obj = UnitGrup(tenant_id=user.tenant_id, ad=body.ad.strip(), aktif=body.aktif)
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.UNIT_GRUP_CREATE, resource_type="unit_grup",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    return UnitGrupOut.model_validate(obj)


@router.patch("/unit-gruplari/{grup_id}", response_model=UnitGrupOut)
async def update_unit_grup(
    grup_id: uuid.UUID,
    body: UnitGrupUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> UnitGrupOut:
    obj = await get_or_404(db, UnitGrup, grup_id)
    veri = body.model_dump(exclude_unset=True)
    if "ad" in veri and veri["ad"] is not None:
        veri["ad"] = veri["ad"].strip()
    for alan, deger in veri.items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.UNIT_GRUP_UPDATE, resource_type="unit_grup",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    sayilar = await _daire_sayilari(db, Unit.unit_grup_id, [obj.id])
    return UnitGrupOut.model_validate(obj).model_copy(
        update={"daire_sayisi": sayilar.get(obj.id, 0)}
    )


@router.delete("/unit-gruplari/{grup_id}", status_code=200)
async def delete_unit_grup(
    grup_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> dict[str, int]:
    """Grubu siler; bagli daireler DURUR, yalniz gruplari bosalir (SET NULL).
    Yanit kac daireyi etkiledigini doner — islem sessiz degildir."""
    obj = await get_or_404(db, UnitGrup, grup_id)
    etkilenen = (
        await db.execute(
            select(func.count()).select_from(Unit).where(Unit.unit_grup_id == obj.id)
        )
    ).scalar_one()
    await audit_user(
        db, user, Action.UNIT_GRUP_DELETE, resource_type="unit_grup",
        resource_id=obj.id, meta={"ad": obj.ad, "etkilenen_daire": etkilenen},
    )
    await db.delete(obj)
    await db.flush()
    return {"etkilenen_daire": etkilenen}


# =============================== TIPLER ==================================== #
@router.get("/unit-tipleri", response_model=UnitTipListResponse)
async def list_unit_tipleri(
    aktif: bool | None = Query(None),
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> UnitTipListResponse:
    base = select(UnitTip)
    if aktif is not None:
        base = base.where(UnitTip.aktif == aktif)
    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    kayitlar = (
        (await db.execute(base.order_by(UnitTip.ad).limit(limit).offset(offset)))
        .scalars()
        .all()
    )
    sayilar = await _daire_sayilari(db, Unit.unit_tip_id, [k.id for k in kayitlar])
    return UnitTipListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            UnitTipOut.model_validate(k).model_copy(
                update={"daire_sayisi": sayilar.get(k.id, 0)}
            )
            for k in kayitlar
        ],
    )


@router.post("/unit-tipleri", response_model=UnitTipOut, status_code=201)
async def create_unit_tip(
    body: UnitTipCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> UnitTipOut:
    obj = UnitTip(
        tenant_id=user.tenant_id,
        ad=body.ad.strip(),
        varsayilan_aidat_kurus=body.varsayilan_aidat_kurus,
        aktif=body.aktif,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.UNIT_TIP_CREATE, resource_type="unit_tip",
        resource_id=obj.id,
        meta={"ad": obj.ad, "varsayilan_aidat_kurus": obj.varsayilan_aidat_kurus},
    )
    return UnitTipOut.model_validate(obj)


@router.patch("/unit-tipleri/{tip_id}", response_model=UnitTipOut)
async def update_unit_tip(
    tip_id: uuid.UUID,
    body: UnitTipUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> UnitTipOut:
    """Tipi gunceller.

    `varsayilan_aidat_kurus: null` GONDERILEBILIR ve tutari KALDIRIR —
    `exclude_unset` sayesinde "gonderilmedi" ile "null gonderildi" ayrilir.
    Bu ayrim onemli: 0 gecerli bir tutardir (muaf daire), null ise
    "tanimsiz"dir.
    """
    obj = await get_or_404(db, UnitTip, tip_id)
    veri = body.model_dump(exclude_unset=True)
    if "ad" in veri and veri["ad"] is not None:
        veri["ad"] = veri["ad"].strip()
    for alan, deger in veri.items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.UNIT_TIP_UPDATE, resource_type="unit_tip",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    sayilar = await _daire_sayilari(db, Unit.unit_tip_id, [obj.id])
    return UnitTipOut.model_validate(obj).model_copy(
        update={"daire_sayisi": sayilar.get(obj.id, 0)}
    )


@router.delete("/unit-tipleri/{tip_id}", status_code=200)
async def delete_unit_tip(
    tip_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> dict[str, int]:
    """Tipi siler; bagli daireler DURUR, yalniz tipleri bosalir (SET NULL)."""
    obj = await get_or_404(db, UnitTip, tip_id)
    etkilenen = (
        await db.execute(
            select(func.count()).select_from(Unit).where(Unit.unit_tip_id == obj.id)
        )
    ).scalar_one()
    await audit_user(
        db, user, Action.UNIT_TIP_DELETE, resource_type="unit_tip",
        resource_id=obj.id, meta={"ad": obj.ad, "etkilenen_daire": etkilenen},
    )
    await db.delete(obj)
    await db.flush()
    return {"etkilenen_daire": etkilenen}
