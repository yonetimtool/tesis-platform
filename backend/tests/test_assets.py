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
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])

    a = _new_asset(client, admin_a)
    # gorevli Asset CRUD yapamaz
    assert client.post("/assets", headers=gorevli, json={"ad": "x"}).status_code == 403
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
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    a = _new_asset(client, admin)

    assert client.post(
        f"/assets/{a['id']}/checkout", headers={**guard, "Idempotency-Key": uuid.uuid4().hex}, json={}
    ).status_code == 201

    # baska kullanici/baska key ile tekrar checkout -> 409 (zaten zimmetli)
    second = client.post(
        f"/assets/{a['id']}/checkout", headers={**gorevli, "Idempotency-Key": uuid.uuid4().hex}, json={}
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


# ----------------------- checkin sahiplik (mobil §13 #6) ------------------- #
def _checkout(client, headers, asset_id, **body):
    r = client.post(
        f"/assets/{asset_id}/checkout",
        headers={**headers, "Idempotency-Key": uuid.uuid4().hex},
        json=body,
    )
    assert r.status_code == 201, r.text
    return r.json()


def _checkin(client, headers, asset_id, **body):
    return client.post(
        f"/assets/{asset_id}/checkin",
        headers={**headers, "Idempotency-Key": uuid.uuid4().hex},
        json=body,
    )


def test_checkin_ownership_other_user_403(client, world):
    """Acik zimmet baskasindaysa checkin 403; sahibi kapatabilir."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    a = _new_asset(client, admin)
    _checkout(client, guard, a["id"])

    r = _checkin(client, gorevli, a["id"])
    assert r.status_code == 403, r.text
    assert r.json()["error"]["code"] == "forbidden"
    assert "baskasinin uzerinde" in r.json()["error"]["message"]

    # zimmet hala acik, sahibi kapatabilir
    assert client.get(f"/assets/{a['id']}", headers=admin).json()["durum"] == "zimmetli"
    assert _checkin(client, guard, a["id"]).status_code == 200


def test_checkin_admin_override_200(client, world):
    """Admin, baskasinin zimmetini kapatabilir (yonetici mudahalesi)."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin)
    _checkout(client, guard, a["id"])

    r = _checkin(client, admin, a["id"])
    assert r.status_code == 200, r.text
    assert r.json()["birakma_zamani"] is not None
    assert client.get(f"/assets/{a['id']}", headers=admin).json()["durum"] == "musait"


# ----------------------- nfc filtresi (mobil §13 #1) ----------------------- #
def test_list_assets_nfc_filter(client, world):
    """?nfc_tag_uid= tam eslesme; bulunamayan bos liste; tenant-izole."""
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])
    nfc = f"AST-{uuid.uuid4().hex[:8]}"
    a = _new_asset(client, admin_a, nfc_tag_uid=nfc)
    _new_asset(client, admin_a, nfc_tag_uid=f"AST-{uuid.uuid4().hex[:8]}")

    body = client.get("/assets", headers=admin_a, params={"nfc_tag_uid": nfc}).json()
    assert body["meta"]["total"] == 1
    assert body["items"][0]["id"] == a["id"]

    yok = client.get("/assets", headers=admin_a, params={"nfc_tag_uid": "YOK-BOYLE"}).json()
    assert yok["meta"]["total"] == 0 and yok["items"] == []

    # B, A'nin nfc'siyle bulamaz (RLS)
    izole = client.get("/assets", headers=admin_b, params={"nfc_tag_uid": nfc}).json()
    assert izole["meta"]["total"] == 0


# -------------------- acik_zimmet ozeti (mobil §13 #2+#5) ------------------ #
def test_asset_acik_zimmet_field(client, world):
    """Detay/listede acik_zimmet: null | {alan_user_id, alan_user_ad, alinma_zamani}."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]
    a = _new_asset(client, admin)

    # zimmet yokken null
    assert client.get(f"/assets/{a['id']}", headers=admin).json()["acik_zimmet"] is None

    _checkout(client, guard, a["id"])
    det = client.get(f"/assets/{a['id']}", headers=admin).json()
    az = det["acik_zimmet"]
    assert az is not None
    assert az["alan_user_id"] == guard_id
    assert az["alan_user_ad"] == "Guard A"
    assert az["alinma_zamani"] is not None

    # listede de dolu
    lst = client.get("/assets", headers=admin, params={"durum": "zimmetli", "limit": 200}).json()
    item = next(it for it in lst["items"] if it["id"] == a["id"])
    assert item["acik_zimmet"]["alan_user_ad"] == "Guard A"

    # checkin sonrasi tekrar null
    _checkin(client, guard, a["id"])
    assert client.get(f"/assets/{a['id']}", headers=admin).json()["acik_zimmet"] is None


# ------------------ checked_out_by=me filtresi (mobil §13 #3) -------------- #
def test_list_assets_checked_out_by_me(client, world):
    """?checked_out_by=me -> yalniz token kullanicisinin acik zimmetindekiler."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])

    mine = _new_asset(client, admin)      # guard alacak
    theirs = _new_asset(client, admin)    # gorevli alacak
    _new_asset(client, admin)             # bos kalacak
    _checkout(client, guard, mine["id"])
    _checkout(client, gorevli, theirs["id"])

    body = client.get("/assets", headers=guard, params={"checked_out_by": "me", "limit": 200}).json()
    ids = [it["id"] for it in body["items"]]
    assert mine["id"] in ids and theirs["id"] not in ids
    assert all(it["acik_zimmet"] is not None for it in body["items"])

    # iade edince listeden duser
    _checkin(client, guard, mine["id"])
    body2 = client.get("/assets", headers=guard, params={"checked_out_by": "me", "limit": 200}).json()
    assert mine["id"] not in [it["id"] for it in body2["items"]]


def test_list_assets_checked_out_by_user_id_admin_only(client, world):
    """checked_out_by=<uuid>: admin gorebilir; digerleri icin 403."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]
    a = _new_asset(client, admin)
    _checkout(client, guard, a["id"])

    body = client.get("/assets", headers=admin, params={"checked_out_by": guard_id}).json()
    assert a["id"] in [it["id"] for it in body["items"]]

    # security kendi UUID'siyle bile 'me' kullanmali -> 403 (sozlesme: UUID yalniz admin)
    r = client.get("/assets", headers=guard, params={"checked_out_by": guard_id})
    assert r.status_code == 403

    # gecersiz deger -> 422
    r = client.get("/assets", headers=admin, params={"checked_out_by": "bozuk"})
    assert r.status_code == 422


# ------------- history siralama + alan_user_ad (mobil §13 #4+#5) ----------- #
def test_history_order_default_desc_and_asc_param(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin)

    first = _checkout(client, guard, a["id"])
    _checkin(client, guard, a["id"])
    second = _checkout(client, guard, a["id"])

    # varsayilan: en yeni ustte (DESC)
    hist = client.get(f"/assets/{a['id']}/history", headers=admin).json()["items"]
    assert [h["id"] for h in hist] == [second["id"], first["id"]]

    # ?order=asc eski davranis
    asc = client.get(f"/assets/{a['id']}/history", headers=admin, params={"order": "asc"}).json()["items"]
    assert [h["id"] for h in asc] == [first["id"], second["id"]]


def test_history_items_include_alan_user_ad(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    a = _new_asset(client, admin)
    _checkout(client, guard, a["id"])

    hist = client.get(f"/assets/{a['id']}/history", headers=admin).json()["items"]
    assert hist[0]["alan_user_id"] is not None
    assert hist[0]["alan_user_ad"] == "Guard A"


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


# ------------------- birakan_user_id (demirbas bulgusu) --------------------- #
def test_checkin_records_birakan_owner_and_admin(client, world):
    """checkin sonrasi birakan_user_id dolu (sahibi ve admin senaryolari); history'de ad."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    guard_id = client.get("/me", headers=guard).json()["id"]
    admin_id = client.get("/me", headers=admin).json()["id"]

    # 1) sahibi birakir -> birakan = sahibi
    a = _new_asset(client, admin)
    _checkout(client, guard, a["id"])
    ci = _checkin(client, guard, a["id"])
    assert ci.status_code == 200, ci.text
    assert ci.json()["birakan_user_id"] == guard_id
    assert ci.json()["birakan_user_ad"] == "Guard A"

    # 2) admin mudahalesi -> birakan = admin (alan hala guard)
    _checkout(client, guard, a["id"])
    ci2 = _checkin(client, admin, a["id"])
    assert ci2.json()["birakan_user_id"] == admin_id
    assert ci2.json()["alan_user_id"] == guard_id

    # acik zimmetteyken birakan alanlari bos
    b = _new_asset(client, admin)
    co = _checkout(client, guard, b["id"])
    assert co["birakan_user_id"] is None and co["birakan_user_ad"] is None

    # history: kapali kayitlarda birakan id+ad birlikte gorunur
    hist = client.get(f"/assets/{a['id']}/history", headers=admin, params={"order": "asc"}).json()["items"]
    assert hist[0]["birakan_user_id"] == guard_id and hist[0]["birakan_user_ad"] == "Guard A"
    assert hist[1]["birakan_user_id"] == admin_id and hist[1]["birakan_user_ad"] == "Admin A"
