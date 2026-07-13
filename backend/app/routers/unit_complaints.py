"""Daire sikayeti (D1) — sakin -> HEDEF DAIRE, TAM ANONIM.

HARD ANONIMLIK KURALI (auth.md §4): `complainant_user_id` YALNIZ ic spam
korumasi + RLS icindir; HICBIR uctan/serializer'dan DONMEZ — yonetici/admin
dahil kimse sikayet edeni goremez. Herkes yalniz daire-basi ACIK sayilar + renk
gorur. Yonetimin ayri `/complaints` (yonetime sikayet) modulunden BAGIMSIZDIR.

Spam korumasi: ayni sakin ayni hedef daireye AYNI ANDA yalniz BIR ACIK sikayet
acabilir (DB partial-unique; kapatilinca yeniden acilabilir) -> 409.

Renk (ACIK sikayet sayisi): 0-2 yesil, 3-4 sari, 5+ kirmizi.
Not gizliligi: `notlar` serbest metni YALNIZ yonetim (admin+yonetici) icin
doner (deanonimlestirme/target-shaming riskini sinirlar); diger roller null gorur.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitComplaint
from ..schemas import (
    BuildingMapBlok,
    BuildingMapKat,
    BuildingMapResponse,
    BuildingMapUnit,
    UnitComplaintCreate,
    UnitComplaintDecision,
    UnitComplaintDurum,
    UnitComplaintListResponse,
    UnitComplaintOut,
    UnitDensityItem,
    UnitDensityResponse,
)

router = APIRouter(prefix="/unit-complaints", tags=["unit-complaints"])

# Sikayet ACMA yalniz sakin (baska daireyi bildirir).
_FILER = require_role("resident")
# Yogunluk/liste OKUMA — tum roller (tenant-ici "harita" herkese acik).
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
# Kapatma — yonetim (sikayet edeni GORMEDEN yalniz durum degistirir).
_MANAGER = require_role("admin", "yonetici")
# Not (serbest metin) YALNIZ yonetime doner.
_NOTE_ROLES = {"admin", "yonetici"}


def _color(count: int) -> str:
    if count <= 2:
        return "yesil"
    if count <= 4:
        return "sari"
    return "kirmizi"


# ------------------------------- kayit -------------------------------------- #
@router.post("", response_model=UnitComplaintOut, status_code=201)
async def file_unit_complaint(
    body: UnitComplaintCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FILER),
) -> UnitComplaintOut:
    # Hedef daire ayni tenant'ta olmali (RLS + kontrol). Baska tenant/olmayan -> 422.
    unit = (
        await db.execute(select(Unit).where(Unit.id == body.target_unit_id))
    ).scalar_one_or_none()
    if unit is None:
        raise APIError(422, "invalid_reference", "Hedef daire bu tenant'ta bulunamadi.")

    obj = UnitComplaint(
        tenant_id=user.tenant_id,
        target_unit_id=unit.id,
        complainant_user_id=user.id,  # IC — asla donmez
        kategori=body.kategori,
        notlar=body.notlar,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        # partial-unique (tenant,target,complainant) WHERE durum='acik' -> spam.
        if is_unique_violation(exc):
            raise APIError(
                409, "conflict",
                "Bu daire icin zaten acik bir sikayetiniz var.",
            )
        raise translate_integrity(exc)
    await db.refresh(obj)
    # Sikayet acan kendi kaydini gorur (kendi notunu — deanonimlestirme degil).
    return UnitComplaintOut.from_model(obj, unit_no=unit.no, include_note=True)


# ------------------------------ yogunluk ------------------------------------ #
@router.get("/density", response_model=UnitDensityResponse)
async def unit_density(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> UnitDensityResponse:
    """Daire-basi ANONIM yogunluk: TUM daireler + ACIK sikayet sayisi + renk.
    Sikayet eden verisi YOKTUR. (Ileride 2D bina haritasini besler.)"""
    rows = (
        await db.execute(
            select(
                Unit.id,
                Unit.no,
                Unit.blok,
                func.count(UnitComplaint.id),
            )
            .select_from(Unit)
            .outerjoin(
                UnitComplaint,
                and_(
                    UnitComplaint.target_unit_id == Unit.id,
                    UnitComplaint.durum == "acik",
                ),
            )
            .group_by(Unit.id, Unit.no, Unit.blok)
            .order_by(Unit.no)
        )
    ).all()
    items = [
        UnitDensityItem(
            target_unit_id=r[0],
            unit_no=r[1],
            blok=r[2],
            acik_sayisi=r[3],
            renk=_color(r[3]),
        )
        for r in rows
    ]
    return UnitDensityResponse(items=items)


# ------------------------------ bina haritasi ------------------------------- #
@router.get("/building-map", response_model=BuildingMapResponse)
async def building_map(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> BuildingMapResponse:
    """Cizilebilir bina semasi: blok -> kat -> daire (yerlesim + ANONIM sayim +
    renk). Yerlesimi (blok/kat/sira uclusu) eksik daireler 'unplaced' kovada.
    Tum roller okur (tenant-ici harita). Sikayet eden verisi YOKTUR."""
    rows = (
        await db.execute(
            select(
                Unit.id,
                Unit.no,
                Unit.blok,
                Unit.kat,
                Unit.sira,
                func.count(UnitComplaint.id),
            )
            .select_from(Unit)
            .outerjoin(
                UnitComplaint,
                and_(
                    UnitComplaint.target_unit_id == Unit.id,
                    UnitComplaint.durum == "acik",
                ),
            )
            .group_by(Unit.id, Unit.no, Unit.blok, Unit.kat, Unit.sira)
            .order_by(Unit.no)
        )
    ).all()

    unplaced: list[BuildingMapUnit] = []
    # blok -> kat -> [BuildingMapUnit]; sirali insert icin dict + sonda sort.
    grouped: dict[str, dict[int, list[BuildingMapUnit]]] = {}
    for uid, no, blok, kat, sira, count in rows:
        item = BuildingMapUnit(
            unit_id=uid,
            unit_no=no,
            blok=blok,
            kat=kat,
            sira=sira,
            complaint_count=count,
            color=_color(count),
        )
        # Yerlesim TAM olmali (blok + kat) — biri eksikse cizilemez -> unplaced.
        if blok is None or kat is None:
            unplaced.append(item)
        else:
            grouped.setdefault(blok, {}).setdefault(kat, []).append(item)

    bloklar = [
        BuildingMapBlok(
            blok=blok,
            katlar=[
                BuildingMapKat(
                    kat=kat,
                    # sira NULL ise sona; ayni sira'da unit_no ile kararli sirala.
                    units=sorted(
                        units,
                        key=lambda u: (u.sira is None, u.sira or 0, u.unit_no),
                    ),
                )
                for kat, units in sorted(katlar.items())  # kat artan (0=zemin altta)
            ],
        )
        for blok, katlar in sorted(grouped.items())
    ]
    return BuildingMapResponse(bloklar=bloklar, unplaced=unplaced)


# ------------------------------- liste -------------------------------------- #
@router.get("", response_model=UnitComplaintListResponse)
async def list_unit_complaints(
    target_unit_id: uuid.UUID | None = Query(None),
    durum: UnitComplaintDurum | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> UnitComplaintListResponse:
    """Daire sikayetleri (kategori + tarih + durum). complainant ASLA yok;
    `notlar` YALNIZ yonetim icin dolu."""
    base = select(UnitComplaint, Unit.no).join(
        Unit, Unit.id == UnitComplaint.target_unit_id
    )
    if target_unit_id is not None:
        base = base.where(UnitComplaint.target_unit_id == target_unit_id)
    if durum is not None:
        base = base.where(UnitComplaint.durum == durum)

    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            base.order_by(UnitComplaint.created_at.desc()).limit(limit).offset(offset)
        )
    ).all()
    include_note = user.role in _NOTE_ROLES
    return UnitComplaintListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            UnitComplaintOut.from_model(obj, unit_no=no, include_note=include_note)
            for obj, no in rows
        ],
    )


# ------------------------------- kapatma ------------------------------------ #
@router.patch("/{complaint_id}", response_model=UnitComplaintOut)
async def close_unit_complaint(
    complaint_id: uuid.UUID,
    body: UnitComplaintDecision,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> UnitComplaintOut:
    """Yonetim durumu degistirir (kapali) — sikayet edeni GORMEDEN. Kapatma
    ACIK sayimi dusurur (renk feedback). Sikayet acan alani yine DONMEZ."""
    obj = await get_or_404(db, UnitComplaint, complaint_id)
    obj.durum = body.durum
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    unit_no = (
        await db.execute(select(Unit.no).where(Unit.id == obj.target_unit_id))
    ).scalar_one_or_none()
    return UnitComplaintOut.from_model(obj, unit_no=unit_no, include_note=True)
