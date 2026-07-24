"""Shift CRUD — /contracts/openapi.yaml (shifts) + RBAC (auth.md §4).

RBAC: GET admin/yonetici/security/tesis_gorevlisi (yonetici: mobil panel
"Vardiya Durumu" bolumu vardiya tanimlarini OKUR); POST/PATCH/DELETE yalniz
admin; PUT /{id}/assignments admin+yonetici (personel atamasi, yalniz saha
rolleri atanabilir). Tenant token'dan gelir (get_tenant_db + RLS); istekten
ASLA alinmaz.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Shift, ShiftAssignment
from ..schemas import (
    GunTipi,
    ShiftAssignmentsUpdate,
    ShiftCreate,
    ShiftListResponse,
    ShiftOut,
    ShiftPersonelOut,
    ShiftUpdate,
)
from ..storage import presign_get

router = APIRouter(prefix="/shifts", tags=["shifts"])

_ADMIN = require_role("admin")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")
_ASSIGNER = require_role("admin", "yonetici")
_ATANABILIR = {"security", "tesis_gorevlisi"}


async def _personel_map(
    db: AsyncSession, shift_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[ShiftPersonelOut]]:
    """shift_id -> atanan personel listesi (ad + presigned avatar)."""
    if not shift_ids:
        return {}
    rows = (
        await db.execute(
            select(ShiftAssignment.shift_id, AppUser)
            .join(AppUser, AppUser.id == ShiftAssignment.user_id)
            .where(ShiftAssignment.shift_id.in_(shift_ids))
            .order_by(AppUser.ad)
        )
    ).all()
    out: dict[uuid.UUID, list[ShiftPersonelOut]] = {}
    for shift_id, u in rows:
        out.setdefault(shift_id, []).append(
            ShiftPersonelOut(
                user_id=u.id, ad=u.ad,
                avatar_url=presign_get(u.avatar_key) if u.avatar_key else None,
            )
        )
    return out


def _shift_out(obj: Shift, personel: list[ShiftPersonelOut]) -> ShiftOut:
    out = ShiftOut.model_validate(obj)
    out.personel = personel
    return out


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
    pmap = await _personel_map(db, [r.id for r in rows])
    return ShiftListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_shift_out(r, pmap.get(r.id, [])) for r in rows],
    )


@router.get("/{shift_id}", response_model=ShiftOut)
async def get_shift(
    shift_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> ShiftOut:
    obj = await get_or_404(db, Shift, shift_id)
    pmap = await _personel_map(db, [obj.id])
    return _shift_out(obj, pmap.get(obj.id, []))


@router.put("/{shift_id}/assignments", response_model=ShiftOut)
async def replace_assignments(
    shift_id: uuid.UUID,
    body: ShiftAssignmentsUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ASSIGNER),
) -> ShiftOut:
    """Vardiya personelini TAM LISTE olarak degistirir (admin + yonetici).

    Yalniz saha rolleri atanabilir (security|tesis_gorevlisi) — baska rol id'si
    422. RLS: yabanci tenant vardiyasi 404."""
    obj = await get_or_404(db, Shift, shift_id)
    ids = list(dict.fromkeys(body.user_ids))  # sirali tekillestirme
    if ids:
        users = (
            (await db.execute(select(AppUser).where(AppUser.id.in_(ids)))).scalars().all()
        )
        if len(users) != len(ids) or any(u.role not in _ATANABILIR for u in users):
            raise APIError(
                422, "invalid_assignment",
                "Yalniz security/tesis_gorevlisi kullanicilari atanabilir.",
            )
    await db.execute(delete(ShiftAssignment).where(ShiftAssignment.shift_id == shift_id))
    for uid in ids:
        db.add(ShiftAssignment(tenant_id=user.tenant_id, shift_id=shift_id, user_id=uid))
    await db.flush()
    await audit_user(
        db, user, Action.SHIFT_ASSIGN, resource_type="shift", resource_id=shift_id,
        meta={"user_ids": [str(i) for i in ids]},
    )
    pmap = await _personel_map(db, [shift_id])
    return _shift_out(obj, pmap.get(shift_id, []))


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
