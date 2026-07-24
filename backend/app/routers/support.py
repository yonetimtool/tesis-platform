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
from ..errors import APIError
from ..models import AppUser, PlatformSupportTicket
from ..schemas import (
    SupportTicketAdminListResponse,
    SupportTicketAdminOut,
    SupportTicketCreate,
    SupportTicketListResponse,
    SupportTicketOut,
    SupportTicketUpdate,
)
from ..storage import presign_get

router = APIRouter(prefix="/support", tags=["support"])

_YONETICI = require_role("yonetici")
_ADMIN = require_role("admin")

_LIST_ALL_SQL = text(
    "SELECT * FROM public.support_ticket_list(:tid, :durum, :lim, :off)"
)
_ANSWER_SQL = text(
    "SELECT * FROM public.support_ticket_answer(:id, :durum, :cevap, :cevap_foto)"
)


def _validate_prefix(foto_key: str | None, tenant_id: uuid.UUID) -> None:
    """Gorsel anahtari yukleyen kullanicinin tenant namespace'inde olmali
    (announcement _validate_foto_key deseni — IDOR engeli)."""
    if foto_key is not None and not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key tenant alani disinda")


def _foto_url(key: str | None) -> str | None:
    return presign_get(key) if key else None


def _ticket_out(t: PlatformSupportTicket) -> SupportTicketOut:
    """ORM bileti -> SupportTicketOut; iki gorsel URL'sini presign ile doldurur."""
    return SupportTicketOut(
        id=t.id, tenant_id=t.tenant_id, acan_user_id=t.acan_user_id,
        konu=t.konu, aciklama=t.aciklama, durum=t.durum,
        admin_cevap=t.admin_cevap,
        foto_key=t.foto_key, admin_cevap_foto_key=t.admin_cevap_foto_key,
        foto_url=_foto_url(t.foto_key),
        admin_cevap_foto_url=_foto_url(t.admin_cevap_foto_key),
        created_at=t.created_at, updated_at=t.updated_at,
    )


@router.post("", response_model=SupportTicketOut, status_code=201)
async def create_ticket(
    body: SupportTicketCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETICI),
) -> SupportTicketOut:
    _validate_prefix(body.foto_key, user.tenant_id)
    obj = PlatformSupportTicket(
        tenant_id=user.tenant_id,
        acan_user_id=user.id,
        konu=body.konu,
        aciklama=body.aciklama,
        foto_key=body.foto_key,
    )
    db.add(obj)
    await db.flush()
    await audit_user(
        db, user, "support_ticket_create",
        resource_type="support_ticket", resource_id=obj.id,
    )
    await db.refresh(obj)
    return _ticket_out(obj)


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
        items=[_ticket_out(r) for r in rows],
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
    items = [
        SupportTicketAdminOut(
            **{k: r[k] for k in (
                "id", "tenant_id", "tenant_ad", "acan_user_id", "konu",
                "aciklama", "durum", "admin_cevap", "foto_key",
                "admin_cevap_foto_key", "created_at", "updated_at",
            )},
            foto_url=_foto_url(r["foto_key"]),
            admin_cevap_foto_url=_foto_url(r["admin_cevap_foto_key"]),
        )
        for r in rows
    ]
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
    if (
        body.durum is None
        and body.admin_cevap is None
        and body.admin_cevap_foto_key is None
    ):
        raise HTTPException(422, detail="durum, admin_cevap veya foto gerekli")
    # Admin cevap gorseli admin'in KENDI tenant namespace'inde olmali (IDOR).
    _validate_prefix(body.admin_cevap_foto_key, user.tenant_id)
    row = (
        await db.execute(
            _ANSWER_SQL,
            {
                "id": ticket_id, "durum": body.durum, "cevap": body.admin_cevap,
                "cevap_foto": body.admin_cevap_foto_key,
            },
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
    return SupportTicketOut(
        **{k: row[k] for k in (
            "id", "tenant_id", "acan_user_id", "konu", "aciklama", "durum",
            "admin_cevap", "foto_key", "admin_cevap_foto_key",
            "created_at", "updated_at",
        )},
        foto_url=_foto_url(row["foto_key"]),
        admin_cevap_foto_url=_foto_url(row["admin_cevap_foto_key"]),
    )
