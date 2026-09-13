"""(P229 §2) VARDIYA — KEYFI GUN SECIMI.

Web'de (P207/P214) ay gorunumu, keyfi coklu secim, surukle-sec ve "tum
pazartesiler" zaten vardi; MOBILDE yalniz BITISIK ARALIK secilebiliyordu.
Bu dosya, iki yuzeyin ARTIK AYNI UCU kullandigini ve aralik kipinin
KIRILMADIGINI olcer.

NEDEN AYNI UC (`/vardiya-plani/toplu`), YENI BIR UC DEGIL: cakisma
denetimi, "hepsi ya da hicbiri" iki gecisi, azami gun siniri ve denetim
kaydi orada. Ikinci bir uc, P205'te cozulen "sessizce atlama" kusurunu
yeni ucta yeniden dogururdu.
"""
from __future__ import annotations

import datetime as dt

import pytest


@pytest.fixture
def yon(client, world):
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["yonetici_a"]["email"],
        "password": world["yonetici_a"]["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def personel(client, world):
    """Vardiya YAZILACAK kisi — fixture'in guvenlik gorevlisi.

    Personel LISTESINDEN alinmiyor: liste ucunun bicimi bu testin
    olctugu sey degil ve degisirse test KENDI kusuru olmadan duserdi.
    """
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["guard_a"]["email"],
        "password": world["guard_a"]["password"]})
    assert r.status_code == 200, r.text
    me = client.get("/me", headers={
        "Authorization": f"Bearer {r.json()['access_token']}"})
    assert me.status_code == 200, me.text
    return me.json()["id"]


def _g(n: int) -> str:
    """Bugunden n gun sonrasi — sabit tarih kullanmak, gecmis gun
    denetimlerine ve tatil takvimine takilirdi."""
    return (dt.date.today() + dt.timedelta(days=n)).isoformat()


def _istek(user_id, gunler=None, **k):
    govde = {
        "user_id": user_id,
        # ARALIK ALANLARI HER ZAMAN GONDERILIR: sozlesmede zorunlu
        # kaldilar cunku yayindaki istemciler onlari gonderiyor.
        "baslangic_tarih": _g(1),
        "bitis_tarih": _g(1),
        "baslangic_saat": "08:00",
        "bitis_saat": "16:00",
    }
    if gunler is not None:
        govde["gunler"] = gunler
    govde.update(k)
    return govde


# ==================================================================== #
# 1. KEYFI (BITISIK OLMAYAN) SECIM
# ==================================================================== #

def test_BITISIK_OLMAYAN_GUNLER_ICIN_VARDIYA_OLUSUR(client, yon, personel):
    """Isteğin ta kendisi: "ayin 3'u, 7'si ve 19'u"."""
    gunler = [_g(40), _g(44), _g(56)]
    r = client.post("/vardiya-plani/toplu", headers=yon,
                    json=_istek(personel, gunler))
    assert r.status_code == 200, r.text
    v = r.json()
    assert v["uygulandi"] is True, v
    assert v["eklenen"] == 3, v
    assert {x["tarih"] for x in v["gunler"]} == set(gunler), v


def test_ARADAKI_GUNLERE_VARDIYA_DUSMEZ(client, yon, personel):
    """ARALIK KIPINE DUSMEDIGININ KANITI.

    Bu test olmasaydi, sunucu `gunler`i gormeyip ilk ve son gun
    arasindaki HER GUNE vardiya yazsa bile ustteki test gecerdi
    (istenen uc gun de listede olurdu).
    """
    gunler = [_g(70), _g(76)]
    r = client.post("/vardiya-plani/toplu", headers=yon,
                    json=_istek(personel, gunler))
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 2, r.json()


def test_TEKRAR_EDEN_GUN_IKI_KEZ_YAZILMAZ(client, yon, personel):
    """Ayni gunu iki kez yazmak, kullanicinin GORMEDIGI bir cakisma
    uretirdi: cizelgede ust uste iki blok."""
    g = _g(90)
    r = client.post("/vardiya-plani/toplu", headers=yon,
                    json=_istek(personel, [g, g, g]))
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 1, r.json()


# ==================================================================== #
# 2. SINIRLAR
# ==================================================================== #

def test_BOS_GUN_LISTESI_REDDEDILIR(client, yon, personel):
    """Bos liste sessizce "hicbir sey yapma"ya donusmemeli: kullanici
    "ekle"ye basmis ve hicbir sey olmamis olurdu."""
    r = client.post("/vardiya-plani/toplu", headers=yon,
                    json=_istek(personel, []))
    assert r.status_code == 422, r.text
    assert r.json()["error"]["code"] == "validation_error"


def test_AZAMI_GUN_ASILAMAZ(client, yon, personel):
    r = client.post("/vardiya-plani/toplu", headers=yon,
                    json=_istek(personel, [_g(200 + i) for i in range(32)]))
    assert r.status_code == 422, r.text


def test_SEMA_SINIRI_ROUTER_SINIRIYLA_AYNI():
    """IKI YERDE AYNI SAYI — ayrisirsa sema 31'i gecen istegi keser ama
    hata metni router'in `vardiya_aralik_cok_uzun`u OLMAZDI."""
    from app.routers.vardiya_plani import AZAMI_GUN
    from app.schemas import AZAMI_VARDIYA_GUN
    assert AZAMI_VARDIYA_GUN == AZAMI_GUN


# ==================================================================== #
# 3. ESKI DAVRANIS KIRILMADI (P205 kurallari)
# ==================================================================== #

def test_GUNLER_VERILMEZSE_ARALIK_KIPI_AYNEN_CALISIR(client, yon, personel):
    """Yayindaki istemciler `gunler` gondermiyor."""
    govde = _istek(personel)
    govde["baslangic_tarih"] = _g(120)
    govde["bitis_tarih"] = _g(122)
    r = client.post("/vardiya-plani/toplu", headers=yon, json=govde)
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 3, r.json()


def test_CAKISMA_SESSIZCE_ATLANMAZ(client, yon, personel):
    """P205 kurali keyfi secimde de gecerli: cakisma varsa HICBIR SEY
    yazilmaz ve cakisan gunler ADLARIYLA doner."""
    g1, g2 = _g(150), _g(151)
    ilk = client.post("/vardiya-plani/toplu", headers=yon,
                      json=_istek(personel, [g1]))
    assert ilk.status_code == 200 and ilk.json()["uygulandi"], ilk.text

    ikinci = client.post("/vardiya-plani/toplu", headers=yon,
                         json=_istek(personel, [g1, g2]))
    assert ikinci.status_code == 200, ikinci.text
    v = ikinci.json()
    assert v["uygulandi"] is False, v
    assert v["eklenen"] == 0, "cakisma varken KISMEN yazilmis"
    assert v["cakisan"] == 1, v

    # Kullanici karar verince: yalniz cakismayan gun yazilir.
    ucuncu = client.post("/vardiya-plani/toplu", headers=yon,
                         json=_istek(personel, [g1, g2],
                                     cakisanlari_atla=True))
    assert ucuncu.status_code == 200, ucuncu.text
    assert ucuncu.json()["eklenen"] == 1, ucuncu.json()


def test_GUN_ASIRI_VARDIYA_KEYFI_SECIMDE_DE_DOGRU(client, yon, personel):
    """(P205) 22:00-06:00 ERTESI GUNE tasar. Keyfi secimde her gun ayri
    degerlendirilir; bitisik OLMAYAN iki gun secilirse birbirleriyle
    cakismamalilar (aralarinda gun var)."""
    r = client.post("/vardiya-plani/toplu", headers=yon,
                    json=_istek(personel, [_g(170), _g(175)],
                                baslangic_saat="22:00", bitis_saat="06:00"))
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 2, r.json()


def test_ARDISIK_GECE_VARDIYALARI_CAKISMA_SAYILMAZ(client, yon, personel):
    """ARDISIK iki gece vardiyasi (22:00-06:00) mesru bir duzendir:
    birinin bitisi otekinin baslangicidir, USTUSTE BINMEZ. Bunu cakisma
    saymak, gece ekibini hic planlayamamak demekti."""
    r = client.post("/vardiya-plani/toplu", headers=yon,
                    json=_istek(personel, [_g(180), _g(181)],
                                baslangic_saat="22:00", bitis_saat="06:00"))
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 2, r.json()
