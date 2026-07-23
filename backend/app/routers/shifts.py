"""Shift CRUD — /contracts/openapi.yaml (shifts) + RBAC (auth.md §4).

RBAC: GET admin/yonetici/security/tesis_gorevlisi (yonetici: mobil panel
"Vardiya Durumu" bolumu vardiya tanimlarini OKUR); POST/PATCH/DELETE yalniz
admin. Tenant token'dan gelir (get_tenant_db + RLS); istekten ASLA alinmaz.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..models import AppUser, Shift
from ..schemas import (
    GunTipi,
    ShiftCreate,
    ShiftListResponse,
    ShiftOut,
    ShiftUpdate,
)

router = APIRouter(prefix="/shifts", tags=["shifts"])

_ADMIN = require_role("admin")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")


@router.get("", response_model=ShiftListResponse)
async def list_shifts(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    gun_tipi: GunTipi | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> ShiftListResponse:
    where = [Shift.gun_tipi == gun_tipi] if gun_tipi else []
    total = (
        await db.execute(select(func.count()).select_from(Shift).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(Shift).where(*where).order_by(Shift.created_at).limit(limit).offset(offset)
        )
    ).scalars().all()
    return ShiftListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=list(rows),
    )


@router.get("/{shift_id}", response_model=ShiftOut)
async def get_shift(
    shift_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> Shift:
    return await get_or_404(db, Shift, shift_id)


@router.post("", response_model=ShiftOut, status_code=201)
async def create_shift(
    body: ShiftCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> Shift:
    obj = Shift(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{shift_id}", response_model=ShiftOut)
async def update_shift(
    shift_id: uuid.UUID,
    body: ShiftUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Shift:
    obj = await get_or_404(db, Shift, shift_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.delete("/{shift_id}", status_code=204)
async def delete_shift(
    shift_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Response:
    obj = await get_or_404(db, Shift, shift_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)
