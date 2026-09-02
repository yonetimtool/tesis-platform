"""(P203 §5) FAZLA MESAI HESABI — yasal kural ve sinir durumlari."""
from __future__ import annotations

import datetime as dt

import pytest

from app.mesai import (
    AYLIK_SAAT_BOLENI,
    HAFTALIK_NORMAL_SAAT,
    KisiOzeti,
    ay_araligi,
    saatlik_ucret,
)


def test_SAATLIK_UCRET_verilmisse_O_kullanilir():
    assert saatlik_ucret(10_000, 2_250_000) == 10_000


def test_SAATLIK_YOKSA_AYLIKTAN_turetilir():
    """225 = 30 gun x 7,5 saat — Turkiye'de standart bolen."""
    assert saatlik_ucret(None, 2_250_000) == 2_250_000 // AYLIK_SAAT_BOLENI
    assert AYLIK_SAAT_BOLENI == 225


def test_UCRET_TANIMSIZSA_None_SIFIR_DEGIL():
    """Sifir kabul edip 0 TL mesai yazmak, yoneticiye "mesai yok"
    demenin sessiz ve YANLIS yoluydu."""
    assert saatlik_ucret(None, None) is None
    assert saatlik_ucret(0, 0) is None
    k = KisiOzeti(user_id="u", ad="A", saatlik_ucret_kurus=None)
    k.ekle(dt.date(2026, 9, 2), 60.0)
    assert k.fazla_saat == 15.0
    assert k.fazla_mesai_kurus(1.5) is None


def test_HAFTALIK_ESIK_45():
    assert HAFTALIK_NORMAL_SAAT == 45.0
    k = KisiOzeti(user_id="u", ad="A", saatlik_ucret_kurus=10_000)
    k.ekle(dt.date(2026, 9, 2), 45.0)
    assert k.fazla_saat == 0.0
    k2 = KisiOzeti(user_id="u", ad="A", saatlik_ucret_kurus=10_000)
    k2.ekle(dt.date(2026, 9, 2), 46.0)
    assert k2.fazla_saat == 1.0


def test_FAZLA_MESAI_HAFTA_HAFTA_hesaplanir():
    """AY TOPLAMI UZERINDEN HESAPLAMAK YANLIS OLURDU.

    Bir hafta 60, otekinde 30 saat calisan biri: ay toplami 90, ayin
    iki haftasi icin normal sinir 90 — "fazla mesai yok" cikardi.
    Oysa ILK HAFTADA 15 saat fazla calisma DOGMUSTUR ve ikinci
    haftanin azligi onu SILMEZ (4857 md. 41 haftalik esige bakar).
    """
    k = KisiOzeti(user_id="u", ad="A", saatlik_ucret_kurus=10_000)
    k.ekle(dt.date(2026, 9, 2), 60.0)    # 1. hafta (carsamba)
    k.ekle(dt.date(2026, 9, 9), 30.0)    # 2. hafta
    assert k.toplam_saat == 90.0
    assert k.fazla_saat == 15.0, "ay toplamiyla hesaplansaydi 0 cikardi"


def test_MESAI_TUTARI_katsayiyla_carpilir():
    """(4857/41) Normal saat ucretinin YUZDE ELLI FAZLASI."""
    k = KisiOzeti(user_id="u", ad="A", saatlik_ucret_kurus=10_000)
    k.ekle(dt.date(2026, 9, 2), 55.0)          # 10 saat fazla
    assert k.fazla_mesai_kurus(1.5) == 150_000  # 10 * 10.000 * 1.5


def test_KATSAYI_DEGISTIRILEBILIR():
    """Toplu is sozlesmesi daha yuksek oran belirleyebilir; yazilim
    mesru bir sozlesmeyi imkansiz kilmamali."""
    k = KisiOzeti(user_id="u", ad="A", saatlik_ucret_kurus=10_000)
    k.ekle(dt.date(2026, 9, 2), 55.0)
    assert k.fazla_mesai_kurus(2.0) == 200_000


@pytest.mark.parametrize("yil,ay,son_gun", [
    (2026, 1, 31), (2026, 2, 28), (2024, 2, 29), (2026, 4, 30), (2026, 12, 31),
])
def test_AY_ARALIGI_sinir_durumlari(yil, ay, son_gun):
    bas, son = ay_araligi(yil, ay)
    assert bas == dt.date(yil, ay, 1)
    assert son.day == son_gun
