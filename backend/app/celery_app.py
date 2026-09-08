"""Celery uygulamasi — iskelet. Broker + backend Redis.

Task'lar `app.tasks` modulunde tanimlanir (include ile kesfedilir; dairesel
import olmamasi icin burada tasks import EDILMEZ).
"""
from __future__ import annotations

from celery import Celery
from celery.schedules import crontab
from celery.signals import beat_init

from .config import settings

celery_app = Celery(
    "tesis",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=["app.tasks", "app.dukkan.gorevler"],
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
    # (DUKKAN F3) SIRALAMA PUANI TAZELEME — her gece 05:00 Istanbul
    # (02:00 UTC).
    #
    # SAAT SECIMI: retention (01:00 UTC) ile finans (03:00 UTC) ARASINA
    # kondu. Ikisiyle cakismamasi bilincli — ucu de veritabanini yoruyor
    # ve ayni anda kosmalari gereksiz bir tepe olustururdu.
    #
    # NEDEN GEREKLI: puanin `yenilik` bileseni ZAMANA bagli ve
    # kendiliginden soner, ama sutunda saklandigi icin yeniden
    # hesaplanmadikca eski deger kalir.
    "dukkan-siralama": {
        "task": "dukkan.siralama_yenile",
        "schedule": crontab(hour=2, minute=0),
    },
    # (DUKKAN F8b) REKLAM BAKIMI — suresi bitenleri dusur, hatirlat,
    # bekleme listesine yer-acildi haberi ver.
    #
    # SIRALAMADAN SONRA (02:20): ikisi ayni veritabanina yaziyor ve
    # siralama isi tum gorunur isletmeleri dolasiyor. Ust uste
    # koymak, gecelik pencerede gereksiz kilitlenme riski olurdu.
    #
    # SABAH DEGIL GECE: "reklamin 1 gun sonra bitiyor" bildirimi
    # gunun ortasinda gelirse isletme o gunu kacirabilir.
    "dukkan-reklam-bakimi": {
        "task": "dukkan.reklam_bakimi",
        "schedule": crontab(hour=2, minute=20),
    },
    # (DUKKAN F8c) ABONELIK CEKIMI — vadesi gelen otomatik yenilemeler.
    #
    # REKLAM BAKIMINDAN SONRA (02:40): bakim suresi bitenleri dusurur ve
    # SLOT ACAR; cekim o slota yeni donemi yazar. Ters sirada, kendi
    # reklami hala "yayinda" oldugu icin yenileme "bolge dolu" alirdi.
    #
    # SAGLAYICI BAGLI DEGILKEN gorev hicbir sey yapmaz ve sayaclari
    # sismez (bkz. `abonelik_cekimi` basligi).
    "dukkan-abonelik-cekimi": {
        "task": "dukkan.abonelik_cekimi",
        "schedule": crontab(hour=2, minute=40),
    },
}


# =========================================================================== #
# BEAT ACILIS KONTROLU — UC KEZ YASANAN "ESKI IMAJ" KUSURU
# =========================================================================== #
# P187 (vardiya ozeti), P192 (finans otomasyonu) ve F8b (reklam bakimi):
# ucunde de gorev yazildi, `api` ve `worker` yenilendi, `beat` ATLANDI ve
# gorev prod'da HIC KOSMADI. Hicbir hata gorunmedi.
#
# Bu kanca, beat'in yukledigi zamanlamayi `contracts/` altindaki CANLI
# MOUNT manifestle karsilastirir. Karsilastirmanin anlamli olmasinin tek
# sebebi manifestin IMAJIN DISINDAN gelmesi (gerekce: `beat_kilidi.py`).
#
# `beat_init` SECILDI, `worker_init` DEGIL: kusur beat'e ozgu. Worker'in
# zamanlamayla isi yok; orada uyarmak gurultu olurdu.
@beat_init.connect
def _beat_acilis_kontrolu(**_kw) -> None:
    """Acilista ayrismayi olcer, loglar ve Redis'e yazar. FIRLATMAZ."""
    try:
        from .beat_kilidi import durumu_gunlukle_ve_yaz

        durumu_gunlukle_ve_yaz(celery_app.conf.beat_schedule, settings.redis_url)
    except Exception:  # pragma: no cover
        # Bir TESPIT mekanizmasi, tespit ettigi seyden buyuk bir arizaya
        # yol acmamali: beat her halukarda kalkar.
        import logging

        logging.getLogger(__name__).exception("beat acilis kontrolu basarisiz")
