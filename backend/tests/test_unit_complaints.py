"""Daire sikayeti (D1 + D-viz Rev-1) — kademeli gizlilik + own-block + kategori.

Rev-1 KURALLARI:
  * complainant (sikayet eden) kimligi YALNIZ yonetim (admin+yonetici) icin
    donuyor (denetim); resident/security/gorevli LISTEYE ERISEMEZ (403).
  * density + liste YALNIZ yonetim (residentlar sayilari goremez).
  * resident YALNIZ KENDI blogundaki daireyi sikayet eder (blok disi -> 403).
  * kategori: gurultu / kapi_onu_ayakkabi / zarar_verme / diger.
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


def _mk_unit(owner_conn, tenant_id, no, blok=None):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no, blok) VALUES (%s,%s,%s) RETURNING id",
            (tenant_id, no, blok),
        )
        return cur.fetchone()[0]


def _link(owner_conn, tenant_id, unit_id, user_id):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit_resident (tenant_id, unit_id, user_id) VALUES (%s,%s,%s)",
            (tenant_id, unit_id, user_id),
        )


@pytest.fixture
def ucworld(client, world, owner_conn):
    """world + blok A (unit1, unit2) + blok B (unit_b) + 6 sakin (blok A'ya
    bagli — own-block ile A dairelerini sikayet edebilirler; B disi)."""
    a = world["a"]
    suffix = uuid.uuid4().hex[:6]
    pw = "UcPass1!"
    unit1 = _mk_unit(owner_conn, a, f"UC-1-{suffix}", blok="A")
    unit2 = _mk_unit(owner_conn, a, f"UC-2-{suffix}", blok="A")
    unit_b = _mk_unit(owner_conn, a, f"UC-B-{suffix}", blok="B")
    residents = []
    for i in range(6):
        email = f"uc{i}-{suffix}@acme.com"
        rid = _mk_resident(owner_conn, a, email, pw)
        _link(owner_conn, a, unit1, rid)  # hepsi blok A sakini
        residents.append({"email": email, "password": pw, "id": str(rid)})

    return {
        **world,
        "unit1": str(unit1),
        "unit1_no": f"UC-1-{suffix}",
        "unit2": str(unit2),
        "unit_b": str(unit_b),
        "unit_b_no": f"UC-B-{suffix}",
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


# ------------------------------- kayit -------------------------------------- #
def test_sakin_acar_kendi_kaydini_gorur_complainant_donmez(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    r = _file(client, slug, r0, ucworld["unit1"], notlar="Gece gurultu")
    assert r.status_code == 201, r.text
    body = r.json()
    # resident kendi kaydini gorur ama complainant kimligi DONMEZ (None)
    assert body["complainant_user_id"] is None and body["complainant_ad"] is None
    assert body["target_unit_id"] == ucworld["unit1"]
    assert body["kategori"] == "gurultu" and body["durum"] == "acik"


# ------------------------------ own-block ----------------------------------- #
def test_own_block_ic_201_dis_403(ucworld, client):
    """resident YALNIZ kendi blogundaki (A) daireyi sikayet eder; baska blok
    (B) -> 403. Blok kapsami sunucuda zorlanir."""
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    # blok A daireleri (unit1, unit2) -> 201
    assert _file(client, slug, r0, ucworld["unit1"]).status_code == 201
    assert _file(client, slug, r0, ucworld["unit2"]).status_code == 201
    # blok B (unit_b) -> 403 (own-block disi)
    rb = _file(client, slug, r0, ucworld["unit_b"])
    assert rb.status_code == 403 and rb.json()["error"]["code"] == "forbidden"


def test_bloksuz_sakin_hicbir_yere_acamaz_403(ucworld, client, owner_conn):
    """Aktif dairesi olmayan sakin -> blok kumesi bos -> her hedefe 403."""
    slug = ucworld["slug_a"]
    pw = "UcPass1!"
    email = f"bagsiz-{uuid.uuid4().hex[:6]}@acme.com"
    _mk_resident(owner_conn, ucworld["a"], email, pw)  # daireye BAGLI DEGIL
    r = _file(client, slug, {"email": email, "password": pw}, ucworld["unit1"])
    assert r.status_code == 403


# --------------------------------- spam ------------------------------------- #
def test_spam_korumasi_ayni_sakin_ayni_daire_409(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"]).status_code == 201
    dup = _file(client, slug, r0, ucworld["unit1"])
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"
    # ayni blok BASKA daireye acabilir
    assert _file(client, slug, r0, ucworld["unit2"]).status_code == 201
    # BASKA sakin ayni daireye acabilir
    assert _file(client, slug, ucworld["residents"][1], ucworld["unit1"]).status_code == 201


def test_kapatinca_yeniden_acilabilir(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"]).status_code == 201
    yon = _headers(client, slug, ucworld["yonetici_a"])
    lst = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": ucworld["unit1"]}
    ).json()["items"]
    cid = lst[0]["id"]
    pc = client.patch(f"/unit-complaints/{cid}", headers=yon, json={"durum": "kapali"})
    assert pc.status_code == 200 and pc.json()["durum"] == "kapali"
    # kapali oldugundan ayni sakin yeniden acabilir
    assert _file(client, slug, r0, ucworld["unit1"]).status_code == 201


# ------------------------------ renk esikleri ------------------------------- #
def test_renk_esikleri_ve_kapatma_feedback(ucworld, client):
    slug = ucworld["slug_a"]
    admin = _headers(client, slug, ucworld["admin_a"])
    unit = ucworld["unit1"]
    res = ucworld["residents"]

    assert _density_for(client, admin, unit)["renk"] == "yesil"
    for i in range(2):
        assert _file(client, slug, res[i], unit).status_code == 201
    d = _density_for(client, admin, unit)
    assert d["acik_sayisi"] == 2 and d["renk"] == "yesil"
    assert _file(client, slug, res[2], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "sari"
    assert _file(client, slug, res[3], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "sari"
    assert _file(client, slug, res[4], unit).status_code == 201
    assert _density_for(client, admin, unit)["renk"] == "kirmizi"

    yon = _headers(client, slug, ucworld["yonetici_a"])
    cid = client.get(
        "/unit-complaints", headers=yon, params={"target_unit_id": unit}
    ).json()["items"][0]["id"]
    assert client.patch(
        f"/unit-complaints/{cid}", headers=yon, json={"durum": "kapali"}
    ).status_code == 200
    d2 = _density_for(client, admin, unit)
    assert d2["acik_sayisi"] == 4 and d2["renk"] == "sari"


# ------------------------- kategori (Rev-1 genisleme) ----------------------- #
def test_kategori_yeni_degerler_ve_eski_ret(ucworld, client):
    slug = ucworld["slug_a"]
    res = ucworld["residents"]
    # yeni gecerli degerler
    assert _file(client, slug, res[0], ucworld["unit1"], kategori="kapi_onu_ayakkabi").status_code == 201
    assert _file(client, slug, res[1], ucworld["unit1"], kategori="zarar_verme").status_code == 201
    assert _file(client, slug, res[2], ucworld["unit1"], kategori="diger").status_code == 201
    # eski/gecersiz degerler -> 422
    for bad in ("ayakkabi", "goruntu", "yok"):
        assert _file(
            client, slug, res[3], ucworld["unit1"], kategori=bad
        ).status_code == 422, bad


# -------------------------------- RBAC -------------------------------------- #
def test_rbac_kademeli(ucworld, client):
    slug = ucworld["slug_a"]
    # ACMA yalniz sakin
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"], ucworld["guard_a"], ucworld["gorevli_a"]):
        h = _headers(client, slug, cred)
        assert client.post(
            "/unit-complaints", headers=h,
            json={"target_unit_id": ucworld["unit1"], "kategori": "diger"},
        ).status_code == 403

    # density + liste YALNIZ yonetim (200); digerleri 403 (Rev-1 kademesi)
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"]):
        h = _headers(client, slug, cred)
        assert client.get("/unit-complaints/density", headers=h).status_code == 200
        assert client.get("/unit-complaints", headers=h).status_code == 200
    for cred in (ucworld["guard_a"], ucworld["gorevli_a"], ucworld["residents"][0]):
        h = _headers(client, slug, cred)
        assert client.get("/unit-complaints/density", headers=h).status_code == 403
        assert client.get("/unit-complaints", headers=h).status_code == 403

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


# ------------------ complainant: yonetime gorunur, digerine kapali ---------- #
def test_complainant_yonetime_gorunur_digerine_403(ucworld, client):
    slug = ucworld["slug_a"]
    r0 = ucworld["residents"][0]
    assert _file(client, slug, r0, ucworld["unit1"], notlar="Gizli not").status_code == 201

    # yonetim: complainant kimligi + adi + not DOLU (denetim)
    for cred in (ucworld["admin_a"], ucworld["yonetici_a"]):
        h = _headers(client, slug, cred)
        item = client.get(
            "/unit-complaints", headers=h, params={"target_unit_id": ucworld["unit1"]}
        ).json()["items"][0]
        assert item["complainant_user_id"] == r0["id"]
        assert item["complainant_ad"]  # ad dolu
        assert item["notlar"] == "Gizli not"

    # digerleri LISTEYE ERISEMEZ -> 403 (complainant/not hicbir sekilde sizmaz)
    for cred in (ucworld["guard_a"], ucworld["gorevli_a"], ucworld["residents"][1]):
        h = _headers(client, slug, cred)
        resp = client.get(
            "/unit-complaints", headers=h, params={"target_unit_id": ucworld["unit1"]}
        )
        assert resp.status_code == 403
        assert r0["id"] not in resp.text and "Gizli not" not in resp.text


# --------------------------- tenant izolasyonu ------------------------------ #
def test_tenant_izolasyonu(ucworld, client):
    slug = ucworld["slug_a"]
    assert _file(client, slug, ucworld["residents"][0], ucworld["unit1"]).status_code == 201

    admin_b = _headers(client, ucworld["slug_b"], ucworld["admin_b"])
    dens_b = client.get("/unit-complaints/density", headers=admin_b).json()["items"]
    assert all(it["target_unit_id"] != ucworld["unit1"] for it in dens_b)
    lst_b = client.get(
        "/unit-complaints", headers=admin_b, params={"target_unit_id": ucworld["unit1"]}
    ).json()["items"]
    assert lst_b == []
