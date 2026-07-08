"""GET /landscape/schedule — peyzaj bakim takvimi.

Ayri model YOK: tip='peyzaj' task'lari, sonraki_planlanan'a gore ARTAN sirada.
Mevcut Task semasi yeniden kullanilir. RBAC: admin/security/tesis_gorevlisi (okuma).
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..models import AppUser, Task
from ..schemas import TaskListResponse

router = APIRouter(prefix="/landscape", tags=["tasks"])

_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")


@router.get("/schedule", response_model=TaskListResponse)
async def landscape_schedule(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> TaskListResponse:
    where = [
        Task.tip == "peyzaj",
        Task.aktif.is_(True),
        Task.sonraki_planlanan.is_not(None),
    ]
    total = (await db.execute(select(func.count()).select_from(Task).where(*where))).scalar_one()
    rows = (
        await db.execute(
            select(Task).where(*where).order_by(Task.sonraki_planlanan).limit(limit).offset(offset)
        )
    ).scalars().all()
    return TaskListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=list(rows))
