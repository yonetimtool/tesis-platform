"""Bina semasi (D-viz) — yerlesim + ROL-FARKINDA /building-map (Rev-1).

Kapsam:
  * PATCH /units/{id}/layout — admin + yonetici (digerleri 403); makul deger (422).
  * GET /unit-complaints/building-map — ROL-FARKINDA:
      - yonetici/admin: sayim + renk (shows_density=True) + tam yapi.
      - resident: YALNIZ KENDI blogu; sayim/renk NULL (shows_density=False).
      - security/tesis_gorevlisi: TUM yapi; sayim/renk NULL.
  * complainant bu uctan ASLA donmez (harita). Tenant izolasyonu.
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


def _link(owner_conn, tenant_id, unit_id, user_id):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
            (tenant_id, unit_id, user_id),
        )


def _create_unit(client, slug, admin, no, **layout):
    body = {"no": no, **layout}
    r = client.post("/units", headers=_headers(client, slug, admin), json=body)
    assert r.status_code == 201, r.text
    return r.json()


@pytest.fixture
def mapworld(client, world, owner_conn):
    """world + 3 sakin BLOK A'ya bagli (own-block ile A dairelerini sikayet
    edebilir) + suffix."""
    suffix = uuid.uuid4().hex[:6]
    pw = "MapPass1!"
    # Sakinlerin blogu: admin bir "ev" dairesi (blok A) acar, 3 sakini baglar.
    home = _create_unit(client, world["slug_a"], world["admin_a"], f"HOME-A-{suffix}", blok="A", kat=0, sira=1)
    residents = []
    for i in range(3):
        email = f"map{i}-{suffix}@acme.com"
        rid = _mk_resident(owner_conn, world["a"], email, pw)
        _link(owner_conn, world["a"], uuid.UUID(home["id"]), rid)
        residents.append({"email": email, "password": pw, "id": str(rid)})
    return {**world, "suffix": suffix, "residents": residents, "pw": pw, "home": home}


def _file(client, slug, resident, target_unit_id):
    return client.post(
        "/unit-complaints",
        headers=_headers(client, slug, resident),
        json={"target_unit_id": target_unit_id, "kategori": "gurultu"},
    )


def _all_units(body):
    return [u for b in body["bloklar"] for k in b["katlar"] for u in k["units"]] + list(body["unplaced"])


# ------------------------------ layout RBAC --------------------------------- #
def test_layout_admin_ve_yonetici_yazar_digerleri_403(mapworld, client):
    slug = mapworld["slug_a"]
    u = _create_unit(client, slug, mapworld["admin_a"], f"L-{mapworld['suffix']}")
    uid = u["id"]

    ra = client.patch(
        f"/units/{uid}/layout",
        headers=_headers(client, slug, mapworld["admin_a"]),
        json={"blok": "A", "kat": 3, "sira": 4},
    )
    assert ra.status_code == 200, ra.text
    assert (ra.json()["blok"], ra.json()["kat"], ra.json()["sira"]) == ("A", 3, 4)

    ry = client.patch(
        f"/units/{uid}/layout",
        headers=_headers(client, slug, mapworld["yonetici_a"]),
        json={"kat": 5},
    )
    assert ry.status_code == 200, ry.text
    assert ry.json()["kat"] == 5 and ry.json()["blok"] == "A"

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


# ------------------ yonetim: sayim + renk + shows_density ------------------- #
def test_building_map_yonetim_sayim_renk_ve_unplaced(mapworld, client):
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    res = mapworld["residents"]

    ua = _create_unit(client, slug, mapworld["admin_a"], f"A2-{sfx}", blok="A", kat=1, sira=2)
    ub = _create_unit(client, slug, mapworld["admin_a"], f"A1-{sfx}", blok="A", kat=1, sira=1)
    un = _create_unit(client, slug, mapworld["admin_a"], f"NO-{sfx}")  # yerlesimsiz

    for r in res:  # sakinler blok A -> ua (blok A) sikayet edebilir
        assert _file(client, slug, r, ua["id"]).status_code == 201

    body = client.get(
        "/unit-complaints/building-map", headers=_headers(client, slug, mapworld["admin_a"])
    ).json()
    assert body["shows_density"] is True

    blok_a = next(b for b in body["bloklar"] if b["blok"] == "A")
    kat1 = next(k for k in blok_a["katlar"] if k["kat"] == 1)
    nos = [u["unit_no"] for u in kat1["units"]]
    assert nos.index(f"A1-{sfx}") < nos.index(f"A2-{sfx}")

    by_id = {u["unit_id"]: u for u in kat1["units"]}
    assert by_id[ua["id"]]["complaint_count"] == 3 and by_id[ua["id"]]["color"] == "sari"
    assert by_id[ub["id"]]["complaint_count"] == 0 and by_id[ub["id"]]["color"] == "yesil"

    unplaced_ids = {u["unit_id"] for u in body["unplaced"]}
    assert un["id"] in unplaced_ids


# ------------------ resident: yapi, sayim/renk YOK, own-block --------------- #
def test_building_map_resident_yapi_only_own_block(mapworld, client):
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    _create_unit(client, slug, mapworld["admin_a"], f"A1-{sfx}", blok="A", kat=1, sira=1)
    _create_unit(client, slug, mapworld["admin_a"], f"B1-{sfx}", blok="B", kat=1, sira=1)

    body = client.get(
        "/unit-complaints/building-map", headers=_headers(client, slug, mapworld["residents"][0])
    ).json()
    assert body["shows_density"] is False
    # resident YALNIZ kendi blogu (A) — B gorunmez
    bloklar = {b["blok"] for b in body["bloklar"]}
    assert "A" in bloklar and "B" not in bloklar
    # sayim + renk NULL (resident hangi dairenin kac sikayeti oldugunu BILEMEZ)
    for u in _all_units(body):
        assert u["complaint_count"] is None and u["color"] is None


def test_building_map_resident_kendi_sikayeti_isaretli(mapworld, client):
    """FIX (Rev-1.1): resident KENDI sikayet ettigi daireyi harita uzerinde
    isaretli gorur (benim_sikayetim + benim_acik_sayisi=KENDI acik sayim);
    sikayet etmedigi daire noturr. Genel yogunluk (sayi/renk) YINE gizli."""
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    ua = _create_unit(client, slug, mapworld["admin_a"], f"OWN-{sfx}", blok="A", kat=1, sira=1)
    ub = _create_unit(client, slug, mapworld["admin_a"], f"OTH-{sfx}", blok="A", kat=1, sira=2)
    r0 = mapworld["residents"][0]
    # 1 POST = 1 kayit -> benim_acik_sayisi TAM 1 (cift sayim yok)
    assert _file(client, slug, r0, ua["id"]).status_code == 201

    body = client.get(
        "/unit-complaints/building-map", headers=_headers(client, slug, r0)
    ).json()
    assert body["shows_density"] is False
    by_id = {u["unit_id"]: u for u in _all_units(body)}
    own, oth = by_id[ua["id"]], by_id[ub["id"]]
    # KENDI sikayet ettigi daire isaretli; genel yogunluk YINE gizli
    assert own["benim_sikayetim"] is True and own["benim_acik_sayisi"] == 1
    assert own["complaint_count"] is None and own["color"] is None
    # Sikayet etmedigi daire noturr
    assert oth["benim_sikayetim"] is False and oth["benim_acik_sayisi"] == 0


def test_building_map_resident_baskasinin_sikayetini_gormez(mapworld, client):
    """GIZLILIK: resident YALNIZ KENDI sikayetini isaretli gorur. Baska sakinin
    ayni daireye actigi sikayet ona benim_sikayetim=True YAPMAZ ve sayiya
    SIZMAZ (own-scope)."""
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    ua = _create_unit(client, slug, mapworld["admin_a"], f"SHR-{sfx}", blok="A", kat=1, sira=1)
    r0, r1 = mapworld["residents"][0], mapworld["residents"][1]
    # r1 sikayet acar; r0 ACMAZ
    assert _file(client, slug, r1, ua["id"]).status_code == 201

    # r0 acisindan: kendi sikayeti YOK -> isaret yok; r1'in kaydi SIZMAZ
    body0 = client.get(
        "/unit-complaints/building-map", headers=_headers(client, slug, r0)
    ).json()
    own0 = next(u for u in _all_units(body0) if u["unit_id"] == ua["id"])
    assert own0["benim_sikayetim"] is False and own0["benim_acik_sayisi"] == 0
    assert own0["complaint_count"] is None

    # r1 acisindan: KENDI sikayeti isaretli
    body1 = client.get(
        "/unit-complaints/building-map", headers=_headers(client, slug, r1)
    ).json()
    own1 = next(u for u in _all_units(body1) if u["unit_id"] == ua["id"])
    assert own1["benim_sikayetim"] is True and own1["benim_acik_sayisi"] == 1


def test_building_map_yonetim_benim_isareti_kullanmaz(mapworld, client):
    """Yonetim gorunumu benim_sikayetim isareti KULLANMAZ (denetim sayim/renk
    kullanir): benim_sikayetim False, benim_acik_sayisi None. Sayim 1 dosya =
    1 kayit (2 degil)."""
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    ua = _create_unit(client, slug, mapworld["admin_a"], f"MGF-{sfx}", blok="A", kat=1, sira=1)
    assert _file(client, slug, mapworld["residents"][0], ua["id"]).status_code == 201
    for cred in (mapworld["admin_a"], mapworld["yonetici_a"]):
        body = client.get(
            "/unit-complaints/building-map", headers=_headers(client, slug, cred)
        ).json()
        u = next(u for u in _all_units(body) if u["unit_id"] == ua["id"])
        assert u["benim_sikayetim"] is False and u["benim_acik_sayisi"] is None
        assert u["complaint_count"] == 1  # 1 dosya = 1 kayit


def test_building_map_security_gorevli_yapi_only_tum_bina(mapworld, client):
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    _create_unit(client, slug, mapworld["admin_a"], f"A1-{sfx}", blok="A", kat=1, sira=1)
    _create_unit(client, slug, mapworld["admin_a"], f"B1-{sfx}", blok="B", kat=1, sira=1)

    for cred in (mapworld["guard_a"], mapworld["gorevli_a"]):
        body = client.get(
            "/unit-complaints/building-map", headers=_headers(client, slug, cred)
        ).json()
        assert body["shows_density"] is False
        # saha rolleri TUM yapiyi gorur (A + B) ama sayim/renk YOK
        bloklar = {b["blok"] for b in body["bloklar"]}
        assert {"A", "B"} <= bloklar
        for u in _all_units(body):
            assert u["complaint_count"] is None and u["color"] is None


def test_building_map_complainant_hicbir_rolde_sizmaz(mapworld, client):
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    ua = _create_unit(client, slug, mapworld["admin_a"], f"AR-{sfx}", blok="A", kat=1, sira=1)
    r0 = mapworld["residents"][0]
    assert _file(client, slug, r0, ua["id"]).status_code == 201
    for cred in (
        mapworld["admin_a"], mapworld["yonetici_a"],
        mapworld["guard_a"], mapworld["gorevli_a"], r0,
    ):
        resp = client.get(
            "/unit-complaints/building-map", headers=_headers(client, slug, cred)
        )
        assert resp.status_code == 200
        assert "complainant" not in resp.text


def test_building_map_yonetici_sayim_renk_ve_complainant_detay(mapworld, client):
    """FIX (Rev-1.1): YONETICI de (admin gibi) sayim+renk gorur; daire
    detayinda (liste) complainant kimligi + not doner. Bu test yonetici
    gorunumunu ACIKCA egzersiz eder (regresyon korumasi)."""
    slug = mapworld["slug_a"]
    sfx = mapworld["suffix"]
    ua = _create_unit(client, slug, mapworld["admin_a"], f"YM-{sfx}", blok="A", kat=1, sira=1)
    r0 = mapworld["residents"][0]  # blok A sakini
    assert _file(client, slug, r0, ua["id"]).status_code == 201

    yon = _headers(client, slug, mapworld["yonetici_a"])
    # 1) YONETICI building-map: shows_density + sayim + renk DOLU
    body = client.get("/unit-complaints/building-map", headers=yon).json()
    assert body["shows_density"] is True
    u = next(u for u in _all_units(body) if u["unit_id"] == ua["id"])
    assert u["complaint_count"] == 1 and u["color"] == "yesil"

    # 2) YONETICI daire detayi (liste): complainant kimligi + adi + not doner
    lst = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": ua["id"]}
    ).json()["items"]
    assert lst and lst[0]["complainant_user_id"] == r0["id"]
    assert lst[0]["complainant_ad"]


def test_building_map_tenant_izolasyonu(mapworld, client):
    slug_a, slug_b, sfx = mapworld["slug_a"], mapworld["slug_b"], mapworld["suffix"]
    ua = _create_unit(client, slug_a, mapworld["admin_a"], f"TA-{sfx}", blok="A", kat=1, sira=1)
    body_b = client.get(
        "/unit-complaints/building-map", headers=_headers(client, slug_b, mapworld["admin_b"])
    ).json()
    assert ua["id"] not in {u["unit_id"] for u in _all_units(body_b)}
