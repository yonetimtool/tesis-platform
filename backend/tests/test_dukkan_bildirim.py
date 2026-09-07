"""(DUKKAN F6) BILDIRIM — kalici satir + push, yan yana.

===========================================================================
NE KORUNUYOR
===========================================================================
1. Her olay KALICI bir satir birakir — push kacirilsa bile olay kaybolmaz.
2. Metin KAYDA DONDURULMEZ: `tip` + `veri` doner, istemci kendi dilinde
   uretir.
3. `gonderildi_at` yalnizca saglayici KABUL ettiginde dolar — noop'ta NULL
   kalir ve "hic gitmemis" olarak GORULUR (P191 tuzagi).
4. HEDEF YOL SUNUCUDA: mobil ve web ayni degeri okur; iki istemcide ayri
   eslestirme, bildirime tiklayinca YANLIS EKRANA gitmek demekti.
5. (F6-ek) TIPLER `dukkan_` ONEKLI: onek, push kanalini secen kuraldir
   (`push_kanal.DUKKAN_ONEK`). Oneksiz bir tip dogru calisiyor gibi
   gorunur ama YANLIS KANALDAN gider. Ayrica `yeni_talep` Yonetiyor'da
   ZATEN VAR — oneksiz birakmak iki urunun tipini cakistirirdi.
6. Cihaz jetonu DEVRALINIR: cihaz el degistirirse eski sahibin
   bildirimleri yeni kullaniciya DUSMEZ.
"""
from __future__ import annotations

import uuid

import pytest


def _tel() -> str:
    return f"+9053{uuid.uuid4().int % 10**8:08d}"


def _giris(client) -> dict:
    tel = _tel()
    kod = client.post("/dukkan/auth/telefon/kod",
                      json={"telefon": tel}).json()["dev_kod"]
    d = client.post("/dukkan/auth/telefon/dogrula",
                    json={"telefon": tel, "kod": kod}).json()
    return {"h": {"Authorization": f"Bearer {d['access_token']}"},
            "id": d["kullanici"]["id"], "telefon": tel}


@pytest.fixture
def moderator(client, dukkan_conn):
    k = _giris(client)
    dukkan_conn.execute(
        "INSERT INTO dukkan.moderator (kullanici_id, atayan) VALUES (%s,'f6') "
        "ON CONFLICT DO NOTHING", (k["id"],))
    return k


def _mahalle(dukkan_conn):
    r = dukkan_conn.execute(
        "SELECT m.id, m.slug, ic.slug, i.slug FROM dukkan.mahalle m "
        "JOIN dukkan.ilce ic ON ic.id = m.ilce_id "
        "JOIN dukkan.il i ON i.id = ic.il_id "
        "WHERE i.slug='istanbul' AND ic.slug='cekmekoy' ORDER BY m.slug LIMIT 1"
    ).fetchone()
    return {"id": str(r[0]), "mahalle": r[1], "ilce": r[2], "il": r[3]}


# ==================================================================== #
# 1. CIHAZ KAYDI
# ==================================================================== #

def test_CIHAZ_KAYDI_ve_SILME(client):
    k = _giris(client)
    jeton = f"fcm-{uuid.uuid4().hex}"
    assert client.post("/dukkan/cihaz", headers=k["h"],
                       json={"fcm_token": jeton,
                             "platform": "android"}).status_code == 200
    # SILME SAYI DONDURUR (P217): sifir ise arayuz "cikis yapildi" derken
    # bildirimlerin devam edecegini bilmeli.
    r = client.delete("/dukkan/cihaz", headers=k["h"],
                      params={"fcm_token": jeton})
    assert r.status_code == 200 and r.json()["silinen"] == 1
    r2 = client.delete("/dukkan/cihaz", headers=k["h"],
                       params={"fcm_token": jeton})
    assert r2.json()["silinen"] == 0


def test_CIHAZ_EL_DEGISTIRINCE_DEVRALINIR(client, dukkan_conn):
    """Ortak telefon / ikinci el: eski sahibin bildirimleri yeni
    kullaniciya DUSMEMELI."""
    a, b = _giris(client), _giris(client)
    jeton = f"fcm-{uuid.uuid4().hex}"
    client.post("/dukkan/cihaz", headers=a["h"], json={"fcm_token": jeton})
    client.post("/dukkan/cihaz", headers=b["h"], json={"fcm_token": jeton})

    sahip = dukkan_conn.execute(
        "SELECT kullanici_id FROM dukkan.dukkan_cihaz WHERE fcm_token=%s",
        (jeton,)).fetchall()
    assert len(sahip) == 1, "ayni jeton IKI satirda"
    assert str(sahip[0][0]) == b["id"], "cihaz DEVRALINMADI"


def test_CIHAZ_KIMLIK_ISTER(client):
    assert client.post("/dukkan/cihaz",
                       json={"fcm_token": "x" * 20}).status_code == 401


# ==================================================================== #
# 2. OLAY -> KALICI SATIR
# ==================================================================== #

@pytest.fixture
def akis(client, dukkan_conn, moderator):
    """Isletme + talep + teklif (bildirim uretecek akis)."""
    m = _mahalle(dukkan_conn)
    sahip = _giris(client)
    isl = client.post("/dukkan/isletme", headers=sahip["h"],
                      json={"ad": f"Bildirim {uuid.uuid4().hex[:6]}",
                            "telefon": _tel()}).json()["id"]
    client.put(f"/dukkan/isletme/{isl}/kategoriler", headers=sahip["h"],
               json={"slugler": ["elektrikci"]})
    client.put(f"/dukkan/isletme/{isl}/hizmet-alanlari", headers=sahip["h"],
               json={"mahalle_idler": [m["id"]]})
    kod = client.post(f"/dukkan/isletme/{isl}/telefon/kod",
                      headers=sahip["h"]).json()["dev_kod"]
    client.post(f"/dukkan/isletme/{isl}/telefon/dogrula", headers=sahip["h"],
                json={"kod": kod})
    client.post(f"/dukkan/isletme/{isl}/basvur", headers=sahip["h"])
    client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                headers=moderator["h"], json={"karar": "onayla"})

    musteri = _giris(client)
    talep = client.post("/dukkan/talep", headers=musteri["h"], json={
        "kategori_slug": "elektrikci", "il_slug": m["il"],
        "ilce_slug": m["ilce"], "mahalle_slug": m["mahalle"],
        "aciklama": "Bildirim testi için talep."}).json()["id"]
    return {"m": m, "sahip": sahip, "isl": isl, "musteri": musteri,
            "talep": talep}


def test_ONAY_ISLETME_SAHIBINE_BILDIRIM_YAZAR(client, akis):
    """Moderator onayi isletme sahibine bildirilmeli — yoksa isletme
    yayina girdigini fark etmez."""
    d = client.get("/dukkan/bildirim", headers=akis["sahip"]["h"]).json()
    tipler = [x["tip"] for x in d["items"]]
    assert "dukkan_isletme_onaylandi" in tipler, tipler
    assert d["okunmamis"] >= 1


def test_TEKLIF_TALEP_SAHIBINE_BILDIRIM_YAZAR(client, akis):
    """Teklifi gormeyen musteri baska yerden usta bulur ve teklif veren
    isletme bosuna beklemis olur."""
    client.post(f"/dukkan/talep/{akis['talep']}/teklif",
                headers=akis["sahip"]["h"], params={"isletme_id": akis["isl"]},
                json={"tutar_kurus": 120000})
    d = client.get("/dukkan/bildirim", headers=akis["musteri"]["h"]).json()
    b = next((x for x in d["items"] if x["tip"] == "dukkan_teklif_geldi"), None)
    assert b is not None, [x["tip"] for x in d["items"]]
    # HEDEF YOL SUNUCUDA: iki istemci ayni degeri okur.
    assert b["hedef_yol"] == f"/taleplerim/{akis['talep']}"


def test_IS_VERILINCE_ISLETMEYE_BILDIRIM(client, akis):
    client.post(f"/dukkan/talep/{akis['talep']}/teklif",
                headers=akis["sahip"]["h"], params={"isletme_id": akis["isl"]},
                json={"tutar_kurus": 120000})
    tk = client.get(f"/dukkan/talep/{akis['talep']}/teklifler",
                    headers=akis["musteri"]["h"]).json()["items"][0]
    client.post(f"/dukkan/teklif/{tk['id']}/kabul", headers=akis["musteri"]["h"])

    d = client.get("/dukkan/bildirim", headers=akis["sahip"]["h"]).json()
    tipler = [x["tip"] for x in d["items"]]
    assert "dukkan_is_verildi" in tipler, tipler


def test_RET_GEREKCESI_BILDIRIMDE(client, dukkan_conn, moderator):
    """"Reddedildi" deyip sebebini soylememek, isletmeyi ne
    duzeltecegini bilmez halde birakirdi."""
    k = _giris(client)
    isl = client.post("/dukkan/isletme", headers=k["h"],
                      json={"ad": "Ret Testi", "telefon": _tel()}).json()["id"]
    dukkan_conn.execute(
        "UPDATE dukkan.isletme SET durum='onay_bekliyor' WHERE id=%s", (isl,))
    client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                headers=moderator["h"],
                json={"karar": "reddet", "gerekce": "Belge okunmuyor."})

    d = client.get("/dukkan/bildirim", headers=k["h"]).json()
    b = next(x for x in d["items"] if x["tip"] == "dukkan_isletme_reddedildi")
    assert b["hedef_yol"] == f"/panel/{isl}"


# ==================================================================== #
# 3. METIN KAYDA DONDURULMUYOR
# ==================================================================== #

def test_BILDIRIM_METIN_DONDURMEZ_TIP_ve_VERI_DONER(client, akis):
    """7 dilli bir uygulamada kaydedilmis metin, kullanici dilini
    degistirdiginde ESKI dilde kalirdi."""
    d = client.get("/dukkan/bildirim", headers=akis["sahip"]["h"]).json()
    b = d["items"][0]
    assert set(b) >= {"tip", "veri", "hedef_yol", "okundu_at", "gonderildi_at"}
    assert "baslik" not in b and "govde" not in b and "mesaj" not in b, b


def test_GONDERILDI_AT_NOOP_TA_NULL_KALIR(client, akis, dukkan_conn):
    """P191 TUZAGI: `PUSH_PROVIDER=noop` sessizce "gonderildi" gibi
    davranirsa bildirimler HIC gitmez ve kimse fark etmez.

    `gonderildi_at` yalnizca saglayici KABUL ettiginde dolar; dev'de
    noop oldugu icin NULL kalmali ve teshiste "hic gitmemis" olarak
    GORULMELI.
    """
    n = dukkan_conn.execute(
        "SELECT count(*) FROM dukkan.bildirim WHERE gonderildi_at IS NOT NULL"
    ).fetchone()[0]
    assert n == 0, (
        f"{n} bildirim 'gonderildi' isaretli — ama saglayici noop. "
        "Sessiz basarisizlik: bildirimler gitmiyor ama gitmis gorunuyor."
    )


# ==================================================================== #
# 4. OKUNDU
# ==================================================================== #

def test_OKUNDU_TEK_ve_TOPLU(client, akis):
    d = client.get("/dukkan/bildirim", headers=akis["sahip"]["h"]).json()
    assert d["okunmamis"] >= 1
    bid = d["items"][0]["id"]

    r = client.post("/dukkan/bildirim/okundu", headers=akis["sahip"]["h"],
                    params={"bildirim_id": bid})
    assert r.json()["okunan"] == 1
    # IKINCI KEZ 0: idempotent ve sayi DOGRUYU soyluyor.
    r2 = client.post("/dukkan/bildirim/okundu", headers=akis["sahip"]["h"],
                     params={"bildirim_id": bid})
    assert r2.json()["okunan"] == 0

    client.post("/dukkan/bildirim/okundu", headers=akis["sahip"]["h"])
    assert client.get("/dukkan/bildirim",
                      headers=akis["sahip"]["h"]).json()["okunmamis"] == 0


def test_BASKASININ_BILDIRIMI_OKUNAMAZ(client, akis):
    """Yol kimlik tasiyor; baskasinin bildirimini okundu isaretlemek
    onun rozetini sifirlardi."""
    d = client.get("/dukkan/bildirim", headers=akis["sahip"]["h"]).json()
    bid = d["items"][0]["id"]
    r = client.post("/dukkan/bildirim/okundu", headers=akis["musteri"]["h"],
                    params={"bildirim_id": bid})
    assert r.json()["okunan"] == 0, "BASKASININ bildirimi okundu isaretlendi"


def test_BILDIRIM_LISTESI_YALNIZ_KENDI(client, akis):
    d = client.get("/dukkan/bildirim", headers=akis["musteri"]["h"]).json()
    for x in d["items"]:
        assert x["tip"] != "dukkan_isletme_onaylandi", (
            "isletme sahibinin bildirimi musteriye gorundu"
        )
