"""Tenant self-signup (POST /auth/signup) — Ozellik 3.

Yonetici mobilden tesis + kendi hesabini tek adimda acar (public, IP rate-limit);
basarida auto-login. Rate-limit anahtarlari testler arasi deterministik olsun diye
autouse fixture ile temizlenir (redis_client). Tests canli API'ye vurur.
"""
from __future__ import annotations

import uuid

import pytest


def _uphone() -> str:
    return "+90" + str(uuid.uuid4().int)[:10]


@pytest.fixture(autouse=True)
def _clear_signup_rate(redis_client):
    """Her testten once IP rate-limit (signup:*) anahtarlarini temizle."""
    for k in redis_client.scan_iter("signup:*"):
        redis_client.delete(k)
    yield


def _signup(client, **over):
    body = {
        "tenant_ad": "Test Tesis",
        "yonetici_ad": "Test Yonetici",
        "phone": _uphone(),
        "password": "YoneticiParola1",
    }
    body.update(over)
    return client.post("/auth/signup", json=body)


def test_signup_creates_tenant_and_auto_login(client):
    phone = _uphone()
    r = _signup(client, phone=phone)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["access_token"] and body["refresh_token"]

    # Ayni telefon+parola ile login-phone calisir (tenant numaradan cozulur).
    lr = client.post(
        "/auth/login-phone",
        json={"phone": phone, "password": "YoneticiParola1"},
    )
    assert lr.status_code == 200, lr.text
    assert lr.json()["password_setup_required"] is False


def test_signup_duplicate_phone_409(client):
    phone = _uphone()
    assert _signup(client, phone=phone).status_code == 200
    dup = _signup(client, phone=phone)
    assert dup.status_code == 409, dup.text
    assert dup.json()["error"]["code"] == "conflict"


def test_signup_invalid_phone_422(client):
    r = _signup(client, phone="abc")
    assert r.status_code == 422, r.text


def test_signup_rate_limited_429(client):
    # Limit 5/saat/IP; autouse fixture pencereyi sifirladi -> 6. deneme 429.
    for _ in range(5):
        assert _signup(client).status_code == 200
    r = _signup(client)
    assert r.status_code == 429, r.text
    assert r.json()["error"]["code"] == "rate_limited"
