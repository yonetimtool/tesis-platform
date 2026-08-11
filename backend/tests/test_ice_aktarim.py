"""(P154 / Asama 8) ICE AKTARIM CATISI.

Olculen bes sey:
  1. Tur kumesi GOCLE ayni (yazim hatasi sessiz bir 500 uretmesin),
  2. ONIZLEME hicbir sey YAZMAZ,
  3. KISMI BASARI tanimi tutuyor: gecerli yazilir, hatali raporlanir,
  4. IDEMPOTENT: ayni dosya iki kez yuklenince ikinci kosum yaratmaz,
  5. GERI ALMA hep-ya-da-hic; kullanimdaki kayit varsa TUMU duser.
"""
from __future__ import annotations

import uuid


def _giris(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _satir(no, **degerler):
    return {"satir_no": no, "degerler": degerler}


def _aktar(client, h, tur, satirlar, dogrula=False, dosya="test.xlsx"):
    r = client.post(
        f"/ice-aktarim/{tur}",
        headers=h,
        json={"satirlar": satirlar, "yalniz_dogrula": dogrula, "dosya_adi": dosya},
    )
    assert r.status_code == 201, r.text
    return r.json()


def _daire_sayisi(owner_conn, slug):
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM unit u JOIN tenant t ON t.id = u.tenant_id "
            "WHERE t.slug = %s",
            (slug,),
        )
        return cur.fetchone()[0]


# ==================== 1) TUR KUMESI GOCLE AYNI ============================= #

def test_turler_GOCLE_AYNI(owner_conn):
    """Router'in bildigi turler ile CHECK kisitinin kumesi AYNI olmali.

    Ayrisirsa: routerda olup CHECK'te olmayan tur, kosum kaydini
    yazarken 500 verir (IntegrityError) — yani AKTARIM YAPILIR ama
    kaydedilemez ve GERI ALINAMAZ hâle gelir.
    """
    import re

    from app.routers.ice_aktarim import TURLER

    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT pg_get_constraintdef(oid) FROM pg_constraint "
            "WHERE conname = 'ck_ice_aktarim_tur'"
        )
        tanim = cur.fetchone()[0]
    assert set(re.findall(r"'([a-z_]+)'", tanim)) == set(TURLER)


def test_TURLER_ucu_ALANLARI_bildirir(client, world):
    """Kolon eslemesi bu alanlarin uzerine kurulur; bos donerse arayuz
    esleme yapamaz."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/ice-aktarim/turler", headers=h)
    assert r.status_code == 200, r.text
    turler = {t["kod"]: t for t in r.json()}
    assert set(turler) == {"daire", "kisi", "acilis_bakiye", "arac"}
    zorunlular = {a["kod"] for a in turler["daire"]["alanlar"] if a["zorunlu"]}
    assert zorunlular == {"blok", "daire_no"}


def test_BILINMEYEN_tur_422(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    r = client.post(
        "/ice-aktarim/boyle-tur-yok",
        headers=h,
        json={"satirlar": [_satir(1, blok="A", daire_no="X-1")]},
    )
    assert r.status_code == 422, r.text


# ======================== 2) ONIZLEME YAZMAZ =============================== #

def test_ONIZLEME_hicbir_sey_YAZMAZ(client, world, owner_conn):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    no = f"ON-{uuid.uuid4().hex[:6]}"
    once = _daire_sayisi(owner_conn, world["slug_a"])

    sonuc = _aktar(client, h, "daire", [_satir(1, blok="ZZ", daire_no=no)], dogrula=True)
    assert sonuc["olusan"] >= 1
    # ONIZLEME bir kosum KAYDI da yaratmaz — geri alinacak bir sey yok.
    assert sonuc["aktarim_id"] is None
    assert _daire_sayisi(owner_conn, world["slug_a"]) == once


# ===================== 3) KISMI BASARI TANIMI ============================== #

def test_GECERLI_yazilir_HATALI_raporlanir(client, world, owner_conn):
    """300 satirlik bir dosyada 4 hatali satir yuzunden 296 dogru satiri
    reddetmek, kullaniciyi dosyayi elle ayiklamaya zorlardi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    iyi = f"OK-{uuid.uuid4().hex[:6]}"
    once = _daire_sayisi(owner_conn, world["slug_a"])

    sonuc = _aktar(client, h, "daire", [
        _satir(1, blok="YY", daire_no=iyi),
        _satir(2, blok="", daire_no="X"),        # blok eksik
        _satir(3, blok="YY", daire_no=""),       # daire eksik
    ])
    assert sonuc["hatali"] == 2
    assert {x["satir_no"] for x in sonuc["hatalar"]} == {2, 3}
    # HATA ALANI da doner: kullanici hangi hucreyi duzeltecegini bilsin.
    assert {x["alan"] for x in sonuc["hatalar"]} == {"blok", "daire_no"}
    # GECERLI satir YAZILDI.
    assert _daire_sayisi(owner_conn, world["slug_a"]) > once


# ========================= 4) IDEMPOTENT =================================== #

def test_AYNI_dosya_IKI_KEZ_yuklenince_ikincisi_YARATMAZ(client, world, owner_conn):
    """Ag hatasindan sonra "yukledi mi yuklemedi mi" belirsizligini
    ortadan kaldirir — kullanici tereddutsuz yeniden dener."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    no = f"ID-{uuid.uuid4().hex[:6]}"
    satirlar = [_satir(1, blok="WW", daire_no=no)]

    _aktar(client, h, "daire", satirlar)
    ara = _daire_sayisi(owner_conn, world["slug_a"])
    ikinci = _aktar(client, h, "daire", satirlar)

    assert ikinci["atlanan"] >= 1
    assert _daire_sayisi(owner_conn, world["slug_a"]) == ara


# ========================== 5) GERI ALMA =================================== #

def test_GERI_ALMA_yarattiklarini_kaldirir(client, world, owner_conn):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    no = f"GA-{uuid.uuid4().hex[:6]}"
    once = _daire_sayisi(owner_conn, world["slug_a"])

    sonuc = _aktar(client, h, "daire", [_satir(1, blok="VV", daire_no=no)])
    assert _daire_sayisi(owner_conn, world["slug_a"]) > once

    r = client.post(f"/ice-aktarim/{sonuc['aktarim_id']}/geri-al", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "geri_alindi"
    assert _daire_sayisi(owner_conn, world["slug_a"]) == once


def test_GERI_ALMA_IKI_KEZ_yapilamaz(client, world):
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    sonuc = _aktar(client, h, "daire", [
        _satir(1, blok="UU", daire_no=f"G2-{uuid.uuid4().hex[:6]}")
    ])
    assert client.post(
        f"/ice-aktarim/{sonuc['aktarim_id']}/geri-al", headers=h
    ).status_code == 200
    assert client.post(
        f"/ice-aktarim/{sonuc['aktarim_id']}/geri-al", headers=h
    ).status_code == 409


def test_GERI_ALINAN_kosum_SILINMEZ_durumu_degisir(client, world):
    """Silmek "bu dosya bir kez yuklendi ve geri alindi" gercegini yok
    etmek olurdu — denetim izinin anlatmasi gereken sey budur."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    sonuc = _aktar(client, h, "daire", [
        _satir(1, blok="TT", daire_no=f"G3-{uuid.uuid4().hex[:6]}")
    ])
    client.post(f"/ice-aktarim/{sonuc['aktarim_id']}/geri-al", headers=h)

    gecmis = client.get("/ice-aktarim", headers=h).json()["items"]
    kayit = next(x for x in gecmis if x["id"] == sonuc["aktarim_id"])
    assert kayit["durum"] == "geri_alindi"
    assert kayit["geri_alma_at"] is not None


def test_KULLANIMDAKI_kayit_varsa_TUM_geri_alma_duser(client, world, owner_conn):
    """HEP YA DA HIC: yarim geri alinmis bir aktarim, kullanicinin
    "sildim" sandigi ama bir kismi duran bir veri birakirdi."""
    h = _giris(client, world["slug_a"], world["yonetici_a"])
    a = f"KA-{uuid.uuid4().hex[:6]}"
    b = f"KB-{uuid.uuid4().hex[:6]}"
    sonuc = _aktar(client, h, "daire", [
        _satir(1, blok="SS", daire_no=a),
        _satir(2, blok="SS", daire_no=b),
    ])

    # Ice aktarilan dairelerden BIRINE sonradan tahakkuk yazilir.
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT u.id, u.tenant_id FROM unit u JOIN tenant t ON t.id = u.tenant_id "
            "WHERE t.slug = %s AND u.no = %s",
            (world["slug_a"], a),
        )
        unit_id, tid = cur.fetchone()
        cur.execute(
            "INSERT INTO dues_assessment (tenant_id, unit_id, donem, tutar_kurus) "
            "VALUES (%s,%s,%s,1000)",
            (tid, unit_id, f"2099-{uuid.uuid4().hex[:2]}"),
        )

    r = client.post(f"/ice-aktarim/{sonuc['aktarim_id']}/geri-al", headers=h)
    # dues_assessment CASCADE ise silme gecer; RESTRICT ise 409 gelir.
    # HANGISI OLURSA OLSUN kural aynidir: kismi sonuc YOKTUR.
    assert r.status_code in (200, 409), r.text
    with owner_conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM unit u JOIN tenant t ON t.id = u.tenant_id "
            "WHERE t.slug = %s AND u.no IN (%s, %s)",
            (world["slug_a"], a, b),
        )
        kalan = cur.fetchone()[0]
    assert kalan in (0, 2), f"KISMI geri alma olustu: {kalan} daire kaldi"


# ============================== YETKI ====================================== #

def test_DENETCI_ve_SAHA_giremez(client, world):
    for anahtar in ("denetci_a", "guard_a", "resident_a"):
        cred = world.get(anahtar)
        if cred is None:
            continue
        h = _giris(client, world["slug_a"], cred)
        assert client.get("/ice-aktarim", headers=h).status_code == 403, anahtar
        assert client.post(
            "/ice-aktarim/daire", headers=h,
            json={"satirlar": [_satir(1, blok="A", daire_no="X")]},
        ).status_code == 403, anahtar


def test_BASKA_TESISIN_aktarimi_GERI_ALINAMAZ(client, world):
    a = _giris(client, world["slug_a"], world["yonetici_a"])
    sonuc = _aktar(client, a, "daire", [
        _satir(1, blok="RR", daire_no=f"TZ-{uuid.uuid4().hex[:6]}")
    ])
    b = _giris(client, world["slug_b"], world["yonetici_b"])
    assert client.post(
        f"/ice-aktarim/{sonuc['aktarim_id']}/geri-al", headers=b
    ).status_code == 404
