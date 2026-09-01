"""(P202) SEMANTIK SURUM KARSILASTIRMASI ve GUNCELLEME KARARI.

===========================================================================
NEDEN METIN KARSILASTIRMASI DEGIL
===========================================================================
`"1.10.0" < "1.9.0"` METIN olarak DOGRUDUR ('1' < '9') ve SURUM olarak
YANLISTIR. Bu kusur sessizdir: 1.9.0 yayindayken kimse fark etmez,
1.10.0 cikinca TUM kullanicilar "guncel" sayilir ve zorunlu guncelleme
HIC calismaz — yani ozellik tam ihtiyac duyuldugu anda ise yaramaz.

Bu yuzden karsilastirma PARCA PARCA ve SAYISALDIR.

===========================================================================
BICIM: "BUYUK.KUCUK.YAMA" — YAPIM NUMARASI YOK SAYILIR
===========================================================================
`pubspec.yaml` surumu `1.1.1+6` seklindedir; `+6` YAPIM numarasidir ve
magazada gorunen surum DEGILDIR. Ayni surumun ikinci yuklemesi yapim
numarasini artirir ama kullanici icin hicbir sey degismez — politika bu
yuzden yalnizca `+`dan ONCEKI kisma bakar.

Eksik parcalar SIFIR sayilir: "1.2" == "1.2.0". Operator panele "1.2"
yazdiginda bunun "1.2.0" demek oldugunu varsaymasi dogaldir.

===========================================================================
GECERSIZ BICIM: ESIK YOK SAYILIR — KULLANICI KILITLENMEZ
===========================================================================
`ayristir` gecersiz metinde `None` doner ve karar veren kod bunu
"esik tanimsiz" sayar. ALTERNATIF, kullaniciyi kilitlemekti: panele
yanlislikla "surum-3" yazan bir operator TUM KULLANICILARI disari
atardi. Zorunlu guncelleme bir GUVENLIK araci; bir kendini-vurma
tetigi degil.
"""
from __future__ import annotations

import re

#: "1", "1.2", "1.2.3" — istege bagli `+yapim` ve `-onsurum` KIRPILIR.
#: Onek/sonek serbest metne izin YOKTUR: "surum 1.2" gecersizdir, cunku
#: "1.2" sanip yanlis karar vermek sessiz bir kusurdur.
_BICIM = re.compile(r"^(\d+)(?:\.(\d+))?(?:\.(\d+))?$")


def ayristir(surum: str | None) -> tuple[int, int, int] | None:
    """`"1.10.0"` -> `(1, 10, 0)`. Gecersiz/bos -> `None`.

    `+yapim` ve `-onsurum` ekleri ATILIR: magazada gorunen surum
    "1.1.1"dir, "1.1.1+6" degil.
    """
    if not surum:
        return None
    metin = str(surum).strip()
    # Yapim ve on-surum ekleri karsilastirmaya GIRMEZ.
    for ayirac in ("+", "-"):
        metin = metin.split(ayirac, 1)[0]
    metin = metin.strip()
    e = _BICIM.match(metin)
    if not e:
        return None
    return (int(e.group(1)), int(e.group(2) or 0), int(e.group(3) or 0))


def karsilastir(a: str, b: str) -> int | None:
    """`a` < `b` ise -1, esitse 0, buyukse 1. Biri gecersizse `None`."""
    x, y = ayristir(a), ayristir(b)
    if x is None or y is None:
        return None
    return -1 if x < y else (0 if x == y else 1)


def eski_mi(surum: str | None, esik: str | None) -> bool:
    """`surum` < `esik` mi.

    ESIK TANIMSIZ ya da SURUM OKUNAMAZ ise **False** — yani "eski
    degil". Karar burada tek yerde toplanir cunku "belirsizlikte ne
    yapmali" sorusunun cevabi TEK olmali: KULLANICIYI ENGELLEME.
    """
    k = karsilastir(surum or "", esik or "")
    return k is not None and k < 0


#: Uc karar. Metin degil KIMLIK: istemci bunlara gore dallanir, cevirmez.
GUNCEL = "guncel"
ONERILEN = "onerilen"
ZORUNLU = "zorunlu"


def karar(
    surum: str | None, asgari: str | None, onerilen: str | None
) -> str:
    """Politika karari — TEK YER.

    ZORUNLU once bakilir: iki esik de asilmissa daha KISITLAYICI olan
    kazanir. Aksi hâlde operator asgari esigi yukseltip onerileni
    guncellemeyi unuttugunda zorunlu guncelleme sessizce "onerilen"e
    duserdi.
    """
    if eski_mi(surum, asgari):
        return ZORUNLU
    if eski_mi(surum, onerilen):
        return ONERILEN
    return GUNCEL
