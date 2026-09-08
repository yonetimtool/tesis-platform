"""(P220 §1) GORUNUR SIKAYET SAYISI ile ESIK SAYACI AYRI SEYLERDIR.

===========================================================================
OLCULEN KUSUR
===========================================================================
P219 haritaya bir gorunurluk penceresi getirdi (`sikayet_harita_saat`,
varsayilan 24 saat) ve yonetimin gordugu `complaint_count`u ona bagladi.
SAKININ KENDI SAYIMI (`benim_acik_sayisi` / `benim_sikayetim`) BAGLANMADI.

Olcum (48 saat eskitilmis tek sikayet):
    yonetim complaint_count : 1 -> 0    (dogru)
    sakin  benim_acik_sayisi: 1 -> 1    (KUSUR)
    sakin  benim_sikayetim  : True -> True

Yani AYNI IZGARADA, haritadan dusmus bir sikayet sakinin hucresinde
gorunmeye devam ediyordu — kullanicinin bildirdigi sey birebir bu.

===========================================================================
BU DOSYANIN ASIL ISI: IKI SAYIYI BIRBIRINDEN AYIRMAK
===========================================================================
  (a) GORUNUR SAYI  -> `sikayet_harita_saat` (24 saat), kullaniciya gosterilir
  (b) ESIK SAYACI   -> `gurultu_pencere_gun` (30 gun), uyari mantigi

Duzeltmenin (b)'yi bozmadigi da OLCULUYOR: pencere disina dusmus
sikayetlerle 5 esigine ulasilip sesli uyarinin HALA gittigi surulur.
Bu, duzeltmenin ters yonde kirilmasini engelliyor — (b)'yi (a)'ya
baglamak, 5 sikayete hicbir zaman ulasilamamasi demekti.
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


@pytest.fixture
def blok(client, world, owner_conn, yon):
    """Sakinin bagli oldugu blok — sikayet YALNIZ kendi blogunda acilir."""
    satir = owner_conn.execute(
        "SELECT u.blok FROM unit_resident r JOIN unit u ON u.id = r.unit_id "
        "JOIN app_user a ON a.id = r.user_id "
        "WHERE a.email = %s AND r.bitis IS NULL LIMIT 1",
        (world["resident_a"]["email"],)).fetchone()
    if satir:
        return satir[0]
    ad = f"B{uuid.uuid4().hex[:4]}"
    d = client.post("/units", headers=yon, json={
        "no": f"P220-{uuid.uuid4().hex[:6]}", "blok": ad,
        "aktif": True}).json()["id"]
    uid = owner_conn.execute("SELECT id FROM app_user WHERE email = %s",
                             (world["resident_a"]["email"],)).fetchone()[0]
    client.post(f"/units/{d}/residents", headers=yon,
                json={"user_id": str(uid), "rol_tipi": "kiraci"})
    return ad


def _daire(client, yon, blok) -> str:
    return client.post("/units", headers=yon, json={
        "no": f"P220H-{uuid.uuid4().hex[:6]}", "blok": blok,
        "aktif": True}).json()["id"]


def _sikayet(client, sakin, hedef, kategori="gurultu") -> str:
    r = client.post("/unit-complaints", headers=sakin, json={
        "target_unit_id": hedef, "kategori": kategori,
        "aciklama": "P220 olcum"})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _bm(client, h, hedef):
    d = client.get("/unit-complaints/building-map", headers=h).json()
    for b in d["bloklar"]:
        for k in b["katlar"]:
            for u in k["units"]:
                if u["unit_id"] == hedef:
                    return u
    for u in d["unplaced"]:
        if u["unit_id"] == hedef:
            return u
    return None


def _eskit(owner_conn, sikayet_id, saat: int) -> None:
    """Sikayeti GERIYE alir — veri SILINMEZ, yalniz eskir."""
    owner_conn.execute(
        "UPDATE unit_complaint SET created_at = now() - make_interval(hours => %s) "
        "WHERE id = %s", (saat, sikayet_id))


# ==================================================================== #
# 1. SAKININ KENDI SAYIMI DA PENCEREYE TABI
# ==================================================================== #

def test_SAKININ_KENDI_SAYIMI_PENCEREYE_TABI(
        client, owner_conn, yon, sakin, blok):
    """Kusurun ta kendisi: haritadan dusen sikayet sakinin hucresinde
    gorunmeye devam ediyordu."""
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})
    hedef = _daire(client, yon, blok)
    sid = _sikayet(client, sakin, hedef)

    once = _bm(client, sakin, hedef)
    assert once["benim_acik_sayisi"] == 1, once
    assert once["benim_sikayetim"] is True, once

    _eskit(owner_conn, sid, 48)

    sonra = _bm(client, sakin, hedef)
    assert sonra["benim_acik_sayisi"] == 0, sonra
    assert sonra["benim_sikayetim"] is False, sonra


def test_YONETIM_SAYIMIYLA_AYNI_ANDA_DUSER(
        client, owner_conn, yon, sakin, blok):
    """Iki sayim AYNI IZGARAYI besliyor; birinde dusup otekinde kalmak
    ayni ekranda iki farkli gercek gostermekti."""
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})
    hedef = _daire(client, yon, blok)
    sid = _sikayet(client, sakin, hedef)

    assert _bm(client, yon, hedef)["complaint_count"] == 1
    assert _bm(client, sakin, hedef)["benim_acik_sayisi"] == 1

    _eskit(owner_conn, sid, 48)

    assert _bm(client, yon, hedef)["complaint_count"] == 0
    assert _bm(client, sakin, hedef)["benim_acik_sayisi"] == 0


def test_PENCERE_SIFIRSA_SURESIZ_ve_IKISI_DE_GORUNUR(
        client, owner_conn, yon, sakin, blok):
    """`0` = SURESIZ. Kucuk sitelerde 24 saatlik pencere haritayi surekli
    bos gosterir; o durumda iki sayim da eski sikayeti GORMELI."""
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 0})
    hedef = _daire(client, yon, blok)
    sid = _sikayet(client, sakin, hedef)
    _eskit(owner_conn, sid, 48 * 30)

    assert _bm(client, yon, hedef)["complaint_count"] == 1
    assert _bm(client, sakin, hedef)["benim_acik_sayisi"] == 1
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})


# ==================================================================== #
# 2. VERI SILINMEDI — LISTE VE SAKININ KENDI KAYITLARI DURUYOR
# ==================================================================== #

def test_PENCERE_DISI_SIKAYET_LISTEDE_ve_MINE_DA_DURUYOR(
        client, owner_conn, yon, sakin, blok):
    """Gorunurluk filtresi VERI SILME DEGIL.

    `/mine` BILEREK filtrelenmiyor: sakinin kendi actigi sikayet,
    haritadan dustukten sonra da onun kaydidir. Gizlemek "sikayetim
    kayboldu" demek olurdu.
    """
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})
    hedef = _daire(client, yon, blok)
    sid = _sikayet(client, sakin, hedef)
    _eskit(owner_conn, sid, 48)

    # Haritadan dustu...
    assert _bm(client, sakin, hedef)["benim_acik_sayisi"] == 0
    # ...ama kaydi duruyor.
    kalan = owner_conn.execute(
        "SELECT count(*) FROM unit_complaint WHERE id = %s", (sid,)).fetchone()[0]
    assert kalan == 1, "sikayet SILINMIS — bu bir gorunurluk filtresi"
    # ...ve sakin kendi kaydini goruyor.
    mine = client.get("/unit-complaints/mine?limit=200", headers=sakin).json()
    assert any(x["id"] == sid for x in mine["items"]), "sakin kendi kaydini kaybetti"


# ==================================================================== #
# 3. ESIK SAYACI DEGISMEDI — 5 SIKAYET -> SESLI UYARI HALA GIDIYOR
# ==================================================================== #
# Duzeltmenin TERS YONDE kirilmasini engelleyen kilit. Gorunur sayimi
# 24 saatlik pencereye baglarken esik sayacini da baglamak, 5 sikayete
# HICBIR ZAMAN ulasilamamasi demekti: sesli uyari hic gitmezdi ve bunu
# fark etmek aylar surerdi (uyari gitmemesi sessizdir).

def test_ESIK_SAYACI_HARITA_PENCERESINDEN_ETKILENMEZ(
        client, owner_conn, yon, sakin, blok):
    """Harita penceresi 1 SAAT, sikayetler 3 saat eski: haritada
    GORUNMEZ ama esik sayacinda SAYILIR (30 gunluk kendi penceresi)."""
    from datetime import timedelta

    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 1})
    hedef = _daire(client, yon, blok)

    # Esik ve pencere ayarlarini OKU (yoneticinin ayarina DOKUNMUYORUZ).
    ayar = client.get("/tenant/settings", headers=yon).json()
    esik = ayar.get("gurultu_esigi") or 5
    pencere_gun = ayar.get("gurultu_pencere_gun") or 30

    # Esik kadar sikayet — her biri AYRI sakin gerektirmiyor: ayni sakin
    # ayni kategoride 7 gunde bir kez sikayet edebiliyor, o yuzden
    # kayitlari DOGRUDAN yaziyoruz (uc uzerinden kurmak spam korumasina
    # takilirdi ve olculen sey o degil).
    uid = owner_conn.execute(
        "SELECT id FROM app_user WHERE email = %s",
        ("dummy@x", )).fetchone() if False else None
    sakin_id = owner_conn.execute(
        "SELECT a.id FROM app_user a JOIN unit_resident r ON r.user_id = a.id "
        "JOIN unit u ON u.id = r.unit_id WHERE u.blok = %s AND r.bitis IS NULL "
        "LIMIT 1", (blok,)).fetchone()[0]
    tenant_id = owner_conn.execute(
        "SELECT tenant_id FROM unit WHERE id = %s", (hedef,)).fetchone()[0]

    for _ in range(esik):
        owner_conn.execute(
            "INSERT INTO unit_complaint (id, tenant_id, target_unit_id, "
            "  complainant_user_id, kategori, notlar, durum, created_at) "
            "VALUES (gen_random_uuid(), %s, %s, %s, 'gurultu', 'esik olcum', "
            " 'acik', now() - interval '3 hours')",
            (tenant_id, hedef, sakin_id))

    # HARITADA GORUNMUYOR (1 saatlik pencere, kayitlar 3 saat eski).
    assert _bm(client, yon, hedef)["complaint_count"] == 0, (
        "harita penceresi calismiyor")

    # ESIK SAYACINDA SAYILIYOR — dogrudan sayaci olcuyoruz.
    sayac = owner_conn.execute(
        "SELECT count(*) FROM unit_complaint WHERE target_unit_id = %s "
        "AND kategori = 'gurultu' AND durum = 'acik' "
        "AND created_at >= now() - make_interval(days => %s)",
        (hedef, pencere_gun)).fetchone()[0]
    assert sayac >= esik, (
        f"esik sayaci harita penceresinden ETKILENMIS: {sayac} < {esik}")

    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})


def test_ESIK_UYARISI_HALA_URETILIYOR(client, owner_conn, yon, sakin, blok):
    """Sesli uyari akisi UCTAN UCA surulur: esik kadar sikayet ->
    `unit_uyari` satiri dogar.

    `esik_kontrol` sikayet ACMA yolundan cagriliyor; bu yuzden son
    sikayet GERCEK UC uzerinden aciliyor (taklit yok).
    """
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 1})
    ayar = client.get("/tenant/settings", headers=yon).json()
    esik = ayar.get("gurultu_esigi") or 5
    hedef = _daire(client, yon, blok)

    sakin_id = owner_conn.execute(
        "SELECT a.id FROM app_user a JOIN unit_resident r ON r.user_id = a.id "
        "JOIN unit u ON u.id = r.unit_id WHERE u.blok = %s AND r.bitis IS NULL "
        "LIMIT 1", (blok,)).fetchone()[0]
    tenant_id = owner_conn.execute(
        "SELECT tenant_id FROM unit WHERE id = %s", (hedef,)).fetchone()[0]

    # ESIK-1 KAYIT BASKA BIR SIKAYETCIYLE: spam korumasi ayni sakin +
    # ayni kategori + ayni daire icin 7 gunde 1 sikayete izin veriyor
    # (urunun mesru kurali). Kayitlari `sakin` adina yazsaydik, asagidaki
    # GERCEK UC cagrisi 409 alirdi ve olculen sey esik degil spam
    # korumasi olurdu.
    #
    # Esik sayaci DAIRE basina sayar, sikayetci basina degil — bu yuzden
    # baska bir kullanici kullanmak olcumu bozmuyor.
    baska = owner_conn.execute(
        "SELECT id FROM app_user WHERE tenant_id = %s AND id <> %s LIMIT 1",
        (tenant_id, sakin_id)).fetchone()[0]

    # hepsi HARITA PENCERESI DISINDA (3 saat eski, pencere 1 saat).
    for _ in range(esik - 1):
        owner_conn.execute(
            "INSERT INTO unit_complaint (id, tenant_id, target_unit_id, "
            "  complainant_user_id, kategori, notlar, durum, created_at) "
            "VALUES (gen_random_uuid(), %s, %s, %s, 'gurultu', 'esik olcum', "
            " 'acik', now() - interval '3 hours')",
            (tenant_id, hedef, baska))

    once = owner_conn.execute(
        "SELECT count(*) FROM unit_uyari WHERE unit_id = %s", (hedef,)
    ).fetchone()[0]

    # SONUNCUSU GERCEK UCTAN: `esik_kontrol` o yoldan cagriliyor.
    _sikayet(client, sakin, hedef)

    sonra = owner_conn.execute(
        "SELECT count(*) FROM unit_uyari WHERE unit_id = %s", (hedef,)
    ).fetchone()[0]
    assert sonra == once + 1, (
        f"ESIK UYARISI URETILMEDI ({once} -> {sonra}). Gorunur sayimi "
        "pencereye baglamak esik sayacini BOZMAMALI.")

    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})
