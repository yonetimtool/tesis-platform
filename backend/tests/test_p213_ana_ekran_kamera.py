"""(P213 §4) ANA EKRAN KAMERA BANDI — secim, sinir ve gorunurluk.

===========================================================================
KARARLAR
===========================================================================
1. AYRI BAYRAK (`ana_ekranda`), `sakin_gorebilir` DEGIL. Ikisi FARKLI
   sorular: biri YETKI ("sakin bu kamerayi gorebilir mi"), oteki YERLESIM
   ("bu kamera ozetin bandinda dursun mu"). Tek bayrakla yonetmek,
   otopark kamerasini sakinlere acan yoneticinin ozetini de kendiliginden
   doldururdu.

2. VARSAYILAN `false`, "hicbiri secilmemisse HICBIRI gosterilmez".
   Varsayilan `true` olsaydi 20 kamerali bir sitede ozet acilir acilmaz
   20 ffmpeg sureci baslardi. "Ilk N kamerayi otomatik goster" gibi bir
   kural da UYDURMA olurdu: hangi kameranin one cikacagi yoneticinin
   bilgisi, alfabetik siranin degil.

3. SINIR VAR (`KAMERA_ANA_EKRAN_SINIR`, varsayilan 4) ve sebebi ffmpeg
   yuku. Sema kisiti DEGIL ayar: siniri degistirmek goc gerektirmemeli.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _kam(client, h, **ek):
    govde = {
        "ad": f"P213 {uuid.uuid4().hex[:6]}", "tur": "hls",
        "stream_url": f"http://192.0.2.{uuid.uuid4().int % 250 + 1}:8888/x/index.m3u8",
        "aktif": True, "sakin_gorebilir": False,
    }
    govde.update(ek)
    r = client.post("/cameras", headers=h, json=govde)
    return r


@pytest.fixture
def temiz(client, world):
    """Ana ekran bandini bosaltir (sinir testleri birbirini bozmasin)."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    acilanlar: list[str] = []

    def kaydet(kid):
        acilanlar.append(kid)
        return kid

    onceki = client.get("/cameras", headers=h,
                        params={"ana_ekranda": True, "limit": 200}).json()
    for it in onceki["items"]:
        client.patch(f"/cameras/{it['id']}", headers=h, json={"ana_ekranda": False})
    yield h, kaydet
    for kid in acilanlar:
        client.delete(f"/cameras/{kid}", headers=h)


# ==================== 1) BAYRAK VE VARSAYILAN =========================== #

def test_VARSAYILAN_kapali(client, temiz):
    h, kaydet = temiz
    r = _kam(client, h)
    assert r.status_code == 201, r.text
    kaydet(r.json()["id"])
    assert r.json()["ana_ekranda"] is False


def test_HICBIRI_SECILMEMISSE_liste_BOS(client, temiz):
    """"Varsayilan bir kural" UYDURULMADI: secim yoksa bant cizilmez."""
    h, kaydet = temiz
    kaydet(_kam(client, h).json()["id"])
    lst = client.get("/cameras", headers=h, params={"ana_ekranda": True}).json()
    assert lst["meta"]["total"] == 0


def test_SECILEN_kamera_listede(client, temiz):
    h, kaydet = temiz
    kid = kaydet(_kam(client, h, ana_ekranda=True).json()["id"])
    lst = client.get("/cameras", headers=h, params={"ana_ekranda": True}).json()
    assert [i["id"] for i in lst["items"]] == [kid]


def test_SAKIN_GOREBILIR_ile_KARISMAZ(client, temiz):
    """Sakine acmak, ana ekrana koymak DEGILDIR."""
    h, kaydet = temiz
    kaydet(_kam(client, h, sakin_gorebilir=True).json()["id"])
    lst = client.get("/cameras", headers=h, params={"ana_ekranda": True}).json()
    assert lst["meta"]["total"] == 0


# ==================== 2) SINIR ========================================== #

def test_SINIR_asilinca_ANLASILIR_422(client, temiz):
    from app.config import settings

    h, kaydet = temiz
    for _ in range(settings.kamera_ana_ekran_sinir):
        r = _kam(client, h, ana_ekranda=True)
        assert r.status_code == 201, r.text
        kaydet(r.json()["id"])
    r = _kam(client, h, ana_ekranda=True)
    assert r.status_code == 422, r.text
    # Mesaj SINIRI SOYLER: "neden ekleyemiyorum" sorusu yanitli.
    assert str(settings.kamera_ana_ekran_sinir) in r.json()["error"]["message"]


def test_SINIR_PATCH_yolunda_da_gecerli(client, temiz):
    from app.config import settings

    h, kaydet = temiz
    for _ in range(settings.kamera_ana_ekran_sinir):
        kaydet(_kam(client, h, ana_ekranda=True).json()["id"])
    kid = kaydet(_kam(client, h).json()["id"])
    r = client.patch(f"/cameras/{kid}", headers=h, json={"ana_ekranda": True})
    assert r.status_code == 422, r.text


def test_ZATEN_ACIK_kamerayi_guncellemek_SINIRA_TAKILMAZ(client, temiz):
    """Sinirdaki bir kameranin ADINI degistirmek engellenmemeli."""
    from app.config import settings

    h, kaydet = temiz
    ids = [kaydet(_kam(client, h, ana_ekranda=True).json()["id"])
           for _ in range(settings.kamera_ana_ekran_sinir)]
    r = client.patch(f"/cameras/{ids[0]}", headers=h,
                     json={"ad": "Yeni Ad", "ana_ekranda": True})
    assert r.status_code == 200, r.text


def test_KALDIRINCA_yer_acilir(client, temiz):
    from app.config import settings

    h, kaydet = temiz
    ids = [kaydet(_kam(client, h, ana_ekranda=True).json()["id"])
           for _ in range(settings.kamera_ana_ekran_sinir)]
    client.patch(f"/cameras/{ids[0]}", headers=h, json={"ana_ekranda": False})
    r = _kam(client, h, ana_ekranda=True)
    assert r.status_code == 201, r.text
    kaydet(r.json()["id"])


# ==================== 3) ROL GORUNURLUGU USTE BINER ===================== #

def test_SAKININ_ana_ekraninda_yalniz_KENDINE_ACIK_kameralar(client, temiz, world):
    """Suzgec rol kapisinin YERINE GECMEZ, USTUNE BINER."""
    h, kaydet = temiz
    gizli = kaydet(_kam(client, h, ana_ekranda=True,
                        sakin_gorebilir=False).json()["id"])
    acik = kaydet(_kam(client, h, ana_ekranda=True,
                       sakin_gorebilir=True).json()["id"])
    sakin = _h(client, world["slug_a"], world["resident_a"])
    lst = client.get("/cameras", headers=sakin, params={"ana_ekranda": True}).json()
    kimlikler = {i["id"] for i in lst["items"]}
    assert acik in kimlikler
    assert gizli not in kimlikler
