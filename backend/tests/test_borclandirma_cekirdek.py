"""Borclandirma CEKIRDEGI (P28) — saf hesaplar, veritabani YOK.

Bu testler urunun KURALINI kilitler: hedefleme, gecikme, kurus kaybi,
sayac dagitimi. Router testleri ayri dosyada.
"""
from __future__ import annotations

from datetime import date

import pytest

from app.borclandirma import (
    Bag,
    esit_dagit,
    gecikme_kurus,
    hedef_sec,
    sayac_tuketim_dagitimi,
    tipe_gore_dagit,
)


# ------------------------------ hedefleme ----------------------------------- #
def test_kiraci_oncelikli_KIRACIYA_yazar():
    baglar = [Bag("m1", "malik"), Bag("k1", "kiraci")]
    assert hedef_sec(baglar, "kiraci_oncelikli") == "k1"


def test_kiraci_YOKSA_malike_duser():
    assert hedef_sec([Bag("m1", "malik")], "kiraci_oncelikli") == "m1"


def test_malik_kurali_KIRACI_VARKEN_de_malige_yazar():
    """Yatirim/demirbas: kiraci tasinsa da yukumluluk MALIKTE kalir."""
    baglar = [Bag("m1", "malik"), Bag("k1", "kiraci")]
    assert hedef_sec(baglar, "malik") == "m1"


def test_malik_kurali_MALIK_YOKSA_None():
    """Uydurma bir kisi secmek (orn. 'ilk bag') YANLIS kisiyi borclandirirdi."""
    assert hedef_sec([Bag("k1", "kiraci")], "malik") is None


def test_ROL_TIPI_BOS_bag_MALIK_SAYILMAZ():
    """P23'te tip opsiyoneldir; "bilinmiyor"u malik saymak yatirim giderini
    yanlis kisiye yazardi."""
    belirsiz = [Bag("x1", None)]
    assert hedef_sec(belirsiz, "malik") is None
    # ...ama kiraci_oncelikli'nin SON CARESIDIR (daireye yazmaktan iyidir).
    assert hedef_sec(belirsiz, "kiraci_oncelikli") == "x1"


def test_bag_YOKSA_daireye_yazilir():
    assert hedef_sec([], "kiraci_oncelikli") is None
    assert hedef_sec([], "malik") is None


# ------------------------------- gecikme ------------------------------------ #
def test_gecikme_TAM_AY_uzerinden():
    """45 gunluk gecikme "1 tam ay"dir; kismi ay ORANTILANMAZ."""
    tutar = 100_000  # 1.000,00 TL
    assert gecikme_kurus(tutar, date(2026, 1, 10), date(2026, 2, 9), 2) == 0
    assert gecikme_kurus(tutar, date(2026, 1, 10), date(2026, 2, 10), 2) == 2000
    assert gecikme_kurus(tutar, date(2026, 1, 10), date(2026, 2, 24), 2) == 2000
    assert gecikme_kurus(tutar, date(2026, 1, 10), date(2026, 3, 10), 2) == 4000


def test_gecikme_BASIT_faiz_bilesik_DEGIL():
    """Bilesik faiz uzun gecikmelerde ana paranin katlarina cikardi."""
    tutar = 100_000
    on_ay = gecikme_kurus(tutar, date(2026, 1, 1), date(2026, 11, 1), 5)
    assert on_ay == 50_000, "10 ay x %5 = %50 (basit)"


def test_vade_YOKSA_gecikme_YOK():
    """Vadesi belirlenmemis bir borc gecikmis SAYILAMAZ."""
    assert gecikme_kurus(100_000, None, date(2030, 1, 1), 10) == 0


def test_oran_SIFIR_ya_da_uygulama_KAPALI_ise_sifir():
    assert gecikme_kurus(100_000, date(2020, 1, 1), date(2026, 1, 1), 0) == 0
    assert gecikme_kurus(
        100_000, date(2020, 1, 1), date(2026, 1, 1), 5, uygula=False
    ) == 0


def test_gecikme_AY_SONU_kaymasi():
    """31 Ocak vadeli bir borc 28 Subat'ta 1 ay gecikmistir (Subat'ta 31 yok)."""
    assert gecikme_kurus(100_000, date(2026, 1, 31), date(2026, 2, 28), 1) == 1000


# ---------------------------- kurus kaybi ----------------------------------- #
@pytest.mark.parametrize("toplam,adet", [(10001, 3), (100, 7), (1, 5), (999999, 13)])
def test_esit_dagit_KURUS_KAYBETMEZ(toplam, adet):
    paylar = esit_dagit(toplam, adet)
    assert len(paylar) == adet
    assert sum(paylar) == toplam, "kurus buharlasti"
    # Fark en fazla 1 kurus olmali (adil dagitim).
    assert max(paylar) - min(paylar) <= 1


def test_esit_dagit_sifir_daire():
    assert esit_dagit(1000, 0) == []


# ---------------------------- tipe gore ------------------------------------- #
def test_tipe_gore_TANIMSIZ_daire_yedege_duser():
    assert tipe_gore_dagit([1000, None, 3000], 2500) == [1000, 2500, 3000]


def test_tipe_gore_YEDEK_de_yoksa_daire_ATLANIR():
    """Sessizce 0 borclandirmak, yonetimin fark etmedigi eksik tahakkuk
    uretirdi."""
    assert tipe_gore_dagit([1000, None], None) == [1000, None]


# ------------------------------- sayac -------------------------------------- #
def test_sayac_ortak_alan_YUZDESI_uygulanir():
    # Ana 100 birim, daireler 30+30+30=90 -> 10 birim ortak; %50'si dagitilir.
    borclar, ortak = sayac_tuketim_dagitimi(100, [30, 30, 30], 1000, 50)
    assert ortak == 5000, "10 birim x %50 x 10,00 TL"
    # Her daire kendi tuketimi (30 x 1000 = 30000) + ortak payi.
    assert sum(borclar) == 90_000 + 5000
    assert max(borclar) - min(borclar) <= 1


def test_sayac_yuzde_YOKSA_farkin_TAMAMI_dagitilir():
    borclar, ortak = sayac_tuketim_dagitimi(100, [30, 30, 30], 1000, None)
    assert ortak == 10_000
    assert sum(borclar) == 100_000


def test_sayac_yuzde_SIFIR_ortak_alani_dagitmaz():
    borclar, ortak = sayac_tuketim_dagitimi(100, [30, 30, 30], 1000, 0)
    assert ortak == 0
    assert sum(borclar) == 90_000


def test_sayac_NEGATIF_fark_SIFIRLANIR():
    """Daire toplami anadan buyukse (olcum hatasi) dairelere NEGATIF borc
    yazmak ALACAK uretirdi."""
    borclar, ortak = sayac_tuketim_dagitimi(50, [30, 30], 1000, None)
    assert ortak == 0
    assert borclar == [30_000, 30_000]
