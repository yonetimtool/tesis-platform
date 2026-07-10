"""Ortak alan tanimlari (havuz/teras/toplanti odasi) — rezervasyonun temeli.

RBAC (auth.md §4): OLUSTURMA/DUZENLEME yonetici + admin (site yonetimi alani
tanimlar). OKUMA TUM roller — sakin neyin rezerve edilebilir oldugunu gormeli;
yonetim pasif alanlari da gorur (duzenleme icin), diger roller YALNIZ aktif
alanlari gorur. Silme YOK: alan kaldirma = aktif=false (soft-delete) —
rezervasyon gecmisi korunur (FK RESTRICT hard-delete'i zaten engeller).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, OrtakAlan
from ..schemas import (
    OrtakAlanCreate,
    OrtakAlanListResponse,
    OrtakAlanOut,
    OrtakAlanUpdate,
)

router = APIRouter(prefix="/common-areas", tags=["rezervasyon"])

_MANAGER = require_role("admin", "yonetici")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")

# Alan yonetimi (pasifler dahil tum listeyi gorme) yonetim rolleri.
_MANAGEMENT_ROLES = ("admin", "yonetici")


@router.get("", response_model=OrtakAlanListResponse)
async def list_areas(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> OrtakAlanListResponse:
    stmt = select(OrtakAlan)
    # Yonetim pasif alanlari da gorur (duzenleme/yeniden aktive etme);
    # diger roller yalniz rezerve edilebilir (aktif) alanlari.
    if user.role not in _MANAGEMENT_ROLES:
        stmt = stmt.where(OrtakAlan.aktif.is_(True))
    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(stmt.order_by(OrtakAlan.ad).limit(limit).offset(offset))
    ).scalars().all()
    return OrtakAlanListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=list(rows),
    )


@router.post("", response_model=OrtakAlanOut, status_code=201)
async def create_area(
    body: OrtakAlanCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> OrtakAlan:
    obj = OrtakAlan(tenant_id=user.tenant_id, ad=body.ad, aciklama=body.aciklama)
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Bu adla bir ortak alan zaten var.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{area_id}", response_model=OrtakAlanOut)
async def update_area(
    area_id: uuid.UUID,
    body: OrtakAlanUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> OrtakAlan:
    obj = (
        await db.execute(select(OrtakAlan).where(OrtakAlan.id == area_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    payload = body.model_dump(exclude_unset=True)
    for k, v in payload.items():
        setattr(obj, k, v)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Bu adla bir ortak alan zaten var.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj
