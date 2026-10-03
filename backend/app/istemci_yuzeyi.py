"""(P253 §C-5) ISTEGIN GELDIGI YUZEY — denetim kaydi icin.

Her denetim satirinin `meta.yuzey` alani: `web` | `mobil` | `bilinmiyor`.
Kaynak istek basligi `X-Istemci-Yuzey`: web BFF (`lib/backend.ts`) ve
mobil Dio istemcisi (`core/network/dio_provider.dart`) ekler. Basliksiz
istek (eski mobil surum, dogrudan API) `bilinmiyor` yazilir — uydurulmaz.

Istek DISINDAKI yazimlar (Celery, beat) icin baglam bostur ve alan HIC
yazilmaz: "sistem" bir yuzey degildir, aktoru zaten yoktur.

`x-oturum-yuzeyi` (P248, oturum suresi) ile KARISTIRILMAZ: o yalniz jeton
verilirken okunur ve mobilde bilerek bostur; bu ise her istekte
okunur ve yalniz denetim icindir. Yetki KARARI bu basliga BAGLANMAZ —
istemcinin beyanidir, kimlik degildir.
"""
from __future__ import annotations

import contextvars

BASLIK = b"x-istemci-yuzey"
YUZEYLER = ("web", "mobil")
BILINMIYOR = "bilinmiyor"

_yuzey: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "istemci_yuzeyi", default=None
)


def istemci_yuzeyi() -> str | None:
    """Istek icindeyse `web`/`mobil`/`bilinmiyor`; istek disinda None."""
    return _yuzey.get()


class IstemciYuzeyi:
    """Saf ASGI katmani: basliktaki yuzeyi baglama koyar."""

    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        deger = BILINMIYOR
        for ad, v in scope.get("headers") or ():
            if ad == BASLIK:
                aday = v.decode("latin-1").strip().lower()
                deger = aday if aday in YUZEYLER else BILINMIYOR
                break
        jeton = _yuzey.set(deger)
        try:
            return await self.app(scope, receive, send)
        finally:
            _yuzey.reset(jeton)
