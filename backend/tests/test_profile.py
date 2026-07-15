"""Self-servis profil: GET /me/profile + PATCH /me/password + PATCH /me/contact.

Canli API'ye httpx (client fixture) — auth.md self-servis profil. Kullanici
KENDI parola/iletisim alanini gunceller; yalniz kendi kaydi.
"""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _login_status(client, slug, cred, password):
    return client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": password},
    ).status_code


# ------------------------------ GET /me/profile --------------------------- #
def test_me_profile_returns_identity_and_contact(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/me/profile", headers=h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert {"id", "ad", "email", "telefon", "aranabilir", "role", "is_active"} <= set(body)
    assert body["role"] == "yonetici"
    assert body["email"] == world["yonetici_a"]["email"]
    assert "password_hash" not in body


# ----------------------------- PATCH /me/password ------------------------- #
def test_change_password_happy_path(client, world):
    slug, cred = world["slug_a"], world["guard_a"]
    h = _headers(client, slug, cred)
    new_pw = "yeniGuard123!"
    r = client.patch(
        "/me/password",
        headers=h,
        json={"current_password": cred["password"], "new_password": new_pw},
    )
    assert r.status_code == 204, r.text

    # Yeni parola ile login olur; eski parola artik gecmez.
    assert _login_status(client, slug, cred, new_pw) == 200
    assert _login_status(client, slug, cred, cred["password"]) == 401


def test_change_password_wrong_current_is_400(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.patch(
        "/me/password",
        headers=h,
        json={"current_password": "yanlisMevcut1", "new_password": "yeterinceUzun1!"},
    )
    assert r.status_code == 400, r.text
    assert r.json()["error"]["code"] == "invalid_credentials"


def test_change_password_short_new_is_422(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.patch(
        "/me/password",
        headers=h,
        json={"current_password": world["guard_a"]["password"], "new_password": "kisa"},
    )
    assert r.status_code == 422, r.text


def test_resident_can_change_own_password(client, world):
    slug, cred = world["slug_a"], world["resident_a"]
    h = _headers(client, slug, cred)  # resident email-login (geriye uyumlu)
    new_pw = "yeniResident123!"
    r = client.patch(
        "/me/password",
        headers=h,
        json={"current_password": cred["password"], "new_password": new_pw},
    )
    assert r.status_code == 204, r.text
    assert _login_status(client, slug, cred, new_pw) == 200


# ------------------------------ PATCH /me/contact ------------------------- #
def test_update_own_contact_reflects_in_profile(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.patch(
        "/me/contact",
        headers=h,
        json={"telefon": "+905551112233", "aranabilir": True},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["telefon"] == "+905551112233"
    assert body["aranabilir"] is True

    prof = client.get("/me/profile", headers=h).json()
    assert prof["telefon"] == "+905551112233"
    assert prof["aranabilir"] is True


def test_update_contact_empty_body_is_422(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.patch("/me/contact", headers=h, json={})
    assert r.status_code == 422, r.text
