"""(E2E 2026-09) OTURUM IPTALI — cikis, parola sifirlama, "her yerden cik".

=========================================================================
OLCULEN KUSUR
=========================================================================
* Backend'de cikis ucu YOKTU: web cikisi yalniz cerezi, mobil cikisi yalniz
  yerel depoyu siliyordu. Cikistan sonra eski refresh 30 gun boyunca yeni
  jeton cifti uretmeye devam ediyordu.
* Parola sifirlama/degistirme acik oturumlara DOKUNMUYORDU: hesabi ele
  gecirilen kullanicinin kurtarma yolu saldirganin oturumunu kapatmiyordu.

=========================================================================
TASARIM — GOCSUZ, TEK NOKTA
=========================================================================
Refresh aileleri Redis'te ama KULLANICIYA gore indekslenmiyor; "bu
kullanicinin tum ailelerini bul" sorusu yanitlanamaz. Onun yerine kullanici
basina bir DAMGA tutulur: "bu andan ONCE verilmis jetonlar gecersiz".
Hem erisim (`get_current_user`) hem yenileme (`/auth/refresh`) bu damgaya
bakar; jetonlarin `ims` (milisaniye) iddiasi damgayla karsilastirilir.

Milisaniye cunku saniye yetmez: sifirlamadan HEMEN sonra (ayni saniyede)
yapilan yeni giris, saniye hassasiyetinde eski sayilip reddedilirdi.

Tekil cikis (bu cihaz) damgaya DOKUNMAZ — diger cihazlar acik kalir; o
cihazin refresh ailesi silinir ve erisim jetonu kalan omru kadar
kara listeye alinir.

REDIS YOKSA ISTEK GECER (fail-open) — `hiz_siniri` ile ayni gerekce:
bu bir sertlestirme katmanidir, kimlik dogrulamanin kendisi degil.
"""
from __future__ import annotations

import logging
import time
from typing import Any

import redis.asyncio as aioredis

from .config import settings

_log = logging.getLogger(__name__)


def _damga_anahtari(user_id: str) -> str:
    return f"oturum_iptal:{user_id}"


def _jti_anahtari(jti: str) -> str:
    return f"oturum_kapali_jti:{jti}"


def jeton_ms(claims: dict[str, Any]) -> int:
    """Jetonun verilis ani (ms). Eski jetonlarda `ims` yok -> `iat`*1000."""
    ims = claims.get("ims")
    if isinstance(ims, int):
        return ims
    return int(claims.get("iat", 0)) * 1000


async def tum_oturumlari_kapat(redis: aioredis.Redis | None, user_id) -> None:
    """Kullanicinin SIMDIYE KADAR verilmis tum jetonlarini gecersiz kilar."""
    if redis is None:
        return
    try:
        await redis.set(
            _damga_anahtari(str(user_id)),
            int(time.time() * 1000),
            ex=settings.refresh_token_expire_days * 86400,
        )
    except Exception as e:  # pragma: no cover - fail-open
        _log.warning("oturum iptal damgasi yazilamadi: %s", e)


async def erisim_jetonunu_kapat(redis: aioredis.Redis | None, claims: dict[str, Any]) -> None:
    """Tek bir erisim jetonunu kalan omru boyunca kara listeye alir."""
    jti = claims.get("jti")
    if redis is None or not jti:
        return
    kalan = int(claims.get("exp", 0)) - int(time.time())
    if kalan <= 0:
        return
    try:
        await redis.set(_jti_anahtari(str(jti)), 1, ex=kalan)
    except Exception as e:  # pragma: no cover
        _log.warning("jti kara listesi yazilamadi: %s", e)


async def iptal_edilmis_mi(redis: aioredis.Redis | None, claims: dict[str, Any]) -> bool:
    if redis is None:
        return False
    try:
        damga, kapali = await redis.mget(
            _damga_anahtari(str(claims.get("sub"))),
            _jti_anahtari(str(claims.get("jti"))),
        )
    except Exception as e:  # pragma: no cover - fail-open
        _log.warning("oturum iptal damgasi okunamadi: %s", e)
        return False
    if kapali is not None:
        return True
    return damga is not None and jeton_ms(claims) < int(damga)
