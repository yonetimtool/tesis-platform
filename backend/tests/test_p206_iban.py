"""(P206 §3) IBAN — dogrulama, bicimleme, banka cozumu (SUNUCU tarafi).

ORNEK KUME `admin-web/tests/p206-iban.test.ts` ile AYNIDIR: kural iki
yerde yazili (sunucu son sozu soyler, istemci kullaniciyi 422 beklemeden
uyarir) ve ayrisma riskine karsi ikisi de AYNI orneklerle olculur.

ESKI DENETIM `^TR[0-9]{24}$` idi ve iki ucta birden yanlisti:
  * yurt disindaki tesis kendi IBAN'ini GIREMIYORDU,
  * tek hanesi yanlis TR IBAN'i KABUL EDILIYORDU (para yanlis hesaba
    gider, ancak kaybolunca fark edilir).
"""
from __future__ import annotations

import pytest

from app.iban import (
    banka_adi_coz,
    banka_kodu,
    iban_bicimle,
    iban_hatasi,
    iban_temizle,
)

GECERLI = [
    "TR330006100519786457841326",
    "TR33 0006 1005 1978 6457 8413 26",
    "tr330006100519786457841326",
    "DE89370400440532013000",
    "GB82WEST12345698765432",
    "NO9386011117947",
]

GECERSIZ = [
    ("", "iban_bos"),
    ("xx", "iban_bicim"),
    ("TR33000610051978645784132", "iban_uzunluk"),
    ("TR330006100519786457841327", "iban_saglama"),
    ("DE89370400440532013001", "iban_saglama"),
]


@pytest.mark.parametrize("ornek", GECERLI)
def test_GECERLI_ornekler_kabul(ornek):
    assert iban_hatasi(ornek) is None, ornek


@pytest.mark.parametrize("ornek,kod", GECERSIZ)
def test_GECERSIZ_ornekler_DOGRU_KIMLIKLE_reddedilir(ornek, kod):
    assert iban_hatasi(ornek) == kod, ornek


def test_MOD97_regexin_yakalayamadigini_yakalar():
    import re

    bozuk = "TR330006100519786457841327"
    assert re.match(r"^TR[0-9]{24}$", bozuk), "eski regex bunu GECIRIYORDU"
    assert iban_hatasi(bozuk) == "iban_saglama"


def test_DEPODA_bosluksuz_EKRANDA_dorderli():
    assert iban_temizle("tr33 0006-1005 1978 6457 8413 26") == (
        "TR330006100519786457841326"
    )
    assert iban_bicimle("TR330006100519786457841326") == (
        "TR33 0006 1005 1978 6457 8413 26"
    )


def test_BANKA_KODU_son_dort_hane():
    assert banka_kodu("TR620006200000000000000000") == "0062"
    assert banka_adi_coz("TR620006200000000000000000") == "Garanti BBVA"
    assert banka_adi_coz("TR100001000000000000000000") == "Ziraat Bankası"


def test_TR_DISINDA_banka_UYDURULMAZ():
    assert banka_kodu("DE89370400440532013000") is None
    assert banka_adi_coz("DE89370400440532013000") is None


# ============================ UC DAVRANISI ================================= #

def _headers(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_GECERSIZ_IBAN_KAYDEDILEMEZ_ve_GECERLI_KANONIK_saklanir(client, world):
    """Kabul kriteri 7: gecersiz IBAN kaydedilemiyor.

    Ve gecerli olan BOSLUKSUZ saklaniyor: ayni IBAN'in iki farkli
    yazimla iki kayit uretmesi, IBAN'i esleme anahtari olarak kullanan
    banka ekstresi eslestirmesini (P191) bozardi.
    """
    import uuid as _u

    h = _headers(client, world["slug_a"], world["yonetici_a"])
    govde = {"kod": f"IB{_u.uuid4().hex[:4]}", "ad": "IBAN Kasa", "banka_mi": True}

    kotu = client.post("/kasalar", headers=h, json={
        **govde, "iban": "TR330006100519786457841327"})
    assert kotu.status_code == 422, kotu.text

    iyi = client.post("/kasalar", headers=h, json={
        **govde, "iban": "TR33 0006 1005 1978 6457 8413 26"})
    assert iyi.status_code == 201, iyi.text
    assert iyi.json()["iban"] == "TR330006100519786457841326"

    # YURT DISI IBAN'I DA KABUL: sistem yalniz Turkiye'de calismak
    # zorunda degil (K3.1).
    yd = client.post("/kasalar", headers=h, json={
        **govde, "kod": f"DE{_u.uuid4().hex[:4]}", "iban": "DE89370400440532013000"})
    assert yd.status_code == 201, yd.text
