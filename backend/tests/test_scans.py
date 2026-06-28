"""POST /scans testleri — olusturma, idempotency, RBAC, izolasyon + uctan uca zincir.

conftest `client`/`world`/`owner_conn` fixture'larini kullanir. Uctan uca testte
scan + scheduler.detect_missed birlikte calisir.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from app.scheduler.service import detect_missed

UTC = timezone.utc
# Gecmis pencere araligi + sonrasinda "now" (detect icin).
W1_START = datetime(2029, 12, 31, 0, 0, tzinfo=UTC)
W1_END = datetime(2029, 12, 31, 1, 0, tzinfo=UTC)
W2_START = datetime(2029, 12, 31, 1, 0, tzinfo=UTC)
W2_END = datetime(2029, 12, 31, 2, 0, tzinfo=UTC)
NOW_AFTER = datetime(2030, 1, 1, 0, 0, tzinfo=UTC)


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _new_checkpoint(client, headers) -> dict:
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"
    r = client.post("/checkpoints", headers=headers, json={"ad": "CP", "nfc_tag_uid": nfc})
    assert r.status_code == 201, r.text
    return r.json()


def _scan_body(nfc, when=W1_START, **extra):
    body = {"nfc_tag_uid": nfc, "okutma_zamani": when.isoformat(), "gps_lat": 41.0, "gps_lng": 29.0}
    body.update(extra)
    return body


# ------------------------------ olusturma ---------------------------------- #
def test_scan_create_resolves_checkpoint_and_guard(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _new_checkpoint(client, admin)
    guard_id = client.get("/me", headers=guard).json()["id"]

    key = uuid.uuid4().hex
    r = client.post("/scans", headers={**guard, "Idempotency-Key": key}, json=_scan_body(cp["nfc_tag_uid"]))
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["checkpoint_id"] == cp["id"]
    assert body["guard_id"] == guard_id           # token'dan turetildi
    assert body["nfc_tag_uid"] == cp["nfc_tag_uid"]
    assert body["imza_dogrulandi"] is False


def test_scan_idempotency_same_and_conflict(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _new_checkpoint(client, admin)
    key = uuid.uuid4().hex
    hdr = {**guard, "Idempotency-Key": key}

    first = client.post("/scans", headers=hdr, json=_scan_body(cp["nfc_tag_uid"]))
    assert first.status_code == 201
    first_id = first.json()["id"]

    # ayni key + ayni govde -> 200, AYNI kayit
    again = client.post("/scans", headers=hdr, json=_scan_body(cp["nfc_tag_uid"]))
    assert again.status_code == 200
    assert again.json()["id"] == first_id

    # ayni key + FARKLI govde -> 409
    diff = client.post(
        "/scans", headers=hdr, json=_scan_body(cp["nfc_tag_uid"], okutma_zamani="2027-01-01T00:00:00Z")
    )
    assert diff.status_code == 409 and diff.json()["error"]["code"] == "conflict"


def test_scan_missing_idempotency_key(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cp = _new_checkpoint(client, admin)
    r = client.post("/scans", headers=guard, json=_scan_body(cp["nfc_tag_uid"]))  # header yok
    assert r.status_code == 400 and r.json()["error"]["code"] == "bad_request"


def test_scan_unknown_nfc(client, world):
    guard = _headers(client, world["slug_a"], world["guard_a"])
    r = client.post(
        "/scans",
        headers={**guard, "Idempotency-Key": uuid.uuid4().hex},
        json=_scan_body("NFC-BILINMEYEN-XYZ"),
    )
    assert r.status_code == 404 and r.json()["error"]["code"] == "not_found"


# -------------------------------- RBAC ------------------------------------- #
def test_scan_rbac_resident_forbidden(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    cp = _new_checkpoint(client, admin)
    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.post(
        "/scans",
        headers={**resident, "Idempotency-Key": uuid.uuid4().hex},
        json=_scan_body(cp["nfc_tag_uid"]),
    )
    assert r.status_code == 403 and r.json()["error"]["code"] == "forbidden"


# ----------------------------- izolasyon ----------------------------------- #
def test_scan_tenant_isolation(client, world):
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    cp_b = _new_checkpoint(client, admin_b)  # B'nin checkpoint'i

    guard_a = _headers(client, world["slug_a"], world["guard_a"])
    # A'nin guard'i B'nin tag'ini okutamaz -> A'da cozulemez -> 404
    r = client.post(
        "/scans",
        headers={**guard_a, "Idempotency-Key": uuid.uuid4().hex},
        json=_scan_body(cp_b["nfc_tag_uid"]),
    )
    assert r.status_code == 404


# ----------------------- uctan uca: scan + scheduler ----------------------- #
def test_e2e_scan_completes_window_and_missing_is_missed(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    tenant_a = world["a"]

    # plan + 2 checkpoint + atama (API ile)
    cp1 = _new_checkpoint(client, admin)
    cp2 = _new_checkpoint(client, admin)
    plan = client.post(
        "/patrol-plans",
        headers=admin,
        json={"ad": "Gece", "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
    ).json()
    pid = plan["id"]
    assign = client.put(
        f"/patrol-plans/{pid}/checkpoints",
        headers=admin,
        json={"items": [{"checkpoint_id": cp1["id"]}, {"checkpoint_id": cp2["id"]}]},
    )
    assert assign.status_code == 200, assign.text

    # iki gecmis pencere (owner ile dogrudan; scheduler de uretebilirdi)
    w1 = uuid.uuid4()
    w2 = uuid.uuid4()
    for wid, start, end in [(w1, W1_START, W1_END), (w2, W2_START, W2_END)]:
        owner_conn.execute(
            "INSERT INTO patrol_window (id, tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
            "VALUES (%s,%s,%s,%s,%s,'bekliyor')",
            (wid, tenant_a, pid, start, end),
        )

    # W1: her iki checkpoint pencere araliginda okutuldu (scan API ile)
    for cp, t in [(cp1, "2029-12-31T00:20:00Z"), (cp2, "2029-12-31T00:40:00Z")]:
        r = client.post(
            "/scans",
            headers={**guard, "Idempotency-Key": uuid.uuid4().hex},
            json=_scan_body(cp["nfc_tag_uid"], okutma_zamani=t),
        )
        assert r.status_code == 201, r.text
    # W2: scan YOK

    # scheduler tespiti
    detect_missed(now=NOW_AFTER)

    def _durum(wid):
        return owner_conn.execute(
            "SELECT durum FROM patrol_window WHERE id=%s", (wid,)
        ).fetchone()[0]

    assert _durum(w1) == "tamamlandi"   # tum checkpoint'ler okutuldu
    assert _durum(w2) == "kacirildi"    # scan yok
