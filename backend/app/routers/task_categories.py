"""Gorev kategorisi CRUD (A6) — yonetici-tanimli, tenant'a ozel kategoriler.

RBAC (auth.md §4): yazma (POST/DELETE) admin/yonetici; okuma gorev goren
roller (admin/yonetici/security/tesis_gorevlisi) — resident 403.
DELETE SOFT-DELETE'tir (aktif=false): gorev gecmisi kategoriye referans
verebilir, hard silme kaydi koparir. tenant token'dan; RLS izole.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, TaskCategory
from ..schemas import (
    TaskCategoryCreate,
    TaskCategoryListResponse,
    TaskCategoryOut,
    TaskCategoryUpdate,
)

router = APIRouter(prefix="/task-categories", tags=["task-categories"])

_MANAGER = require_role("admin", "yonetici")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")


@router.post("", response_model=TaskCategoryOut, status_code=201)
async def create_category(
    body: TaskCategoryCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> TaskCategory:
    obj = TaskCategory(tenant_id=user.tenant_id, ad=body.ad)
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "kategori_adi_zaten_kayitli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.get("", response_model=TaskCategoryListResponse)
async def list_categories(
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    aktif: bool = Query(True, description="Varsayilan yalniz aktif kategoriler."),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> TaskCategoryListResponse:
    where = [TaskCategory.aktif == aktif]
    total = (
        await db.execute(select(func.count()).select_from(TaskCategory).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(TaskCategory).where(*where).order_by(TaskCategory.ad, TaskCategory.id).limit(limit).offset(offset)
        )
    ).scalars().all()
    return TaskCategoryListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=list(rows)
    )


@router.patch("/{category_id}", response_model=TaskCategoryOut)
async def update_category(
    category_id: uuid.UUID,
    body: TaskCategoryUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> TaskCategory:
    """(P166 §8.3) Kategoriyi DUZENLE — ad ve/veya aktiflik.

    Bu uc P166'ya kadar YOKTU. Web'de kategori ekrani acilirken ortaya
    cikti: liste/form deseni duzenleme sunuyor, sunucuda karsiligi yok —
    "Kaydet" 405 donerdi.

    AD BENZERSIZLIGI: `uq_task_category_tenant_ad` ayni tenant'ta ayni adi
    engelliyor. Cakismayi 500 yerine 409 olarak dondurmek, POST ile AYNI
    davranistir; istemci iki yolu ayri ele almak zorunda kalmaz.
    """
    obj = await get_or_404(db, TaskCategory, category_id)
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "kategori_adi_zaten_kayitli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.delete("/{category_id}", status_code=204)
async def delete_category(
    category_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> Response:
    obj = await get_or_404(db, TaskCategory, category_id)
    obj.aktif = False
    obj.updated_at = func.now()
    await db.flush()
    return Response(status_code=204)
