"""Kamera MVP (WP-F) — site kamera yayin URL'leri CRUD.

RBAC (auth.md §4): GET admin/yonetici/security (KVKK: tesis_gorevlisi ve
resident kamera GORMEZ); yazma admin/yonetici. Backend yayini HIC cekmez
(istemci oynatir) — SSRF yuzeyi yok; URL semasi http(s) ile sinirli.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..models import AppUser, Camera
from ..schemas import CameraCreate, CameraListResponse, CameraOut, CameraUpdate

router = APIRouter(prefix="/cameras", tags=["cameras"])

_READER = require_role("admin", "yonetici", "security")
_WRITER = require_role("admin", "yonetici")


@router.get("", response_model=CameraListResponse)
async def list_cameras(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> CameraListResponse:
    total = (await db.execute(select(func.count()).select_from(Camera))).scalar_one()
    rows = (
        await db.execute(select(Camera).order_by(Camera.ad).limit(limit).offset(offset))
    ).scalars().all()
    return CameraListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=list(rows)
    )


@router.post("", response_model=CameraOut, status_code=201)
async def create_camera(
    body: CameraCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Camera:
    obj = Camera(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.CAMERA_CREATE, resource_type="camera",
                     resource_id=obj.id, meta={"ad": obj.ad})
    await db.refresh(obj)
    return obj


@router.patch("/{camera_id}", response_model=CameraOut)
async def update_camera(
    camera_id: uuid.UUID,
    body: CameraUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Camera:
    obj = await get_or_404(db, Camera, camera_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.CAMERA_UPDATE, resource_type="camera",
                     resource_id=obj.id)
    await db.refresh(obj)
    return obj


@router.delete("/{camera_id}", status_code=204)
async def delete_camera(
    camera_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Response:
    obj = await get_or_404(db, Camera, camera_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(db, user, Action.CAMERA_DELETE, resource_type="camera",
                     resource_id=camera_id)
    return Response(status_code=204)
