"""Kamera MVP (WP-F) — CRUD RBAC + URL semasi + tenant izolasyonu."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_yonetici_crud_security_okur(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    ad = f"Ana Giriş {uuid.uuid4().hex[:6]}"
    r = client.post("/cameras", headers=yonetici,
                    json={"ad": ad, "stream_url": "https://nvr.example.com/s1.m3u8"})
    assert r.status_code == 201, r.text
    cid = r.json()["id"]

    r = client.get("/cameras", headers=guard)  # security OKUR
    assert r.status_code == 200
    assert any(i["id"] == cid for i in r.json()["items"])

    r = client.patch(f"/cameras/{cid}", headers=yonetici, json={"ad": ad + "-2"})
    assert r.status_code == 200 and r.json()["ad"] == ad + "-2"

    assert client.delete(f"/cameras/{cid}", headers=yonetici).status_code == 204


def test_rbac_gorevli_resident_403_guard_yazamaz(client, world):
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    for h in (gorevli, resident):  # KVKK: kamera listesi bile kapali
        assert client.get("/cameras", headers=h).status_code == 403
    r = client.post("/cameras", headers=guard,
                    json={"ad": "X", "stream_url": "https://x/y.m3u8"})
    assert r.status_code == 403


def test_gecersiz_url_422(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/cameras", headers=yonetici,
                    json={"ad": "K", "stream_url": "rtsp://nvr/kanal1"})
    assert r.status_code == 422  # yalniz http(s) — istemci oynaticisi sinirli


def test_tenant_izolasyonu(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    r = client.post("/cameras", headers=yonetici_a,
                    json={"ad": f"A-{uuid.uuid4().hex[:6]}",
                          "stream_url": "https://a/s.m3u8"})
    cid = r.json()["id"]
    assert client.get("/cameras", headers=yonetici_b).json()["items"] == [] or all(
        i["id"] != cid for i in client.get("/cameras", headers=yonetici_b).json()["items"]
    )
    assert client.delete(f"/cameras/{cid}", headers=yonetici_b).status_code == 404
