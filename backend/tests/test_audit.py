"""KVKK denetim kaydi (WP1) — yazim kapsami, append-only, admin goruntuleyici.

Testler CANLI api container'ina vurur (httpx client). audit_log satirlari
owner_conn (RLS bypass) ile dogrulanir. Append-only garantisi app_conn (app_rw)
ile UPDATE/DELETE'in permission-denied ile reddedildigini kanitlar.
"""
from __future__ import annotations

import uuid

import psycopg
import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _count(owner_conn, tenant_id, action, **extra):
    q = "SELECT count(*) FROM audit_log WHERE tenant_id = %s AND action = %s"
    params: list = [str(tenant_id), action]
    for k, v in extra.items():
        q += f" AND {k} = %s"
        params.append(v)
    return owner_conn.execute(q, params).fetchone()[0]


def _resident_id(owner_conn, tenant_id):
    return owner_conn.execute(
        "SELECT id FROM app_user WHERE tenant_id=%s AND role='resident' LIMIT 1",
        (str(tenant_id),),
    ).fetchone()[0]


# ------------------------------- yazim kapsami ------------------------------ #
def test_login_ok_ve_fail_yazilir(world, client, owner_conn):
    slug, tid = world["slug_a"], world["a"]
    before_ok = _count(owner_conn, tid, "login_ok")
    _headers(client, slug, world["admin_a"])  # basarili giris
    assert _count(owner_conn, tid, "login_ok") == before_ok + 1

    before_fail = _count(owner_conn, tid, "login_fail")
    bad = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": world["admin_a"]["email"], "password": "yanlis-parola"},
    )
    assert bad.status_code == 401
    assert _count(owner_conn, tid, "login_fail") == before_fail + 1


def test_resident_create_yazilir(world, client, owner_conn):
    slug, tid = world["slug_a"], world["a"]
    admin = _headers(client, slug, world["admin_a"])
    before = _count(owner_conn, tid, "resident_create")
    r = client.post(
        "/residents", headers=admin,
        json={"ad": "Denetim Sakini", "unit_no": f"AUD-{uuid.uuid4().hex[:5]}",
              "blok": "A", "telefon": f"+90555{uuid.uuid4().int % 10000000:07d}"},
    )
    assert r.status_code == 201, r.text
    assert _count(owner_conn, tid, "resident_create", resource_id=r.json()["user_id"]) == 1
    assert _count(owner_conn, tid, "resident_create") == before + 1


def test_phone_reveal_ve_call_initiate_yazilir(world, client, owner_conn):
    """KVKK-kritik: telefon ifsasi + arama baslatma denetime yazilir."""
    slug, tid = world["slug_a"], world["a"]
    callee_id = _resident_id(owner_conn, tid)
    # Callee'yi aranabilir yap (riza) — numarasi world'de zaten var.
    owner_conn.execute(
        "SELECT set_config('app.current_tenant_id', %s, true)", (str(tid),)
    )  # owner icin gereksiz ama zararsiz
    owner_conn.execute(
        "UPDATE app_user SET aranabilir=true WHERE id=%s", (callee_id,)
    )
    guard = _headers(client, slug, world["guard_a"])  # security -> resident (izinli yon)

    before_reveal = _count(owner_conn, tid, "phone_reveal")
    before_call = _count(owner_conn, tid, "call_initiate")
    r = client.get(f"/call-target/{callee_id}", headers=guard)
    assert r.status_code == 200, r.text
    assert r.json()["telefon"]  # numara gercekten donuyor
    assert _count(owner_conn, tid, "phone_reveal", resource_id=str(callee_id)) >= 1
    assert _count(owner_conn, tid, "phone_reveal") == before_reveal + 1
    assert _count(owner_conn, tid, "call_initiate") == before_call + 1


def test_meta_kisisel_veri_tasimaz(world, client, owner_conn):
    """meta yalniz id/alan-adi; telefon/email/parola DEGERI ICERMEZ (KVKK)."""
    slug, tid = world["slug_a"], world["a"]
    admin = _headers(client, slug, world["admin_a"])
    tel = f"+90555{uuid.uuid4().int % 10000000:07d}"
    r = client.post(
        "/residents", headers=admin,
        json={"ad": "Meta Test", "unit_no": f"MT-{uuid.uuid4().hex[:5]}",
              "blok": "A", "telefon": tel},
    )
    assert r.status_code == 201, r.text
    rows = owner_conn.execute(
        "SELECT meta::text FROM audit_log WHERE tenant_id=%s AND action='resident_create' "
        "AND resource_id=%s",
        (str(tid), r.json()["user_id"]),
    ).fetchall()
    assert rows
    for (meta_text,) in rows:
        assert tel not in meta_text and "Meta Test" not in meta_text


# ------------------------------- append-only -------------------------------- #
def test_append_only_app_rw_update_delete_reddedilir(world, client, owner_conn, app_conn):
    """app_rw denetim satirini DEGISTIREMEZ/SILEMEZ (GRANT'ta UPDATE/DELETE yok).
    Kesin kanit: ham app_rw baglantisi UPDATE/DELETE'te permission-denied alir."""
    # En az bir satir olussun (login_ok).
    _headers(client, world["slug_a"], world["admin_a"])

    # Yetki (GRANT) kontrolu RLS'ten ONCE calisir; tenant baglami gerekmez.
    # app_rw'de UPDATE/DELETE GRANT'i YOK => permission-denied.
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        app_conn.execute("UPDATE audit_log SET action='tampered' WHERE true")
    app_conn.rollback()

    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        app_conn.execute("DELETE FROM audit_log WHERE true")
    app_conn.rollback()

    # INSERT ise acik (append-only = ekle + oku, ama degistirme/silme yok).
    # (Kapsam/RLS ayri; burada yalniz YETKI kanitlaniyor.)


# --------------------------- admin goruntuleyici ---------------------------- #
def test_audit_endpoint_admin_only(world, client):
    slug = world["slug_a"]
    admin = _headers(client, slug, world["admin_a"])
    assert client.get("/audit", headers=admin).status_code == 200
    # yonetici + saha 403 (panel yalniz admin).
    for role in ("yonetici_a", "guard_a"):
        h = _headers(client, slug, world[role])
        assert client.get("/audit", headers=h).status_code == 403, role


def test_audit_endpoint_capraz_tenant_ve_filtre(world, client, owner_conn):
    """Admin TUM tenant'lari gorur; tenant filtresi calisir; action filtresi calisir."""
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    # Her iki tenant'ta da login_ok uret.
    _headers(client, world["slug_b"], world["admin_b"])

    # Filtresiz: >=1 kayit, ve birden fazla tenant gorunebilir.
    allr = client.get("/audit", headers=admin_a, params={"action": "login_ok", "limit": 200})
    assert allr.status_code == 200
    tenant_ids = {i["tenant_id"] for i in allr.json()["items"]}
    assert str(world["a"]) in tenant_ids and str(world["b"]) in tenant_ids

    # tenant filtresi: yalniz A.
    onlya = client.get(
        "/audit", headers=admin_a,
        params={"tenant_id": str(world["a"]), "action": "login_ok", "limit": 200},
    )
    assert onlya.status_code == 200
    assert {i["tenant_id"] for i in onlya.json()["items"]} == {str(world["a"])}
