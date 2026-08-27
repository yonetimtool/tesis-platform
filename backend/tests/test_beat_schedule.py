"""(P181 Bölüm 10.2) BEAT SCHEDULE KİLİDİ.

Vardiya özeti prod'da HİÇ çalışmadı: task tanımlıydı ama `beat_schedule`'a
kaydı gözden kaçtı (ve prod `beat` konteyneri eski imajdaydı). Mevcut testler
`summarize_ended_shifts`'i DOĞRUDAN çağırdığı için zamanlayıcı kaydını hiç
görmedi. Bu kilit iki yönü de tarar:

  1. `beat_schedule`'daki her görevin `task` adı GERÇEKTEN kayıtlı bir celery
     task'ı — typo/var-olmayan ad beat'te sessiz hataya döner.
  2. Her PERİYODİK (`scheduler.*`) task `beat_schedule`'da — bir task tanımlanıp
     ZAMANLANMAZSA (vardiya özeti hatası) bu test kırılır. On-demand task'lar
     (`ceviri.*`, `rapor.*`, `ping`) periyodik değildir; `scheduler.` öneki
     onları kapsam dışı bırakır.
"""
from __future__ import annotations

# Task'ların kayıtlı olması için modülün import EDİLMESİ şart (dekoratörler
# import anında `celery_app.tasks`'a ekler). `include=["app.tasks"]` yalnız
# worker/beat sürecinde çalışır; testte elle import ederiz.
import app.tasks  # noqa: F401
from app.celery_app import celery_app

#: Beat ile KOŞMAYAN, çağrı üzerine (on-demand) tetiklenen task'lar. `scheduler.`
#: öneki zaten bunları dışlar; liste yine de niyeti belgelemek için burada.
ON_DEMAND = {"ping", "ceviri.translate_entity", "rapor.uret"}


def _zamanlanan_task_adlari() -> set[str]:
    return {g["task"] for g in celery_app.conf.beat_schedule.values()}


def test_beat_schedule_gorevleri_KAYITLI_task():
    """Her beat_schedule girdisinin task'ı celery'de kayıtlı (typo/eksik yakalar)."""
    kayitli = set(celery_app.tasks.keys())
    eksik = {
        f"{ad} -> {g['task']}"
        for ad, g in celery_app.conf.beat_schedule.items()
        if g["task"] not in kayitli
    }
    assert not eksik, f"beat_schedule'da KAYITSIZ task(lar): {eksik}"


def test_scheduler_periyodik_tasklar_ZAMANLANMIS():
    """Her `scheduler.*` task beat_schedule'da — tanımlanıp ZAMANLANMAYAN bir
    görev (vardiya özeti hatası) tekrar olmasın."""
    zamanlanan = _zamanlanan_task_adlari()
    scheduler_tasklari = {
        ad for ad in celery_app.tasks if ad.startswith("scheduler.")
    }
    eksik = scheduler_tasklari - zamanlanan
    assert not eksik, (
        f"tanımlı ama ZAMANLANMAMIŞ scheduler task(lar): {eksik} — "
        "beat_schedule'a ekleyin ya da on-demand ise adını 'scheduler.' dışına alın"
    )


def test_vardiya_ozeti_GERCEKTEN_zamanlanmis():
    """Doğrudan bu bölümün regresyonu: vardiya özeti beat'te KAYITLI."""
    assert "scheduler.summarize_shifts" in _zamanlanan_task_adlari()


def test_ON_DEMAND_listesi_GERCEK():
    """ON_DEMAND'daki her ad gerçekten kayıtlı VE zamanlanmamış (liste yalan
    bir gerekçe koleksiyonuna dönmesin)."""
    kayitli = set(celery_app.tasks.keys())
    zamanlanan = _zamanlanan_task_adlari()
    for ad in ON_DEMAND:
        assert ad in kayitli, f"ON_DEMAND '{ad}' kayıtlı değil"
        assert ad not in zamanlanan, f"ON_DEMAND '{ad}' aslında zamanlanmış"
