"""(P231) GUVENLIK AMIRI — atama, gorunurluk ayrimi, IDOR.

===========================================================================
§0 OLCUM (once, CANLI SURULEREK)
===========================================================================
Rol P129'dan beri tanimli ve rol matrisinde 125 ucta IZINLI — `GET /users`,
`POST /users`, `PATCH /users/{id}` dahil. P218'de "hicbir yuzeye giremiyor"
diye olculmustu; P213 §6 web yuzeyini acmis (dashboard + kamera kayitlari +
profil).

AMA GORUNURLUK HIC DARALTILMAMISTI. Amir hesabiyla giris yapip
`GET /users?limit=1000` cektigimde YEDI ROLUN HEPSI geldi:

    {'admin': 1, 'guvenlik_amiri': 1, 'denetci': 1, 'tesis_gorevlisi': 1,
     'security': 1, 'resident': 1, 'yonetici': 1}

Yani "dis guvenlik sirketi amiri" tesisin TUM sakin ve personel listesini
goruyordu. Bu dosya o sizintiyi kilitler.
"""
from __future__ import annotations

import uuid

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
def amir(client, world):
    return _h(client, world, "amir_a")


@pytest.fixture
def adm(client, world):
    return _h(client, world, "admin_a")


def _roller(client, h, **k):
    q = "&".join(f"{a}={b}" for a, b in k.items())
    r = client.get(f"/users?limit=1000&{q}", headers=h)
    assert r.status_code == 200, r.text
    return {u["role"] for u in r.json()["items"]}


# ==================================================================== #
# §2 — GORUNURLUK AYRIMI
# ==================================================================== #

def test_AMIR_YALNIZ_GUVENLIK_PERSONELINI_GORUR(client, amir):
    """OLCULEN SIZINTININ TA KENDISI."""
    assert _roller(client, amir) <= {"security", "guvenlik_amiri"}


def test_AMIR_SAKINI_VE_TESIS_GOREVLISINI_GORMEZ(client, amir):
    gorulen = _roller(client, amir)
    for yasak in ("resident", "tesis_gorevlisi", "yonetici", "admin", "denetci"):
        assert yasak not in gorulen, (yasak, gorulen)


def test_YONETICI_HERKESI_GORMEYE_DEVAM_EDER(client, yon):
    """KORUMA FAZLA GENIS OLMASIN: suzgec yanlis yazilsaydi yoneticinin
    listesi de daralir ve kimse fark etmezdi."""
    gorulen = _roller(client, yon)
    assert {"resident", "security", "tesis_gorevlisi"} <= gorulen, gorulen


def test_AMIRIN_ROL_SUZGECI_KESISIR_EZMEZ(client, amir):
    """Amir `?role=resident` gonderirse BOS liste alir — suzgec istemciden
    gelen parametreyle EZILEMEZ."""
    assert _roller(client, amir, role="resident") == set()


# ==================================================================== #
# §2 — IDOR: tekil uc de kapali
# ==================================================================== #

def test_AMIR_SAKIN_KAYDINI_TEKIL_UCTAN_OKUYAMAZ(client, yon, amir):
    """Listeyi daraltmak YETMEZ: tekil uc acik kalsaydi amir bir sakinin
    id'sini baska bir yerden gorup TUM kaydini okuyabilirdi.

    404 (403 DEGIL): "var ama goremezsin", kaydin VARLIGINI sizdirmak
    olurdu.
    """
    sakinler = client.get("/users?limit=1000&role=resident", headers=yon).json()
    if not sakinler["items"]:
        pytest.skip("fixture'da sakin yok")
    sid = sakinler["items"][0]["id"]
    # Yonetici gorebiliyor.
    assert client.get(f"/users/{sid}", headers=yon).status_code == 200
    # Amir GOREMEZ.
    assert client.get(f"/users/{sid}", headers=amir).status_code == 404


def test_AMIR_GUVENLIK_KAYDINI_TEKIL_OKUR(client, yon, amir):
    """KORUMA FAZLA GENIS OLMASIN."""
    g = client.get("/users?limit=1000&role=security", headers=yon).json()["items"]
    if not g:
        pytest.skip("fixture'da guvenlik personeli yok")
    assert client.get(f"/users/{g[0]['id']}", headers=amir).status_code == 200


# ==================================================================== #
# §1 — ATAMA
# ==================================================================== #

def test_YONETICI_GUVENLIKCIYI_AMIR_YAPAR_VE_GERI_ALIR(client, yon):
    """ROL DEGISIMI, AYRI BAYRAK DEGIL: amirlik bir YETKI SEVIYESIDIR;
    ayri bir bayrak, yetkinin IKI kaynaktan (rol + bayrak) turemesi ve
    ikisinin ayrismasi demekti."""
    g = client.get("/users?limit=1000&role=security", headers=yon).json()["items"]
    if not g:
        pytest.skip("fixture'da guvenlik personeli yok")
    kid = g[0]["id"]
    try:
        r = client.patch(f"/users/{kid}", headers=yon,
                         json={"role": "guvenlik_amiri"})
        assert r.status_code == 200, r.text
        assert r.json()["role"] == "guvenlik_amiri"
    finally:
        geri = client.patch(f"/users/{kid}", headers=yon,
                            json={"role": "security"})
        assert geri.status_code == 200, geri.text
        assert geri.json()["role"] == "security"


def test_ADMIN_YONETICI_VARKEN_AMIR_ATAYAMAZ(client, yon, adm):
    """Amir tesisin IC isidir: kime guvenecegine tesisin yoneticisi karar
    verir."""
    g = client.get("/users?limit=1000&role=security", headers=yon).json()["items"]
    if not g:
        pytest.skip("fixture'da guvenlik personeli yok")
    r = client.patch(f"/users/{g[0]['id']}", headers=adm,
                     json={"role": "guvenlik_amiri"})
    assert r.status_code == 403, r.text
    assert r.json()["error"]["code"] == "forbidden"


def test_ADMIN_YONETICISIZ_TESISTE_ATAYABILIR(client, yon, adm, owner_conn, world):
    """KURTARMA YOLU ACIK KALIR.

    Admin'i KOSULSUZ kapatmak, bu hafta gercekten yasanan senaryoyla
    celisiyordu: prod'da platform admini disinda kimse kalmamisti (P224)
    ve aktif yonetici yokken amir atamak imkansiz hale gelirdi.
    """
    g = client.get("/users?limit=1000&role=security", headers=yon).json()["items"]
    if not g:
        pytest.skip("fixture'da guvenlik personeli yok")
    kid = g[0]["id"]
    owner_conn.execute(
        "UPDATE app_user SET is_active = false WHERE role = 'yonetici' "
        "AND tenant_id = %s", (world["a"],))
    try:
        r = client.patch(f"/users/{kid}", headers=adm,
                         json={"role": "guvenlik_amiri"})
        assert r.status_code == 200, r.text
    finally:
        owner_conn.execute(
            "UPDATE app_user SET is_active = true WHERE role = 'yonetici' "
            "AND tenant_id = %s", (world["a"],))
        owner_conn.execute(
            "UPDATE app_user SET role = 'security' WHERE id = %s", (kid,))


def test_SECURITY_AMIR_ATAYAMAZ(client, world):
    g = _h(client, world, "guard_a")
    liste = client.get("/users?limit=1000", headers=g)
    assert liste.status_code == 403, liste.text


def test_ATAMA_VE_GOREVDEN_ALMA_DENETLENIR(client, yon, owner_conn):
    """"Bu siteye amiri kim, ne zaman atadi" bir YETKI sorusudur ve genel
    bir `user_update` kaydinin icinde aranmasi gereken bir sey degil."""
    g = client.get("/users?limit=1000&role=security", headers=yon).json()["items"]
    if not g:
        pytest.skip("fixture'da guvenlik personeli yok")
    kid = g[0]["id"]
    client.patch(f"/users/{kid}", headers=yon, json={"role": "guvenlik_amiri"})
    client.patch(f"/users/{kid}", headers=yon, json={"role": "security"})
    eylemler = {
        r[0] for r in owner_conn.execute(
            "SELECT action FROM audit_log WHERE resource_id = %s", (kid,)).fetchall()
    }
    assert "guvenlik_amiri_ata" in eylemler, eylemler
    assert "guvenlik_amiri_kaldir" in eylemler, eylemler


# ==================================================================== #
# §3 — YETKI ALANI
# ==================================================================== #

def test_AMIRE_UCRET_VE_FINANS_KAPALI(client, amir):
    """UCRET BILGISI HASSAS — istegin acik sarti. `/mesai` ve finans
    uclarinin hepsi reddedilmeli."""
    for yol in ("/residents", "/dues/assessments", "/finans/hareketler",
                "/mesai", "/mesai/ayar", "/kargo"):
        r = client.get(yol, headers=amir)
        assert r.status_code in (403, 404), (yol, r.status_code)


def test_AMIR_ZIYARETCI_KAYITLARINI_GORUR(client, amir):
    """Ekibinin kaydettigi veriyi DENETLEMEK icin."""
    r = client.get("/visitors", headers=amir)
    assert r.status_code == 200, r.text


def test_AMIR_ZIYARETCI_KAYDI_ACAMAZ(client, amir):
    """Kaydi KAPIDAKI gorevli girer; amirin isi denetlemek. Yazma yetkisi
    "kim kaydetti" izini bulaniklastirirdi."""
    r = client.post("/visitors", headers=amir, json={"ad": "X"})
    assert r.status_code in (403, 422), r.status_code


def test_AMIR_GUVENLIKCIYE_GOREV_ATAR(client, yon, amir):
    g = client.get("/users?limit=1000&role=security", headers=yon).json()["items"]
    if not g:
        pytest.skip("fixture'da guvenlik personeli yok")
    r = client.post("/tasks", headers=amir, json={
        "ad": f"P231 {uuid.uuid4().hex[:6]}", "atanan_user_id": g[0]["id"]})
    assert r.status_code == 201, r.text


def test_AMIR_TESIS_GOREVLISINE_GOREV_ATAYAMAZ(client, yon, amir):
    """TEK KAYNAK: personel listesinde kimi goruyorsa gorev de ancak ona
    atanabilir. Ayri bir kume yazmak, amirin GOREMEDIGI birine gorev
    atayabilmesi demekti."""
    t = client.get("/users?limit=1000&role=tesis_gorevlisi", headers=yon).json()["items"]
    if not t:
        pytest.skip("fixture'da tesis gorevlisi yok")
    r = client.post("/tasks", headers=amir, json={
        "ad": "yasak atama", "atanan_user_id": t[0]["id"]})
    assert r.status_code == 422, r.text


# ==================================================================== #
# §2 — VARDIYA: amir kendi ekibini planlar
# ==================================================================== #

def _kisi(client, h, rol):
    v = client.get(f"/users?limit=1000&role={rol}", headers=h).json()["items"]
    return v[0]["id"] if v else None


def test_AMIR_GUVENLIK_VARDIYASI_PLANLAR(client, yon, amir):
    """Sahada vardiya degisimini amir yonetir; her degisiklik icin
    yoneticiye gitmek gecikme uretir."""
    gid = _kisi(client, yon, "security")
    if not gid:
        pytest.skip("guvenlik personeli yok")
    from datetime import date, timedelta
    g = (date.today() + timedelta(days=300)).isoformat()
    r = client.post("/vardiya-plani/toplu", headers=amir, json={
        "user_id": gid, "baslangic_tarih": g, "bitis_tarih": g,
        "baslangic_saat": "08:00", "bitis_saat": "16:00"})
    assert r.status_code == 200, r.text
    assert r.json()["uygulandi"] is True, r.json()


def test_AMIR_TESIS_GOREVLISININ_VARDIYASINA_DOKUNAMAZ(client, yon, amir):
    """TEK KAYNAK: personel listesinde goremedigi kisinin vardiyasini da
    duzenleyemez. Ayri bir kume yazmak, birinin eskimesi demekti."""
    tid = _kisi(client, yon, "tesis_gorevlisi")
    if not tid:
        pytest.skip("tesis gorevlisi yok")
    from datetime import date, timedelta
    g = (date.today() + timedelta(days=301)).isoformat()
    r = client.post("/vardiya-plani/toplu", headers=amir, json={
        "user_id": tid, "baslangic_tarih": g, "bitis_tarih": g,
        "baslangic_saat": "08:00", "bitis_saat": "16:00"})
    assert r.status_code == 403, r.text


def test_AMIR_TESIS_GOREVLISININ_VARDIYASINI_SILEMEZ_YAYINLAYAMAZ(
    client, yon, amir, owner_conn
):
    """(E2E 2026-09) Kapsam yalniz EKLEYEN uclardaydi: amir tesis
    gorevlisinin satirini silebiliyor, duzenleyebiliyor, yayinlayip ona
    bildirim gonderebiliyor ve kopyalamayla temizleyebiliyordu."""
    tid = _kisi(client, yon, "tesis_gorevlisi")
    if not tid:
        pytest.skip("tesis gorevlisi yok")
    from datetime import date, timedelta
    gun = date.today() + timedelta(days=320)
    g = gun.isoformat()
    r = client.post("/vardiya-plani/toplu", headers=yon, json={
        "user_id": tid, "baslangic_tarih": g, "bitis_tarih": g,
        "baslangic_saat": "08:00", "bitis_saat": "16:00"})
    assert r.status_code == 200, r.text
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM vardiya_plani WHERE user_id = %s AND tarih = %s "
            "AND durum = 'planli'", (tid, gun))
        plan_id = cur.fetchone()[0]

    assert client.delete(f"/vardiya-plani/{plan_id}", headers=amir).status_code == 404
    assert client.patch(f"/vardiya-plani/{plan_id}", headers=amir,
                        json={"not_metni": "amir"}).status_code == 404
    r = client.post(f"/vardiya-plani/yayinla?baslangic={g}&gun=1", headers=amir)
    assert r.status_code == 200, r.text
    with owner_conn.cursor() as cur:
        cur.execute("SELECT durum, yayinlandi_at, not_metni FROM vardiya_plani WHERE id = %s",
                    (plan_id,))
        durum, yayin, notu = cur.fetchone()
    assert durum == "planli" and yayin is None and notu != "amir"
    client.delete(f"/vardiya-plani/{plan_id}", headers=yon)


def test_AMIR_CIZELGEDE_YALNIZ_GUVENLIGI_GORUR(client, amir):
    """BOS SATIRLAR DA SUZULUR: yalniz bloklari suzup personel listesini
    acik birakmak, amire tesis gorevlisinin ADINI yine gosterirdi."""
    from datetime import date
    r = client.get(
        f"/vardiya-plani/cizelge?baslangic={date.today().isoformat()}&gun=7",
        headers=amir)
    assert r.status_code == 200, r.text
    roller = {k["rol"] for k in r.json()["personel"]}
    assert roller <= {"security", "guvenlik_amiri"}, roller


def test_YONETICI_CIZELGEDE_HERKESI_GORUR(client, yon):
    from datetime import date
    r = client.get(
        f"/vardiya-plani/cizelge?baslangic={date.today().isoformat()}&gun=7",
        headers=yon)
    assert r.status_code == 200, r.text
    roller = {k["rol"] for k in r.json()["personel"]}
    assert "tesis_gorevlisi" in roller, roller


# ==================================================================== #
# §2 — KORUMA FAZLA GENIS OLMASIN: saha rolleri etkilenmemeli
# ==================================================================== #

def test_SAHA_ROLU_VARDIYADAKI_PERSONELI_GORMEYE_DEVAM_EDER(client, world, yon):
    """(P232) OLCULEN GERILEME: `GORUNUR_ROLLER`in fail-closed varsayilani
    saha rollerini de kapsiyordu ve `GET /shifts` cagiran bir guvenlik
    gorevlisi vardiyadaki PERSONELI BOS goruyordu.

    Kusur SESSIZDI: uc 200 doner ve liste doludur; yalnizca her
    vardiyanin `personel` alani bosalir. "Bu vardiyada benimle kim var"
    sorusu VARDIYA DEVRININ kendisidir.
    """
    guard = _h(client, world, "guard_a")
    r = client.get("/shifts?limit=200", headers=guard)
    assert r.status_code == 200, r.text
    # Fail-closed kume donseydi HICBIR vardiyada personel gorunmezdi.
    from app.roller import gorunur_roller
    assert gorunur_roller("security") is None, (
        "saha rolu personel gorunurlugunden DUSMUS")
    assert gorunur_roller("tesis_gorevlisi") is None


def test_TANINMAYAN_ROL_HALA_FAIL_CLOSED():
    """Saha rollerini acikca yazmak, BILINMEYEN rolu de acmamali."""
    from app.roller import gorunur_roller
    assert gorunur_roller("uydurma_rol") == frozenset()
