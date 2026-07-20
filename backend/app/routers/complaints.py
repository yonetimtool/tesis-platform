"""Sikayet/oneri — tesiste yasayan/calisandan yonetime talep kanali.

RBAC (auth.md §4, canli test kesin kurali): ACMA security + tesis_gorevlisi +
resident (acan token'dan); yonetici ve admin ACAMAZ. OKUMA acan roller YALNIZ
kendi actiklarini, admin+yonetici tenant'taki TUMUNU (yonetim gorunumu);
YANIT/DURUM (PATCH) yalniz admin+yonetici. tenant token'dan; RLS izole.

Opsiyonel gorsel: acmada /uploads/presign ile yuklenmis foto_key kabul edilir
(tenant-namespace dogrulamali); okumada presigned GET foto_url doner.

Acmada admin+yonetici cihazlarina push denenir; yonetici yanitinda push
YALNIZ talebi acan sakine gider (kisi hedefli). Ikisi de EK gonderim —
hatasi talep kaydini kirmaz (duyuru ile ayni desen).
"""
from __future__ import annotations

import uuid
from typing import Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Complaint
from ..scheduler.notify import dispatch_external
from ..schemas import (
    ComplaintCreate,
    ComplaintDurum,
    ComplaintListResponse,
    ComplaintOut,
)
from ..storage import presign_get

router = APIRouter(prefix="/complaints", tags=["complaints"])

# Task 3 removed ComplaintKategori/ComplaintUpdate from app.schemas (Complaint
# reshape). This whole router is rewritten in Task 5 against the new model
# (kategori_id, foto_keys, durum lifecycle, convert/resolve/decline). These
# local stubs exist ONLY so the app keeps booting until then — do not build on
# them.
ComplaintKategori = Literal["gurultu", "goruntu", "diger"]


class ComplaintUpdate(BaseModel):
    durum: ComplaintDurum | None = None
    yonetici_yaniti: str | None = None


# ACMA: saha rolleri + sakin (talebi YASAYAN acar). yonetici ACAMAZ —
# kanalin cevaplayan tarafi; admin de acmaz (platform operatoru, tesiste
# yasamaz/calismaz — canli test kesin kurali, auth.md §4).
_OPENER = require_role("security", "tesis_gorevlisi", "resident")
_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident"
)
_MANAGER = require_role("admin", "yonetici")

# Kendi-kaydi kapsamindaki roller (yonetim DISI): yalniz actiklarini gorur.
_OWN_SCOPED_ROLES = ("security", "tesis_gorevlisi", "resident")

# Yeni talep push'u YONETIME gider (kanal sakin->yonetim; duyuru deseni).
_MANAGEMENT_ROLES: tuple[str, ...] = ("admin", "yonetici")


def _validate_foto_key(foto_key: str | None, tenant_id: uuid.UUID) -> None:
    """foto_key kendi tenant namespace'inde olmali (make_foto_key oneki).

    Okumada bu anahtara presigned GET imzalanir — dogrulanmazsa baska
    tenant'in objesi talep gorseli diye sizdirilabilir (IDOR).
    """
    if foto_key is not None and not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key tenant alani disinda")


def _out(obj: Complaint, acan_ad: str | None) -> ComplaintOut:
    out = ComplaintOut.model_validate(obj)
    out.acan_ad = acan_ad
    if obj.foto_key:
        try:
            out.foto_url = presign_get(obj.foto_key)
        except APIError:
            # Depo yapilandirilmamissa okuma akisi kirilmasin; foto_url bos kalir.
            out.foto_url = None
    return out


def _own_scope(stmt, user: AppUser):
    """Acan roller (saha + sakin) yalniz KENDI actiklarini gorur;
    yonetim (admin+yonetici) tum tenant'i."""
    if user.role in _OWN_SCOPED_ROLES:
        return stmt.where(Complaint.acan_user_id == user.id)
    return stmt


@router.get("", response_model=ComplaintListResponse)
async def list_complaints(
    durum: ComplaintDurum | None = Query(None),
    kategori: ComplaintKategori | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> ComplaintListResponse:
    stmt = select(Complaint, AppUser.ad).join(
        AppUser, AppUser.id == Complaint.acan_user_id
    )
    if durum is not None:
        stmt = stmt.where(Complaint.durum == durum)
    if kategori is not None:
        stmt = stmt.where(Complaint.kategori == kategori)
    stmt = _own_scope(stmt, user)

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            stmt.order_by(Complaint.created_at.desc()).limit(limit).offset(offset)
        )
    ).all()
    return ComplaintListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(c, ad) for c, ad in rows],
    )


@router.get("/{complaint_id}", response_model=ComplaintOut)
async def get_complaint(
    complaint_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> ComplaintOut:
    row = (
        await db.execute(
            _own_scope(
                select(Complaint, AppUser.ad)
                .join(AppUser, AppUser.id == Complaint.acan_user_id)
                .where(Complaint.id == complaint_id),
                user,
            )
        )
    ).first()
    if row is None:
        # Baskasinin talebi resident'a 404 — varligi da sizdirilmaz.
        raise APIError(404, "not_found", "Kayit bulunamadi")
    obj, ad = row
    return _out(obj, ad)


@router.post("", response_model=ComplaintOut, status_code=201)
async def create_complaint(
    body: ComplaintCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OPENER),
) -> ComplaintOut:
    _validate_foto_key(body.foto_key, user.tenant_id)
    obj = Complaint(
        tenant_id=user.tenant_id,
        acan_user_id=user.id,
        baslik=body.baslik,
        mesaj=body.mesaj,
        kategori=body.kategori,
        foto_key=body.foto_key,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # EK push: yeni talep yonetime bildirilir (hatasi talep kaydini kirmaz,
    # duyuru ile ayni desen).
    dispatch_external(
        f"Yeni talep: {body.baslik}",
        tenant_id=user.tenant_id,
        target_roles=_MANAGEMENT_ROLES,
        title="Sikayet/Oneri",
        data={"tip": "talep", "complaint_id": str(obj.id)},
    )
    return _out(obj, user.ad)


@router.patch("/{complaint_id}", response_model=ComplaintOut)
async def update_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> ComplaintOut:
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise APIError(422, "empty_update", "durum veya yonetici_yaniti gerekli")

    row = (
        await db.execute(
            select(Complaint, AppUser.ad)
            .join(AppUser, AppUser.id == Complaint.acan_user_id)
            .where(Complaint.id == complaint_id)
        )
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    obj, acan_ad = row

    yanitlandi = False
    if "durum" in payload and payload["durum"] is not None:
        obj.durum = payload["durum"]
    if "yonetici_yaniti" in payload:
        obj.yonetici_yaniti = payload["yonetici_yaniti"]
        # Yanit kim tarafindan/ne zaman — otomatik damgalanir.
        obj.yanitlayan_user_id = user.id
        obj.yanit_zamani = func.now()
        yanitlandi = obj.yonetici_yaniti is not None
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    if yanitlandi:
        # EK push: yanit YALNIZ talebi acan sakine gider (kisi hedefli —
        # tenant'taki diger sakinlere sizmaz); hatasi kaydi kirmaz.
        dispatch_external(
            f"Talebiniz yanitlandi: {obj.baslik}",
            tenant_id=user.tenant_id,
            target_user_ids=(obj.acan_user_id,),
            title="Sikayet/Oneri",
            data={"tip": "talep_yanit", "complaint_id": str(obj.id)},
        )
    return _out(obj, acan_ad)
