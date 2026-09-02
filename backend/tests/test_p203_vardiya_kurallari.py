"""(P203 §4) VARDIYA KURALLARI — geceyi asma, cakisma, sure.

Kilitlenen kusur sinifi: geceyi asan vardiyanin "eksi saat" sayilmasi.
20:00-08:00 icin naif cikarma -12 saat verir ve hem cakisma hem sure
hesabi SESSIZCE yanlis olur.
"""
from __future__ import annotations

import datetime as dt

import pytest

from app.vardiya import (
    GUNLUK_AZAMI_SAAT,
    HAFTALIK_NORMAL_SAAT,
    cakisiyor_mu,
    saat_farki,
    vardiya_araligi,
)

G = dt.date(2026, 9, 2)


def _ara(bas: str, son: str, tarih: dt.date = G):
    return vardiya_araligi(
        tarih, dt.time.fromisoformat(bas), dt.time.fromisoformat(son)
    )


def test_GUNDUZ_vardiyasi_ayni_gun():
    bas, son = _ara("08:00", "16:00")
    assert bas.date() == G and son.date() == G
    assert saat_farki(bas, son) == 8.0


def test_GECEYI_ASAN_vardiya_ERTESI_GUNE_tasar():
    """Kusurun kendisi: naif cikarma -12 saat verirdi."""
    bas, son = _ara("20:00", "08:00")
    assert son.date() == G + dt.timedelta(days=1)
    assert saat_farki(bas, son) == 12.0


def test_TAM_24_SAATLIK_vardiya():
    """bitis == baslangic: sifir degil, TAM GUN."""
    bas, son = _ara("08:00", "08:00")
    assert saat_farki(bas, son) == 24.0


def test_CAKISAN_araliklar():
    assert cakisiyor_mu(_ara("08:00", "16:00"), _ara("12:00", "20:00"))
    assert cakisiyor_mu(_ara("08:00", "16:00"), _ara("08:00", "16:00"))
    # Geceyi asan vardiya ERTESI GUNUN sabah vardiyasiyla cakisir.
    gece = _ara("20:00", "08:00")
    ertesi_sabah = _ara("06:00", "14:00", G + dt.timedelta(days=1))
    assert cakisiyor_mu(gece, ertesi_sabah), (
        "geceyi asan vardiya ertesi gunun sabahiyla cakisiyor — "
        "tarihi yok saymak bunu KACIRIRDI"
    )


def test_UC_UCA_EKLENEN_vardiyalar_CAKISMAZ():
    """08:00-16:00 ve 16:00-24:00 ardisiktir, cakisma DEGIL. `<=`
    kullanmak mesru bir devir teslimi engellerdi."""
    assert not cakisiyor_mu(_ara("08:00", "16:00"), _ara("16:00", "23:59"))


def test_AYRI_GUNLERDEKI_ayni_vardiya_CAKISMAZ():
    a = _ara("08:00", "16:00")
    b = _ara("08:00", "16:00", G + dt.timedelta(days=1))
    assert not cakisiyor_mu(a, b)


def test_YASAL_SINIRLAR_kayit_altinda():
    """Sayilar KODDA TEK YERDE ve gerekcesi modul basliginda.

    Degistirilmeleri gerekirse (kanun degisir) tek yer aranir; testin
    kendisi de o degeri kilitler ki "neden 11" sorusu yanitsiz
    kalmasin.
    """
    assert GUNLUK_AZAMI_SAAT == 11.0     # 4857/63 — UYARI esigi
    assert HAFTALIK_NORMAL_SAAT == 45.0  # 4857/63 — ustu FAZLA MESAI
