"""(DUKKAN F4) KVKK GORUNURLUK — tasarimin EN KRITIK tek kurali.

===========================================================================
NEDEN BU DOSYA AYRI
===========================================================================
`docs/dukkan/04-api-sozlesmesi.md` §4 bes kilit testi ISIMLE sayiyor.
Hepsi burada ve hepsi AKISI GERCEKTEN SUREREK olculuyor.

Kural SUNUCUDA olmak zorunda: arayuzde gizlemek YETMEZ, cunku ikinci
istemci (mobil) o gizlemeyi tasimaz. Bu dosya sunucunun ne dondurdugune
bakiyor — arayuze hic bakmiyor.

===========================================================================
NE OLURSA SIZINTI SAYILIR
===========================================================================
Yanit GOVDESININ TAMAMINDA arama yapiliyor, alan alan degil. Bir uc
sizintiyi `items[].id` yerine `meta`, `ozet` ya da ic ice bir alanda
yapabilir; alan alan bakmak, bakmayi unuttugumuz alani savunmasiz
birakirdi. (Ayni yaklasim `test_tesis_izolasyonu_tarama.py`de yazili.)
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
                    json={"telefon": tel, "kod": kod,
                          "ad_soyad": "Sakin Test"}).json()
    return {"h": {"Authorization": f"Bearer {d['access_token']}"},
            "id": d["kullanici"]["id"], "telefon": tel}


@pytest.fixture
def moderator(client, dukkan_conn):
    k = _giris(client)
    dukkan_conn.execute(
        "INSERT INTO dukkan.moderator (kullanici_id, atayan) VALUES (%s,'kvkk') "
        "ON CONFLICT DO NOTHING", (k["id"],))
    return k


def _mahalle(dukkan_conn, ilce="cekmekoy"):
    r = dukkan_conn.execute(
        "SELECT m.id, m.slug, ic.slug, i.slug FROM dukkan.mahalle m "
        "JOIN dukkan.ilce ic ON ic.id = m.ilce_id "
        "JOIN dukkan.il i ON i.id = ic.il_id "
        "WHERE i.slug='istanbul' AND ic.slug=%s ORDER BY m.slug LIMIT 1",
        (ilce,)).fetchone()
    return {"id": str(r[0]), "mahalle": r[1], "ilce": r[2], "il": r[3]}


def _isletme_yayinda(client, dukkan_conn, moderator, mahalle_id,
                     kategori="elektrikci") -> dict:
    """Onayli bir isletme uretir. Doner: {h, id, sahip}."""
    k = _giris(client)
    isl = client.post("/dukkan/isletme", headers=k["h"],
                      json={"ad": f"Usta {uuid.uuid4().hex[:6]}",
                            "telefon": _tel()}).json()["id"]
    client.put(f"/dukkan/isletme/{isl}/kategoriler", headers=k["h"],
               json={"slugler": [kategori]})
    client.put(f"/dukkan/isletme/{isl}/hizmet-alanlari", headers=k["h"],
               json={"mahalle_idler": [mahalle_id]})
    kod = client.post(f"/dukkan/isletme/{isl}/telefon/kod",
                      headers=k["h"]).json()["dev_kod"]
    client.post(f"/dukkan/isletme/{isl}/telefon/dogrula", headers=k["h"],
                json={"kod": kod})
    client.post(f"/dukkan/isletme/{isl}/basvur", headers=k["h"])
    client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                headers=moderator["h"], json={"karar": "onayla"})
    return {"h": k["h"], "id": isl, "sahip": k}


ADRES = "Çatalmeşe Mah. Test Sk. No:5 Daire:7"


@pytest.fixture
def sahne(client, dukkan_conn, moderator):
    """Sakin + iki isletme + adres PAYLASILAN bir talep."""
    m = _mahalle(dukkan_conn)
    sakin = _giris(client)
    a = _isletme_yayinda(client, dukkan_conn, moderator, m["id"])
    b = _isletme_yayinda(client, dukkan_conn, moderator, m["id"])

    r = client.post("/dukkan/talep", headers=sakin["h"], json={
        "kategori_slug": "elektrikci",
        "il_slug": m["il"], "ilce_slug": m["ilce"], "mahalle_slug": m["mahalle"],
        "aciklama": "Salondaki priz çalışmıyor, acil.",
        "paylas_ad": False, "paylas_telefon": False,
        "paylas_adres": True, "acik_adres": ADRES,
    })
    assert r.status_code == 201, r.text
    return {"m": m, "sakin": sakin, "a": a, "b": b, "talep": r.json()["id"]}


# ===================================================================== #
# KILIT 1 — teklif asamasinda acik adres HICBIR YERDE gecmiyor
# ===================================================================== #

def test_KILIT1_TEKLIF_ASAMASINDA_ACIK_ADRES_YOK(client, sahne):
    """Isletme, is kabul edilmeden acik adresi GOREMEZ.

    Kullanici `paylas_adres=True` DEMIS olsa bile: o izin, adresin
    ISI ALAN ustaya acilmasi icindir — teklif veren HERKESE degil.
    """
    r = client.get(f"/dukkan/talep/{sahne['talep']}",
                   headers=sahne["a"]["h"],
                   params={"isletme_id": sahne["a"]["id"]})
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["acik_adres"] is None, "ACIK ADRES TEKLIF ASAMASINDA SIZDI"
    # GOVDENIN TAMAMINDA ara — sizinti ic ice bir alanda olabilir.
    assert ADRES not in r.text, f"adres metni govdede gecti: {r.text[:300]}"
    assert "Daire:7" not in r.text, "DAIRE NUMARASI sizdi"
    # Mahalle GORUNMELI: isletme teklif verebilmek icin bolgeyi bilmeli.
    assert d["mahalle"]["ad"], "mahalle gorunmuyor — teklif verilemez"


def test_KILIT1b_TALEP_LISTESINDE_DE_ADRES_YOK(client, sahne):
    """Isletmeye gelen talep AKISINDA da adres olmamali.

    Detay ucunu duzeltip listeyi unutmak, en olasi kacak yolu.
    """
    r = client.get(f"/dukkan/isletme/{sahne['a']['id']}/talepler",
                   headers=sahne["a"]["h"])
    assert r.status_code == 200, r.text
    assert ADRES not in r.text, "talep AKISINDA adres sizdi"
    assert "Daire:7" not in r.text
    benim = next(x for x in r.json()["items"] if x["id"] == sahne["talep"])
    assert benim["acik_adres"] is None


# ===================================================================== #
# KILIT 2 — paylas_telefon=false iken telefon HICBIR ALANDA yok
# ===================================================================== #

def test_KILIT2_PAYLAS_TELEFON_FALSE_ISE_TELEFON_YOK(client, sahne):
    for r in (
        client.get(f"/dukkan/talep/{sahne['talep']}", headers=sahne["a"]["h"],
                   params={"isletme_id": sahne["a"]["id"]}),
        client.get(f"/dukkan/isletme/{sahne['a']['id']}/talepler",
                   headers=sahne["a"]["h"]),
    ):
        assert r.status_code == 200
        assert sahne["sakin"]["telefon"] not in r.text, "TELEFON SIZDI"


def test_KILIT2b_PAYLAS_TELEFON_TRUE_ISE_GORUNUR(client, dukkan_conn, sahne):
    """Ters yonlu kanit: kural "hep gizle" DEGIL, "kullanici ne dediyse o".

    Bu test olmasa, telefonu HICBIR ZAMAN dondurmeyen bozuk bir uc da
    KILIT2'yi gecerdi.
    """
    m, sakin = sahne["m"], sahne["sakin"]
    r = client.post("/dukkan/talep", headers=sakin["h"], json={
        "kategori_slug": "elektrikci", "il_slug": m["il"],
        "ilce_slug": m["ilce"], "mahalle_slug": m["mahalle"],
        "aciklama": "Telefonumu paylaşıyorum, arayın.",
        "paylas_telefon": True, "paylas_ad": True,
    })
    talep = r.json()["id"]
    d = client.get(f"/dukkan/talep/{talep}", headers=sahne["a"]["h"],
                   params={"isletme_id": sahne["a"]["id"]}).json()
    assert d["telefon"] == sakin["telefon"], "izin verilmis telefon GORUNMUYOR"
    assert d["ad"], "izin verilmis ad gorunmuyor"


# ===================================================================== #
# KILIT 3 — teklif KABULUNDEN SONRA adres YALNIZ kabul edilene acilir
# ===================================================================== #

def test_KILIT3_KABUL_SONRASI_ADRES_ACILIR(client, sahne):
    a, b, sakin = sahne["a"], sahne["b"], sahne["sakin"]
    for isl in (a, b):
        assert client.post(
            f"/dukkan/talep/{sahne['talep']}/teklif", headers=isl["h"],
            params={"isletme_id": isl["id"]},
            json={"tutar_kurus": 150000, "mesaj": "Yarın gelebilirim."},
        ).status_code == 201

    teklifler = client.get(f"/dukkan/talep/{sahne['talep']}/teklifler",
                           headers=sakin["h"]).json()["items"]
    a_teklif = next(t for t in teklifler if t["isletme_slug"].startswith("usta"))
    # A'nin teklifini bul (isletme adina gore degil, kimlikle esle).
    a_teklif = next(
        t for t in teklifler
        if client.get(f"/dukkan/isletme/{a['id']}", headers=a["h"]).json()["slug"]
        == t["isletme_slug"]
    )
    r = client.post(f"/dukkan/teklif/{a_teklif['id']}/kabul", headers=sakin["h"])
    assert r.status_code == 200, r.text

    # KABUL EDILEN artik adresi GORUYOR.
    d = client.get(f"/dukkan/talep/{sahne['talep']}", headers=a["h"],
                   params={"isletme_id": a["id"]}).json()
    assert d["acik_adres"] == ADRES, "kabul sonrasi adres ACILMADI"
    assert d["telefon"] == sakin["telefon"], "kabul sonrasi telefon acilmadi"


# ===================================================================== #
# KILIT 4 — kabul EDILMEYEN isletme kabul sonrasi da GOREMEZ
# ===================================================================== #

def test_KILIT4_KABUL_EDILMEYEN_ADRESI_GOREMEZ(client, sahne):
    """En kolay kacirilacak kilit: "is kabul edildi" kosulunu isletmeye
    BAGLAMADAN yazmak, adresi TEKLIF VEREN HERKESE acardi."""
    a, b, sakin = sahne["a"], sahne["b"], sahne["sakin"]
    for isl in (a, b):
        client.post(f"/dukkan/talep/{sahne['talep']}/teklif", headers=isl["h"],
                    params={"isletme_id": isl["id"]},
                    json={"tutar_kurus": 100000})
    teklifler = client.get(f"/dukkan/talep/{sahne['talep']}/teklifler",
                           headers=sakin["h"]).json()["items"]
    a_slug = client.get(f"/dukkan/isletme/{a['id']}", headers=a["h"]).json()["slug"]
    a_teklif = next(t for t in teklifler if t["isletme_slug"] == a_slug)
    client.post(f"/dukkan/teklif/{a_teklif['id']}/kabul", headers=sakin["h"])

    r = client.get(f"/dukkan/talep/{sahne['talep']}", headers=b["h"],
                   params={"isletme_id": b["id"]})
    assert r.status_code == 200, r.text
    assert r.json()["acik_adres"] is None, "KABUL EDILMEYEN isletme adresi GORDU"
    assert ADRES not in r.text
    assert sahne["sakin"]["telefon"] not in r.text


# ===================================================================== #
# KILIT 5 — bir isletme BASKA isletmenin teklifini goremez
# ===================================================================== #

def test_KILIT5_ISLETME_BASKA_TEKLIFI_GOREMEZ(client, sahne):
    """Gorseydi fiyat kirma ve teklif kopyalama mumkun olurdu."""
    a, b = sahne["a"], sahne["b"]
    client.post(f"/dukkan/talep/{sahne['talep']}/teklif", headers=b["h"],
                params={"isletme_id": b["id"]},
                json={"tutar_kurus": 999000, "mesaj": "B firmasının gizli teklifi"})

    # A, teklif listesini HIC goremez (yalniz talep sahibi gorur).
    r = client.get(f"/dukkan/talep/{sahne['talep']}/teklifler", headers=a["h"])
    assert r.status_code == 403, r.text

    # A'nin talep gorunumunde de B'nin teklifi GECMEZ.
    d = client.get(f"/dukkan/talep/{sahne['talep']}", headers=a["h"],
                   params={"isletme_id": a["id"]})
    assert "999000" not in d.text
    assert "gizli teklifi" not in d.text


# ===================================================================== #
# EK: TALEP HASADI (T6) — bolgesi disindaki isletme talebi OKUYAMAZ
# ===================================================================== #

def test_BOLGE_DISI_ISLETME_TALEBI_OKUYAMAZ(client, dukkan_conn, moderator, sahne):
    """Kimse sahte isletme kurup dolandiricilik yapmak zorunda degil —
    sadece TALEPLERI OKUYARAK sakinlerin telefon ve adresini toplayabilir.

    Iki asamali gorunurluk bunun asil savunmasi; ama bolge kontrolu
    olmasaydi bir isletme TUM taleplerin aciklamasini okuyabilirdi.
    """
    uzak = _mahalle(dukkan_conn, ilce="silivri")
    yabanci = _isletme_yayinda(client, dukkan_conn, moderator, uzak["id"])
    r = client.get(f"/dukkan/talep/{sahne['talep']}", headers=yabanci["h"],
                   params={"isletme_id": yabanci["id"]})
    assert r.status_code == 403, r.text
    assert "bolgenizde_degil" in r.text


def test_ADRES_PAYLASILMAZSA_HIC_SAKLANMAZ(client, dukkan_conn, sahne):
    """KVKK veri minimizasyonu: "nasilsa gostermeyiz" diye saklamak
    gereksiz bir sizinti yuzeyi. Izin yoksa veri HIC GIRMEZ."""
    m, sakin = sahne["m"], sahne["sakin"]
    r = client.post("/dukkan/talep", headers=sakin["h"], json={
        "kategori_slug": "elektrikci", "il_slug": m["il"],
        "ilce_slug": m["ilce"], "mahalle_slug": m["mahalle"],
        "aciklama": "Adresimi paylaşmıyorum ama yazdım.",
        "paylas_adres": False, "acik_adres": "Gizli Sokak No:1",
    })
    talep = r.json()["id"]
    saklanan = dukkan_conn.execute(
        "SELECT acik_adres FROM dukkan.talep WHERE id=%s", (talep,)).fetchone()[0]
    assert saklanan is None, (
        f"izin verilmedigi halde adres VERITABANINA yazildi: {saklanan!r}"
    )


def test_VARSAYILANLAR_HEPSI_FALSE(client, dukkan_conn, sahne):
    """`paylas_*` alanlari GONDERILMEZSE `false` olmali.

    Varsayilan `true` olsaydi, formda kutuyu kaldirmayi unutan bir
    kullanici verisini PAYLASMIS olurdu.
    """
    m, sakin = sahne["m"], sahne["sakin"]
    r = client.post("/dukkan/talep", headers=sakin["h"], json={
        "kategori_slug": "elektrikci", "il_slug": m["il"],
        "ilce_slug": m["ilce"], "mahalle_slug": m["mahalle"],
        "aciklama": "Hiçbir paylaşım tercihi göndermiyorum.",
    })
    talep = r.json()["id"]
    satir = dukkan_conn.execute(
        "SELECT paylas_ad, paylas_telefon, paylas_adres FROM dukkan.talep "
        "WHERE id=%s", (talep,)).fetchone()
    assert satir == (False, False, False), satir
