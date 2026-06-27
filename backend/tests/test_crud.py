"""Shift / Checkpoint / PatrolPlan CRUD + RBAC + tenant izolasyon testleri.

conftest'teki `client` + `world` fixture'larini kullanir. `docker compose exec
api pytest` ile calistirilir (calisan API'ye token'li istekler).
"""
from __future__ import annotations

import uuid


def _login(client, slug, cred):
    return client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )


def _headers(client, slug, cred) -> dict:
    r = _login(client, slug, cred)
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ------------------------------- shift ------------------------------------- #
def test_shift_crud_happy_path(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])

    # create — baslangic > bitis (gece sarkmasi) GECERLI, reddedilmemeli
    r = client.post(
        "/shifts",
        headers=h,
        json={"ad": "Gece", "baslangic_saat": "23:00", "bitis_saat": "07:00", "gun_tipi": "her_gun"},
    )
    assert r.status_code == 201, r.text
    sid = r.json()["id"]
    assert r.json()["baslangic_saat"] == "23:00"
    assert r.json()["bitis_saat"] == "07:00"

    assert client.get(f"/shifts/{sid}", headers=h).status_code == 200

    lr = client.get("/shifts", headers=h, params={"limit": 10, "offset": 0})
    assert lr.status_code == 200
    body = lr.json()
    assert body["meta"]["limit"] == 10 and body["meta"]["total"] >= 1
    assert any(it["id"] == sid for it in body["items"])

    pr = client.patch(f"/shifts/{sid}", headers=h, json={"ad": "Gece-2"})
    assert pr.status_code == 200 and pr.json()["ad"] == "Gece-2"

    assert client.delete(f"/shifts/{sid}", headers=h).status_code == 204
    assert client.get(f"/shifts/{sid}", headers=h).status_code == 404


def test_shift_validation_422(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/shifts", headers=h, json={"ad": "x", "baslangic_saat": "08:00"})
    assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"
    r2 = client.post(
        "/shifts", headers=h, json={"ad": "x", "baslangic_saat": "99:99", "bitis_saat": "08:00"}
    )
    assert r2.status_code == 422


# ----------------------------- checkpoint ---------------------------------- #
def test_checkpoint_crud_and_nfc_conflict(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])
    nfc = f"NFC-{uuid.uuid4().hex[:10]}"

    r = client.post(
        "/checkpoints",
        headers=h,
        json={"ad": "Kapi", "nfc_tag_uid": nfc, "gps_lat": 41.015, "gps_lng": 28.979},
    )
    assert r.status_code == 201, r.text
    cid = r.json()["id"]
    assert r.json()["aktif"] is True

    # ayni nfc_tag_uid -> 409
    rc = client.post("/checkpoints", headers=h, json={"ad": "Kapi2", "nfc_tag_uid": nfc})
    assert rc.status_code == 409 and rc.json()["error"]["code"] == "conflict"

    assert client.get(f"/checkpoints/{uuid.uuid4()}", headers=h).status_code == 404

    pr = client.patch(f"/checkpoints/{cid}", headers=h, json={"aktif": False})
    assert pr.status_code == 200 and pr.json()["aktif"] is False

    assert client.delete(f"/checkpoints/{cid}", headers=h).status_code == 204


# ---------------------------- patrol plan ---------------------------------- #
def test_patrol_plan_crud_and_assign(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])

    cp_ids = []
    for i in range(2):
        cp = client.post(
            "/checkpoints", headers=h, json={"ad": f"CP{i}", "nfc_tag_uid": f"PP-{uuid.uuid4().hex[:8]}"}
        ).json()
        cp_ids.append(cp["id"])

    pr = client.post(
        "/patrol-plans",
        headers=h,
        json={"ad": "Devriye", "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
    )
    assert pr.status_code == 201, pr.text
    pid = pr.json()["id"]

    # checkpoint atama (sira: biri verili, biri index'ten)
    ar = client.put(
        f"/patrol-plans/{pid}/checkpoints",
        headers=h,
        json={"items": [{"checkpoint_id": cp_ids[0]}, {"checkpoint_id": cp_ids[1], "sira": 5}]},
    )
    assert ar.status_code == 200, ar.text
    assert [it["sira"] for it in ar.json()] == [0, 5]

    det = client.get(f"/patrol-plans/{pid}", headers=h).json()
    assert len(det["checkpoints"]) == 2

    gc = client.get(f"/patrol-plans/{pid}/checkpoints", headers=h)
    assert gc.status_code == 200 and len(gc.json()) == 2

    assert client.patch(f"/patrol-plans/{pid}", headers=h, json={"periyot_dakika": 30}).json()[
        "periyot_dakika"
    ] == 30

    assert client.delete(f"/patrol-plans/{pid}", headers=h).status_code == 204


def test_plan_rejects_cross_tenant_checkpoint(client, world):
    ha = _headers(client, world["slug_a"], world["admin_a"])
    hb = _headers(client, world["slug_b"], world["admin_b"])

    cp_b = client.post(
        "/checkpoints", headers=hb, json={"ad": "B-cp", "nfc_tag_uid": f"BX-{uuid.uuid4().hex[:8]}"}
    ).json()["id"]
    pid = client.post(
        "/patrol-plans",
        headers=ha,
        json={"ad": "A-plan", "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
    ).json()["id"]

    r = client.put(
        f"/patrol-plans/{pid}/checkpoints", headers=ha, json={"items": [{"checkpoint_id": cp_b}]}
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_reference"


def test_plan_rejects_cross_tenant_shift(client, world):
    ha = _headers(client, world["slug_a"], world["admin_a"])
    hb = _headers(client, world["slug_b"], world["admin_b"])

    shift_b = client.post(
        "/shifts", headers=hb, json={"ad": "B", "baslangic_saat": "08:00", "bitis_saat": "16:00"}
    ).json()["id"]
    r = client.post(
        "/patrol-plans",
        headers=ha,
        json={
            "ad": "A",
            "baslangic_saat": "00:00",
            "bitis_saat": "06:00",
            "periyot_dakika": 60,
            "shift_id": shift_b,
        },
    )
    assert r.status_code == 422 and r.json()["error"]["code"] == "invalid_reference"


# --------------------------- tenant izolasyon ------------------------------ #
def test_tenant_isolation_crud(client, world):
    ha = _headers(client, world["slug_a"], world["admin_a"])
    hb = _headers(client, world["slug_b"], world["admin_b"])

    sid = client.post(
        "/shifts", headers=ha, json={"ad": "A-shift", "baslangic_saat": "08:00", "bitis_saat": "16:00"}
    ).json()["id"]

    # B, A'nin shift'ini goremez/degistiremez/silemez
    assert client.get(f"/shifts/{sid}", headers=hb).status_code == 404
    assert client.patch(f"/shifts/{sid}", headers=hb, json={"ad": "x"}).status_code == 404
    assert client.delete(f"/shifts/{sid}", headers=hb).status_code == 404

    b_items = client.get("/shifts", headers=hb, params={"limit": 200}).json()["items"]
    assert all(it["id"] != sid for it in b_items)


# -------------------------------- RBAC ------------------------------------- #
def test_rbac_security_read_yes_write_no(client, world):
    hg = _headers(client, world["slug_a"], world["guard_a"])

    # okuma izinli (matris)
    assert client.get("/shifts", headers=hg).status_code == 200
    assert client.get("/checkpoints", headers=hg).status_code == 200
    assert client.get("/patrol-plans", headers=hg).status_code == 200

    # yazma yasak -> 403
    r = client.post(
        "/shifts", headers=hg, json={"ad": "x", "baslangic_saat": "08:00", "bitis_saat": "16:00"}
    )
    assert r.status_code == 403 and r.json()["error"]["code"] == "forbidden"
    assert (
        client.post("/checkpoints", headers=hg, json={"ad": "x", "nfc_tag_uid": "y"}).status_code
        == 403
    )
    assert (
        client.post(
            "/patrol-plans",
            headers=hg,
            json={"ad": "x", "baslangic_saat": "00:00", "bitis_saat": "06:00", "periyot_dakika": 60},
        ).status_code
        == 403
    )
