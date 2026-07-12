"""Gorev kategorisi CRUD (A6): yonetici ozellestirir (POST/DELETE), saha okur.

RBAC: yazma admin+yonetici; okuma admin/yonetici/security/tesis_gorevlisi
(gorev goren roller); resident 403. Soft-delete: DELETE aktif=false yapar;
pasif kategori gorev olusturmada kullanilamaz. Tenant izolasyonu RLS ile.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _new_category(client, headers, ad=None):
    ad = ad or f"Kategori-{uuid.uuid4().hex[:8]}"
    r = client.post("/task-categories", headers=headers, json={"ad": ad})
    assert r.status_code == 201, r.text
    return r.json()


def test_kategori_crud_ve_soft_delete(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    kat = _new_category(client, yonetici)
    assert kat["aktif"] is True and kat["ad"].startswith("Kategori-")

    # listede gorunur
    ids = {it["id"] for it in client.get("/task-categories", headers=yonetici).json()["items"]}
    assert kat["id"] in ids

    # ayni ad ayni tenant -> 409
    dup = client.post("/task-categories", headers=yonetici, json={"ad": kat["ad"]})
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "conflict"

    # DELETE -> soft-delete (204); varsayilan listede YOK, aktif=false ile gorunur
    assert client.delete(f"/task-categories/{kat['id']}", headers=yonetici).status_code == 204
    aktifler = {
        it["id"] for it in client.get("/task-categories", headers=yonetici).json()["items"]
    }
    assert kat["id"] not in aktifler
    pasifler = {
        it["id"]
        for it in client.get(
            "/task-categories", headers=yonetici, params={"aktif": False}
        ).json()["items"]
    }
    assert kat["id"] in pasifler

    # olmayan kategori DELETE -> 404
    assert (
        client.delete(f"/task-categories/{uuid.uuid4()}", headers=yonetici).status_code == 404
    )


def test_kategori_gorev_olusturmada_secilir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    kat = _new_category(client, yonetici)

    # gorev kategoriyle olusur; yanit kategori_id tasir
    r = client.post(
        "/tasks",
        headers=yonetici,
        json={"tip": "temizlik", "ad": "Kategorili gorev", "kategori_id": kat["id"]},
    )
    assert r.status_code == 201, r.text
    assert r.json()["kategori_id"] == kat["id"]

    # gecersiz kategori -> 422 invalid_reference
    bad = client.post(
        "/tasks",
        headers=yonetici,
        json={"tip": "temizlik", "ad": "x", "kategori_id": str(uuid.uuid4())},
    )
    assert bad.status_code == 422 and bad.json()["error"]["code"] == "invalid_reference"

    # pasif kategoriyle gorev olusturulamaz -> 422
    client.delete(f"/task-categories/{kat['id']}", headers=yonetici)
    pasif = client.post(
        "/tasks",
        headers=yonetici,
        json={"tip": "temizlik", "ad": "x", "kategori_id": kat["id"]},
    )
    assert pasif.status_code == 422, pasif.text


def test_kategori_rbac(client, world):
    """Yazma yalniz admin+yonetici (201); saha rolleri okur (200) ama yazamaz
    (403); resident tamamen 403."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])

    kat = _new_category(client, yonetici)
    _new_category(client, admin)

    for h in (guard, gorevli):
        assert client.get("/task-categories", headers=h).status_code == 200
        assert (
            client.post("/task-categories", headers=h, json={"ad": "x"}).status_code == 403
        )
        assert (
            client.delete(f"/task-categories/{kat['id']}", headers=h).status_code == 403
        )

    assert client.get("/task-categories", headers=resident).status_code == 403
    assert (
        client.post("/task-categories", headers=resident, json={"ad": "x"}).status_code
        == 403
    )


def test_kategori_tenant_izolasyonu(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    admin_b = _headers(client, world["slug_b"], world["admin_b"])

    kat = _new_category(client, yonetici_a)

    # B tarafi A'nin kategorisini goremez / silemez (RLS -> 404)
    b_ids = {it["id"] for it in client.get("/task-categories", headers=admin_b).json()["items"]}
    assert kat["id"] not in b_ids
    assert (
        client.delete(f"/task-categories/{kat['id']}", headers=admin_b).status_code == 404
    )

    # ayni ad FARKLI tenant'ta serbest (unique tenant-kapsamli)
    r = client.post("/task-categories", headers=admin_b, json={"ad": kat["ad"]})
    assert r.status_code == 201, r.text
