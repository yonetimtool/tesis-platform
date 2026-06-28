"""Bildirim kancasi — kacirilan turu KALICI notification kaydina yazar.

Idempotent: ON CONFLICT (tenant_id, tip, patrol_window_id) DO NOTHING — ayni
kacirilan pencere icin tekrar kayit uretmez. Yazma, cagiranin (scheduler) ACTIVE
psycopg baglantisi + tenant context'i (SET LOCAL app.current_tenant_id) icinde
yapilir; boylece RLS WITH CHECK saglanir.

Gercek push/SMS gonderimi hala YOK — soyut `_dispatch_external` kancasi (no-op/log)
sonraki is (FCM/SMS) icin yer tutar.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime

logger = logging.getLogger("scheduler.notify")


def _dispatch_external(message: str) -> None:
    """Soyut gercek-gonderim kancasi (FCM/SMS) — simdilik no-op + log."""
    logger.info("EXTERNAL_NOTIFY (no-op): %s", message)


def notify_missed_tour(
    *,
    conn,
    tenant_id: uuid.UUID,
    plan_id: uuid.UUID,
    window_id: uuid.UUID,
    pencere_baslangic: datetime,
    pencere_bitis: datetime,
    missing_checkpoints: list[uuid.UUID],
) -> None:
    """Kacirilan tur icin kalici notification yaz (idempotent) + log + soyut gonderim."""
    mesaj = (
        f"Kacirilan tur: pencere {pencere_baslangic.isoformat()} - "
        f"{pencere_bitis.isoformat()} ({len(missing_checkpoints)} eksik checkpoint)"
    )
    conn.execute(
        "INSERT INTO notification (tenant_id, tip, patrol_window_id, patrol_plan_id, mesaj) "
        "VALUES (%s, 'kacirilan_tur', %s, %s, %s) "
        "ON CONFLICT (tenant_id, tip, patrol_window_id) DO NOTHING",
        (tenant_id, window_id, plan_id, mesaj),
    )
    logger.warning(
        "MISSED_TOUR tenant=%s plan=%s window=%s missing=%s",
        tenant_id, plan_id, window_id, [str(c) for c in missing_checkpoints],
    )
    _dispatch_external(mesaj)
