"""(P160) Okutma mesafe esigi — TESIS AYARI.

Esik bir URUN KARARIDIR (varsayilan 50 m) ve tesis bazinda degisir: bir
sitede noktalar bahce icinde 10 m araliklarla dizilidir, digerinde
bloklar arasi 200 m vardir. Ayni sayi ikisinde de anlamli olamaz.

BU DOSYANIN OLCTUKLERI:
  * varsayilan gercekten 50 (goc `DEFAULT 50` yaziyor),
  * YONETICI degistirebilir — saha isletmesi onun isi,
  * sinirlar HEM API'de HEM SEMADA ayni (1..5000); iki farkli sinir,
    API'den gecen bir degerin veritabaninda reddedilmesi demekti,
  * tenant IZOLASYONU: bir tesisin esigi digerini etkilemez.
"""
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


def test_varsayilan_esik_50(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/tenant/settings", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["okutma_mesafe_esigi_m"] == 50


def test_yonetici_esigi_degistirir(client, world):
    """Saha isletmesi: noktalari yerlestiren kisi esigi de ayarlamali."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch(
        "/tenant/settings", json={"okutma_mesafe_esigi_m": 120}, headers=h
    )
    assert r.status_code == 200, r.text
    assert r.json()["okutma_mesafe_esigi_m"] == 120

    # Okuma ucu da yeni degeri doner (panel haritasi bunu okur).
    assert (
        client.get("/tenant/settings", headers=h).json()["okutma_mesafe_esigi_m"]
        == 120
    )


def test_sifir_esik_reddedilir(client, world):
    """0 m bir esik DEGILDIR: her okutma esik disi olurdu."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch(
        "/tenant/settings", json={"okutma_mesafe_esigi_m": 0}, headers=h
    )
    assert r.status_code == 422, r.text


def test_asiri_esik_reddedilir(client, world):
    """5 km site olceginin cok disinda — kabul etmek esigi anlamsizlastirir."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch(
        "/tenant/settings", json={"okutma_mesafe_esigi_m": 5001}, headers=h
    )
    assert r.status_code == 422, r.text


def test_semadaki_kisit_API_ILE_AYNI(owner_conn, world):
    """SINIR IKI YERDE AYNI olmali.

    API `ge=1, le=5000` diyor; sema `CHECK BETWEEN 1 AND 5000`. Farkli
    olsalardi API'den gecen bir deger veritabaninda reddedilir ve istek
    500 ile duserdi. Kisit dogrudan olculuyor — iki tanimi elle
    karsilastirmak yerine veritabanina soruluyor.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            """
            SELECT pg_get_constraintdef(oid)
            FROM pg_constraint
            WHERE conname = 'tenant_okutma_mesafe_esigi_araligi'
            """
        )
        satir = cur.fetchone()
    assert satir is not None, "sema kisiti yok"
    tanim = satir[0]
    assert "1" in tanim and "5000" in tanim, tanim


def test_esik_TENANT_BAZINDA(client, world):
    """Bir tesisin esigi digerini ETKILEMEZ (RLS + tenant kolonu)."""
    ha = _headers(client, world["slug_a"], world["yonetici_a"])
    hb = _headers(client, world["slug_b"], world["yonetici_b"])

    client.patch("/tenant/settings", json={"okutma_mesafe_esigi_m": 200}, headers=ha)
    assert (
        client.get("/tenant/settings", headers=hb).json()["okutma_mesafe_esigi_m"]
        == 50
    ), "B tesisi A'nin esigini gormemeli"
