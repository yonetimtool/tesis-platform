"""Onboarding Model A — admin cross-tenant tesis olusturma/listeleme +
yonetici ilk-giris adlandirma (POST/GET /tenants, POST /tenant/setup).

Admin isimsiz tenant (kurulum_tamamlandi=false) + yonetici acar; yonetici ilk
giriste tesisi adlandirir (kurulum_tamamlandi=true). Mobil self-signup KALDIRILDI.
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


def _uphone() -> str:
    return "+90" + str(uuid.uuid4().int)[:10]


def test_admin_creates_tenant_yonetici_then_first_login_setup(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    phone = _uphone()

    # 1) admin: tenant (isimsiz) + yonetici (parolasiz -> gecici kod)
    r = client.post("/tenants", headers=admin, json={"yonetici_ad": "Yeni Yonetici", "phone": phone})
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["tenant_id"] and body["yonetici_user_id"]
    temp = body["temp_code"]
    assert temp  # parola verilmedi -> gecici kod

    # 2) yonetici telefonla ilk giris -> parola kurulumu gerekir
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": temp})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True
    sp = client.post(
        "/auth/set-password",
        json={"setup_token": lp.json()["setup_token"], "new_password": "YeniYonetici1!"},
    )
    assert sp.status_code == 200, sp.text
    yon = {"Authorization": f"Bearer {sp.json()['access_token']}"}

    # 3) tenant henuz kurulmamis (kurulum_tamamlandi=false)
    ts = client.get("/tenant/settings", headers=yon)
    assert ts.status_code == 200 and ts.json()["kurulum_tamamlandi"] is False

    # 4) yonetici tesisi adlandirir -> kurulum tamamlanir
    su = client.post("/tenant/setup", headers=yon, json={"ad": "Benim Sitem"})
    assert su.status_code == 200, su.text
    assert su.json()["ad"] == "Benim Sitem" and su.json()["kurulum_tamamlandi"] is True

    # 5) ikinci setup -> 409 (zaten kuruldu)
    assert client.post("/tenant/setup", headers=yon, json={"ad": "XY"}).status_code == 409


def test_admin_creates_tenant_with_password_skips_temp_code(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    phone = _uphone()
    r = client.post(
        "/tenants",
        headers=admin,
        json={"yonetici_ad": "Parolali", "phone": phone, "password": "YonParola1!"},
    )
    assert r.status_code == 201, r.text
    assert r.json()["temp_code"] is None
    lp = client.post("/auth/login-phone", json={"phone": phone, "password": "YonParola1!"})
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is False


def test_admin_lists_all_tenants(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/tenants", headers=admin)
    assert r.status_code == 200, r.text
    ids = {i["id"] for i in r.json()["items"]}
    # world A ve B tenant'lari listede (cross-tenant admin gorunumu)
    assert str(world["a"]) in ids and str(world["b"]) in ids
    for i in r.json()["items"]:
        assert {"id", "ad", "kurulum_tamamlandi", "created_at"} <= set(i)


def test_tenants_admin_only(client, world):
    for role in ("yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get("/tenants", headers=h).status_code == 403, role
        assert client.post(
            "/tenants", headers=h, json={"yonetici_ad": "x", "phone": _uphone()}
        ).status_code == 403, role


def test_tenant_setup_rbac_and_already_done(client, world):
    # world tenant_a HAZIR (kurulum_tamamlandi default true) -> setup 409
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    assert client.post("/tenant/setup", headers=yon, json={"ad": "XY"}).status_code == 409
    # yonetici disi roller -> 403
    for role in ("admin_a", "guard_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post("/tenant/setup", headers=h, json={"ad": "XY"}).status_code == 403, role
