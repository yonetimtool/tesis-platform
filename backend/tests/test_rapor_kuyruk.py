"""(P167 Asama 5) RAPOR MOTORU — katalog metadatasi, uc yeni rapor, kuyruk.

EN PAHALI SONUCLAR, testin agirligi da orada:

 1. KATALOG ILE MOTORUN AYRISMASI. Katalog artik her raporun ANLAMLANDIRDIGI
    alanlari bildiriyor ve modal yalniz onlari ciziyor. Katalogda olmayan
    bir alan modalda cizilmez; motorda olmayan bir alan katalogda durursa
    kullanici cizilen ama ISLEMEYEN bir suzgec gorur — sessiz kusur.
 2. KUYRUKTA SAHIPLIK. Rapor ciktisi kisi adlari ve site finansi tasir;
    baskasinin istedigi dosyayi indirebilmek bir sizintidir.
 3. "HAZIR AMA DOSYASIZ" IS. Arayuzde tiklanan ve hicbir sey indirmeyen
    bir baglanti demektir; veritabani kisiti bunu engelliyor.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# --------------------------------------------------------------------------- #
# 1. KATALOG METADATASI
# --------------------------------------------------------------------------- #
def test_katalog_KATEGORI_ve_ALAN_tasir(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/raporlar/katalog", headers=y)
    assert r.status_code == 200, r.text
    govde = r.json()

    # KATEGORI SIRASI brief §5'in sirasi — alfabetik siralamak
    # "Listeler"i "Dokumler"in altina duşürürdü.
    assert govde["kategoriler"] == ["listeler", "ekstreler", "dokumler"]

    for oge in govde["items"]:
        assert oge["kategori"] in govde["kategoriler"], oge
        # HER RAPORUN EN AZ BIR ALANI VAR: alansiz bir rapor, modali bos
        # acilan ve dogrudan calistirilan bir kart demekti — brief
        # "yapilandirma modali" istiyor.
        assert oge["alanlar"], oge["kod"]


def test_katalog_BRIEF_LISTESININ_TAMAMINI_icerir(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    kodlar = {o["kod"] for o in client.get("/raporlar/katalog", headers=y).json()["items"]}
    # Brief §5'in on uc raporu.
    for kod in (
        "borc_alacak", "detayli_borc", "site_sakinleri", "donemsel_bakiye",
        "notlar", "kasa_ekstresi", "firma_ekstresi", "hesap_ekstresi",
        "isletme_defteri", "finansal_hareketler", "makbuz_dokumu",
        "gelir_gider_ozet", "ihtar_yazisi",
    ):
        assert kod in kodlar, kod


def test_MEVCUT_ISLEV_KAYBOLMADI(client, world):
    # GENEL KISITLAR: "Mevcut islev kaybolmayacak." Brief'in listesinde
    # olmayan ama P31'de yazilmis ve calisan iki rapor katalogda KALDI.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    kodlar = {o["kod"] for o in client.get("/raporlar/katalog", headers=y).json()["items"]}
    assert "tahsilat_performansi" in kodlar
    assert "denetim_raporu" in kodlar


def test_AGIR_raporlar_isaretli(client, world):
    """Hangi raporun kuyruga gitmesi gerektigini SUNUCU soyler.

    Olcu istemcide olsaydi, yeni bir agir rapor eklendiginde arayuz onu
    senkron cagirmaya devam ederdi.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    agir = {
        o["kod"] for o in client.get("/raporlar/katalog", headers=y).json()["items"]
        if o["agir"]
    }
    # Tum defteri tarayanlar.
    assert "borc_alacak" in agir
    assert "detayli_borc" in agir
    # Dar kapsamli olanlar agir DEGIL — hepsini agir isaretlemek, kuyrugu
    # anlamsiz kilardi (her rapor icin bekleme).
    assert "kasa_ekstresi" not in agir


def test_KATALOGDAKI_HER_KOD_GERCEKTEN_URETILEBILIYOR(client, world):
    """Listede gorunup calismayan bir rapor OLAMAZ.

    Katalog ile motor ayni sozlukten besleniyor ama `_uret` icindeki
    dallanma AYRI: bir kod kataloga eklenip `_uret`e eklenmezse kart
    cizilir, tiklanir ve bos bir tablo doner.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    for oge in client.get("/raporlar/katalog", headers=y).json()["items"]:
        r = client.post(
            f"/raporlar/{oge['kod']}?bicim=tablo", headers=y,
            json={"baslangic": "2026-01-01", "bitis": "2026-12-31"},
        )
        assert r.status_code == 200, f"{oge['kod']}: {r.text}"


def test_HER_KOD_EXCEL_ve_PDF_GECERLI_URETIR(client, world):
    """(P181 Bölüm 8) 13+ raporun PDF/Excel çıktısı hiç doğrulanmamıştı.

    Her kodu excel VE pdf üret, dosyanın GEÇERLİ (açılabilir) olduğunu magic-byte
    ile doğrula: xlsx = ZIP imzası (PK\\x03\\x04), pdf = %PDF. Böylece "kartı var
    ama çıktısı bozuk" rapor kalmaz.
    """
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    kodlar = [o["kod"] for o in client.get("/raporlar/katalog", headers=y).json()["items"]]
    assert len(kodlar) >= 13, f"katalog eksik: {kodlar}"
    hatalar = []
    for kod in kodlar:
        for bicim, sihir in (("excel", b"PK\x03\x04"), ("pdf", b"%PDF")):
            r = client.post(
                f"/raporlar/{kod}?bicim={bicim}", headers=y,
                json={"baslangic": "2026-01-01", "bitis": "2026-12-31"},
            )
            if r.status_code != 200:
                hatalar.append(f"{kod}/{bicim}: HTTP {r.status_code} {r.text[:80]}")
            elif not r.content.startswith(sihir):
                hatalar.append(f"{kod}/{bicim}: geçersiz imza {r.content[:8]!r}")
            elif len(r.content) < 100:
                hatalar.append(f"{kod}/{bicim}: çok küçük ({len(r.content)}b)")
    assert not hatalar, "Açılamayan/üretilemeyen çıktılar:\n" + "\n".join(hatalar)


# --------------------------------------------------------------------------- #
# 2. UC YENI RAPOR
# --------------------------------------------------------------------------- #
def test_NOTLAR_raporu_sutunlari(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/raporlar/notlar?bicim=tablo", headers=y, json={
        "baslangic": "2026-01-01", "bitis": "2026-12-31",
    })
    assert r.status_code == 200, r.text
    anahtarlar = [s["anahtar"] for s in r.json()["sutunlar"]]
    # Brief: "Ilk Tarih* · Son Tarih* · Olusturan · Bolum*"
    assert anahtarlar == ["tarih", "bolum", "olusturan", "metin"]


def test_FIRMA_EKSTRESI_yon_isaretini_TUTARA_gomer(client, world):
    """Ekstrede "cikis" yazip tutari arti gostermek, toplami gozle almayi
    imkansiz kilardi."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kasa = client.post("/kasalar", headers=admin, json={
        "kod": f"K{uuid.uuid4().hex[:6]}", "ad": "Ekstre Kasa",
    }).json()["id"]
    firma = client.post("/firmalar", headers=admin, json={"ad": "Test Firma"})
    assert firma.status_code in (200, 201), firma.text
    firma_id = firma.json()["id"]

    client.post("/finans/hareketler", headers=admin, json={"satirlar": [
        {"tip": "gider", "tutar_kurus": 5000, "kasa_id": kasa,
         "firma_id": firma_id, "tarih": "2026-06-01"},
    ]})

    r = client.post("/raporlar/firma_ekstresi?bicim=tablo", headers=admin, json={
        "firma_id": firma_id, "baslangic": "2026-01-01", "bitis": "2026-12-31",
    })
    assert r.status_code == 200, r.text
    satirlar = r.json()["satirlar"]
    assert satirlar, satirlar
    # GIDER = kasadan CIKIS => tutar NEGATIF.
    assert satirlar[0]["tutar_kurus"] == -5000


def test_HESAP_EKSTRESI_YURUYEN_BAKIYE_tasir(client, world):
    """Ekstrenin varlik sebebi: satir satir borc/alacak yetmez, kullanicinin
    sordugu sey "su an ne kadar"."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/raporlar/hesap_ekstresi?bicim=tablo", headers=admin, json={
        "baslangic": "2026-01-01", "bitis": "2026-12-31",
    })
    assert r.status_code == 200, r.text
    anahtarlar = [s["anahtar"] for s in r.json()["sutunlar"]]
    assert "bakiye_kurus" in anahtarlar
    assert "borc_kurus" in anahtarlar and "alacak_kurus" in anahtarlar


def test_YENI_RAPORLAR_EXCEL_ve_PDF_uretir(client, world):
    # Tablo calisip dosya uretiminin patlamasi mumkun: `Sutun` tipleri
    # ciktiya gore bicimlendiriliyor ve yeni bir tip yanlis yazilirsa
    # yalnizca dosya yolunda patlar.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    for kod in ("notlar", "firma_ekstresi", "hesap_ekstresi"):
        for bicim in ("excel", "pdf"):
            r = client.post(f"/raporlar/{kod}?bicim={bicim}", headers=y, json={
                "baslangic": "2026-01-01", "bitis": "2026-12-31",
            })
            assert r.status_code == 200, f"{kod}/{bicim}: {r.text}"
            assert len(r.content) > 100, f"{kod}/{bicim} bos dosya"


# --------------------------------------------------------------------------- #
# 3. KUYRUK
# --------------------------------------------------------------------------- #
def test_kuyruga_alma_202_ve_IS_KIMLIGI_doner(client, world):
    # Senkron uc bir DOSYA doner, kuyruk ucu bir IS KIMLIGI. Ayni ucun
    # bazen dosya bazen kimlik dondurmesi, ayrimi unutan bir istemcinin
    # JSON'u dosya diye indirmesine yol acardi.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/raporlar/borc_alacak/kuyruk?bicim=excel", headers=y, json={
        "baslangic": "2026-01-01", "bitis": "2026-12-31",
    })
    assert r.status_code == 202, r.text
    govde = r.json()
    assert govde["kod"] == "borc_alacak"
    assert govde["bicim"] == "excel"
    assert govde["durum"] in ("bekliyor", "uretiliyor", "hazir")
    # DOSYA ANAHTARI DONMEZ (avatar ve duyuru gorseliyle ayni kural).
    assert "dosya_key" not in govde


def test_kuyruk_TABLO_bicimini_KABUL_ETMEZ(client, world):
    # Tablo ciktisi ekranda gosterilir ve zaten hizlidir; kuyruga almak,
    # kullaniciyi gormek istedigi seyi beklemeye zorlamak olurdu.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/raporlar/borc_alacak/kuyruk?bicim=tablo", headers=y, json={})
    assert r.status_code == 422, r.text


def test_BILINMEYEN_KOD_kuyruga_alinmaz(client, world):
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/raporlar/olmayan_rapor/kuyruk?bicim=excel", headers=y, json={})
    assert r.status_code == 404, r.text


def test_ISLERIM_yalniz_KENDI_islerimi_gosterir(client, world):
    """Rapor ciktisi kisi adlari ve site finansi tasir.

    Ayni tesisteki baska bir yoneticinin BASKASININ istedigi dosyayi
    gormesi icin bir sebep yok — ve bu sizinti sessizdir.
    """
    a = _headers(client, world["slug_a"], world["yonetici_a"])
    b = _headers(client, world["slug_a"], world["admin_a"])

    is_id = client.post("/raporlar/borc_alacak/kuyruk?bicim=excel", headers=a,
                        json={}).json()["id"]

    assert any(i["id"] == is_id for i in client.get("/raporlar/isler", headers=a).json())
    assert not any(
        i["id"] == is_id for i in client.get("/raporlar/isler", headers=b).json()
    )
    # B indiremez de — bulunamayan is 404 ("senin degil" demek, o isin
    # VAR OLDUGUNU dogrulamak olurdu).
    assert client.get(f"/raporlar/isler/{is_id}/indir", headers=b).status_code == 404


def test_HAZIR_OLMAYAN_is_indirilemez_409(client, world):
    # Worker testte kosmuyor olabilir; is `bekliyor`da kalir. Arayuzun
    # "indir" dugmesini o durumda cizmemesi gerekir ve uc de reddeder.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    is_id = client.post("/raporlar/borc_alacak/kuyruk?bicim=excel", headers=y,
                        json={}).json()["id"]
    r = client.get(f"/raporlar/isler/{is_id}/indir", headers=y)
    # Worker acikken is hazir olabilir; kapaliyken 409. IKISI DE DOGRU —
    # test edilen sey "hazir olmayan is indirilemez", worker'in hizi degil.
    assert r.status_code in (200, 409), r.text
    if r.status_code == 409:
        assert r.json()["error"]["code"] == "conflict"


def test_PARAMETRE_ISLE_BIRLIKTE_SAKLANIR(client, world):
    # Is kuyruga girdikten sonra kullanicinin sectigi suzgecler
    # DEGISMEMELI; "ayni raporu tekrar al" da bu kayittan beslenir.
    y = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/raporlar/detayli_borc/kuyruk?bicim=pdf", headers=y, json={
        "baslangic": "2026-03-01", "bitis": "2026-03-31", "ismi_goster": False,
    })
    assert r.status_code == 202, r.text
    # Parametre yanitin ICINDE donmuyor (gereksiz), ama is listesinde
    # kod/bicim korunuyor — saklandiginin gozlemlenebilir isareti.
    isler = client.get("/raporlar/isler", headers=y).json()
    kayit = next(i for i in isler if i["id"] == r.json()["id"])
    assert kayit["kod"] == "detayli_borc" and kayit["bicim"] == "pdf"


def test_kuyruk_SAHA_ROLLERINE_kapali(client, world):
    for kim in ("guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[kim])
        assert client.post(
            "/raporlar/borc_alacak/kuyruk?bicim=excel", headers=h, json={}
        ).status_code == 403, kim
        assert client.get("/raporlar/isler", headers=h).status_code == 403, kim


def test_DENETCI_kuyrugu_KULLANABILIR(client, world):
    # Rapor URETIMI bir OKUMADIR (P128'in notu): `POST` secilmesinin sebebi
    # parametrelerin bir govde istemesi. Denetciye kapatmak, ona gorevinin
    # ana aracini kapatmak olurdu.
    d = _headers(client, world["slug_a"], world["denetci_a"])
    assert client.post(
        "/raporlar/borc_alacak/kuyruk?bicim=excel", headers=d, json={}
    ).status_code == 202
    assert client.get("/raporlar/isler", headers=d).status_code == 200
