"""(DUKKAN F3) ZAMANLANMIS ISLER.

===========================================================================
NEDEN KENDI `_async_calistir` KOPYASI
===========================================================================
Yonetiyor'un `tasks.py`indeki sarmalayici bitiste `app.db.engine`i
dispose ediyor — YONETIYOR havuzunu. Dukkan'in AYRI bir engine'i var
(`dukkan_app` roluyle) ve dispose edilmezse P187'de olculen kusur
BIREBIR tekrarlanir:

  asyncpg baglantilari olusturuldugu event loop'a BAGLIDIR; loop
  kapaninca havuzdaki baglantilar olu loop'a bagli kalir, temiz
  kapatilamaz ve PG'de 'idle in transaction' olarak BIRIKIR.

Prod'da bu 90/100 baglantiyla olculdu. Ayni tuzaga ikinci bir havuzla
yeniden dusmemek icin sarmalayici KOPYALANDI — paylasmak, Yonetiyor
engine'ini dispose edip Dukkan'inkini acik birakmak olurdu.
"""
from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import TypeVar

from ..celery_app import celery_app

_T = TypeVar("_T")


def _dukkan_async_calistir(fabrika: Callable[[], Awaitable[_T]]) -> _T:
    """Async gorevi kendi loop'unda kosar ve DUKKAN engine'ini dispose eder."""
    import asyncio

    from .veritabani import engine

    async def _sar() -> _T:
        try:
            return await fabrika()
        finally:
            await engine.dispose()

    return asyncio.run(_sar())


@celery_app.task(name="dukkan.siralama_yenile")
def siralama_yenile() -> dict:
    """Tum gorunur isletmelerin siralama puanini yeniden hesaplar.

    Doner: {"islenen": n}

    ==================================================================
    NEDEN GECELIK GEREKLI
    ==================================================================
    Formulun `yenilik` bileseni ZAMANA bagli ve kendiliginden soner —
    ama puan bir SUTUNDA saklandigi icin yeniden hesaplanmadikca ESKI
    deger kalir. Bu is olmasa, bir yil once onaylanmis bir isletme
    sonsuza dek "yeni isletme" puani tasirdi ve listenin ustunde
    kalirdi.

    IDEMPOTENT: ayni girdiyle ayni sonucu uretir; daha sik kosmak zarar
    vermez.
    """
    async def _calis() -> int:
        from .siralama import tum_puanlari_hesapla
        from .veritabani import SessionLocal

        async with SessionLocal() as s:
            async with s.begin():
                return await tum_puanlari_hesapla(s)

    return {"islenen": _dukkan_async_calistir(_calis)}
