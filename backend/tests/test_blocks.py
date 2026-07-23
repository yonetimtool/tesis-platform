"""Bina blok CRUD (D-viz Rev-1) — yonetici/admin yonetir; digerleri 403.

Canli-site kurallari:
  * Daire olusturma bloga baglidir (bloksuz POST /units -> 422).
  * Yeniden-adlandirma YERINDE (ayni id) + blogun daireleri (unit.blok) yeni ada
    tasinir; cift ad -> 422.
  * Silme: blogun daireleri varsa cascade=false -> 409 (onay gerekli);
    cascade=true -> daireler + bagli kayitlar (DB ON DELETE CASCADE) silinir.
Tenant izolasyonu RLS ile (capraz-tenant 404).
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


@pytest.fixture
def bworld(client, world):
    return world


# ------------------------------- RBAC --------------------------------------- #
def test_blok_crud_yonetici_ve_admin(bworld, client):
    slug = bworld["slug_a"]
    for role in ("admin_a", "yonetici_a"):
        h = _headers(client, slug, bworld[role])
        ad = f"{role[0].upper()}{uuid.uuid4().hex[:3]}"
        r = client.post("/blocks", headers=h, json={"ad": ad, "kat_sayisi": 5})
        assert r.status_code == 201, r.text
        assert r.json()["ad"] == ad and r.json()["kat_sayisi"] == 5
        assert r.json()["unit_sayisi"] == 0
        bid = r.json()["id"]
        # okuma (liste)
        items = client.get("/blocks", headers=h).json()["items"]
        assert any(b["id"] == bid for b in items)
        # guncelle
        up = client.patch(f"/blocks/{bid}", headers=h, json={"kat_sayisi": 8})
        assert up.status_code == 200 and up.json()["kat_sayisi"] == 8
        # sil
        assert client.delete(f"/blocks/{bid}", headers=h).status_code == 204


def test_blok_yazma_digerleri_403(bworld, client):
    """Blok YAZMA yalniz admin+yonetici; digerleri 403."""
    slug = bworld["slug_a"]
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, slug, bworld[role])
        assert client.post("/blocks", headers=h, json={"ad": "Z1"}).status_code == 403


def test_blok_okuma_saha_salt_okuma(bworld, client):
    """OKUMA: security + tesis_gorevlisi "Bina Duzenleme"yi SALT-OKUMA gorur
    (GET 200); resident editore erisemez (403)."""
    slug = bworld["slug_a"]
    for role in ("guard_a", "gorevli_a"):
        h = _headers(client, slug, bworld[role])
        assert client.get("/blocks", headers=h).status_code == 200, role
    assert client.get(
        "/blocks", headers=_headers(client, slug, bworld["resident_a"])
    ).status_code == 403


def test_blok_dup_ad_409(bworld, client):
    slug = bworld["slug_a"]
    admin = _headers(client, slug, bworld["admin_a"])
    ad = f"D{uuid.uuid4().hex[:3]}"
    assert client.post("/blocks", headers=admin, json={"ad": ad}).status_code == 201
    dup = client.post("/blocks", headers=admin, json={"ad": ad})
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"


def test_blok_dogrulama_422(bworld, client):
    slug = bworld["slug_a"]
    admin = _headers(client, slug, bworld["admin_a"])
    for bad in ({}, {"ad": ""}, {"ad": "A-1"}, {"ad": "cok-uzun-blok"}, {"ad": "A", "kat_sayisi": -1}):
        assert client.post("/blocks", headers=admin, json=bad).status_code == 422, bad


def test_blok_silme_kullanilan_409(bworld, client):
    """Blogu kullanan daire varsa silme reddedilir (409)."""
    slug = bworld["slug_a"]
    admin = _headers(client, slug, bworld["admin_a"])
    ad = f"U{uuid.uuid4().hex[:3]}"
    bid = client.post("/blocks", headers=admin, json={"ad": ad}).json()["id"]
    # ayni etiketli daire olustur
    u = client.post("/units", headers=admin, json={"no": f"{ad}-1", "blok": ad})
    assert u.status_code == 201
    d = client.delete(f"/blocks/{bid}", headers=admin)
    assert d.status_code == 409 and d.json()["error"]["code"] == "conflict"
    # unit_sayisi listede gorunur
    item = next(b for b in client.get("/blocks", headers=admin).json()["items"] if b["id"] == bid)
    assert item["unit_sayisi"] == 1


def test_blok_tenant_izolasyonu(bworld, client):
    slug_a, slug_b = bworld["slug_a"], bworld["slug_b"]
    admin_a = _headers(client, slug_a, bworld["admin_a"])
    ad = f"T{uuid.uuid4().hex[:3]}"
    bid = client.post("/blocks", headers=admin_a, json={"ad": ad}).json()["id"]
    admin_b = _headers(client, slug_b, bworld["admin_b"])
    assert all(b["id"] != bid for b in client.get("/blocks", headers=admin_b).json()["items"])
    # B admini A'nin blogunu guncelleyemez (RLS -> 404)
    assert client.patch(f"/blocks/{bid}", headers=admin_b, json={"kat_sayisi": 2}).status_code == 404


# --------------------------- FIX 1: bloksuz daire ---------------------------- #
def test_unit_olusturma_bloksuz_422(bworld, client):
    """Canli-site kurali: her daire bir bloga baglanir. Bloksuz POST -> 422;
    blok verilince 201."""
    slug = bworld["slug_a"]
    admin = _headers(client, slug, bworld["admin_a"])
    no = f"NB-{uuid.uuid4().hex[:5]}"
    assert client.post("/units", headers=admin, json={"no": no}).status_code == 422
    assert client.post("/units", headers=admin, json={"no": no, "blok": "A"}).status_code == 201


# ----------------------- FIX 2: yerinde yeniden-adlandirma ------------------- #
def test_blok_rename_yerinde_ve_daireleri_tasir(bworld, client):
    """PATCH ad AYNI id'yi gunceller (yeni blok OLUSTURMAZ) ve blogun daireleri
    (unit.blok zayif baglanti) yeni ada tasinir."""
    slug = bworld["slug_a"]
    admin = _headers(client, slug, bworld["admin_a"])
    old = f"R{uuid.uuid4().hex[:3]}"
    new = f"R{uuid.uuid4().hex[:3]}"
    bid = client.post("/blocks", headers=admin, json={"ad": old}).json()["id"]
    uid = client.post("/units", headers=admin, json={"no": f"{old}-1", "blok": old}).json()["id"]

    r = client.patch(f"/blocks/{bid}", headers=admin, json={"ad": new})
    assert r.status_code == 200, r.text
    assert r.json()["id"] == bid and r.json()["ad"] == new  # AYNI id, yeni ad
    assert r.json()["unit_sayisi"] == 1  # daire hala bagli (yeni ada tasindi)

    # daire yeni etiketi tasir; eski etiket kaybolur
    assert client.get(f"/units/{uid}", headers=admin).json()["blok"] == new
    labels = {b["ad"] for b in client.get("/blocks", headers=admin).json()["items"]}
    assert new in labels and old not in labels


def test_blok_rename_dup_422(bworld, client):
    """Var olan bir bloga yeniden-adlandirma -> 422 (benzersizlik)."""
    slug = bworld["slug_a"]
    admin = _headers(client, slug, bworld["admin_a"])
    ad1 = f"E{uuid.uuid4().hex[:3]}"
    ad2 = f"F{uuid.uuid4().hex[:3]}"
    client.post("/blocks", headers=admin, json={"ad": ad1})
    bid2 = client.post("/blocks", headers=admin, json={"ad": ad2}).json()["id"]
    dup = client.patch(f"/blocks/{bid2}", headers=admin, json={"ad": ad1})
    assert dup.status_code == 422 and dup.json()["error"]["code"] == "conflict"
    # bid2 hala kendi adiyla durur (degismedi)
    assert client.get("/blocks", headers=admin).json()
    assert any(
        b["id"] == bid2 and b["ad"] == ad2
        for b in client.get("/blocks", headers=admin).json()["items"]
    )


# --------------------- FIX 3: cascade silme (daireli blok) ------------------- #
def test_blok_silme_cascade_daireleri_ve_bagli_kayitlari_siler(bworld, client, owner_conn):
    """cascade=true: blogun daireleri + daireye bagli kayitlar (unit_resident,
    dues_assessment — DB ON DELETE CASCADE) silinir. cascade=false -> 409."""
    slug = bworld["slug_a"]
    tenant_a = bworld["a"]
    admin = _headers(client, slug, bworld["admin_a"])
    ad = f"C{uuid.uuid4().hex[:3]}"
    bid = client.post("/blocks", headers=admin, json={"ad": ad}).json()["id"]
    u1 = client.post("/units", headers=admin, json={"no": f"{ad}-1", "blok": ad}).json()
    u2 = client.post("/units", headers=admin, json={"no": f"{ad}-2", "blok": ad}).json()

    # bagli kayitlar: dues_assessment (u1) + unit_resident (u1 <- resident_a)
    assert client.post(
        "/dues/assessments", headers=admin,
        json={"unit_id": u1["id"], "donem": "2026-07", "tutar_kurus": 50000},
    ).status_code == 201
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s AND role='resident' LIMIT 1",
            (tenant_a,),
        )
        resident_id = cur.fetchone()[0]
    assert client.post(
        f"/units/{u1['id']}/residents", headers=admin, json={"user_id": str(resident_id)}
    ).status_code == 201

    # cascade=false (varsayilan) -> 409 (kaza korumasi)
    assert client.delete(f"/blocks/{bid}", headers=admin).status_code == 409

    # cascade=true -> 204; daireler + bagli kayitlar gider
    assert client.delete(f"/blocks/{bid}?cascade=true", headers=admin).status_code == 204
    assert client.get(f"/units/{u1['id']}", headers=admin).status_code == 404
    assert client.get(f"/units/{u2['id']}", headers=admin).status_code == 404
    assert all(b["id"] != bid for b in client.get("/blocks", headers=admin).json()["items"])
    # DB seviyesi cascade: bagli satirlar 0
    with owner_conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM dues_assessment WHERE unit_id=%s", (u1["id"],))
        assert cur.fetchone()[0] == 0
        cur.execute("SELECT count(*) FROM unit_resident WHERE unit_id=%s", (u1["id"],))
        assert cur.fetchone()[0] == 0


def test_blok_silme_cascade_tenant_izolasyonu_404(bworld, client):
    """B admini A'nin blogunu cascade ile bile silemez (RLS -> 404)."""
    slug_a, slug_b = bworld["slug_a"], bworld["slug_b"]
    admin_a = _headers(client, slug_a, bworld["admin_a"])
    admin_b = _headers(client, slug_b, bworld["admin_b"])
    ad = f"X{uuid.uuid4().hex[:3]}"
    bid = client.post("/blocks", headers=admin_a, json={"ad": ad}).json()["id"]
    assert client.delete(f"/blocks/{bid}?cascade=true", headers=admin_b).status_code == 404
    # A tarafinda blok hala durur
    assert any(b["id"] == bid for b in client.get("/blocks", headers=admin_a).json()["items"])


def test_unit_crud_yonetici_yapabilir(bworld, client):
    """D-viz Rev-1: daire CRUD artik admin+YONETICI. gorevli/security/resident 403."""
    slug = bworld["slug_a"]
    yon = _headers(client, slug, bworld["yonetici_a"])
    no = f"Y-{uuid.uuid4().hex[:5]}"
    r = client.post("/units", headers=yon, json={"no": no, "blok": "A", "kat": 1, "sira": 1})
    assert r.status_code == 201, r.text
    uid = r.json()["id"]
    assert client.get("/units", headers=yon).status_code == 200
    assert client.patch(f"/units/{uid}", headers=yon, json={"sira": 2}).json()["sira"] == 2
    assert client.delete(f"/units/{uid}", headers=yon).status_code == 204
    # saha rolleri + resident YAZAMAZ
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, slug, bworld[role])
        assert client.post("/units", headers=h, json={"no": "X-1", "blok": "A"}).status_code == 403
    # OKUMA: saha rolleri daireleri SALT-OKUMA gorur (read-only editor); resident 403
    for role in ("guard_a", "gorevli_a"):
        h = _headers(client, slug, bworld[role])
        assert client.get("/units", headers=h).status_code == 200, role
    assert client.get(
        "/units", headers=_headers(client, slug, bworld["resident_a"])
    ).status_code == 403
