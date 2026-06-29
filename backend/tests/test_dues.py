"""Aidat: unit CRUD + sakin + tahakkuk + odeme (idempotent) + bakiye + RBAC + izolasyon."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _new_unit(client, admin, no=None):
    no = no or f"A-{uuid.uuid4().hex[:6]}"
    r = client.post("/units", headers=admin, json={"no": no, "blok": "A"})
    assert r.status_code == 201, r.text
    return r.json()


# -------------------------------- unit ------------------------------------- #
def test_unit_crud_and_no_conflict(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    no = f"A-{uuid.uuid4().hex[:6]}"
    u = _new_unit(client, admin, no)
    assert client.get(f"/units/{u['id']}", headers=admin).status_code == 200
    assert client.get("/units", headers=admin).json()["meta"]["total"] >= 1
    assert client.patch(f"/units/{u['id']}", headers=admin, json={"blok": "B"}).json()["blok"] == "B"
    # ayni no -> 409
    assert client.post("/units", headers=admin, json={"no": no}).status_code == 409
    assert client.delete(f"/units/{u['id']}", headers=admin).status_code == 204
    assert client.get(f"/units/{u['id']}", headers=admin).status_code == 404


def test_unit_rbac_and_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    cleaning = _headers(client, world["slug_a"], world["cleaning_a"])
    u = _new_unit(client, admin_a)
    assert client.post("/units", headers=cleaning, json={"no": "X-1"}).status_code == 403
    assert client.get(f"/units/{u['id']}", headers=admin_b).status_code == 404


# ----------------------------- tahakkuk ------------------------------------ #
def test_assessment_duplicate_and_bulk(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u1 = _new_unit(client, admin)
    u2 = _new_unit(client, admin)

    # tek daire
    r = client.post("/dues/assessments", headers=admin, json={"unit_id": u1["id"], "donem": "2026-07", "tutar_kurus": 75000})
    assert r.status_code == 201 and len(r.json()["created"]) == 1
    # ayni daire+donem ikinci kez -> 409
    dup = client.post("/dues/assessments", headers=admin, json={"unit_id": u1["id"], "donem": "2026-07", "tutar_kurus": 75000})
    assert dup.status_code == 409

    # toplu (unit_ids)
    bulk = client.post("/dues/assessments", headers=admin, json={"unit_ids": [u1["id"], u2["id"]], "donem": "2026-08", "tutar_kurus": 80000})
    assert bulk.status_code == 201 and len(bulk.json()["created"]) == 2 and bulk.json()["atlanan"] == 0
    # ikinci toplu ayni donem -> hepsi atlanir
    bulk2 = client.post("/dues/assessments", headers=admin, json={"unit_ids": [u1["id"], u2["id"]], "donem": "2026-08", "tutar_kurus": 80000})
    assert bulk2.json()["atlanan"] == 2 and len(bulk2.json()["created"]) == 0


def test_assessment_amount_must_be_positive(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    assert client.post("/dues/assessments", headers=admin, json={"unit_id": u["id"], "donem": "2026-09", "tutar_kurus": 0}).status_code == 422
    assert client.post("/dues/assessments", headers=admin, json={"unit_id": u["id"], "donem": "2026-09", "tutar_kurus": -5}).status_code == 422


# ------------------------------- odeme ------------------------------------- #
def test_payment_idempotency_balance_and_partial(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    a = client.post("/dues/assessments", headers=admin, json={"unit_id": u["id"], "donem": "2026-10", "tutar_kurus": 75000}).json()["created"][0]

    key = uuid.uuid4().hex
    hdr = {**admin, "Idempotency-Key": key}
    payload = {"unit_id": u["id"], "assessment_id": a["id"], "tutar_kurus": 50000, "yontem": "elden"}

    p = client.post("/dues/payments", headers=hdr, json=payload)
    assert p.status_code == 201 and p.json()["durum"] == "basarili"

    # idempotent ayni -> 200 ayni kayit
    again = client.post("/dues/payments", headers=hdr, json=payload)
    assert again.status_code == 200 and again.json()["id"] == p.json()["id"]
    # farkli govde -> 409
    assert client.post("/dues/payments", headers=hdr, json={**payload, "tutar_kurus": 60000}).status_code == 409
    # key yok -> 400
    assert client.post("/dues/payments", headers=admin, json=payload).status_code == 400

    # kismi odeme sonrasi bakiye = 75000 - 50000 = 25000
    st = client.get(f"/units/{u['id']}/dues", headers=admin).json()
    assert st["toplam_tahakkuk_kurus"] == 75000
    assert st["toplam_odenen_kurus"] == 50000
    assert st["bakiye_kurus"] == 25000

    # kalan odeme -> bakiye 0
    client.post("/dues/payments", headers={**admin, "Idempotency-Key": uuid.uuid4().hex},
                json={"unit_id": u["id"], "tutar_kurus": 25000, "yontem": "havale"})
    st2 = client.get(f"/units/{u['id']}/dues", headers=admin).json()
    assert st2["bakiye_kurus"] == 0


def test_payment_amount_positive(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    u = _new_unit(client, admin)
    r = client.post("/dues/payments", headers={**admin, "Idempotency-Key": uuid.uuid4().hex},
                    json={"unit_id": u["id"], "tutar_kurus": 0, "yontem": "elden"})
    assert r.status_code == 422


# ----------------------------- resident ------------------------------------ #
def test_resident_me_dues_and_isolation(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    resident_id = client.get("/me", headers=resident).json()["id"]

    u1 = _new_unit(client, admin)
    u2 = _new_unit(client, admin)  # resident bu daireye BAGLI DEGIL
    # resident'i u1'e ata
    asg = client.post(f"/units/{u1['id']}/residents", headers=admin, json={"user_id": resident_id, "rol_tipi": "malik"})
    assert asg.status_code == 201
    client.post("/dues/assessments", headers=admin, json={"unit_id": u1["id"], "donem": "2026-11", "tutar_kurus": 90000})

    me = client.get("/me/dues", headers=resident)
    assert me.status_code == 200
    items = me.json()["items"]
    unit_ids = [it["unit_id"] for it in items]
    assert u1["id"] in unit_ids
    assert u2["id"] not in unit_ids        # baska daireyi GORMEZ
    own = next(it for it in items if it["unit_id"] == u1["id"])
    assert own["bakiye_kurus"] == 90000

    # resident tahakkuk/odeme YAPAMAZ -> 403
    assert client.post("/dues/assessments", headers=resident, json={"unit_id": u1["id"], "donem": "2026-12", "tutar_kurus": 1000}).status_code == 403
    assert client.post("/dues/payments", headers={**resident, "Idempotency-Key": uuid.uuid4().hex},
                       json={"unit_id": u1["id"], "tutar_kurus": 1000, "yontem": "elden"}).status_code == 403
    # security aidat gormez
    guard = _headers(client, world["slug_a"], world["guard_a"])
    assert client.get("/dues/assessments", headers=guard).status_code == 403


def test_dues_tenant_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    u = _new_unit(client, admin_a)
    client.post("/dues/assessments", headers=admin_a, json={"unit_id": u["id"], "donem": "2027-01", "tutar_kurus": 10000})
    # B, A'nin dairesinin borcunu goremez
    assert client.get(f"/units/{u['id']}/dues", headers=admin_b).status_code == 404
