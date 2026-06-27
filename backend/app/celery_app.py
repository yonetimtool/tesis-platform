"""Celery uygulamasi — iskelet. Broker + backend Redis.

Task'lar `app.tasks` modulunde tanimlanir (include ile kesfedilir; dairesel
import olmamasi icin burada tasks import EDILMEZ).
"""
from __future__ import annotations

from celery import Celery

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
