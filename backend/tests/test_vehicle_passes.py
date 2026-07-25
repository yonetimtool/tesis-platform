"""Arac gecisi (G1) + otopark dolulugu (G4).

Kapsam: giris/cikis mutlu yol, plaka NORMALIZASYONU, ayni plakadan tek ACIK
gecis (409), cift cikis (409), acik/plaka suzgecleri, RBAC (yonetici/resident/
tesis_gorevlisi 403), doluluk hesabi (kapasite tanimli/tanimsiz) ve RLS tenant
izolasyonu.
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


def _plaka() -> str:
    """Test kosumlari arasinda cakismayan benzersiz plaka (2-20 alfanumerik)."""
    return "TST" + uuid.uuid4().hex[:8].upper()


def _giris(client, headers, plaka=None, **over):
    body = {"plaka": plaka or _plaka()}
    body.update(over)
    r = client.post("/vehicle-passes", headers=headers, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def _mk_unit(owner_conn, tenant_id, no):
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO unit (tenant_id, no) VALUES (%s,%s) RETURNING id",
            (tenant_id, no),
        )
        return cur.fetchone()[0]


def _set_kapasite(owner_conn, tenant_id, kapasite):
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE tenant SET otopark_kapasite = %s WHERE id = %s",
            (kapasite, tenant_id),
        )


# ------------------------------ mutlu yol ---------------------------------- #
def test_guard_giris_ve_cikis(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    obj = _giris(client, h, arac_tanim="BMW Siyah")
    assert obj["cikis_zamani"] is None  # acik gecis => arac iceride
    assert obj["kaydeden_ad"] == "Guard A"

    r = client.post(f"/vehicle-passes/{obj['id']}/checkout", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["cikis_zamani"] is not None


def test_plaka_normalize_edilir(client, world):
    """Bosluk/tire atilir, harfler buyur — saklanan ve donen deger kanonik."""
    h = _headers(client, world["slug_a"], world["guard_a"])
    ham = _plaka()
    obj = _giris(client, h, plaka=f"{ham[:2]} {ham[2:5]}-{ham[5:].lower()}")
    assert obj["plaka"] == ham


def test_ayni_plakadan_ikinci_acik_gecis_409(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    plaka = _plaka()
    _giris(client, h, plaka=plaka)
    # Farkli yazimla bile ayni arac (normalize) -> 409.
    r = client.post("/vehicle-passes", headers=h, json={"plaka": f" {plaka.lower()} "})
    assert r.status_code == 409, r.text


def test_cikistan_sonra_ayni_plaka_yeniden_girebilir(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    plaka = _plaka()
    ilk = _giris(client, h, plaka=plaka)
    assert client.post(f"/vehicle-passes/{ilk['id']}/checkout", headers=h).status_code == 200
    ikinci = _giris(client, h, plaka=plaka)  # kismi unique indeks engellemez
    assert ikinci["id"] != ilk["id"]


def test_cift_cikis_409(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    obj = _giris(client, h)
    assert client.post(f"/vehicle-passes/{obj['id']}/checkout", headers=h).status_code == 200
    r = client.post(f"/vehicle-passes/{obj['id']}/checkout", headers=h)
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "conflict"


def test_olmayan_kayda_cikis_404(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.post(f"/vehicle-passes/{uuid.uuid4()}/checkout", headers=h)
    assert r.status_code == 404


def test_gecersiz_plaka_422(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.post("/vehicle-passes", headers=h, json={"plaka": "-- --"})
    assert r.status_code == 422, r.text


def test_daire_referansi(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["guard_a"])
    no = f"VP-{uuid.uuid4().hex[:6]}"
    _mk_unit(owner_conn, world["a"], no)
    obj = _giris(client, h, unit_no=no)
    assert obj["unit_no"] == no
    # Olmayan daire -> 422 (sessizce ziyaretci araci yapilmaz).
    r = client.post(
        "/vehicle-passes", headers=h, json={"plaka": _plaka(), "unit_no": "YOK-999"}
    )
    assert r.status_code == 422, r.text


# ------------------------------- suzgecler --------------------------------- #
def test_acik_ve_plaka_suzgecleri(client, world):
    h = _headers(client, world["slug_a"], world["guard_a"])
    acik = _giris(client, h)
    kapali = _giris(client, h)
    client.post(f"/vehicle-passes/{kapali['id']}/checkout", headers=h)

    ids = lambda r: {i["id"] for i in r.json()["items"]}  # noqa: E731
    r = client.get("/vehicle-passes?acik=true&limit=200", headers=h)
    assert acik["id"] in ids(r) and kapali["id"] not in ids(r)
    r = client.get("/vehicle-passes?acik=false&limit=200", headers=h)
    assert kapali["id"] in ids(r) and acik["id"] not in ids(r)

    # Plaka aramasi da NORMALIZE: bosluklu/kucuk harfli arama eslesir.
    p = acik["plaka"]
    r = client.get(f"/vehicle-passes?plaka={p[:3].lower()} {p[3:5]}", headers=h)
    assert acik["id"] in ids(r)


def test_tarih_suzgeci(client, world):
    """"Bugun N giris" sayaci: giris_zamani araligi (/visitors deseni)."""
    from datetime import datetime, timedelta, timezone

    h = _headers(client, world["slug_a"], world["guard_a"])
    simdi = datetime.now(tz=timezone.utc)
    eski = _giris(client, h, giris_zamani=(simdi - timedelta(days=3)).isoformat())
    yeni = _giris(client, h)

    # NOT: tarih degeri params= ile gecirilir — isoformat() "+00:00" uretir ve
    # duz URL icinde '+' BOSLUK olarak cozulur (422). Istemciler de kodlamali.
    sinir = (simdi - timedelta(days=1)).isoformat()

    def _ids(**params):
        r = client.get(
            "/vehicle-passes", headers=h, params={"limit": 200, **params}
        )
        assert r.status_code == 200, r.text
        return {i["id"] for i in r.json()["items"]}

    ids = _ids(baslangic=sinir)
    assert yeni["id"] in ids and eski["id"] not in ids

    ids = _ids(bitis=sinir)
    assert eski["id"] in ids and yeni["id"] not in ids


def test_gelecege_damga_422(client, world):
    from datetime import datetime, timedelta, timezone

    h = _headers(client, world["slug_a"], world["guard_a"])
    ileri = (datetime.now(tz=timezone.utc) + timedelta(hours=2)).isoformat()
    r = client.post(
        "/vehicle-passes", headers=h, json={"plaka": _plaka(), "giris_zamani": ileri}
    )
    assert r.status_code == 422, r.text


# --------------------------------- RBAC ------------------------------------ #
@pytest.mark.parametrize("who", ["yonetici_a", "resident_a", "gorevli_a"])
def test_okuma_ve_yazma_yalniz_admin_security(client, world, who):
    h = _headers(client, world["slug_a"], world[who])
    assert client.get("/vehicle-passes", headers=h).status_code == 403
    r = client.post("/vehicle-passes", headers=h, json={"plaka": _plaka()})
    assert r.status_code == 403


def test_admin_okur_ve_yazar(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])
    obj = _giris(client, h)
    assert client.get("/vehicle-passes", headers=h).status_code == 200
    assert client.get(f"/vehicle-passes/{obj['id']}", headers=h).status_code == 200


def test_anonim_401(client):
    assert client.get("/vehicle-passes").status_code == 401


# ---------------------------- doluluk (G4) --------------------------------- #
def test_doluluk_acik_gecisleri_sayar(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["guard_a"])
    _set_kapasite(owner_conn, world["a"], 10)

    once = client.get("/parking/occupancy", headers=h).json()
    assert once["kapasite"] == 10

    obj = _giris(client, h)
    sonra = client.get("/parking/occupancy", headers=h).json()
    assert sonra["dolu"] == once["dolu"] + 1
    assert sonra["oran"] == round(100 * sonra["dolu"] / 10)

    # Cikis dolulugu geri dusurur (ayri sayac yok — tek dogruluk kaynagi).
    client.post(f"/vehicle-passes/{obj['id']}/checkout", headers=h)
    assert client.get("/parking/occupancy", headers=h).json()["dolu"] == once["dolu"]


def test_kapasite_tanimsizken_oran_null(client, world, owner_conn):
    h = _headers(client, world["slug_a"], world["guard_a"])
    _set_kapasite(owner_conn, world["a"], None)
    body = client.get("/parking/occupancy", headers=h).json()
    assert body["kapasite"] is None and body["oran"] is None
    assert isinstance(body["dolu"], int)  # dolu HER ZAMAN gercek sayi


def test_doluluk_tum_rollere_acik(client, world):
    """Agregat: plaka/daire icermez -> ana ekran karti her rolde calisir."""
    for who in ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[who])
        assert client.get("/parking/occupancy", headers=h).status_code == 200, who


def test_kapasite_yonetici_ayarindan_gelir(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", headers=h, json={"otopark_kapasite": 42})
    assert r.status_code == 200, r.text
    assert r.json()["otopark_kapasite"] == 42
    assert client.get("/parking/occupancy", headers=h).json()["kapasite"] == 42
    # Acikca null -> tanimsiz'a doner.
    r = client.patch("/tenant/settings", headers=h, json={"otopark_kapasite": None})
    assert r.json()["otopark_kapasite"] is None


# ------------------------------ izolasyon ---------------------------------- #
def test_tenant_izolasyonu(client, world):
    """B tenant'in admini A'nin gecisini GOREMEZ (RLS)."""
    ha = _headers(client, world["slug_a"], world["guard_a"])
    obj = _giris(client, ha)

    hb = _headers(client, world["slug_b"], world["admin_b"])
    assert client.get(f"/vehicle-passes/{obj['id']}", headers=hb).status_code == 404
    ids = {i["id"] for i in client.get("/vehicle-passes?limit=200", headers=hb).json()["items"]}
    assert obj["id"] not in ids
