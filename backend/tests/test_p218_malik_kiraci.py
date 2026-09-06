"""(P218) MALIK / KIRACI AYRIMI — UCTAN UCA.

===========================================================================
NE COZULDU
===========================================================================
Kat Mulkiyeti Kanunu md. 20 gider sorumlulugunu IKI AYRI gercege
baglar: isletme gideri KULLANANIN, bakim/onarim gideri MALIKIN.

Model bugune kadar yalnizca `rol_tipi` tasiyordu ve UC DURUMDAN BIRINI
temsil edemiyordu:
  1. Malik oturmuyor (kiraya vermis)  -> edilebiliyordu
  2. Kiraci oturuyor                  -> edilebiliyordu
  3. MALIK OTURUYOR                   -> EDILEMIYORDU (olculdu: ayni
     kisi ayni daireye ikinci rolle baglanamiyor, 409)

`unit_resident.oturuyor` (goc 0109) MULKIYET ile KULLANIMI ayirdi.

Bu dosya UC DURUMU DA gercek uclarla surer; cekirdek (saf fonksiyon)
ayrica `test_borclandirma_cekirdek.py`de olculuyor.
"""
from __future__ import annotations

import uuid

import pytest


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _daire(client, h) -> str:
    r = client.post("/units", headers=h, json={
        "no": f"P218-{uuid.uuid4().hex[:6]}", "blok": "P", "aktif": True})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _kisi(client, h, ad: str) -> str:
    r = client.post("/users", headers=h, json={
        "ad": ad, "email": f"p218-{uuid.uuid4().hex[:10]}@ornek.com",
        "role": "resident", "password": "Parola123!"})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _tanim(client, h, kural: str) -> str:
    r = client.post("/gelir-gider-tanimlari", headers=h, json={
        "ad": f"P218 {kural} {uuid.uuid4().hex[:5]}", "tip": "gider",
        "hedef_kurali": kural})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _hedef(client, h, unit_id: str, tanim_id: str, donem: str) -> str | None:
    r = client.post("/dues/assessments", headers=h, json={
        "unit_id": unit_id, "donem": donem, "tutar_kurus": 1234,
        "gelir_gider_tanim_id": tanim_id})
    assert r.status_code in (200, 201), r.text
    return r.json()["created"][0]["hedef_user_id"]


@pytest.fixture
def yon(client, world):
    return _h(client, world["slug_a"], world["yonetici_a"])


def _donem() -> str:
    return f"20{uuid.uuid4().int % 80 + 19}-{uuid.uuid4().int % 12 + 1:02d}"


# ==================== UC DURUM ========================================== #

def test_DURUM1_malik_oturmuyor_kiraci_oturuyor(client, yon):
    """Isletme gideri KIRACIYA, bakim gideri MALIGE."""
    u = _daire(client, yon)
    m, k = _kisi(client, yon, "Malik"), _kisi(client, yon, "Kiraci")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": m, "rol_tipi": "malik", "oturuyor": False})
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": k, "rol_tipi": "kiraci"})

    assert _hedef(client, yon, u, _tanim(client, yon, "kiraci_oncelikli"), _donem()) == k
    assert _hedef(client, yon, u, _tanim(client, yon, "malik"), _donem()) == m


def test_DURUM3_MALIK_OTURUYOR_her_iki_giderden_sorumlu(client, yon):
    """ESKIDEN TEMSIL EDILEMEYEN DURUM.

    Ayni kisi hem malik hem kiraci olarak baglanamiyordu (409); yonetici
    ya `malik` yazip oturdugu bilgisini kaybediyor ya `kiraci` yazip
    mulkiyeti yanlis gosteriyordu.
    """
    u = _daire(client, yon)
    mo = _kisi(client, yon, "Malik Oturan")
    r = client.post(f"/units/{u}/residents", headers=yon,
                    json={"user_id": mo, "rol_tipi": "malik", "oturuyor": True})
    assert r.status_code in (200, 201), r.text
    assert r.json()["oturuyor"] is True

    # Kullanan kurali ONA yazar (oturuyor), malik kurali da ONA (malik).
    assert _hedef(client, yon, u, _tanim(client, yon, "kiraci_oncelikli"), _donem()) == mo
    assert _hedef(client, yon, u, _tanim(client, yon, "malik"), _donem()) == mo


def test_OTURMAYAN_MALIK_isletme_giderini_ALIR_ama_bu_SON_CAREDIR(client, yon):
    """Dairede oturan kimse yoksa isletme gideri yine malige yazilir —
    bos daire de gider uretir ve borcun sahipsiz kalmasi daha kotudur."""
    u = _daire(client, yon)
    m = _kisi(client, yon, "Yalniz Malik")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": m, "rol_tipi": "malik", "oturuyor": False})
    assert _hedef(client, yon, u, _tanim(client, yon, "kiraci_oncelikli"), _donem()) == m


# ==================== `oturuyor` VARSAYILANI ============================ #

def test_KIRACIYA_oturuyor_SORULMAZ_sunucu_True_varsayar(client, yon):
    """Kiraci tanimi geregi oturur; ayrica sormak yoneticiye bilgi
    degeri olmayan bir soru sormakti."""
    u = _daire(client, yon)
    k = _kisi(client, yon, "Kiraci")
    r = client.post(f"/units/{u}/residents", headers=yon,
                    json={"user_id": k, "rol_tipi": "kiraci"})
    assert r.json()["oturuyor"] is True


def test_MALIGE_oturuyor_SORULMAZSA_False(client, yon):
    """"Bilinmiyor"u "oturuyor" saymak, isletme giderini oturmayan
    malige yazardi."""
    u = _daire(client, yon)
    m = _kisi(client, yon, "Malik")
    r = client.post(f"/units/{u}/residents", headers=yon,
                    json={"user_id": m, "rol_tipi": "malik"})
    assert r.json()["oturuyor"] is False


def test_ROLSUZ_bag_oturuyor_FALSE(client, yon):
    """Kullanici ekleme ekraninin (bugunku hâliyle) actigi bag."""
    u = _daire(client, yon)
    x = _kisi(client, yon, "Rolsuz")
    r = client.post(f"/units/{u}/residents", headers=yon, json={"user_id": x})
    assert r.json()["oturuyor"] is False


# ==================== SINIRLAR ========================================== #

def test_MALIK_OTURUYORKEN_KIRACI_da_eklenebilir(client, yon):
    """URUN KARARI: engellenmiyor. Malik bir odayi kiraya vermis
    olabilir; devir doneminde ikisi bir arada gorunebilir."""
    u = _daire(client, yon)
    mo, k = _kisi(client, yon, "Malik Oturan"), _kisi(client, yon, "Kiraci")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": mo, "rol_tipi": "malik", "oturuyor": True})
    r = client.post(f"/units/{u}/residents", headers=yon,
                    json={"user_id": k, "rol_tipi": "kiraci"})
    assert r.status_code in (200, 201), r.text


def test_LISTE_oturuyor_alanini_DONER(client, yon):
    u = _daire(client, yon)
    mo = _kisi(client, yon, "Malik Oturan")
    client.post(f"/units/{u}/residents", headers=yon,
                json={"user_id": mo, "rol_tipi": "malik", "oturuyor": True})
    r = client.get(f"/units/{u}/residents", headers=yon)
    assert r.status_code == 200, r.text
    kayit = [x for x in r.json() if x["user_id"] == mo][0]
    assert kayit["oturuyor"] is True
    assert kayit["rol_tipi"] == "malik"
