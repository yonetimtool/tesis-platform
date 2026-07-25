"""Ihlal kaydi (G2) — kayit, durum gecisleri, RBAC ve RLS izolasyonu.

Kural ozeti: YAZMA admin+security; OKUMA admin+yonetici+security; KAPATMA
YALNIZ admin (dort-goz); 'kapatildi' TERMINAL (yeniden acilmaz -> 409); ayni
duruma gecis idempotent.
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


def _mk(client, headers, **over):
    body = {"baslik": f"Ihlal {uuid.uuid4().hex[:6]}"}
    body.update(over)
    r = client.post("/violations", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


# ------------------------------ mutlu yol ---------------------------------- #
def test_security_ihlal_acar(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    obj = _mk(
        client, h, aciklama="Yangin yolunda park",
        kaynak="kamera", konum="Otopark Girişi - Kamera 3",
    )
    assert obj["durum"] == "yeni"          # varsayilan
    assert obj["kaynak"] == "kamera"
    assert obj["konum"] == "Otopark Girişi - Kamera 3"
    assert obj["olusturan_ad"] == "Guard A"


def test_kaynak_varsayilani_manuel(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    assert _mk(client, h)["kaynak"] == "manuel"


def test_gecersiz_kaynak_422(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.post(
        "/violations", headers=h, json={"baslik": "X", "kaynak": "uydurma"}
    )
    assert r.status_code == 422


def test_durum_yeni_sayaci(client, world):
    """Ana ekran karti: ?durum=yeni&limit=1 -> meta.total."""
    h = _headers(client, world["slug_a"], world["guard_a"])
    once = client.get("/violations?durum=yeni&limit=1", headers=h).json()["meta"]["total"]
    _mk(client, h)
    sonra = client.get("/violations?durum=yeni&limit=1", headers=h).json()["meta"]["total"]
    assert sonra == once + 1


def test_detay_ve_404(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    obj = _mk(client, h)
    assert client.get(f"/violations/{obj['id']}", headers=h).json()["id"] == obj["id"]
    assert client.get(f"/violations/{uuid.uuid4()}", headers=h).status_code == 404


# --------------------------- durum gecisleri -------------------------------- #
def test_security_incelemeye_alir_ama_kapatamaz(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    obj = _mk(client, h)

    r = client.patch(f"/violations/{obj['id']}", headers=h, json={"durum": "inceleniyor"})
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "inceleniyor"

    # Kapatma dort-goz kurali: security kapatamaz.
    r = client.patch(f"/violations/{obj['id']}", headers=h, json={"durum": "kapatildi"})
    assert r.status_code == 403, r.text


def test_admin_kapatir_ve_terminal(client, world):
    hg = _headers(client, world["slug_a"], world["guard_a"])
    ha = _headers(client, world["slug_a"], world["admin_a"])
    obj = _mk(client, hg)

    r = client.patch(f"/violations/{obj['id']}", headers=ha, json={"durum": "kapatildi"})
    assert r.status_code == 200 and r.json()["durum"] == "kapatildi"

    # TERMINAL: kapali kayit yeniden acilmaz (denetim izi korunur).
    r = client.patch(f"/violations/{obj['id']}", headers=ha, json={"durum": "yeni"})
    assert r.status_code == 409, r.text


def test_ayni_duruma_gecis_idempotent(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    obj = _mk(client, h)
    r = client.patch(f"/violations/{obj['id']}", headers=h, json={"durum": "yeni"})
    assert r.status_code == 200 and r.json()["durum"] == "yeni"


# --------------------------------- RBAC ------------------------------------ #
def test_yonetici_okur_ama_yazamaz(client, world):
    hg = _headers(client, world["slug_a"], world["guard_a"])
    obj = _mk(client, hg)
    hy = _headers(client, world["slug_a"], world["yonetici_a"])

    assert client.get("/violations", headers=hy).status_code == 200
    assert client.post("/violations", headers=hy, json={"baslik": "X"}).status_code == 403
    r = client.patch(f"/violations/{obj['id']}", headers=hy, json={"durum": "inceleniyor"})
    assert r.status_code == 403


@pytest.mark.parametrize("who", ["resident_a", "gorevli_a"])
def test_resident_ve_gorevli_403(client, world, who):
    h = _headers(client, world["slug_a"], world[who])
    assert client.get("/violations", headers=h).status_code == 403
    assert client.post("/violations", headers=h, json={"baslik": "X"}).status_code == 403


def test_anonim_401(client):
    assert client.get("/violations").status_code == 401


# ------------------------------ izolasyon ---------------------------------- #
def test_tenant_izolasyonu(client, world):
    ha = _headers(client, world["slug_a"], world["guard_a"])
    obj = _mk(client, ha)

    hb = _headers(client, world["slug_b"], world["admin_b"])
    assert client.get(f"/violations/{obj['id']}", headers=hb).status_code == 404
    ids = {i["id"] for i in client.get("/violations?limit=200", headers=hb).json()["items"]}
    assert obj["id"] not in ids
