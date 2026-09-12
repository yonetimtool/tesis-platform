"""(P223 §3) OTOPARK SAYACI — kapasite, yonetici isaretlemesi, bos yer.

===========================================================================
OLCULEN BOSLUKLAR
===========================================================================
Sayac ALTYAPISI zaten vardi (`vehicle_pass` acik gecis sayimi +
`GET /parking/occupancy`). Eksik olan UC sey vardi:

  1. `tenant.otopark_kapasite` veritabaninda ve semada VARDI ama HICBIR
     EKRANDA girilemiyordu -> `oran` her zaman null, doluluk yuzdesi
     hicbir zaman gorunmuyordu.
  2. Gecisi yalnizca admin+security acip kapatabiliyordu. Kucuk sitelerde
     7/24 guvenlik yok; YONETICI sayaci duzeltemiyordu — "elle
     isaretlenebilsin" istegi tam olarak bu yuzden karsilanmiyordu.
  3. Sakin bos yer sayisini HICBIR YERDE gormuyordu.

Uctan uca suruldu (dev):
    kapasite 50 yazildi          -> 200
    doluluk                      -> {'kapasite': 50, 'dolu': 3, 'oran': 6}
    yonetici GIRIS isaretledi    -> 201
    doluluk                      -> dolu 4, oran 8
    yonetici CIKIS isaretledi    -> 200
    doluluk                      -> dolu 3, oran 6
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


@pytest.fixture
def sakin(client, world):
    return _h(client, world["slug_a"], world["resident_a"])


@pytest.fixture
def kapasite_geri_al(client, yon):
    """Kapasite ayari DB'de KALICI — birakilan deger sonraki testleri kirar."""
    onceki = client.get("/tenant/settings", headers=yon).json().get(
        "otopark_kapasite")
    yield
    client.patch("/tenant/settings", headers=yon,
                 json={"otopark_kapasite": onceki})


def _plaka() -> str:
    return "34" + uuid.uuid4().hex[:5].upper()


def _doluluk(client, h) -> dict:
    r = client.get("/parking/occupancy", headers=h)
    assert r.status_code == 200, r.text
    return r.json()


def test_YONETICI_GIRIS_CIKIS_ISARETLEYEBILIR(client, yon, kapasite_geri_al):
    """Kusurun ta kendisi: yonetici `_OPERATOR` degildi ve 403 aliyordu."""
    client.patch("/tenant/settings", headers=yon, json={"otopark_kapasite": 50})
    once = _doluluk(client, yon)["dolu"]

    g = client.post("/vehicle-passes", headers=yon, json={"plaka": _plaka()})
    assert g.status_code == 201, g.text
    assert _doluluk(client, yon)["dolu"] == once + 1

    ck = client.post(f"/vehicle-passes/{g.json()['id']}/checkout", headers=yon)
    assert ck.status_code == 200, ck.text
    assert _doluluk(client, yon)["dolu"] == once


def test_KAPASITE_GIRILINCE_ORAN_HESAPLANIR(client, yon, kapasite_geri_al):
    """Kapasite YOKKEN oran null; girilince sayi. Kusur, kapasitenin
    hicbir ekrandan girilememesiydi — uc zaten hazirdi."""
    client.patch("/tenant/settings", headers=yon, json={"otopark_kapasite": None})
    assert _doluluk(client, yon)["oran"] is None

    client.patch("/tenant/settings", headers=yon, json={"otopark_kapasite": 100})
    d = _doluluk(client, yon)
    assert d["kapasite"] == 100
    assert d["oran"] == round(100 * d["dolu"] / 100)


def test_SAKIN_DOLULUGU_OKUYABILIR_ama_ISARETLEYEMEZ(client, yon, sakin,
                                                     kapasite_geri_al):
    """Sakin bos yeri GORUR; giris/cikis ISARETLEYEMEZ.

    Kendi aracini "girdi" isaretleyen sakin baskasinin yerini de
    doldurabilirdi ve sayac dogrulanamaz hale gelirdi.
    """
    client.patch("/tenant/settings", headers=yon, json={"otopark_kapasite": 40})
    d = _doluluk(client, sakin)
    assert d["kapasite"] == 40 and isinstance(d["dolu"], int)

    r = client.post("/vehicle-passes", headers=sakin, json={"plaka": _plaka()})
    assert r.status_code == 403, r.status_code


def test_KAPASITE_ASILIRSA_ORAN_100_USTU_OLUR_ama_SAYI_GERCEK_KALIR(
        client, yon, kapasite_geri_al):
    """Elle isaretlemede kapasite asilabilir; sayiyi KIRPMAK veriyi
    yalan soylemek olurdu. Istemci "bos yer"i 0'da tabanlar (negatif
    bos yer kullaniciya anlamsiz gelir) ama SUNUCU gercek sayiyi doner."""
    d0 = _doluluk(client, yon)
    if d0["dolu"] == 0:
        g = client.post("/vehicle-passes", headers=yon, json={"plaka": _plaka()})
        assert g.status_code == 201
    dolu = _doluluk(client, yon)["dolu"]
    client.patch("/tenant/settings", headers=yon, json={"otopark_kapasite": 1})
    d = _doluluk(client, yon)
    assert d["dolu"] == dolu
    if dolu > 1:
        assert d["oran"] > 100, d
