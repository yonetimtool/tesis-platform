"""(P232) TEK MODALDA COK GRUPLU VARDIYA — "pazartesi gunduz, sali-carsamba gece".

===========================================================================
OLCUM ONCE: UCUN COGU ZATEN VARDI
===========================================================================
`POST /vardiya-plani/kalip-uygula` (P207) su an bile sunlari yapiyor:
  * `gunler: list[date]`     -> keyfi (bitisik olmayan) gun secimi
  * `dilimler`               -> gunu birden cok vardiyaya bolme
  * `atamalar`               -> hangi dilime kim
  * `kuru: bool`             -> ONIZLEME (ayri uc DEGIL, ayni kod yolu)
  * `cakisanlari_atla`       -> P205 kurali: sessizce atlama yok
  * `parti_id`               -> P207 geri alma
  * `rotasyon: haftalik`     -> haftalik kaydirma

EKSIK OLAN TEK SEY: bir istekte AYNI dilimler TUM gunlere uygulaniyordu.
"Pazartesi gunduz, sali-carsamba gece" icin modali UC KEZ acmak ve UC
AYRI PARTI uretmek gerekiyordu — uc onizleme, uc catisma kontrolu ve
geri alirken UC AYRI ISTEK.

Bu dosya `gruplar` alanini kilitler: TEK istek, TEK parti, TEK onizleme.
"""
from __future__ import annotations

import uuid
from datetime import date, timedelta

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


@pytest.fixture
def kisi(client, yon):
    v = client.get("/users?limit=1000&role=security", headers=yon).json()["items"]
    if not v:
        pytest.skip("guvenlik personeli yok")
    return v[0]["id"]


GUNDUZ = {"ad": "Gunduz", "baslangic": "08:00", "bitis": "16:00"}
GECE = {"ad": "Gece", "baslangic": "22:00", "bitis": "06:00"}


def _gun(n: int) -> str:
    return (date.today() + timedelta(days=400 + n)).isoformat()


def _uygula(client, yon, gruplar, **k):
    govde = {"gruplar": gruplar, "rotasyon": "yok"}
    govde.update(k)
    return client.post("/vardiya-plani/kalip-uygula", headers=yon, json=govde)


# ==================================================================== #
# 1. ASIL ISTEK
# ==================================================================== #

def test_PAZARTESI_GUNDUZ_SALI_CARSAMBA_GECE_TEK_ISTEKTE(client, yon, kisi):
    """Istegin birebir kendisi."""
    r = _uygula(client, yon, [
        {"gunler": [_gun(0)], "dilimler": [GUNDUZ], "atamalar": {"0": [kisi]}},
        {"gunler": [_gun(1), _gun(2)], "dilimler": [GECE],
         "atamalar": {"0": [kisi]}},
    ])
    assert r.status_code == 200, r.text
    v = r.json()
    assert v["uygulandi"] is True, v
    assert v["eklenen"] == 3, v
    saatler = {(s["tarih"], s["baslangic"]) for s in v["satirlar"]}
    assert (_gun(0), "08:00:00") in saatler, saatler
    assert (_gun(1), "22:00:00") in saatler, saatler
    assert (_gun(2), "22:00:00") in saatler, saatler


def test_TEK_PARTI_HEPSINI_GERI_ALIR(client, yon, kisi):
    """GRUPLAR AYRI AYRI YAZILSAYDI geri alma birden cok istek olurdu —
    kullanici acisindan tek karar, sistemde birden cok iz."""
    r = _uygula(client, yon, [
        {"gunler": [_gun(10)], "dilimler": [GUNDUZ], "atamalar": {"0": [kisi]}},
        {"gunler": [_gun(11)], "dilimler": [GECE], "atamalar": {"0": [kisi]}},
    ])
    assert r.status_code == 200, r.text
    parti = r.json()["parti_id"]
    assert parti, r.json()
    g = client.post(f"/vardiya-plani/parti/{parti}/geri-al", headers=yon)
    assert g.status_code == 200, g.text
    assert g.json()["iptal_edilen"] == 2, g.json()


def test_ONIZLEME_HICBIR_SEY_YAZMAZ(client, yon, kisi):
    """`kuru=true` AYNI kod yolundan gecer: onizlemede baska, kaydetmede
    baska sonuc cikamaz."""
    gruplar = [
        {"gunler": [_gun(20), _gun(21)], "dilimler": [GUNDUZ],
         "atamalar": {"0": [kisi]}},
        {"gunler": [_gun(22)], "dilimler": [GECE], "atamalar": {"0": [kisi]}},
    ]
    kuru = _uygula(client, yon, gruplar, kuru=True)
    assert kuru.status_code == 200, kuru.text
    assert kuru.json()["uygulandi"] is False
    assert kuru.json()["eklenecek"] == 3, kuru.json()

    # Gercekten yazilmamis: ayni istek YAZARKEN de 3 uretmeli.
    gercek = _uygula(client, yon, gruplar)
    assert gercek.json()["eklenen"] == 3, gercek.json()


# ==================================================================== #
# 2. BOZULMAYACAKLAR
# ==================================================================== #

def test_GUN_ASIRI_VARDIYA_KORUNDU(client, yon, kisi):
    """(P205) 22:00-06:00 ERTESI GUNE tasar; ardisik iki gece cakisma
    SAYILMAZ."""
    r = _uygula(client, yon, [
        {"gunler": [_gun(30), _gun(31)], "dilimler": [GECE],
         "atamalar": {"0": [kisi]}},
    ])
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 2, r.json()


def test_CAKISMA_SESSIZCE_ATLANMAZ(client, yon, kisi):
    """(P205) Cakisma varsa HICBIR SEY yazilmaz ve satir satir soylenir."""
    ilk = _uygula(client, yon, [
        {"gunler": [_gun(40)], "dilimler": [GUNDUZ], "atamalar": {"0": [kisi]}},
    ])
    assert ilk.json()["eklenen"] == 1, ilk.json()

    ikinci = _uygula(client, yon, [
        {"gunler": [_gun(40)], "dilimler": [
            {"ad": "Ogle", "baslangic": "12:00", "bitis": "20:00"}],
         "atamalar": {"0": [kisi]}},
        {"gunler": [_gun(41)], "dilimler": [GECE], "atamalar": {"0": [kisi]}},
    ])
    assert ikinci.status_code == 200, ikinci.text
    v = ikinci.json()
    assert v["uygulandi"] is False, v
    assert v["eklenen"] == 0, "cakisma varken KISMEN yazildi"
    assert v["cakisan"] >= 1, v


def test_CAKISANLARI_ATLA_YALNIZ_TEMIZ_OLANI_YAZAR(client, yon, kisi):
    _uygula(client, yon, [
        {"gunler": [_gun(50)], "dilimler": [GUNDUZ], "atamalar": {"0": [kisi]}},
    ])
    r = _uygula(client, yon, [
        {"gunler": [_gun(50)], "dilimler": [
            {"ad": "Ogle", "baslangic": "12:00", "bitis": "20:00"}],
         "atamalar": {"0": [kisi]}},
        {"gunler": [_gun(51)], "dilimler": [GECE], "atamalar": {"0": [kisi]}},
    ], cakisanlari_atla=True)
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 1, r.json()


# ==================================================================== #
# 3. ESKI BICIM KIRILMADI
# ==================================================================== #

def test_TEKIL_BICIM_AYNEN_CALISIR(client, yon, kisi):
    """Yayindaki istemciler tekil bicimi gonderiyor."""
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "gunler": [_gun(60), _gun(61)],
        "dilimler": [GUNDUZ],
        "atamalar": {"0": [kisi]},
    })
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 2, r.json()


def test_NE_GUNLER_NE_GRUPLAR_REDDEDILIR(client, yon, kisi):
    r = client.post("/vardiya-plani/kalip-uygula", headers=yon, json={
        "dilimler": [GUNDUZ], "atamalar": {"0": [kisi]}})
    assert r.status_code == 422, r.text


# ==================================================================== #
# 4. (P231) AMIR KAPSAMI COK GRUPLU ISTEKTE DE GECERLI
# ==================================================================== #

def test_AMIR_COK_GRUPLU_ISTEKLE_DE_KAPSAM_DISINA_CIKAMAZ(client, world, yon):
    """Yeni bir giris bicimi, ESKI bir kapiyi atlamanin yolu olmamali."""
    amir = _h(client, world, "amir_a")
    t = client.get("/users?limit=1000&role=tesis_gorevlisi", headers=yon).json()
    if not t["items"]:
        pytest.skip("tesis gorevlisi yok")
    r = client.post("/vardiya-plani/kalip-uygula", headers=amir, json={
        "gruplar": [{
            "gunler": [_gun(70)], "dilimler": [GECE],
            "atamalar": {"0": [t["items"][0]["id"]]},
        }],
    })
    assert r.status_code == 403, r.text


# ==================================================================== #
# 5. DUZENLEME: "yalniz bu gunu" / "tum seriyi"
# ==================================================================== #

def _seri_kur(client, yon, kisi, ofset: int):
    r = _uygula(client, yon, [
        {"gunler": [_gun(ofset), _gun(ofset + 1), _gun(ofset + 2)],
         "dilimler": [GUNDUZ], "atamalar": {"0": [kisi]}},
    ])
    assert r.status_code == 200 and r.json()["eklenen"] == 3, r.text
    parti = r.json()["parti_id"]
    cizelge = client.get(
        f"/vardiya-plani/cizelge?baslangic={_gun(ofset)}&gun=3", headers=yon)
    assert cizelge.status_code == 200, cizelge.text
    bloklar = [b for k in cizelge.json()["personel"] for b in k["bloklar"]]
    return parti, bloklar


def test_TEK_KAPSAM_YALNIZ_O_GUNU_DEGISTIRIR(client, yon, kisi):
    """VARSAYILAN `tek` VE BU BILINCLI: tek satiri duzeltmek en sik
    yapilan is; varsayilani `seri` yapmak kullanicinin BEKLEMEDIGI bir
    toplu degisiklik uretirdi."""
    _, bloklar = _seri_kur(client, yon, kisi, 100)
    hedef = bloklar[0]
    r = client.patch(f"/vardiya-plani/{hedef['plan_id']}", headers=yon,
                     json={"baslangic_saat": "09:00"})
    assert r.status_code == 200, r.text

    cizelge = client.get(
        f"/vardiya-plani/cizelge?baslangic={_gun(100)}&gun=3", headers=yon)
    saatler = sorted(
        b["baslar"][11:16] for k in cizelge.json()["personel"]
        for b in k["bloklar"])
    assert saatler.count("09:00") == 1, saatler
    assert saatler.count("08:00") == 2, saatler


def test_SERI_KAPSAMI_TUM_PARTIYI_DEGISTIRIR(client, yon, kisi):
    _, bloklar = _seri_kur(client, yon, kisi, 110)
    hedef = bloklar[0]
    r = client.patch(f"/vardiya-plani/{hedef['plan_id']}", headers=yon,
                     json={"baslangic_saat": "10:00", "kapsam": "seri"})
    assert r.status_code == 200, r.text

    cizelge = client.get(
        f"/vardiya-plani/cizelge?baslangic={_gun(110)}&gun=3", headers=yon)
    saatler = sorted(
        b["baslar"][11:16] for k in cizelge.json()["personel"]
        for b in k["bloklar"])
    assert saatler == ["10:00", "10:00", "10:00"], saatler


def test_SERIDE_TARIH_DEGISTIRILEMEZ(client, yon, kisi):
    """SERT KURAL: serideki her satirin KENDI tarihi var; hepsini tek
    tarihe cekmek otuz gunluk plani TEK GUNE YIGMAK olurdu."""
    _, bloklar = _seri_kur(client, yon, kisi, 120)
    r = client.patch(f"/vardiya-plani/{bloklar[0]['plan_id']}", headers=yon,
                     json={"tarih": _gun(130), "kapsam": "seri"})
    assert r.status_code == 422, r.text


def test_PARTISI_OLMAYAN_SATIRDA_SERI_REDDEDILIR(client, yon, kisi, owner_conn):
    """Sessizce "tek" gibi davranmak, kullaniciya yaptigini sandigi seyi
    YAPMAMIS olmak olurdu.

    (E2E 2026-09) Toplu ekleme artik PARTI tasiyor (geri alinabilsin);
    partisiz satir eski/tekil kayittir — burada elle partisiz yapilir."""
    g = _gun(140)
    r = client.post("/vardiya-plani/toplu", headers=yon, json={
        "user_id": kisi, "baslangic_tarih": g, "bitis_tarih": g,
        "baslangic_saat": "08:00", "bitis_saat": "16:00"})
    assert r.status_code == 200 and r.json()["eklenen"] == 1, r.text
    cizelge = client.get(
        f"/vardiya-plani/cizelge?baslangic={g}&gun=1", headers=yon).json()
    pid = [b for k in cizelge["personel"] for b in k["bloklar"]][0]["plan_id"]
    with owner_conn.cursor() as cur:
        cur.execute("UPDATE vardiya_plani SET parti_id = NULL WHERE id = %s", (pid,))
    d = client.patch(f"/vardiya-plani/{pid}", headers=yon,
                     json={"baslangic_saat": "09:00", "kapsam": "seri"})
    assert d.status_code == 422, d.text


def test_KAPSAM_DENETIME_YAZILIR(client, yon, kisi, owner_conn):
    """"Otuz vardiyam neden degisti" sorusunun yaniti denetimde
    aranir."""
    _, bloklar = _seri_kur(client, yon, kisi, 150)
    client.patch(f"/vardiya-plani/{bloklar[0]['plan_id']}", headers=yon,
                 json={"baslangic_saat": "11:00", "kapsam": "seri"})
    satir = owner_conn.execute(
        "SELECT meta FROM audit_log WHERE resource_id = %s "
        "AND action = 'vardiya_plan_update' ORDER BY ts DESC LIMIT 1",
        (bloklar[0]["plan_id"],)).fetchone()
    assert satir is not None, "guncelleme denetime yazilmadi"
    assert "seri" in str(satir[0]), satir[0]
