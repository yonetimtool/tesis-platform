"""(P233 §1) TESIS KONUMU — adresten koordinat cozumleme.

===========================================================================
OLCULEN DURUM: ALAN VARDI, DEGER YOKTU
===========================================================================
`tenant.konum_lat/konum_lon/konum_ad` goc 0005'ten beri var ve `/weather`
onlari kullaniyor. Ama dev veritabanindaki TUM tesisler ayni degeri
tasiyor:

    konum_ad='İstanbul'  konum_lat=41.008200  konum_lon=28.978400

Bu sunucu VARSAYILANI — kimse hic ayarlamamis. Sonucu gorunur ve yanlis:
Erzurum'daki "Oltu Sitesi" ISTANBUL havasini gosteriyor.

Alanlar `PATCH /tenant/settings` ile yazilabiliyordu; eksik olan sey,
yoneticinin ENLEM/BOYLAM YAZMADAN konumunu verebilecegi bir yoldu.
"""
from __future__ import annotations

import pytest


def _h(client, world, kim):
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world[kim]["email"], "password": world[kim]["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon(client, world):
    return _h(client, world, "yonetici_a")


# ==================================================================== #
# 1. OLCULEN KUSURUN KAYDI
# ==================================================================== #

def test_VARSAYILAN_KONUM_ISTANBUL_VE_BU_BIR_VARSAYILAN(client, yon):
    """Kusurun KAYDI: yeni tesis, kimse ayarlamadan Istanbul gorunur.

    Test bunu "dogru" ilan etmiyor — varsayilanin VAR oldugunu ve
    degistirilebilir oldugunu sabitliyor. Asagidaki testler degisimi
    olcer.
    """
    r = client.get("/tenant/settings", headers=yon)
    assert r.status_code == 200, r.text
    v = r.json()
    assert v["konum_ad"], v
    assert v["konum_lat"] is not None and v["konum_lon"] is not None


# ==================================================================== #
# 2. ADRESTEN COZUMLEME
# ==================================================================== #

def test_ARAMA_ADAY_LISTESI_DONER(client, yon):
    """ADAY LISTESI, TEK SONUC DEGIL: "Oltu" sorgusu Erzurum'daki ilceyi
    de, Artvin'deki "Oltuca"yi da dondurur. Sunucunun ilkini secip
    "buldum" demesi, yoneticinin HIC GORMEDIGI bir konumu tesise yazmak
    olurdu."""
    r = client.get("/konum/ara?q=Oltu", headers=yon)
    if r.status_code == 503:
        pytest.skip("cografi kodlama servisi erisilemiyor (agsiz ortam)")
    assert r.status_code == 200, r.text
    items = r.json()["items"]
    assert len(items) >= 1, items
    ilk = items[0]
    assert ilk["lat"] and ilk["lon"]
    assert ilk["aciklama"], "ayirt edici aciklama bos"
    # Bos parcalar ELENMIS olmali — "Oltu, , Türkiye" cikmamali.
    assert ", ," not in ilk["aciklama"], ilk["aciklama"]


def test_ARAMA_TEK_HARF_REDDEDILIR(client, yon):
    r = client.get("/konum/ara?q=O", headers=yon)
    assert r.status_code == 422, r.text


def test_ARAMA_YETKI_YONETIMDE(client, world):
    """Tesisin konumunu belirleyen kisi YONETIMDIR."""
    for kim in ("guard_a", "resident_a"):
        h = _h(client, world, kim)
        r = client.get("/konum/ara?q=Ankara", headers=h)
        assert r.status_code == 403, (kim, r.status_code)


# ==================================================================== #
# 3. KONUM YAZILIYOR VE HAVA DURUMU ONU KULLANIYOR
# ==================================================================== #

def test_KONUM_YAZILIR_VE_OKUNUR(client, yon):
    """MEVCUT TESISLER ICIN SONRADAN GIRILEBILIR — ayri bir uc degil,
    zaten var olan ayar ucu."""
    r = client.patch("/tenant/settings", headers=yon, json={
        "konum_ad": "Oltu", "konum_lat": 40.53945, "konum_lon": 41.98722})
    assert r.status_code == 200, r.text
    v = client.get("/tenant/settings", headers=yon).json()
    assert v["konum_ad"] == "Oltu"
    assert abs(v["konum_lat"] - 40.53945) < 1e-4, v
    assert abs(v["konum_lon"] - 41.98722) < 1e-4, v


def test_HAVA_DURUMU_YAZILAN_KONUMU_KULLANIR(client, yon):
    """ZINCIRIN UCUNDAN UCUNA: konum yazilinca hava durumu ONU sorar.

    `konum_ad` yanitta doner ve hava ucu ayni tenant satirindan okur;
    yani "ayar kaydedildi ama hava hala Istanbul" durumu burada duser.
    """
    client.patch("/tenant/settings", headers=yon, json={
        "konum_ad": "Oltu", "konum_lat": 40.53945, "konum_lon": 41.98722})
    r = client.get("/weather", headers=yon)
    if r.status_code == 503:
        pytest.skip("hava servisi erisilemiyor (agsiz ortam)")
    assert r.status_code == 200, r.text
    assert r.json()["konum_ad"] == "Oltu", r.json()


def test_KONUMU_SAHA_ROLU_DEGISTIREMEZ(client, world):
    """KVKK/yetki: tesis konumu sakinlerin YASADIGI YER. Okumasi genis
    (hava durumu herkese gorunur) ama YAZMASI yonetimde."""
    h = _h(client, world, "guard_a")
    r = client.patch("/tenant/settings", headers=h, json={"konum_ad": "X"})
    assert r.status_code == 403, r.text


def test_HAVA_DURUMUNU_HERKES_OKUR(client, world):
    """Hava durumu tesisin genel bilgisidir; sakinden saklamanin anlami
    yok."""
    h = _h(client, world, "resident_a")
    r = client.get("/weather", headers=h)
    assert r.status_code in (200, 503), r.text
