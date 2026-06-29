"""Unit (daire) CRUD + sakin atama — /contracts/openapi.yaml. RBAC: admin."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitResident
from ..schemas import (
    ResidentAssign,
    UnitCreate,
    UnitListResponse,
    UnitOut,
    UnitResidentOut,
    UnitUpdate,
)

router = APIRouter(prefix="/units", tags=["aidat"])

_ADMIN = require_role("admin")


@router.get("", response_model=UnitListResponse)
async def list_units(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    blok: str | None = Query(None),
    aktif: bool | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> UnitListResponse:
    where = []
    if blok is not None:
        where.append(Unit.blok == blok)
    if aktif is not None:
        where.append(Unit.aktif == aktif)
    total = (await db.execute(select(func.count()).select_from(Unit).where(*where))).scalar_one()
    rows = (
        await db.execute(select(Unit).where(*where).order_by(Unit.no).limit(limit).offset(offset))
    ).scalars().all()
    return UnitListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=list(rows))


@router.get("/{unit_id}", response_model=UnitOut)
async def get_unit(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Unit:
    return await get_or_404(db, Unit, unit_id)


@router.post("", response_model=UnitOut, status_code=201)
async def create_unit(
    body: UnitCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> Unit:
    obj = Unit(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Daire no bu tesiste zaten kayitli.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{unit_id}", response_model=UnitOut)
async def update_unit(
    unit_id: uuid.UUID,
    body: UnitUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Unit:
    obj = await get_or_404(db, Unit, unit_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Daire no bu tesiste zaten kayitli.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.delete("/{unit_id}", status_code=204)
async def delete_unit(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Response:
    obj = await get_or_404(db, Unit, unit_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)


# ------------------------------ sakinler ----------------------------------- #
@router.get("/{unit_id}/residents", response_model=list[UnitResidentOut])
async def list_residents(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> list[UnitResident]:
    await get_or_404(db, Unit, unit_id)
    rows = (
        await db.execute(
            select(UnitResident)
            .where(UnitResident.unit_id == unit_id)
            .order_by(UnitResident.created_at)
        )
    ).scalars().all()
    return list(rows)


@router.post("/{unit_id}/residents", response_model=UnitResidentOut, status_code=201)
async def assign_resident(
    unit_id: uuid.UUID,
    body: ResidentAssign,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> UnitResident:
    await get_or_404(db, Unit, unit_id)
    target = (
        await db.execute(select(AppUser).where(AppUser.id == body.user_id))
    ).scalar_one_or_none()
    if target is None:
        raise APIError(422, "invalid_reference", "user_id bu tenant'ta bulunamadi.")
    if target.role != "resident":
        raise APIError(422, "invalid_reference", "Atanacak kullanici role=resident olmali.")

    obj = UnitResident(
        tenant_id=user.tenant_id,
        unit_id=unit_id,
        user_id=body.user_id,
        rol_tipi=body.rol_tipi,
        baslangic=body.baslangic,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Bu kullanici daireye zaten aktif olarak bagli.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.delete("/{unit_id}/residents/{user_id}", status_code=204)
async def remove_resident(
    unit_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Response:
    await get_or_404(db, Unit, unit_id)
    binding = (
        await db.execute(
            select(UnitResident).where(
                UnitResident.unit_id == unit_id,
                UnitResident.user_id == user_id,
                UnitResident.bitis.is_(None),
            )
        )
    ).scalar_one_or_none()
    if binding is None:
        raise APIError(404, "not_found", "Aktif sakin baglantisi bulunamadi.")
    binding.bitis = datetime.now(tz=timezone.utc)
    await db.flush()
    return Response(status_code=204)
