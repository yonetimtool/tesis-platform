"""(P253 §C-2) GERI DONDURULEMEZ FINANS EYLEMLERINDE SEBEP ZORUNLU.

Iptal (ters kayit), red ve borclandirma ters kaydi: web ve mobil AYNI uca
gider, AYNI kural. Istemciler dugmeyi sebepsiz etkinlestirmez (web
`onay-kullan.SEBEP_ASGARI`, mobil `finans_onay.dart sebepAsgari`); sunucu
da reddeder — istemcinin unuttugu yerde kural yine gecerli.
"""
from __future__ import annotations

from .errors import APIError

SEBEP_ASGARI = 3


def sebep_zorunlu(aciklama: str | None) -> str:
    """Kirpilmis sebebi doner; `SEBEP_ASGARI`den kisaysa 422 `sebep_zorunlu`."""
    sebep = (aciklama or "").strip()
    if len(sebep) < SEBEP_ASGARI:
        raise APIError(422, "validation_error", "sebep_zorunlu")
    return sebep
