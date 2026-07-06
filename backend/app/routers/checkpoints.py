"""Checkpoint CRUD + SDM anahtar kaydi — /contracts/openapi.yaml + RBAC (auth.md §4).

nfc_tag_uid tenant icinde benzersiz (uq_checkpoint_tenant_nfc) — cakismada 409.
RBAC: GET admin/security/cleaning; POST/PATCH/DELETE ve sdm-key yalniz admin.
SDM anahtari SDM_KEK ile sifreli saklanir ve HICBIR response'ta donmez.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Checkpoint
from ..nfc_sdm import encrypt_key
from ..schemas import (
    CheckpointCreate,
    CheckpointListResponse,
    CheckpointOut,
    CheckpointUpdate,
    SdmKeyUpdate,
)

router = APIRouter(prefix="/checkpoints", tags=["checkpoints"])

_ADMIN = require_role("admin")
_READER = require_role("admin", "security", "cleaning")

_NFC_CONFLICT = APIError(409, "conflict", "nfc_tag_uid bu tenant'ta zaten kayitli.")


@router.get("", response_model=CheckpointListResponse)
async def list_checkpoints(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    aktif: bool | None = Query(None),
    nfc_tag_uid: str | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> CheckpointListResponse:
    where = []
    if aktif is not None:
        where.append(Checkpoint.aktif == aktif)
    if nfc_tag_uid is not None:
        where.append(Checkpoint.nfc_tag_uid == nfc_tag_uid)
    total = (
        await db.execute(select(func.count()).select_from(Checkpoint).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(Checkpoint).where(*where).order_by(Checkpoint.created_at).limit(limit).offset(offset)
        )
    ).scalars().all()
    return CheckpointListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=list(rows),
    )


@router.get("/{checkpoint_id}", response_model=CheckpointOut)
async def get_checkpoint(
    checkpoint_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> Checkpoint:
    return await get_or_404(db, Checkpoint, checkpoint_id)


@router.post("", response_model=CheckpointOut, status_code=201)
async def create_checkpoint(
    body: CheckpointCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> Checkpoint:
    obj = Checkpoint(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise _conflict_or_translate(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{checkpoint_id}", response_model=CheckpointOut)
async def update_checkpoint(
    checkpoint_id: uuid.UUID,
    body: CheckpointUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Checkpoint:
    obj = await get_or_404(db, Checkpoint, checkpoint_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise _conflict_or_translate(exc)
    await db.refresh(obj)
    return obj


@router.put("/{checkpoint_id}/sdm-key", response_model=CheckpointOut)
async def set_sdm_key(
    checkpoint_id: uuid.UUID,
    body: SdmKeyUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Checkpoint:
    """NTAG424 SDM anahtarini kaydet ({key: 32 hex}) veya kapat ({key: null}).

    Yeni anahtar = yeni/yeniden provision edilmis etiket varsayimi -> sayac 0'lanir.
    Anahtar HICBIR response'ta geri donmez (yalniz sdm_aktif gorunur).
    """
    obj = await get_or_404(db, Checkpoint, checkpoint_id)
    if body.key is None:
        obj.sdm_key_sifreli = None
    else:
        if not settings.sdm_kek or len(settings.sdm_kek) < 32:
            raise APIError(
                500, "config_error",
                "SDM_KEK yapilandirilmamis (32+ karakter env) — anahtar kaydi reddedildi.",
            )
        obj.sdm_key_sifreli = encrypt_key(bytes.fromhex(body.key), settings.sdm_kek)
    obj.sdm_son_sayac = 0
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    return obj


@router.delete("/{checkpoint_id}", status_code=204)
async def delete_checkpoint(
    checkpoint_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Response:
    obj = await get_or_404(db, Checkpoint, checkpoint_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        # scan_event RESTRICT vb. -> 409
        raise translate_integrity(exc)
    return Response(status_code=204)


def _conflict_or_translate(exc: IntegrityError) -> APIError:
    api = translate_integrity(exc)
    # nfc benzersizlik ihlalini daha anlamli mesajla don
    if api.status_code == 409:
        return _NFC_CONFLICT
    return api
