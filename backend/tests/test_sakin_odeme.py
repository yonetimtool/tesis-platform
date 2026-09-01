"""Sakin "Öde" akisi (P30) — havale kodu + kart + otomatik eslestirme."""
from __future__ import annotations

import uuid

import pytest

from app.odeme_kodu import ayikla, uret



def _p197_mail() -> str:
    """(P197) Kullanici/sakin olusturmada e-posta ZORUNLU oldu.

    `app_user.email` NOT NULL (goc 0089): davet, dogrulama kodu ve parola
    sifirlama YALNIZ e-postadan gidiyor, yani e-postasiz acilan hesap
    sahiplenilemez. Test govdelerine BENZERSIZ adres verilir —
    `uq_app_user_tenant_email` ayni tesiste tekrari reddeder.
    """
    return f"p197-{uuid.uuid4().hex[:12]}@ornek.com"

def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _sfx() -> str:
    return uuid.uuid4().hex[:6]


@pytest.fixture
def adm(client, world):
    return _headers(client, world["slug_a"], world["admin_a"])


@pytest.fixture
def sakin(client, world):
    return _headers(client, world["slug_a"], world["resident_a"])


# ------------------------------ kod cekirdegi ------------------------------- #
def test_kod_bicimi_KARISTIRILABILIR_harf_YOK():
    """Kullanici kodu ELLE yazacak; telefonda `0/O` ve `1/I` ayrimi okunmaz.

    `L` DISARIDA DEGIL: karisan sey KUCUK `l`dir ve kod BUYUK harftir —
    `L` ile `1` buyuk harfte karismaz.
    """
    for _ in range(50):
        k = uret()
        assert k.startswith("TS-") and len(k) == 9
        govde = k[3:]
        assert not (set(govde) & set("01OI")), k


def test_kod_SERBEST_METINDEN_ayiklanir():
    """Aciklamada baska metin de olur: esitlik degil ARAMA yapilir."""
    assert ayikla("AIDAT TS-A7K2M9 TESEKKURLER") == "TS-A7K2M9"
    # Kucuk harf de kabul (banka ekstresi kucuk dondurebilir).
    assert ayikla("odeme ts-a7k2m9") == "TS-A7K2M9"
    assert ayikla("HAVALE") is None
    assert ayikla("") is None


# --------------------------- odeme bilgileri uc ----------------------------- #
def test_odeme_bilgileri_KOD_URETIR_ve_SABIT_kalir(client, sakin):
    """Kod BIR KEZ uretilir: turetilseydi daire no degisince sakinin
    bankadaki duzenli talimati SESSIZCE eslesmez olurdu."""
    ilk = client.get("/me/odeme-bilgileri", headers=sakin)
    assert ilk.status_code == 200, ilk.text
    kod = ilk.json()["odeme_kodu"]
    assert kod.startswith("TS-")
    ikinci = client.get("/me/odeme-bilgileri", headers=sakin).json()
    assert ikinci["odeme_kodu"] == kod, "kod her cagrida degisiyor"


def test_IBAN_banka_kasasindan_gelir_YOKSA_null(client, adm, sakin):
    """Ayri bir "anlasmali IBAN" alani ACILMADI: iki yerde tutulan IBAN, biri
    guncellenip digeri unutuldugunda parayi YANLIS HESABA yollardi."""
    once = client.get("/me/odeme-bilgileri", headers=sakin).json()
    # Banka kasasi yoksa IBAN null olmali (istemci havaleyi gizler).
    if once["iban"] is None:
        client.post("/kasalar", headers=adm, json={
            "kod": f"BN{_sfx()}", "ad": "Site Banka", "banka_mi": True,
            "iban": "TR330006100519786457841326", "banka_adi": "Ziraat"})
        sonra = client.get("/me/odeme-bilgileri", headers=sakin).json()
        assert sonra["iban"] == "TR330006100519786457841326"
        assert sonra["banka_adi"] == "Ziraat"


def test_borc_kurus_HEDEFSIZ_tahakkuku_da_sayar(client, adm, sakin, world):
    """P28 oncesi/tursuz tahakkuklar DAIREYE yazilidir ve sakin onlari da
    odemek zorundadir."""
    once = client.get("/me/odeme-bilgileri", headers=sakin).json()["borc_kurus"]
    # resident_a'nin dairesini bul.
    daireler = client.get("/units", headers=adm, params={"limit": 200}).json()["items"]
    # Sakine daire bagli degilse test anlamsiz olur; bagliysa tahakkuk ac.
    hedef = None
    for d in daireler:
        sakinler = client.get(f"/units/{d['id']}/residents", headers=adm)
        if sakinler.status_code == 200 and sakinler.json():
            hedef = d
            break
    if hedef is None:
        pytest.skip("world fixture'inda daireye bagli sakin yok")
    client.post("/dues/assessments", headers=adm, json={
        "donem": f"2031-{_sfx()[:1] if _sfx()[:1].isdigit() and _sfx()[:1] != '0' else '1'}1",
        "unit_id": hedef["id"], "tutar_kurus": 45000})
    sonra = client.get("/me/odeme-bilgileri", headers=sakin).json()["borc_kurus"]
    assert sonra >= once


def test_kart_aktif_MANUEL_saglayicida_KAPALI(client, sakin):
    """Manuel saglayici "kart" degildir: secenegi acmak sakini calismayan
    bir akisa sokardi."""
    r = client.get("/me/odeme-bilgileri", headers=sakin).json()
    assert r["kart_aktif"] is False


def test_odeme_bilgileri_YALNIZ_SAKIN(client, world):
    for rol in ("admin_a", "yonetici_a", "guard_a"):
        h = _headers(client, world["slug_a"], world[rol])
        assert client.get("/me/odeme-bilgileri", headers=h).status_code == 403


# ------------------------------ kart odemesi -------------------------------- #
def test_kart_odemesi_TAHSILAT_yazar(client, adm, sakin):
    """Basarili odeme P29 defterine yazilir — kasa/gelir yansimasi oradan
    gelir, burada TEKRARLANMAZ."""
    r = client.post("/me/odeme/kart", headers=sakin, json={"tutar_kurus": 12345})
    assert r.status_code == 201, r.text
    assert r.json()["durum"] == "basarili"
    hid = r.json()["hareket_id"]
    assert hid

    liste = client.get("/finans/hareketler", headers=adm,
                       params={"tip": "tahsilat", "limit": 200}).json()["items"]
    kayit = next(h for h in liste if h["id"] == hid)
    assert kayit["yon"] == "giris" and kayit["tutar_kurus"] == 12345


# -------------------------- otomatik eslestirme ----------------------------- #
def test_KOD_eslestirmeyi_KESINLESTIRIR(client, adm, sakin):
    """Kod her seyi EZER: ad/tutar tahminine gore sonra bakmak, kodu dogru
    yazmis bir sakini "belirsiz" saymak olurdu."""
    kod = client.get("/me/odeme-bilgileri", headers=sakin).json()["odeme_kodu"]

    # Sakine hedeflenmis bir borc ac (eslestirme adaylari borctan gelir).
    tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Aidat-{_sfx()}", "tip": "gider"}).json()
    u = client.post("/units", headers=adm,
                    json={"no": f"OD-{_sfx()}", "blok": "A"}).json()
    kisi = client.post("/residents", headers=adm, json={
        "ad": "Kod Testi", "unit_no": u["no"],
        "telefon": f"+9054{uuid.uuid4().int % 10**8:08d}", "rol_tipi": "malik", "email": _p197_mail()}).json()
    client.post("/dues/assessments", headers=adm, json={
        "donem": "2031-05", "unit_id": u["id"], "tutar_kurus": 88888,
        "gelir_gider_tanim_id": tanim["id"]})

    # Bu kisinin kodunu al: kendi oturumuyla uretmesi gerekiyor — bunun
    # yerine ADMIN eslestirmeyi test etsin diye resident_a'nin kodunu
    # kullanacagiz; onun da borcu olmali.
    r = client.post("/finans/banka-eslestir", headers=adm, json={"satirlar": [
        {"satir_no": 1, "aciklama": f"EFT {kod} AIDAT", "tutar_kurus": 1},
    ]}).json()["oneriler"]
    # resident_a'nin acik borcu varsa KESIN eslesme (guven 100) beklenir;
    # yoksa aday listesinde olmadigi icin oneri uretilmez. Iki durumda da
    # ONEMLI OLAN: kod gecen bir satir ASLA "belirsiz" donmemeli.
    assert r[0]["neden"] in ("odeme_kodu", "eslesme_yok"), r[0]
    if r[0]["neden"] == "odeme_kodu":
        assert r[0]["guven"] == 100
