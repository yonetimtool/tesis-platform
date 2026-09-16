"""(P238) CIHAZ KAYDINDA UYGULAMA SURUMU — YALNIZ VERI TOPLAMA.

===========================================================================
BU TURDA PUSH MANTIGI YAZILMADI
===========================================================================
"Asgari surum yukseltilince eski surumdeki cihazlara bildirim" 1.5.0'a
birakildi (`docs/P238-kararlar.md` §2). Burada olculen tek sey: surum
KAYDEDILIYOR ve KAYBOLMUYOR. Cunku kolonun bugun acilmasinin TEK sebebi
budur — 1.5.0 geldiginde 1.4.x istemciler gorunur olsun.

Dolayisiyla en onemli test "gonderilmeyince MEVCUT DEGER KORUNUR":
uygulama her acilista cihazi yeniden kaydeder ve bir yukseltmede alanin
gecici olarak bos gelmesi, daha once ogrenilmis surumu SILMEMELI.
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def h(client, world):
    """ADMIN: `GET /devices` yalniz adminde (teshis ucu). Kayit her rolde
    yapilabiliyor ama okuma icin ayni oturumu kullanmak testi sadelestirir."""
    return _headers(client, world["slug_a"], world["admin_a"])


def _kaydet(client, h, token, **alanlar):
    govde = {"fcm_token": token, "platform": "android"}
    govde.update(alanlar)
    r = client.post("/devices", headers=h, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


def _oku(client, h, token):
    r = client.get("/devices?limit=200", headers=h)
    assert r.status_code == 200, r.text
    return next(d for d in r.json()["items"] if d["fcm_token"] == token)


def test_SURUM_KAYDEDILIR_ve_okunur(client, h):
    token = f"p238-{uuid.uuid4().hex}"
    _kaydet(client, h, token, uygulama_surum="1.4.1")
    assert _oku(client, h, token)["uygulama_surum"] == "1.4.1"


def test_GONDERILMEZSE_MEVCUT_DEGER_KORUNUR(client, h):
    """Uygulama her acilista cihazi yeniden kaydeder. Bir yukseltmede
    alanin gecici olarak bos gelmesi, ogrenilmis surumu SILMEMELI —
    silseydi cihaz "surumu bilinmiyor"a duser ve 1.5.0'daki hedefleme
    onu elerdi."""
    token = f"p238-{uuid.uuid4().hex}"
    _kaydet(client, h, token, uygulama_surum="1.4.1")
    _kaydet(client, h, token)  # surum YOK
    assert _oku(client, h, token)["uygulama_surum"] == "1.4.1"


def test_YENI_SURUM_ESKISINI_EZER(client, h):
    token = f"p238-{uuid.uuid4().hex}"
    _kaydet(client, h, token, uygulama_surum="1.4.1")
    _kaydet(client, h, token, uygulama_surum="1.5.0")
    assert _oku(client, h, token)["uygulama_surum"] == "1.5.0"


def test_SURUMSUZ_KAYIT_KABUL_EDILIR(client, h):
    """Alani gondermeyen surumler sahada calisiyor; 'surumu bilinmeyen
    cihaz' GECERLI bir durumdur."""
    token = f"p238-{uuid.uuid4().hex}"
    _kaydet(client, h, token)
    assert _oku(client, h, token)["uygulama_surum"] is None


def test_COK_UZUN_SURUM_REDDEDILIR(client, h):
    """Sema siniri (64) — sinirsiz metin kabul etmek, cihaz kaydini
    serbest bir depolama alanina cevirirdi."""
    r = client.post(
        "/devices",
        headers=h,
        json={
            "fcm_token": f"p238-{uuid.uuid4().hex}",
            "platform": "android",
            "uygulama_surum": "9" * 65,
        },
    )
    assert r.status_code == 422, r.text
