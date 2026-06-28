"""notification — idempotent uretim + GET/PATCH /notifications (RBAC, izolasyon)."""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from app.scheduler.service import detect_missed

UTC = timezone.utc
PAST_START = datetime(2029, 12, 31, 0, 0, tzinfo=UTC)
PAST_END = datetime(2029, 12, 31, 1, 0, tzinfo=UTC)
NOW_AFTER = datetime(2030, 1, 1, 0, 0, tzinfo=UTC)


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _checkpoint(client, headers):
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    return client.post("/checkpoints", headers=headers, json={"ad": "CP", "nfc_tag_uid": nfc}).json()


def _plan(client, headers, cp_ids):
    plan = client.post(
        "/patrol-plans",
        headers=headers,
        json={"ad": "P", "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
    ).json()
    client.put(
        f"/patrol-plans/{plan['id']}/checkpoints",
        headers=headers,
        json={"items": [{"checkpoint_id": c} for c in cp_ids]},
    )
    return plan


def _past_window(owner_conn, tenant_id, plan_id):
    wid = uuid.uuid4()
    owner_conn.execute(
        "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
        "VALUES (%s,%s,%s,%s,%s,'bekliyor')",
        (wid, tenant_id, plan_id, PAST_START, PAST_END),
    )
    return wid


def _make_missed(client, owner_conn, admin, tenant_id):
    """tenant'ta kacirilan bir tur + (detect ile) notification olustur; window id doner."""
    cp = _checkpoint(client, admin)
    plan = _plan(client, admin, [cp["id"]])
    wid = _past_window(owner_conn, tenant_id, plan["id"])
    detect_missed(now=NOW_AFTER)
    return wid


def _notif_count(owner_conn, wid):
    return owner_conn.execute(
        "SELECT count(*) FROM notification WHERE patrol_window_id=%s", (wid,)
    ).fetchone()[0]


# ----------------------------- idempotency --------------------------------- #
def test_detect_creates_notification_idempotently(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    wid = _make_missed(client, owner_conn, admin, world["a"])
    assert _notif_count(owner_conn, wid) == 1

    # pencereyi tekrar 'bekliyor' yapip detect'i tekrar kosalim -> CIFT kayit OLMAMALI
    owner_conn.execute("UPDATE patrol_window SET durum='bekliyor' WHERE id=%s", (wid,))
    detect_missed(now=NOW_AFTER)
    assert _notif_count(owner_conn, wid) == 1


# ---------------------------- GET /notifications --------------------------- #
def test_list_notifications_and_okundu_filter(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    wid = _make_missed(client, owner_conn, admin, world["a"])

    r = client.get("/notifications", headers=admin)
    assert r.status_code == 200, r.text
    body = r.json()
    assert {"meta", "items"} <= set(body)
    item = next((n for n in body["items"] if n["patrol_window_id"] == str(wid)), None)
    assert item is not None
    assert item["tip"] == "kacirilan_tur" and item["okundu"] is False

    # okundu=false -> var; okundu=true -> yok
    assert any(
        n["patrol_window_id"] == str(wid)
        for n in client.get("/notifications", headers=admin, params={"okundu": False}).json()["items"]
    )
    assert all(
        n["patrol_window_id"] != str(wid)
        for n in client.get("/notifications", headers=admin, params={"okundu": True}).json()["items"]
    )


def test_list_notifications_tenant_isolation(client, world, owner_conn):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    wid = _make_missed(client, owner_conn, admin_a, world["a"])

    b_items = client.get("/notifications", headers=admin_b).json()["items"]
    assert all(n["patrol_window_id"] != str(wid) for n in b_items)


def test_notifications_rbac(client, world):
    sec = _headers(client, world["slug_a"], world["guard_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/notifications", headers=sec).status_code == 200
    assert client.get("/notifications", headers=res).status_code == 403


# --------------------------- PATCH /notifications -------------------------- #
def test_mark_read_and_isolation(client, world, owner_conn):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    wid = _make_missed(client, owner_conn, admin_a, world["a"])

    nid = next(
        n["id"]
        for n in client.get("/notifications", headers=admin_a).json()["items"]
        if n["patrol_window_id"] == str(wid)
    )

    # B, A'nin bildirimini guncelleyemez -> 404 (RLS)
    assert client.patch(f"/notifications/{nid}", headers=admin_b, json={"okundu": True}).status_code == 404

    # A okundu=true yapar
    pr = client.patch(f"/notifications/{nid}", headers=admin_a, json={"okundu": True})
    assert pr.status_code == 200 and pr.json()["okundu"] is True
    # artik okundu=true filtresinde gorunur
    assert any(
        n["id"] == nid
        for n in client.get("/notifications", headers=admin_a, params={"okundu": True}).json()["items"]
    )
