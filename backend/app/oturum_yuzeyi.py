"""(P248 §4) OTURUMUN YUZEYI VE HAREKETSIZLIK SURESI.

===========================================================================
OLCULEN DURUM (once)
===========================================================================
Web'de zamana bagli tek sinirlar erisim jetonu (15 dk) ve 30 gunluk kayan
yenileme jetonuydu: BFF 401'de sessizce yeniliyor (`lib/backend.ts`),
middleware yalniz yenileme cerezinin VARLIGINA bakiyor. Tarayicida erisim
cerezi silinerek (15 dk dolmus gibi) sayfalar ve 40 sn arka plan yoklamasi
suruldu: 401 YOK, oturum dusmedi. Yani web'de "hareketsizlik suresi" diye
bir kural YOKTU — oturum fiilen 30 gun aciktti.

===========================================================================
KARAR
===========================================================================
* WEB (`app.*`): 2 saat hareketsizlikte oturum duser.
* PLATFORM PANELI (`panel.*`): 30 dakika. Oradan TUM tesisler yonetilir;
  basi bos birakilmis bir platform oturumu en genis yetkidir.
* MOBIL: P247'deki 30 gunluk kayan kural aynen — jetonda yuzey YOK.

NEDEN SUNUCUDA: istemci zamanlayicisi atlatilabilir ve kapanan sekmede
calismaz. Yuzey JETONUN ICINDE tasinir (`yz`): calinan bir web jetonundan
iddia silinip 30 gunluk kurala gecilemez. Istek basligi (BFF gonderir)
yalniz jeton VERILIRKEN okunur ve yalniz KISALTIR — basligi gondermeyen
bir istemci bugunku davranisi alir, gonderen daha kisa oturum alir.

NASIL: her kimlikli istek ailenin `oturum:etkin:<fam>` anahtarini yeniler
(ömür = sinir). Anahtar kendiliginden duser; yenileme ucu anahtari
bulamazsa aileyi kapatir. Erisim jetonu (15 dk) her iki sinirdan kisa
oldugu icin ayrica erisimde denetim gerekmez.
"""
from __future__ import annotations

import contextvars
import logging
from typing import Any

import redis.asyncio as aioredis

from .config import settings

_log = logging.getLogger(__name__)

#: Istek basligi — BFF (`admin-web/lib/backend.ts callBackend`) gonderir.
BASLIK = "x-oturum-yuzeyi"
YUZEYLER = ("web", "platform")

_yuzey: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "oturum_yuzeyi", default=None
)


def istek_yuzeyi() -> str | None:
    """Bu istegin (jeton verilecekse) yuzeyi; mobil/bilinmeyen -> None."""
    return _yuzey.get()


def sinir_sn(yz: str | None) -> int | None:
    if yz == "web":
        return settings.web_hareketsizlik_dk * 60
    if yz == "platform":
        return settings.panel_hareketsizlik_dk * 60
    return None


def _anahtar(fam: str) -> str:
    return f"oturum:etkin:{fam}"


async def etkinlik_isle(redis: aioredis.Redis | None, yz: str | None, fam: str | None) -> None:
    """Ailenin son etkinligini tazeler (yuzeyi olmayan jetonda no-op)."""
    sn = sinir_sn(yz)
    if redis is None or sn is None or not fam:
        return
    try:
        await redis.set(_anahtar(fam), 1, ex=sn)
    except Exception as e:  # pragma: no cover - fail-open (oturum_iptal ile ayni)
        _log.warning("oturum etkinligi yazilamadi: %s", e)


async def hareketsiz_mi(redis: aioredis.Redis | None, claims: dict[str, Any]) -> bool:
    """Yenileme jetonunun ailesi sinirdan uzun suredir hareketsiz mi."""
    if redis is None or sinir_sn(claims.get("yz")) is None:
        return False
    try:
        return not await redis.exists(_anahtar(str(claims.get("fam", ""))))
    except Exception as e:  # pragma: no cover
        _log.warning("oturum etkinligi okunamadi: %s", e)
        return False


class OturumYuzeyi:
    """Saf ASGI katmani: istek basligindaki yuzeyi baglama koyar."""

    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        deger = None
        for ad, v in scope.get("headers") or ():
            if ad == BASLIK.encode():
                deger = v.decode("latin-1").strip().lower()
                break
        jeton = _yuzey.set(deger if deger in YUZEYLER else None)
        try:
            return await self.app(scope, receive, send)
        finally:
            _yuzey.reset(jeton)
