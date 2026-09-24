"""(P247 §6) ISTEK GOVDESI BOYUT SINIRI — tum uclar icin tek kapi.

=========================================================================
NEDEN
=========================================================================
Uc guvenlik envanteri 88 ucta 159 metin alaninin uzunluk sinirsiz oldugunu
gosterdi (E2E turunda 10.000 karakterlik bir kullanici adi /tasks sayfasini
90.000px genislige tasirmisti). Alan alan `max_length` eklemek gerekli ama
TEK BASINA YETMEZ: yeni bir alan eklenirken unutulur. Govde siniri, alan
duzeyi sinirlarin ALTINDA kalan son savunma hattidir — sinirsiz bir alan
bile en fazla bu kadar veri tasiyabilir.

DOSYA YUKLEME API'DEN GECMEZ (imzali adresle dogrudan nesne deposuna),
bu yuzden sinir dusuk tutulabilir. En buyuk mesru JSON govdeleri toplu ice
aktarimlardir (sakin/daire/vardiya satirlari, banka ekstresi metni).

Content-Length varsa istek UYGULAMAYA HIC GIRMEDEN reddedilir; yoksa
(chunked) okunan bayt sayilir ve sinir asilinca kesilir.
"""
from __future__ import annotations

import json

#: JSON / form govdesi icin ust sinir (bayt).
GOVDE_SINIRI = 5 * 1024 * 1024

def _yanit(scope) -> bytes:
    """Istegin dilinde hata govdesi (hata katalogu, 7 dil)."""
    from .hata_metinleri import hata_metni, istek_dili

    dil = None
    for ad, deger in scope.get("headers") or []:
        if ad == b"accept-language":
            dil = deger.decode("latin-1")
    return json.dumps(
        {"error": {"code": "payload_too_large",
                   "message": hata_metni("istek_govdesi_cok_buyuk", istek_dili(dil))}},
        ensure_ascii=False,
    ).encode()


class _Asildi(Exception):
    pass


class GovdeSiniri:
    """Saf ASGI ara katmani (Starlette BaseHTTPMiddleware govdeyi tamponlar)."""

    def __init__(self, app, sinir: int = GOVDE_SINIRI) -> None:
        self.app = app
        self.sinir = sinir

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        for ad, deger in scope.get("headers") or []:
            if ad == b"content-length":
                try:
                    if int(deger) > self.sinir:
                        await self._reddet(scope, send)
                        return
                except ValueError:
                    await self._reddet(scope, send, 400)
                    return
        okunan = 0
        baslandi = False

        async def sayan_receive():
            nonlocal okunan
            mesaj = await receive()
            if mesaj["type"] == "http.request":
                okunan += len(mesaj.get("body", b""))
                if okunan > self.sinir:
                    raise _Asildi()
            return mesaj

        async def izleyen_send(mesaj):
            nonlocal baslandi
            if mesaj["type"] == "http.response.start":
                baslandi = True
            await send(mesaj)

        try:
            await self.app(scope, sayan_receive, izleyen_send)
        except _Asildi:
            if not baslandi:
                await self._reddet(scope, send)

    @staticmethod
    async def _reddet(scope, send, durum: int = 413) -> None:
        govde = _yanit(scope)
        await send({
            "type": "http.response.start",
            "status": durum,
            "headers": [(b"content-type", b"application/json"),
                        (b"content-length", str(len(govde)).encode())],
        })
        await send({"type": "http.response.body", "body": govde})
