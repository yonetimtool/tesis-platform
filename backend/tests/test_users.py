"""Kullanici yonetimi: liste/detay/olustur/guncelle + RBAC + tenant izolasyon + login."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _login_status(client, slug, email, password):
    return client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": email, "password": password},
    ).status_code


# -------------------------------- liste ------------------------------------ #
def test_list_users_no_password_hash_and_filters(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/users", headers=admin)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["meta"]["total"] >= 4  # admin/guard/cleaner/resident (seed/world)
    for u in body["items"]:
        assert "password_hash" not in u  # ASLA donmez
        assert {"id", "ad", "email", "role", "is_active", "created_at"} <= set(u)

    # role filtresi
    sec = client.get("/users", headers=admin, params={"role": "security"}).json()["items"]
    assert all(u["role"] == "security" for u in sec)
    # is_active filtresi
    act = client.get("/users", headers=admin, params={"is_active": True}).json()["items"]
    assert all(u["is_active"] is True for u in act)


def test_list_users_rbac_and_isolation(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cleaning = _headers(client, world["slug_a"], world["cleaning_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    for h in (guard, cleaning, resident):
        assert client.get("/users", headers=h).status_code == 403

    # tenant izolasyonu: A admin'i B kullanicisini goremez
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    a_emails = {u["email"] for u in client.get("/users", headers=admin_a).json()["items"]}
    b_ids = [u["id"] for u in client.get("/users", headers=admin_b).json()["items"]]
    # A'nin gordukleri B'nin id'leriyle kesismez
    a_ids = {u["id"] for u in client.get("/users", headers=admin_a).json()["items"]}
    assert a_ids.isdisjoint(set(b_ids))
    assert "guard@example.com" in a_emails


# ------------------------------ olustur ------------------------------------ #
def test_create_user_can_login_and_email_conflict(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    email = f"yeni-{uuid.uuid4().hex[:8]}@acme.com"
    pw = "YeniParola1"

    r = client.post(
        "/users",
        headers=admin,
        json={"ad": "Yeni Personel", "email": email, "telefon": "555", "role": "security", "password": pw},
    )
    assert r.status_code == 201, r.text
    assert r.json()["role"] == "security" and r.json()["is_active"] is True
    assert "password_hash" not in r.json()

    # olusturulan kullanici GERCEKTEN login olabiliyor (parola hash'lendi)
    assert _login_status(client, world["slug_a"], email, pw) == 200
    # yanlis parola -> 401
    assert _login_status(client, world["slug_a"], email, "yanlis123") == 401

    # ayni email tekrar -> 409
    dup = client.post(
        "/users",
        headers=admin,
        json={"ad": "x", "email": email, "role": "cleaning", "password": "Baska1234"},
    )
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"


def test_create_user_rbac(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    r = client.post(
        "/users",
        headers=guard,
        json={"ad": "x", "email": f"x-{uuid.uuid4().hex[:6]}@a.com", "role": "resident", "password": "Parola123"},
    )
    assert r.status_code == 403


# ------------------------------ guncelle ----------------------------------- #
def test_update_user_role_active_password(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    email = f"upd-{uuid.uuid4().hex[:8]}@acme.com"
    created = client.post(
        "/users",
        headers=admin,
        json={"ad": "Guncellenecek", "email": email, "role": "cleaning", "password": "IlkParola1"},
    ).json()
    uid = created["id"]

    # rol + pasiflestir
    pr = client.patch(f"/users/{uid}", headers=admin, json={"role": "security", "is_active": False})
    assert pr.status_code == 200
    assert pr.json()["role"] == "security" and pr.json()["is_active"] is False

    # parola degistir -> yeni parola ile login olur (ama is_active False -> login reddedilir)
    client.patch(f"/users/{uid}", headers=admin, json={"is_active": True, "password": "YeniParola9"})
    assert _login_status(client, world["slug_a"], email, "YeniParola9") == 200
    assert _login_status(client, world["slug_a"], email, "IlkParola1") == 401


def test_update_user_tenant_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    # A'da kullanici olustur
    uid = client.post(
        "/users",
        headers=admin_a,
        json={"ad": "A user", "email": f"a-{uuid.uuid4().hex[:8]}@acme.com", "role": "resident", "password": "Parola123"},
    ).json()["id"]
    # B admin goremez / degistiremez -> 404 (RLS)
    assert client.get(f"/users/{uid}", headers=admin_b).status_code == 404
    assert client.patch(f"/users/{uid}", headers=admin_b, json={"ad": "x"}).status_code == 404
