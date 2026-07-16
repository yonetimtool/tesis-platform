"""Tesis gorunen adi: BIRINCIL yonetici adlandirir; yoneticiler yeniden
adlandirir. `slug` ve tenant `id` ASLA degismez."""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={
            "tenant_slug": slug,
            "email": cred["email"],
            "password": cred["password"],
        },
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _tenant_row(owner_conn, tenant_id):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT ad, slug, yonetim_email FROM tenant WHERE id = %s", (tenant_id,)
        )
        return cur.fetchone()


def test_yonetici_adi_degistirir_slug_degismez(client, world, owner_conn):
    onceki_ad, onceki_slug, _ = _tenant_row(owner_conn, world["a"])

    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", json={"ad": "Yeni Tesis Adi"}, headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["ad"] == "Yeni Tesis Adi"

    ad, slug, _ = _tenant_row(owner_conn, world["a"])
    assert ad == "Yeni Tesis Adi"
    assert slug == onceki_slug, "slug DEGISMEMELI (login akisi bagli)"
    assert ad != onceki_ad

    # Okuma ucu da yeni adi doner (mobil app-bar + panel bunu okur).
    assert client.get("/tenant/settings", headers=h).json()["ad"] == "Yeni Tesis Adi"


def test_yonetici_timezone_degistiremez_403(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", json={"timezone": "UTC"}, headers=h)
    assert r.status_code == 403, r.text


def test_yonetici_yonetim_email_degistiremez_403(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", json={"yonetim_email": "x@x.com"}, headers=h)
    assert r.status_code == 403, r.text


def test_yonetici_ad_ile_birlikte_timezone_gonderemez_403(client, world):
    """Yetki yukseltme yok: izinli alanla birlikte gonderilse bile reddedilir."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch(
        "/tenant/settings", json={"ad": "X Sitesi", "timezone": "UTC"}, headers=h
    )
    assert r.status_code == 403, r.text


def test_admin_hepsini_degistirir(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["admin_a"])
    r = client.patch(
        "/tenant/settings",
        json={"ad": "Admin Adi", "yonetim_email": "yonetim@a.com"},
        headers=h,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["ad"] == "Admin Adi"
    assert body["yonetim_email"] == "yonetim@a.com"

    _, slug, yonetim_email = _tenant_row(owner_conn, world["a"])
    assert yonetim_email == "yonetim@a.com"
    assert slug == world["slug_a"], "admin de slug'i degistiremez"


def test_saha_rolleri_adi_degistiremez_403(client, world):
    for cred in (world["guard_a"], world["gorevli_a"], world["resident_a"]):
        h = _headers(client, world["slug_a"], cred)
        r = client.patch("/tenant/settings", json={"ad": "Olmaz"}, headers=h)
        assert r.status_code == 403, r.text


def test_profil_birincil_alani_doner(client, world, owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET birincil = true WHERE tenant_id = %s AND ad = %s",
            (world["a"], "Yonetici A"),
        )
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/me/profile", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["birincil"] is True

    # Yonetici disi rol: daima false.
    hg = _headers(client, world["slug_a"], world["guard_a"])
    assert client.get("/me/profile", headers=hg).json()["birincil"] is False


def test_birincil_olmayan_yonetici_setup_403(client, world, owner_conn):
    """Kapi mobilde yalniz birincile gosterilir; uc de eslesmeli."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET birincil = false WHERE tenant_id = %s AND ad = %s",
            (world["a"], "Yonetici A"),
        )
        cur.execute(
            "UPDATE tenant SET kurulum_tamamlandi = false WHERE id = %s", (world["a"],)
        )
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/tenant/setup", json={"ad": "Olmaz"}, headers=h)
    assert r.status_code == 403, r.text


def test_birincil_yonetici_setup_eder_sonra_409(client, world, owner_conn):
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE app_user SET birincil = true WHERE tenant_id = %s AND ad = %s",
            (world["a"], "Yonetici A"),
        )
        cur.execute(
            "UPDATE tenant SET kurulum_tamamlandi = false WHERE id = %s", (world["a"],)
        )
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/tenant/setup", json={"ad": "Benim Sitem"}, headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["ad"] == "Benim Sitem"
    assert r.json()["kurulum_tamamlandi"] is True

    # Ikinci kez: 409 (tek seferlik kapi).
    r2 = client.post("/tenant/setup", json={"ad": "Tekrar"}, headers=h)
    assert r2.status_code == 409, r2.text

    # slug yine degismedi.
    with owner_conn.cursor() as cur:
        cur.execute("SELECT slug FROM tenant WHERE id = %s", (world["a"],))
        assert cur.fetchone()[0] == world["slug_a"]
