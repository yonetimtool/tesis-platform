"""Bina blok CRUD (D-viz Rev-1) — yonetici/admin yonetir; digerleri 403.

Silme guvenligi: blogu kullanan daire varsa 409. Tenant izolasyonu RLS ile.
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
        assert client.post("/units", headers=h, json={"no": "X-1"}).status_code == 403
    # OKUMA: saha rolleri daireleri SALT-OKUMA gorur (read-only editor); resident 403
    for role in ("guard_a", "gorevli_a"):
        h = _headers(client, slug, bworld[role])
        assert client.get("/units", headers=h).status_code == 200, role
    assert client.get(
        "/units", headers=_headers(client, slug, bworld["resident_a"])
    ).status_code == 403
