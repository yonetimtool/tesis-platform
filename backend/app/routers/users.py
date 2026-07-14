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
    UserContactUpdate,
    UserCreate,
    UserCreatedOut,
    UserRoleLiteral,
    UserUpdate,
)
from ..security import generate_temp_code, hash_password

router = APIRouter(prefix="/users", tags=["users"])

_ADMIN = require_role("admin")
# yonetici gorev atamak icin kullanici listesini OKUR; CRUD admin-only (auth.md §4).
_READER = require_role("admin", "yonetici")
# Kullanici OLUSTURMA: admin (her rol) + yonetici (YALNIZ saha personeli).
_USER_CREATOR = require_role("admin", "yonetici")
# yonetici self-signup ile tesis acabildiginden (Ozellik 3), kendi tenant'inda
# saha personeli (security/tesis_gorevlisi) acar; admin/yonetici/resident ACAMAZ
# (yetki yukseltme yok — resident'lar POST /residents ile acilir).
_YONETICI_CREATABLE_ROLES = frozenset({"security", "tesis_gorevlisi"})
# Iletisim ayari (telefon + arama rizasi) admin + yonetici yonetir (rol/parola
# gibi hassas alanlara dokunmadan — yetki yukseltme yok).
_CONTACT_MANAGER = require_role("admin", "yonetici")
# telefon global benzersiz; email tenant-ici benzersiz — hangisi cakisti
# ayirt edilmeden tek mesaj.
_CONTACT_CONFLICT = APIError(409, "conflict", "Bu telefon veya e-posta zaten kayitli.")


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


@router.post("", response_model=UserCreatedOut, status_code=201)
async def create_user(
    body: UserCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_USER_CREATOR),
) -> UserCreatedOut:
    # yonetici YALNIZ saha personeli acabilir (yetki yukseltme yok).
    if user.role == "yonetici" and body.role not in _YONETICI_CREATABLE_ROLES:
        raise APIError(
            403, "forbidden",
            "Bu rolu olusturamazsiniz (yalniz guvenlik/tesis gorevlisi).",
        )
    # password verilirse admin parolayi dogrudan belirler (password_set=true);
    # verilmezse TEK SEFERLIK gecici kod uretilir (temp password first) —
    # kod yanitta bir kez doner, kullanici telefonla girip parola belirler.
    temp_code: str | None = None
    if body.password is not None:
        password_hash = hash_password(body.password)
        password_set = True
        temp_code_hash = None
    else:
        temp_code = generate_temp_code()
        password_hash = None
        password_set = False
        temp_code_hash = hash_password(temp_code)

    obj = AppUser(
        tenant_id=user.tenant_id,
        ad=body.ad,
        email=str(body.email) if body.email else None,
        telefon=body.telefon,
        aranabilir=body.aranabilir,
        password_hash=password_hash,
        password_set=password_set,
        temp_code_hash=temp_code_hash,
        role=body.role,
        is_active=True,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _CONTACT_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    return UserCreatedOut(
        id=obj.id,
        ad=obj.ad,
        email=obj.email,
        telefon=obj.telefon,
        aranabilir=obj.aranabilir,
        role=obj.role,
        is_active=obj.is_active,
        created_at=obj.created_at,
        temp_code=temp_code,
    )


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
        obj.password_set = True
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _CONTACT_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{user_id}/contact", response_model=UserAdminOut)
async def update_user_contact(
    user_id: uuid.UUID,
    body: UserContactUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_CONTACT_MANAGER),
) -> AppUser:
    """Rol-bazli arama iletisim ayari (C1a): telefon + arama rizasi.

    admin + yonetici yonetir — rol/parola/is_active gibi hassas alanlara
    DOKUNMADAN (tam PATCH admin-only kalir; yonetici burada yalniz iletisim
    ayarini gunceller — yetki yukseltme yok). Numara yonetim tarafindan girilir;
    kullanici bu turda kendi yonetmez.
    """
    obj = await get_or_404(db, AppUser, user_id)
    data = body.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        # telefon GLOBAL benzersiz -> baska kullanicinin numarasi verilirse cakisir.
        if is_unique_violation(exc):
            raise _CONTACT_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj
