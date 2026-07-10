"""Site kurallari — blog-tarzi icerik: yonetici CRUD, TUM roller okur.

Akis (urun sahibi sabit):
  1. Yonetici kural ekler: baslik + icerik + opsiyonel foto + sira.
  2. Yonetici duzenler/siler; istedigi an yenisini ekler.
  3. TUM roller okur (sira'ya gore sirali blog listesi).
  4. ARAMA: `?q=` basligi SUNUCU tarafinda ILIKE ile suzer (karar) —
     buyuk/kucuk harf duyarsiz, RLS ile tenant-kapsamli (sizinti yok).

RBAC (auth.md §4): CRUD admin+yonetici (duyuru deseni); OKUMA TUM roller.
Silme HARD DELETE (karar): salt icerik — operasyonel gecmis/FK tasimaz.
Foto MEVCUT presign akisiyla (foto_key tenant-namespace dogrulanir — IDOR
korumasi; okumada kisa omurlu presigned GET foto_url). Push YOK — kurallar
duyuru degil basvuru icerigidir (urun karari).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, SiteKurali
from ..schemas import (
    SiteKuraliCreate,
    SiteKuraliListResponse,
    SiteKuraliOut,
    SiteKuraliUpdate,
)
from ..storage import presign_get

router = APIRouter(prefix="/site-rules", tags=["site-kurallari"])

_MANAGER = require_role("admin", "yonetici")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")


def _validate_foto_key(foto_key: str | None, tenant_id: uuid.UUID) -> None:
    """foto_key kendi tenant namespace'inde olmali (complaints/kargo ile ayni
    IDOR korumasi)."""
    if foto_key is not None and not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key tenant alani disinda")


def _out(obj: SiteKurali, olusturan_ad: str | None) -> SiteKuraliOut:
    out = SiteKuraliOut.model_validate(obj)
    out.olusturan_ad = olusturan_ad
    if obj.foto_key:
        try:
            out.foto_url = presign_get(obj.foto_key)
        except APIError:
            # Depo yapilandirilmamissa okuma akisi kirilmasin; foto_url bos kalir.
            out.foto_url = None
    return out


def _base_stmt():
    return select(SiteKurali, AppUser.ad).join(
        AppUser, AppUser.id == SiteKurali.olusturan_user_id
    )


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=SiteKuraliListResponse)
async def list_rules(
    q: str | None = Query(None, min_length=1, max_length=200,
                          description="Baslik aramasi (ILIKE, buyuk/kucuk harf duyarsiz)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> SiteKuraliListResponse:
    stmt = _base_stmt()
    if q is not None:
        # SUNUCU tarafi arama: ILIKE + RLS (yalniz kendi tenant'inin
        # kurallari taranir — sizinti yok). % / _ joker karakterleri
        # kacislanir: arama LITERAL metin uzerinedir.
        guvenli = q.replace("\\", "\\\\").replace("%", r"\%").replace("_", r"\_")
        stmt = stmt.where(SiteKurali.baslik.ilike(f"%{guvenli}%", escape="\\"))
    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            # Blog sirasi: sira ASC (kucuk once), esitlikte eski once.
            stmt.order_by(SiteKurali.sira, SiteKurali.created_at)
            .limit(limit).offset(offset)
        )
    ).all()
    return SiteKuraliListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(o, ad) for o, ad in rows],
    )


@router.get("/{rule_id}", response_model=SiteKuraliOut)
async def get_rule(
    rule_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> SiteKuraliOut:
    row = (
        await db.execute(_base_stmt().where(SiteKurali.id == rule_id))
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    return _out(*row)


# ------------------------------- yonetim ------------------------------------ #
@router.post("", response_model=SiteKuraliOut, status_code=201)
async def create_rule(
    body: SiteKuraliCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> SiteKuraliOut:
    _validate_foto_key(body.foto_key, user.tenant_id)
    obj = SiteKurali(
        tenant_id=user.tenant_id,
        baslik=body.baslik,
        icerik=body.icerik,
        foto_key=body.foto_key,
        sira=body.sira,
        olusturan_user_id=user.id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return _out(obj, user.ad)


@router.patch("/{rule_id}", response_model=SiteKuraliOut)
async def update_rule(
    rule_id: uuid.UUID,
    body: SiteKuraliUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> SiteKuraliOut:
    row = (
        await db.execute(_base_stmt().where(SiteKurali.id == rule_id))
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    obj, olusturan_ad = row
    payload = body.model_dump(exclude_unset=True)
    if "foto_key" in payload:
        # Acik null = gorseli kaldir; dolu deger = yeni gorsel (dogrulanir).
        _validate_foto_key(payload["foto_key"], user.tenant_id)
    for k, v in payload.items():
        setattr(obj, k, v)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return _out(obj, olusturan_ad)


@router.delete("/{rule_id}", status_code=204)
async def delete_rule(
    rule_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> Response:
    obj = (
        await db.execute(select(SiteKurali).where(SiteKurali.id == rule_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    # HARD DELETE (karar): salt icerik, FK/gecmis tasimaz.
    await db.delete(obj)
    await db.flush()
    return Response(status_code=204)
