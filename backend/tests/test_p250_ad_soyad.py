"""(P250 §1) KULLANICI ADI: AD + SOYAD, Turkce harf kuraliyla.

Olculen:
  1. Bicim kurali (saf fonksiyon) — kullanicinin verdigi ornekler AYNEN.
  2. Her yazma yolu (kullanici ekleme/duzenleme, profil, sakin ekleme/
     duzenleme, Excel ice aktarim) ayni kurali uyguluyor ve soyadi ayri
     sakliyor.
  3. Eski istemci (soyadsiz `ad`) kirilmiyor; mevcut kayitlara dokunulmuyor.
"""
from __future__ import annotations

import uuid

import pytest

from app.kisi_adi import ad_bicimle, ayir, soyad_bicimle, tam_ad, tr_buyuk, tr_kucuk


# ------------------------------------------------------------------ #
# 1. KURAL
# ------------------------------------------------------------------ #
@pytest.mark.parametrize(
    "girdi,beklenen",
    [
        ("mehmet ali", "Mehmet Ali"),
        ("ışıl", "Işıl"),
        ("ilker", "İlker"),
        ("çiğdem", "Çiğdem"),
        ("İLKER", "İlker"),
        ("IŞIL", "Işıl"),
        ("  ayşe   nur  ", "Ayşe Nur"),
        ("ayşe-nur", "Ayşe-Nur"),
        ("ÖMER FARUK", "Ömer Faruk"),
        ("şükrü", "Şükrü"),
    ],
)
def test_ad_bicimi(girdi, beklenen):
    assert ad_bicimle(girdi) == beklenen


@pytest.mark.parametrize(
    "girdi,beklenen",
    [
        ("yılmaz", "YILMAZ"),
        ("öztürk", "ÖZTÜRK"),
        ("işçi", "İŞÇİ"),
        ("çiftçi", "ÇİFTÇİ"),
        ("  kara   kaya ", "KARA KAYA"),
    ],
)
def test_soyad_bicimi(girdi, beklenen):
    assert soyad_bicimle(girdi) == beklenen


def test_varsayilan_donusum_YANLIS_turkce_dogru():
    """Kilidin sebebi: varsayilan upper/lower Turkce'de yanlis sonuc verir."""
    assert "ilker".upper() == "ILKER"  # yanlis (noktasiz I)
    assert tr_buyuk("ilker") == "İLKER"
    assert len("İ".lower()) == 2  # birlesik nokta
    assert tr_kucuk("İ") == "i"
    assert tr_kucuk("I") == "ı"


def test_tam_ad_ve_ayir():
    assert tam_ad("Mehmet Ali", "YILMAZ") == "Mehmet Ali YILMAZ"
    assert tam_ad("Mehmet", None) == "Mehmet"
    assert ayir("Mehmet Ali YILMAZ", "YILMAZ") == ("Mehmet Ali", "YILMAZ")
    # P250 oncesi kayit: son kelime soyad ONERISI (yalniz form on-dolumu).
    assert ayir("Ali Veli", None) == ("Ali", "Veli")
    assert ayir("Tekad", None) == ("Tekad", None)


# ------------------------------------------------------------------ #
# 2. YAZMA YOLLARI (canli API)
# ------------------------------------------------------------------ #
def _h(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _mail() -> str:
    return f"p250-{uuid.uuid4().hex[:12]}@ornek.com"


def _satir(owner_conn, user_id):
    with owner_conn.cursor() as cur:
        cur.execute("SELECT ad, soyad FROM app_user WHERE id=%s", (user_id,))
        return cur.fetchone()


def test_kullanici_ekleme_bicimler_ve_soyadi_ayri_saklar(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/users", headers=h, json={
        "ad": "mehmet ali", "soyad": "yılmaz", "email": _mail(), "role": "security",
    })
    assert r.status_code == 201, r.text
    assert r.json()["ad"] == "Mehmet Ali YILMAZ"
    assert r.json()["soyad"] == "YILMAZ"
    assert _satir(owner_conn, r.json()["id"]) == ("Mehmet Ali YILMAZ", "YILMAZ")


def test_kullanici_duzenleme_yalniz_soyad_ve_eski_istemci(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    uid = client.post("/users", headers=h, json={
        "ad": "ışıl", "soyad": "öztürk", "email": _mail(), "role": "security",
    }).json()["id"]
    assert _satir(owner_conn, uid) == ("Işıl ÖZTÜRK", "ÖZTÜRK")
    # Yalniz soyad: ilk ad korunur.
    r = client.patch(f"/users/{uid}", headers=h, json={"soyad": "kaya"})
    assert r.status_code == 200, r.text
    assert _satir(owner_conn, uid) == ("Işıl KAYA", "KAYA")
    # Eski istemci: soyadsiz tam ad -> kelime basi bicim, soyad bosalir.
    r = client.patch(f"/users/{uid}", headers=h, json={"ad": "ışıl kaya"})
    assert r.status_code == 200, r.text
    assert _satir(owner_conn, uid) == ("Işıl Kaya", None)
    # Ayrintida soyad ayri gelir (duzenleme formu on-dolumu).
    d = client.get(f"/users/{uid}", headers=h).json()
    assert d["ad"] == "Işıl Kaya" and d["soyad"] is None


def test_bos_ad_reddedilir(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/users", headers=h, json={
        "ad": "   ", "soyad": "x", "email": _mail(), "role": "security",
    })
    assert r.status_code == 422, r.text


def test_profil_duzenleme(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["guard_a"])
    r = client.patch("/me/contact", headers=h, json={"ad": "çiğdem", "soyad": "işçi"})
    assert r.status_code == 200, r.text
    assert r.json()["ad"] == "Çiğdem İŞÇİ"
    assert r.json()["soyad"] == "İŞÇİ"


def test_sakin_ekleme_ve_duzenleme(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    no = f"P250-{uuid.uuid4().hex[:5]}"
    r = client.post("/residents", headers=h, json={
        "ad": "ilker", "soyad": "yılmaz", "email": _mail(), "blok": "A", "unit_no": no,
        "telefon": f"+9053{uuid.uuid4().int % 100000000:08d}",
    })
    assert r.status_code == 201, r.text
    uid = r.json()["user_id"]
    assert _satir(owner_conn, uid) == ("İlker YILMAZ", "YILMAZ")
    r = client.patch(f"/residents/{uid}", headers=h, json={"ad": "ilker can", "soyad": "yılmaz"})
    assert r.status_code == 204, r.text
    assert _satir(owner_conn, uid) == ("İlker Can YILMAZ", "YILMAZ")
    liste = client.get("/residents", headers=h, params={"q": "ilker can"}).json()["items"]
    satir = next(i for i in liste if i["user_id"] == uid)
    assert satir["soyad"] == "YILMAZ"


def test_ice_aktarim_soyad_zorunlu_ve_bicimli(client, world, owner_conn):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    eposta = _mail()

    def aktar(degerler, dogrula):
        r = client.post("/ice-aktarim/kisi", headers=h, json={
            "satirlar": [{"satir_no": 2, "degerler": degerler}],
            "yalniz_dogrula": dogrula,
        })
        assert r.status_code == 201, r.text
        return r.json()

    sonuc = aktar({"ad": "ali", "eposta": eposta}, True)
    assert any(x["alan"] == "soyad" for x in sonuc["hatalar"]), sonuc
    aktar({"ad": "ali osman", "soyad": "çelik", "eposta": eposta}, False)
    with owner_conn.cursor() as cur:
        cur.execute("SELECT ad, soyad FROM app_user WHERE email=%s", (eposta,))
        assert cur.fetchone() == ("Ali Osman ÇELİK", "ÇELİK")


def test_mevcut_kayitlara_dokunulmaz(world, owner_conn):
    """Goc geri doldurma YAPMAZ: fixture kullanicilarinin soyadi NULL kalir."""
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT ad, soyad FROM app_user WHERE tenant_id=%s AND ad='Admin A'",
            (world["a"],),
        )
        assert cur.fetchone() == ("Admin A", None)
