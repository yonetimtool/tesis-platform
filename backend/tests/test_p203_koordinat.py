"""(P203 §1) KOORDINAT DOGRULAMASI — 500 bir daha cikmasin.

===========================================================================
OLCULEN KUSUR
===========================================================================
`PATCH /checkpoints/{id}` koordinat girilince **500** donuyordu. Zincir
uctu:

  1. Panel `sayiCoz` ile ayristiriyordu — o bir PARA ayristiricisidir ve
     noktadan sonra 2'den fazla basamak varsa noktayi BINLIK AYRACI
     sayip SILER: "41.008238" -> 41008238 (istemcide olculdu).
  2. Sunucu bu sayiyi DOGRULAMADAN kabul ediyordu (`float`, sinir yok).
  3. Sutun `Numeric(9, 6)` — uc tam basamak sigar. 41008238 TASTI,
     psycopg `NumericValueOutOfRange` atti, yakalanmadi -> 500.

Panel de duzeltildi (koordinat para degildir), AMA BU DOSYA SUNUCUYU
KILITLER: istemciye guvenmek, ayni 500'u bir sonraki istemcide (mobil,
entegrasyon, curl) yeniden uretmek olurdu.
"""
from __future__ import annotations

import pytest


def _giris(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


import uuid


@pytest.fixture
def nokta(client, world):
    """(basliklar, checkpoint_id, patch_fonksiyonu)."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/checkpoints", headers=h, json={
        "ad": "P203 Kapi", "nfc_tag_uid": f"TAG-{uuid.uuid4().hex[:8]}"})
    assert r.status_code == 201, r.text
    cid = r.json()["id"]

    def yaz(govde):
        return client.patch(f"/checkpoints/{cid}", headers=h, json=govde)

    return yaz


# ============================ 500 YOK ===================================== #

def test_TASAN_KOORDINAT_500_DEGIL_422(nokta):
    """Kusurun KENDISI. Bu deger tam olarak panelin urettigi seydi."""
    r = nokta({"gps_lat": 41008238.0, "gps_lng": 28978359.0})
    assert r.status_code == 422, r.text


@pytest.mark.parametrize("lat,lng", [
    (41008238.0, 28978359.0),   # panelin urettigi deger — kusurun kendisi
    (1234.5, 5678.9),
    (91.0, 0.0),                # enlem sinirinin 1 disi
    (-91.0, 0.0),
    (0.0, 181.0),               # boylam sinirinin 1 disi
    (0.0, -181.0),
    (90.000001, 0.0),           # sinirin KILDAN disi
])
def test_ARALIK_DISI_REDDEDILIR(nokta, lat, lng):
    r = nokta({"gps_lat": lat, "gps_lng": lng})
    assert r.status_code == 422, f"{lat},{lng} -> {r.status_code} {r.text}"


@pytest.mark.parametrize("lat,lng", [
    (41.008238, 28.978359),     # Istanbul
    (90.0, 180.0),              # SINIRIN KENDISI kabul edilir
    (-90.0, -180.0),
    (0.0, 0.0),
    (41.0082376, 28.9783589),   # 7 ondalik — sutun yuvarlar, hata YOK
])
def test_GECERLI_KOORDINAT_KABUL(nokta, lat, lng):
    r = nokta({"gps_lat": lat, "gps_lng": lng})
    assert r.status_code == 200, f"{lat},{lng} -> {r.status_code} {r.text}"


def test_NULL_koordinat_SILME_niyetidir(nokta):
    """Bos birakmak hata DEGIL: kullanici koordinati kaldirabilmeli."""
    assert nokta({"gps_lat": None, "gps_lng": None}).status_code == 200


def test_METIN_koordinat_422(nokta):
    r = nokta({"gps_lat": "abc", "gps_lng": "def"})
    assert r.status_code == 422, r.text


def test_OLUSTURMADA_da_dogrulanir(client, world):
    """PATCH ve POST AYNI semayi paylasmali; yalniz birini korumak,
    ayni 500'u oteki uctan uretmek olurdu."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/checkpoints", headers=h, json={
        "ad": "Tasan", "nfc_tag_uid": "TAG-TASAN", "gps_lat": 1234.5, "gps_lng": 0.0})
    assert r.status_code == 422, r.text


# ==================== AYNI KALIP BASKA UCLARDA ============================ #

def test_TARAMA_gps_alani_olan_TUM_semalar_ARALIK_TASIR():
    """(P203 §1) Kalibi TEK TEK degil TOPTAN kilitler.

    `gps_lat` alani olan yeni bir sema eklenirse ve aralik verilmezse bu
    test duser. Alan alan test yazmak, bir sonraki semada yine
    unutulmasi demekti — kusurun kendisi zaten "kural vardi, GPS
    alanlarinda uygulanmamisti"ydi (`konum_lat` aralik tasiyordu).
    """
    import inspect
    import json

    from pydantic import BaseModel

    from app import schemas

    def _sinirli(sema: dict) -> bool:
        """Alanin semasinda alt VE ust sinir var mi.

        JSON SEMASINDAN okunur, `model_fields` metadata'sindan DEGIL:
        `Enlem | None` gibi bir birlesikte kisit UNION UYESININ icine
        iner ve metadata BOS gorunur — ilk yazimda tam bu yanilgiya
        dusuldu ve tarama saglam alanlari "kusurlu" saydi. Duz metin
        aramasi bu ic ice yapiyi kendiliginden gezer.
        """
        ham = json.dumps(sema)
        return '"minimum"' in ham and '"maximum"' in ham

    kusurlu: list[str] = []
    for ad, nesne in inspect.getmembers(schemas, inspect.isclass):
        if not issubclass(nesne, BaseModel) or nesne is BaseModel:
            continue
        try:
            sema = nesne.model_json_schema()
        except Exception:  # noqa: BLE001 — cozulemeyen sema taramayi kirmasin
            continue
        for alan_adi, alan_sema in (sema.get("properties") or {}).items():
            if not any(
                p in alan_adi
                for p in ("gps_lat", "gps_lng", "konum_lat", "konum_lon")
            ):
                continue
            if not _sinirli(alan_sema):
                kusurlu.append(f"{ad}.{alan_adi}")
    assert not kusurlu, (
        "aralik dogrulamasi TASIMAYAN koordinat alani: " + ", ".join(kusurlu)
        + ". Aralik yoksa tasan bir deger sutunda `Numeric(9,6)` tasmasi "
        "yapar ve 500 doner (P203 §1'de olculdu)."
    )
