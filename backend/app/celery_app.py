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
    # (P34) Gecikme alarmi: tespitten DAHA SIK — pencere aciktir ve tur
    # hala kurtarilabilir; gec gonderilen bir "tur baslamadi" alarmi
    # kimseyi harekete geciremez.
    "detect-late-patrols": {
        "task": "scheduler.detect_late_patrols",
        "schedule": float(settings.scheduler_gecikme_interval_seconds),
    },
    # (P181 Bölüm 10.2) Vardiya sonu ozeti: biten vardiyalar icin TEK bildirim.
    # SIKLIK = 5 dk (300 s), GEREKCE:
    #  * Fonksiyon IDEMPOTENT (vardiya+gun basina tek, dedup_key) — sik kosmak
    #    tekrar bildirim URETMEZ, yalnizca hafif bir sorgudur.
    #  * Ozet bir RAPOR (alarm degil); birkac dakikalik gecikme zararsiz.
    #  * Ama COK seyrek de olamaz: bir vardiyanin ozetlenebilir penceresi
    #    [bitis, ertesi yerel gece-yarisi] arasidir (gece-yarisinda `bugun`
    #    donunce olusum degisir). Gece-yarisina YAKIN biten bir vardiyada bu
    #    pencere kisadir; 5 dk kacirma penceresini <5 dk'ya indirir.
    # DETECT'ten AYRI/SABIT: `detect_interval`e baglamak, operator onu (or.
    # buyuk kampus icin) uzatinca ozetin sessizce gec-yarisi vardiyalarini
    # kacirmasi demekti.
    "summarize-shifts": {
        "task": "scheduler.summarize_shifts",
        "schedule": 300.0,
    },
    # (P207 §3) VARDIYA HATIRLATMA + BASLAMAMA UYARISI.
    #
    # DAKIKADA BIR: kademe penceresi bir dakikadir (`kademe-1 < kalan <=
    # kademe`). Bes dakikada bir kossaydi "5 dakika kaldi" kademesi
    # cogu vardiyada HIC yakalanmazdi.
    #
    # DAGITIM NOTU: bu gorev BEAT + WORKER imajlarinda kosar; ikisi de
    # yeniden dagitilmali (daha once iki kez atlandi — bkz.
    # `docs/dagitim.md`).
    "vardiya-hatirlatma": {
        "task": "scheduler.vardiya_hatirlatma",
        "schedule": 60.0,
    },
    # (P37) Caydirici webhook yeniden deneme kuyrugu — geri cekilme
    # dakikalar mertebesinde oldugu icin dakikada bir bakmak yeterli.
    "gurultu-kuyrugu": {
        "task": "scheduler.gurultu_kuyrugu",
        "schedule": 60.0,
    },
    # (P154 / Asama 9) Mesaj yeniden deneme kuyrugu. Ayni gerekce:
    # geri cekilme dakikalar mertebesinde, dakikada bir bakmak yeterli.
    "mesaj-kuyrugu": {
        "task": "scheduler.mesaj_kuyrugu",
        "schedule": 60.0,
    },
    # KVKK saklama & imha — her gece 04:00 Europe/Istanbul. App TZ = UTC; TR
    # yil boyu UTC+3 (DST yok) => 01:00 UTC = 04:00 Istanbul.
    "run-retention": {
        "task": "scheduler.run_retention",
        "schedule": crontab(hour=1, minute=0),
    },
    # (P192 §4) FINANS OTOMASYONU — her gun 06:00 Europe/Istanbul
    # (03:00 UTC; TR yil boyu UTC+3, DST yok).
    #
    # SAAT SECIMI: tahakkuk ve hatirlatma bildirimleri SABAH gitmeli —
    # gece yarisi gonderilen bir "borcunuz var" bildirimi kimseyi
    # harekete gecirmez, yalnizca uyandirir. Retention 01:00'de kosuyor;
    # ondan SONRA olmasi da bilincli: silinmis/anonimlestirilmis
    # kayitlara bildirim gitmesin.
    #
    # GUNDE BIR: gorev idempotenttir (her is kendi damgasina bakar), yani
    # daha sik kosmak zarar vermez — ama gerek de yok: hepsi GUNLUK
    # kararlardir.
    "finans-otomasyonu": {
        "task": "scheduler.finans_otomasyonu",
        "schedule": crontab(hour=3, minute=0),
    },
}
