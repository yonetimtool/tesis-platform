"""(P202) SURUM KARSILASTIRMASI — sinir durumlari.

Kilitlenen kusur: metin karsilastirmasi. `"1.10.0" < "1.9.0"` metin
olarak DOGRU, surum olarak YANLIS. Sessiz bir kusurdur: 1.9.0
yayindayken kimse fark etmez; 1.10.0 cikinca TUM kullanicilar "guncel"
sayilir ve zorunlu guncelleme tam ihtiyac aninda calismaz.
"""
from __future__ import annotations

import pytest

from app.surum import GUNCEL, ONERILEN, ZORUNLU, ayristir, eski_mi, karar, karsilastir


@pytest.mark.parametrize(
    "a,b,beklenen",
    [
        # ISTEKTE ACIKCA SORULAN SINIRLAR
        ("1.9.0", "1.10.0", -1),   # metin karsilastirmasi bunu TERS yapar
        ("1.10.0", "1.9.0", 1),
        ("1.1.1", "1.1.10", -1),   # yama alaninda ayni tuzak
        ("1.1.10", "1.1.1", 1),
        ("1.1.1", "1.1.1", 0),     # esitlik
        # Genel
        ("2.0.0", "1.99.99", 1),
        ("1.0.0", "1.0.1", -1),
        ("0.9.9", "1.0.0", -1),
        # Eksik parca SIFIR sayilir
        ("1.2", "1.2.0", 0),
        ("1", "1.0.0", 0),
        ("1.2", "1.2.1", -1),
        # Yapim numarasi KARSILASTIRMAYA GIRMEZ (pubspec "1.1.1+6")
        ("1.1.1+6", "1.1.1", 0),
        ("1.1.1+9", "1.1.2", -1),
        ("1.1.1-beta", "1.1.1", 0),
    ],
)
def test_KARSILASTIRMA(a, b, beklenen):
    assert karsilastir(a, b) == beklenen, f"{a} vs {b}"


@pytest.mark.parametrize(
    "gecersiz",
    ["", None, "surum-3", "1.2.3.4", "a.b.c", "1.2.x", " ", "v1.2.3", "1..2"],
)
def test_GECERSIZ_BICIM_None_doner(gecersiz):
    assert ayristir(gecersiz) is None


def test_GECERSIZ_BICIM_KULLANICIYI_KILITLEMEZ():
    """Panele yanlislikla "surum-3" yazan bir operator TUM kullanicilari
    disari atmamali. Belirsizlikte karar: ENGELLEME."""
    assert eski_mi("1.0.0", "surum-3") is False
    assert eski_mi("bozuk", "9.9.9") is False
    assert eski_mi(None, "9.9.9") is False
    assert karar("bozuk", "9.9.9", "9.9.9") == GUNCEL


def test_ESIK_BOSSA_o_seviye_KAPALI():
    """Goc uygulanir uygulanmaz kimse kilitlenmemeli: iki esik de bos
    dogar ve bos = seviye kapali."""
    assert karar("1.0.0", None, None) == GUNCEL
    assert karar("1.0.0", "", "") == GUNCEL


def test_KARAR_UC_SEVIYE():
    assert karar("1.0.0", "1.2.0", "1.5.0") == ZORUNLU
    assert karar("1.3.0", "1.2.0", "1.5.0") == ONERILEN
    assert karar("1.5.0", "1.2.0", "1.5.0") == GUNCEL
    assert karar("2.0.0", "1.2.0", "1.5.0") == GUNCEL


def test_ZORUNLU_ONERILENI_EZER():
    """Iki esik de asilmissa daha KISITLAYICI olan kazanir. Aksi hâlde
    operator asgariyi yukseltip onerileni guncellemeyi unuttugunda
    zorunlu guncelleme sessizce "onerilen"e duserdi."""
    assert karar("1.0.0", "1.9.0", "1.9.0") == ZORUNLU


def test_ESIT_SURUM_ZORUNLU_DEGIL():
    """Esigin KENDISI kabul edilir; "asgari" dahil demektir. Aksi hâlde
    operator 1.2.0 yazinca 1.2.0 kullanicilari da disari atilirdi."""
    assert karar("1.2.0", "1.2.0", None) == GUNCEL
