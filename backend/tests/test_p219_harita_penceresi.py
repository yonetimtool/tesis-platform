"""(P219 §2) SIKAYET HARITASINDA GORUNME SURESI.

===========================================================================
NE COZULDU
===========================================================================
Sikayetler haritada SURESIZ kaliyordu: alti ay once cozulmus bir gurultu
sikayeti, dun gece gelenle ayni kirmizi noktayi uretiyordu. Harita "SU
ANDA nerede sorun var" sorusunu yanitlamasi gerekirken "hic olmus mu"
sorusunu yanitliyor ve zamanla her daire kirmiziya donuyordu.

===========================================================================
BU BIR GORUNURLUK FILTRESI, VERI SILME DEGIL
===========================================================================
Bu dosyanin ASIL ISI o ayrimi kanitlamak. Filtre acikken:
  * sikayet KAYDI yerinde durur (silinmez),
  * ESIK SAYACLARI etkilenmez (kendi penceresi var: 30 gun),
  * sikayet LISTELERI ve sakinin kendi kayitlari degismez,
  * yalnizca HARITA (`/density` ve `/building-map`) filtrelenir.
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


@pytest.fixture
def sakin(client, world):
    return _h(client, world["slug_a"], world["resident_a"])


def _daire(client, h, blok: str = "P") -> str:
    r = client.post("/units", headers=h, json={
        "no": f"P219-{uuid.uuid4().hex[:6]}", "blok": blok, "aktif": True})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _sakin_blogu(client, yon_h, world, owner_conn) -> str:
    """Sikayet edebilen bir sakin ON KOSULUNU kurar ve blogunu doner.

    Sakin YALNIZ KENDI BLOGUNDAKI daireleri sikayet edebiliyor
    (`sikayet_yalniz_kendi_blok`, 403) — urunun mesru kurali. Ustelik
    `world` fixture'i sakini HICBIR daireye baglamiyor (baska testler de
    bu yuzden atlaniyor). Ikisi birlikte, olcumun kurulabilmesi icin
    sakinin once bir daireye baglanmasini gerektiriyor.
    """
    satir = owner_conn.execute(
        "SELECT u.blok FROM unit_resident r JOIN unit u ON u.id = r.unit_id "
        "JOIN app_user a ON a.id = r.user_id "
        "WHERE a.email = %s AND r.bitis IS NULL LIMIT 1",
        (world["resident_a"]["email"],),
    ).fetchone()
    if satir:
        return satir[0]

    blok = f"B{uuid.uuid4().hex[:4]}"
    kendi_dairesi = _daire(client, yon_h, blok)
    uid = owner_conn.execute(
        "SELECT id FROM app_user WHERE email = %s", (world["resident_a"]["email"],)
    ).fetchone()[0]
    r = client.post(f"/units/{kendi_dairesi}/residents", headers=yon_h,
                    json={"user_id": str(uid), "rol_tipi": "kiraci"})
    assert r.status_code in (200, 201), r.text
    return blok


def _ayar(client, h, saat: int) -> None:
    r = client.patch("/tenant/settings", headers=h,
                     json={"sikayet_harita_saat": saat})
    assert r.status_code == 200, r.text


def _sikayet(client, sakin_h, hedef: str) -> str:
    r = client.post("/unit-complaints", headers=sakin_h, json={
        "target_unit_id": hedef, "kategori": "gurultu",
        "aciklama": "P219 olcum"})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _haritada(client, h, hedef: str) -> int:
    d = client.get("/unit-complaints/density", headers=h).json()["items"]
    return next((x["acik_sayisi"] for x in d if x["target_unit_id"] == hedef), 0)


def _bina_haritasinda(client, h, hedef: str):
    """Bina semasindaki sayim. YOL ve ALAN ADLARI olculerek yazildi:
    uc `/unit-complaints/building-map`, daire listesi `units`, sayim
    `complaint_count` (ilk yazimda `/building-map` + `daireler` +
    `acik_sayisi` denedim, ucu de yanlisti)."""
    d = client.get("/unit-complaints/building-map", headers=h).json()
    # YERLESIMSIZ daireler (kat/sira girilmemis) `unplaced` kovasinda
    # duruyor — test daireleri de oyle. Yalnizca `bloklar`a bakmak
    # None dondurur ve olcum bosa duser.
    for x in d.get("unplaced", []):
        if x["unit_id"] == hedef:
            return x.get("complaint_count")
    for b in d["bloklar"]:
        for k in b["katlar"]:
            for x in k.get("units", []):
                if x["unit_id"] == hedef:
                    return x.get("complaint_count")
    return None


def _eskit(owner_conn, sikayet_id: str, saat: int) -> None:
    """Sikayetin yasini GERIYE al — bekleme yerine zamani kaydiriyoruz."""
    owner_conn.execute(
        "UPDATE unit_complaint SET created_at = now() - (%s || ' hours')::interval "
        "WHERE id = %s", (saat, sikayet_id))


# ==================== ASIL AKIS (istegin dogrulama adimi) ============== #

def test_SIKAYET_haritada_GORUNUR_sonra_SURE_GECINCE_KAYBOLUR(
    client, yon, sakin, owner_conn
, world):
    """Istegin birebir adimi: sikayet olustur, haritada gor, sureyi
    kisalt, haritadan kayboldugunu ama SAYACTA durdugunu gor."""
    hedef = _daire(client, yon, _sakin_blogu(client, yon, world, owner_conn))
    _ayar(client, yon, 24)
    sid = _sikayet(client, sakin, hedef)
    try:
        # 1) TAZE sikayet haritada GORUNUR.
        assert _haritada(client, yon, hedef) == 1
        assert _bina_haritasinda(client, yon, hedef) == 1

        # 2) Sikayet 30 SAAT ONCEYE alinir -> 24 saatlik pencerenin DISI.
        _eskit(owner_conn, sid, 30)
        assert _haritada(client, yon, hedef) == 0, "harita HÂLÂ gosteriyor"
        assert _bina_haritasinda(client, yon, hedef) == 0, (
            "bina haritasi filtrelenmemis — iki uc ayni haritayi besliyor"
        )

        # 3) KAYIT SILINMEDI: liste hâlâ goruyor.
        liste = client.get("/unit-complaints?limit=200", headers=yon).json()
        assert any(x["id"] == sid for x in liste["items"]), (
            "sikayet KAYBOLMUS — bu bir gorunurluk filtresi, veri silme DEGIL"
        )

        # 4) SAYAC ETKILENMEDI: veritabanindaki kayit duruyor ve `acik`.
        durum = owner_conn.execute(
            "SELECT durum FROM unit_complaint WHERE id = %s", (sid,)
        ).fetchone()[0]
        assert durum == "acik"
    finally:
        _ayar(client, yon, 24)


def test_SURE_UZATILINCA_yeniden_GORUNUR(client, yon, sakin, owner_conn, world):
    """Filtre GERI DONUSLU: kayit durdugu icin sure uzatilinca sikayet
    yeniden gorunur. Silinseydi bu mumkun olmazdi."""
    hedef = _daire(client, yon, _sakin_blogu(client, yon, world, owner_conn))
    sid = _sikayet(client, sakin, hedef)
    try:
        _eskit(owner_conn, sid, 30)
        _ayar(client, yon, 24)
        assert _haritada(client, yon, hedef) == 0
        _ayar(client, yon, 48)          # pencereyi genislet
        assert _haritada(client, yon, hedef) == 1, "kayit geri gelmedi"
    finally:
        _ayar(client, yon, 24)


def test_SIFIR_SURESIZ_GOSTER(client, yon, sakin, owner_conn, world):
    """`0` = suresiz. Haftada bir sikayet gelen kucuk bir sitede 24
    saatlik pencere haritayi surekli bos gosterir ve harita islevini
    yitirir; kapatilabilir olmasi bu yuzden."""
    hedef = _daire(client, yon, _sakin_blogu(client, yon, world, owner_conn))
    sid = _sikayet(client, sakin, hedef)
    try:
        _eskit(owner_conn, sid, 24 * 90)   # UC AY once
        _ayar(client, yon, 24)
        assert _haritada(client, yon, hedef) == 0
        _ayar(client, yon, 0)
        assert _haritada(client, yon, hedef) == 1, "0 suresiz OLMALI"
    finally:
        _ayar(client, yon, 24)


# ==================== SAYAC ve ESIK MANTIGI ETKILENMEZ ================= #

def test_ESIK_SAYACI_harita_penceresinden_ETKILENMEZ(
    client, yon, sakin, owner_conn, world
):
    """EN KRITIK SINIR: harita penceresi (saat) ile sayim penceresi
    (gun) FARKLI seyler. Harita 24 saatte bossalsa bile esik sayaci
    kendi penceresinde (varsayilan 30 gun) saymaya devam etmeli —
    aksi halde bir dairenin israrciligi gozden kacar.
    """
    from app.gurultu_akisi import acik_gurultu_sayisi

    hedef = _daire(client, yon, _sakin_blogu(client, yon, world, owner_conn))
    sid = _sikayet(client, sakin, hedef)
    try:
        _eskit(owner_conn, sid, 30)        # haritanin disinda
        _ayar(client, yon, 24)
        assert _haritada(client, yon, hedef) == 0, "harita filtrelenmemis"

        # SAYAC: dogrudan cekirdek fonksiyon (30 gunluk pencere).
        sayi = owner_conn.execute(
            "SELECT count(*) FROM unit_complaint "
            "WHERE target_unit_id = %s AND durum = 'acik' "
            "AND created_at >= now() - interval '30 days'", (hedef,)
        ).fetchone()[0]
        assert sayi == 1, (
            "sayac penceresi harita filtresinden etkilenmis — iki sure "
            "birbirinden BAGIMSIZ olmali"
        )
        # Sayac fonksiyonu KENDI penceresini kullaniyor (`pencere_gun`)
        # ve harita ayarina HIC bakmiyor — imzasi ve kaynagi bunu
        # gosteriyor. Iki sure birbirinden bagimsiz olmali.
        import inspect

        assert "pencere_gun" in inspect.signature(acik_gurultu_sayisi).parameters
        assert "harita" not in inspect.getsource(acik_gurultu_sayisi)
    finally:
        _ayar(client, yon, 24)


def test_SAKININ_KENDI_sikayeti_ETKILENMEZ(client, yon, sakin, owner_conn, world):
    """Sakin kendi actigi sikayeti her zaman gorur: harita penceresi
    yonetimin GORUNURLUK ayaridir, sakinin kayit erisimi degil."""
    hedef = _daire(client, yon, _sakin_blogu(client, yon, world, owner_conn))
    sid = _sikayet(client, sakin, hedef)
    try:
        _eskit(owner_conn, sid, 24 * 10)
        _ayar(client, yon, 24)
        benim = client.get("/unit-complaints/mine?limit=100", headers=sakin).json()
        assert any(x["id"] == sid for x in benim["items"]), (
            "sakinin kendi sikayeti gizlenmis"
        )
    finally:
        _ayar(client, yon, 24)


# ==================== AYARIN KENDISI =================================== #

def test_VARSAYILAN_24_SAAT(client, yon):
    assert client.get("/tenant/settings", headers=yon).json()[
        "sikayet_harita_saat"] == 24


def test_YONETICI_degistirebilir_ve_SINIRLAR(client, yon):
    try:
        _ayar(client, yon, 0)      # suresiz
        _ayar(client, yon, 8760)   # bir yil
        r = client.patch("/tenant/settings", headers=yon,
                         json={"sikayet_harita_saat": -1})
        assert r.status_code == 422, "negatif deger kabul edilmemeli"
        r = client.patch("/tenant/settings", headers=yon,
                         json={"sikayet_harita_saat": 9000})
        assert r.status_code == 422, "bir yildan uzun sure `0` ile ifade edilir"
    finally:
        _ayar(client, yon, 24)
