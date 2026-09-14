"""(P230 §4) GOREV TAKIBI — durum, zaman cizelgesi, gecikme.

===========================================================================
OLCULEN DURUM (once)
===========================================================================
`task` tablosunda takip icin gereken UC alan da yoktu:
  * DURUM yok  -> "baslandi mi", "gecikti mi" YANITLANAMIYORDU
  * SON TARIH yok -> gecikme HESAPLANAMIYORDU
  * ATAYAN yok -> "bu isi bana kim verdi" hicbir yerde yoktu

P229'da yalniz TAMAMLAMA eklenmisti.

===========================================================================
DURUM SAKLANMAZ, TURETILIR
===========================================================================
Ayri bir `durum` kolonu uc kaynakla senkron tutulmak zorunda olurdu;
tamamlama silinince (P229 geri acma) durumu geri almayi unutan bir kod
yolu gorevi "tamamlandi" gorunur birakirdi.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

import pytest


def _giris(client, world, kim):
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world[kim]["email"], "password": world[kim]["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def yon(client, world):
    return _giris(client, world, "yonetici_a")


@pytest.fixture
def guard(client, world):
    return _giris(client, world, "guard_a")


@pytest.fixture
def guard_id(client, guard):
    return client.get("/me", headers=guard).json()["id"]


def _gorev(client, yon, guard_id, **k):
    govde = {"ad": f"P230 {uuid.uuid4().hex[:6]}", "atanan_user_id": guard_id}
    govde.update(k)
    r = client.post("/tasks", headers=yon, json=govde)
    assert r.status_code == 201, r.text
    return r.json()


def _oku(client, h, tid):
    r = client.get(f"/tasks/{tid}", headers=h)
    assert r.status_code == 200, r.text
    return r.json()


def _tamamla(client, h, tid):
    return client.post(f"/tasks/{tid}/completions", headers={
        **h, "Idempotency-Key": uuid.uuid4().hex},
        json={"tamamlanma_zamani": datetime.now(timezone.utc).isoformat()})


# ==================================================================== #
# 1. DORT DURUM
# ==================================================================== #

def test_YENI_GOREV_ATANDI(client, yon, guard_id):
    assert _gorev(client, yon, guard_id)["durum"] == "atandi"


def test_BASLANINCA_BASLANDI(client, yon, guard, guard_id):
    """TEK YENI GERCEK: "baslandi" hicbir yerden turetilemez. Onceden
    yalniz iki hal vardi ve yonetici, isin ELE ALINDIGINI mi yoksa OYLECE
    DURDUGUNU mu bilmiyordu."""
    t = _gorev(client, yon, guard_id)
    r = client.post(f"/tasks/{t['id']}/basla", headers=guard)
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "baslandi"
    assert r.json()["baslama_zamani"] is not None


def test_TAMAMLANINCA_TAMAMLANDI(client, yon, guard, guard_id):
    t = _gorev(client, yon, guard_id)
    assert _tamamla(client, guard, t["id"]).status_code == 201
    assert _oku(client, yon, t["id"])["durum"] == "tamamlandi"


def test_SON_TARIH_GECINCE_GECIKTI(client, yon, guard_id):
    gecmis = (datetime.now(timezone.utc) - timedelta(days=3)).isoformat()
    t = _gorev(client, yon, guard_id, son_tarih=gecmis)
    v = _oku(client, yon, t["id"])
    assert v["durum"] == "gecikti"
    assert v["gecikme_gun"] == 3, v


def test_TAMAMLANMIS_GOREV_GECIKMIS_GORUNMEZ(client, yon, guard, guard_id):
    """SIRA ONEMLI: son tarihi gecmis AMA tamamlanmis bir gorevi
    "gecikti" gostermek, biten isi bitmemis gibi raporlamak olurdu."""
    gecmis = (datetime.now(timezone.utc) - timedelta(days=3)).isoformat()
    t = _gorev(client, yon, guard_id, son_tarih=gecmis)
    assert _tamamla(client, guard, t["id"]).status_code == 201
    assert _oku(client, yon, t["id"])["durum"] == "tamamlandi"


def test_SON_TARIH_YOKSA_GECIKME_NONE(client, yon, guard_id):
    """SIFIR DEGIL None: sifir "bugun son gun" demektir, "olcusu yok" ile
    karistirilamaz."""
    assert _gorev(client, yon, guard_id)["gecikme_gun"] is None


# ==================================================================== #
# 2. ZAMAN CIZELGESI VE KISILER
# ==================================================================== #

def test_KIM_ATADI_KAYDEDILIR_VE_AD_COZULUR(client, yon, guard, guard_id):
    """Id yeterli degil: saha rolu kullanici listesini GOREMIYOR (403),
    yani "bu isi bana kim verdi" sorusunu istemci kendi cozemezdi."""
    t = _gorev(client, yon, guard_id)
    v = _oku(client, guard, t["id"])
    assert v["olusturan_user_id"] is not None
    assert v["olusturan_ad"], "atayan adi cozulmemis"
    assert v["atanan_ad"], "atanan adi cozulmemis"


def test_ATAYAN_GOVDEDEN_ALINMAZ(client, yon, guard_id):
    """Istemcinin gonderebilecegi bir alan olsaydi BASKASININ ADINA gorev
    atanabilirdi."""
    sahte = str(uuid.uuid4())
    r = client.post("/tasks", headers=yon, json={
        "ad": "sahte atayan", "atanan_user_id": guard_id,
        "olusturan_user_id": sahte})
    assert r.status_code == 201, r.text
    assert r.json()["olusturan_user_id"] != sahte


def test_BASLAMA_IDEMPOTENT(client, yon, guard, guard_id):
    """Ikinci cagri zamani EZMEZ: ezseydi yanlislikla iki kez dokunan
    kullanici GERCEK baslama anini kaybederdi."""
    t = _gorev(client, yon, guard_id)
    ilk = client.post(f"/tasks/{t['id']}/basla", headers=guard).json()
    ikinci = client.post(f"/tasks/{t['id']}/basla", headers=guard).json()
    assert ilk["baslama_zamani"] == ikinci["baslama_zamani"]


def test_BASLAMA_DENETIME_YAZILIR(client, yon, guard, guard_id, owner_conn):
    t = _gorev(client, yon, guard_id)
    client.post(f"/tasks/{t['id']}/basla", headers=guard)
    satir = owner_conn.execute(
        "SELECT action FROM audit_log WHERE resource_id = %s AND action='task_start'",
        (t["id"],)).fetchone()
    assert satir is not None, "baslama denetime YAZILMADI"


# ==================================================================== #
# 3. YETKI
# ==================================================================== #

def test_SAHA_BASKASININ_GOREVINI_BASLATAMAZ(client, yon, guard):
    """Tamamlama ile AYNI kural. Farkli olsaydi, baskasinin gorevini
    "baslatip" tamamlayamayan bir kullanici ortaya cikardi."""
    r = client.post("/tasks", headers=yon, json={"ad": "havuz gorevi"})
    assert r.status_code == 201, r.text
    assert client.post(f"/tasks/{r.json()['id']}/basla",
                       headers=guard).status_code == 404


def test_YONETICI_BASLATABILIR(client, yon, guard_id):
    t = _gorev(client, yon, guard_id)
    assert client.post(f"/tasks/{t['id']}/basla", headers=yon).status_code == 200


# ==================================================================== #
# 4. DURUM SUZGECI — SUNUCUDA
# ==================================================================== #

def _suz(client, yon, durum):
    r = client.get(f"/tasks?limit=200&durum={durum}", headers=yon)
    assert r.status_code == 200, r.text
    return {t["id"] for t in r.json()["items"]}


def test_SUZGEC_SUNUCUDA_VE_DURUMLA_TUTARLI(client, yon, guard, guard_id):
    """Istemcide suzmek SAYFALAMAYI BOZARDI: sunucu 50 satir doner,
    istemci 7'sini gosterir ve kullanici "toplam 300" yazan bir
    sayfalayicida bos sayfalar gezerdi."""
    acik = _gorev(client, yon, guard_id)
    baslanan = _gorev(client, yon, guard_id)
    client.post(f"/tasks/{baslanan['id']}/basla", headers=guard)
    biten = _gorev(client, yon, guard_id)
    assert _tamamla(client, guard, biten["id"]).status_code == 201
    gecikmis = _gorev(
        client, yon, guard_id,
        son_tarih=(datetime.now(timezone.utc) - timedelta(days=1)).isoformat())

    assert acik["id"] in _suz(client, yon, "atandi")
    assert baslanan["id"] in _suz(client, yon, "baslandi")
    assert biten["id"] in _suz(client, yon, "tamamlandi")
    assert gecikmis["id"] in _suz(client, yon, "gecikti")


def test_GECIKEN_BASLANDI_LISTESINDE_CIKMAZ(client, yon, guard, guard_id):
    """Durum hesabi gecikmeyi ONCE degerlendiriyor; suzgec ayrisirsa ayni
    gorev IKI listede birden gorunurdu."""
    t = _gorev(
        client, yon, guard_id,
        son_tarih=(datetime.now(timezone.utc) - timedelta(days=1)).isoformat())
    client.post(f"/tasks/{t['id']}/basla", headers=guard)
    assert t["id"] not in _suz(client, yon, "baslandi")
    assert t["id"] in _suz(client, yon, "gecikti")


def test_BILINMEYEN_DURUM_REDDEDILIR(client, yon):
    r = client.get("/tasks?durum=uydurma", headers=yon)
    assert r.status_code == 422, r.text
