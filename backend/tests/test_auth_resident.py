"""Sakin (resident) daire-no ile giris + ilk giris parola kurulumu (KABUL KRITERI).

Kimlik modeli: sakin `tenant_slug + unit_no + parola` ile girer. Yonetici sakini
gecici kodla olusturur (POST /residents); ilk giris gecici kodla yapilir ve
parola belirleme ZORUNLUDUR (POST /auth/set-password). Personel (email+parola)
akisi DEGISMEZ — bkz. /contracts/auth.md §1.2.

Veri kurulumu owner (psycopg, RLS bypass) ile; endpoint cagrilari calisan
API'ye (httpx, API_URL) yapilir.
"""
from __future__ import annotations

import os
import uuid

import httpx
import psycopg
import pytest

from app.security import decode_token, hash_password

API_URL = os.getenv("API_URL", "http://localhost:8000")
OWNER_DSN = os.getenv(
    "OWNER_DSN", "postgresql://tesis_owner:owner_secret_change_me@db:5432/tesis"
)

PW_YONETICI_A = "yonpassA1"
PW_YONETICI_B = "yonpassB1"
PW_GUARD_A = "guardpassA1"
YONETICI_EMAIL = "yon-res@example.com"
GUARD_EMAIL = "guard-res@example.com"


@pytest.fixture
def client():
    try:
        with httpx.Client(base_url=API_URL, timeout=10) as c:
            c.get("/health")
            yield c
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"API erisilemiyor ({API_URL}): {exc}")


@pytest.fixture
def rworld():
    """A ve B tenant'lari + yonetici/guard kullanicilari (sakinler API ile acilir)."""
    try:
        conn = psycopg.connect(OWNER_DSN, autocommit=True, connect_timeout=5)
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"DB erisilemiyor: {exc}")

    a = uuid.uuid4()
    b = uuid.uuid4()
    slug_a = f"ra-{a.hex[:8]}"
    slug_b = f"rb-{b.hex[:8]}"

    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (id, ad, slug) VALUES (%s,%s,%s),(%s,%s,%s)",
            (a, "A", slug_a, b, "B", slug_b),
        )
        for tid, ad, email, pw, role in [
            (a, "Yonetici A", YONETICI_EMAIL, PW_YONETICI_A, "yonetici"),
            (a, "Guard A", GUARD_EMAIL, PW_GUARD_A, "security"),
            (b, "Yonetici B", YONETICI_EMAIL, PW_YONETICI_B, "yonetici"),
        ]:
            cur.execute(
                "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
                "VALUES (%s,%s,%s,%s,%s::user_role)",
                (tid, ad, email, hash_password(pw), role),
            )

    yield {"a": a, "b": b, "slug_a": slug_a, "slug_b": slug_b, "conn": conn}

    with conn.cursor() as cur:
        cur.execute("DELETE FROM tenant WHERE id IN (%s,%s)", (a, b))
    conn.close()


def _bearer(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _staff_token(client, slug: str, email: str, password: str) -> str:
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": email, "password": password},
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def _create_resident(client, token: str, unit_no: str, ad: str, **extra) -> dict:
    r = client.post(
        "/residents",
        json={"unit_no": unit_no, "ad": ad, **extra},
        headers=_bearer(token),
    )
    assert r.status_code == 201, r.text
    return r.json()


def _login_resident(client, slug: str, unit_no: str, password: str):
    return client.post(
        "/auth/login-resident",
        json={"tenant_slug": slug, "unit_no": unit_no, "password": password},
    )


def _set_password(client, setup_token: str, new_password: str):
    return client.post(
        "/auth/set-password",
        json={"setup_token": setup_token, "new_password": new_password},
    )


# --------------------- sakin olusturma (yonetici) -------------------------- #
def test_yonetici_creates_resident_with_temp_code(client, rworld):
    tok = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    body = _create_resident(client, tok, "A-1", "Sakin Bir", blok="A")

    assert set(body) >= {"user_id", "unit_id", "unit_no", "ad", "temp_code"}
    assert body["unit_no"] == "A-1"
    # kod tek seferlik gosterilir; okunakli format (XXXX-XXXX)
    assert len(body["temp_code"]) == 9 and body["temp_code"][4] == "-"

    # DB: kod HASH'li saklanir (duz metin degil), parola henuz yok.
    with rworld["conn"].cursor() as cur:
        cur.execute(
            "SELECT temp_code_hash, password_hash, password_set, role, email "
            "FROM app_user WHERE id = %s",
            (body["user_id"],),
        )
        temp_hash, pw_hash, pw_set, role, email = cur.fetchone()
    assert temp_hash and temp_hash != body["temp_code"]
    assert temp_hash.startswith("$2")  # bcrypt
    assert pw_hash is None
    assert pw_set is False
    assert role == "resident"
    assert email is None  # email opsiyonel

    # unit + aktif unit_resident baglantisi olustu
    with rworld["conn"].cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM unit_resident "
            "WHERE unit_id = %s AND user_id = %s AND bitis IS NULL",
            (body["unit_id"], body["user_id"]),
        )
        assert cur.fetchone()[0] == 1


def test_create_resident_rbac(client, rworld):
    guard = _staff_token(client, rworld["slug_a"], GUARD_EMAIL, PW_GUARD_A)
    r = client.post(
        "/residents",
        json={"unit_no": "A-9", "ad": "Yetkisiz"},
        headers=_bearer(guard),
    )
    assert r.status_code == 403
    assert r.json()["error"]["code"] == "forbidden"


def test_create_resident_existing_unit_reused(client, rworld):
    """Ayni unit_no ikinci sakinde YENI unit acmaz; mevcuta baglar."""
    tok = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    r1 = _create_resident(client, tok, "A-2", "Es Bir")
    r2 = _create_resident(client, tok, "A-2", "Es Iki")
    assert r1["unit_id"] == r2["unit_id"]
    assert r1["user_id"] != r2["user_id"]
    assert r1["temp_code"] != r2["temp_code"]


# ----------------------- ilk giris: kod -> parola --------------------------- #
def test_first_login_temp_code_then_set_password(client, rworld):
    tok = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    created = _create_resident(client, tok, "B-1", "Ilk Giris")

    # 1) gecici kod ile giris -> parola kurulumu ZORUNLU, oturum token'i YOK
    r = _login_resident(client, rworld["slug_a"], "B-1", created["temp_code"])
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["password_setup_required"] is True
    assert body.get("setup_token")
    assert "access_token" not in body or not body.get("access_token")

    # 2) parola belirle -> tam oturum (TokenPair) doner
    r2 = _set_password(client, body["setup_token"], "YeniParola1!")
    assert r2.status_code == 200, r2.text
    tokens = r2.json()
    assert set(tokens) >= {"access_token", "refresh_token", "token_type", "expires_in"}
    claims = decode_token(tokens["access_token"], expected_type="access")
    assert claims["role"] == "resident"
    assert claims["tenant_id"] == str(rworld["a"])
    assert claims["sub"] == created["user_id"]

    # 3) sonraki giris: daire no + KENDI parolasi
    r3 = _login_resident(client, rworld["slug_a"], "B-1", "YeniParola1!")
    assert r3.status_code == 200, r3.text
    b3 = r3.json()
    assert b3["password_setup_required"] is False
    assert b3["access_token"] and b3["refresh_token"]

    # 4) gecici kod artik GECERSIZ
    r4 = _login_resident(client, rworld["slug_a"], "B-1", created["temp_code"])
    assert r4.status_code == 401

    # DB: kod temizlendi, bayrak kalkti
    with rworld["conn"].cursor() as cur:
        cur.execute(
            "SELECT temp_code_hash, password_set FROM app_user WHERE id = %s",
            (created["user_id"],),
        )
        temp_hash, pw_set = cur.fetchone()
    assert temp_hash is None
    assert pw_set is True


def test_wrong_temp_code_rejected(client, rworld):
    tok = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    _create_resident(client, tok, "B-2", "Yanlis Kod")

    r = _login_resident(client, rworld["slug_a"], "B-2", "XXXX-YYYY")
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "invalid_credentials"


def test_setup_token_invalid_or_wrong_type(client, rworld):
    # cop token
    assert _set_password(client, "cop.token.degeri", "YeniParola1!").status_code == 401
    # staff ACCESS token'i setup_token yerine gecmez (type kontrolu)
    staff = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    assert _set_password(client, staff, "YeniParola1!").status_code == 401


# ------------------- ayni dairede birden fazla sakin ----------------------- #
def test_two_residents_same_unit_separate_accounts(client, rworld):
    tok = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    es1 = _create_resident(client, tok, "C-1", "Es Bir")
    es2 = _create_resident(client, tok, "C-1", "Es Iki")

    # her ikisi kendi koduyla parola belirler
    for created, pw in [(es1, "EsBirParola1"), (es2, "EsIkiParola2")]:
        setup = _login_resident(
            client, rworld["slug_a"], "C-1", created["temp_code"]
        ).json()["setup_token"]
        assert _set_password(client, setup, pw).status_code == 200

    # ayni daire no, farkli parola -> farkli hesaplara cozulur
    t1 = _login_resident(client, rworld["slug_a"], "C-1", "EsBirParola1").json()
    t2 = _login_resident(client, rworld["slug_a"], "C-1", "EsIkiParola2").json()
    c1 = decode_token(t1["access_token"], expected_type="access")
    c2 = decode_token(t2["access_token"], expected_type="access")
    assert c1["sub"] == es1["user_id"]
    assert c2["sub"] == es2["user_id"]
    assert c1["sub"] != c2["sub"]


# ----------------------------- guvenlik ------------------------------------ #
def test_resident_login_unknown_unit_or_slug(client, rworld):
    assert _login_resident(client, rworld["slug_a"], "YOK-99", "parola123").status_code == 401
    assert _login_resident(client, "yok-slug", "A-1", "parola123").status_code == 401


def test_resident_login_tenant_isolation(client, rworld):
    """Ayni unit_no iki tenant'ta da olabilir; parola karsi tenant'ta GECMEZ."""
    tok_a = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    tok_b = _staff_token(client, rworld["slug_b"], YONETICI_EMAIL, PW_YONETICI_B)
    res_a = _create_resident(client, tok_a, "D-1", "Sakin A")
    _create_resident(client, tok_b, "D-1", "Sakin B")

    setup = _login_resident(
        client, rworld["slug_a"], "D-1", res_a["temp_code"]
    ).json()["setup_token"]
    assert _set_password(client, setup, "IzoleParola1").status_code == 200

    # A'nin parolasi B tenant'inda ayni daire no ile GECERSIZ
    assert _login_resident(client, rworld["slug_b"], "D-1", "IzoleParola1").status_code == 401
    # A'nin kodu da B'de gecersiz (kod tenant'a ozgu hesaba bagli)
    assert _login_resident(client, rworld["slug_b"], "D-1", res_a["temp_code"]).status_code == 401


def test_moved_out_resident_cannot_login(client, rworld):
    tok = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    created = _create_resident(client, tok, "E-1", "Tasinan")
    setup = _login_resident(
        client, rworld["slug_a"], "E-1", created["temp_code"]
    ).json()["setup_token"]
    assert _set_password(client, setup, "TasinanParola1").status_code == 200

    # yonetici sakini daireden cikarir (bitis dolar)
    with rworld["conn"].cursor() as cur:
        cur.execute(
            "UPDATE unit_resident SET bitis = now() WHERE user_id = %s",
            (created["user_id"],),
        )
    assert _login_resident(client, rworld["slug_a"], "E-1", "TasinanParola1").status_code == 401


def test_resident_token_works_on_me_and_refresh(client, rworld):
    tok = _staff_token(client, rworld["slug_a"], YONETICI_EMAIL, PW_YONETICI_A)
    created = _create_resident(client, tok, "F-1", "Token Sakin")
    setup = _login_resident(
        client, rworld["slug_a"], "F-1", created["temp_code"]
    ).json()["setup_token"]
    tokens = _set_password(client, setup, "TokenParola1").json()

    # /me email'siz sakinde de calisir
    me = client.get("/me", headers=_bearer(tokens["access_token"]))
    assert me.status_code == 200, me.text
    assert me.json()["role"] == "resident"

    # refresh akisi sakin icin de aynen calisir
    r = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 200, r.text


def test_staff_login_unchanged(client, rworld):
    """Personel email+parola akisi bu degisiklikten ETKILENMEZ."""
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": rworld["slug_a"],
            "email": YONETICI_EMAIL,
            "password": PW_YONETICI_A,
        },
    )
    assert r.status_code == 200
    claims = decode_token(r.json()["access_token"], expected_type="access")
    assert claims["role"] == "yonetici"
