"""Odeme webhook'u — POST /webhooks/payments/{provider}.

GUVENLIK:
  * PUBLIC endpoint (token YOK) ama imza-korumali: saglayici imzasi dogrulanir;
    gecersizse 401, hicbir islem yapilmaz (sahte 'odendi' kabul edilmez).
  * Tenant context webhook'ta yok -> provider_ref'ten owner-sahipli SECURITY DEFINER
    fonksiyon (payment_tenant_by_ref) ile RLS-safe cozulur; sonra set_config.
  * IDEMPOTENT: (tenant, provider, event_id) -> payment_webhook_event UNIQUE; ayni
    olay iki kez gelirse tek kez islenir.
  * TUTAR kontrolu: webhook tutari (kurus) odemenin tutari ile ESLESMELI (manipulasyon
    engeli); uyusmazsa 400, durum degismez.
"""
from __future__ import annotations

from fastapi import APIRouter, Request
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError

from ..db import SessionLocal, set_tenant
from ..errors import APIError
from ..models import DuesPayment
from ..payments import get_named_provider
from .budget import ensure_dues_income_entry

router = APIRouter(prefix="/webhooks/payments", tags=["webhooks"])

_RESOLVE_TENANT = text("SELECT public.payment_tenant_by_ref(:p, :r)")
_INSERT_EVENT = text(
    "INSERT INTO payment_webhook_event (tenant_id, provider, event_id, provider_ref) "
    "VALUES (:t, :p, :e, :r) ON CONFLICT (tenant_id, provider, event_id) DO NOTHING"
)


@router.post("/{provider}")
async def payment_webhook(provider: str, request: Request) -> dict:
    raw = await request.body()
    prov = get_named_provider(provider)  # 404 bilinmeyen saglayici

    # 1) IMZA DOGRULAMA (DB'den ONCE) — gecersizse 401, islem yok.
    event = prov.parse_and_verify_webhook(raw, request.headers)

    async with SessionLocal() as session:
        async with session.begin():
            # 2) tenant'i provider_ref'ten coz (SECURITY DEFINER; RLS bypass).
            tenant_id = (
                await session.execute(
                    _RESOLVE_TENANT, {"p": provider, "r": event.provider_ref}
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise APIError(404, "not_found", "Odeme referansi bulunamadi.")

            await set_tenant(session, tenant_id)

            # 3) idempotency: olay daha once islendiyse tekrar isleme.
            try:
                ins = await session.execute(
                    _INSERT_EVENT,
                    {"t": tenant_id, "p": provider, "e": event.event_id, "r": event.provider_ref},
                )
            except IntegrityError:
                return {"status": "already_processed"}
            if ins.rowcount == 0:
                return {"status": "already_processed"}

            # 4) odemeyi bul + TUTAR kontrolu + durum guncelle.
            payment = (
                await session.execute(
                    select(DuesPayment).where(
                        DuesPayment.provider == provider,
                        DuesPayment.provider_ref == event.provider_ref,
                    )
                )
            ).scalar_one_or_none()
            if payment is None:
                raise APIError(404, "not_found", "Odeme bulunamadi.")
            if event.tutar_kurus != payment.tutar_kurus:
                # manipulasyon engeli -> rollback (event isaretlenmez), durum degismez
                raise APIError(400, "amount_mismatch", "Webhook tutari odeme ile uyusmuyor.")

            payment.durum = event.durum
            # Kartli odeme webhook'la 'basarili' oldugunda otomatik butce
            # gelir kaydi (idempotent; hata webhook islemesini dusurmez).
            await ensure_dues_income_entry(session, payment)

    return {"status": "ok", "durum": event.durum}
