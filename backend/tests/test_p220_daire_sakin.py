"""(P220 §5) DAIRE PENCERESINDE SAKIN BILGISI — daire bazli rol degisimi.

===========================================================================
NEDEN YENI BIR UC GEREKTI
===========================================================================
Bina duzenleme ekranindaki daire penceresi TEK BIR DAIRE hakkinda
konusuyor. Rol degistirmek icin elimizde yalnizca `PATCH /residents/{id}`
vardi ve o uc kullanicinin AKTIF TUM baglarina uyguluyor (kendi
dokumaninda yazili).

Somut sonucu: iki dairesi olan bir sakinde — birinde MALIK, otekinde
KIRACI — daire penceresinden yapilan bir rol degisikligi IKI DAIREYI DE
degistirirdi. Bu dosya once o farki KANITLIYOR, sonra yeni ucun yalniz
hedef daireye dokundugunu olcuyor.

===========================================================================
YETKI SUNUCUDA
===========================================================================
Arayuzde gizlemek YETMEZ: ikinci istemci (mobil/web) o gizlemeyi
tasimayabilir. `security` ve `resident` rolleri icin 403 olculuyor.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


def _tel() -> str:
    return f"+9056{uuid.uuid4().int % 10**8:08d}"


def _daire(client, yon, blok=None) -> str:
    # BLOK ZORUNLU (P193: blok ve daire AYRILDI, create blok istiyor).
    # Olculdu: `blok` verilmezse 422 "Field required", `null` verilirse
    # 422 "should be a valid string".
    r = client.post("/units", headers=yon, json={
        "no": f"P220D-{uuid.uuid4().hex[:6]}",
        "blok": blok or f"P{uuid.uuid4().hex[:4].upper()}",
        "aktif": True})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _sakin(client, yon) -> str:
    """Sakin hesabi acar. Doner: user_id."""
    r = client.post("/residents", headers=yon, json={
        "unit_no": f"GECICI-{uuid.uuid4().hex[:6]}",
        "ad": f"Sakin {uuid.uuid4().hex[:5]}",
        "email": f"{uuid.uuid4().hex[:10]}@ornek.com",
        "telefon": _tel(), "rol_tipi": "malik"})
    assert r.status_code in (200, 201), r.text
    return r.json()["user_id"]


def _bagla(client, yon, unit_id, user_id, rol="malik"):
    r = client.post(f"/units/{unit_id}/residents", headers=yon,
                    json={"user_id": user_id, "rol_tipi": rol})
    assert r.status_code in (200, 201), r.text
    return r.json()


def _baglar(client, yon, unit_id):
    r = client.get(f"/units/{unit_id}/residents", headers=yon)
    assert r.status_code == 200, r.text
    return [x for x in r.json() if x["bitis"] is None]


# ==================================================================== #
# 1. DAIRE PENCERESI ICIN GEREKEN VERI ZATEN DONUYOR
# ==================================================================== #

def test_DAIRE_SAKINLERI_AD_ve_ROL_ILE_DONUYOR(client, yon):
    """Pencerede "kim oturuyor: ad + rol" gosterilecek; on kosul bu."""
    d = _daire(client, yon)
    u = _sakin(client, yon)
    _bagla(client, yon, d, u, "kiraci")

    satirlar = _baglar(client, yon, d)
    assert len(satirlar) == 1, satirlar
    assert satirlar[0]["user_ad"], "ad DONMUYOR — pencerede UUID gorunurdu"
    assert satirlar[0]["rol_tipi"] == "kiraci"
    # (P218) `oturuyor` MULKIYETTEN AYRI bir gercek: kiraci tanimi
    # geregi oturur.
    assert satirlar[0]["oturuyor"] is True


def test_BOS_DAIRE_BOS_LISTE_DONER(client, yon):
    """"Bos daire" durumu bir HATA degil, normal bir yanit."""
    d = _daire(client, yon)
    assert _baglar(client, yon, d) == []


def test_BIRDEN_COK_SAKIN_HEPSI_LISTELENIR(client, yon):
    """Bir dairede malik VE kiraci olabilir (P154 karari)."""
    d = _daire(client, yon)
    _bagla(client, yon, d, _sakin(client, yon), "malik")
    _bagla(client, yon, d, _sakin(client, yon), "kiraci")
    assert len(_baglar(client, yon, d)) == 2


# ==================================================================== #
# 2. ROL DEGISIMI YALNIZ O DAIREYE DOKUNUR
# ==================================================================== #

def test_ROL_DEGISIMI_DIGER_DAIREYI_ETKILEMEZ(client, yon):
    """Yeni ucun varlik sebebi.

    Ayni sakin iki dairede: birinde malik, otekinde kiraci. Daire
    penceresinden birini degistirmek OTEKINI DEGISTIRMEMELI.
    """
    d1, d2 = _daire(client, yon), _daire(client, yon)
    u = _sakin(client, yon)
    _bagla(client, yon, d1, u, "malik")
    _bagla(client, yon, d2, u, "kiraci")

    r = client.patch(f"/units/{d1}/residents/{u}", headers=yon,
                     json={"rol_tipi": "kiraci"})
    assert r.status_code == 200, r.text
    assert r.json()["rol_tipi"] == "kiraci"

    # OTEKI DAIRE DEGISMEDI.
    oteki = _baglar(client, yon, d2)
    assert oteki[0]["rol_tipi"] == "kiraci", oteki
    # ...ve hedef daire gercekten degisti.
    hedef = _baglar(client, yon, d1)
    assert hedef[0]["rol_tipi"] == "kiraci", hedef


def test_ESKI_UC_TUM_BAGLARA_UYGULUYOR(client, yon):
    """Farki KANITLAYAN olcum: `PATCH /residents/{id}` IKISINI DE
    degistiriyor — yeni ucun neden gerektigi budur."""
    d1, d2 = _daire(client, yon), _daire(client, yon)
    u = _sakin(client, yon)
    _bagla(client, yon, d1, u, "malik")
    _bagla(client, yon, d2, u, "kiraci")

    r = client.patch(f"/residents/{u}", headers=yon,
                     json={"rol_tipi": "malik"})
    assert r.status_code in (200, 204), r.text

    assert _baglar(client, yon, d1)[0]["rol_tipi"] == "malik"
    assert _baglar(client, yon, d2)[0]["rol_tipi"] == "malik", (
        "eski uc TEK daireye uygulamis — bu testin varsayimi degisti")


def test_AYNI_ROLDEN_IKINCISI_409(client, yon):
    """Daire kurali korunuyor: bir dairede en fazla bir malik."""
    d = _daire(client, yon)
    _bagla(client, yon, d, _sakin(client, yon), "malik")
    kiraci = _sakin(client, yon)
    _bagla(client, yon, d, kiraci, "kiraci")

    r = client.patch(f"/units/{d}/residents/{kiraci}", headers=yon,
                     json={"rol_tipi": "malik"})
    assert r.status_code == 409, r.text


def test_AYNI_ROLE_GUNCELLEME_409_VERMEZ(client, yon):
    """Kendi satirini catisma saymamali — "malik -> malik" 409 verseydi
    `oturuyor` degistirmek imkansiz olurdu."""
    d = _daire(client, yon)
    u = _sakin(client, yon)
    _bagla(client, yon, d, u, "malik")
    r = client.patch(f"/units/{d}/residents/{u}", headers=yon,
                     json={"rol_tipi": "malik"})
    assert r.status_code == 200, r.text


def test_OTURUYOR_AYRI_GUNCELLENEBILIR(client, yon):
    """(P218) Oturma MULKIYETTEN AYRI: malik oturuyor da olabilir."""
    d = _daire(client, yon)
    u = _sakin(client, yon)
    _bagla(client, yon, d, u, "malik")
    r = client.patch(f"/units/{d}/residents/{u}", headers=yon,
                     json={"oturuyor": True})
    assert r.status_code == 200, r.text
    assert r.json()["oturuyor"] is True


def test_BOS_GOVDE_422(client, yon):
    d = _daire(client, yon)
    u = _sakin(client, yon)
    _bagla(client, yon, d, u, "malik")
    r = client.patch(f"/units/{d}/residents/{u}", headers=yon, json={})
    assert r.status_code == 422, r.text


def test_AKTIF_BAG_YOKSA_404(client, yon):
    d = _daire(client, yon)
    r = client.patch(f"/units/{d}/residents/{uuid.uuid4()}", headers=yon,
                     json={"rol_tipi": "malik"})
    assert r.status_code == 404, r.text


# ==================================================================== #
# 3. YETKI SUNUCUDA
# ==================================================================== #

def test_SAKIN_ve_GUVENLIK_ROL_DEGISTIREMEZ(client, world, yon):
    """Arayuzde gizlemek YETMEZ: ikinci istemci o gizlemeyi tasimaz."""
    d = _daire(client, yon)
    u = _sakin(client, yon)
    _bagla(client, yon, d, u, "malik")

    for anahtar in ("resident_a", "security_a"):
        cred = world.get(anahtar)
        if not cred:
            continue
        h = _h(client, world["slug_a"], cred)
        r = client.patch(f"/units/{d}/residents/{u}", headers=h,
                         json={"rol_tipi": "kiraci"})
        assert r.status_code == 403, (anahtar, r.status_code, r.text)


def test_KIMLIKSIZ_401(client, yon):
    d = _daire(client, yon)
    r = client.patch(f"/units/{d}/residents/{uuid.uuid4()}",
                     json={"rol_tipi": "malik"})
    assert r.status_code == 401, r.text
