"""(P181 Bölüm 1) Mevcut kullanicinin e-posta ekleme/dogrulama uclari.

client -> CALISAN API (ayri surec): kod HASH'li saklandigi icin tam dogrulama
akisi (kod okuma) burada test edilmez — kod uretimi/dogrulamasi mevcut
`eposta_kodu_uret_ve_gonder`/`eposta_kodunu_dogrula` yardimcilariyla (kayit
akislarinda) zaten test kapsaminda. Burada UCUN kapisi test edilir: auth,
dogrulama, cakisma ve /me bayragi.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_me_eposta_dogrulandi_alani_var(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/me", headers=admin)
    assert r.status_code == 200, r.text
    # (P181) Alan HER kullanicida bulunur (bool).
    assert "eposta_dogrulandi" in r.json()
    assert isinstance(r.json()["eposta_dogrulandi"], bool)


def test_eposta_kod_iste_AUTH_ister(client):
    r = client.post("/me/eposta/kod-iste", json={"eposta": "x@ornek.test"})
    assert r.status_code == 401


def test_eposta_kod_iste_GECERSIZ_adres_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/me/eposta/kod-iste", headers=admin, json={"eposta": "gecersiz"})
    assert r.status_code == 422


def test_eposta_kod_iste_TAZE_adres_gonderir(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    taze = f"p181-{uuid.uuid4().hex[:10]}@ornek.test"
    r = client.post("/me/eposta/kod-iste", headers=admin, json={"eposta": taze})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "gonderildi"


def test_eposta_kod_iste_BASKASININ_adresi_409(client, world):
    # admin_a'nin e-postasi (varsa) baska bir kullanicida sayilir -> 409.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    # admin'e taze bir adres dogrulat DEGIL; guard admin'in login e-postasini
    # isterse 409 almali (o adres admin_a'da). admin_a login e-postasi:
    admin_eposta = world["admin_a"]["email"]
    r = client.post("/me/eposta/kod-iste", headers=guard, json={"eposta": admin_eposta})
    assert r.status_code == 409, r.text
