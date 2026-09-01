"""Celery task iskeleti — ornek bos task.

Gercek task'lar (scheduler: patrol_window uretimi, kacirilan tur tespiti vb.)
sonraki prompt'larda eklenecek.
"""
from __future__ import annotations

import uuid
from collections.abc import Awaitable, Callable
from typing import TypeVar

from .celery_app import celery_app

_T = TypeVar("_T")


def _async_calistir(coro_fabrika: Callable[[], Awaitable[_T]]) -> _T:
    """(P187) BAGLANTI SIZINTISI DUZELTMESI — async Celery gorevini kendi event
    loop'unda kosar VE BITISTE async engine'i dispose eder.

    NEDEN: `asyncio.run` her gorevde YENI bir event loop acip kapatir. asyncpg
    baglantilari olusturuldugu loop'a BAGLIDIR; loop kapaninca havuzda kalan
    baglantilar OLU loop'a bagli olur, temiz kapatilamaz ve PG'de
    'idle in transaction' olarak BIRIKIR (beat `gurultu`/`mesaj` kuyrugunu 60
    sn'de bir tetikledigi icin saatler icinde `max_connections` dolar). Loop
    KAPANMADAN `engine.dispose()` cagirmak tum havuz baglantilarini duzgun
    kapatir; sonraki gorev taze acar. Ayrica goc 0071 rol-seviyesinde
    `idle_in_transaction_session_timeout` koydu (ikinci savunma).

    `coro_fabrika` bir CALLABLE'dir (coroutine'i loop ICINDE uretir); coroutine'i
    disarida uretip beklemeye birakmak "coroutine was never awaited" uyarisi ve
    yanlis-loop baglama riski dogururdu.
    """
    import asyncio

    from .db import engine

    async def _sar() -> _T:
        try:
            return await coro_fabrika()
        finally:
            # Loop HALA acikken dispose et: baglantilar bu loop'a bagli, temiz
            # kapanmalari icin loop yasarken kapatilmalari sart.
            await engine.dispose()

    return asyncio.run(_sar())


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


@celery_app.task(name="scheduler.summarize_shifts")
def summarize_shifts() -> dict:
    """(P181 Bölüm 10.2) Beat: biten vardiyalar için TEK özet bildirim.

    Devriye okutmaları tek tek push üretmez; vardiya bitince yönetime tek
    "X/Y nokta okutuldu" özeti gider. Idempotent (vardiya+gün başına tek);
    beat sık koşsa da tekrar üretmez — sıklık yalnız özet gecikmesini etkiler.
    """
    from .scheduler.service import summarize_ended_shifts

    return {"ozet": summarize_ended_shifts()}


@celery_app.task(name="scheduler.gurultu_kuyrugu")
def gurultu_kuyrugu() -> dict:
    """(P37) Beat: basarisiz caydirici webhook'larini geri-cekilmeli dener.

    ISTEK YOLUNDA DEGIL: kullanicinin sikayet kaydini dis bir ucun
    yavasligina baglamak olurdu. Tenant enumerasyonu OWNER ile (RLS
    bootstrap), asil is her tenant icin app_rw + tenant baglami altinda.
    """
    from .gurultu_kuyruk import tum_tenantlar_icin

    return {"islenen": _async_calistir(tum_tenantlar_icin)}


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


@celery_app.task(name="scheduler.finans_otomasyonu")
def finans_otomasyonu() -> dict:
    """(P192 §4) Beat (gunluk): aidat plani, borc hatirlatmasi, duzenli
    gider, gecikme faizi ve aylik ozet.

    TEK GOREV, BES IS: hepsi ayni gunluk pencerede ve ayni tesis
    baglaminda kosar. Bes ayri gorev, bes ayri tenant dongusu ve bes ayri
    baglanti demekti; ayrica siralama garantisi kalmazdi (faiz, tahakkuk
    yazildiktan SONRA hesaplanmali).

    IDEMPOTENT: her is kendi damgasina bakar (bkz. `app/otomasyon.py`),
    yani gorev gunde birden cok kez kossa da tekrar etmez. Bu sayede
    siklik bir IS KURALI degil, DAGITIM detayidir.
    """
    from .otomasyon import tum_tenantlar_icin

    return _async_calistir(tum_tenantlar_icin)


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
    from .mesaj_kuyruk import tum_tenantlar_icin

    return {"islenen": _async_calistir(tum_tenantlar_icin)}


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
    from .rapor_kuyruk import isi_uret

    return _async_calistir(lambda: isi_uret(uuid.UUID(is_id)))
