"""(P220 §3) BILDIRIM ARAMASI — kullanicinin GORDUGU metinde arar.

===========================================================================
NEDEN SQL'DE ARANMIYOR — OLCULEN KISIT
===========================================================================
Bildirim metni KAYITTA DURMUYOR. Satir `mesaj_kimlik` + `mesaj_veri`
tasiyor; cumle OKUMA ANINDA, istegin dilinde kuruluyor (tur 16 karari —
ayni kayit her kullaniciya kendi dilinde gorunsun diye).

Sonucu: `WHERE mesaj ILIKE '%kargo%'` yalniz TUR 16 ONCESI satirlari
bulurdu — yani kullanicinin gordugu metinlerin neredeyse hicbirini.

Bu dosya once o kisiti KANITLIYOR (kayittaki `mesaj` bos ama arama
buluyor), sonra aramanin uc kapsamini (baslik + govde + tip) olcuyor.

===========================================================================
ISTEMCIDE FILTRELEMEK DE YANLIS OLURDU
===========================================================================
Yalniz ACIK SAYFAYI suzer: "kargo" arayan kullanici 3. sayfadaki kaydi
bulamaz ve "yok" saniyor. `test_ARAMA_SAYFA_DISINDAKINI_de_BULUR` bunu
olcuyor.
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
def bildirimler(client, world, owner_conn, yon):
    """Kimligi olan (metni URETILEN) bildirimler yazar.

    DOGRUDAN SQL: bildirim uretimi bir sürü akisa dagilmis durumda ve
    olculen sey o akislar degil ARAMA. Kimlik + veri yaziliyor, metin
    ucta uretiliyor — gercek satirlarla ayni yapida.
    """
    # `user_id IS NULL` = TESISE AIT YONETIM ALARMI. Yonetici YALNIZ
    # bunlari gorur (`_kapsam`); kendi kimligiyle yazsaydik kayitlar
    # kapsam disinda kalir ve arama degil YETKI olculurdu.
    kayitlar = []
    for kimlik, veri in (
        ("kacirilan_tur", {"plan": "TESTPLAN1", "eksik": 3}),
        ("gurultu_uyarisi", {"daire": "A-42", "sayi": 5}),
        ("portal_iletisim", {"ad": "Deneme Kisi"}),
    ):
        nid = uuid.uuid4()
        owner_conn.execute(
            "INSERT INTO notification (id, tenant_id, user_id, tip, mesaj, "
            " mesaj_kimlik, mesaj_veri, okundu, created_at) "
            "VALUES (%s,%s,NULL,'kacirilan_tur','', %s, %s::jsonb, false, now())",
            (nid, world["a"], kimlik, __import__("json").dumps(veri)))
        kayitlar.append(str(nid))
    yield {"idler": kayitlar, "kullanici": None}
    for nid in kayitlar:
        owner_conn.execute("DELETE FROM notification WHERE id = %s", (nid,))


def _ara(client, yon, q, okundu=None, limit=50, offset=0):
    yol = f"/notifications?limit={limit}&offset={offset}&q={q}"
    if okundu is not None:
        yol += f"&okundu={'true' if okundu else 'false'}"
    r = client.get(yol, headers=yon)
    assert r.status_code == 200, r.text
    return r.json()


# ==================================================================== #
# 1. KISITIN KANITI
# ==================================================================== #

def test_KAYITTAKI_MESAJ_BOS_ama_ARAMA_BULUYOR(
        client, owner_conn, yon, bildirimler):
    """SQL aramasinin neden yetmedigini KANITLIYOR.

    Kayitlarin `mesaj` sutunu BOS; metin okuma aninda uretiliyor.
    `WHERE mesaj ILIKE ...` bunlarin hicbirini bulamazdi.
    """
    ham = owner_conn.execute(
        "SELECT mesaj FROM notification WHERE id = %s",
        (bildirimler["idler"][0],)).fetchone()[0]
    assert (ham or "") == "", "on kosul bozuldu: kayitta metin var"

    d = _ara(client, yon, "TESTPLAN1")
    assert d["meta"]["total"] >= 1, d["meta"]
    assert any("TESTPLAN1" in x["mesaj"] for x in d["items"]), d["items"]


# ==================================================================== #
# 2. KAPSAM: BASLIK + GOVDE + TIP
# ==================================================================== #

def test_GOVDEDE_arar(client, yon, bildirimler):
    """Kullanicinin GORDUGU cumlede arama — istegin bu maddesi."""
    d = _ara(client, yon, "TESTPLAN1")
    assert d["meta"]["total"] >= 1, d["meta"]


def test_BASLIKTA_da_arar(client, yon, bildirimler):
    """Baslik da URETILEN metin: `push_basligi(mesaj_kimlik, dil)`."""
    d = _ara(client, yon, "Gürültü uyarısı")
    assert d["meta"]["total"] >= 1, d["meta"]


def test_TIP_KIMLIGINDE_de_arar(client, yon, bildirimler):
    d = _ara(client, yon, "kacirilan_tur")
    assert d["meta"]["total"] >= 1, d["meta"]


def test_KISA_SORGU_ARAMA_SAYILMAZ(client, yon, bildirimler):
    """Tek harf, taranan satirlarin neredeyse tamamiyla eslesir ve arama
    bir ise yaramaz — o yuzden aramasiz yola duser."""
    d = _ara(client, yon, "k")
    assert d["meta"].get("arama_tarandi") is None, d["meta"]


# ==================================================================== #
# 3. SEKME ILE BIRLIKTE CALISIR (istegin 6. kabul kriteri)
# ==================================================================== #

def test_ARAMA_HER_IKI_SEKMEDE_de_CALISIR(
        client, owner_conn, yon, bildirimler):
    """Okunmus VE okunmamis sekmesinde arama."""
    # Hepsi okunmamis -> okunmamis sekmesinde bulunur.
    d = _ara(client, yon, "TESTPLAN1", okundu=False)
    assert d["meta"]["total"] >= 1, d["meta"]

    # Birini okundu isaretle -> okunmus sekmesine GECER.
    hedef = bildirimler["idler"][0]
    r = client.patch(f"/notifications/{hedef}", headers=yon,
                     json={"okundu": True})
    assert r.status_code == 200, r.text

    okunmus = _ara(client, yon, "TESTPLAN1", okundu=True)
    assert any(x["id"] == hedef for x in okunmus["items"]), okunmus["items"]
    okunmamis = _ara(client, yon, "TESTPLAN1", okundu=False)
    assert not any(x["id"] == hedef for x in okunmamis["items"]), (
        "okundu isaretlenen bildirim OKUNMAMIS sekmesinde kaldi")


def test_ARAMA_SAYFA_DISINDAKINI_de_BULUR(
        client, owner_conn, yon, bildirimler, world):
    """Istemcide filtreleme YETMEZ: yalniz acik sayfayi suzerdi.

    Aranan kaydin ONUNE, ayni kapsamda bol miktarda kayit koyuyoruz;
    `limit=1` ile ilk sayfada GORUNMEZ ama arama onu buluyor.
    """
    dolgu = []
    for _ in range(5):
        nid = uuid.uuid4()
        owner_conn.execute(
            "INSERT INTO notification (id, tenant_id, user_id, tip, mesaj, "
            " mesaj_kimlik, mesaj_veri, okundu, created_at) "
            "VALUES (%s,%s,NULL,'kacirilan_tur','', 'portal_iletisim', "
            " '{\"ad\": \"dolgu\"}'::jsonb, false, now())",
            (nid, world["a"]))
        dolgu.append(nid)
    try:
        # Aramasiz ilk sayfada (limit=1) aranan kayit YOK.
        ilk = client.get("/notifications?limit=1&offset=0",
                         headers=yon).json()
        assert not any("TESTPLAN1" in x["mesaj"] for x in ilk["items"])
        # Arama onu BULUYOR.
        d = _ara(client, yon, "TESTPLAN1", limit=1)
        assert d["meta"]["total"] >= 1, d["meta"]
        assert d["items"], d
    finally:
        for nid in dolgu:
            owner_conn.execute("DELETE FROM notification WHERE id = %s", (nid,))


def test_ARAMA_TAVANI_YANITTA_GORUNUR(client, yon, bildirimler):
    """Sessizce eksik sonuc dondurmek, kullaniciyi "demek ki yok"
    sonucuna goturur. Tarama seffaf."""
    d = _ara(client, yon, "TESTPLAN1")
    assert "arama_tarandi" in d["meta"], d["meta"]
    assert d["meta"]["arama_tavani_asildi"] in (True, False), d["meta"]


def test_ARAMA_KAPSAMI_ASMAZ(client, world, yon, bildirimler):
    """Arama YETKIYI GENISLETMEZ: baska tesisin bildirimi gelmez."""
    b_yon = _h(client, world["slug_b"], world["yonetici_b"])
    d = _ara(client, b_yon, "TESTPLAN1")
    assert d["meta"]["total"] == 0, d
