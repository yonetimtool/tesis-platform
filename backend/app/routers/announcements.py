"""Duyuru — yonetimden tum tesise — /contracts/openapi.yaml.

RBAC (auth.md §4): OLUSTURMA yonetici (mobil) + admin (platform/panel);
duzenleme/silme admin+yonetici; OKUMA tum roller
(resident dahil — sakinin ilk operasyon-disi kaynagi). tenant token'dan; RLS
izole. Olusturmada tenant'in TUM aktif cihazlarina push denenir (EK gonderim —
hatasi duyuru kaydini kirmaz).

Opsiyonel gorsel: olusturmada /uploads/presign ile yuklenmis foto_key kabul
edilir; okumada goruntuleme icin kisa omurlu presigned GET foto_url doner.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import Announcement, AppUser
from ..scheduler.notify import dispatch_external
from ..storage import presign_get
from ..schemas import (
    AnnouncementCreate,
    AnnouncementListResponse,
    AnnouncementOut,
    AnnouncementUpdate,
)

router = APIRouter(prefix="/announcements", tags=["announcements"])

# OLUSTURMA: yonetici (site yonetiminin agzi, mobil) + admin (platform
# tarafi, panel) — canli test kesin kurali, auth.md §4. Saha rolleri +
# resident 403. Duzenleme/silme de admin+yonetici.
_CREATOR = require_role("yonetici", "admin")
_SENDER = require_role("admin", "yonetici")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")

# Duyuru push'u TUM rollere gider (okuma herkese acik oldugu icin).
_ALL_ROLES: tuple[str, ...] = (
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
)


def _validate_foto_key(foto_key: str | None, tenant_id: uuid.UUID) -> None:
    """foto_key kendi tenant namespace'inde olmali (make_foto_key oneki).

    Okumada bu anahtara presigned GET imzalanir — dogrulanmazsa baska
    tenant'in objesi duyuru gorseli diye sizdirilabilir (IDOR).
    """
    if foto_key is not None and not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key tenant alani disinda")


def _out(obj: Announcement, olusturan_ad: str | None) -> AnnouncementOut:
    out = AnnouncementOut.model_validate(obj)
    out.olusturan_ad = olusturan_ad
    if obj.foto_key:
        try:
            out.foto_url = presign_get(obj.foto_key)
        except APIError:
            # Depo yapilandirilmamissa okuma akisi kirilmasin; foto_url bos kalir.
            out.foto_url = None
    return out


@router.get("", response_model=AnnouncementListResponse)
async def list_announcements(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> AnnouncementListResponse:
    total = (
        await db.execute(select(func.count()).select_from(Announcement))
    ).scalar_one()
    rows = (
        await db.execute(
            select(Announcement, AppUser.ad)
            .join(AppUser, AppUser.id == Announcement.olusturan_user_id)
            .order_by(Announcement.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return AnnouncementListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(a, ad) for a, ad in rows],
    )


@router.get("/{announcement_id}", response_model=AnnouncementOut)
async def get_announcement(
    announcement_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> AnnouncementOut:
    obj = await get_or_404(db, Announcement, announcement_id)
    ad = (
        await db.execute(select(AppUser.ad).where(AppUser.id == obj.olusturan_user_id))
    ).scalar_one_or_none()
    return _out(obj, ad)


@router.post("", response_model=AnnouncementOut, status_code=201)
async def create_announcement(
    body: AnnouncementCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_CREATOR),
) -> AnnouncementOut:
    _validate_foto_key(body.foto_key, user.tenant_id)
    obj = Announcement(
        tenant_id=user.tenant_id,
        baslik=body.baslik,
        govde=body.govde,
        foto_key=body.foto_key,
        olusturan_user_id=user.id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # EK push (in-app kaydi duyurunun kendisi; push hatasi akisi kirmaz).
    dispatch_external(
        body.baslik,
        tenant_id=user.tenant_id,
        target_roles=_ALL_ROLES,
        title="Duyuru",
        data={"tip": "duyuru", "announcement_id": str(obj.id)},
    )
    return _out(obj, user.ad)


@router.patch("/{announcement_id}", response_model=AnnouncementOut)
async def update_announcement(
    announcement_id: uuid.UUID,
    body: AnnouncementUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_SENDER),
) -> AnnouncementOut:
    _validate_foto_key(body.foto_key, user.tenant_id)
    obj = await get_or_404(db, Announcement, announcement_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    ad = (
        await db.execute(select(AppUser.ad).where(AppUser.id == obj.olusturan_user_id))
    ).scalar_one_or_none()
    return _out(obj, ad)


@router.delete("/{announcement_id}", status_code=204)
async def delete_announcement(
    announcement_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_SENDER),
) -> Response:
    obj = await get_or_404(db, Announcement, announcement_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)
