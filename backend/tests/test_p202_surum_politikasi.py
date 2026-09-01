"""(P202) ZORUNLU GUNCELLEME — uc davranisi.

Olculen sey su dort kural:
  1. Karari SUNUCU verir; politika yeni surum yayinlamadan degisir,
  2. Kontrol ucu PUBLIC (giristen ONCE calisir),
  3. Esik BOS ya da GECERSIZ ise KIMSE KILITLENMEZ,
  4. Panel uclari YALNIZ platform adminine acik.
"""
from __future__ import annotations

import pytest


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def politika(client, world, owner_conn):
    """Android politikasini kurar, test sonunda GERI ALIR.

    Tablo tenant-disidir: birakilan bir esik SONRAKI testleri etkiler.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE surum_politikasi SET asgari_surum='1.1.0', "
            "onerilen_surum='1.2.0', "
            """mesaj='{"tr":"Guvenlik guncellemesi","en":"Security update"}'::jsonb """
            "WHERE platform='android'"
        )
    yield
    with owner_conn.cursor() as cur:
        cur.execute(
            "UPDATE surum_politikasi SET asgari_surum=NULL, onerilen_surum=NULL, "
            "mesaj='{}'::jsonb WHERE platform='android'"
        )


def _kontrol(client, surum, platform="android", **kw):
    return client.post(
        "/surum/kontrol", json={"platform": platform, "surum": surum}, **kw
    )


# ============================ 1) KARAR ==================================== #

def test_ESKI_SURUM_ZORUNLU_doner(client, politika):
    r = _kontrol(client, "1.0.9")
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["durum"] == "zorunlu"
    assert d["magaza_url"], "guncelle dugmesi adressiz cizilemez"
    assert "play.google.com" in d["magaza_url"]
    assert d["mesaj"] == "Guvenlik guncellemesi"


def test_ARADAKI_SURUM_ONERILEN_doner(client, politika):
    assert _kontrol(client, "1.1.5").json()["durum"] == "onerilen"


def test_GUNCEL_SURUM_hicbir_sey_gostermez(client, politika):
    d = _kontrol(client, "1.2.0").json()
    assert d["durum"] == "guncel"
    # Guncel istemciye mesaj/adres GONDERILMEZ: yanlislikla ekran
    # cizmesine zemin hazirlamayalim.
    assert d["mesaj"] is None
    assert d["magaza_url"] is None


def test_SEMANTIK_KARSILASTIRMA_metin_karsilastirmasi_DEGIL(client, politika):
    """1.10.0 > 1.2.0. Metin karsilastirmasi bunu TERS yapar ('1' < '2')
    ve zorunlu guncelleme tam ihtiyac aninda calismazdi."""
    assert _kontrol(client, "1.10.0").json()["durum"] == "guncel"


def test_YAPIM_NUMARASI_karari_DEGISTIRMEZ(client, politika):
    """pubspec "1.1.1+6" gonderir; magazada gorunen surum "1.1.1"dir."""
    assert _kontrol(client, "1.1.1+6").json()["durum"] == "onerilen"


# ====================== 2) KIMSE KILITLENMEZ ============================== #

def test_POLITIKA_YOKKEN_kimse_kilitlenmez(client):
    """Goc uygulanir uygulanmaz kimse disari atilmamali: iki esik de
    BOS dogar ve bos = o seviye KAPALI."""
    assert _kontrol(client, "0.0.1", platform="ios").json()["durum"] == "guncel"


def test_GECERSIZ_SURUM_bildiren_istemci_KILITLENMEZ(client, politika):
    """Bozuk bir surum metni kullaniciyi disari atmamali."""
    assert _kontrol(client, "bozuk").json()["durum"] == "guncel"


def test_BILINMEYEN_PLATFORM_HATA_DEGIL(client, politika):
    """Hata dondurmek, istemcinin hata dalina duserek hicbir sey
    yapmamasina yol acardi — ayni sonuc, ama gurultulu."""
    r = _kontrol(client, "1.0.0", platform="web")
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "guncel"


# ============================ 3) PUBLIC =================================== #

def test_KONTROL_UCU_KIMLIK_ISTEMEZ(client, politika):
    """Giristen ONCE calisir: kirici bir API degisikliginde eski istemci
    giris bile yapamayabilir."""
    r = _kontrol(client, "1.0.0")
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "zorunlu"


def test_MESAJ_DILE_GORE_secilir(client, politika):
    d = _kontrol(client, "1.0.0", headers={"Accept-Language": "en-US,en;q=0.9"})
    assert d.json()["mesaj"] == "Security update"
    # Cevrilmemis dil TR'ye duser (metin hic gosterilmemesindense).
    d = _kontrol(client, "1.0.0", headers={"Accept-Language": "de"})
    assert d.json()["mesaj"] == "Guvenlik guncellemesi"


# ========================= 4) PANEL YONETIMI ============================== #

def test_PANEL_UCLARI_YALNIZ_ADMIN(client, world):
    yon = _giris(client, world["slug_a"], world["yonetici_a"])
    assert client.get("/surum-politikasi", headers=yon).status_code == 403
    assert client.put(
        "/surum-politikasi/android", headers=yon, json={"asgari_surum": "1.0.0"}
    ).status_code == 403


def test_ADMIN_POLITIKAYI_DEGISTIRIR_ve_KARAR_ANINDA_DEGISIR(client, world):
    """Ozelligin asil vaadi: KOD DEGISMEDEN politika degisir."""
    adm = _giris(client, world["slug_a"], world["admin_a"])
    try:
        assert _kontrol(client, "1.0.0").json()["durum"] == "guncel"
        r = client.put(
            "/surum-politikasi/android",
            headers=adm,
            json={"asgari_surum": "1.5.0", "mesaj": {"tr": "Yeni"}},
        )
        assert r.status_code == 200, r.text
        # Yeniden dagitim YOK, yeni surum YOK — karar DEGISTI.
        d = _kontrol(client, "1.0.0").json()
        assert d["durum"] == "zorunlu"
        assert d["mesaj"] == "Yeni"
    finally:
        client.put(
            "/surum-politikasi/android",
            headers=adm,
            json={"asgari_surum": None, "onerilen_surum": None, "mesaj": {}},
        )


def test_GECERSIZ_SURUM_BICIMI_PANELDE_REDDEDILIR(client, world):
    """Sessizce kabul edip "gecersiz esik = yok say"a birakmak,
    operatore "kaydedildi" deyip politikayi HIC calistirmamak olurdu."""
    adm = _giris(client, world["slug_a"], world["admin_a"])
    r = client.put(
        "/surum-politikasi/android", headers=adm, json={"asgari_surum": "surum-3"}
    )
    assert r.status_code == 422, r.text


def test_BOSALTMA_SERBEST(client, world):
    """Bos = o seviye kapali; operator politikayi geri alabilmeli."""
    adm = _giris(client, world["slug_a"], world["admin_a"])
    r = client.put(
        "/surum-politikasi/android", headers=adm, json={"asgari_surum": ""}
    )
    assert r.status_code == 200, r.text
    assert r.json()["asgari_surum"] is None


def test_DESTEKLENMEYEN_DIL_REDDEDILIR(client, world):
    adm = _giris(client, world["slug_a"], world["admin_a"])
    r = client.put(
        "/surum-politikasi/android", headers=adm, json={"mesaj": {"zz": "x"}}
    )
    assert r.status_code == 422, r.text


def test_GECERSIZ_PLATFORM_REDDEDILIR(client, world):
    adm = _giris(client, world["slug_a"], world["admin_a"])
    r = client.put(
        "/surum-politikasi/windows", headers=adm, json={"asgari_surum": "1.0.0"}
    )
    assert r.status_code == 422, r.text
