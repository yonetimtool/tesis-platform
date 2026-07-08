"""Kullanici yonetimi — GET/POST/PATCH /users (admin) — /contracts/openapi.yaml.

Mevcut app_user tablosu uzerinde calisir (yeni tablo yok). parola bcrypt ile
hash'lenir; password_hash YANITTA donmez (UserAdminOut'ta yok). tenant token'dan,
RLS izole. email tenant icinde benzersiz -> cakisma 409. Silme yok; pasiflestirme
is_active=false (PATCH).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser
from ..schemas import (
    UserAdminListResponse,
    UserAdminOut,
    UserCreate,
    UserRoleLiteral,
    UserUpdate,
)
from ..security import hash_password

router = APIRouter(prefix="/users", tags=["users"])

_ADMIN = require_role("admin")
# yonetici gorev atamak icin kullanici listesini OKUR; CRUD admin-only (auth.md §4).
_READER = require_role("admin", "yonetici")
_EMAIL_CONFLICT = APIError(409, "conflict", "email bu tenant'ta zaten kayitli.")


@router.get("", response_model=UserAdminListResponse)
async def list_users(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    role: UserRoleLiteral | None = Query(None),
    is_active: bool | None = Query(None),
    q: str | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> UserAdminListResponse:
    where = []
    if role is not None:
        where.append(AppUser.role == role)
    if is_active is not None:
        where.append(AppUser.is_active == is_active)
    if q:
        like = f"%{q}%"
        where.append(or_(AppUser.ad.ilike(like), AppUser.email.ilike(like)))
    total = (await db.execute(select(func.count()).select_from(AppUser).where(*where))).scalar_one()
    rows = (
        await db.execute(select(AppUser).where(*where).order_by(AppUser.ad).limit(limit).offset(offset))
    ).scalars().all()
    return UserAdminListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=list(rows))


@router.get("/{user_id}", response_model=UserAdminOut)
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> AppUser:
    return await get_or_404(db, AppUser, user_id)


@router.post("", response_model=UserAdminOut, status_code=201)
async def create_user(
    body: UserCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> AppUser:
    obj = AppUser(
        tenant_id=user.tenant_id,
        ad=body.ad,
        email=str(body.email),
        telefon=body.telefon,
        password_hash=hash_password(body.password),
        role=body.role,
        is_active=True,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _EMAIL_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{user_id}", response_model=UserAdminOut)
async def update_user(
    user_id: uuid.UUID,
    body: UserUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> AppUser:
    obj = await get_or_404(db, AppUser, user_id)
    data = body.model_dump(exclude_unset=True)
    new_password = data.pop("password", None)
    if "email" in data and data["email"] is not None:
        data["email"] = str(data["email"])
    for key, value in data.items():
        setattr(obj, key, value)
    if new_password is not None:
        obj.password_hash = hash_password(new_password)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _EMAIL_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj
