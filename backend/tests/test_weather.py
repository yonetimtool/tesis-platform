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


DURUMLAR = {"acik", "parcali", "kapali", "sis", "yagmur", "kar", "firtina"}


def test_kod_durum_eslemesi():
    from app.weather import kod_durum

    assert kod_durum(0) == "acik"
    assert kod_durum(2) == "parcali"
    assert kod_durum(3) == "kapali"
    assert kod_durum(45) == "sis"
    assert kod_durum(61) == "yagmur"
    assert kod_durum(80) == "yagmur"
    assert kod_durum(71) == "kar"
    assert kod_durum(95) == "firtina"
    assert kod_durum(9999) == "kapali"  # bilinmeyen kod guvenli varsayilan


def test_weather_tum_roller_okur_anonim_401(client, world):
    # Dis servis (Open-Meteo) testte erisilemeyebilir: 200 (veri) da 503
    # (weather_unavailable) da SOZLESMEYE uygundur; 403 ASLA.
    for who in ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[who])
        r = client.get("/weather", headers=h)
        assert r.status_code in (200, 503), f"{who}: {r.status_code} {r.text}"
        if r.status_code == 200:
            body = r.json()
            assert set(body) >= {"sicaklik_c", "durum", "konum_ad"}
            assert body["durum"] in DURUMLAR
    assert client.get("/weather").status_code == 401
