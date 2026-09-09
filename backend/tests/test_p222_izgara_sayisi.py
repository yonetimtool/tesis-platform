"""(P222 §1) ANA EKRAN IZGARASININ sikayet sayisi — HARITA ILE AYNI SAYI.

===========================================================================
OLCULEN KUSUR
===========================================================================
P220'de harita ve sakinin kendi sayimi pencereye baglandi. IZGARA
KAROSU ATLANDI: karo `GET /unit-complaints?durum=acik&limit=1` cagirip
`meta.total` okuyor ve o LISTE ucu `sikayet_harita_saat` penceresini
UYGULAMAZ. Olcum (48 saat eskitilmis tek sikayet, pencere 24 saat):

    izgara karosu (meta.total)      : 1 -> 1    (KUSUR)
    karonun actigi harita           : 1 -> 0    (dogru)

Yani karo "1 Acik" derken dokununca acilan ekran bos geliyordu.
Modul basligindaki iki sayidan hicbiri degil, UCUNCU sinifsiz bir sayi.

===========================================================================
COZUM VE SINIRI
===========================================================================
Yeni uc `GET /unit-complaints/gorunur-sayi` haritayla AYNI
`_harita_penceresi()` fonksiyonundan gecer.

LISTE UCU BILEREK PENCERESIZ KALDI: kuyruktan kayit dusurmek
"sikayetim kayboldu" demek olurdu (P220 kilidi `test_p220_gorunur_sayi.
py::test_PENCERE_DISI_SIKAYET_LISTEDE_ve_MINE_DA_DURUYOR`). Bu dosya
o kilidin HALA gecerli oldugunu da olcer — iki karar birbirini
yemesin diye.

ESIK SAYACI (b) bu turda HIC DEGISMEDI; asagida ayrica surulur.
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
    satir = owner_conn.execute(
        "SELECT u.blok FROM unit_resident r JOIN unit u ON u.id = r.unit_id "
        "JOIN app_user a ON a.id = r.user_id "
        "WHERE a.email = %s AND r.bitis IS NULL LIMIT 1",
        (world["resident_a"]["email"],)).fetchone()
    if satir:
        return satir[0]
    ad = f"B{uuid.uuid4().hex[:4]}"
    d = client.post("/units", headers=yon, json={
        "no": f"P222-{uuid.uuid4().hex[:6]}", "blok": ad, "aktif": True}).json()["id"]
    uid = owner_conn.execute("SELECT id FROM app_user WHERE email = %s",
                             (world["resident_a"]["email"],)).fetchone()[0]
    client.post(f"/units/{d}/residents", headers=yon,
                json={"user_id": str(uid), "rol_tipi": "kiraci"})
    return ad


@pytest.fixture
def pencere_geri_al(client, yon):
    """Pencere ayari DB'de KALICI — birakilan deger sonraki testleri kirar."""
    onceki = client.get("/tenant/settings", headers=yon).json().get(
        "sikayet_harita_saat")
    yield
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": onceki})


def _daire(client, yon, blok) -> str:
    return client.post("/units", headers=yon, json={
        "no": f"P222H-{uuid.uuid4().hex[:6]}", "blok": blok,
        "aktif": True}).json()["id"]


def _sikayet(client, sakin, hedef, kategori="gurultu") -> str:
    r = client.post("/unit-complaints", headers=sakin, json={
        "target_unit_id": hedef, "kategori": kategori, "notlar": "P222 olcum"})
    assert r.status_code in (200, 201), r.text
    return r.json()["id"]


def _eskit(owner_conn, sikayet_id, saat: int) -> None:
    owner_conn.execute(
        "UPDATE unit_complaint SET created_at = now() - make_interval(hours => %s) "
        "WHERE id = %s", (saat, sikayet_id))


def _izgara(client, h) -> int:
    r = client.get("/unit-complaints/gorunur-sayi", headers=h)
    assert r.status_code == 200, r.text
    return r.json()["acik_sayisi"]


def _harita_toplami(client, h) -> int:
    d = client.get("/unit-complaints/density", headers=h).json()
    return sum(x["acik_sayisi"] for x in d["items"])


# ==================================================================== #
# 1. SIKAYET OLUSUNCA IZGARADA GORUNUR
# ==================================================================== #

def test_SIKAYET_OLUSUNCA_IZGARA_SAYISI_ARTAR(
        client, yon, sakin, blok, pencere_geri_al):
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})
    once = _izgara(client, yon)
    _sikayet(client, sakin, _daire(client, yon, blok))
    assert _izgara(client, yon) == once + 1


# ==================================================================== #
# 2. SURE DOLUNCA IZGARADAN DA DUSER — VE HARITAYLA AYNI ANDA
# ==================================================================== #

def test_SURE_DOLUNCA_IZGARADAN_DUSER_HARITAYLA_AYNI_ANDA(
        client, owner_conn, yon, sakin, blok, pencere_geri_al):
    """Kusurun ta kendisi: eskiden izgara duserken harita dusuyordu."""
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})
    hedef = _daire(client, yon, blok)
    sid = _sikayet(client, sakin, hedef)

    izgara_once, harita_once = _izgara(client, yon), _harita_toplami(client, yon)
    _eskit(owner_conn, sid, 48)
    izgara_sonra, harita_sonra = _izgara(client, yon), _harita_toplami(client, yon)

    assert izgara_once - izgara_sonra == 1, "izgara sayisi DUSMEDI"
    assert harita_once - harita_sonra == 1, "harita sayisi DUSMEDI"
    # ASIL KILIT: ikisi AYNI SEYI sayiyor.
    assert izgara_sonra == harita_sonra, (
        f"izgara {izgara_sonra} · harita {harita_sonra} — AYRI SAYIYORLAR")


def test_PENCERE_SIFIRSA_SURESIZ_izgara_DUSMEZ(
        client, owner_conn, yon, sakin, blok, pencere_geri_al):
    """`0` = suresiz. Kucuk sitede 24 saat izgarayi surekli bos gosterirdi."""
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 0})
    hedef = _daire(client, yon, blok)
    sid = _sikayet(client, sakin, hedef)
    once = _izgara(client, yon)
    _eskit(owner_conn, sid, 500)
    assert _izgara(client, yon) == once, "pencere 0 iken sayi DUSTU"


# ==================================================================== #
# 3. LISTE UCU PENCERESIZ KALDI (P220 karari korunuyor)
# ==================================================================== #

def test_LISTE_UCU_PENCERESIZ_KALDI_kayit_kuyruktan_DUSMEZ(
        client, owner_conn, yon, sakin, blok, pencere_geri_al):
    """Izgarayi pencereye baglarken KUYRUGU da baglamak, yoneticinin
    acik kalmis eski sikayetleri GORMEMESI demekti."""
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 24})
    hedef = _daire(client, yon, blok)
    sid = _sikayet(client, sakin, hedef)
    _eskit(owner_conn, sid, 48)

    assert _izgara(client, yon) == _harita_toplami(client, yon)
    liste = client.get("/unit-complaints?durum=acik&limit=200", headers=yon).json()
    assert any(x["id"] == sid for x in liste["items"]), (
        "sikayet KUYRUKTAN dustu — bu bir gorunurluk filtresi, veri silme degil")


# ==================================================================== #
# 4. ESIK SAYACI (b) ETKILENMEDI — 5 SIKAYETTE UYARI HALA GIDIYOR
# ==================================================================== #

def test_ESIK_SAYACI_IZGARA_DUZELTMESINDEN_ETKILENMEZ(
        client, owner_conn, yon, sakin, blok, pencere_geri_al):
    """Izgara 0 gosterirken esik sayaci 5'e ulasip uyari uretmeli.

    Ters yonde kirilmayi engelleyen kilit: izgarayi pencereye baglarken
    esik sayacini da baglamak, 5 sikayete HICBIR ZAMAN ulasilamamasi
    ve sesli uyarinin HIC gitmemesi demekti — ve bu SESSIZ bir kusurdur.
    """
    client.patch("/tenant/settings", headers=yon,
                 json={"sikayet_harita_saat": 1})
    hedef = _daire(client, yon, blok)

    # Ayni sakin ayni kategoride 7 gunde 1 sikayet acabilir; 5 AYRI
    # kategori kullanilir (spam korumasi kategori bazli).
    # Semadaki BES kategorinin TAMAMI (schemas.UnitComplaintKategori);
    # uydurma bir ad 422 dondurur ve test 2 sikayette kalirdi.
    kategoriler = ["gurultu", "kapi_onu_ayakkabi", "zarar_verme",
                   "goruntu_kirliligi", "diger"]
    idler = []
    for k in kategoriler:
        r = client.post("/unit-complaints", headers=sakin, json={
            "target_unit_id": hedef, "kategori": k, "notlar": "P222 esik"})
        if r.status_code in (200, 201):
            idler.append(r.json()["id"])
    assert len(idler) >= 5, f"5 sikayet acilamadi: {len(idler)}"

    # Hepsi haritanin 1 saatlik penceresinin DISINA cikarilir.
    for sid in idler:
        _eskit(owner_conn, sid, 3)

    # Izgara bu daireyi artik saymiyor...
    d = client.get("/unit-complaints/density", headers=yon).json()
    bu_daire = next(x for x in d["items"] if x["target_unit_id"] == hedef)
    assert bu_daire["acik_sayisi"] == 0, "harita penceresi uygulanmadi"

    # ...ama ESIK SAYACI (30 gunluk kendi penceresi) 5'i goruyor.
    sayi = owner_conn.execute(
        "SELECT count(*) FROM unit_complaint WHERE target_unit_id = %s "
        "AND durum = 'acik' AND created_at >= now() - interval '30 days'",
        (hedef,)).fetchone()[0]
    assert sayi >= 5, f"esik sayaci pencereden ETKILENDI: {sayi}"
