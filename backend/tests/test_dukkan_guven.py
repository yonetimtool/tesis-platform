"""(DUKKAN F5) GUVEN — iki katmanli yorum, kota, sahte yorum savunmalari.

===========================================================================
NE KORUNUYOR
===========================================================================
1. IKI KATMAN AYRI: dogrulanmis ve davetli yorum ayri sayilir, agirliklari
   farklidir ve kullanici FARKI GORUR.
2. KENDINE YORUM: sahip de, isletme numarasiyla acilmis hesap da RET.
3. KOTA: sahte yorumun maliyeti GERCEK IS YAPMAYA bagli.
4. OLUMSUZ + DOGRULANMAMIS -> moderasyon (yayin GECIKIR, KAYBOLMAZ).
5. ISLETME SILEMEZ, CEVAP VEREBILIR.
6. SIKAYET KIMLIKSIZ yapilabilir.

Akis GERCEKTEN suruluyor: is tamamlanir, yorum yazilir, puan degisir.
"""
from __future__ import annotations

import uuid

import pytest


def _tel() -> str:
    return f"+9053{uuid.uuid4().int % 10**8:08d}"


def _giris(client, tel=None) -> dict:
    tel = tel or _tel()
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
        "INSERT INTO dukkan.moderator (kullanici_id, atayan) VALUES (%s,'f5') "
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


@pytest.fixture
def sahne(client, dukkan_conn, moderator):
    """Onayli isletme + tamamlanmis bir is."""
    m = _mahalle(dukkan_conn)
    sahip = _giris(client)
    isl_tel = _tel()
    isl = client.post("/dukkan/isletme", headers=sahip["h"],
                      json={"ad": f"Güven {uuid.uuid4().hex[:6]}",
                            "telefon": isl_tel}).json()["id"]
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
    slug = client.get(f"/dukkan/isletme/{isl}", headers=sahip["h"]).json()["slug"]

    musteri = _giris(client)
    talep = client.post("/dukkan/talep", headers=musteri["h"], json={
        "kategori_slug": "elektrikci", "il_slug": m["il"],
        "ilce_slug": m["ilce"], "mahalle_slug": m["mahalle"],
        "aciklama": "Güven testi için iş."}).json()["id"]
    client.post(f"/dukkan/talep/{talep}/teklif", headers=sahip["h"],
                params={"isletme_id": isl}, json={"tutar_kurus": 100000})
    tk = client.get(f"/dukkan/talep/{talep}/teklifler",
                    headers=musteri["h"]).json()["items"][0]
    is_id = client.post(f"/dukkan/teklif/{tk['id']}/kabul",
                        headers=musteri["h"]).json()["is_id"]
    client.post(f"/dukkan/is/{is_id}/tamamlandi", headers=musteri["h"])
    return {"m": m, "sahip": sahip, "isl": isl, "slug": slug,
            "isl_tel": isl_tel, "musteri": musteri, "is_id": is_id}


# ==================================================================== #
# 1. KATMAN A — DOGRULANMIS YORUM
# ==================================================================== #

def test_DOGRULANMIS_YORUM_DOGRUDAN_YAYINLANIR(client, sahne):
    """Gercek bir is var; susturmak yorum sistemini YALANCI yapardi."""
    r = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                    headers=sahne["musteri"]["h"],
                    json={"puan": 5, "metin": "Çok memnun kaldım."})
    assert r.status_code == 201, r.text
    d = r.json()
    assert d["durum"] == "yayinda"
    assert d["kaynak"] == "platform"


def test_DOGRULANMIS_OLUMSUZ_YORUM_DA_YAYINLANIR(client, sahne):
    """TERS YONLU KANIT: kural "iyi yorumu yayinla" DEGIL.

    Dogrulanmis olumsuz yorumu moderasyona dusurmek, isletmeleri
    korumak icin gercegi geciktirmek olurdu.
    """
    r = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                    headers=sahne["musteri"]["h"],
                    json={"puan": 1, "metin": "Hiç memnun kalmadım."})
    assert r.status_code == 201, r.text
    assert r.json()["durum"] == "yayinda"


def test_BIR_ISE_BIR_YORUM(client, sahne):
    client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                headers=sahne["musteri"]["h"], json={"puan": 5})
    r = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                    headers=sahne["musteri"]["h"], json={"puan": 1})
    assert r.status_code == 409, r.text


def test_TAMAMLANMAMIS_ISE_YORUM_YAZILAMAZ(client, dukkan_conn, sahne):
    """Isi yapmamis bir ustayi degerlendirmek olurdu."""
    dukkan_conn.execute(
        "UPDATE dukkan.is_kaydi SET durum='kabul' WHERE id=%s", (sahne["is_id"],))
    r = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                    headers=sahne["musteri"]["h"], json={"puan": 5})
    assert r.status_code == 409, r.text


def test_BASKASININ_ISINE_YORUM_YAZILAMAZ(client, sahne):
    yabanci = _giris(client)
    r = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                    headers=yabanci["h"], json={"puan": 5})
    assert r.status_code == 403, r.text


# ==================================================================== #
# 2. KENDINE YORUM — iki kacak yolu da kapali
# ==================================================================== #

def test_SAHIP_KENDI_ISLETMESINE_YORUM_YAZAMAZ(client, dukkan_conn, sahne):
    """Sahip, kendi isletmesinden hizmet alip yorum yazmaya calisirsa."""
    # Sahibi isin musterisi yapalim (senaryo kurulumu).
    dukkan_conn.execute(
        "UPDATE dukkan.is_kaydi SET kullanici_id=%s WHERE id=%s",
        (sahne["sahip"]["id"], sahne["is_id"]))
    r = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                    headers=sahne["sahip"]["h"], json={"puan": 5})
    assert r.status_code == 403, r.text
    assert "kendi_isletmenize" in r.text


def test_ISLETME_NUMARASIYLA_ACILAN_HESAP_YORUM_YAZAMAZ(
    client, dukkan_conn, sahne
):
    """IKINCI KACAK YOLU: sahip, ISLETME NUMARASIYLA ayri bir Dukkan
    hesabi acip kendine yorum yazabilirdi.

    Sahiplik kontrolu tek basina bunu YAKALAMAZ — hesap farkli bir
    kullanici. Telefon eslesmesi gerekiyor.
    """
    ikinci = _giris(client, tel=sahne["isl_tel"])
    dukkan_conn.execute(
        "UPDATE dukkan.is_kaydi SET kullanici_id=%s WHERE id=%s",
        (ikinci["id"], sahne["is_id"]))
    r = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                    headers=ikinci["h"], json={"puan": 5})
    assert r.status_code == 403, r.text
    assert "kendi_isletmenize" in r.text


# ==================================================================== #
# 3. KATMAN B — DAVET VE KOTA
# ==================================================================== #

def test_DAVET_KOTASI_ETKINLIGE_BAGLI(client, dukkan_conn, sahne):
    """Sahte yorumun maliyeti GERCEK IS YAPMAYA bagli.

    Kotasiz davet, "bana 50 yorum yaz" demenin platform onayli yolu
    olurdu.
    """
    r = client.get(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti/kota",
                   headers=sahne["sahip"]["h"])
    assert r.status_code == 200, r.text
    d = r.json()
    # Sahnede 1 teklif + 1 is var -> etkinlik 2.
    assert d["etkinlik"] >= 2, d
    assert d["hak"] > d["etkinlik"], "kota tabani uygulanmamis"
    assert d["kalan"] == d["hak"] - d["kullanilan"]


def test_KOTA_DOLUNCA_429_ve_DENETIME_YAZILIR(client, dukkan_conn, sahne):
    """Sessizce reddetmek kotuye kullanimi GORUNMEZ yapar — engellenen
    deneme de bir sinyaldir."""
    # Kotayi doldur: hak kadar davet gonder.
    hak = client.get(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti/kota",
                     headers=sahne["sahip"]["h"]).json()["hak"]
    for _ in range(hak):
        r = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                        headers=sahne["sahip"]["h"], json={"telefon": _tel()})
        assert r.status_code == 201, r.text

    r = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                    headers=sahne["sahip"]["h"], json={"telefon": _tel()})
    assert r.status_code == 429, r.text

    n = dukkan_conn.execute(
        "SELECT count(*) FROM dukkan.denetim WHERE eylem='kota_asimi' "
        "AND hedef_id=%s", (sahne["isl"],)).fetchone()[0]
    assert n >= 1, "kota asimi DENETIME yazilmadi"


def test_KENDI_NUMARASINA_DAVET_REDDEDILIR(client, sahne):
    """En kaba sahte yorum yolu."""
    r = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                    headers=sahne["sahip"]["h"],
                    json={"telefon": sahne["isl_tel"]})
    assert r.status_code == 403, r.text
    assert "kendi_numaraniza" in r.text


def test_DAVETLI_YORUM_AKISI(client, sahne):
    """Davet -> OTP -> yorum. Kullanicinin Dukkan hesabi OLMAYABILIR."""
    tel = _tel()
    r = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                    headers=sahne["sahip"]["h"], json={"telefon": tel})
    assert r.status_code == 201, r.text
    kod = r.json()["dev_kod"]
    # CELISKI YOK (SMS turunde olculen kusurun ayni sinifI).
    assert r.json()["gonderildi"] is (r.json()["gonderim"] == "gonderildi")

    r2 = client.post("/dukkan/yorum-daveti/dogrula", params={"telefon": tel},
                     json={"kod": kod, "puan": 5, "metin": "Teşekkürler."})
    assert r2.status_code == 201, r2.text
    assert r2.json()["kaynak"] == "davet"
    assert r2.json()["durum"] == "yayinda"


def test_DAVETLI_OLUMSUZ_YORUM_MODERASYONA_DUSER(client, sahne):
    """Rakip saldirisini (T2) SUSTURMADAN yavaslatmanin yolu:
    yayin GECIKIR, KAYBOLMAZ."""
    tel = _tel()
    kod = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                      headers=sahne["sahip"]["h"],
                      json={"telefon": tel}).json()["dev_kod"]
    r = client.post("/dukkan/yorum-daveti/dogrula", params={"telefon": tel},
                    json={"kod": kod, "puan": 1, "metin": "Kötüydü."})
    assert r.status_code == 201, r.text
    assert r.json()["durum"] == "beklemede", "olumsuz davetli yorum DOGRUDAN yayinlandi"


def test_DAVET_KODU_TEKRAR_KULLANILAMAZ(client, sahne):
    tel = _tel()
    kod = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                      headers=sahne["sahip"]["h"],
                      json={"telefon": tel}).json()["dev_kod"]
    client.post("/dukkan/yorum-daveti/dogrula", params={"telefon": tel},
                json={"kod": kod, "puan": 5})
    r = client.post("/dukkan/yorum-daveti/dogrula", params={"telefon": tel},
                    json={"kod": kod, "puan": 5})
    assert r.status_code == 409, r.text


# ==================================================================== #
# 4. IKI KATMAN AYRI GOSTERILIR
# ==================================================================== #

def test_KAMU_LISTESI_IKI_KATMANI_AYRI_SAYAR(client, sahne):
    """Kullanici "8 dogrulanmis" ile "0 dogrulanmis, 40 davetli"
    arasindaki farki KENDI okumali — karari gizlemek yerine GORUNUR
    kiliyoruz."""
    client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                headers=sahne["musteri"]["h"], json={"puan": 5})
    tel = _tel()
    kod = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                      headers=sahne["sahip"]["h"],
                      json={"telefon": tel}).json()["dev_kod"]
    client.post("/dukkan/yorum-daveti/dogrula", params={"telefon": tel},
                json={"kod": kod, "puan": 4})

    r = client.get(f"/dukkan/isletme-profil/{sahne['slug']}/yorum")
    assert r.status_code == 200, r.text
    d = r.json()
    assert d["ozet"]["dogrulanmis"] == 1
    assert d["ozet"]["davetli"] == 1
    # HER YORUMDA `kaynak` DONER: arayuz rozet farkini cizebilsin.
    assert {x["kaynak"] for x in d["items"]} == {"platform", "davet"}
    # DOGRULANMIS ONCE: siralama okuyucuya en guvenilir bilgiyi once verir.
    assert d["items"][0]["kaynak"] == "platform"


def test_AGIRLIK_FARKI_PUANA_YANSIYOR(client, dukkan_conn, sahne):
    """Davetli yorum, dogrulanmisin UCTE BIRI kadar agirlik tasimali.

    Olcum: ayni puanli iki yorum, farkli kaynaklarla eklendiginde
    ortalama_puan AYNI kalir ama GUVEN CARPANI farkli olur — bu yuzden
    `siralama_puani` uzerinden olcuyoruz.
    """
    # Once yalniz DAVETLI 5 puan.
    tel = _tel()
    kod = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                      headers=sahne["sahip"]["h"],
                      json={"telefon": tel}).json()["dev_kod"]
    client.post("/dukkan/yorum-daveti/dogrula", params={"telefon": tel},
                json={"kod": kod, "puan": 5})
    davetli_puan = dukkan_conn.execute(
        "SELECT siralama_puani FROM dukkan.isletme WHERE id=%s",
        (sahne["isl"],)).fetchone()[0]

    # Simdi DOGRULANMIS 5 puan ekle.
    client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                headers=sahne["musteri"]["h"], json={"puan": 5})
    ikisi_puan = dukkan_conn.execute(
        "SELECT siralama_puani FROM dukkan.isletme WHERE id=%s",
        (sahne["isl"],)).fetchone()[0]

    assert ikisi_puan > davetli_puan, (
        f"dogrulanmis yorum puani ARTIRMADI ({davetli_puan} -> {ikisi_puan})"
    )


# ==================================================================== #
# 5. CEVAP HAKKI — silme YOK
# ==================================================================== #

def test_ISLETME_YORUMU_SILEMEZ_AMA_CEVAP_VEREBILIR(client, sahne):
    yorum = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                        headers=sahne["musteri"]["h"],
                        json={"puan": 2, "metin": "Geç geldi."}).json()

    # SILME UCU YOK — DELETE tanimli degil.
    assert client.delete(f"/dukkan/yorum/{yorum['id']}").status_code in (404, 405)

    r = client.post(f"/dukkan/yorum/{yorum['id']}/cevap",
                    headers=sahne["sahip"]["h"],
                    json={"metin": "Trafikte kaldım, özür dilerim."})
    assert r.status_code == 201, r.text
    d = client.get(f"/dukkan/isletme-profil/{sahne['slug']}/yorum").json()
    assert d["items"][0]["cevap"] == "Trafikte kaldım, özür dilerim."


def test_BASKA_ISLETME_YORUMA_CEVAP_VEREMEZ(client, dukkan_conn, moderator, sahne):
    yorum = client.post(f"/dukkan/is/{sahne['is_id']}/yorum",
                        headers=sahne["musteri"]["h"], json={"puan": 3}).json()
    yabanci = _giris(client)
    baska = client.post("/dukkan/isletme", headers=yabanci["h"],
                        json={"ad": "Yabancı", "telefon": _tel()}).json()["id"]
    r = client.post(f"/dukkan/yorum/{yorum['id']}/cevap", headers=yabanci["h"],
                    json={"metin": "Ben cevaplıyorum"})
    assert r.status_code == 403, r.text


# ==================================================================== #
# 6. SIKAYET VE MODERASYON
# ==================================================================== #

def test_SIKAYET_KIMLIKSIZ_YAPILABILIR(client, sahne):
    """Dolandirilan ve hesabi olmayan bir kullanici sikayet EDEMESEYDI,
    en cok duyulmasi gereken ses kesilirdi."""
    r = client.post("/dukkan/sikayet", json={
        "tip": "odeme", "isletme_slug": sahne["slug"],
        "metin": "Kapora aldı, gelmedi.", "iletisim": "0555 111 22 33"})
    assert r.status_code == 201, r.text
    assert r.json()["durum"] == "acik"


def test_SIKAYET_YANLIS_SLUGLA_DA_KAYDEDILIR(client):
    """Yanlis yazilmis bir slug yuzunden bir DOLANDIRICILIK sikayetini
    reddetmek, en kotu sonucu uretirdi."""
    r = client.post("/dukkan/sikayet", json={
        "tip": "sahte_isletme", "isletme_slug": "boyle-bir-isletme-yok",
        "metin": "Sahte olduğunu düşünüyorum."})
    assert r.status_code == 201, r.text


def test_SIKAYET_KAPATMA_SONUC_ISTER(client, sahne, moderator):
    """Sonucsuz kapatilan bir sikayet, hicbir sey yapilmadigini gizler."""
    s = client.post("/dukkan/sikayet", json={
        "tip": "hizmet", "isletme_slug": sahne["slug"],
        "metin": "İş yarım kaldı."}).json()["id"]
    r = client.post(f"/dukkan/moderasyon/sikayet/{s}/karar",
                    headers=moderator["h"], json={"durum": "kapandi"})
    assert r.status_code == 422, r.text
    r = client.post(f"/dukkan/moderasyon/sikayet/{s}/karar",
                    headers=moderator["h"],
                    json={"durum": "kapandi", "sonuc": "İşletme ile görüşüldü."})
    assert r.status_code == 200, r.text


def test_ASKI_ADAYLARI_ESIGI_UYGULAR(client, sahne, moderator):
    """Odeme sikayeti esigi asilinca isletme ADAY LISTESINE duser.

    OTOMATIK ASKI DEGIL: sikayet kimliksiz yapilabildigi icin uc sahte
    sikayet uretmek UCUZ ve otomatik aski, bir isletmeyi rakibinin
    kapatmasinin yolu olurdu. Karar bir insanin, ama AYNI GUN.
    """
    def adayda_mi() -> bool:
        d = client.get("/dukkan/moderasyon/aski-adaylari",
                       headers=moderator["h"]).json()
        return any(x["slug"] == sahne["slug"] for x in d["items"])

    assert not adayda_mi()
    for n in range(3):
        client.post("/dukkan/sikayet", json={
            "tip": "odeme", "isletme_slug": sahne["slug"],
            "metin": f"Kapora şikayeti {n}."})
    assert adayda_mi(), "esik asildi ama aday listesinde YOK"


def test_MODERASYON_UCLARI_MODERATOR_ISTER(client, sahne):
    yabanci = _giris(client)
    for metot, yol, govde in [
        ("get", "/dukkan/moderasyon/yorum-kuyrugu", None),
        ("get", "/dukkan/moderasyon/sikayet-kuyrugu", None),
        ("get", "/dukkan/moderasyon/aski-adaylari", None),
    ]:
        r = getattr(client, metot)(yol, headers=yabanci["h"])
        assert r.status_code == 403, f"{yol} -> {r.status_code}"


def test_YORUM_KARARI_GEREKCE_ISTER(client, sahne, moderator):
    tel = _tel()
    kod = client.post(f"/dukkan/isletme/{sahne['isl']}/yorum-daveti",
                      headers=sahne["sahip"]["h"],
                      json={"telefon": tel}).json()["dev_kod"]
    y = client.post("/dukkan/yorum-daveti/dogrula", params={"telefon": tel},
                    json={"kod": kod, "puan": 1, "metin": "Kötü."}).json()
    assert y["durum"] == "beklemede"
    r = client.post(f"/dukkan/moderasyon/yorum/{y['id']}/karar",
                    headers=moderator["h"], json={"karar": "reddet"})
    assert r.status_code == 422, r.text
    r = client.post(f"/dukkan/moderasyon/yorum/{y['id']}/karar",
                    headers=moderator["h"],
                    json={"karar": "yayinla"})
    assert r.status_code == 200 and r.json()["durum"] == "yayinda"
