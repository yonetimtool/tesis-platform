"""(P205 §2) ZAMAN CIZELGESI, TOPLU EKLEME, SERBEST SAAT, DUZENLEME.

===========================================================================
NEYIN EKSIK OLDUGU OLCULDU
===========================================================================
P203 §4'te plan satiri saatlerini DAIMA sablondan aliyordu; §2'nin
"Hizli Vardiya Ekle" penceresi ise BASLANGIC/BITIS SAATI soruyor. Goc
0096 `vardiya_plani`ye kendi saatlerini ekledi ve `shift_id`yi
NULLABLE yapti. Sablon KALDIRILMADI: varsayilan kadro ve
`haftayi-doldur` ona dayaniyor.

Bu dosyanin en sert kilidi TOPLU EKLEMEDIR: cakisan gunler SESSIZCE
ATLANMAZ. Sunucu once hicbir sey yazmadan `uygulandi=false` doner ve
cakisan gunleri listeler; karar KULLANICININDIR.
"""
from __future__ import annotations

import datetime as dt

import pytest

from .test_p203_vardiya_plani import _ata, _giris, duzen  # noqa: F401

BUGUN = dt.date(2026, 9, 2)


def _cizelge(client, h, gun=7, baslangic=BUGUN):
    r = client.get("/vardiya-plani/cizelge", headers=h,
                   params={"baslangic": baslangic.isoformat(), "gun": gun})
    assert r.status_code == 200, r.text
    return r.json()


def _toplu(client, h, duzen, *, bas=BUGUN, son=None, bas_saat="08:00",
           son_saat="16:00", atla=False, kisi=None):
    return client.post("/vardiya-plani/toplu", headers=h, json={
        "user_id": kisi or duzen["kisi"],
        "baslangic_tarih": bas.isoformat(),
        "bitis_tarih": (son or bas).isoformat(),
        "baslangic_saat": bas_saat,
        "bitis_saat": son_saat,
        "cakisanlari_atla": atla,
    })


# ========================= 1) CIZELGE ==================================== #

def test_CIZELGE_kisi_satirlari_ve_COZULMUS_saatler(client, world, duzen):
    """Saat SUNUCUDA cozulur: istemciye "sablon mu satir mi" secimini
    yaptirmak, ayni kurali web'de ve mobilde IKI KEZ yazmakti."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    _ata(client, h, duzen, "gunduz")
    d = _cizelge(client, h, gun=1)
    kisi = next(k for k in d["personel"] if k["user_id"] == duzen["kisi"])
    blok = kisi["bloklar"][0]
    assert blok["baslar"].endswith("T08:00:00")
    assert blok["biter"].endswith("T16:00:00")
    assert blok["shift_ad"] == "P203 Gunduz"
    assert blok["gece_asiyor"] is False


def test_VARDIYASI_OLMAYAN_personel_de_listede(client, world, duzen):
    """"Kim BOSTA" da bir plan sorusudur; bos satir olmasaydi yonetici
    atamak istedigi kisiyi ekranda goremezdi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    d = _cizelge(client, h, gun=1)
    kimlikler = {k["user_id"] for k in d["personel"]}
    assert duzen["kisi"] in kimlikler and duzen["kisi2"] in kimlikler
    assert all(k["bloklar"] == [] for k in d["personel"])


def test_GECE_ASAN_vardiya_IKI_GUNE_yayilir_ve_ONCEKI_GUNDEN_TASAN_gorunur(
    client, world, duzen
):
    """22:00-05:00 blogu ERTESI GUNE tasar. Ayrica cizelge, gorunen
    araligin BIR GUN ONCESINDEN tasan bloklari da getirmeli — yoksa
    gece vardiyasi sabah saatlerinde EKRANDA HIC GORUNMEZDI."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _toplu(client, h, duzen, bas_saat="22:00", son_saat="05:00")
    assert r.status_code == 200, r.text

    d = _cizelge(client, h, gun=1)
    blok = next(k for k in d["personel"] if k["user_id"] == duzen["kisi"])["bloklar"][0]
    assert blok["baslar"].startswith("2026-09-02T22:00")
    assert blok["biter"].startswith("2026-09-03T05:00")
    assert blok["gece_asiyor"] is True

    # ERTESI GUNU tek basina istedigimizde de GORUNUR.
    d2 = _cizelge(client, h, gun=1, baslangic=BUGUN + dt.timedelta(days=1))
    bloklar = next(
        k for k in d2["personel"] if k["user_id"] == duzen["kisi"]
    )["bloklar"]
    assert len(bloklar) == 1 and bloklar[0]["gece_asiyor"] is True


# ===================== 2) TOPLU EKLEME =================================== #

def test_TARIH_ARALIGI_HER_GUN_icin_kayit_acar(client, world, duzen):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _toplu(client, h, duzen, bas=BUGUN, son=BUGUN + dt.timedelta(days=4))
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["uygulandi"] is True and d["eklenen"] == 5
    assert [g["durum"] for g in d["gunler"]] == ["eklendi"] * 5

    c = _cizelge(client, h, gun=5)
    kisi = next(k for k in c["personel"] if k["user_id"] == duzen["kisi"])
    assert len(kisi["bloklar"]) == 5


def test_CAKISAN_GUNLER_SESSIZCE_ATLANMAZ_once_SORULUR(client, world, duzen):
    """Istegin en sert sarti. Ilk istek HICBIR SEY YAZMAZ."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    # Ortadaki gun DOLU olsun.
    dolu = BUGUN + dt.timedelta(days=1)
    assert _toplu(client, h, duzen, bas=dolu).json()["eklenen"] == 1

    r = _toplu(client, h, duzen, bas=BUGUN, son=BUGUN + dt.timedelta(days=2))
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["uygulandi"] is False, "cakismaya ragmen yazildi"
    assert d["eklenen"] == 0
    assert [g["tarih"] for g in d["gunler"] if g["durum"] == "cakisma"] == [
        dolu.isoformat()
    ]

    # HICBIR SEY YAZILMADI: dolu gunun disinda kayit YOK.
    c = _cizelge(client, h, gun=3)
    kisi = next(k for k in c["personel"] if k["user_id"] == duzen["kisi"])
    assert len(kisi["bloklar"]) == 1


def test_KULLANICI_ONAYLARSA_cakisanlar_HARIC_eklenir(client, world, duzen):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    dolu = BUGUN + dt.timedelta(days=1)
    _toplu(client, h, duzen, bas=dolu)

    r = _toplu(client, h, duzen, bas=BUGUN, son=BUGUN + dt.timedelta(days=2),
               atla=True)
    d = r.json()
    assert d["uygulandi"] is True
    assert d["eklenen"] == 2 and d["cakisan"] == 1
    # HANGI GUNUN atlandigi yanitta YAZAR — "iki gun eklendi" demek,
    # eksigin hangisi oldugunu sahada aratmak olurdu.
    assert {g["tarih"]: g["durum"] for g in d["gunler"]}[dolu.isoformat()] == "cakisma"


def test_TERS_ARALIK_ve_COK_UZUN_ARALIK_REDDEDILIR(client, world, duzen):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _toplu(client, h, duzen, bas=BUGUN, son=BUGUN - dt.timedelta(days=1))
    assert r.status_code == 422, r.text
    r = _toplu(client, h, duzen, bas=BUGUN, son=BUGUN + dt.timedelta(days=40))
    assert r.status_code == 422, r.text


def test_HAFTALIK_ASIM_UYARISI_toplu_eklemede_de_doner(client, world, duzen):
    """45 saat ustu FAZLA MESAIDIR: yasal ama MALIYETLI. Engellenmez,
    UYARILIR — ve toplu eklemede uyariyi yutmak, maliyeti gorunmez
    kilardi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = _toplu(client, h, duzen, bas=BUGUN, son=BUGUN + dt.timedelta(days=6),
               bas_saat="08:00", son_saat="18:00")   # 7 x 10 = 70 saat
    d = r.json()
    assert d["uygulandi"] is True
    assert "haftalik_normal_asildi" in d["uyarilar"]


# ================== 3) SERBEST SAAT + DUZENLEME ========================== #

def test_SABLONSUZ_vardiya_CAKISMA_DENETIMINE_girer(client, world, duzen):
    """Serbest vardiyalar `join` ile denetim disinda kalsaydi, "ayni
    anda iki yerde olmak" tam da YENI yolda mumkun olurdu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    assert _toplu(client, h, duzen, bas_saat="10:00", son_saat="18:00"
                  ).json()["eklenen"] == 1
    # Sablonlu atama (08:00-16:00) serbest blokla cakisiyor -> RED.
    r = _ata(client, h, duzen, "gunduz")
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "validation_error"


def test_SAAT_DEGISTIRME_SABLONU_DEGISTIRMEZ(client, world, duzen, owner_conn):
    """Sablonu guncellemek, o vardiyadaki HERKESIN saatini sessizce
    degistirmek olurdu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    plan_id = _ata(client, h, duzen, "gunduz").json()["id"]
    r = client.patch(f"/vardiya-plani/{plan_id}", headers=h,
                     json={"baslangic_saat": "09:30", "bitis_saat": "17:30"})
    assert r.status_code == 200, r.text

    c = _cizelge(client, h, gun=1)
    blok = next(k for k in c["personel"] if k["user_id"] == duzen["kisi"])["bloklar"][0]
    assert blok["baslar"].endswith("T09:30:00")

    with owner_conn.cursor() as cur:
        cur.execute("SELECT baslangic_saat FROM shift WHERE id=%s",
                    (duzen["gunduz"],))
        assert str(cur.fetchone()[0]) == "08:00:00", "SABLON degisti"


def test_DUZENLEME_KENDI_SATIRIYLA_CAKISMAZ(client, world, duzen):
    """P203'te bir kez dusulen tuzak: kendi satirini haric tutmayan bir
    denetim, her duzenlemede "bu kisi ayni saatte baska bir vardiyada"
    derdi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    plan_id = _ata(client, h, duzen, "gunduz").json()["id"]
    r = client.patch(f"/vardiya-plani/{plan_id}", headers=h,
                     json={"baslangic_saat": "08:30"})
    assert r.status_code == 200, r.text


def test_DUZENLEME_BASKA_BIR_VARDIYAYLA_cakisirsa_REDDEDILIR(client, world, duzen):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    _toplu(client, h, duzen, bas_saat="18:00", son_saat="22:00")
    plan_id = _ata(client, h, duzen, "gunduz").json()["id"]   # 08:00-16:00
    r = client.patch(f"/vardiya-plani/{plan_id}", headers=h,
                     json={"baslangic_saat": "17:00", "bitis_saat": "20:00"})
    assert r.status_code == 422, r.text


def test_DUZENLEME_DENETIME_YAZILIR(client, world, duzen, owner_conn):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    plan_id = _ata(client, h, duzen, "gunduz").json()["id"]
    client.patch(f"/vardiya-plani/{plan_id}", headers=h,
                 json={"baslangic_saat": "09:00"})
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT meta FROM audit_log WHERE tenant_id=%s AND resource_id=%s "
            "ORDER BY ts DESC LIMIT 1",
            (world["a"], plan_id))
        meta = cur.fetchone()[0]
    assert meta["islem"] == "guncelle"
    # ONCEKI ve YENI birlikte yazilir: "neyin degistigi" sorusunu
    # yanitlamayan bir denetim kaydi hicbir ise yaramaz.
    assert "onceki" in meta and "yeni" in meta


# ========================= 4) YETKI + IZOLASYON ========================== #

def test_SAHA_CIZELGEYI_OKUR_AMA_YAZAMAZ(client, world, duzen):
    h = _giris(client, world["slug_a"], world["guard_a"])
    assert client.get("/vardiya-plani/cizelge", headers=h,
                      params={"baslangic": BUGUN.isoformat(), "gun": 1}
                      ).status_code == 200
    r = _toplu(client, h, duzen)
    assert r.status_code == 403, r.text


def test_SAKIN_CIZELGEYI_GOREMEZ(client, world, duzen):
    h = _giris(client, world["slug_a"], world["resident_a"])
    r = client.get("/vardiya-plani/cizelge", headers=h,
                   params={"baslangic": BUGUN.isoformat(), "gun": 1})
    assert r.status_code == 403, r.text


def test_BASKA_TESISIN_BLOGU_GORUNMEZ(client, world, duzen, owner_conn):
    """Izolasyon: B tesisinde ayni tarihe bir plan yazilir, A'nin
    cizelgesinde GORUNMEMELI."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    with owner_conn.cursor() as cur:
        # B tesisinde HERHANGI bir kullanici: `world` orada yalniz
        # yonetici aciyor, `security` YOK — rol sabitlemek testi
        # kurulum ayrintisina bagimli kilardi.
        cur.execute(
            "SELECT id FROM app_user WHERE tenant_id=%s LIMIT 1", (world["b"],))
        kisi_b = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO vardiya_plani (tenant_id, shift_id, tarih, user_id, "
            "baslangic_saat, bitis_saat) VALUES (%s, NULL, %s, %s, '08:00','16:00')",
            (world["b"], BUGUN, kisi_b))
    owner_conn.commit()
    try:
        d = _cizelge(client, h, gun=1)
        assert all(k["user_id"] != str(kisi_b) for k in d["personel"])
    finally:
        with owner_conn.cursor() as cur:
            cur.execute("DELETE FROM vardiya_plani WHERE tenant_id=%s", (world["b"],))
        owner_conn.commit()
