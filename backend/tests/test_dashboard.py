"""GET /dashboard/live testleri — aktif turlar + sayilar, izolasyon, RBAC, alarm e2e."""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

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


def _plan_with_checkpoints(client, headers, cp_ids):
    plan = client.post(
        "/patrol-plans",
        headers=headers,
        json={"ad": "Devriye", "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
    ).json()
    client.put(
        f"/patrol-plans/{plan['id']}/checkpoints",
        headers=headers,
        json={"items": [{"checkpoint_id": c} for c in cp_ids]},
    )
    return plan


def _ins_window(conn, tid, pid, start, end, durum="bekliyor"):
    wid = uuid.uuid4()
    conn.execute(
        "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (wid, tid, pid, start, end, durum),
    )
    return wid


def _ins_scan(conn, tid, gid, cid, when):
    conn.execute(
        "INSERT INTO scan_event (tenant_id, guard_id, checkpoint_id, nfc_tag_uid, okutma_zamani, idempotency_key) "
        "VALUES (%s,%s,%s,%s,%s,%s)",
        (tid, gid, cid, "NFC", when, uuid.uuid4().hex),
    )


def test_dashboard_shows_today_windows_with_counts(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]

    cp1 = _checkpoint(client, admin)
    cp2 = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp1["id"], cp2["id"]])

    now = datetime.now(tz=UTC)
    wid = _ins_window(owner_conn, world["a"], plan["id"], now, now + timedelta(hours=1))
    _ins_scan(owner_conn, world["a"], guard_id, cp1["id"], now + timedelta(seconds=1))  # 1/2 okutuldu

    r = client.get("/dashboard/live", headers=admin)
    assert r.status_code == 200, r.text
    body = r.json()
    assert {"generated_at", "aktif_turlar", "son_alarmlar"} <= set(body)

    tur = next((t for t in body["aktif_turlar"] if t["patrol_window_id"] == str(wid)), None)
    assert tur is not None
    assert tur["patrol_plan_id"] == plan["id"]
    assert tur["patrol_plan_ad"] == "Devriye"
    assert tur["durum"] == "bekliyor"
    assert tur["beklenen_checkpoint_sayisi"] == 2
    assert tur["okutulan_checkpoint_sayisi"] == 1


def test_dashboard_tenant_isolation(client, world, owner_conn):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])

    cp = _checkpoint(client, admin_a)
    plan = _plan_with_checkpoints(client, admin_a, [cp["id"]])
    now = datetime.now(tz=UTC)
    wid = _ins_window(owner_conn, world["a"], plan["id"], now, now + timedelta(hours=1))

    # B'nin paneli A'nin penceresini gormez
    body_b = client.get("/dashboard/live", headers=admin_b).json()
    assert all(t["patrol_window_id"] != str(wid) for t in body_b["aktif_turlar"])


def test_dashboard_rbac(client, world):
    # security -> 200 (matris), resident -> 403
    sec = _headers(client, world["slug_a"], world["guard_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    assert client.get("/dashboard/live", headers=sec).status_code == 200
    r = client.get("/dashboard/live", headers=res)
    assert r.status_code == 403 and r.json()["error"]["code"] == "forbidden"


def test_dashboard_alarm_limit_validation(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    assert client.get("/dashboard/live", headers=admin, params={"alarm_limit": 0}).status_code == 422
    assert client.get("/dashboard/live", headers=admin, params={"alarm_limit": 5}).status_code == 200


def test_e2e_missed_tour_appears_in_dashboard_alarms(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _checkpoint(client, admin)
    plan = _plan_with_checkpoints(client, admin, [cp["id"]])
    # gecmis pencere, scan YOK -> detect ile kacirildi
    wid = _ins_window(owner_conn, world["a"], plan["id"], PAST_START, PAST_END)

    detect_missed(now=NOW_AFTER)

    body = client.get("/dashboard/live", headers=admin).json()
    alarm = next((a for a in body["son_alarmlar"] if a["patrol_window_id"] == str(wid)), None)
    assert alarm is not None
    assert alarm["tip"] == "kacirilan_tur"
    assert "mesaj" in alarm and alarm["mesaj"]
