"""Borclandirma UCLARI (P28) — tekil / toplu / sayac / ice aktarim.

BIRLESTIRME KARARI KILITLI: dort yol da `dues_assessment`e yazar, yani
mevcut aidat akislari (bakiye, /me/dues, rapor) bozulmaz.
"""
from __future__ import annotations

import uuid
from datetime import date

import pytest



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
def gider(client, adm):
    """Bir GIDER tanimi (kiraci oncelikli — varsayilan)."""
    r = client.post("/gelir-gider-tanimlari", headers=adm,
                    json={"ad": f"Elektrik-{_sfx()}", "tip": "gider",
                          "dagitim_sekli": "bagimsiz_bolumlere_esit"})
    assert r.status_code == 201, r.text
    return r.json()


def _daire(client, adm, blok="A", **over):
    govde = {"no": f"B-{_sfx()}", "blok": blok}
    govde.update(over)
    r = client.post("/units", headers=adm, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


#: Telefon GLOBAL benzersiz login anahtaridir; kosumlar arasi catismasin
#: diye sayacli uretilir (repo geneli desen).
_TEL = [0]


def _sakin(client, adm, unit_no, rol_tipi):
    """Sakin olustur — `/residents` DAIRE NO ve TELEFON ister (unit_id degil)."""
    _TEL[0] += 1
    r = client.post("/residents", headers=adm, json={
        "ad": f"Sakin {_sfx()}", "unit_no": unit_no,
        "telefon": f"+9055{_TEL[0]:08d}", "rol_tipi": rol_tipi, "email": _p197_mail()})
    assert r.status_code in (200, 201), r.text
    return r.json()


# ============================ TEKIL BORCLANDIRMA ============================ #
def test_tekil_TUR_ve_HEDEF_ile(client, adm, gider):
    """Tekil yol icin AYRI UC ACILMADI: mevcut /dues/assessments genisletildi."""
    unit = _daire(client, adm)
    _sakin(client, adm, unit["no"], "kiraci")
    r = client.post("/dues/assessments", headers=adm, json={
        "donem": f"2026-0{_sfx()[0] if _sfx()[0].isdigit() and _sfx()[0] != '0' else '1'}",
        "unit_id": unit["id"], "tutar_kurus": 150000,
        "gelir_gider_tanim_id": gider["id"],
    })
    assert r.status_code == 201, r.text
    kayit = r.json()["created"][0]
    assert kayit["gelir_gider_tanim_id"] == gider["id"]
    assert kayit["gelir_gider_tanim_ad"] == gider["ad"]
    assert kayit["hedef_user_id"] is not None, "kiraci hedeflenmeliydi"
    assert kayit["hedef_ad"]


def test_tur_VERILMEZSE_eski_davranis(client, adm):
    """Mevcut cagiranlar (mobil, panel) hicbir sey degistirmeden calisir."""
    unit = _daire(client, adm)
    r = client.post("/dues/assessments", headers=adm, json={
        "donem": "2026-02", "unit_id": unit["id"], "tutar_kurus": 100000,
    })
    assert r.status_code == 201
    kayit = r.json()["created"][0]
    assert kayit["gelir_gider_tanim_id"] is None
    assert kayit["hedef_user_id"] is None, "tursuz tahakkuk DAIREYE yazilir"


def test_GELIR_kalemi_BORCLANDIRILAMAZ(client, adm):
    gelir = client.post("/gelir-gider-tanimlari", headers=adm,
                        json={"ad": f"Kira-{_sfx()}", "tip": "gelir"}).json()
    unit = _daire(client, adm)
    r = client.post("/dues/assessments", headers=adm, json={
        "donem": "2026-03", "unit_id": unit["id"], "tutar_kurus": 1000,
        "gelir_gider_tanim_id": gelir["id"],
    })
    assert r.status_code == 422


def test_AYNI_DONEMDE_FARKLI_TUR_serbest(client, adm, gider):
    """OMURGA: eski kisit donem basina TEK kayda izin veriyordu; oysa ayni ay
    hem aidat hem elektrik borclandirilir."""
    unit = _daire(client, adm)
    ikinci = client.post("/gelir-gider-tanimlari", headers=adm,
                         json={"ad": f"Su-{_sfx()}", "tip": "gider"}).json()
    donem = "2026-04"
    a = client.post("/dues/assessments", headers=adm, json={
        "donem": donem, "unit_id": unit["id"], "tutar_kurus": 1000,
        "gelir_gider_tanim_id": gider["id"]})
    b = client.post("/dues/assessments", headers=adm, json={
        "donem": donem, "unit_id": unit["id"], "tutar_kurus": 2000,
        "gelir_gider_tanim_id": ikinci["id"]})
    assert a.status_code == 201 and b.status_code == 201
    # ...ama AYNI TUR ikinci kez 409 (mukerrer tahakkuk korumasi DURUYOR).
    c = client.post("/dues/assessments", headers=adm, json={
        "donem": donem, "unit_id": unit["id"], "tutar_kurus": 3000,
        "gelir_gider_tanim_id": gider["id"]})
    assert c.status_code == 409


def test_TURSUZ_kayitlarda_ESKI_koruma_AYNEN_duruyor(client, adm):
    """Postgres'te NULL'lar benzersizlikte FARKLI sayilir; duz bir
    UNIQUE(..., tanim_id) eski korumayi SESSIZCE kaldirirdi."""
    unit = _daire(client, adm)
    ilk = client.post("/dues/assessments", headers=adm, json={
        "donem": "2026-05", "unit_id": unit["id"], "tutar_kurus": 1000})
    ikinci = client.post("/dues/assessments", headers=adm, json={
        "donem": "2026-05", "unit_id": unit["id"], "tutar_kurus": 2000})
    assert ilk.status_code == 201
    assert ikinci.status_code == 409, "tursuz mukerrer tahakkuk korumasi kalkmis"


# ============================ HEDEFLEME KURALI ============================== #
def test_hedefleme_KIRACI_VAR_YOK_IKISI_BIRDEN(client, adm):
    """P28 kabul olcutu: kiraci var / yok / ikisi birden."""
    malik_tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Yatirim-{_sfx()}", "tip": "gider", "hedef_kurali": "malik",
    }).json()
    kiraci_tanim = client.post("/gelir-gider-tanimlari", headers=adm, json={
        "ad": f"Aidat-{_sfx()}", "tip": "gider",
        "hedef_kurali": "kiraci_oncelikli",
    }).json()

    # (1) IKISI BIRDEN
    u1 = _daire(client, adm)
    m1 = _sakin(client, adm, u1["no"], "malik")
    k1 = _sakin(client, adm, u1["no"], "kiraci")
    r = client.post("/dues/assessments", headers=adm, json={
        "donem": "2026-06", "unit_id": u1["id"], "tutar_kurus": 1000,
        "gelir_gider_tanim_id": kiraci_tanim["id"]})
    assert r.json()["created"][0]["hedef_user_id"] == k1["user_id"]
    r = client.post("/dues/assessments", headers=adm, json={
        "donem": "2026-06", "unit_id": u1["id"], "tutar_kurus": 1000,
        "gelir_gider_tanim_id": malik_tanim["id"]})
    assert r.json()["created"][0]["hedef_user_id"] == m1["user_id"]

    # (2) YALNIZ MALIK
    u2 = _daire(client, adm)
    m2 = _sakin(client, adm, u2["no"], "malik")
    r = client.post("/dues/assessments", headers=adm, json={
        "donem": "2026-06", "unit_id": u2["id"], "tutar_kurus": 1000,
        "gelir_gider_tanim_id": kiraci_tanim["id"]})
    assert r.json()["created"][0]["hedef_user_id"] == m2["user_id"], "kiraci yoksa malik"

    # (3) YALNIZ KIRACI — malik kurali kimseyi bulamaz, DAIREYE yazilir.
    u3 = _daire(client, adm)
    _sakin(client, adm, u3["no"], "kiraci")
    r = client.post("/dues/assessments", headers=adm, json={
        "donem": "2026-06", "unit_id": u3["id"], "tutar_kurus": 1000,
        "gelir_gider_tanim_id": malik_tanim["id"]})
    assert r.json()["created"][0]["hedef_user_id"] is None


# ============================ TOPLU BORCLANDIRMA ============================ #
def test_toplu_ONIZLEME_HICBIR_SEY_YAZMAZ(client, adm, gider):
    blok = f"T{_sfx()[:3].upper()}"
    for _ in range(3):
        _daire(client, adm, blok=blok)
    istek = {"donem": "2026-07", "gelir_gider_tanim_id": gider["id"],
             "suzgec": {"blok": blok}, "tutar_kurus": 50000}
    on = client.post("/borclandirma/toplu/onizleme", headers=adm, json=istek)
    assert on.status_code == 200, on.text
    assert on.json()["islenecek"] == 3
    assert on.json()["toplam_kurus"] == 150000

    liste = client.get("/dues/assessments", headers=adm,
                       params={"donem": "2026-07", "limit": 200}).json()
    assert liste["meta"]["total"] == 0, "onizleme YAZDI!"


def test_toplu_ISLEME_onizleme_ile_AYNI(client, adm, gider):
    blok = f"T{_sfx()[:3].upper()}"
    for _ in range(4):
        _daire(client, adm, blok=blok)
    istek = {"donem": "2026-08", "gelir_gider_tanim_id": gider["id"],
             "suzgec": {"blok": blok}, "tutar_kurus": 25000}
    on = client.post("/borclandirma/toplu/onizleme", headers=adm, json=istek).json()
    r = client.post("/borclandirma/toplu", headers=adm, json=istek)
    assert r.status_code == 201, r.text

    liste = client.get("/dues/assessments", headers=adm, params={
        "donem": "2026-08", "gelir_gider_tanim_id": gider["id"], "limit": 200,
    }).json()
    assert liste["meta"]["total"] == on["islenecek"]
    assert sum(i["tutar_kurus"] for i in liste["items"]) == on["toplam_kurus"]


def test_toplu_TIP_VARSAYILANI_kullanir_tanimsizi_ATLAR(client, adm, gider):
    """Sessizce 0 borclandirmak, yonetimin fark etmedigi eksik tahakkuk
    uretirdi — atlanan AYRI sayilir ve onizlemede gorunur."""
    tip = client.post("/unit-tipleri", headers=adm, json={
        "ad": f"2+1-{_sfx()}", "varsayilan_aidat_kurus": 80000}).json()
    blok = f"T{_sfx()[:3].upper()}"
    _daire(client, adm, blok=blok, unit_tip_id=tip["id"])
    _daire(client, adm, blok=blok, unit_tip_id=tip["id"])
    _daire(client, adm, blok=blok)  # TIPSIZ

    istek = {"donem": "2026-09", "gelir_gider_tanim_id": gider["id"],
             "suzgec": {"blok": blok}}
    on = client.post("/borclandirma/toplu/onizleme", headers=adm, json=istek).json()
    assert on["islenecek"] == 2 and on["atlanacak"] == 1
    assert on["toplam_kurus"] == 160000

    # YEDEK tutar verilince tipsiz daire de islenir.
    istek["yedek_tutar_kurus"] = 60000
    on2 = client.post("/borclandirma/toplu/onizleme", headers=adm, json=istek).json()
    assert on2["islenecek"] == 3 and on2["toplam_kurus"] == 220000


def test_toplu_ELLE_SECIM_suzgeci_EZER(client, adm, gider):
    a = _daire(client, adm, blok="AA")
    b = _daire(client, adm, blok="BB")
    istek = {"donem": "2026-10", "gelir_gider_tanim_id": gider["id"],
             "suzgec": {"blok": "AA", "unit_ids": [a["id"], b["id"]]},
             "tutar_kurus": 1000}
    on = client.post("/borclandirma/toplu/onizleme", headers=adm, json=istek).json()
    assert on["islenecek"] == 2, "secilen daire suzgecle elenmemeli"


def test_toplu_TEKRAR_calistirilinca_ATLAR(client, adm, gider):
    blok = f"T{_sfx()[:3].upper()}"
    _daire(client, adm, blok=blok)
    istek = {"donem": "2026-11", "gelir_gider_tanim_id": gider["id"],
             "suzgec": {"blok": blok}, "tutar_kurus": 1000}
    assert client.post("/borclandirma/toplu", headers=adm, json=istek).status_code == 201
    ikinci = client.post("/borclandirma/toplu", headers=adm, json=istek)
    assert ikinci.status_code == 201
    assert ikinci.json()["atlanan"] == 1, "mukerrer tahakkuk yazilmis"


# ========================= SAYAC ILE BORCLANDIRMA =========================== #
def test_sayac_sihirbazi_ORTAK_ALANI_dagitir(client, adm, gider):
    ana = client.post("/sayaclar/ana", headers=adm, json={
        "ad": f"Ana-{_sfx()}", "tip": "su", "ortak_alan_yuzde": 100}).json()
    sayaclar = []
    for _ in range(2):
        u = _daire(client, adm)
        s = client.post("/sayaclar/bolum", headers=adm, json={
            "unit_id": u["id"], "ana_sayac_id": ana["id"]})
        assert s.status_code == 201, s.text
        sayaclar.append(s.json())

    r = client.post("/borclandirma/sayac", headers=adm, json={
        "donem": "2026-12", "gelir_gider_tanim_id": gider["id"],
        "ana_sayac_id": ana["id"], "ana_tuketim": 100,
        "birim_fiyat_kurus": 1000,
        "bolum_tuketimleri": {sayaclar[0]["id"]: 30, sayaclar[1]["id"]: 30},
    })
    assert r.status_code == 201, r.text
    liste = client.get("/dues/assessments", headers=adm, params={
        "donem": "2026-12", "gelir_gider_tanim_id": gider["id"], "limit": 200,
    }).json()
    # 60 birim daire + 40 birim ortak = 100 birim x 10,00 TL
    assert sum(i["tutar_kurus"] for i in liste["items"]) == 100_000


def test_sayac_OLMAYAN_ana_sayac_422(client, adm, gider):
    r = client.post("/borclandirma/sayac", headers=adm, json={
        "donem": "2026-12", "gelir_gider_tanim_id": gider["id"],
        "ana_sayac_id": str(uuid.uuid4()), "ana_tuketim": 10,
        "birim_fiyat_kurus": 100, "bolum_tuketimleri": {},
    })
    assert r.status_code == 422


# ============================== ICE AKTARIM ================================= #
def test_ice_aktarim_BOZUK_SATIR_tum_islemi_DUSURMEZ(client, adm, gider):
    """400 satirlik dosyada 3 hatali satir yuzunden 397 dogru satiri
    reddetmek, kullaniciyi dosyayi elle ayiklamaya zorlardi."""
    u1 = _daire(client, adm)
    u2 = _daire(client, adm)
    r = client.post("/borclandirma/ice-aktarim", headers=adm, json={
        "donem": "2027-01", "gelir_gider_tanim_id": gider["id"],
        "satirlar": [
            {"satir_no": 2, "unit_no": u1["no"], "tutar_kurus": 10000},
            {"satir_no": 3, "unit_no": "OLMAYAN-DAIRE", "tutar_kurus": 10000},
            {"satir_no": 4, "unit_no": u2["no"], "tutar_kurus": 0},
            {"satir_no": 5, "unit_no": u2["no"], "tutar_kurus": 20000},
        ], "email": _p197_mail()})
    assert r.status_code == 201, r.text
    sonuc = r.json()
    assert sonuc["olusturulan"] == 2
    assert sonuc["atlanan"] == 2
    numaralar = {h["satir_no"] for h in sonuc["hatalar"]}
    assert numaralar == {3, 4}, sonuc["hatalar"]
    # Hata metni COZULMUS (kimlik degil).
    assert all(h["hata"] and " " in h["hata"] for h in sonuc["hatalar"])


def test_ice_aktarim_MUKERRER_satir_raporlanir(client, adm, gider):
    u = _daire(client, adm)
    govde = {"donem": "2027-02", "gelir_gider_tanim_id": gider["id"],
             "satirlar": [{"satir_no": 2, "unit_no": u["no"], "tutar_kurus": 5000}]}
    assert client.post("/borclandirma/ice-aktarim", headers=adm,
                       json=govde).json()["olusturulan"] == 1
    ikinci = client.post("/borclandirma/ice-aktarim", headers=adm, json=govde).json()
    assert ikinci["olusturulan"] == 0 and len(ikinci["hatalar"]) == 1


# ============================== GECIKME ===================================== #
def test_gecikme_ANLIK_hesaplanir_SAKLANMAZ(client, adm, gider):
    """Oran degistiginde GECMIS kayitlar da yeni orana gore okunmali —
    saklansaydi ayni borc iki yerde iki tutar gosterirdi."""
    unit = _daire(client, adm)
    gecmis = date(2026, 1, 10).isoformat()
    client.post("/dues/assessments", headers=adm, json={
        "donem": "2027-03", "unit_id": unit["id"], "tutar_kurus": 100000,
        "gelir_gider_tanim_id": gider["id"], "son_odeme_tarihi": gecmis,
    })

    def _gecikme():
        liste = client.get("/dues/assessments", headers=adm, params={
            "donem": "2027-03", "unit_id": unit["id"]}).json()["items"]
        return liste[0]["gecikme_kurus"]

    assert client.patch("/borclandirma/gecikme-ayari", headers=adm,
                        json={"gecikme_aylik_yuzde": 0}).status_code == 200
    assert _gecikme() == 0

    assert client.patch("/borclandirma/gecikme-ayari", headers=adm,
                        json={"gecikme_aylik_yuzde": 2}).status_code == 200
    ilk = _gecikme()
    assert ilk > 0

    client.patch("/borclandirma/gecikme-ayari", headers=adm,
                 json={"gecikme_aylik_yuzde": 4})
    assert _gecikme() == ilk * 2, "gecmis kayit yeni orana gore okunmali"
    # Temizlik: diger testleri etkilemesin.
    client.patch("/borclandirma/gecikme-ayari", headers=adm,
                 json={"gecikme_aylik_yuzde": 0})


def test_gecikme_UYGULA_KAPALI_kalem_sifir(client, adm, gider):
    unit = _daire(client, adm)
    client.post("/dues/assessments", headers=adm, json={
        "donem": "2027-04", "unit_id": unit["id"], "tutar_kurus": 100000,
        "gelir_gider_tanim_id": gider["id"],
        "son_odeme_tarihi": date(2026, 1, 10).isoformat(),
        "gecikme_uygula": False,
    })
    client.patch("/borclandirma/gecikme-ayari", headers=adm,
                 json={"gecikme_aylik_yuzde": 5})
    liste = client.get("/dues/assessments", headers=adm, params={
        "donem": "2027-04", "unit_id": unit["id"]}).json()["items"]
    assert liste[0]["gecikme_kurus"] == 0
    client.patch("/borclandirma/gecikme-ayari", headers=adm,
                 json={"gecikme_aylik_yuzde": 0})


# ================================ RBAC ====================================== #
def test_rbac_yazma_YONETIM(client, world):
    """(P206 §1) YONETICI DE YAZAR — eski ad `..._ADMIN`di.

    Donem basi toplu borclandirma site yoneticisinin ASIL isi; onu
    platform adminine birakmak musteriyi her donem bize bagimli
    kiliyordu.
    """
    for rol, izin in [("admin_a", True), ("yonetici_a", True),
                      ("guard_a", False), ("resident_a", False)]:
        h = _headers(client, world["slug_a"], world[rol])
        r = client.post("/borclandirma/toplu/onizleme", headers=h, json={
            "donem": "2027-05", "gelir_gider_tanim_id": str(uuid.uuid4()),
        })
        # admin 422 alir (olmayan tanim); digerleri 403.
        assert (r.status_code != 403) is izin, (rol, r.status_code)
