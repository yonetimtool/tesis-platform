"""Auth + RBAC + token-uzerinden tenant izolasyon testleri (KABUL KRITERI).

Veri kurulumu owner (psycopg, RLS bypass) ile; endpoint cagrilari calisan API'ye
(httpx, API_URL) yapilir. `docker compose exec api pytest` ile calistirilir.
"""
from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta, timezone

import httpx
import jwt
import psycopg
import pytest

from app.config import settings
from app.security import decode_token, hash_password

API_URL = os.getenv("API_URL", "http://localhost:8000")
OWNER_DSN = os.getenv(
    "OWNER_DSN", "postgresql://tesis_owner:owner_secret_change_me@db:5432/tesis"
)

PW_ADMIN_A = "passwordA1"
PW_GUARD_A = "guardpassA1"
PW_ADMIN_B = "passwordB1"
SHARED_EMAIL = "admin@example.com"   # A ve B'de AYNI email -> slug ile ayrisir
GUARD_EMAIL = "guard@example.com"


@pytest.fixture
def client():
    try:
        with httpx.Client(base_url=API_URL, timeout=10) as c:
            c.get("/health")  # erisilebilirlik kontrolu
            yield c
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"API erisilemiyor ({API_URL}): {exc}")


@pytest.fixture
def world():
    """A ve B tenant'lari + kullanicilar + checkpoint'lar (A:2, B:3)."""
    try:
        conn = psycopg.connect(OWNER_DSN, autocommit=True, connect_timeout=5)
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"DB erisilemiyor: {exc}")

    a = uuid.uuid4()
    b = uuid.uuid4()
    slug_a = f"ta-{a.hex[:8]}"
    slug_b = f"tb-{b.hex[:8]}"

    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (id, ad, slug) VALUES (%s,%s,%s), (%s,%s,%s)",
            (a, "A", slug_a, b, "B", slug_b),
        )
        # A: admin (paylasilan email) + security (guard)
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,%s,%s)",
            (a, "Admin A", SHARED_EMAIL, hash_password(PW_ADMIN_A), "admin"),
        )
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,%s,%s)",
            (a, "Guard A", GUARD_EMAIL, hash_password(PW_GUARD_A), "security"),
        )
        # B: admin (AYNI email, farkli parola/tenant)
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,%s,%s)",
            (b, "Admin B", SHARED_EMAIL, hash_password(PW_ADMIN_B), "admin"),
        )
        for i in range(2):
            cur.execute(
                "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid) VALUES (%s,%s,%s)",
                (a, f"A-CP-{i}", f"A-{a}-{i}"),
            )
        for i in range(3):
            cur.execute(
                "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid) VALUES (%s,%s,%s)",
                (b, f"B-CP-{i}", f"B-{b}-{i}"),
            )

    yield {"a": a, "b": b, "slug_a": slug_a, "slug_b": slug_b}

    with conn.cursor() as cur:
        cur.execute("DELETE FROM tenant WHERE id IN (%s,%s)", (a, b))
    conn.close()


def _login(client, slug, email, password):
    return client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": email, "password": password},
    )


def _bearer(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ------------------------------- login ------------------------------------- #
def test_login_success(client, world):
    r = _login(client, world["slug_a"], SHARED_EMAIL, PW_ADMIN_A)
    assert r.status_code == 200, r.text
    body = r.json()
    assert set(body) >= {"access_token", "refresh_token", "token_type", "expires_in"}
    assert body["token_type"] == "Bearer"
    claims = decode_token(body["access_token"], expected_type="access")
    assert claims["tenant_id"] == str(world["a"])
    assert claims["role"] == "admin"


def test_login_wrong_password(client, world):
    r = _login(client, world["slug_a"], SHARED_EMAIL, "yanlisparola")
    assert r.status_code == 401
    assert r.json()["error"]["code"]  # sozlesme hata zarfi


def test_login_wrong_tenant_slug(client, world):
    # B'nin slug'i + A'nin parolasi -> B'de o parola gecersiz -> 401
    r = _login(client, world["slug_b"], SHARED_EMAIL, PW_ADMIN_A)
    assert r.status_code == 401
    assert "error" in r.json()


def test_login_same_email_resolves_by_slug(client, world):
    """Ayni email, slug'a gore farkli tenant/kullaniciya cozulur."""
    ra = _login(client, world["slug_a"], SHARED_EMAIL, PW_ADMIN_A)
    rb = _login(client, world["slug_b"], SHARED_EMAIL, PW_ADMIN_B)
    assert ra.status_code == 200 and rb.status_code == 200
    ca = decode_token(ra.json()["access_token"], expected_type="access")
    cb = decode_token(rb.json()["access_token"], expected_type="access")
    assert ca["tenant_id"] == str(world["a"])
    assert cb["tenant_id"] == str(world["b"])
    assert ca["tenant_id"] != cb["tenant_id"]


def test_login_unknown_slug(client, world):
    r = _login(client, "yok-boyle-slug", SHARED_EMAIL, PW_ADMIN_A)
    assert r.status_code == 401


# ------------------------------ refresh ------------------------------------ #
def test_refresh_success(client, world):
    tokens = _login(client, world["slug_a"], SHARED_EMAIL, PW_ADMIN_A).json()
    r = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 200, r.text
    new = r.json()
    claims = decode_token(new["access_token"], expected_type="access")
    assert claims["tenant_id"] == str(world["a"])


def test_refresh_invalid(client, world):
    r = client.post("/auth/refresh", json={"refresh_token": "cop.token.degeri"})
    assert r.status_code == 401
    assert "error" in r.json()


def test_refresh_rotation_blocks_reuse(client, world):
    tokens = _login(client, world["slug_a"], SHARED_EMAIL, PW_ADMIN_A).json()
    old = tokens["refresh_token"]
    first = client.post("/auth/refresh", json={"refresh_token": old})
    assert first.status_code == 200
    # eski refresh tekrar kullanilirsa (rotation sonrasi) reddedilir
    reuse = client.post("/auth/refresh", json={"refresh_token": old})
    assert reuse.status_code == 401


# -------------------------------- /me -------------------------------------- #
def test_me_ok(client, world):
    tokens = _login(client, world["slug_a"], SHARED_EMAIL, PW_ADMIN_A).json()
    r = client.get("/me", headers=_bearer(tokens["access_token"]))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["email"] == SHARED_EMAIL
    assert body["tenant_id"] == str(world["a"])
    assert body["role"] == "admin"


def test_me_no_token(client, world):
    r = client.get("/me")
    assert r.status_code == 401


def test_me_expired_token(client, world):
    now = datetime.now(tz=timezone.utc)
    expired = jwt.encode(
        {
            "sub": str(uuid.uuid4()),
            "tenant_id": str(world["a"]),
            "role": "admin",
            "type": "access",
            "iat": int((now - timedelta(hours=2)).timestamp()),
            "exp": int((now - timedelta(hours=1)).timestamp()),
            "jti": str(uuid.uuid4()),
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    r = client.get("/me", headers=_bearer(expired))
    assert r.status_code == 401
    assert r.json()["error"]["code"] in {"token_expired", "invalid_token"}


# -------------------------------- RBAC ------------------------------------- #
def test_rbac_admin_allowed(client, world):
    tokens = _login(client, world["slug_a"], SHARED_EMAIL, PW_ADMIN_A).json()
    r = client.get("/admin/overview", headers=_bearer(tokens["access_token"]))
    assert r.status_code == 200


def test_rbac_security_forbidden(client, world):
    tokens = _login(client, world["slug_a"], GUARD_EMAIL, PW_GUARD_A).json()
    r = client.get("/admin/overview", headers=_bearer(tokens["access_token"]))
    assert r.status_code == 403
    assert r.json()["error"]["code"] == "forbidden"


# ---------------------- tenant izolasyonu (token e2e) ---------------------- #
def test_tenant_isolation_via_token(client, world):
    ta = _login(client, world["slug_a"], SHARED_EMAIL, PW_ADMIN_A).json()["access_token"]
    tb = _login(client, world["slug_b"], SHARED_EMAIL, PW_ADMIN_B).json()["access_token"]

    ra = client.get("/me/checkpoints", headers=_bearer(ta))
    rb = client.get("/me/checkpoints", headers=_bearer(tb))
    assert ra.status_code == 200 and rb.status_code == 200

    a_items = ra.json()
    b_items = rb.json()
    assert len(a_items) == 2  # A sadece kendi 2 checkpoint'ini gorur
    assert len(b_items) == 3  # B sadece kendi 3 checkpoint'ini gorur
    assert all(ci["nfc_tag_uid"].startswith("A-") for ci in a_items)
    assert all(ci["nfc_tag_uid"].startswith("B-") for ci in b_items)
