"""Ihlal kaydi (G2) — site kurallarinin somut ihlal izi.

`site_kurali` YALNIZ metin tutar (kural listesi); bu tablo "kural cignendi"
olayini izler: baslik + serbest konum metni + tespit kaynagi (kamera|manuel|
devriye) + is akisi durumu. Ana ekran sayaci `?durum=yeni`.

Durum akisi:  yeni -> inceleniyor -> kapatildi
  * `kapatildi` TERMINAL: kapali kayit yeniden acilmaz (409).
  * KAPATMA YALNIZ admin — inceleyen personel kendi kaydini kapatamaz
    (dort-goz kurali; gorev talimati). security 'inceleniyor'a alabilir.
  * Ayni duruma tekrar gecis IDEMPOTENT'tir (200, kayit degismez).

RBAC (auth.md §4): YAZMA (kayit + durum) admin + security; OKUMA admin +
yonetici + security (yonetim ihlal panosunu gorur ama kayit acmaz/kapatmaz —
kapatma admin'de). resident + tesis_gorevlisi ERISMEZ (403): ihlal kaydi
komsu davranisi hakkinda veri tasir (KVKK), sakine gosterilmez.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Violation
from ..schemas import (
    ViolationCreate,
    ViolationDurum,
    ViolationListResponse,
    ViolationOut,
    ViolationUpdate,
)

router = APIRouter(prefix="/violations", tags=["violations"])

_WRITER = require_role("admin", "security")
_READER = require_role("admin", "yonetici", "security")
# Kapatma YALNIZ admin (dort-goz).
_KAPATABILEN = {"admin"}


def _out(row) -> ViolationOut:
    obj, olusturan_ad = row
    out = ViolationOut.model_validate(obj)
    out.olusturan_ad = olusturan_ad
    return out


def _base_stmt():
    return select(Violation, AppUser.ad).join(
        AppUser, AppUser.id == Violation.olusturan_user_id
    )


# ------------------------------- kayit -------------------------------------- #
@router.post("", response_model=ViolationOut, status_code=201)
async def create_violation(
    body: ViolationCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> ViolationOut:
    obj = Violation(
        tenant_id=user.tenant_id,
        olusturan_user_id=user.id,
        **body.model_dump(),
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)

    await audit_user(
        db, user, Action.VIOLATION_CREATE, resource_type="violation",
        resource_id=obj.id, meta={"kaynak": obj.kaynak},
    )
    return _out((obj, user.ad))


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=ViolationListResponse)
async def list_violations(
    durum: ViolationDurum | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> ViolationListResponse:
    """Ana ekran sayaci: `?durum=yeni&limit=1` -> `meta.total`."""
    stmt = _base_stmt()
    if durum is not None:
        stmt = stmt.where(Violation.durum == durum)

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            stmt.order_by(Violation.created_at.desc(), Violation.id.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return ViolationListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r) for r in rows],
    )


@router.get("/{violation_id}", response_model=ViolationOut)
async def get_violation(
    violation_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> ViolationOut:
    row = (await db.execute(_base_stmt().where(Violation.id == violation_id))).first()
    if row is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    return _out(row)


# ---------------------------- durum gecisi ---------------------------------- #
@router.patch("/{violation_id}", response_model=ViolationOut)
async def update_violation(
    violation_id: uuid.UUID,
    body: ViolationUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> ViolationOut:
    """yeni -> inceleniyor -> kapatildi. Kapatma YALNIZ admin (403); kapali
    kayit yeniden acilmaz (409). Ayni duruma gecis idempotent."""
    obj = (
        await db.execute(select(Violation).where(Violation.id == violation_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")

    hedef = body.durum
    if hedef == obj.durum:
        row = (
            await db.execute(_base_stmt().where(Violation.id == violation_id))
        ).first()
        return _out(row)

    # Terminal durum: kapali kayit yeniden acilmaz (denetim izi bozulmasin).
    if obj.durum == "kapatildi":
        raise APIError(409, "conflict", "ihlal_yeniden_acilamaz")
    # Kapatma yetkisi: dort-goz kurali — kaydi acan/inceleyen kapatamaz.
    if hedef == "kapatildi" and user.role not in _KAPATABILEN:
        raise APIError(403, "forbidden", "ihlal_yalniz_admin_kapatir")

    obj.durum = hedef
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)

    await audit_user(
        db, user, Action.VIOLATION_UPDATE, resource_type="violation",
        resource_id=obj.id, meta={"durum": hedef},
    )
    olusturan_ad = (
        await db.execute(select(AppUser.ad).where(AppUser.id == obj.olusturan_user_id))
    ).scalar_one_or_none()
    return _out((obj, olusturan_ad))
