"""Bildirim kancasi — kacirilan turu KALICI notification kaydina yazar.

Idempotent: ON CONFLICT (tenant_id, tip, patrol_window_id) DO NOTHING — ayni
kacirilan pencere icin tekrar kayit uretmez. Yazma, cagiranin (scheduler) ACTIVE
psycopg baglantisi + tenant context'i (SET LOCAL app.current_tenant_id) icinde
yapilir; boylece RLS WITH CHECK saglanir.

Gercek push: `dispatch_external` kancasi FCM'e baglanir (app/push.py). In-app
notification'i ETKILEMEZ — push EK gonderimdir; hatasi bildirim akisini kirmaz.
"""
from __future__ import annotations

import logging
import uuid
from collections.abc import Mapping, Sequence
from datetime import datetime

import psycopg

from .. import push
from ..config import settings

logger = logging.getLogger("scheduler.notify")

# Alarm bildirimlerini push olarak alacak roller (dashboard alarm mantigiyla tutarli).
_ALARM_ROLES: tuple[str, ...] = ("admin", "security")


def dispatch_external(
    message: str,
    *,
    tenant_id: uuid.UUID | None = None,
    target_roles: Sequence[str] | None = None,
    title: str = "Tesis bildirimi",
    data: Mapping[str, str] | None = None,
) -> None:
    """Gercek-gonderim kancasi (FCM push) — EK gonderim, in-app'i etkilemez.

    tenant_id/target_roles verilmezse eski no-op davranisi (yalniz log). Push
    hatasi bildirim akisini KIRMAZ (try/except + log).
    """
    logger.info("EXTERNAL_NOTIFY: %s", message)
    try:
        _push_to_devices(
            tenant_id=tenant_id, target_roles=target_roles, title=title, body=message, data=data
        )
    except Exception:  # savunma: push cokerse in-app bildirim akisi devam eder
        logger.exception("push gonderimi basarisiz (in-app bildirimi etkilenmez)")


def _push_to_devices(
    *,
    tenant_id: uuid.UUID | None,
    target_roles: Sequence[str] | None,
    title: str,
    body: str,
    data: Mapping[str, str] | None,
) -> None:
    provider = push.get_push_provider()
    if tenant_id is None or not target_roles:
        return  # hedef bilgisi yok -> gonderim yapma (eski no-op)
    tokens = _fetch_device_tokens(tenant_id, target_roles)
    if not tokens:
        return
    provider.send(tokens, title=title, body=body, data=dict(data or {}))


def _fetch_device_tokens(tenant_id: uuid.UUID, roles: Sequence[str]) -> list[str]:
    """Tenant'ta hedef rollerdeki AKTIF kullanicilarin aktif device token'lari.

    Kendi kisa-omurlu app_rw baglantisini acar + tenant context set eder (RLS-safe);
    boylece hem sync (scheduler) hem async (emergency) cagiran icin ayni kod calisir.
    """
    with psycopg.connect(settings.app_dsn, connect_timeout=10) as conn:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
            )
            cur.execute(
                "SELECT d.fcm_token FROM user_device d "
                "JOIN app_user u ON u.id = d.user_id "
                "WHERE d.aktif = true AND u.is_active = true AND u.role::text = ANY(%s)",
                (list(roles),),
            )
            return [r[0] for r in cur.fetchall()]


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
    dispatch_external(
        mesaj,
        tenant_id=tenant_id,
        target_roles=_ALARM_ROLES,
        title="Kacirilan tur",
        data={"tip": "kacirilan_tur", "patrol_window_id": str(window_id)},
    )


def notify_landscape(
    *,
    conn,
    tenant_id: uuid.UUID,
    task_id: uuid.UUID,
    tip: str,
    planlanan: datetime,
    mesaj: str,
) -> None:
    """Peyzaj hatirlatma bildirimi (idempotent: dedup_key = <tip>:<task_id>:<planlanan_iso>).

    tip: 'peyzaj_yaklasan' | 'peyzaj_kacirilan'. Yazma cagiranin tenant-context'li
    psycopg baglantisi icinde yapilir (RLS WITH CHECK).
    """
    dedup_key = f"{tip}:{task_id}:{planlanan.isoformat()}"
    conn.execute(
        "INSERT INTO notification (tenant_id, tip, task_id, dedup_key, mesaj) "
        "VALUES (%s, %s::notification_tip, %s, %s, %s) "
        "ON CONFLICT (tenant_id, dedup_key) DO NOTHING",
        (tenant_id, tip, task_id, dedup_key, mesaj),
    )
    logger.warning("LANDSCAPE_REMINDER tenant=%s task=%s tip=%s", tenant_id, task_id, tip)
    dispatch_external(
        mesaj,
        tenant_id=tenant_id,
        target_roles=_ALARM_ROLES,
        title="Peyzaj hatirlatma",
        data={"tip": tip, "task_id": str(task_id)},
    )
