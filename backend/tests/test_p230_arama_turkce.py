"""(P230 §3) ARAMA — TURKCE HARF DUYARSIZ.

OLCULEN EKSIK: arama duz `ILIKE` kullaniyordu. "cekmekoy" yazan kullanici
"Çekmeköy"u BULAMIYORDU — ve bos sonuc, arama hatalarinin EN KOTUSU:
kullanici kaydin OLMADIGINI sanir, aramanin calismadigini degil.

NEDEN `unaccent` DEGIL: `ı/İ` Latin-1 aksanli harf DEGILDIR; `unaccent`
`ı`yi `i`ye cevirmez. Turkce icin ozel katlama sart.

NEDEN IKI TARAFTA: yalniz DESENI katlamak, "Çekmeköy" yazani bulamaz hale
getirirdi (kolon hala `ö` tasiyor). Ikisi de ASCII'ye indiriliyor.
"""
from __future__ import annotations

import uuid

import pytest


@pytest.fixture
def yon(client, world):
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["yonetici_a"]["email"],
        "password": world["yonetici_a"]["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def turkce_gorev(client, yon):
    """Arama hedefi — adinda BES Turkce harf var."""
    ad = f"Çöp Şütü Bakımı {uuid.uuid4().hex[:5]}"
    r = client.post("/tasks", headers=yon, json={"ad": ad})
    assert r.status_code == 201, r.text
    return ad


def _ara(client, yon, q):
    r = client.get(f"/arama?q={q}", headers=yon)
    assert r.status_code == 200, r.text
    return [v["baslik"] for v in r.json()["items"]]


def test_ASCII_YAZAN_TURKCE_KAYDI_BULUR(client, yon, turkce_gorev):
    """Klavyesi Turkce olmayan ya da hizli yazan kullanici."""
    assert any("Çöp" in b for b in _ara(client, yon, "cop sutu")), (
        "ASCII desen Turkce kaydi bulamadi")


def test_TURKCE_YAZAN_DA_BULUR(client, yon, turkce_gorev):
    """Ters yon: yalniz deseni katlasaydik BU dusordu."""
    assert any("Çöp" in b for b in _ara(client, yon, "Çöp Şütü"))


def test_NOKTASIZ_I_VE_NOKTALI_I_AYRISMAZ(client, yon):
    """`ı`/`i` ayrimi Turkce aramanin en sik takildigi yer; `unaccent`
    bunu COZMEZ."""
    ad = f"Isıtma Bakımı {uuid.uuid4().hex[:5]}"
    r = client.post("/tasks", headers=yon, json={"ad": ad})
    assert r.status_code == 201, r.text
    assert any("Isıtma" in b for b in _ara(client, yon, "isitma"))


def test_BUYUK_KUCUK_HARF_AYRISMAZ(client, yon, turkce_gorev):
    assert any("Çöp" in b for b in _ara(client, yon, "ÇÖP"))


def test_TEK_HARF_REDDEDILIR(client, yon):
    """Tek harf butun tesisi tarar ve kullaniciya da bir sey anlatmaz."""
    r = client.get("/arama?q=a", headers=yon)
    assert r.status_code == 422, r.text


def test_ROL_SUZGECI_SUNUCUDA(client, world, turkce_gorev):
    """Sakin GOREV kaynagini gormemeli — suzgec istemcide degil sunucuda.

    Mobil arama ekrani ayni ucu kullaniyor; ikinci bir uc yazsaydik rol
    kumelerinin IKINCI bir kopyasi olur ve biri eskidiginde sessiz bir
    yetki sapmasi dogardi.
    """
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["resident_a"]["email"],
        "password": world["resident_a"]["password"]})
    assert r.status_code == 200, r.text
    h = {"Authorization": f"Bearer {r.json()['access_token']}"}
    v = client.get("/arama?q=cop sutu", headers=h)
    assert v.status_code == 200, v.text
    assert all(x["kaynak"] != "gorev" for x in v.json()["items"]), v.json()
