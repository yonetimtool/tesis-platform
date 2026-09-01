"""(P193 §4) TESIS POSTA ADRESI — yonetici yazar, makbuz/rapor gosterir.

Rehberi yazarken bulunan eksik 1: sistemde tesisin posta adresi hicbir
yerde tutulmuyordu. Makbuz yalnizca site ADINI yaziyordu; oysa elden
verilen ya da bir anlasmazlikta gosterilen bir makbuz, hangi tesise ait
oldugunu adresiyle de belirtmelidir.
"""
from __future__ import annotations

from app.makbuz import adres_satiri


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ==================== 1) YONETICI ADRESI YAZABILIR ==================== #

def test_YONETICI_adres_yazar_ve_GERI_OKUR(client, world):
    """Adres SITE YONETIMININ isidir: adresi bilen kisi yoneticidir.

    Platform operatorune birakmak, her tabela degisikligini bir destek
    talebine cevirirdi.
    """
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    govde = {
        "adres": "Örnek Mah. 1. Sk. No:5",
        "ilce": "Kadıköy",
        "il": "İstanbul",
        "posta_kodu": "34710",
    }
    r = client.patch("/tenant/settings", headers=h, json=govde)
    assert r.status_code == 200, r.text
    for alan, deger in govde.items():
        assert r.json()[alan] == deger, f"{alan} yanitta DONMEDI"

    # AYRI ISTEKTE de duruyor mu (gercekten yazildi mi).
    r = client.get("/tenant/settings", headers=h)
    assert r.status_code == 200
    assert r.json()["adres"] == govde["adres"]


def test_POSTA_KODU_BES_HANE_DEGILSE_REDDEDILIR(client, world):
    """Sinir semada ve DB CHECK'inde AYNI. Iki yerde iki farkli kural,
    API'den gecen bir degerin veritabaninda reddedilmesi demekti."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", headers=h, json={"posta_kodu": "34 71"})
    assert r.status_code == 422, r.text


def test_BOS_ADRES_NONE_OLUR(client, world):
    """`" "` TRUTHY'dir: temizlenmemis bir bosluk "adres var" sayilir ve
    makbuzda bos bir satir birakirdi."""
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", headers=h, json={"adres": "   "})
    assert r.status_code == 200, r.text
    assert r.json()["adres"] is None


# ==================== 2) MAKBUZDA GORUNUR ==================== #

def test_ADRES_SATIRI_BOS_ALANLARI_ATLAR():
    """Yarim girilmis bir adres, sarkan virgul birakmamali."""
    assert adres_satiri("Örnek Mah. No:5", "Kadıköy", "İstanbul", "34710") == (
        "Örnek Mah. No:5, Kadıköy, 34710 İstanbul"
    )
    # Yalniz sokak: virgul YOK.
    assert adres_satiri("Örnek Mah. No:5", None, None, None) == "Örnek Mah. No:5"
    # Posta kodu yoksa il tek basina yazilir.
    assert adres_satiri("A Sk.", "B", "C", None) == "A Sk., B, C"
    # Hicbiri yoksa BOS DIZGE — cagiran "adres yok" diye anlar.
    assert adres_satiri(None, None, None, None) == ""


def test_MAKBUZ_PDF_ADRESLI_URETILIR():
    """PDF gercekten uretiliyor mu (adres satiri cizimi dusurmuyor mu)."""
    from datetime import date

    from app.makbuz import makbuz_pdf

    pdf = makbuz_pdf(
        site_ad="Acme Plaza",
        site_adres="Örnek Mah. No:5, Kadıköy, 34710 İstanbul",
        belge_no="A-1",
        tarih=date(2026, 9, 1),
        odeyen_ad="Ali Veli",
        daire_no="A-1",
        tutar_kurus=75000,
        aciklama="Ağustos aidatı",
        kalemler=[("2026-08", 75000)],
    )
    assert pdf.startswith(b"%PDF")
    # ADRESSIZ de uretilmeli: adres opsiyoneldir.
    pdf2 = makbuz_pdf(
        site_ad="Acme Plaza", belge_no="A-2", tarih=date(2026, 9, 1),
        odeyen_ad="Ali Veli", daire_no=None, tutar_kurus=1,
        aciklama=None, kalemler=[],
    )
    assert pdf2.startswith(b"%PDF")
    # Adresli belge, adressizden UZUNDUR: satir gercekten cizildi.
    assert len(pdf) > len(pdf2)


# ==================== 3) SIHIRBAZDA SORULUR ==================== #

def test_KURULUM_SIHIRBAZINDA_ADRES_ADIMI_VAR(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/kurulum", headers=h)
    assert r.status_code == 200, r.text
    adimlar = {a["kod"]: a for a in r.json()["adimlar"]}
    assert "adres" in adimlar, "adres adimi sihirbazda YOK"
    # ZORUNLU DEGIL: adressiz bir tesis de calisir, yalnizca ciktilari
    # eksik gorunur.
    assert adimlar["adres"]["zorunlu"] is False

    client.patch("/tenant/settings", headers=h, json={"adres": "Örnek Mah. No:5"})
    r = client.get("/kurulum", headers=h)
    assert {a["kod"]: a for a in r.json()["adimlar"]}["adres"]["tamam"] is True
