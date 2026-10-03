"""(P253 A2) Hareket listesi — serbest arama (`q`) + durum suzgeci.

Web ve mobil ayni parametreleri gonderir. Arama Turkce harf katlamali
(`sahin` -> "ŞAHİN"), `%`/`_` literal; durum enum disi deger 422.
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
def ortam(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    iz = uuid.uuid4().hex[:6]
    kasa = client.post("/kasalar", headers=h, json={
        "kod": f"KA{iz}", "ad": "Arama Kasa", "acilis_bakiye_kurus": 0}).json()["id"]
    firma = client.post("/firmalar", headers=h, json={"ad": f"Şahin Asansör {iz}"})
    assert firma.status_code == 201, firma.text
    satirlar = [
        {"tip": "gider", "tutar_kurus": 1000, "kasa_id": kasa, "durum": "onay_bekliyor",
         "aciklama": f"Çatı onarımı {iz}"},
        {"tip": "gider", "tutar_kurus": 2000, "kasa_id": kasa, "durum": "odendi",
         "aciklama": f"Bakım {iz}", "firma_id": firma.json()["id"]},
        {"tip": "gider", "tutar_kurus": 3000, "kasa_id": kasa, "durum": "odendi",
         "aciklama": f"100% indirim {iz}"},
    ]
    r = client.post("/finans/hareketler", headers=h, json={"satirlar": satirlar})
    assert r.status_code == 201, r.text
    return h, iz, kasa


def _ara(client, h, kasa, **p):
    r = client.get("/finans/hareketler", headers=h, params={"kasa_id": kasa, "limit": 200, **p})
    assert r.status_code == 200, r.text
    return sorted(x["tutar_kurus"] for x in r.json()["items"])


def test_ARAMA_aciklama_firma_ve_TURKCE_KATLAMA(client, ortam):
    h, iz, kasa = ortam
    assert _ara(client, h, kasa, q="cati onarimi") == [1000]
    assert _ara(client, h, kasa, q="SAHIN") == [2000]  # firma adi, katlamali
    assert _ara(client, h, kasa, q=iz) == [1000, 2000, 3000]


def test_ARAMA_joker_LITERAL(client, ortam):
    h, _, kasa = ortam
    assert _ara(client, h, kasa, q="%") == [3000]
    assert _ara(client, h, kasa, q="_") == []


def test_DURUM_SUZGECI(client, ortam):
    h, iz, kasa = ortam
    assert _ara(client, h, kasa, durum="onay_bekliyor") == [1000]
    assert _ara(client, h, kasa, durum="odendi", q=iz) == [2000, 3000]
    r = client.get("/finans/hareketler", headers=h, params={"durum": "uydurma"})
    assert r.status_code == 422
