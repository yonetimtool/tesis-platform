"""Daire sikayeti (D1) — TAM ANONIM + spam korumasi + renk esikleri + RBAC.

HARD KURAL: complainant_user_id HICBIR yanitta (density/liste/detay/olusturma/
kapatma) GORUNMEZ — yonetici/admin dahil. Yonetimin ayri /complaints modulunden
bagimsizdir.
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
            "INSERT INTO app_user (tenant_id, ad, email, password_hash, role, password_set) "
            "VALUES (%s,%s,%s,%s,'resident'::user_role, true) RETURNING id",
            (tenant_id, f"Sakin {email.split('@')[0]}", email, hash_password(pw)),
        )
        return cur.fetchone()[0]


def _mk_unit(owner_conn, tenant_id, no):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
            (tenant_id, no),
        )
        return cur.fetchone()[0]


@pytest.fixture
def ucworld(client, world, owner_conn):
    """world + hedef daireler + 6 sakin (renk esiklerini asmak icin coklu
    sikayetci — spam korumasi sakin-basi 1 acik ile sinirlar)."""
    a = world["a"]
    suffix = uuid.uuid4().hex[:6]
    pw = "UcPass1!"
    residents = []  # (email, id, creds)
    for i in range(6):
        email = f"uc{i}-{suffix}@acme.com"
        rid = _mk_resident(owner_conn, a, email, pw)
        residents.append({"email": email, "password": pw, "id": str(rid)})

    unit1 = _mk_unit(owner_conn, a, f"UC-1-{suffix}")
    unit2 = _mk_unit(owner_conn, a, f"UC-2-{suffix}")
    return {
        **world,
        "unit1": str(unit1),
        "unit1_no": f"UC-1-{suffix}",
        "unit2": str(unit2),
        "residents": residents,
    }


def _file(client, slug, resident, target_unit_id, **over):
    body = {"target_unit_id": target_unit_id, "kategori": "gurultu"}
    body.update(over)
    return client.post(
        "/unit-complaints",
        headers=_headers(client, slug, resident),
        json=body,
    )


def _density_for(client, headers, unit_id):
    d = client.get("/unit-complaints/density", headers=headers).json()["items"]
    return next((it for it in d if it["target_unit_id"] == unit_id), None)


# ------------------------------- kayit + anonimlik -------------------------- #
def test_sakin_acar_ve_complainant_donmez(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    r = _file(client, slug, r0, ucworld["unit1"], notlar="Gece gurultu")
    assert r.status_code == 201, r.text
    body = r.json()
    # complainant HICBIR sekilde donmez
    assert "complainant_user_id" not in body
    assert r0["id"] not in str(body)
    assert body["target_unit_id"] == ucworld["unit1"]
    assert body["kategori"] == "gurultu" and body["durum"] == "acik"


def test_complainant_hicbir_uctan_sizmaz(ucworld, client):
    """density + liste + (tum roller) — complainant_user_id ASLA gorunmez."""
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"], notlar="X").status_code == 201
    cid = r0["id"]

    for role_cred in (
        ucworld["admin_a"],
        ucworld["yonetici_a"],
        ucworld["guard_a"],
        ucworld["gorevli_a"],
        r0,
    ):
        h = _headers(client, slug, role_cred)
        dens = client.get("/unit-complaints/density", headers=h)
        assert dens.status_code == 200
        assert "complainant_user_id" not in dens.text and cid not in dens.text
        lst = client.get(
            "/unit-complaints", headers=h, params={"target_unit_id": ucworld["unit1"]}
        )
        assert lst.status_code == 200
        assert "complainant_user_id" not in lst.text and cid not in lst.text


# --------------------------------- spam ------------------------------------- #
def test_spam_korumasi_ayni_sakin_ayni_daire_409(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"]).status_code == 201
    # ayni sakin ayni daireye tekrar -> 409
    dup = _file(client, slug, r0, ucworld["unit1"])
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"
    # BASKA daireye acabilir
    assert _file(client, slug, r0, ucworld["unit2"]).status_code == 201
    # BASKA sakin ayni daireye acabilir
    assert _file(client, slug, ucworld["residents"][1], ucworld["unit1"]).status_code == 201


def test_kapatinca_yeniden_acilabilir(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"]).status_code == 201
    # yonetim kapatir (sikayet edeni gormeden)
    yon = _headers(client, slug, ucworld["yonetici_a"])
    lst = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": ucworld["unit1"]}
    ).json()["items"]
    cid = lst[0]["id"]
    pc = client.patch(f"/unit-complaints/{cid}", headers=yon, json={"durum": "kapali"})
    assert pc.status_code == 200 and pc.json()["durum"] == "kapali"
    assert "complainant_user_id" not in pc.text
    # kapali oldugundan ayni sakin yeniden acabilir
    assert _file(client, slug, r0, ucworld["unit1"]).status_code == 201


# ------------------------------ renk esikleri ------------------------------- #
def test_renk_esikleri_ve_kapatma_feedback(ucworld, client):
    slug = ucworld["slug_a"]
    admin = _headers(client, slug, ucworld["admin_a"])
    unit = ucworld["unit1"]
    res = ucworld["residents"]

    # 0 -> yesil
    assert _density_for(client, admin, unit)["renk"] == "yesil"
    # 2 -> yesil (sinir)
    for i in range(2):
        assert _file(client, slug, res[i], unit).status_code == 201
    d = _density_for(client, admin, unit)
    assert d["acik_sayisi"] == 2 and d["renk"] == "yesil"
    # 3 -> sari
    assert _file(client, slug, res[2], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "sari"
    # 4 -> sari (sinir)
    assert _file(client, slug, res[3], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "sari"
    # 5 -> kirmizi
    assert _file(client, slug, res[4], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "kirmizi"

    # kapatma ACIK sayimi dusurur -> renk feedback (5->4 -> sari)
    yon = _headers(client, slug, ucworld["yonetici_a"])
    cid = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": unit}
    ).json()["items"][0]["id"]
    assert client.patch(
        f"/unit-complaints/{cid}", headers=yon, json={"durum": "kapali"}
    ).status_code == 200
    d2 = _density_for(client, admin, unit)
    assert d2["acik_sayisi"] == 4 and d2["renk"] == "sari"


# -------------------------------- RBAC -------------------------------------- #
def test_rbac(ucworld, client):
    slug = ucworld["slug_a"]
    # ACMA yalniz sakin
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"], ucworld["guard_a"], ucworld["gorevli_a"]):
        h = _headers(client, slug, cred)
        assert client.post(
            "/unit-complaints", headers=h,
            json={"target_unit_id": ucworld["unit1"], "kategori": "diger"},
        ).status_code == 403

    # density + liste tum rollerde 200
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"], ucworld["guard_a"],
                 ucworld["gorevli_a"], ucworld["residents"][0]):
        h = _headers(client, slug, cred)
        assert client.get("/unit-complaints/density", headers=h).status_code == 200
        assert client.get("/unit-complaints", headers=h).status_code == 200

    # kapatma yalniz yonetim
    r0 = ucworld["residents"][0]
    _file(client, slug, r0, ucworld["unit1"])
    yon = _headers(client, slug, ucworld["yonetici_a"])
    cid = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": ucworld["unit1"]}
    ).json()["items"][0]["id"]
    for cred in (ucworld["guard_a"], ucworld["gorevli_a"], r0):
        h = _headers(client, slug, cred)
        assert client.patch(
            f"/unit-complaints/{cid}", headers=h, json={"durum": "kapali"}
        ).status_code == 403


# --------------------------- not gizliligi ---------------------------------- #
def test_not_yalniz_yonetime_gorunur(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"], notlar="Gizli not").status_code == 201

    # yonetim: not DOLU
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"]):
        h = _headers(client, slug, cred)
        item = client.get(
            "/unit-complaints", headers=h, params={"target_unit_id": ucworld["unit1"]}
        ).json()["items"][0]
        assert item["notlar"] == "Gizli not"

    # digerleri (security/gorevli/resident): not NULL
    for cred in (ucworld["guard_a"], ucworld["gorevli_a"], ucworld["residents"][1]):
        h = _headers(client, slug, cred)
        item = client.get(
            "/unit-complaints", headers=h, params={"target_unit_id": ucworld["unit1"]}
        ).json()["items"][0]
        assert item["notlar"] is None
        assert "Gizli not" not in client.get(
            "/unit-complaints", headers=h, params={"target_unit_id": ucworld["unit1"]}
        ).text


# --------------------------- tenant izolasyonu ------------------------------ #
def test_tenant_izolasyonu(ucworld, client):
    slug = ucworld["slug_a"]
    assert _file(client, slug, ucworld["residents"][0], ucworld["unit1"]).status_code == 201

    # B admini A'nin sikayetini/dairesini goremez (RLS): density'de A dairesi yok
    admin_b = _headers(client, ucworld["slug_b"], ucworld["admin_b"])
    dens_b = client.get("/unit-complaints/density", headers=admin_b).json()["items"]
    assert all(it["target_unit_id"] != ucworld["unit1"] for it in dens_b)
    lst_b = client.get(
        "/unit-complaints", headers=admin_b, params={"target_unit_id": ucworld["unit1"]}
    ).json()["items"]
    assert lst_b == []


# ------------------- yonetim modulunden AYRI oldugu ------------------------- #
def test_yonetim_complaint_modulunden_ayri(ucworld, client):
    """/unit-complaints ile /complaints AYRI uclardir (karismaz)."""
    slug = ucworld["slug_a"]
    _file(client, slug, ucworld["residents"][0], ucworld["unit1"])
    # /complaints (yonetim modulu) daire-sikayeti dondurmez; /unit-complaints doner.
    yon = _headers(client, slug, ucworld["yonetici_a"])
    uc = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": ucworld["unit1"]}
    ).json()
    assert uc["meta"]["total"] >= 1
