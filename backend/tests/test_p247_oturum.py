"""(P247 §4) OTURUM SURESI — 30 gun KAYAN; parola degisince TUM cihazlar duser.

Kabul olcutu 8: "30 gun oturum; parola degisince tum cihazlar duser."
Iki cihaz iki ayri girisle temsil edilir (iki bagimsiz refresh ailesi).
"""
from __future__ import annotations

import time

import jwt

from app.config import settings


def _giris(client, slug, cred, parola=None):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"],
        "password": parola or cred["password"]})
    assert r.status_code == 200, r.text
    return r.json()


def _h(tok):
    return {"Authorization": f"Bearer {tok}"}


def _exp(jeton):
    return jwt.decode(jeton, options={"verify_signature": False})["exp"]


def test_OTURUM_30_GUN_KAYAN(client, world):
    """Yenileme jetonu 30 gun; her yenileme pencereyi YENIDEN 30 gune acar."""
    t = _giris(client, world["slug_a"], world["guard_a"])
    gun = settings.refresh_token_expire_days
    assert gun == 30
    assert abs(_exp(t["refresh_token"]) - (time.time() + gun * 86400)) < 120
    # Erisim jetonu KISA kalir (15 dk): calinan erisim jetonunun omru sinirli.
    assert _exp(t["access_token"]) - time.time() <= 16 * 60

    time.sleep(1.1)
    r = client.post("/auth/refresh", json={"refresh_token": t["refresh_token"]})
    assert r.status_code == 200, r.text
    # KAYAN: yeni yenileme jetonunun bitisi eskisinden SONRA.
    assert _exp(r.json()["refresh_token"]) > _exp(t["refresh_token"])


def test_PAROLA_DEGISINCE_TUM_CIHAZLAR_DUSER(client, world):
    slug, cred = world["slug_a"], world["guard_a"]
    telefon = _giris(client, slug, cred)   # 1. cihaz
    tablet = _giris(client, slug, cred)    # 2. cihaz
    web = _giris(client, slug, cred)       # degisikligi yapan cihaz

    yeni = "YeniOturum247!"
    r = client.patch("/me/password", headers=_h(web["access_token"]),
                     json={"current_password": cred["password"], "new_password": yeni})
    assert r.status_code == 200, r.text
    taze = r.json()
    assert taze["access_token"] and taze["refresh_token"]

    # OTEKI cihazlar: erisim de yenileme de gecmez.
    for cihaz in (telefon, tablet):
        assert client.get("/me", headers=_h(cihaz["access_token"])).status_code == 401
        assert client.post("/auth/refresh",
                           json={"refresh_token": cihaz["refresh_token"]}).status_code == 401
    # Degisikligi yapan cihazin ESKI cifti de kapandi (baglam yenilendi) ...
    assert client.get("/me", headers=_h(web["access_token"])).status_code == 401
    assert client.post("/auth/refresh",
                       json={"refresh_token": web["refresh_token"]}).status_code == 401
    # ... ama DONEN TAZE cift calisir ve yenilenebilir.
    assert client.get("/me", headers=_h(taze["access_token"])).status_code == 200
    r = client.post("/auth/refresh", json={"refresh_token": taze["refresh_token"]})
    assert r.status_code == 200, r.text

    # Oteki cihaz yeni parolayla yeniden girebilir; eski parola gecmez.
    assert _giris(client, slug, cred, yeni)["access_token"]
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 401


def test_YANLIS_MEVCUT_PAROLA_OTURUMLARI_DUSURMEZ(client, world):
    """Basarisiz deneme hic kimseyi dusurmemeli (DoS yolu olmasin)."""
    slug, cred = world["slug_a"], world["guard_a"]
    telefon = _giris(client, slug, cred)
    web = _giris(client, slug, cred)
    r = client.patch("/me/password", headers=_h(web["access_token"]),
                     json={"current_password": "yanlisMevcut1", "new_password": "YeniOturum247!"})
    assert r.status_code == 400
    assert client.get("/me", headers=_h(telefon["access_token"])).status_code == 200
