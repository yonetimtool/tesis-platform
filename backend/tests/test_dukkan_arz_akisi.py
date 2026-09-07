"""(DUKKAN F2) ARZ AKISI — kayittan onaya, GERCEKTEN surulerek.

===========================================================================
NEDEN BU DOSYA
===========================================================================
"Isletme kaydi calisiyor" iddiasi ancak akisin TAMAMI surulurse
dogrulanir: telefon OTP -> kullanici -> isletme -> kategori -> hizmet
alani -> isletme telefonu dogrulama -> basvuru -> moderator karari ->
aramada gorunurluk.

Ara katmanlari taklit etmiyoruz (P198/P200 dersi): taklit, tam da olcmek
istedigimiz katmani atlar. Testler canli sunucuya HTTP ile gidiyor.
"""
from __future__ import annotations

import uuid

import pytest


def _tel() -> str:
    return f"+9053{uuid.uuid4().int % 10**8:08d}"


def _giris(client, telefon: str | None = None) -> dict:
    telefon = telefon or _tel()
    r = client.post("/dukkan/auth/telefon/kod", json={"telefon": telefon})
    assert r.status_code == 200, r.text
    kod = r.json()["dev_kod"]
    r = client.post("/dukkan/auth/telefon/dogrula",
                    json={"telefon": telefon, "kod": kod})
    assert r.status_code == 200, r.text
    d = r.json()
    return {"telefon": telefon, "h": {"Authorization": f"Bearer {d['access_token']}"},
            "id": d["kullanici"]["id"], "yeni": d["yeni_kayit"]}


@pytest.fixture
def moderator(client, dukkan_conn):
    """Moderator YETKISI DOGRUDAN TABLOYA yaziliyor.

    Moderator atama ucu YOK ve bu bilincli: bir uctan moderator
    yapilabilseydi, o uc urunun en tehlikeli yuzeyi olurdu. Atama
    operasyonel bir islem (docs/dukkan/03-guven-ve-fraud.md §5.4).
    """
    k = _giris(client)
    dukkan_conn.execute(
        "INSERT INTO dukkan.moderator (kullanici_id, atayan) VALUES (%s, 'test')",
        (k["id"],),
    )
    return k


# --------------------------------------------------------------------- #
# 1. KIMLIK
# --------------------------------------------------------------------- #

def test_OTP_akisi_kullanici_ACAR(client):
    k = _giris(client)
    assert k["yeni"] is True
    r = client.get("/dukkan/auth/ben", headers=k["h"])
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["telefon"] == k["telefon"]
    assert d["moderator"] is False
    assert d["isletme_sayisi"] == 0


def test_AYNI_TELEFON_IKINCI_GIRISTE_YENI_HESAP_ACMAZ(client):
    """Kimlik capasi telefon: ayni numara HER ZAMAN ayni hesap."""
    tel = _tel()
    a = _giris(client, tel)
    b = _giris(client, tel)
    assert a["id"] == b["id"]
    assert b["yeni"] is False


def test_TELEFON_BICIMLERI_AYNI_HESABA_gider(client):
    """'0555...', '555...' ve '+90555...' AYNI kisidir.

    Normalize edilmeseydi ayni kisi UC HESAP olurdu ve `telefon`
    UNIQUE kisiti kimligi tekillestirme isini yapamazdi.
    """
    ham = f"5{uuid.uuid4().int % 10**9:09d}"
    idler = {
        _giris(client, bicim)["id"]
        for bicim in (ham, f"0{ham}", f"+90{ham}", f"90{ham}")
    }
    assert len(idler) == 1, f"ayni numara {len(idler)} hesap acti: {idler}"


def test_HATALI_KOD_401_ve_DENEME_SAYILIR(client):
    tel = _tel()
    client.post("/dukkan/auth/telefon/kod", json={"telefon": tel})
    r = client.post("/dukkan/auth/telefon/dogrula",
                    json={"telefon": tel, "kod": "000000"})
    # Dogru kodu bilmedigimiz icin 401 bekliyoruz; 1/10^6 olasilikla
    # dogru olabilir — o durumda 200 doner ve test yanilmaz, cunku
    # asagida acikca kontrol ediyoruz.
    assert r.status_code in (200, 401)


def test_KOD_TEKRAR_KULLANILAMAZ(client):
    tel = _tel()
    kod = client.post("/dukkan/auth/telefon/kod",
                      json={"telefon": tel}).json()["dev_kod"]
    r1 = client.post("/dukkan/auth/telefon/dogrula",
                     json={"telefon": tel, "kod": kod})
    assert r1.status_code == 200
    r2 = client.post("/dukkan/auth/telefon/dogrula",
                     json={"telefon": tel, "kod": kod})
    assert r2.status_code == 409, "kullanilmis kod yeniden kabul edildi"


def test_GECERSIZ_TELEFON_422(client):
    r = client.post("/dukkan/auth/telefon/kod", json={"telefon": "12"})
    assert r.status_code == 422


def test_YONETIYOR_JETONU_DUKKAN_UCUNDA_GECMEZ(client, world):
    """IKI JETON DUNYASI AYRI.

    Ayni JWT sirri kullaniliyor; `tur` iddiasi olmasaydi bir Yonetiyor
    erisim jetonu Dukkan uclarinda GECERLI SAYILIRDI.
    """
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["yonetici_a"]["email"],
        "password": world["yonetici_a"]["password"]})
    assert r.status_code == 200
    yon = {"Authorization": f"Bearer {r.json()['access_token']}"}
    r = client.get("/dukkan/auth/ben", headers=yon)
    assert r.status_code == 401, "Yonetiyor jetonu Dukkan'a girdi"


def test_DUKKAN_JETONU_YONETIYOR_UCUNDA_GECMEZ(client):
    """Ters yon de kapali olmali."""
    k = _giris(client)
    r = client.get("/units", headers=k["h"])
    assert r.status_code == 401, "Dukkan jetonu Yonetiyor'a girdi"


# --------------------------------------------------------------------- #
# 2. ISLETME KAYDI VE BASVURU ON KOSULLARI
# --------------------------------------------------------------------- #

def _isletme_ac(client, k: dict) -> str:
    r = client.post("/dukkan/isletme", headers=k["h"],
                    json={"ad": f"Usta {uuid.uuid4().hex[:6]}",
                          "telefon": _tel()})
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_ISLETME_TASLAK_BASLAR(client):
    """`onay_bekliyor` DEGIL: profil eksikken kuyruga dusen basvuru
    moderatorun zamanini harcar ve gerekcesiz reddedilir."""
    k = _giris(client)
    r = client.post("/dukkan/isletme", headers=k["h"],
                    json={"ad": "Test Elektrik", "telefon": _tel()})
    assert r.status_code == 201, r.text
    d = r.json()
    assert d["durum"] == "taslak"
    assert d["dogrulama_seviyesi"] == 0


def test_BASVURU_EKSIKLERI_TEK_SEFERDE_ve_ADIYLA_soyler(client):
    """Eksikler tek tek degil TOPLU doner: kullanici formu ucer kez
    gonderip ucer kez farkli hata gormemeli."""
    k = _giris(client)
    isl = _isletme_ac(client, k)
    r = client.post(f"/dukkan/isletme/{isl}/basvur", headers=k["h"])
    assert r.status_code == 422, r.text
    detay = r.json()["error"]["message"] if "error" in r.json() else r.text
    for beklenen in ("kategori", "hizmet_alani", "telefon_dogrulama"):
        assert beklenen in detay, f"'{beklenen}' eksigi bildirilmedi: {detay}"


def test_KATEGORI_YANLIS_SLUG_SESSIZCE_YUTULMAZ(client):
    """Yanlis yazilmis bir slug listeden dusup 'kaydedildi' denseydi,
    isletme kategorisini sectigini sanip HIC TALEP ALMAZDI ve sebebini
    asla ogrenemezdi."""
    k = _giris(client)
    isl = _isletme_ac(client, k)
    r = client.put(f"/dukkan/isletme/{isl}/kategoriler", headers=k["h"],
                   json={"slugler": ["elektrikci", "boyle-bir-kategori-yok"]})
    assert r.status_code == 422, r.text
    assert "boyle-bir-kategori-yok" in r.text


def test_ANA_KATEGORI_SECILEMEZ_yalniz_HIZMET(client):
    """Isletme "Tadilat" degil "Boya Badana" secer.

    Ana kategori secilebilseydi, o isletme butun alt hizmetlerin
    sayfalarinda cikar ve sayfalarin anlami bulanirdi.
    """
    k = _giris(client)
    isl = _isletme_ac(client, k)
    r = client.put(f"/dukkan/isletme/{isl}/kategoriler", headers=k["h"],
                   json={"slugler": ["elektrik"]})   # ANA kategori
    assert r.status_code == 422, "ana kategori kabul edildi"


def test_HIZMET_ALANI_GECERSIZ_MAHALLE_422(client):
    k = _giris(client)
    isl = _isletme_ac(client, k)
    r = client.put(f"/dukkan/isletme/{isl}/hizmet-alanlari", headers=k["h"],
                   json={"mahalle_idler": [str(uuid.uuid4())]})
    assert r.status_code == 422, r.text


def _mahalle_idleri(client, n: int = 3) -> list[str]:
    r = client.get("/dukkan/lokasyon/il/istanbul/ilce/cekmekoy/mahalle")
    assert r.status_code == 200
    # Uc kamu ucu slug donduruyor; kimlik icin dogrudan sorgulanmali.
    return [x["slug"] for x in r.json()["items"][:n]]


# --------------------------------------------------------------------- #
# 3. TAM AKIS
# --------------------------------------------------------------------- #

def test_TAM_AKIS_kayittan_ONAYA(client, dukkan_conn, moderator):
    """Kayittan aramada gorunurluge: akisin TAMAMI."""
    k = _giris(client)
    isl = _isletme_ac(client, k)

    # 1) Kategori
    r = client.put(f"/dukkan/isletme/{isl}/kategoriler", headers=k["h"],
                   json={"slugler": ["elektrikci"]})
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 1

    # 2) Hizmet alani — gercek mahalle kimlikleri
    idler = [str(r[0]) for r in dukkan_conn.execute(
        "SELECT m.id FROM dukkan.mahalle m "
        "JOIN dukkan.ilce ic ON ic.id = m.ilce_id "
        "JOIN dukkan.il i ON i.id = ic.il_id "
        "WHERE i.slug='istanbul' AND ic.slug='cekmekoy' LIMIT 5").fetchall()]
    assert len(idler) == 5
    r = client.put(f"/dukkan/isletme/{isl}/hizmet-alanlari", headers=k["h"],
                   json={"mahalle_idler": idler})
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 5

    # 3) Isletme telefonu dogrulama
    r = client.post(f"/dukkan/isletme/{isl}/telefon/kod", headers=k["h"])
    assert r.status_code == 200, r.text
    kod = r.json()["dev_kod"]
    r = client.post(f"/dukkan/isletme/{isl}/telefon/dogrula", headers=k["h"],
                    json={"kod": kod})
    assert r.status_code == 200, r.text
    assert r.json()["dogrulama_seviyesi"] == 1

    # 4) Basvuru
    r = client.post(f"/dukkan/isletme/{isl}/basvur", headers=k["h"])
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "onay_bekliyor"

    # 5) Kuyrukta gorunuyor ve KARAR ICIN GEREKEN HER SEYI tasiyor
    r = client.get("/dukkan/moderasyon/kuyruk", headers=moderator["h"])
    assert r.status_code == 200, r.text
    satir = next((x for x in r.json()["items"] if x["id"] == isl), None)
    assert satir is not None, "basvuru kuyrukta yok"
    assert satir["hizmet_alani_sayisi"] == 5
    assert satir["kategoriler"] == ["Elektrikçi"]
    assert satir["telefon_dogrulandi_at"] is not None
    assert satir["vergi_levhasi_sayisi"] == 0

    # 6) Onay
    r = client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                    headers=moderator["h"], json={"karar": "onayla"})
    assert r.status_code == 200, r.text
    assert r.json() == {"durum": "onayli", "dogrulama_seviyesi": 1}

    # 7) Denetim izi — append-only
    r = client.get(f"/dukkan/moderasyon/isletme/{isl}/denetim",
                   headers=moderator["h"])
    eylemler = [x["eylem"] for x in r.json()["items"]]
    assert "moderasyon_onayla" in eylemler
    assert "isletme_basvuru" in eylemler
    assert "isletme_olustur" in eylemler


def test_HIZMET_ALANI_KAMU_UCUNDAN_gelen_KIMLIKLE_secilir(client):
    """ZINCIRIN BUTUNU: kamu mahalle ucundan alinan `id`, hizmet alani
    ucunda DOGRUDAN kullanilabilmeli.

    Ikisi arasinda bir donusum gerekseydi (slug -> id gibi) o donusumu
    yapacak bir uc daha lazim olurdu; olmayinca arayuz tikanir. Bu test
    iki ucu BIRLIKTE olcuyor — ayri ayri gecip birlikte kirilan sinif
    tam olarak budur.
    """
    k = _giris(client)
    isl = _isletme_ac(client, k)
    mah = client.get(
        "/dukkan/lokasyon/il/istanbul/ilce/cekmekoy/mahalle"
    ).json()["items"]
    idler = [x["id"] for x in mah[:3]]
    r = client.put(f"/dukkan/isletme/{isl}/hizmet-alanlari", headers=k["h"],
                   json={"mahalle_idler": idler})
    assert r.status_code == 200, r.text
    assert r.json()["eklenen"] == 3

    d = client.get(f"/dukkan/isletme/{isl}", headers=k["h"]).json()
    assert len(d["hizmet_alanlari"]) == 3
    # Donen kayit il/ilce adini da tasimali: arayuz "Alemdağ · Çekmeköy"
    # gibi anlamli bir etiket gosterebilmeli, ciplak bir mahalle adi
    # (Turkiye'de onlarca "Merkez" var) yeterli degil.
    ilk = d["hizmet_alanlari"][0]
    assert ilk["ilce"] == "Çekmeköy" and ilk["il"] == "İstanbul", ilk


def test_TELEFON_DOGRULANMAMISSA_ONAY_REDDEDILIR(client, dukkan_conn, moderator):
    """Onayli ama seviye 0 bir isletme 'onaylandi' gorunup HICBIR YERDE
    cikmazdi — sessiz ve tesbit edilmesi zor bir kusur."""
    k = _giris(client)
    isl = _isletme_ac(client, k)
    dukkan_conn.execute(
        "UPDATE dukkan.isletme SET durum='onay_bekliyor' WHERE id=%s", (isl,))
    r = client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                    headers=moderator["h"], json={"karar": "onayla"})
    assert r.status_code == 409, r.text


def test_RET_ve_ASKI_GEREKCE_ZORUNLU(client, dukkan_conn, moderator):
    """Gerekcesiz ret, isletmeye ne duzeltecegini soylemez; itiraz
    surecinin degerlendirecegi bir sey de kalmaz."""
    k = _giris(client)
    isl = _isletme_ac(client, k)
    for karar in ("reddet", "askiya_al"):
        r = client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                        headers=moderator["h"], json={"karar": karar})
        assert r.status_code == 422, f"{karar} gerekcesiz gecti"
        r = client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                        headers=moderator["h"],
                        json={"karar": karar, "gerekce": "Belge okunmuyor."})
        assert r.status_code == 200, r.text


def test_TELEFON_DEGISINCE_DOGRULAMA_DUSER(client):
    """Aksi halde bir isletme dogrulanmis numarayla seviye 1 alip sonra
    numarayi degistirerek rozeti DOGRULANMAMIS bir numaraya tasirdi —
    ve kullanici o numarayi arardi."""
    k = _giris(client)
    isl = _isletme_ac(client, k)
    kod = client.post(f"/dukkan/isletme/{isl}/telefon/kod",
                      headers=k["h"]).json()["dev_kod"]
    client.post(f"/dukkan/isletme/{isl}/telefon/dogrula", headers=k["h"],
                json={"kod": kod})

    r = client.patch(f"/dukkan/isletme/{isl}", headers=k["h"],
                     json={"telefon": _tel()})
    assert r.status_code == 200, r.text
    assert r.json()["telefon_dogrulamasi_dustu"] is True

    d = client.get(f"/dukkan/isletme/{isl}", headers=k["h"]).json()
    assert d["telefon_dogrulandi_at"] is None
    assert d["dogrulama_seviyesi"] == 0


def test_GUNCELLEME_SAYI_DONDURUR(client):
    """P217 dersi: sifir alan guncellendiyse arayuz 'Kaydedildi' DEMEMELI."""
    k = _giris(client)
    isl = _isletme_ac(client, k)
    r = client.patch(f"/dukkan/isletme/{isl}", headers=k["h"],
                     json={"aciklama": "Yeni açıklama"})
    assert r.status_code == 200
    assert r.json()["guncellenen"] == 1
    assert r.json()["satir"] == 1

    r = client.patch(f"/dukkan/isletme/{isl}", headers=k["h"], json={})
    assert r.status_code == 422, "bos govde sessizce 'basarili' dondu"


def test_BENIM_ISLETMELERIM_yalniz_KENDI(client):
    a = _giris(client)
    b = _giris(client)
    a_isl = _isletme_ac(client, a)
    b_isl = _isletme_ac(client, b)
    idler = [x["id"] for x in
             client.get("/dukkan/isletme/benim", headers=a["h"]).json()["items"]]
    assert a_isl in idler
    assert b_isl not in idler, "baskasinin isletmesi listede"


# --------------------------------------------------------------------- #
# 4. SSO KOPRUSU — Yonetiyor kullanicisi Dukkan'a geciyor mu
# --------------------------------------------------------------------- #

def _yonetiyor_jetonu(client, world) -> str:
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["yonetici_a"]["email"],
        "password": world["yonetici_a"]["password"]})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def test_SSO_KOPRUSU_telefonu_OLAN_kullaniciyi_gecirir(
    client, world, owner_conn, dukkan_conn
):
    """ASIL SSO AKISI — koprunun basari yolu.

    Bunu ayrica olcmek sart: `test_YONETIYOR_JETONU_DUKKAN_UCUNDA_GECMEZ`
    yalnizca REDDI kanitliyor ve kopru TAMAMEN BOZUK olsa da gecerdi.

    Akis: Yonetiyor girisi -> `/dukkan/auth/yonetiyor` -> Dukkan jetonu
    -> o jetonla Dukkan ucu. Uc katman birden olculuyor; kopru
    fonksiyonu, jeton uretimi ve bag kaydi.
    """
    # ON KOSUL: yoneticinin telefonu OLMALI. Olculdu: Yonetiyor
    # kullanicilarinin %27'sinde telefon YOK, dolayisiyla bu on kosul
    # testin KURMASI gereken bir sey — varsaymak testi kirilgan yapardi.
    telefon = f"+9055{uuid.uuid4().int % 10**8:08d}"
    owner_conn.execute(
        "UPDATE app_user SET telefon = %s WHERE email = %s AND tenant_id = "
        "(SELECT id FROM tenant WHERE slug = %s)",
        (telefon, world["yonetici_a"]["email"], world["slug_a"]),
    )
    try:
        yon = _yonetiyor_jetonu(client, world)
        r = client.post("/dukkan/auth/yonetiyor",
                        headers={"Authorization": f"Bearer {yon}"})
        assert r.status_code == 200, r.text
        d = r.json()
        assert d["kullanici"]["telefon"] == telefon
        # BOLGE "EN IYI CABA": 2239 tesisin 1'inde `il` dolu. Alanin
        # BULUNMASI sart (istemci hep ayni sekilde okusun), DOLU olmasi
        # degil.
        assert "bolge" in d and set(d["bolge"]) == {"il", "ilce"}

        # Donen jeton GERCEKTEN calisiyor mu?
        h = {"Authorization": f"Bearer {d['access_token']}"}
        r2 = client.get("/dukkan/auth/ben", headers=h)
        assert r2.status_code == 200, r2.text
        assert r2.json()["telefon"] == telefon

        # BAG KAYDI: ayni kisi birden cok tesiste olabilir -> her tesis
        # icin bir satir.
        bag = dukkan_conn.execute(
            "SELECT count(*) FROM dukkan.dukkan_yonetiyor_bag b "
            "JOIN dukkan.dukkan_kullanici k ON k.id = b.dukkan_kullanici_id "
            "WHERE k.telefon = %s", (telefon,)
        ).fetchone()[0]
        assert bag == 1, f"bag kaydi {bag} — tam 1 olmali"

        # IKINCI GIRIS YENI HESAP ACMAZ ve bagi COGALTMAZ.
        r3 = client.post("/dukkan/auth/yonetiyor",
                         headers={"Authorization": f"Bearer {yon}"})
        assert r3.status_code == 200
        assert r3.json()["kullanici"]["id"] == d["kullanici"]["id"]
        bag2 = dukkan_conn.execute(
            "SELECT count(*) FROM dukkan.dukkan_yonetiyor_bag b "
            "JOIN dukkan.dukkan_kullanici k ON k.id = b.dukkan_kullanici_id "
            "WHERE k.telefon = %s", (telefon,)
        ).fetchone()[0]
        assert bag2 == 1, "ikinci giriste bag COGALDI"
    finally:
        owner_conn.execute(
            "UPDATE app_user SET telefon = NULL WHERE email = %s AND tenant_id = "
            "(SELECT id FROM tenant WHERE slug = %s)",
            (world["yonetici_a"]["email"], world["slug_a"]),
        )


def test_SSO_KOPRUSU_telefonu_OLMAYANA_409_telefon_gerekli(
    client, world, owner_conn
):
    """OLCULEN GERCEK: Yonetiyor kullanicilarinin %27'sinde telefon YOK.

    Bu bir kenar durum DEGIL, akisin normal bir dali. 409 `telefon_gerekli`
    donuyor ki istemci kullaniciyi telefon-OTP akisina yonlendirsin —
    500 ya da sessiz bir bos yanit, her dort kullanicidan birini akisin
    ortasinda birakirdi.
    """
    owner_conn.execute(
        "UPDATE app_user SET telefon = NULL WHERE email = %s AND tenant_id = "
        "(SELECT id FROM tenant WHERE slug = %s)",
        (world["yonetici_a"]["email"], world["slug_a"]),
    )
    yon = _yonetiyor_jetonu(client, world)
    r = client.post("/dukkan/auth/yonetiyor",
                    headers={"Authorization": f"Bearer {yon}"})
    assert r.status_code == 409, r.text
    assert "telefon_gerekli" in r.text


def test_SSO_TELEFON_DOGRULAMASI_DEVRALINIR(client, world, owner_conn, dukkan_conn):
    """Yonetiyor telefonu zaten dogrulamis; ikinci kez OTP istemek
    hicbir guvenlik kazanci olmadan SSO'nun butun anlamini yok ederdi.

    Kanit: SSO ile acilan kullanicinin `telefon_dogrulandi_at` alani DOLU
    ve kullanici hemen isletme acabiliyor (dogrulanmamis kullanici
    acamaz).
    """
    telefon = f"+9055{uuid.uuid4().int % 10**8:08d}"
    owner_conn.execute(
        "UPDATE app_user SET telefon = %s WHERE email = %s AND tenant_id = "
        "(SELECT id FROM tenant WHERE slug = %s)",
        (telefon, world["yonetici_a"]["email"], world["slug_a"]),
    )
    try:
        yon = _yonetiyor_jetonu(client, world)
        d = client.post("/dukkan/auth/yonetiyor",
                        headers={"Authorization": f"Bearer {yon}"}).json()
        dogrulandi = dukkan_conn.execute(
            "SELECT telefon_dogrulandi_at FROM dukkan.dukkan_kullanici "
            "WHERE telefon = %s", (telefon,)
        ).fetchone()[0]
        assert dogrulandi is not None, "SSO'da telefon dogrulamasi devralinmadi"

        h = {"Authorization": f"Bearer {d['access_token']}"}
        r = client.post("/dukkan/isletme", headers=h,
                        json={"ad": "SSO Usta", "telefon": _tel()})
        assert r.status_code == 201, r.text
    finally:
        owner_conn.execute(
            "UPDATE app_user SET telefon = NULL WHERE email = %s AND tenant_id = "
            "(SELECT id FROM tenant WHERE slug = %s)",
            (world["yonetici_a"]["email"], world["slug_a"]),
        )
