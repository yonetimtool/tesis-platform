"""Test fixtures — RLS izolasyon testleri icin iki ayri DB baglantisi.

Baglanti bilgileri env'den okunur (libpq DSN; psycopg sync):
  * OWNER_DSN : owner/superuser (RLS BYPASS) — kurulum/temizlik icin.
  * APP_DSN   : app_rw (RLS'e TABI) — izolasyon davranisini dogrulamak icin.

Varsayilanlar compose ag ici hostname'i (`db`) ve .env.example sifrelerini
kullanir. Host'tan calistiriyorsaniz OWNER_DSN/APP_DSN env'lerini override edin
(orn. host=localhost).
"""
from __future__ import annotations

import os
import uuid

import psycopg
import pytest

OWNER_DSN = os.getenv(
    "OWNER_DSN",
    "postgresql://tesis_owner:owner_secret_change_me@db:5432/tesis",
)
APP_DSN = os.getenv(
    "APP_DSN",
    "postgresql://app_rw:app_rw_secret_change_me@db:5432/tesis",
)


def _connect(dsn: str, **kw):
    try:
        return psycopg.connect(dsn, connect_timeout=5, **kw)
    except Exception as exc:  # pragma: no cover - ortam yoksa anlamli atla
        pytest.skip(f"DB erisilemiyor ({dsn.split('@')[-1]}): {exc}")


@pytest.fixture
def owner_conn():
    """Owner (superuser) baglantisi — autocommit; RLS'i bypass eder."""
    conn = _connect(OWNER_DSN, autocommit=True)
    try:
        yield conn
    finally:
        conn.close()


@pytest.fixture
def app_conn():
    """app_rw baglantisi — transaction-scoped (set_config LOCAL icin)."""
    conn = _connect(APP_DSN)
    try:
        yield conn
    finally:
        conn.rollback()
        conn.close()


@pytest.fixture
def two_tenants(owner_conn):
    """Owner ile 2 tenant + checkpoint'lar olusturur (A:2, B:3); sonra temizler."""
    tenant_a = uuid.uuid4()
    tenant_b = uuid.uuid4()

    # slug NOT NULL + benzersiz (bkz. /contracts/auth.md §1.1) — her kosumda essiz.
    slug_a = f"rls-a-{tenant_a.hex[:8]}"
    slug_b = f"rls-b-{tenant_b.hex[:8]}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (id, ad, slug, timezone) VALUES (%s, %s, %s, %s)",
            (tenant_a, "TENANT-A", slug_a, "Europe/Istanbul"),
        )
        cur.execute(
            "INSERT INTO tenant (id, ad, slug, timezone) VALUES (%s, %s, %s, %s)",
            (tenant_b, "TENANT-B", slug_b, "Europe/Istanbul"),
        )
        for i in range(2):
            cur.execute(
                "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid) "
                "VALUES (%s, %s, %s)",
                (tenant_a, f"A-CP-{i}", f"A-{tenant_a}-{i}"),
            )
        for i in range(3):
            cur.execute(
                "INSERT INTO checkpoint (tenant_id, ad, nfc_tag_uid) "
                "VALUES (%s, %s, %s)",
                (tenant_b, f"B-CP-{i}", f"B-{tenant_b}-{i}"),
            )

    yield tenant_a, tenant_b

    # Temizlik: tenant silinince checkpoint'lar CASCADE ile gider.
    with owner_conn.cursor() as cur:
        cur.execute(
            "DELETE FROM tenant WHERE id IN (%s, %s)", (tenant_a, tenant_b)
        )


# --------------------------------------------------------------------------- #
# API uzerinden (token'li) testler icin paylasilan fixture'lar.
# (httpx/app importlari TEMBEL — app-free RLS testleri etkilenmesin.)
# --------------------------------------------------------------------------- #
API_URL = os.getenv("API_URL", "http://localhost:8000")

# world kullanicilarinin kimlik bilgileri (admin A ve B AYNI email -> slug ayristirir)
SHARED_EMAIL = "admin@example.com"
GUARD_EMAIL = "guard@example.com"
CLEANER_EMAIL = "cleaner@example.com"
RESIDENT_EMAIL = "resident@example.com"
PW_ADMIN_A = "passwordA1"
PW_GUARD_A = "guardpassA1"
PW_CLEANER_A = "cleanerpassA1"
PW_RESIDENT_A = "residentpassA1"
PW_ADMIN_B = "passwordB1"


@pytest.fixture
def client():
    """Calisan API'ye httpx.Client; erisilemezse testi atla."""
    import httpx

    try:
        c = httpx.Client(base_url=API_URL, timeout=10)
        c.get("/health")
    except Exception as exc:  # pragma: no cover
        pytest.skip(f"API erisilemiyor ({API_URL}): {exc}")
    try:
        yield c
    finally:
        c.close()


@pytest.fixture
def world(owner_conn):
    """A ve B tenant'lari + admin/security kullanicilar (CRUD/RBAC testleri icin)."""
    from app.security import hash_password

    a = uuid.uuid4()
    b = uuid.uuid4()
    slug_a = f"ca-{a.hex[:8]}"
    slug_b = f"cb-{b.hex[:8]}"
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO tenant (id, ad, slug) VALUES (%s,%s,%s),(%s,%s,%s)",
            (a, "A", slug_a, b, "B", slug_b),
        )
        users = [
            (a, "Admin A", SHARED_EMAIL, PW_ADMIN_A, "admin"),
            (a, "Guard A", GUARD_EMAIL, PW_GUARD_A, "security"),
            (a, "Cleaner A", CLEANER_EMAIL, PW_CLEANER_A, "cleaning"),
            (a, "Resident A", RESIDENT_EMAIL, PW_RESIDENT_A, "resident"),
            (b, "Admin B", SHARED_EMAIL, PW_ADMIN_B, "admin"),
        ]
        for tid, ad, email, pw, role in users:
            cur.execute(
                "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
                "VALUES (%s,%s,%s,%s,%s::user_role)",
                (tid, ad, email, hash_password(pw), role),
            )

    yield {
        "a": a,
        "b": b,
        "slug_a": slug_a,
        "slug_b": slug_b,
        "admin_a": {"email": SHARED_EMAIL, "password": PW_ADMIN_A},
        "guard_a": {"email": GUARD_EMAIL, "password": PW_GUARD_A},
        "cleaning_a": {"email": CLEANER_EMAIL, "password": PW_CLEANER_A},
        "resident_a": {"email": RESIDENT_EMAIL, "password": PW_RESIDENT_A},
        "admin_b": {"email": SHARED_EMAIL, "password": PW_ADMIN_B},
    }

    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM tenant WHERE id IN (%s,%s)", (a, b))
