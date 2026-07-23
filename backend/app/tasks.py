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


@celery_app.task(name="scheduler.generate_patrol_windows")
def generate_patrol_windows() -> dict:
    """Beat: aktif planlar icin pencereleri onceden uretir (materialize-ahead)."""
    from .scheduler.service import materialize_windows

    return {"created": materialize_windows()}


@celery_app.task(name="scheduler.detect_missed_tours")
def detect_missed_tours() -> dict:
    """Beat: bitmis 'bekliyor' pencereleri tamamlandi/kacirildi olarak isaretler."""
    from .scheduler.service import detect_missed

    return detect_missed()


@celery_app.task(name="scheduler.run_retention")
def run_retention() -> dict:
    """Beat (gecelik): KVKK saklama sinirini gecen kisisel veriyi siler/
    anonimlestirir + audit_log purge; sonuc audit_log'a erasure_run olarak yazilir."""
    from .retention import run_retention as _run

    return _run()
