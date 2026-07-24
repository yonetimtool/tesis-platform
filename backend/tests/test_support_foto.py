"""Destek talebi gorselleri (WP-G) — yonetici talep fotosu + admin cevap fotosu."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _upload_foto(client, headers) -> str:
    import httpx

    r = client.post(
        "/uploads/presign", headers=headers,
        json={"content_type": "image/jpeg", "dosya_adi": "destek.jpg"},
    )
    assert r.status_code == 200, r.text
    t = r.json()
    put = httpx.put(t["upload_url"], content=b"fake-jpeg",
                    headers={"Content-Type": "image/jpeg"}, timeout=10)
    assert put.status_code in (200, 204), put.text
    return t["foto_key"]


def test_yonetici_fotolu_talep_acar_ve_gorur(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    key = _upload_foto(client, yonetici)
    r = client.post("/support", headers=yonetici,
                    json={"konu": "Ekran hatasi", "aciklama": "Görsel ekte",
                          "foto_key": key})
    assert r.status_code == 201, r.text
    assert r.json()["foto_url"]

    r = client.get("/support", headers=yonetici)
    item = next(i for i in r.json()["items"] if i["foto_key"] == key)
    assert item["foto_url"]


def test_yabanci_onek_422(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/support", headers=yonetici,
                    json={"konu": "X", "aciklama": "Y",
                          "foto_key": f"{uuid.uuid4()}/kacak.jpg"})
    assert r.status_code == 422


def test_admin_fotolu_cevap_yonetici_gorur(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/support", headers=yonetici,
                    json={"konu": "Soru", "aciklama": "Detay"})
    tid = r.json()["id"]

    cevap_key = _upload_foto(client, admin)
    r = client.patch(f"/support/{tid}", headers=admin,
                     json={"durum": "cozuldu", "admin_cevap": "Ekte",
                           "admin_cevap_foto_key": cevap_key})
    assert r.status_code == 200, r.text
    assert r.json()["admin_cevap_foto_url"]

    r = client.get("/support", headers=yonetici)
    item = next(i for i in r.json()["items"] if i["id"] == tid)
    assert item["admin_cevap_foto_url"]

    # admin /all listesi de fotolari tasir
    r = client.get("/support/all", headers=admin)
    item = next(i for i in r.json()["items"] if i["id"] == tid)
    assert item["admin_cevap_foto_url"]
