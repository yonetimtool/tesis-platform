"""Duyuru: CRUD + RBAC (gonderme admin/yonetici, okuma TUM roller) + izolasyon."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _new(client, headers, **over):
    body = {"baslik": f"Duyuru {uuid.uuid4().hex[:6]}", "govde": "Icerik."}
    body.update(over)
    r = client.post("/announcements", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# -------------------------------- CRUD ------------------------------------- #
def test_crud_happy_path_yonetici(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])

    a = _new(client, yonetici, baslik="Su kesintisi", govde="Yarin 10:00-12:00.")
    assert a["olusturan_ad"] == "Yonetici A"

    # detay + listede en yeni onde
    assert client.get(f"/announcements/{a['id']}", headers=yonetici).status_code == 200
    b = _new(client, yonetici, baslik="Ikinci duyuru")
    listed = client.get("/announcements", headers=yonetici, params={"limit": 10}).json()
    ids = [it["id"] for it in listed["items"]]
    assert ids.index(b["id"]) < ids.index(a["id"])  # created_at DESC

    # guncelle
    p = client.patch(
        f"/announcements/{a['id']}", headers=yonetici, json={"govde": "Iptal edildi."}
    )
    assert p.status_code == 200 and p.json()["govde"] == "Iptal edildi."

    # sil
    assert client.delete(f"/announcements/{a['id']}", headers=yonetici).status_code == 204
    assert client.get(f"/announcements/{a['id']}", headers=yonetici).status_code == 404
    client.delete(f"/announcements/{b['id']}", headers=yonetici)


def test_admin_da_gonderebilir(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    a = _new(client, admin, baslik="Admin duyurusu")
    assert a["olusturan_ad"] == "Admin A"
    client.delete(f"/announcements/{a['id']}", headers=admin)


def test_validation(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    # bos baslik/govde -> 422
    assert client.post(
        "/announcements", headers=yonetici, json={"baslik": "", "govde": "x"}
    ).status_code == 422
    assert client.post(
        "/announcements", headers=yonetici, json={"baslik": "x", "govde": ""}
    ).status_code == 422
    # PATCH bos govdeyle de 422
    a = _new(client, yonetici)
    assert client.patch(
        f"/announcements/{a['id']}", headers=yonetici, json={"baslik": ""}
    ).status_code == 422
    client.delete(f"/announcements/{a['id']}", headers=yonetici)


# -------------------------------- RBAC ------------------------------------- #
def test_rbac_okuma_tum_roller_yazma_yonetim(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    a = _new(client, yonetici, baslik="Herkese acik")

    for role in ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        r = client.get("/announcements", headers=h)
        assert r.status_code == 200, f"{role}: {r.text}"
        assert any(it["id"] == a["id"] for it in r.json()["items"])
        assert client.get(f"/announcements/{a['id']}", headers=h).status_code == 200

    # saha rolleri + resident YAZAMAZ (403)
    for role in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[role])
        assert client.post(
            "/announcements", headers=h, json={"baslik": "x", "govde": "y"}
        ).status_code == 403, role
        assert client.patch(
            f"/announcements/{a['id']}", headers=h, json={"baslik": "z"}
        ).status_code == 403, role
        assert client.delete(
            f"/announcements/{a['id']}", headers=h
        ).status_code == 403, role

    client.delete(f"/announcements/{a['id']}", headers=yonetici)


# ----------------------------- tenant izolasyonu --------------------------- #
def test_tenant_izolasyonu(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])

    a = _new(client, yonetici_a, baslik="A-ozel duyuru")

    # B tenant'i A'nin duyurusunu goremez/degistiremez/silemez (RLS -> 404)
    b_ids = [it["id"] for it in client.get(
        "/announcements", headers=yonetici_b, params={"limit": 200}
    ).json()["items"]]
    assert a["id"] not in b_ids
    assert client.get(f"/announcements/{a['id']}", headers=yonetici_b).status_code == 404
    assert client.patch(
        f"/announcements/{a['id']}", headers=yonetici_b, json={"baslik": "ele gecti"}
    ).status_code == 404
    assert client.delete(f"/announcements/{a['id']}", headers=yonetici_b).status_code == 404

    client.delete(f"/announcements/{a['id']}", headers=yonetici_a)
