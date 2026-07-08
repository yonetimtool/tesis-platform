"""GET /notifications + PATCH /notifications/{id} — /contracts/openapi.yaml.

RBAC (auth.md §4): admin + security. tenant token'dan; RLS izole.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..models import AppUser, Notification
from ..schemas import NotificationListResponse, NotificationOut, NotificationUpdate

router = APIRouter(prefix="/notifications", tags=["notifications"])

_VIEWER = require_role("admin", "yonetici", "security")


@router.get("", response_model=NotificationListResponse)
async def list_notifications(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    okundu: bool | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_VIEWER),
) -> NotificationListResponse:
    where = [] if okundu is None else [Notification.okundu == okundu]
    total = (
        await db.execute(select(func.count()).select_from(Notification).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(Notification)
            .where(*where)
            .order_by(Notification.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    return NotificationListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=list(rows),
    )


@router.patch("/{notification_id}", response_model=NotificationOut)
async def update_notification(
    notification_id: uuid.UUID,
    body: NotificationUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_VIEWER),
) -> Notification:
    obj = await get_or_404(db, Notification, notification_id)
    obj.okundu = body.okundu
    await db.flush()
    await db.refresh(obj)
    return obj
