"""Celery uygulamasi — iskelet. Broker + backend Redis.

Task'lar `app.tasks` modulunde tanimlanir (include ile kesfedilir; dairesel
import olmamasi icin burada tasks import EDILMEZ).
"""
from __future__ import annotations

from celery import Celery
from celery.schedules import crontab

from .config import settings

celery_app = Celery(
    "tesis",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=["app.tasks"],
)

celery_app.conf.update(
    task_track_started=True,
    task_acks_late=True,
    timezone="UTC",
    enable_utc=True,
)

# Beat: pencere uretimi + kacirilan tur tespiti (periyotlar config'ten).
celery_app.conf.beat_schedule = {
    "generate-patrol-windows": {
        "task": "scheduler.generate_patrol_windows",
        "schedule": float(settings.scheduler_generate_interval_seconds),
    },
    "detect-missed-tours": {
        "task": "scheduler.detect_missed_tours",
        "schedule": float(settings.scheduler_detect_interval_seconds),
    },
    # KVKK saklama & imha — her gece 04:00 Europe/Istanbul. App TZ = UTC; TR
    # yil boyu UTC+3 (DST yok) => 01:00 UTC = 04:00 Istanbul.
    "run-retention": {
        "task": "scheduler.run_retention",
        "schedule": crontab(hour=1, minute=0),
    },
}
