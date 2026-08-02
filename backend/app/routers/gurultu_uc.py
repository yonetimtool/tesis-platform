"""Gurultu caydirici uclari (P37) — uyari kayitlari + manuel isaretleme.

Sikayet acma ucundan AYRI: caydirici bir sikayetin alt-ozelligi degil,
kendi gecmisi olan bir eylemdir ("bu daireye ne zaman, hangi sayacla,
hangi metinle uyari verildi").
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..gurultu_akisi import kuyrugu_isle
from ..models import AppUser, Unit, UnitUyari
from ..schemas import UnitUyariListResponse, UnitUyariOut

router = APIRouter(prefix="/unit-uyarilari", tags=["gurultu"])

# Uyari kaydi KOMSU DAVRANISI hakkinda veri tasir (P24 ile ayni gerekce):
# yalniz yonetim gorur.
_MANAGER = require_role("admin", "yonetici")


@router.get("", response_model=UnitUyariListResponse)
async def liste(
    unit_id: uuid.UUID | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> UnitUyariListResponse:
    kosul = [UnitUyari.unit_id == unit_id] if unit_id else []
    total = (
        await db.execute(
            select(func.count()).select_from(UnitUyari).where(*kosul)
        )
    ).scalar_one()
    rows = (
        await db.execute(
            select(UnitUyari, Unit.no)
            .join(Unit, Unit.id == UnitUyari.unit_id)
            .where(*kosul)
            .order_by(UnitUyari.created_at.desc(), UnitUyari.id.desc())
            .limit(limit).offset(offset)
        )
    ).all()
    return UnitUyariListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            UnitUyariOut.model_validate(u).model_copy(update={"unit_no": no})
            for u, no in rows
        ],
    )


@router.post("/{uyari_id}/yapildi", response_model=UnitUyariOut)
async def manuel_yapildi(
    uyari_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> UnitUyariOut:
    """Manuel modda anonsun YAPILDIGINI isaretle.

    SUNUCU BUNU KENDILIGINDEN VARSAYAMAZ: anonsun gercekten yapilip
    yapilmadigini yalniz insan bilir. Isaretlenmeyen kayit `manuel_bekliyor`
    olarak DURUR — sessizce "yapildi" saymak, denetimde yapilmamis bir isi
    yapilmis gostermek olurdu.
    """
    obj = await get_or_404(db, UnitUyari, uyari_id)
    if obj.durum not in ("manuel_bekliyor", "basarisiz"):
        raise APIError(409, "conflict", "uyari_manuel_beklemiyor")
    obj.durum = "manuel_yapildi"
    obj.son_deneme_at = datetime.now(tz=timezone.utc)
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.UYARI_MANUEL, resource_type="unit_uyari",
        resource_id=obj.id, meta={"unit_id": str(obj.unit_id)},
    )
    no = (
        await db.execute(select(Unit.no).where(Unit.id == obj.unit_id))
    ).scalar_one_or_none()
    return UnitUyariOut.model_validate(obj).model_copy(update={"unit_no": no})


@router.post("/kuyruk-isle", response_model=dict)
async def kuyruk(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(require_role("admin")),
) -> dict:
    """Basarisiz webhook uyarilarini ELLE yeniden dene (operasyon/test).

    Normalde bunu zamanlanmis gorev yapar; bu uc, beat'i beklemeden
    dogrulamak icindir (scheduler'in `--once` bayragiyla ayni gerekce).
    """
    return {"islenen": await kuyrugu_isle(db)}
