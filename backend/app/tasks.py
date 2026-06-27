"""Celery task iskeleti — ornek bos task.

Gercek task'lar (scheduler: patrol_window uretimi, kacirilan tur tespiti vb.)
sonraki prompt'larda eklenecek.
"""
from __future__ import annotations

from .celery_app import celery_app


@celery_app.task(name="ping")
def ping() -> str:
    """Iskelet/saglik task'i — worker'in calistigini dogrulamak icin."""
    return "pong"
