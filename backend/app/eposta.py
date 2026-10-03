"""(P253 acil) E-POSTA NORMALLESTIRME — tek kaynak.

Kural: bas/son bosluk kirpilir, YALNIZ ASCII A-Z kucultulur.

`str.lower()` DEGIL ve `tr_arama` katlamasi HIC DEGIL: Turkce kurali
`I`yi `ı`ya cevirir ve e-postayi bozar; Unicode `lower()` de `İ`yi iki
karaktere boler. Veritabanindaki `public.eposta_normalle` (goc 0170) ayni
kurali uygular ve her e-posta sutununa yazma tetigi olarak baglidir —
bu fonksiyon uygulamanin ayni sonucu ONCEDEN bilmesi icindir (karsilastirma,
benzersizlik denetimi, yanit).

Sunucu buyuk harfi REDDETMEZ, kucultur: SSO saglayicilari ve Excel
buyuk harf gonderebilir. Reddetmek ekranlarin isidir (kullanici yazarken).
"""
from __future__ import annotations

_ASCII_KUCUK = str.maketrans(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"
)


def eposta_normalle(eposta: str) -> str:
    return eposta.strip().translate(_ASCII_KUCUK)


def eposta_normalle_bos(eposta: str | None) -> str | None:
    """Istege bagli alan: None/bos -> None."""
    if eposta is None:
        return None
    e = eposta_normalle(eposta)
    return e or None
