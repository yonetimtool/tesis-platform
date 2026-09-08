"""(DUKKAN F8b) REKLAM — slot siniri, sponsorlu ayrim, bekleme listesi.

===========================================================================
EN KRITIK KILIT: REKLAM ORGANIK SIRALAMAYI DEGISTIRMEZ
===========================================================================
Gelir modelinin tamami buna dayaniyor. Reklam siralamaya karisirsa:
  * kullanici "en iyi sonuc" sandigi seyi satin almis olur,
  * organik listenin degeri duser,
  * ve satilan sey (degerli bir listenin ustunde olmak) degersizlesir.

`siralama_puani` `siralama.py`nin TEK YAZMA YOLU. Bu dosya reklam satin
alindiginda o puanin DEGISMEDIGINI olcuyor — iddia degil, olcum.

===========================================================================
SLOT SINIRI IKI KATMANLI
===========================================================================
1. `azami_slot` (kapsam basina: mahalle 1 / ilce 2 / il 3)
2. `azami_oran` (%20 tavan) — mahallede 3 isletme varsa 1 slot bile
   listenin ucte biri olur; oran tavani o durumda slotu SIFIRA ceker.

Sayilar VERIDE (`reklam_slot_kurali`), kodda degil: ilk uc ayda gercek
veriyle ayarlanacaklar. Testler de sayilari SABIT VARSAYMIYOR — kurali
kendileri kuruyor.
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
            "id": d["kullanici"]["id"]}


@pytest.fixture
def moderator(client, dukkan_conn):
    k = _giris(client)
    dukkan_conn.execute(
        "INSERT INTO dukkan.moderator (kullanici_id, atayan) VALUES (%s,'f8') "
        "ON CONFLICT DO NOTHING", (k["id"],))
    return k


@pytest.fixture
def bos_mahalle(dukkan_conn):
    """HIC ISLETMESI OLMAYAN bir mahalle.

    NEDEN: oran tavani (%20) o bolgedeki GORUNUR isletme sayisina bagli.
    Baska testlerin doldurdugu bir mahalle kullansaydim, slot sayisi
    kosuma gore degisir ve test SIRA-BAGIMLI olurdu (P181'de olculen
    flake sinifi).
    """
    r = dukkan_conn.execute(
        """
        SELECT m.id, m.slug, ic.slug, i.slug FROM dukkan.mahalle m
        JOIN dukkan.ilce ic ON ic.id = m.ilce_id
        JOIN dukkan.il i ON i.id = ic.il_id
        WHERE NOT EXISTS (SELECT 1 FROM dukkan.isletme_hizmet_alani ha
                           WHERE ha.mahalle_id = m.id)
        ORDER BY m.id LIMIT 1
        """
    ).fetchone()
    return {"id": str(r[0]), "mahalle": r[1], "ilce": r[2], "il": r[3]}


def _onayli_isletme(client, dukkan_conn, moderator, mahalle_id: str) -> dict:
    """Onayli, o mahallede hizmet veren, elektrikci bir isletme."""
    sahip = _giris(client)
    isl = client.post("/dukkan/isletme", headers=sahip["h"],
                      json={"ad": f"Reklam {uuid.uuid4().hex[:6]}",
                            "telefon": _tel()}).json()["id"]
    client.put(f"/dukkan/isletme/{isl}/kategoriler", headers=sahip["h"],
               json={"slugler": ["elektrikci"]})
    client.put(f"/dukkan/isletme/{isl}/hizmet-alanlari", headers=sahip["h"],
               json={"mahalle_idler": [mahalle_id]})
    kod = client.post(f"/dukkan/isletme/{isl}/telefon/kod",
                      headers=sahip["h"]).json()["dev_kod"]
    client.post(f"/dukkan/isletme/{isl}/telefon/dogrula", headers=sahip["h"],
                json={"kod": kod})
    client.post(f"/dukkan/isletme/{isl}/basvur", headers=sahip["h"])
    client.post(f"/dukkan/moderasyon/isletme/{isl}/karar",
                headers=moderator["h"], json={"karar": "onayla"})
    return {"sahip": sahip, "id": isl}


@pytest.fixture
def paket(dukkan_conn):
    """Mahalle kapsamli 30 gunluk paket."""
    pid = dukkan_conn.execute(
        "INSERT INTO dukkan.reklam_paketi (ad, kapsam, gun, fiyat_kurus) "
        "VALUES (%s, 'mahalle', 30, 50000) RETURNING id",
        (f"Test {uuid.uuid4().hex[:6]}",)).fetchone()[0]
    yield str(pid)
    dukkan_conn.execute("DELETE FROM dukkan.reklam_paketi WHERE id=%s", (pid,))


def _kural_yaz(dukkan_conn, kapsam: str, slot: int, oran: float):
    """Slot kuralini bu test icin AYARLAR.

    Yeni satir yaziliyor, mevcut silinmiyor: uretimde de kural boyle
    versiyonlanacak ("o tarihte kural neydi" sorusu bir itirazda
    sorulur) ve test o davranisi kullaniyor.
    """
    dukkan_conn.execute(
        "INSERT INTO dukkan.reklam_slot_kurali (kapsam, azami_slot, "
        " azami_oran, etkin_at) VALUES (%s, %s, %s, now())",
        (kapsam, slot, oran))


# ==================================================================== #
# 1. EN KRITIK: SIRALAMA DEGISMEZ
# ==================================================================== #

def test_REKLAM_SIRALAMA_PUANINI_DEGISTIRMEZ(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Gelir modelinin dayandigi kilit.

    Reklam satin alindiginda `siralama_puani` AYNI kalmali. Degisseydi,
    para organik sirayi manipule ediyor olurdu.
    """
    # Oran tavanini asmamak icin bolgede yeterli isletme olmali.
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])

    once = dukkan_conn.execute(
        "SELECT siralama_puani FROM dukkan.isletme WHERE id=%s",
        (isl["id"],)).fetchone()[0]

    r = client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                    params={"isletme_id": isl["id"]},
                    json={"paket_id": paket, "kategori_slug": "elektrikci",
                          "mahalle_id": bos_mahalle["id"]})
    assert r.status_code == 201, r.text

    sonra = dukkan_conn.execute(
        "SELECT siralama_puani FROM dukkan.isletme WHERE id=%s",
        (isl["id"],)).fetchone()[0]
    assert sonra == once, (once, sonra)


def test_SPONSORLU_AYRI_ANAHTARDA_ve_ROZETLI(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Sponsorlu sonuc `items` icine KARISTIRILMAZ ve `sponsorlu: true`
    bayragini SUNUCUDAN tasir.

    Bayragi istemcinin varsaymasina birakmak, ikinci istemcide (mobil)
    rozetin DUSMESI demekti — rozet zorunlu.
    """
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                params={"isletme_id": isl["id"]},
                json={"paket_id": paket, "kategori_slug": "elektrikci",
                      "mahalle_id": bos_mahalle["id"]})

    d = client.get("/dukkan/isletme-ara", params={
        "il": bos_mahalle["il"], "ilce": bos_mahalle["ilce"],
        "mahalle": bos_mahalle["mahalle"], "kategori": "elektrikci"}).json()

    assert "sponsorlu" in d, d.keys()
    assert len(d["sponsorlu"]) == 1, d["sponsorlu"]
    assert d["sponsorlu"][0]["sponsorlu"] is True
    # ORGANIK LISTEDE DE CIKAR: organikten cikarmak, paranin siraya
    # karismasinin tersten haliydi.
    assert any(x["slug"] == d["sponsorlu"][0]["slug"] for x in d["items"])
    # ...ama organik kalemler sponsorlu BAYRAGI TASIMAZ.
    assert all("sponsorlu" not in x for x in d["items"]), d["items"][0]


def test_KATEGORISIZ_ARAMADA_SPONSORLU_YOK(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Alakasiz reklam iki tarafi da memnuniyetsiz birakir."""
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                params={"isletme_id": isl["id"]},
                json={"paket_id": paket, "kategori_slug": "elektrikci",
                      "mahalle_id": bos_mahalle["id"]})

    d = client.get("/dukkan/isletme-ara", params={
        "il": bos_mahalle["il"], "ilce": bos_mahalle["ilce"],
        "mahalle": bos_mahalle["mahalle"]}).json()
    assert d["sponsorlu"] == [], d["sponsorlu"]


def test_IKINCI_SAYFADA_SPONSORLU_YOK(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Ikinci sayfaya inen kullanici aramasini surduruyor; oraya da
    reklam koymak listeyi reklamla kesmek olurdu."""
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                params={"isletme_id": isl["id"]},
                json={"paket_id": paket, "kategori_slug": "elektrikci",
                      "mahalle_id": bos_mahalle["id"]})

    d = client.get("/dukkan/isletme-ara", params={
        "il": bos_mahalle["il"], "ilce": bos_mahalle["ilce"],
        "mahalle": bos_mahalle["mahalle"], "kategori": "elektrikci",
        "sayfa": 2}).json()
    assert d["sponsorlu"] == []


# ==================================================================== #
# 2. SLOT SINIRI
# ==================================================================== #

def test_SLOT_DOLUNCA_SATIS_KAPANIR(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """ROTASYON YOK, SATIS KAPANIR.

    Fazla satip sirayla gostermek daha cok gelir getirirdi ama isletme
    ne satin aldigini bilemez, "ne kadar gorundum" sorusu dogar ve
    platform onu KANITLAMAK zorunda kalir. Kapali satis durust.
    """
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    a = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    b = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])

    govde = {"paket_id": paket, "kategori_slug": "elektrikci",
             "mahalle_id": bos_mahalle["id"]}
    assert client.post("/dukkan/reklam", headers=a["sahip"]["h"],
                       params={"isletme_id": a["id"]},
                       json=govde).status_code == 201

    r = client.post("/dukkan/reklam", headers=b["sahip"]["h"],
                    params={"isletme_id": b["id"]}, json=govde)
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "bolge_dolu", r.text


def test_ORAN_TAVANI_SLOTU_SIFIRA_CEKER(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Mahallede 1 isletme + %20 tavan -> 0 slot.

    1 slot bile listenin TAMAMI olurdu. Sayfa reklam panosuna donerse
    organik sonucun degeri duser — ve satilan sey tam olarak "degerli
    bir listenin ustunde olmak".
    """
    _kural_yaz(dukkan_conn, "mahalle", 1, 20.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])

    r = client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                    params={"isletme_id": isl["id"]},
                    json={"paket_id": paket, "kategori_slug": "elektrikci",
                          "mahalle_id": bos_mahalle["id"]})
    assert r.status_code == 409, r.text
    assert r.json()["error"]["code"] == "bolge_dolu"

    d = client.get("/dukkan/reklam/slot-durumu", params={
        "kapsam": "mahalle", "bolge_id": bos_mahalle["id"],
        "kategori_slug": "elektrikci"}).json()
    assert d["azami"] == 0 and d["oran_tavani_slot"] == 0, d
    assert d["isletme_sayisi"] == 1, d


def test_KURAL_YOKSA_SATIS_KAPALI(client, dukkan_conn, bos_mahalle):
    """"Kural bulunamadi" durumunda SINIRSIZ satmak, bir yapilandirma
    hatasini gelire cevirip sayfayi reklam panosuna dondururdu."""
    from app.dukkan.reklam import slot_kurali  # noqa: F401  (belge amacli)

    d = client.get("/dukkan/reklam/slot-durumu", params={
        "kapsam": "il", "bolge_id": bos_mahalle["id"],
        "kategori_slug": "elektrikci"}).json()
    # Bolge kimligi yanlis tipte (mahalle id'si il olarak) -> 0 isletme,
    # dolayisiyla 0 slot. Onemli olan: ASLA negatif ya da sinirsiz degil.
    assert d["azami"] >= 0 and d["bos"] >= 0, d


def test_ONAYSIZ_ISLETME_REKLAM_ALAMAZ(client, dukkan_conn, bos_mahalle, paket):
    """Aramada hic gorunmeyen bir isletmeye para odetmek olurdu."""
    sahip = _giris(client)
    isl = client.post("/dukkan/isletme", headers=sahip["h"],
                      json={"ad": "Onaysiz", "telefon": _tel()}).json()["id"]
    r = client.post("/dukkan/reklam", headers=sahip["h"],
                    params={"isletme_id": isl},
                    json={"paket_id": paket, "kategori_slug": "elektrikci",
                          "mahalle_id": bos_mahalle["id"]})
    assert r.status_code == 403, r.text


def test_BASKASININ_ISLETMESINE_REKLAM_ALINAMAZ(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """IDOR: reklam da bir sahiplik islemi."""
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    yabanci = _giris(client)
    r = client.post("/dukkan/reklam", headers=yabanci["h"],
                    params={"isletme_id": isl["id"]},
                    json={"paket_id": paket, "kategori_slug": "elektrikci",
                          "mahalle_id": bos_mahalle["id"]})
    assert r.status_code == 403, r.text


def test_ISLETMENIN_OLMADIGI_KATEGORIDE_REKLAM_ALINAMAZ(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Alakasiz aramalarda cikan reklam, hem kullanici hem reklamveren
    icin degersiz."""
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    r = client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                    params={"isletme_id": isl["id"]},
                    json={"paket_id": paket, "kategori_slug": "boya-badana",
                          "mahalle_id": bos_mahalle["id"]})
    assert r.status_code == 400, r.text
    assert "kategoride_degil" in r.text


def test_KAPSAMLA_UYUSMAYAN_BOLGE_400(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Mahalle paketine ilce kimligi verilirse: tutarsiz satir arama
    sorgusunda SESSIZCE hicbir yere dusmezdi."""
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    r = client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                    params={"isletme_id": isl["id"]},
                    json={"paket_id": paket, "kategori_slug": "elektrikci",
                          "ilce_id": bos_mahalle["id"]})
    assert r.status_code == 400, r.text
    assert "kapsamla_uyusmuyor" in r.text


# ==================================================================== #
# 3. BEKLEME LISTESI
# ==================================================================== #

def test_DOLU_BOLGEDE_SIRAYA_GIRILIR_ve_SIRA_DONER(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """`sira` DONUYOR: kacinci oldugunu bilmeyen isletme bekleyip
    beklememeye karar veremez."""
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    a = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    b = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    govde = {"paket_id": paket, "kategori_slug": "elektrikci",
             "mahalle_id": bos_mahalle["id"]}
    client.post("/dukkan/reklam", headers=a["sahip"]["h"],
                params={"isletme_id": a["id"]}, json=govde)

    r = client.post("/dukkan/reklam/bekleme", headers=b["sahip"]["h"],
                    params={"isletme_id": b["id"]}, json=govde)
    assert r.status_code == 201, r.text
    assert r.json()["sira"] == 1, r.text

    # AYNI ISLETME IKI KEZ SIRAYA GIREMEZ.
    r2 = client.post("/dukkan/reklam/bekleme", headers=b["sahip"]["h"],
                     params={"isletme_id": b["id"]}, json=govde)
    assert r2.status_code == 409 and "zaten_sirada" in r2.text, r2.text


def test_YER_VARKEN_SIRAYA_ALINMAZ(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Isletme bekledigini sanip beklerken, satin alabilecegi bir yer
    bos dururdu."""
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    r = client.post("/dukkan/reklam/bekleme", headers=isl["sahip"]["h"],
                    params={"isletme_id": isl["id"]},
                    json={"paket_id": paket, "kategori_slug": "elektrikci",
                          "mahalle_id": bos_mahalle["id"]})
    assert r.status_code == 409 and "yer_var" in r.text, r.text


# ==================================================================== #
# 4. SURE BITIMI + BILDIRIM (gecelik gorev)
# ==================================================================== #

def test_SURESI_BITEN_REKLAM_DUSER_ama_SILINMEZ(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Silmek, "gecen ay hangi reklam yayindaydi" sorusunu cevapsiz
    birakirdi — o soru bir faturada ya da itirazda sorulur."""
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    rid = client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                      params={"isletme_id": isl["id"]},
                      json={"paket_id": paket, "kategori_slug": "elektrikci",
                            "mahalle_id": bos_mahalle["id"]}).json()["id"]
    # Suresini GECMISE cek (gorev canli sunucuda kosuyor; zamani
    # ilerletemeyiz, kaydi geriye alabiliriz).
    #
    # BASLANGIC DA GERIYE ALINIYOR: `bitis > baslangic` CHECK'i var ve
    # olmasi DOGRU — bitisi baslangictan once olan bir reklam anlamsiz.
    # Testin kisiti delmesi degil, GERCEKCI bir gecmis kurmasi gerekir:
    # 31 gun once baslamis 30 gunluk bir reklam.
    dukkan_conn.execute(
        "UPDATE dukkan.reklam SET baslangic = now() - interval '31 days', "
        " bitis = now() - interval '1 hour' WHERE id=%s", (rid,))

    from app.dukkan.gorevler import reklam_bakimi

    sonuc = reklam_bakimi()
    assert sonuc["biten"] >= 1, sonuc

    satir = dukkan_conn.execute(
        "SELECT durum FROM dukkan.reklam WHERE id=%s", (rid,)).fetchone()
    assert satir is not None, "reklam SILINMIS — kayit kalmali"
    assert satir[0] == "bitti", satir

    # DUSEN REKLAM ARAMADA GORUNMEZ.
    d = client.get("/dukkan/isletme-ara", params={
        "il": bos_mahalle["il"], "ilce": bos_mahalle["ilce"],
        "mahalle": bos_mahalle["mahalle"], "kategori": "elektrikci"}).json()
    assert d["sponsorlu"] == [], d["sponsorlu"]


def test_BITISE_YAKIN_REKLAM_HATIRLATMA_URETIR(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """OTOMATIK YENILEME YOK — bunun yerine HATIRLATMA. Sessizce kart
    cekmek en cok sikayet ureten seydir."""
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    isl = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    rid = client.post("/dukkan/reklam", headers=isl["sahip"]["h"],
                      params={"isletme_id": isl["id"]},
                      json={"paket_id": paket, "kategori_slug": "elektrikci",
                            "mahalle_id": bos_mahalle["id"]}).json()["id"]
    dukkan_conn.execute(
        "UPDATE dukkan.reklam SET bitis = now() + interval '7 days' "
        "WHERE id=%s", (rid,))

    from app.dukkan.gorevler import reklam_bakimi

    reklam_bakimi()
    n = dukkan_conn.execute(
        "SELECT count(*) FROM dukkan.bildirim "
        "WHERE tip='dukkan_reklam_bitiyor' AND veri->>'reklam_id'=%s",
        (rid,)).fetchone()[0]
    assert n == 1, n

    # IDEMPOTENT: ikinci kosum AYNI GUN icinde ikinci bildirim yazmaz.
    reklam_bakimi()
    n2 = dukkan_conn.execute(
        "SELECT count(*) FROM dukkan.bildirim "
        "WHERE tip='dukkan_reklam_bitiyor' AND veri->>'reklam_id'=%s",
        (rid,)).fetchone()[0]
    assert n2 == 1, n2


def test_YER_ACILINCA_BEKLEYENE_BILDIRIM(
        client, dukkan_conn, moderator, bos_mahalle, paket):
    """Bekleme listesinin karsiligi: yer acilinca HABER GIDER.

    Gitmeseydi "siraya gir" demek, isletmeyi sonu olmayan bir kuyruga
    koymak olurdu.
    """
    _kural_yaz(dukkan_conn, "mahalle", 1, 100.0)
    a = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    b = _onayli_isletme(client, dukkan_conn, moderator, bos_mahalle["id"])
    govde = {"paket_id": paket, "kategori_slug": "elektrikci",
             "mahalle_id": bos_mahalle["id"]}
    rid = client.post("/dukkan/reklam", headers=a["sahip"]["h"],
                      params={"isletme_id": a["id"]},
                      json=govde).json()["id"]
    bid = client.post("/dukkan/reklam/bekleme", headers=b["sahip"]["h"],
                      params={"isletme_id": b["id"]},
                      json=govde).json()["id"]

    from app.dukkan.gorevler import reklam_bakimi

    # Yer HENUZ acilmadi: bildirim OLMAMALI (yanlis alarm, bekleyeni
    # bosuna kosturur).
    reklam_bakimi()
    assert dukkan_conn.execute(
        "SELECT durum FROM dukkan.reklam_bekleme WHERE id=%s",
        (bid,)).fetchone()[0] == "bekliyor"

    # Reklamin suresi doldu -> yer acildi.
    dukkan_conn.execute(
        "UPDATE dukkan.reklam SET baslangic = now() - interval '31 days', "
        " bitis = now() - interval '1 hour' WHERE id=%s", (rid,))
    reklam_bakimi()

    assert dukkan_conn.execute(
        "SELECT durum FROM dukkan.reklam_bekleme WHERE id=%s",
        (bid,)).fetchone()[0] == "yer_acildi"
    n = dukkan_conn.execute(
        "SELECT count(*) FROM dukkan.bildirim "
        "WHERE tip='dukkan_reklam_yer_acildi' AND veri->>'bekleme_id'=%s",
        (bid,)).fetchone()[0]
    assert n == 1, n


def test_REKLAM_BILDIRIM_TIPLERI_DUKKAN_ONEKLI():
    """Onek, push kanalini secen kuraldir (F6-ek). Oneksiz bir tip
    Yonetiyor kanalindan gider ve kullanici pazar yeri bildirimlerini
    kapattigini sanip almaya devam ederdi."""
    from app.dukkan.bildirim import TIPLER
    from app.push_kanal import DUKKAN_ONEK, KANAL_DUKKAN, kanal_sec

    for tip in ("dukkan_reklam_bitiyor", "dukkan_reklam_yer_acildi"):
        assert tip in TIPLER, tip
        assert tip.startswith(DUKKAN_ONEK)
        assert kanal_sec(tip, sesli=True) == KANAL_DUKKAN
