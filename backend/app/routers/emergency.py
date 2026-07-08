"""Acil durum (panik butonu) — POST/GET/PATCH /emergency — /contracts/openapi.yaml.

POST: saha+yonetici+admin tetikler -> emergency_alert + yuksek oncelikli 'acil_durum'
notification (idempotent). GET/PATCH(coz): admin/yonetici. Idempotency scan SAVEPOINT deseni.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, Query
from fastapi.responses import JSONResponse
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import coord_eq, get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, EmergencyAlert
from ..schemas import (
    EmergencyAlertOut,
    EmergencyCreate,
    EmergencyDurum,
    EmergencyListResponse,
    EmergencyResolve,
)
from ..scheduler.notify import dispatch_external

router = APIRouter(prefix="/emergency", tags=["emergency"])

_FIELD = require_role("admin", "yonetici", "security", "tesis_gorevlisi")
_MANAGER = require_role("admin", "yonetici")

_NOTIF_SQL = text(
    "INSERT INTO notification (tenant_id, tip, dedup_key, mesaj) "
    "VALUES (:t, 'acil_durum', :d, :m) "
    "ON CONFLICT (tenant_id, dedup_key) DO NOTHING"
)


def _same(existing: EmergencyAlert, *, tetikleyen, gps_lat, gps_lng, notlar) -> bool:
    return (
        existing.tetikleyen_user_id == tetikleyen
        and coord_eq(existing.gps_lat, gps_lat)
        and coord_eq(existing.gps_lng, gps_lng)
        and existing.notlar == notlar
    )


async def _emit_notification(db: AsyncSession, tenant_id: uuid.UUID, alert: EmergencyAlert) -> None:
    """Yuksek oncelikli acil durum bildirimi (idempotent: dedup_key=acil_durum:<alert_id>)."""
    mesaj = f"ACIL DURUM: {alert.tetiklenme_zamani.isoformat()}"
    await db.execute(
        _NOTIF_SQL, {"t": tenant_id, "d": f"acil_durum:{alert.id}", "m": mesaj}
    )
    # EK push (in-app notification'i etkilemez; hata bildirim akisini kirmaz).
    dispatch_external(
        mesaj,
        tenant_id=tenant_id,
        target_roles=("admin", "security"),
        title="ACIL DURUM",
        data={"tip": "acil_durum", "alert_id": str(alert.id)},
    )


@router.post("")
async def trigger_emergency(
    body: EmergencyCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FIELD),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "Idempotency-Key header zorunlu.")

    existing = (
        await db.execute(
            select(EmergencyAlert).where(EmergencyAlert.idempotency_key == idempotency_key)
        )
    ).scalar_one_or_none()
    if existing is not None:
        if _same(existing, tetikleyen=user.id, gps_lat=body.gps_lat, gps_lng=body.gps_lng, notlar=body.notlar):
            return JSONResponse(status_code=200, content=EmergencyAlertOut.model_validate(existing).model_dump(mode="json"))
        raise APIError(409, "conflict", "Ayni Idempotency-Key farkli govde ile gonderildi.")

    obj = EmergencyAlert(
        tenant_id=user.tenant_id,
        tetikleyen_user_id=user.id,
        gps_lat=body.gps_lat,
        gps_lng=body.gps_lng,
        notlar=body.notlar,
        idempotency_key=idempotency_key,
    )
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        try:
            db.expunge(obj)
        except Exception:
            pass
        if is_unique_violation(exc):
            again = (
                await db.execute(
                    select(EmergencyAlert).where(EmergencyAlert.idempotency_key == idempotency_key)
                )
            ).scalar_one()
            if _same(again, tetikleyen=user.id, gps_lat=body.gps_lat, gps_lng=body.gps_lng, notlar=body.notlar):
                return JSONResponse(status_code=200, content=EmergencyAlertOut.model_validate(again).model_dump(mode="json"))
            raise APIError(409, "conflict", "Ayni Idempotency-Key farkli govde ile gonderildi.")
        raise translate_integrity(exc)

    await db.refresh(obj)
    await _emit_notification(db, user.tenant_id, obj)
    return JSONResponse(status_code=201, content=EmergencyAlertOut.model_validate(obj).model_dump(mode="json"))


@router.get("", response_model=EmergencyListResponse)
async def list_emergency(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    durum: EmergencyDurum | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> EmergencyListResponse:
    where = [] if durum is None else [EmergencyAlert.durum == durum]
    total = (
        await db.execute(select(func.count()).select_from(EmergencyAlert).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(EmergencyAlert)
            .where(*where)
            .order_by(EmergencyAlert.tetiklenme_zamani.desc())
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    return EmergencyListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=list(rows))


@router.patch("/{alert_id}", response_model=EmergencyAlertOut)
async def resolve_emergency(
    alert_id: uuid.UUID,
    body: EmergencyResolve,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> EmergencyAlert:
    obj = await get_or_404(db, EmergencyAlert, alert_id)
    if obj.durum != "cozuldu":
        obj.durum = "cozuldu"
        obj.cozen_user_id = user.id
        obj.cozulme_zamani = datetime.now(tz=timezone.utc)
    if body.notlar is not None:
        obj.notlar = body.notlar
    await db.flush()
    await db.refresh(obj)
    return obj
