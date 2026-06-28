"""POST /scans — tur kaniti alimi (idempotent) — /contracts/openapi.yaml.

RBAC (auth.md §4): admin/security/cleaning gonderebilir; resident -> 403.
tenant + guard_id token'dan turetilir (istekten ALINMAZ).

Idempotency (offline outbox cift gonderimi):
  * Idempotency-Key header ZORUNLU; yoksa 400.
  * UNIQUE(tenant_id, idempotency_key) -> ayni key + ayni govde => mevcut kayit 200;
    ayni key + FARKLI govde => 409. Race-safe: SAVEPOINT (begin_nested) ile INSERT
    denenir; unique ihlalinde mevcut kayit okunup govde karsilastirilir.

Pencere durum gecisi BURADA YAPILMAZ — bu scheduler'in detect task'inin isidir
(tek sorumluluk). Burada yalnizca scan dogru kaydedilir; patrol_window_id verildiyse
dogrulanir, verilmediyse scheduler zaman-tabanli eslestirir (bkz. README scheduler).
"""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header
from fastapi.responses import JSONResponse
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Checkpoint, PatrolWindow, ScanEvent
from ..schemas import ScanCreate, ScanEventOut

router = APIRouter(prefix="/scans", tags=["scans"])

_SCANNER = require_role("admin", "security", "cleaning")


def _is_unique_violation(exc: IntegrityError) -> bool:
    orig = getattr(exc, "orig", None)
    code = getattr(orig, "sqlstate", None) or getattr(orig, "pgcode", None)
    return code == "23505"


def _coord_eq(a, b) -> bool:
    if a is None or b is None:
        return a is b
    return round(float(a), 6) == round(float(b), 6)


def _same_request(existing: ScanEvent, *, guard_id, checkpoint_id, patrol_window_id,
                  nfc_tag_uid, okutma_zamani, gps_lat, gps_lng, foto_url, imza_dogrulandi) -> bool:
    """Idempotent tekrar mi (ayni govde) yoksa cakisma mi (farkli govde)?"""
    return (
        existing.guard_id == guard_id
        and existing.checkpoint_id == checkpoint_id
        and existing.patrol_window_id == patrol_window_id
        and existing.nfc_tag_uid == nfc_tag_uid
        and existing.okutma_zamani == okutma_zamani
        and _coord_eq(existing.gps_lat, gps_lat)
        and _coord_eq(existing.gps_lng, gps_lng)
        and existing.foto_url == foto_url
        and existing.imza_dogrulandi == imza_dogrulandi
    )


@router.post("")
async def create_scan(
    body: ScanCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_SCANNER),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "Idempotency-Key header zorunlu.")

    # 1) nfc_tag_uid -> checkpoint (RLS ile tenant-scoped). Capraz-tenant/bilinmeyen -> 404.
    checkpoint = (
        await db.execute(select(Checkpoint).where(Checkpoint.nfc_tag_uid == body.nfc_tag_uid))
    ).scalar_one_or_none()
    if checkpoint is None:
        raise APIError(404, "not_found", "nfc_tag_uid hicbir checkpoint ile eslesmedi.")
    if body.checkpoint_id is not None and body.checkpoint_id != checkpoint.id:
        raise APIError(422, "invalid_reference", "checkpoint_id nfc_tag_uid ile eslesmiyor.")

    # 2) patrol_window_id verildiyse dogrula (durum DEGISTIRILMEZ — scheduler isi).
    if body.patrol_window_id is not None:
        exists = (
            await db.execute(
                select(PatrolWindow.id).where(PatrolWindow.id == body.patrol_window_id)
            )
        ).scalar_one_or_none()
        if exists is None:
            raise APIError(422, "invalid_reference", "patrol_window_id bu tenant'ta bulunamadi.")

    okutma = body.okutma_zamani
    if okutma.tzinfo is None:  # zamanlar UTC (konvansiyon)
        okutma = okutma.replace(tzinfo=timezone.utc)

    obj = ScanEvent(
        tenant_id=user.tenant_id,
        guard_id=user.id,
        checkpoint_id=checkpoint.id,
        patrol_window_id=body.patrol_window_id,
        nfc_tag_uid=body.nfc_tag_uid,
        okutma_zamani=okutma,
        gps_lat=body.gps_lat,
        gps_lng=body.gps_lng,
        foto_url=body.foto_url,
        imza_dogrulandi=body.imza_dogrulandi,  # gercek kripto dogrulama bu promptta YOK
        idempotency_key=idempotency_key,
    )

    # 3) race-safe insert (SAVEPOINT). Unique ihlalinde idempotent yola gec.
    created = True
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        if not _is_unique_violation(exc):
            raise translate_integrity(exc)
        created = False
        try:
            db.expunge(obj)
        except Exception:
            pass

    if created:
        await db.refresh(obj)
        return JSONResponse(
            status_code=201, content=ScanEventOut.model_validate(obj).model_dump(mode="json")
        )

    # idempotent tekrar: mevcut kaydi getir, govdeyi karsilastir
    existing = (
        await db.execute(select(ScanEvent).where(ScanEvent.idempotency_key == idempotency_key))
    ).scalar_one()
    if _same_request(
        existing,
        guard_id=user.id,
        checkpoint_id=checkpoint.id,
        patrol_window_id=body.patrol_window_id,
        nfc_tag_uid=body.nfc_tag_uid,
        okutma_zamani=okutma,
        gps_lat=body.gps_lat,
        gps_lng=body.gps_lng,
        foto_url=body.foto_url,
        imza_dogrulandi=body.imza_dogrulandi,
    ):
        return JSONResponse(
            status_code=200, content=ScanEventOut.model_validate(existing).model_dump(mode="json")
        )
    raise APIError(409, "conflict", "Ayni Idempotency-Key farkli govde ile gonderildi.")
