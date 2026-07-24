"""Platform destek kanali (WP1) — yonetici -> Yonetio ekibi.

RBAC (auth.md §4 eki):
  * POST /support        YALNIZ yonetici (kendi tenant'inda bilet acar).
  * GET  /support        YALNIZ yonetici (kendi tenant biletleri — RLS).
  * GET  /support/all    YALNIZ admin — TUM tenant'lar (SECURITY DEFINER
                         `support_ticket_list`, audit_log_list deseni).
  * PATCH /support/{id}  YALNIZ admin — durum + admin_cevap (SECURITY
                         DEFINER `support_ticket_answer`; yoksa 404).
Denetim: create + update audit_log'a yazilir (ayni tx; KVKK — meta'da
yalniz id/alan adi, metin DEGERI yok).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import audit_user
from ..db import SessionLocal
from ..deps import get_tenant_db, require_role
from ..models import AppUser, PlatformSupportTicket
from ..schemas import (
    SupportTicketAdminListResponse,
    SupportTicketAdminOut,
    SupportTicketCreate,
    SupportTicketListResponse,
    SupportTicketOut,
    SupportTicketUpdate,
)

router = APIRouter(prefix="/support", tags=["support"])

_YONETICI = require_role("yonetici")
_ADMIN = require_role("admin")

_LIST_ALL_SQL = text(
    "SELECT * FROM public.support_ticket_list(:tid, :durum, :lim, :off)"
)
_ANSWER_SQL = text(
    "SELECT * FROM public.support_ticket_answer(:id, :durum, :cevap)"
)


@router.post("", response_model=SupportTicketOut, status_code=201)
async def create_ticket(
    body: SupportTicketCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETICI),
) -> PlatformSupportTicket:
    obj = PlatformSupportTicket(
        tenant_id=user.tenant_id,
        acan_user_id=user.id,
        konu=body.konu,
        aciklama=body.aciklama,
    )
    db.add(obj)
    await db.flush()
    await audit_user(
        db, user, "support_ticket_create",
        resource_type="support_ticket", resource_id=obj.id,
    )
    await db.refresh(obj)
    return obj


@router.get("", response_model=SupportTicketListResponse)
async def list_my_tickets(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETICI),
) -> SupportTicketListResponse:
    from sqlalchemy import func

    total = (
        await db.execute(select(func.count()).select_from(PlatformSupportTicket))
    ).scalar_one()
    rows = (
        await db.execute(
            select(PlatformSupportTicket)
            .order_by(PlatformSupportTicket.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    return SupportTicketListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=list(rows),
    )


@router.get("/all", response_model=SupportTicketAdminListResponse)
async def list_all_tickets(
    tenant_id: uuid.UUID | None = Query(None),
    durum: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    _: AppUser = Depends(_ADMIN),
) -> SupportTicketAdminListResponse:
    async with SessionLocal() as session:
        async with session.begin():
            rows = (
                await session.execute(
                    _LIST_ALL_SQL,
                    {"tid": tenant_id, "durum": durum, "lim": limit, "off": offset},
                )
            ).mappings().all()
    total = int(rows[0]["total"]) if rows else 0
    items = [SupportTicketAdminOut(**{k: r[k] for k in (
        "id", "tenant_id", "tenant_ad", "acan_user_id", "konu", "aciklama",
        "durum", "admin_cevap", "created_at", "updated_at",
    )}) for r in rows]
    return SupportTicketAdminListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=items
    )


@router.patch("/{ticket_id}", response_model=SupportTicketOut)
async def answer_ticket(
    ticket_id: uuid.UUID,
    body: SupportTicketUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> SupportTicketOut:
    if body.durum is None and body.admin_cevap is None:
        raise HTTPException(422, detail="durum veya admin_cevap gerekli")
    row = (
        await db.execute(
            _ANSWER_SQL,
            {"id": ticket_id, "durum": body.durum, "cevap": body.admin_cevap},
        )
    ).mappings().first()
    if row is None:
        raise HTTPException(404, detail="Bilet bulunamadi")
    # Denetim: aktorun (admin) tenant baglaminda; hedef bilet baska tenant'in
    # olabilir -> meta'da hedef tenant id'si (KVKK: yalniz id'ler).
    await audit_user(
        db, user, "support_ticket_update",
        resource_type="support_ticket", resource_id=ticket_id,
        meta={
            "ticket_tenant_id": str(row["tenant_id"]),
            **({"durum": body.durum} if body.durum else {}),
            **({"fields": ["admin_cevap"]} if body.admin_cevap else {}),
        },
    )
    return SupportTicketOut(**{k: row[k] for k in (
        "id", "tenant_id", "acan_user_id", "konu", "aciklama", "durum",
        "admin_cevap", "created_at", "updated_at",
    )})
