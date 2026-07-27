"""Tutarli hata zarfi: { "error": { "code": "...", "message": "..." } }.

/contracts/README.md (Hata formati) + openapi `Error` semasi ile uyumlu.

DIL (tur 14): `message` artik SABIT degildir — `APIError` cumle yerine
**kimlik** tasir ve metin BURADA, istegin `Accept-Language` basligina gore
uretilir (`hata_metinleri.METINLER`). Boylece Arapca arayuzdeki bir sakin
409'u Arapca gorur. Gerekce ve kurallar: `app/hata_metinleri.py`.

Yapilandirma/saglayici hatalari (bkz. `CEVRILMEYEN_KODLAR`) duz metin
tasimaya devam eder: operatore hitap eder, cevirisi yaniltici olur.
"""
from __future__ import annotations

from collections.abc import Mapping

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.hata_metinleri import hata_metni, istek_dili


class APIError(Exception):
    """Sozlesme hata zarfiyla donen uygulama hatasi.

    `mesaj`: `hata_metinleri.METINLER` icindeki KIMLIK (tercih edilen) ya da
    cevrilmeyecek duz metin (yapilandirma/saglayici hatalari). Ikisi de `str`
    oldugu icin ayrim katalogda arama ile yapilir: kimlik bulunursa cevrilir,
    bulunmazsa metin AYNEN gecer. Bu, yeni bir kimlik eklenirken katalog
    unutulsa bile istegin 500 vermemesini saglar (testler yakalar).

    `params`: metin sablonundaki `{...}` alanlari (orn. `{plaka}`).
    """

    def __init__(
        self,
        status_code: int,
        code: str,
        mesaj: str,
        **params: object,
    ) -> None:
        self.status_code = status_code
        self.code = code
        self.mesaj = mesaj
        self.params: Mapping[str, object] = params
        super().__init__(mesaj)

    def metin(self, dil: str) -> str:
        """Istegin dilinde gosterilecek metin."""
        return hata_metni(self.mesaj, dil, self.params)


def _envelope(status_code: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"error": {"code": code, "message": message}},
    )


def _dil(request: Request) -> str:
    return istek_dili(request.headers.get("accept-language"))


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(APIError)
    async def _api_error(request: Request, exc: APIError) -> JSONResponse:
        return _envelope(exc.status_code, exc.code, exc.metin(_dil(request)))

    @app.exception_handler(RequestValidationError)
    async def _validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        # `details[].message` pydantic'in KENDI (Ingilizce) metnidir: alan
        # duzeyinde teknik ayrinti, istemci onu kullaniciya ham gostermez.
        # Kullaniciya gosterilen UST mesaj cevrilir.
        return JSONResponse(
            status_code=422,
            content={
                "error": {
                    "code": "validation_error",
                    "message": hata_metni("istek_govdesi_gecersiz", _dil(request)),
                    "details": [
                        {
                            "field": ".".join(str(p) for p in e.get("loc", []) if p != "body"),
                            "message": e.get("msg", ""),
                        }
                        for e in exc.errors()
                    ],
                }
            },
        )

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(
        request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        # FastAPI/Starlette kaynakli HTTPException'lari da zarfa cevir.
        code = {
            400: "bad_request",
            401: "unauthorized",
            403: "forbidden",
            404: "not_found",
            409: "conflict",
            429: "rate_limited",
        }.get(exc.status_code, "error")
        # `detail` cerceve metnidir (orn. "Not Found"); katalogda kimlik olarak
        # aranir, yoksa aynen gecer.
        ham = exc.detail if isinstance(exc.detail, str) else code
        return _envelope(exc.status_code, code, hata_metni(ham, _dil(request)))
