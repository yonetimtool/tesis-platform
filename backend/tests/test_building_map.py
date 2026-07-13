"""Bina semasi (D-viz-1) — yerlesim (blok/kat/sira) girisi + /building-map.

Kapsam:
  * PATCH /units/{id}/layout — YALNIZ admin + yonetici (digerleri 403);
    kat/sira/blok makul olmali (422).
  * GET /unit-complaints/building-map — blok -> kat -> daire (renk) + 'unplaced'
    kovasi; TUM roller okur; sikayet eden ASLA sizmaz; tenant izolasyonu.

Anonimlik: yerlesim hicbir sikayetci verisi tasimaz (D1'in HARD kurali surer).
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _mk_resident(owner_conn, tenant_id, email, pw):
    from app.security import hash_password

    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role) "
            "VALUES (%s,%s,%s,%s,'resident'::user_role) RETURNING id",
            (tenant_id, f"Sakin {email.split('@')[0]}", email, hash_password(pw)),
        )
        return cur.fetchone()[0]


@pytest.fixture
def mapworld(client, world, owner_conn):
    """world + 3 sakin (renk esigini asmak icin) + suffix (benzersiz daire no)."""
    suffix = uuid.uuid4().hex[:6]
    pw = "MapPass1!"
    residents = []
    for i in range(3):
        email = f"map{i}-{suffix}@acme.com"
        _mk_resident(owner_conn, world["a"], email, pw)
        residents.append({"email": email, "password": pw})
    return {**world, "suffix": suffix, "residents": residents, "pw": pw}


def _create_unit(client, slug, admin, no, **layout):
    body = {"no": no, **layout}
    r = client.post("/units", headers=_headers(client, slug, admin), json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _file(client, slug, resident, target_unit_id):
    return client.post(
        "/unit-complaints",
        headers=_headers(client, slug, resident),
        json={"target_unit_id": target_unit_id, "kategori": "gurultu"},
    )


# ------------------------------ layout RBAC --------------------------------- #
def test_layout_admin_ve_yonetici_yazar_digerleri_403(mapworld, client):
    slug = mapworld["slug_a"]
    u = _create_unit(client, slug, mapworld["admin_a"], f"L-{mapworld['suffix']}")
    uid = u["id"]

    # admin yazabilir
    ra = client.patch(
        f"/units/{uid}/layout",
        headers=_headers(client, slug, mapworld["admin_a"]),
        json={"blok": "A", "kat": 3, "sira": 4},
    )
    assert ra.status_code == 200, ra.text
    assert (ra.json()["blok"], ra.json()["kat"], ra.json()["sira"]) == ("A", 3, 4)

    # yonetici yazabilir (mobilden yonetim)
    ry = client.patch(
        f"/units/{uid}/layout",
        headers=_headers(client, slug, mapworld["yonetici_a"]),
        json={"kat": 5},
    )
    assert ry.status_code == 200, ry.text
    assert ry.json()["kat"] == 5 and ry.json()["blok"] == "A"  # blok korunur

    # security + resident YAZAMAZ -> 403
    for cred in (mapworld["guard_a"], mapworld["gorevli_a"], mapworld["residents"][0]):
        rf = client.patch(
            f"/units/{uid}/layout",
            headers=_headers(client, slug, cred),
            json={"kat": 9},
        )
        assert rf.status_code == 403, rf.text


def test_layout_makul_olmayan_deger_422(mapworld, client):
    slug = mapworld["slug_a"]
    admin = _headers(client, slug, mapworld["admin_a"])
    u = _create_unit(client, slug, mapworld["admin_a"], f"LV-{mapworld['suffix']}")
    uid = u["id"]
    for bad in ({"kat": 9999}, {"sira": -3}, {"blok": "A-1"}, {"blok": "cok-uzun-blok"}, {}):
        r = client.patch(f"/units/{uid}/layout", headers=admin, json=bad)
        assert r.status_code == 422, (bad, r.text)


# --------------------------- building-map yapisi ---------------------------- #
def test_building_map_gruplu_renk_ve_unplaced(mapworld, client):
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    res = mapworld["residents"]

    # blok A / kat 1: iki daire (sira 2 ve 1 — harita sira'ya gore sirali doner)
    ua = _create_unit(client, slug, mapworld["admin_a"], f"A2-{sfx}", blok="A", kat=1, sira=2)
    ub = _create_unit(client, slug, mapworld["admin_a"], f"A1-{sfx}", blok="A", kat=1, sira=1)
    # yerlesimi EKSIK daire (blok yok) -> unplaced
    un = _create_unit(client, slug, mapworld["admin_a"], f"NO-{sfx}")

    # ua'ya 3 sikayet -> sari; ub sikayetsiz -> yesil
    for r in res:
        assert _file(client, slug, r, ua["id"]).status_code == 201

    body = client.get(
        "/unit-complaints/building-map", headers=_headers(client, slug, mapworld["admin_a"])
    ).json()

    blok_a = next(b for b in body["bloklar"] if b["blok"] == "A")
    kat1 = next(k for k in blok_a["katlar"] if k["kat"] == 1)
    # sira'ya gore sirali: A1 (sira 1) once, A2 (sira 2) sonra
    nos = [u["unit_no"] for u in kat1["units"]]
    assert nos.index(f"A1-{sfx}") < nos.index(f"A2-{sfx}")

    by_id = {u["unit_id"]: u for u in kat1["units"]}
    assert by_id[ua["id"]]["complaint_count"] == 3
    assert by_id[ua["id"]]["color"] == "sari"
    assert by_id[ub["id"]]["complaint_count"] == 0
    assert by_id[ub["id"]]["color"] == "yesil"
    # her daire yerlesim alanlarini tasir
    assert by_id[ua["id"]]["blok"] == "A" and by_id[ua["id"]]["kat"] == 1

    # yerlesimsiz daire unplaced kovada, bloklarda DEGIL
    unplaced_ids = {u["unit_id"] for u in body["unplaced"]}
    assert un["id"] in unplaced_ids
    placed_ids = {
        u["unit_id"] for b in body["bloklar"] for k in b["katlar"] for u in k["units"]
    }
    assert un["id"] not in placed_ids


def test_building_map_tum_roller_okur_complainant_sizmaz(mapworld, client):
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    ua = _create_unit(client, slug, mapworld["admin_a"], f"AR-{sfx}", blok="A", kat=1, sira=1)
    # sikayet ac — complainant id'si HICBIR yanitta gorunmemeli
    r0 = mapworld["residents"][0]
    assert _file(client, slug, r0, ua["id"]).status_code == 201

    for cred in (
        mapworld["admin_a"],
        mapworld["yonetici_a"],
        mapworld["guard_a"],
        mapworld["gorevli_a"],
        r0,
    ):
        resp = client.get(
            "/unit-complaints/building-map", headers=_headers(client, slug, cred)
        )
        assert resp.status_code == 200, resp.text
        assert "complainant" not in resp.text
        assert "complainant_user_id" not in resp.text


def test_building_map_tenant_izolasyonu(mapworld, client):
    slug_a = mapworld["slug_a"]
    slug_b = mapworld["slug_b"]
    sfx = mapworld["suffix"]
    ua = _create_unit(client, slug_a, mapworld["admin_a"], f"TA-{sfx}", blok="A", kat=1, sira=1)

    # B tenant'inin haritasinda A'nin dairesi GORUNMEZ
    body_b = client.get(
        "/unit-complaints/building-map", headers=_headers(client, slug_b, mapworld["admin_b"])
    ).json()
    all_b_ids = (
        {u["unit_id"] for b in body_b["bloklar"] for k in b["katlar"] for u in k["units"]}
        | {u["unit_id"] for u in body_b["unplaced"]}
    )
    assert ua["id"] not in all_b_ids
