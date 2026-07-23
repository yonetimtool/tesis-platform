"""GET /audit — admin (platform) capraz-tenant denetim goruntuleyici (WP1).

RLS FORCE oldugundan app_rw yalniz kendi tenant'ini gorur; bu uc, owner-sahipli
SECURITY DEFINER `audit_log_list` fonksiyonuyla TUM tenant'lari (istege bagli
filtreyle) doner (mevcut list_all_tenants deseni). YALNIZ admin (yonetici DEGIL).
Bare session (set_tenant YOK) kullanilir — RLS bypass fonksiyonun icindedir.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text

from ..db import SessionLocal
from ..deps import require_role
from ..models import AppUser
from ..schemas import AuditLogListResponse, AuditLogOut

router = APIRouter(prefix="/audit", tags=["audit"])

_ADMIN = require_role("admin")

_QUERY = text(
    "SELECT * FROM public.audit_log_list("
    ":tid, :action, :rtype, :dfrom, :dto, :lim, :off)"
)


@router.get("", response_model=AuditLogListResponse)
async def list_audit(
    tenant_id: uuid.UUID | None = Query(None, description="tenant filtresi (opsiyonel)"),
    action: str | None = Query(None),
    resource_type: str | None = Query(None),
    date_from: datetime | None = Query(None, alias="from"),
    date_to: datetime | None = Query(None, alias="to"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    _: AppUser = Depends(_ADMIN),
) -> AuditLogListResponse:
    async with SessionLocal() as session:
        async with session.begin():
            rows = (
                await session.execute(
                    _QUERY,
                    {
                        "tid": tenant_id,
                        "action": action,
                        "rtype": resource_type,
                        "dfrom": date_from,
                        "dto": date_to,
                        "lim": limit,
                        "off": offset,
                    },
                )
            ).mappings().all()
    total = int(rows[0]["total"]) if rows else 0
    items = [
        AuditLogOut(
            id=r["id"],
            ts=r["ts"],
            tenant_id=r["tenant_id"],
            actor_user_id=r["actor_user_id"],
            actor_rol=r["actor_rol"],
            action=r["action"],
            resource_type=r["resource_type"],
            resource_id=r["resource_id"],
            meta=r["meta"] or {},
        )
        for r in rows
    ]
    return AuditLogListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=items
    )
