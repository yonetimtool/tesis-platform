"""Hava durumu — tenant konum ayarlari + GET /weather (0005 / WP-C)."""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_settings_konum_alanlari_doner_ve_yonetici_gunceller(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/tenant/settings", headers=yonetici)
    assert r.status_code == 200
    body = r.json()
    assert body["konum_ad"] == "İstanbul"
    assert abs(body["konum_lat"] - 41.0082) < 1e-4

    r = client.patch(
        "/tenant/settings", headers=yonetici,
        json={"konum_ad": "Ankara", "konum_lat": 39.9334, "konum_lon": 32.8597},
    )
    assert r.status_code == 200, r.text
    assert r.json()["konum_ad"] == "Ankara"


def test_konum_sinir_disi_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.patch("/tenant/settings", headers=admin, json={"konum_lat": 91.0})
    assert r.status_code == 422
