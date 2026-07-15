"""Acil durum: tetikleme + notification + idempotency + RBAC + cozme + dashboard + numara."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _trigger(client, headers, key, **body):
    return client.post("/emergency", headers={**headers, "Idempotency-Key": key}, json=body)


def _notif_count(owner_conn, tenant_id, tip):
    return owner_conn.execute(
        "SELECT count(*) FROM notification WHERE tenant_id=%s AND tip=%s::notification_tip",
        (tenant_id, tip),
    ).fetchone()[0]


# ----------------------------- tetikleme ----------------------------------- #
def test_trigger_creates_alert_and_notification(client, world, owner_conn):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]

    r = _trigger(client, guard, uuid.uuid4().hex, notlar="yangin", gps_lat=41.0, gps_lng=29.0)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["durum"] == "acik"
    assert body["tetikleyen_user_id"] == guard_id
    # yuksek oncelikli notification olustu
    assert _notif_count(owner_conn, world["a"], "acil_durum") == 1


def test_trigger_idempotency_and_400(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    key = uuid.uuid4().hex

    first = _trigger(client, guard, key, notlar="yangin")
    assert first.status_code == 201
    cid = first.json()["id"]

    again = _trigger(client, guard, key, notlar="yangin")
    assert again.status_code == 200 and again.json()["id"] == cid

    diff = _trigger(client, guard, key, notlar="baska")
    assert diff.status_code == 409

    nokey = client.post("/emergency", headers=guard, json={"notlar": "x"})
    assert nokey.status_code == 400 and nokey.json()["error"]["code"] == "bad_request"


def test_trigger_resident_allowed_read_forbidden(client, world):
    """Panik butonu sakinin de hakki (canli test karari, auth.md §4):
    resident TETIKLER (201); liste/cozme yonetimde kalir (403)."""
    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]

    r = _trigger(client, resident, uuid.uuid4().hex, notlar="asansorde mahsur")
    assert r.status_code == 201, r.text
    assert r.json()["tetikleyen_user_id"] == resident_id
    assert r.json()["durum"] == "acik"

    # okuma/cozme hala yonetim isi
    assert client.get("/emergency", headers=resident).status_code == 403
    assert client.patch(
        f"/emergency/{r.json()['id']}", headers=resident, json={"notlar": "x"}
    ).status_code == 403


# --------------------------- liste / izolasyon ----------------------------- #
def test_list_admin_only_and_tenant_isolation(client, world):
    guard_a = _headers(client, world["slug_a"], world["guard_a"])
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])

    alert_id = _trigger(client, guard_a, uuid.uuid4().hex, notlar="A-acil").json()["id"]

    # security liste goremez (admin-only)
    assert client.get("/emergency", headers=guard_a).status_code == 403
    # A admin gorur
    a_ids = [e["id"] for e in client.get("/emergency", headers=admin_a).json()["items"]]
    assert alert_id in a_ids
    # B admin A'nin acilini GORMEZ
    b_ids = [e["id"] for e in client.get("/emergency", headers=admin_b).json()["items"]]
    assert alert_id not in b_ids


# -------------------------------- cozme ------------------------------------ #
def test_resolve_admin_only(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    admin_id = client.get("/me", headers=admin).json()["id"]
    alert_id = _trigger(client, guard, uuid.uuid4().hex, notlar="acil").json()["id"]

    # security cozemez
    assert client.patch(f"/emergency/{alert_id}", headers=guard, json={}).status_code == 403

    r = client.patch(f"/emergency/{alert_id}", headers=admin, json={"notlar": "ekip gitti"})
    assert r.status_code == 200
    body = r.json()
    assert body["durum"] == "cozuldu"
    assert body["cozen_user_id"] == admin_id
    assert body["cozulme_zamani"] is not None


# ------------------------------ dashboard ---------------------------------- #
def test_emergency_shown_first_in_dashboard(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    # once normal bir alarm (kacirilan_tur) ekle
    owner_conn.execute(
        "INSERT INTO notification (tenant_id, tip, mesaj) VALUES (%s,'kacirilan_tur',%s)",
        (world["a"], "eski alarm"),
    )
    # sonra acil durum tetikle
    _trigger(client, guard, uuid.uuid4().hex, notlar="ACIL")

    alarms = client.get("/dashboard/live", headers=admin).json()["son_alarmlar"]
    assert alarms, "alarm bekleniyordu"
    assert alarms[0]["tip"] == "acil_durum"  # oncelikli => en ustte


# --------------------------- yonetim numarasi ------------------------------ #
def test_tenant_settings_phone_read_write(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])

    # admin numarayi ayarlar
    up = client.patch("/tenant/settings", headers=admin, json={"acil_durum_telefon": "+902120001122"})
    assert up.status_code == 200 and up.json()["acil_durum_telefon"] == "+902120001122"

    # saha rolu (mobil) okuyabilir
    got = client.get("/tenant/settings", headers=guard)
    assert got.status_code == 200 and got.json()["acil_durum_telefon"] == "+902120001122"
    assert got.json()["tenant_id"] == str(world["a"])

    # resident de OKUYABILIR (ana ekran basligi icin site adi — tum roller);
    # ama security YAZAMAZ (guncelleme admin-only)
    r = client.get("/tenant/settings", headers=resident)
    assert r.status_code == 200 and r.json()["tenant_id"] == str(world["a"])
    assert client.patch("/tenant/settings", headers=guard, json={"acil_durum_telefon": "x"}).status_code == 403
