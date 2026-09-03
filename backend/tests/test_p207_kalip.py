"""(P207 §1) AY BAZINDA TOPLU PLANLAMA — kalip, rotasyon, onizleme, geri alma.

===========================================================================
NE OLCULUYOR
===========================================================================
  1. KALIP tanimlanip TEKRAR KULLANILIYOR (gunu N vardiyaya bolme),
  2. SECILI GUNLERE uygulaniyor (aralik degil — "tum pazartesiler"
     gibi duzensiz secim olabilir),
  3. ONIZLEME kaydetmeden once KAC VARDIYA olusacagini soyluyor,
  4. CAKISMA SESSIZCE ATLANMIYOR (P205 kurali),
  5. HAFTALIK ROTASYON ekipleri dilimler arasinda kaydiriyor,
  6. TOPLU ISLEM GERI ALINABILIYOR (istegin KRITIK sarti),
  7. GUN ASIRI dilim (20:00-08:00) dogru kaydediliyor (P205 korundu),
  8. TESIS IZOLASYONU: baska tesisin personeli atanamiyor.
"""
from __future__ import annotations

import datetime as dt
import uuid

import pytest

from .test_p203_vardiya_plani import _giris, duzen  # noqa: F401

BUGUN = dt.date(2026, 9, 7)   # pazartesi

IKI_VARDIYA = [
    {"ad": "Gunduz", "baslangic": "08:00", "bitis": "20:00"},
    {"ad": "Gece", "baslangic": "20:00", "bitis": "08:00"},
]


@pytest.fixture
def yon(client, world):
    return _giris(client, world["slug_a"], world["yonetici_a"])


@pytest.fixture(autouse=True)
def _temiz(client, world, owner_conn):
    """Her test TEMIZ plan tablosuyla baslar: bu dosya ayni kisilere
    ayni gunlerde yaziyor ve artik satirlar testleri SIRA BAGIMLI
    yapardi."""
    yield
    with owner_conn.cursor() as cur:
        cur.execute("DELETE FROM vardiya_plani WHERE tenant_id=%s", (world["a"],))
        cur.execute("DELETE FROM vardiya_kalibi WHERE tenant_id=%s", (world["a"],))
    owner_conn.commit()


def _kalip(client, yon, ad=None, dilimler=None):
    r = client.post("/vardiya-plani/kaliplar", headers=yon, json={
        "ad": ad or f"K{uuid.uuid4().hex[:6]}",
        "dilimler": dilimler or IKI_VARDIYA,
    })
    assert r.status_code == 201, r.text
    return r.json()


def _uygula(client, yon, duzen, **kw):
    govde = {
        "gunler": [BUGUN.isoformat()],
        "atamalar": {"0": [duzen["kisi"]]},
        **kw,
    }
    return client.post("/vardiya-plani/kalip-uygula", headers=yon, json=govde)


# ============================ 1) KALIP ==================================== #

def test_KALIP_tanimlanir_ve_TEKRAR_KULLANILIR(client, world, yon, duzen):
    k = _kalip(client, yon, ad="P207 Iki Vardiya")
    assert [d["ad"] for d in k["dilimler"]] == ["Gunduz", "Gece"]

    liste = client.get("/vardiya-plani/kaliplar", headers=yon)
    assert liste.status_code == 200
    assert any(x["id"] == k["id"] for x in liste.json()["items"])

    # AYNI AD IKI KEZ: 409. Ayni adla iki kalip, ay basinda "hangisiydi"
    # sorusunu yanitlanamaz yapardi.
    r = client.post("/vardiya-plani/kaliplar", headers=yon, json={
        "ad": "P207 Iki Vardiya", "dilimler": IKI_VARDIYA})
    assert r.status_code == 409, r.text


def test_KALIPSIZ_da_uygulanabilir_TEK_SEFERLIK(client, world, yon, duzen):
    """Kalibi KAYDETMEDEN uygulamak mumkun: bir kerelik plan icin kalici
    tanim uretmek, tanim listesini sismanlatirdi."""
    r = _uygula(client, yon, duzen, dilimler=IKI_VARDIYA)
    assert r.status_code == 200, r.text
    assert r.json()["uygulandi"] is True


def test_IKISI_BIRDEN_verilirse_REDDEDILIR(client, world, yon, duzen):
    k = _kalip(client, yon)
    r = _uygula(client, yon, duzen, kalip_id=k["id"], dilimler=IKI_VARDIYA)
    assert r.status_code == 422, r.text


# ======================= 2) ONIZLEME + UYGULAMA =========================== #

def test_ONIZLEME_KAC_VARDIYA_olusacagini_soyler_ve_YAZMAZ(
    client, world, yon, duzen
):
    """Istegin acik sarti (kabul kriteri 4)."""
    k = _kalip(client, yon)
    gunler = [(BUGUN + dt.timedelta(days=i)).isoformat() for i in range(5)]
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": gunler,
        "atamalar": {"0": [duzen["kisi"]], "1": [duzen["kisi2"]]},
        "kuru": True,
    })
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["uygulandi"] is False
    # 5 gun x 2 dilim x 1 kisi = 10
    assert d["eklenecek"] == 10
    assert len(d["satirlar"]) == 10

    # HICBIR SEY YAZILMADI.
    c = client.get("/vardiya-plani/cizelge", headers=yon,
                   params={"baslangic": BUGUN.isoformat(), "gun": 7})
    assert all(not k2["bloklar"] for k2 in c.json()["personel"])


def test_UYGULAMA_gun_x_dilim_KADAR_satir_yazar(client, world, yon, duzen):
    k = _kalip(client, yon)
    gunler = [(BUGUN + dt.timedelta(days=i)).isoformat() for i in range(3)]
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": gunler,
        "atamalar": {"0": [duzen["kisi"]], "1": [duzen["kisi2"]]},
    })
    d = r.json()
    assert d["uygulandi"] is True and d["eklenen"] == 6
    assert d["parti_id"]

    c = client.get("/vardiya-plani/cizelge", headers=yon,
                   params={"baslangic": BUGUN.isoformat(), "gun": 3})
    kisi = next(x for x in c.json()["personel"] if x["user_id"] == duzen["kisi"])
    assert len(kisi["bloklar"]) == 3


def test_GUN_ASIRI_dilim_ERTESI_GUNE_tasar(client, world, yon, duzen):
    """P205'te cozulmustu; kalip yolunda da BOZULMAMALI."""
    k = _kalip(client, yon)
    client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": [BUGUN.isoformat()],
        "atamalar": {"1": [duzen["kisi2"]]},
    })
    c = client.get("/vardiya-plani/cizelge", headers=yon,
                   params={"baslangic": BUGUN.isoformat(), "gun": 1})
    blok = next(
        x for x in c.json()["personel"] if x["user_id"] == duzen["kisi2"]
    )["bloklar"][0]
    assert blok["baslar"].startswith("2026-09-07T20:00")
    assert blok["biter"].startswith("2026-09-08T08:00")
    assert blok["gece_asiyor"] is True


def test_DUZENSIZ_GUN_SECIMI_calisir(client, world, yon, duzen):
    """"Tum pazartesiler" gibi duzensiz secim: aralik gondermek bunu
    ANLATAMAZDI."""
    k = _kalip(client, yon)
    pazartesiler = [(BUGUN + dt.timedelta(weeks=i)).isoformat() for i in range(4)]
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": pazartesiler,
        "atamalar": {"0": [duzen["kisi"]]},
    })
    assert r.json()["eklenen"] == 4
    tarihler = {s["tarih"] for s in r.json()["satirlar"]}
    assert tarihler == set(pazartesiler)


# =========================== 3) CAKISMA =================================== #

def test_CAKISMA_SESSIZCE_ATLANMAZ(client, world, yon, duzen):
    """P205 kurali korundu (kabul kriteri 5)."""
    k = _kalip(client, yon)
    gunler = [BUGUN.isoformat(), (BUGUN + dt.timedelta(days=1)).isoformat()]
    # Ikinci gunun GUNDUZUNE cakisan bir vardiya koy.
    client.post("/vardiya-plani/toplu", headers=yon, json={
        "user_id": duzen["kisi"],
        "baslangic_tarih": (BUGUN + dt.timedelta(days=1)).isoformat(),
        "bitis_tarih": (BUGUN + dt.timedelta(days=1)).isoformat(),
        "baslangic_saat": "10:00", "bitis_saat": "14:00",
    })

    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": gunler,
        "atamalar": {"0": [duzen["kisi"]]},
    })
    d = r.json()
    assert d["uygulandi"] is False, "cakismaya ragmen yazildi"
    assert d["cakisan"] == 1
    cakisan = [s for s in d["satirlar"] if s["durum"] == "cakisma"]
    # HANGI GUN VE HANGI DILIM oldugu SOYLENIR.
    assert cakisan[0]["tarih"] == gunler[1]
    assert cakisan[0]["dilim"] == "Gunduz"

    # KULLANICI KARAR VERINCE: cakisan ATLANIR, otekiler yazilir.
    r2 = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": gunler,
        "atamalar": {"0": [duzen["kisi"]]},
        "cakisanlari_atla": True,
    })
    assert r2.json()["uygulandi"] is True
    assert r2.json()["eklenen"] == 1 and r2.json()["cakisan"] == 1


def test_ZATEN_VAR_olan_satir_CAKISMA_SAYILMAZ(client, world, yon, duzen):
    """Kalibi ikinci kez uygulamak (bir gun ekleyip yeniden calistirmak)
    mevcut satirlari HATA gibi gostermemeli."""
    k = _kalip(client, yon)
    govde = {
        "kalip_id": k["id"], "gunler": [BUGUN.isoformat()],
        "atamalar": {"0": [duzen["kisi"]]},
    }
    client.post("/vardiya-plani/kalip-uygula", headers=yon, json=govde)
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json=govde)
    d = r.json()
    assert d["cakisan"] == 0
    assert d["zaten_var"] == 1


# =========================== 4) ROTASYON ================================== #

def test_HAFTALIK_ROTASYON_ekipleri_kaydirir(client, world, yon, duzen):
    """Guvenlik sektorunun standart kalibi: A gunduz -> gece, B tersi."""
    k = _kalip(client, yon)
    gunler = [BUGUN.isoformat(), (BUGUN + dt.timedelta(days=7)).isoformat()]
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": gunler,
        "atamalar": {"0": [duzen["kisi"]], "1": [duzen["kisi2"]]},
        "rotasyon": "haftalik",
    })
    d = r.json()
    assert d["uygulandi"] is True and d["eklenen"] == 4

    def dilim(tarih, kisi):
        return next(
            s["dilim"] for s in d["satirlar"]
            if s["tarih"] == tarih and s["user_id"] == kisi
        )

    # ILK HAFTA: kisi gunduz, kisi2 gece. IKINCI HAFTA: TERSI.
    assert dilim(gunler[0], duzen["kisi"]) == "Gunduz"
    assert dilim(gunler[1], duzen["kisi"]) == "Gece"
    assert dilim(gunler[0], duzen["kisi2"]) == "Gece"
    assert dilim(gunler[1], duzen["kisi2"]) == "Gunduz"


def test_ROTASYON_YOKSA_atama_DEGISMEZ(client, world, yon, duzen):
    k = _kalip(client, yon)
    gunler = [BUGUN.isoformat(), (BUGUN + dt.timedelta(days=7)).isoformat()]
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": gunler,
        "atamalar": {"0": [duzen["kisi"]]},
    })
    assert {s["dilim"] for s in r.json()["satirlar"]} == {"Gunduz"}


# ========================== 5) GERI ALMA ================================== #

def test_TOPLU_ISLEM_GERI_ALINABILIR(client, world, yon, duzen):
    """Istegin KRITIK sarti: 30 gunluk yanlis plan tek istekle geri
    alinmali (kabul kriteri 6)."""
    k = _kalip(client, yon)
    gunler = [(BUGUN + dt.timedelta(days=i)).isoformat() for i in range(10)]
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": gunler,
        "atamalar": {"0": [duzen["kisi"]]},
    })
    parti = r.json()["parti_id"]
    assert r.json()["eklenen"] == 10

    g = client.post(f"/vardiya-plani/parti/{parti}/geri-al", headers=yon)
    assert g.status_code == 200, g.text
    assert g.json()["iptal_edilen"] == 10

    c = client.get("/vardiya-plani/cizelge", headers=yon,
                   params={"baslangic": BUGUN.isoformat(), "gun": 10})
    kisi = next(x for x in c.json()["personel"] if x["user_id"] == duzen["kisi"])
    assert kisi["bloklar"] == []

    # IKINCI KEZ GERI ALMA: 404 (iptal edilecek satir kalmadi).
    assert client.post(
        f"/vardiya-plani/parti/{parti}/geri-al", headers=yon
    ).status_code == 404


def test_GERI_ALMA_BASKA_PARTIYE_DOKUNMAZ(client, world, yon, duzen):
    """Iki yonetici ayni dakikada iki toplu islem yapabilir; zaman
    araligiyla geri almak otekinin satirlarini da iptal ederdi."""
    k = _kalip(client, yon)
    p1 = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": [BUGUN.isoformat()],
        "atamalar": {"0": [duzen["kisi"]]},
    }).json()
    p2 = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "kalip_id": k["id"], "gunler": [BUGUN.isoformat()],
        "atamalar": {"1": [duzen["kisi2"]]},
    }).json()
    assert p1["parti_id"] != p2["parti_id"]

    client.post(f"/vardiya-plani/parti/{p1['parti_id']}/geri-al", headers=yon)
    c = client.get("/vardiya-plani/cizelge", headers=yon,
                   params={"baslangic": BUGUN.isoformat(), "gun": 1})
    kalan = {x["user_id"] for x in c.json()["personel"] if x["bloklar"]}
    assert duzen["kisi2"] in kalan and duzen["kisi"] not in kalan


# ======================= 6) YETKI + IZOLASYON ============================= #

def test_SAHA_KALIP_UYGULAYAMAZ(client, world, duzen):
    h = _giris(client, world["slug_a"], world["guard_a"])
    r = client.post("/vardiya-plani/kalip-uygula", headers=h, json={
        "dilimler": IKI_VARDIYA, "gunler": [BUGUN.isoformat()],
        "atamalar": {"0": [duzen["kisi"]]},
    })
    assert r.status_code == 403, r.text


def test_BASKA_TESISIN_PERSONELI_ATANAMAZ(client, world, yon, owner_conn):
    """Yetki genisledi, KAPSAM genislemedi: B'nin kullanicisi RLS'te
    GORUNMEZ, yani "bulunamadi" olur."""
    with owner_conn.cursor() as cur:
        cur.execute("SELECT id FROM app_user WHERE tenant_id=%s LIMIT 1",
                    (world["b"],))
        b_kisi = cur.fetchone()[0]
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "dilimler": IKI_VARDIYA, "gunler": [BUGUN.isoformat()],
        "atamalar": {"0": [str(b_kisi)]},
    })
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "validation_error"
