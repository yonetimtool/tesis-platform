"""Bildirim kancasi — bu turda SADECE yapilandirilmis log.

Gercek push/SMS gonderimi ve Notification tablosu SONRAKI prompt'ta gelecek.
Imza burada sabitlenir ki cagiranlar degismesin.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime

logger = logging.getLogger("scheduler.notify")


def notify_missed_tour(
    *,
    tenant_id: uuid.UUID,
    plan_id: uuid.UUID,
    window_id: uuid.UUID,
    pencere_baslangic: datetime,
    pencere_bitis: datetime,
    missing_checkpoints: list[uuid.UUID],
) -> None:
    """Kacirilan tur icin soyut bildirim kancasi (simdilik log)."""
    logger.warning(
        "MISSED_TOUR tenant=%s plan=%s window=%s pencere=[%s..%s] "
        "missing_checkpoints=%s",
        tenant_id,
        plan_id,
        window_id,
        pencere_baslangic.isoformat(),
        pencere_bitis.isoformat(),
        [str(c) for c in missing_checkpoints],
    )
    # TODO(sonraki prompt): Notification kaydi + gercek push/SMS gonderimi.
