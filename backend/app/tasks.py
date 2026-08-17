"""Celery task iskeleti — ornek bos task.

Gercek task'lar (scheduler: patrol_window uretimi, kacirilan tur tespiti vb.)
sonraki prompt'larda eklenecek.
"""
from __future__ import annotations

import uuid

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


@celery_app.task(name="scheduler.detect_late_patrols")
def detect_late_patrols() -> dict:
    """(P34) Beat: ACIK pencerede tolerans asildi ve hic okutma yok -> alarm.

    `detect_missed_tours`DAN AYRI CALISIR ve DAHA SIK kosar: kacirildi
    damgasi pencere bitince bir kez vurulur, gecikme alarmi ise pencere
    ACIKKEN anlamlidir — seyrek kosan bir gorev alarmi tolerans suresinden
    cok sonra gonderirdi.
    """
    from .scheduler.service import detect_gecikmis

    return {"alarm": detect_gecikmis()}


@celery_app.task(name="scheduler.gurultu_kuyrugu")
def gurultu_kuyrugu() -> dict:
    """(P37) Beat: basarisiz caydirici webhook'larini geri-cekilmeli dener.

    ISTEK YOLUNDA DEGIL: kullanicinin sikayet kaydini dis bir ucun
    yavasligina baglamak olurdu. Tenant enumerasyonu OWNER ile (RLS
    bootstrap), asil is her tenant icin app_rw + tenant baglami altinda.
    """
    import asyncio

    from .gurultu_kuyruk import tum_tenantlar_icin

    return {"islenen": asyncio.run(tum_tenantlar_icin())}


@celery_app.task(name="ceviri.translate_entity", bind=True, max_retries=3)
def translate_entity(self, tip_ad: str, entity_id: str, tenant_id: str) -> dict:
    """Yayin iceriginin (duyuru/kural/etkinlik) eksik cevirilerini uretir.

    Istek yolundan `enqueue_ceviri` ile kuyruklanir. Idempotent: hazir ve
    kaynagi degismemis diller yeniden cevrilmez; elle duzeltilmis ceviriler
    korunur (bkz. app/ceviri.py [korunur_mu]).

    COMMIT YARISI: icerik henuz gorunmuyorsa (istegin transaction'i commit
    edilmemis) is SINIRLI SAYIDA yeniden denenir — aksi halde ceviri sessizce
    hic uretilmezdi. Icerik GERCEKTEN silinmisse denemeler tukenir ve is
    "icerik yok" ile sessizce biter (dogru davranis: cevirisi de CASCADE ile
    silinmistir)."""
    from .ceviri_service import entity_cevir

    ozet = entity_cevir(tip_ad, entity_id, tenant_id)
    if ozet.get("not") == "icerik yok" and self.request.retries < self.max_retries:
        raise self.retry(countdown=3)
    return ozet


@celery_app.task(name="scheduler.run_retention")
def run_retention() -> dict:
    """Beat (gecelik): KVKK saklama sinirini gecen kisisel veriyi siler/
    anonimlestirir + audit_log purge; sonuc audit_log'a erasure_run olarak yazilir."""
    from .retention import run_retention as _run

    return _run()


@celery_app.task(name="scheduler.mesaj_kuyrugu")
def mesaj_kuyrugu() -> dict:
    """(P154 / Asama 9) Beat: basarisiz mesaj gonderimlerini yeniden dener.

    ISTEK YOLUNDA DEGIL: yeniden denemeyi istegin icine koymak,
    yoneticinin tarayicisini saglayicinin geri-cekilme suresi boyunca
    bekletirdi. Tenant enumerasyonu OWNER ile (RLS bootstrap), asil is her
    tenant icin `app.current_tenant_id` baglami altinda.
    """
    import asyncio

    from .mesaj_kuyruk import tum_tenantlar_icin

    return {"islenen": asyncio.run(tum_tenantlar_icin())}


@celery_app.task(name="rapor.uret", bind=True, max_retries=2)
def rapor_uret_gorevi(self, is_id: str) -> dict:
    """(P167 Asama 5) Agir raporu arka planda uret.

    ISTEK YOLUNDA DEGIL: `borc_alacak` gibi raporlar tum defteri tarar ve
    senkron uretimde tarayici yanit gelene kadar bekler; zaman asiminda is
    YARIM kalir (bkz. `app/rapor_kuyruk.py` basligi).

    YENIDEN DENEME SINIRLI (`max_retries=2`) ve bilincli: hatanin cogu
    kalicidir (gecersiz parametre, silinmis kasa). Sinirsiz denemek, ayni
    pahali sorguyu sonsuza kadar tekrarlamak olurdu. Kalici hata zaten
    satira YAZILIYOR — kullanici sebebini goruyor.
    """
    import asyncio

    from .rapor_kuyruk import isi_uret

    return asyncio.run(isi_uret(uuid.UUID(is_id)))
