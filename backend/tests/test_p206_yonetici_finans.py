"""(P206 §1) YONETICI KENDI TESISININ FINANSINI YONETEBILIR.

===========================================================================
OLCULEN KUSUR
===========================================================================
Rol matrisi taranarak cikarildi: ON ALTI finans ucu yoneticiye KAPALIYDI
(403). Yani yonetici kapida elden aldigi aidati SISTEME GIREMIYORDU;
gideri kaydedemiyor, kendi kaydettigi gideri onaylayamiyor, donem basi
toplu borclandirmayi yapamiyordu. Modul, onu kullanacak kisi icin fiilen
YOKTU.

Eski gerekce (P167): "tahakkuk borc yazmaktir, tahsilat PARA ALINDI
beyanidir". Ayrim yanlis yere cizilmisti — parayi alan kisi zaten
yonetici; platform admininin girmesi icin ONDAN duymasi gerekiyordu.

===========================================================================
BU DOSYA NEYI KILITLER
===========================================================================
  1. Yonetici on alti ucun HEPSINDE 403 ALMAZ (yetki kapisi acildi),
  2. DENETCI hepsinde 403 ALIR (salt okuma degismedi),
  3. SAKIN hepsinde 403 ALIR,
  4. TESIS IZOLASYONU: yonetici BASKA tesisin kasasina yazamaz.

403 ALMAMAK olculur, "200 doner" degil: govde dogrulama hatalari (422)
bu dosyanin konusu degil ve her ucun kendi testi zaten var. Kilit
YETKI KAPISINDADIR — sessizce daralirsa burasi kirmizi olur.
"""
from __future__ import annotations

import uuid

import pytest


def _headers(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon(client, world):
    return _headers(client, world["slug_a"], world["yonetici_a"])


@pytest.fixture
def kasa_id(client, world):
    adm = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/kasalar", headers=adm, json={
        "kod": f"P206{uuid.uuid4().hex[:4]}", "ad": "P206 Kasa",
        "acilis_bakiye_kurus": 0})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def _uclar(kasa_id: str) -> list[tuple[str, str, dict | None]]:
    """(metot, yol, govde) — P206'da yoneticiye ACILAN on alti uc."""
    donem = "2026-09"
    return [
        ("POST", "/finans/tahsilat", {
            "kasa_id": kasa_id, "tutar_kurus": 1000, "aciklama": "p206"}),
        ("POST", "/finans/tahsilat/toplu", {"kasa_id": kasa_id, "satirlar": []}),
        ("POST", "/finans/hareketler", {"kayitlar": [{
            "kasa_id": kasa_id, "tip": "gider", "tutar_kurus": 1000,
            "aciklama": "p206"}]}),
        ("POST", "/finans/virman", {
            "kaynak_kasa_id": kasa_id, "hedef_kasa_id": kasa_id,
            "tutar_kurus": 1000}),
        ("POST", "/finans/iade", {
            "hareket_id": str(uuid.uuid4()), "tutar_kurus": 1000}),
        ("POST", f"/finans/hareketler/{uuid.uuid4()}/onayla", {}),
        ("POST", f"/finans/hareketler/{uuid.uuid4()}/reddet", {}),
        ("POST", f"/finans/hareketler/{uuid.uuid4()}/iptal", {}),
        ("POST", "/finans/acilis", {
            "kasa_id": kasa_id, "tutar_kurus": 1000}),
        ("POST", "/finans/banka-eslestir", {"satirlar": []}),
        ("POST", "/dues/payments", {
            "unit_id": str(uuid.uuid4()), "tutar_kurus": 1000}),
        ("POST", "/borclandirma/toplu/onizleme", {
            "donem": donem, "tutar_kurus": 1000}),
        ("POST", "/borclandirma/toplu", {"donem": donem, "tutar_kurus": 1000}),
        ("POST", "/borclandirma/sayac", {"donem": donem, "okumalar": []}),
        ("POST", "/borclandirma/ice-aktarim", {"donem": donem, "satirlar": []}),
        ("PATCH", "/borclandirma/gecikme-ayari", {"aylik_oran_binde": 15}),
    ]


def _cagir(client, headers, metot, yol, govde):
    if metot == "POST":
        return client.post(yol, headers=headers, json=govde or {})
    return client.patch(yol, headers=headers, json=govde or {})


def test_YONETICI_finans_uclarinda_403_ALMAZ(client, world, yon, kasa_id):
    """Kabul kriteri 1. Govde hatasi (422) SORUN DEGIL — olculen sey
    YETKI KAPISI."""
    engellenen = []
    for metot, yol, govde in _uclar(kasa_id):
        r = _cagir(client, yon, metot, yol, govde)
        if r.status_code == 403:
            engellenen.append(f"{metot} {yol}")
    assert engellenen == [], f"yoneticiye HÂLÂ kapali: {engellenen}"


def test_DENETCI_finans_YAZMA_uclarinda_403_ALIR(client, world, kasa_id):
    """Kabul kriteri 4: denetci SALT OKUMA. Mali gozetim okumakla
    yapilir; yazma yetkisi gozetimin bagimsizligini bozardi."""
    h = _headers(client, world["slug_a"], world["denetci_a"])
    gecen = []
    for metot, yol, govde in _uclar(kasa_id):
        r = _cagir(client, h, metot, yol, govde)
        if r.status_code != 403:
            gecen.append(f"{metot} {yol} -> {r.status_code}")
    assert gecen == [], f"denetci YAZMA ucuna girdi: {gecen}"


def test_SAKIN_finans_uclarinda_403_ALIR(client, world, kasa_id):
    h = _headers(client, world["slug_a"], world["resident_a"])
    gecen = []
    for metot, yol, govde in _uclar(kasa_id):
        r = _cagir(client, h, metot, yol, govde)
        if r.status_code != 403:
            gecen.append(f"{metot} {yol} -> {r.status_code}")
    assert gecen == [], f"sakin finans ucuna girdi: {gecen}"


def test_YONETICI_BASKA_TESISIN_kasasina_YAZAMAZ(client, world, owner_conn):
    """Kabul kriteri: yetki genisledi, KAPSAM genislemedi.

    B tesisinde bir kasa acilir; A'nin yoneticisi o kasaya tahsilat
    yazmayi dener. RLS o satiri HIC gormedigi icin uc 422
    `invalid_reference` verir — 201 DEGIL.
    """
    with owner_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO kasa (tenant_id, kod, ad) VALUES (%s,%s,%s) RETURNING id",
            (world["b"], f"B{uuid.uuid4().hex[:4]}", "B Kasa"))
        b_kasa = cur.fetchone()[0]
    owner_conn.commit()
    try:
        h = _headers(client, world["slug_a"], world["yonetici_a"])
        r = client.post("/finans/tahsilat", headers=h, json={
            "kasa_id": str(b_kasa), "tutar_kurus": 1000, "aciklama": "izolasyon"})
        assert r.status_code == 422, r.text
        assert r.json()["error"]["code"] == "invalid_reference"
    finally:
        with owner_conn.cursor() as cur:
            cur.execute("DELETE FROM kasa WHERE id=%s", (b_kasa,))
        owner_conn.commit()
