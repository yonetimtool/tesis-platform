"""Asset CRUD + zimmet (checkout/checkin/history) testleri."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _new_asset(client, admin, **over):
    body = {"ad": "Cim bicme makinesi", "kategori": "ekipman"}
    body.update(over)
    r = client.post("/assets", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# -------------------------------- CRUD ------------------------------------- #
def test_asset_crud_and_nfc_conflict(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    nfc = f"AST-{uuid.uuid4().hex[:8]}"
    a = _new_asset(client, admin, nfc_tag_uid=nfc)
    aid = a["id"]
    assert a["durum"] == "musait"

    assert client.get(f"/assets/{aid}", headers=admin).status_code == 200

    lst = client.get("/assets", headers=admin, params={"kategori": "ekipman", "limit": 10}).json()
    assert lst["meta"]["limit"] == 10 and any(it["id"] == aid for it in lst["items"])

    # nfc cakismasi -> 409
    dup = client.post("/assets", headers=admin, json={"ad": "x", "nfc_tag_uid": nfc})
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"

    assert client.patch(f"/assets/{aid}", headers=admin, json={"durum": "bakimda"}).json()["durum"] == "bakimda"
    assert client.delete(f"/assets/{aid}", headers=admin).status_code == 204
    assert client.get(f"/assets/{aid}", headers=admin).status_code == 404


def test_asset_rbac_and_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    cleaning = _headers(client, world["slug_a"], world["cleaning_a"])

    a = _new_asset(client, admin_a)
    # cleaning Asset CRUD yapamaz
    assert client.post("/assets", headers=cleaning, json={"ad": "x"}).status_code == 403
    # B, A'nin asset'ini goremez
    assert client.get(f"/assets/{a['id']}", headers=admin_b).status_code == 404


# ------------------------------ checkout ----------------------------------- #
def test_checkout_idempotency_and_400(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin)
    key = uuid.uuid4().hex
    hdr = {**guard, "Idempotency-Key": key}

    first = client.post(f"/assets/{a['id']}/checkout", headers=hdr, json={"notlar": "aldim"})
    assert first.status_code == 201, first.text
    cid = first.json()["id"]
    assert first.json()["alan_user_id"] == client.get("/me", headers=guard).json()["id"]

    # durum zimmetli
    assert client.get(f"/assets/{a['id']}", headers=admin).json()["durum"] == "zimmetli"

    # ayni key + ayni govde -> 200 ayni kayit
    again = client.post(f"/assets/{a['id']}/checkout", headers=hdr, json={"notlar": "aldim"})
    assert again.status_code == 200 and again.json()["id"] == cid

    # ayni key + farkli govde -> 409
    diff = client.post(f"/assets/{a['id']}/checkout", headers=hdr, json={"notlar": "baska"})
    assert diff.status_code == 409

    # key yok -> 400
    nokey = client.post(f"/assets/{a['id']}/checkout", headers=guard, json={})
    assert nokey.status_code == 400 and nokey.json()["error"]["code"] == "bad_request"


def test_checkout_already_assigned_409_single_open(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    cleaning = _headers(client, world["slug_a"], world["cleaning_a"])
    a = _new_asset(client, admin)

    assert client.post(
        f"/assets/{a['id']}/checkout", headers={**guard, "Idempotency-Key": uuid.uuid4().hex}, json={}
    ).status_code == 201

    # baska kullanici/baska key ile tekrar checkout -> 409 (zaten zimmetli)
    second = client.post(
        f"/assets/{a['id']}/checkout", headers={**cleaning, "Idempotency-Key": uuid.uuid4().hex}, json={}
    )
    assert second.status_code == 409

    # tek aktif zimmet: history'de acik (birakma_zamani null) kayit sayisi == 1
    hist = client.get(f"/assets/{a['id']}/history", headers=admin).json()["items"]
    assert sum(1 for h in hist if h["birakma_zamani"] is None) == 1


def test_checkout_nfc_mismatch(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin, nfc_tag_uid=f"AST-{uuid.uuid4().hex[:8]}")

    bad = client.post(
        f"/assets/{a['id']}/checkout",
        headers={**guard, "Idempotency-Key": uuid.uuid4().hex},
        json={"nfc_tag_uid": "YANLIS"},
    )
    assert bad.status_code == 422

    ok = client.post(
        f"/assets/{a['id']}/checkout",
        headers={**guard, "Idempotency-Key": uuid.uuid4().hex},
        json={"nfc_tag_uid": a["nfc_tag_uid"]},
    )
    assert ok.status_code == 201


def test_checkout_tenant_isolation(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    guard_b = _headers(client, world["slug_b"], world["admin_b"])  # B tarafi
    a = _new_asset(client, admin_a)
    # B, A'nin asset'ini alamaz -> 404
    r = client.post(
        f"/assets/{a['id']}/checkout", headers={**guard_b, "Idempotency-Key": uuid.uuid4().hex}, json={}
    )
    assert r.status_code == 404


def test_checkout_rbac_resident(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    a = _new_asset(client, admin)
    r = client.post(
        f"/assets/{a['id']}/checkout", headers={**resident, "Idempotency-Key": uuid.uuid4().hex}, json={}
    )
    assert r.status_code == 403


# ------------------------------- checkin ----------------------------------- #
def test_checkin_closes_and_idempotent(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin)
    client.post(f"/assets/{a['id']}/checkout", headers={**guard, "Idempotency-Key": uuid.uuid4().hex}, json={})

    ckey = uuid.uuid4().hex
    ci = client.post(f"/assets/{a['id']}/checkin", headers={**guard, "Idempotency-Key": ckey}, json={})
    assert ci.status_code == 200 and ci.json()["birakma_zamani"] is not None
    # durum musait
    assert client.get(f"/assets/{a['id']}", headers=admin).json()["durum"] == "musait"

    # idempotent tekrar (ayni checkin key) -> 200 ayni kayit
    again = client.post(f"/assets/{a['id']}/checkin", headers={**guard, "Idempotency-Key": ckey}, json={})
    assert again.status_code == 200 and again.json()["id"] == ci.json()["id"]


def test_checkin_without_open_409(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin)  # hic zimmetlenmedi
    r = client.post(f"/assets/{a['id']}/checkin", headers={**guard, "Idempotency-Key": uuid.uuid4().hex}, json={})
    assert r.status_code == 409


def test_checkin_missing_key_400(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin)
    client.post(f"/assets/{a['id']}/checkout", headers={**guard, "Idempotency-Key": uuid.uuid4().hex}, json={})
    r = client.post(f"/assets/{a['id']}/checkin", headers=guard, json={})
    assert r.status_code == 400


# ------------------------------- history ----------------------------------- #
def test_history_records_cycle(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin)

    client.post(f"/assets/{a['id']}/checkout", headers={**guard, "Idempotency-Key": uuid.uuid4().hex}, json={})
    client.post(f"/assets/{a['id']}/checkin", headers={**guard, "Idempotency-Key": uuid.uuid4().hex}, json={})
    client.post(f"/assets/{a['id']}/checkout", headers={**guard, "Idempotency-Key": uuid.uuid4().hex}, json={})

    hist = client.get(f"/assets/{a['id']}/history", headers=admin).json()
    assert hist["meta"]["total"] == 2
    # tam olarak bir acik zimmet (son checkout)
    assert sum(1 for h in hist["items"] if h["birakma_zamani"] is None) == 1
