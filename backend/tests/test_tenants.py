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


# --------------------------------------------------------------------------- #
# Tesis detay & yonetici konfigurasyonu (admin cross-tenant)
# --------------------------------------------------------------------------- #

def _admin(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


def _create_tenant(client, admin, password=None):
    phone = _uphone()
    body = {"yonetici_ad": "Detay Yon", "phone": phone}
    if password:
        body["password"] = password
    r = client.post("/tenants", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json(), phone


def _login_phone(client, phone, pw):
    return client.post("/auth/login-phone", json={"phone": phone, "password": pw})


def _setup_yonetici(client, phone, temp):
    """Gecici kod ile ilk giris + kalici parola -> yonetici auth header."""
    lp = _login_phone(client, phone, temp)
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True
    sp = client.post(
        "/auth/set-password",
        json={"setup_token": lp.json()["setup_token"], "new_password": "DetayYon1!"},
    )
    assert sp.status_code == 200, sp.text
    return {"Authorization": f"Bearer {sp.json()['access_token']}"}


def test_get_tenant_detail(client, world):
    admin = _admin(client, world)
    created, phone = _create_tenant(client, admin)
    tid = created["tenant_id"]
    r = client.get(f"/tenants/{tid}", headers=admin)
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["tenant_id"] == tid and d["kurulum_tamamlandi"] is False
    assert d["yonetici"]["id"] == created["yonetici_user_id"]
    assert d["yonetici"]["telefon"] == phone
    assert d["yonetici"]["password_set"] is False and d["yonetici"]["is_active"] is True


def test_get_tenant_detail_404(client, world):
    admin = _admin(client, world)
    assert client.get(f"/tenants/{uuid.uuid4()}", headers=admin).status_code == 404


def test_update_yonetici_and_phone_conflict(client, world):
    admin = _admin(client, world)
    created, _phone = _create_tenant(client, admin)
    tid = created["tenant_id"]
    newphone = _uphone()
    r = client.patch(
        f"/tenants/{tid}/yonetici",
        headers=admin,
        json={"ad": "Yeni Ad", "phone": newphone, "is_active": True},
    )
    assert r.status_code == 200, r.text
    assert r.json()["yonetici"]["ad"] == "Yeni Ad"
    assert r.json()["yonetici"]["telefon"] == newphone
    # cakisma: baska tenant'in yoneticisinin telefonuna cekmek -> 409
    _other, ophone = _create_tenant(client, admin)
    c = client.patch(f"/tenants/{tid}/yonetici", headers=admin, json={"phone": ophone})
    assert c.status_code == 409, c.text


def test_reset_credential_relogin(client, world):
    admin = _admin(client, world)
    created, phone = _create_tenant(client, admin, password="IlkParola1!")
    tid = created["tenant_id"]
    assert _login_phone(client, phone, "IlkParola1!").json()["password_setup_required"] is False
    rr = client.post(f"/tenants/{tid}/yonetici/reset-credential", headers=admin)
    assert rr.status_code == 200, rr.text
    temp = rr.json()["temp_code"]
    assert temp
    # eski parola artik gecmez; yeni gecici kod ilk-giris (parola belirleme) verir
    assert _login_phone(client, phone, "IlkParola1!").status_code == 401
    lp = _login_phone(client, phone, temp)
    assert lp.status_code == 200 and lp.json()["password_setup_required"] is True


def test_deactivate_blocks_login(client, world):
    admin = _admin(client, world)
    created, phone = _create_tenant(client, admin, password="AktifParola1!")
    tid = created["tenant_id"]
    assert _login_phone(client, phone, "AktifParola1!").status_code == 200
    client.patch(f"/tenants/{tid}/yonetici", headers=admin, json={"is_active": False})
    assert _login_phone(client, phone, "AktifParola1!").status_code == 401


def test_delete_tenant_cascade(client, world):
    admin = _admin(client, world)
    created, phone = _create_tenant(client, admin)
    tid = created["tenant_id"]
    yon = _setup_yonetici(client, phone, created["temp_code"])
    # RESTRICT-referans veren veri: yonetici duyuru olusturur (announcement->app_user)
    a = client.post("/announcements", headers=yon, json={"baslik": "Test", "govde": "Govde"})
    assert a.status_code in (200, 201), a.text
    # tesisi sil -> 204 (RESTRICT'e takilmadan cascade)
    d = client.delete(f"/tenants/{tid}", headers=admin)
    assert d.status_code == 204, d.text
    assert client.get(f"/tenants/{tid}", headers=admin).status_code == 404
    ids = {i["id"] for i in client.get("/tenants", headers=admin).json()["items"]}
    assert tid not in ids


def test_delete_tenant_404(client, world):
    admin = _admin(client, world)
    assert client.delete(f"/tenants/{uuid.uuid4()}", headers=admin).status_code == 404


def test_tenant_detail_rbac(client, world):
    created, _ = _create_tenant(client, _admin(client, world))
    tid = created["tenant_id"]
    for role in ("yonetici_a", "guard_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.get(f"/tenants/{tid}", headers=h).status_code == 403, role
        assert client.patch(
            f"/tenants/{tid}/yonetici", headers=h, json={"ad": "X2"}
        ).status_code == 403, role
        assert client.post(
            f"/tenants/{tid}/yonetici/reset-credential", headers=h
        ).status_code == 403, role
        assert client.delete(f"/tenants/{tid}", headers=h).status_code == 403, role
