"""Muhasebe "Tanimlar" katmani (P27) — yedi kayit defteri + ayarlar.

Kilitlenen kararlar:
  * para HER YERDE kurus; acilis bakiyesi ISARETSIZ tutar + AYRI yon,
  * IBAN yalniz BANKA kasasinda,
  * GELIR kaleminde dagitim sekli OLMAZ,
  * personel kaydi app_user'DAN AYRI (bag opsiyonel, hesap silinince kayit
    durur),
  * arac plakasi `vehicle_pass` ile AYNI kuralla normalize,
  * tanim silinince BAGLI kayitlar durur (SET NULL) — daire sayaci haric
    (dairesi silinince CASCADE),
  * otomatik sayac uretimi YENIDEN CALISTIRILABILIR,
  * `para_birimi` YALNIZ GOSTERIM.
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


@pytest.fixture
def yon(client, world):
    return _headers(client, world["slug_a"], world["yonetici_a"])


def _sfx() -> str:
    return uuid.uuid4().hex[:6]


# ================================= KASA ===================================== #
def test_kasa_crud_ve_acilis_bakiyesi_KURUS(client, yon):
    r = client.post("/kasalar", headers=yon, json={
        "kod": f"K{_sfx()}", "ad": "Merkez Kasa",
        "acilis_bakiye_kurus": 1250050, "acilis_tarihi": "2026-01-01",
    })
    assert r.status_code == 201, r.text
    assert r.json()["acilis_bakiye_kurus"] == 1250050

    kid = r.json()["id"]
    r2 = client.patch(f"/kasalar/{kid}", headers=yon, json={"ad": "Yeni Ad"})
    assert r2.status_code == 200 and r2.json()["ad"] == "Yeni Ad"
    assert client.delete(f"/kasalar/{kid}", headers=yon).status_code == 204


def test_kasa_IBAN_yalniz_BANKA_kasasinda(client, yon):
    """Banka olmayan bir kasada dolu IBAN, odemeyi yanlis hesaba yonlendirirdi."""
    kotu = client.post("/kasalar", headers=yon, json={
        "kod": f"K{_sfx()}", "ad": "Nakit", "banka_mi": False,
        "iban": "TR" + "1" * 24,
    })
    assert kotu.status_code == 422

    iyi = client.post("/kasalar", headers=yon, json={
        "kod": f"K{_sfx()}", "ad": "Banka", "banka_mi": True,
        "iban": "TR" + "1" * 24, "banka_adi": "X Bank",
    })
    assert iyi.status_code == 201


def test_kasa_banka_KAPATILIRKEN_iban_kalirsa_422(client, yon):
    """BIRLESIK durum: `banka_mi` kapatilirken IBAN gonderilmemis olabilir —
    DB CHECK'i 500 gibi okunan bir ihlal verirdi."""
    kid = client.post("/kasalar", headers=yon, json={
        "kod": f"K{_sfx()}", "ad": "Banka", "banka_mi": True,
        "iban": "TR" + "2" * 24,
    }).json()["id"]
    r = client.patch(f"/kasalar/{kid}", headers=yon, json={"banka_mi": False})
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "validation_error"


def test_kasa_gecersiz_IBAN_RET(client, yon):
    assert client.post("/kasalar", headers=yon, json={
        "kod": f"K{_sfx()}", "ad": "B", "banka_mi": True, "iban": "TR123",
    }).status_code == 422


# ========================= GELIR/GIDER =============================== #
def test_gelir_kaleminde_DAGITIM_OLMAZ(client, yon):
    """Bir GELIR kalemi bagimsiz bolumlere dagitilmaz, tahsil edilir."""
    r = client.post("/gelir-gider-tanimlari", headers=yon, json={
        "ad": f"Kira-{_sfx()}", "tip": "gelir",
        "dagitim_sekli": "bagimsiz_bolumlere_esit",
    })
    assert r.status_code == 422

    ok = client.post("/gelir-gider-tanimlari", headers=yon, json={
        "ad": f"Asansor-{_sfx()}", "tip": "gider",
        "dagitim_sekli": "bagimsiz_bolumlere_esit",
    })
    assert ok.status_code == 201


def test_tip_GELIRE_cevrilirken_eski_dagitim_yakalanir(client, yon):
    """BIRLESIK kural: PATCH yalniz `tip` gonderirse eski dagitim kalirdi."""
    tid = client.post("/gelir-gider-tanimlari", headers=yon, json={
        "ad": f"G-{_sfx()}", "tip": "gider", "dagitim_sekli": "tipe_gore",
    }).json()["id"]
    r = client.patch(f"/gelir-gider-tanimlari/{tid}", headers=yon,
                     json={"tip": "gelir"})
    assert r.status_code == 422


def test_dagitim_ENUM_yalniz_IKI_deger(client, yon):
    """"arsa_payi"/"kisi_sayisi" BILEREK yok: secilebilir ama uygulanmayan bir
    secenek YANLIS BORCLANDIRIRDI."""
    r = client.post("/gelir-gider-tanimlari", headers=yon, json={
        "ad": f"X-{_sfx()}", "tip": "gider", "dagitim_sekli": "arsa_payi",
    })
    assert r.status_code == 422


def test_grup_silinince_TANIM_DURUR(client, yon):
    gid = client.post("/gelir-gider-gruplari", headers=yon,
                      json={"ad": f"Grup-{_sfx()}"}).json()["id"]
    tid = client.post("/gelir-gider-tanimlari", headers=yon, json={
        "ad": f"T-{_sfx()}", "tip": "gider", "grup_id": gid,
    }).json()["id"]

    r = client.delete(f"/gelir-gider-gruplari/{gid}", headers=yon)
    assert r.status_code == 200 and r.json()["etkilenen_tanim"] == 1

    liste = client.get("/gelir-gider-tanimlari", headers=yon,
                       params={"limit": 200}).json()["items"]
    kalan = next(t for t in liste if t["id"] == tid)
    assert kalan["grup_id"] is None, "tanim silinmis ya da grubu duruyor"


def test_grup_adi_ciktida_doner(client, yon):
    gid = client.post("/gelir-gider-gruplari", headers=yon,
                      json={"ad": f"Bakim-{_sfx()}"}).json()
    r = client.post("/gelir-gider-tanimlari", headers=yon, json={
        "ad": f"T-{_sfx()}", "tip": "gider", "grup_id": gid["id"],
    })
    assert r.json()["grup_ad"] == gid["ad"]


def test_olmayan_grup_422(client, yon):
    r = client.post("/gelir-gider-tanimlari", headers=yon, json={
        "ad": f"T-{_sfx()}", "tip": "gider", "grup_id": str(uuid.uuid4()),
    })
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "invalid_reference"


# ================================ FIRMA ===================================== #
def test_firma_acilis_bakiyesi_ISARETSIZ_tutar_AYRI_yon(client, yon):
    """"-500" bir firmada "biz mi borcluyuz, o mu" sorusunu yanitlamaz."""
    r = client.post("/firmalar", headers=yon, json={
        "ad": f"Firma-{_sfx()}", "acilis_bakiye_kurus": 50000,
        "acilis_bakiye_yon": "alacak", "vergi_no": "1234567890",
    })
    assert r.status_code == 201
    assert r.json()["acilis_bakiye_yon"] == "alacak"
    # NEGATIF tutar reddedilir (isaret yon alaninda tasinir).
    assert client.post("/firmalar", headers=yon, json={
        "ad": f"F-{_sfx()}", "acilis_bakiye_kurus": -1,
    }).status_code == 422


def test_firma_vergi_no_10_veya_11_hane(client, yon):
    for no, beklenen in [("1234567890", 201), ("12345678901", 201),
                         ("123", 422), ("abcdefghij", 422)]:
        r = client.post("/firmalar", headers=yon,
                        json={"ad": f"F-{_sfx()}", "vergi_no": no})
        assert r.status_code == beklenen, (no, r.text)


# ============================== PERSONEL ==================================== #
def test_personel_app_user_BAGI_OPSIYONEL(client, world, yon):
    """Her personelin uygulama hesabi yoktur; her kullanici personel degildir."""
    hesapsiz = client.post("/personel-kayitlari", headers=yon,
                           json={"ad": "Bahcivan Ali", "gorev": "Bahcivan"})
    assert hesapsiz.status_code == 201
    assert hesapsiz.json()["app_user_id"] is None

    kullanicilar = client.get("/users", headers=yon,
                              params={"limit": 50}).json()["items"]
    uid = kullanicilar[0]["id"]
    bagli = client.post("/personel-kayitlari", headers=yon, json={
        "ad": "Bagli Personel", "app_user_id": uid, "maas_kurus": 4500000,
    })
    assert bagli.status_code == 201
    assert bagli.json()["app_user_id"] == uid
    assert bagli.json()["app_user_ad"], "bagli kullanicinin adi donmeli"


def test_personel_CIKIS_GIRISTEN_once_olamaz(client, yon):
    r = client.post("/personel-kayitlari", headers=yon, json={
        "ad": "X", "giris_tarihi": "2026-05-01", "cikis_tarihi": "2026-04-01",
    })
    assert r.status_code == 422

    pid = client.post("/personel-kayitlari", headers=yon, json={
        "ad": "Y", "giris_tarihi": "2026-05-01",
    }).json()["id"]
    # BIRLESIK: PATCH yalniz cikis gonderirse giris kayitta kalir.
    r2 = client.patch(f"/personel-kayitlari/{pid}", headers=yon,
                      json={"cikis_tarihi": "2026-04-01"})
    assert r2.status_code == 422


def test_personel_TC_11_hane(client, yon):
    assert client.post("/personel-kayitlari", headers=yon,
                       json={"ad": "Z", "tc": "123"}).status_code == 422
    assert client.post("/personel-kayitlari", headers=yon,
                       json={"ad": "Z", "tc": "12345678901"}).status_code == 201


# ================================ ARAC ====================================== #
def test_arac_plakasi_NORMALIZE_edilir(client, yon):
    """`vehicle_pass` ile AYNI kural — iki farkli normalizasyon iki farkli
    cevap verirdi (P17 rozetleri bu tablodan soracak)."""
    plaka = f"34 xy {uuid.uuid4().hex[:3]}"
    r = client.post("/arac-kayitlari", headers=yon, json={"plaka": plaka})
    assert r.status_code == 201
    kayitli = r.json()["plaka"]
    assert kayitli == plaka.replace(" ", "").upper()

    # ARAMA da normalize edilir: bosluklu yazilsa da bulmali.
    bulundu = client.get("/arac-kayitlari", headers=yon,
                         params={"plaka": plaka}).json()["items"]
    assert [a["plaka"] for a in bulundu] == [kayitli]


def test_arac_plaka_SITE_ICINDE_TEK(client, yon):
    """Iki daireye kayitli bir arac, rozetin hangi daireyi gosterecegini
    belirsiz birakirdi."""
    plaka = f"34ZZ{uuid.uuid4().hex[:4].upper()}"
    assert client.post("/arac-kayitlari", headers=yon,
                       json={"plaka": plaka}).status_code == 201
    assert client.post("/arac-kayitlari", headers=yon,
                       json={"plaka": plaka}).status_code == 409


def test_arac_daireye_baglanir_ADIYLA_doner(client, yon):
    blok = "A"
    unit = client.post("/units", headers=yon,
                       json={"no": f"AR-{_sfx()}", "blok": blok}).json()
    r = client.post("/arac-kayitlari", headers=yon, json={
        "plaka": f"06AB{uuid.uuid4().hex[:3].upper()}", "unit_id": unit["id"],
        "marka": "Fiat", "model": "Egea", "renk": "Beyaz",
    })
    assert r.status_code == 201
    assert r.json()["unit_no"] == unit["no"]


# =============================== SAYACLAR =================================== #
def test_sayac_otomatik_uretim_YENIDEN_CALISTIRILABILIR(client, yon):
    """ZATEN sayaci olan daireler ATLANIR — yeni daireler eklendikce uc
    tekrar cagrilir ve benzersizlik kisitina carpip 409 vermez."""
    # En az bir AKTIF daire olmali (world fixture'i daire kurmaz).
    for _ in range(2):
        assert client.post("/units", headers=yon, json={
            "no": f"OT-{_sfx()}", "blok": "A",
        }).status_code == 201
    ana = client.post("/sayaclar/ana", headers=yon,
                      json={"ad": f"Ana Su {_sfx()}", "tip": "su"}).json()
    ilk = client.post("/sayaclar/bolum/otomatik", headers=yon,
                      json={"ana_sayac_id": ana["id"]})
    assert ilk.status_code == 201, ilk.text
    assert ilk.json()["olusturulan"] >= 2
    assert ilk.json()["atlanan"] == 0

    ikinci = client.post("/sayaclar/bolum/otomatik", headers=yon,
                         json={"ana_sayac_id": ana["id"]})
    assert ikinci.status_code == 201
    assert ikinci.json()["olusturulan"] == 0
    assert ikinci.json()["atlanan"] == ilk.json()["olusturulan"]


def test_ana_sayac_silinince_BOLUM_SAYACLARI_DURUR(client, yon):
    ana = client.post("/sayaclar/ana", headers=yon,
                      json={"ad": f"Ana {_sfx()}"}).json()
    unit = client.post("/units", headers=yon,
                       json={"no": f"SB-{_sfx()}", "blok": "A"}).json()
    bolum = client.post("/sayaclar/bolum", headers=yon, json={
        "unit_id": unit["id"], "ana_sayac_id": ana["id"], "ilk_okuma": 12.5,
    })
    assert bolum.status_code == 201, bolum.text

    r = client.delete(f"/sayaclar/ana/{ana['id']}", headers=yon)
    assert r.status_code == 200 and r.json()["etkilenen_bolum_sayaci"] == 1

    kalan = client.get("/sayaclar/bolum", headers=yon,
                       params={"unit_id": unit["id"]}).json()["items"]
    assert len(kalan) == 1 and kalan[0]["ana_sayac_id"] is None


def test_ayni_daire_ayni_ana_sayac_TEK(client, yon):
    ana = client.post("/sayaclar/ana", headers=yon,
                      json={"ad": f"Ana {_sfx()}"}).json()
    unit = client.post("/units", headers=yon,
                       json={"no": f"SC-{_sfx()}", "blok": "A"}).json()
    govde = {"unit_id": unit["id"], "ana_sayac_id": ana["id"]}
    assert client.post("/sayaclar/bolum", headers=yon,
                       json=govde).status_code == 201
    assert client.post("/sayaclar/bolum", headers=yon,
                       json=govde).status_code == 409


def test_ortak_alan_yuzdesi_SINIRLI(client, yon):
    for yuzde, beklenen in [(0, 201), (100, 201), (100.01, 422), (-1, 422)]:
        r = client.post("/sayaclar/ana", headers=yon, json={
            "ad": f"A-{_sfx()}", "ortak_alan_yuzde": yuzde,
        })
        assert r.status_code == beklenen, (yuzde, r.text)


# =========================== MUHASEBE AYARLARI ============================== #
def test_muhasebe_ayarlari_varsayilan_ve_guncelleme(client, yon):
    r = client.get("/muhasebe-ayarlari", headers=yon)
    assert r.status_code == 200
    assert r.json()["para_birimi"] == "TRY"
    assert r.json()["evrak_sira"] >= 1

    g = client.patch("/muhasebe-ayarlari", headers=yon,
                     json={"evrak_seri": "AB", "evrak_sira": 1000})
    assert g.status_code == 200
    assert g.json()["evrak_seri"] == "AB" and g.json()["evrak_sira"] == 1000

    # Bicim kurallari: seri BUYUK harf, sira >= 1, para birimi 3 harf.
    assert client.patch("/muhasebe-ayarlari", headers=yon,
                        json={"evrak_seri": "ab1"}).status_code == 422
    assert client.patch("/muhasebe-ayarlari", headers=yon,
                        json={"evrak_sira": 0}).status_code == 422
    assert client.patch("/muhasebe-ayarlari", headers=yon,
                        json={"para_birimi": "TL"}).status_code == 422


# ============================ RBAC + izolasyon ============================== #
@pytest.mark.parametrize("yol", [
    "/kasalar", "/gelir-gider-gruplari", "/gelir-gider-tanimlari", "/firmalar",
    "/personel-kayitlari", "/arac-kayitlari", "/sayaclar/ana", "/sayaclar/bolum",
    "/muhasebe-ayarlari",
])
def test_rbac_YALNIZ_YONETIM(client, world, yol):
    """Muhasebe tanimlari saha ve sakine KAPALIDIR (P26'nin daire tip/grup
    tanimlarindan farki: bunlarin saha gorunumu yok)."""
    for rol, izin in [("admin_a", True), ("yonetici_a", True),
                      ("guard_a", False), ("gorevli_a", False),
                      ("resident_a", False)]:
        h = _headers(client, world["slug_a"], world[rol])
        r = client.get(yol, headers=h)
        assert (r.status_code == 200) is izin, (yol, rol, r.status_code)


def test_tenant_izolasyonu(client, world):
    a = _headers(client, world["slug_a"], world["admin_a"])
    b = _headers(client, world["slug_b"], world["admin_b"])
    kod = f"K{_sfx()}"
    kasa = client.post("/kasalar", headers=a,
                       json={"kod": kod, "ad": "A Kasa"}).json()

    b_liste = client.get("/kasalar", headers=b,
                         params={"limit": 200}).json()["items"]
    assert kasa["id"] not in [k["id"] for k in b_liste]
    # B, A'nin kasasini GUNCELLEYEMEZ (404 — varligi bile sizmaz).
    assert client.patch(f"/kasalar/{kasa['id']}", headers=b,
                        json={"ad": "X"}).status_code == 404
    # Ayni KOD B'de serbest (benzersizlik tenant icidir).
    assert client.post("/kasalar", headers=b,
                       json={"kod": kod, "ad": "B Kasa"}).status_code == 201
