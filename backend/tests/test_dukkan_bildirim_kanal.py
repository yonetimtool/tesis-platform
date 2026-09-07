"""(DUKKAN F6-ek) BILDIRIM KANALI + TERCIH.

===========================================================================
NE KORUNUYOR
===========================================================================
1. DUKKAN KENDI KANALINDAN gider. Yonetiyor'un kanallarina dusmesi,
   kullanicinin pazar yeri bildirimlerini SITE bildirimlerini susturmadan
   kapatamamasi demekti (Android'de kapatma kanal basinadir).
2. KANAL ONEKTEN turetilir, elle tutulan bir listeden DEGIL: yeni bir
   Dukkan tipi eklendiginde sessizce Yonetiyor kanalina dusemez.
3. SES: Yonetiyor'un KIMLIK SESI (`yonetio_bildirim`) Dukkan'a
   VERILMEZ. O ses "binanla ilgili bir sey oldu" der.
4. TERCIH KAPALIYSA PUSH GITMEZ ama SATIR YAZILIR: kullanici push
   istemiyor olabilir, olayi kaybetmeyi istemez.
5. Dukkan tercihi YONETIYOR'UNKINDEN AYRI: biri kapatilinca digeri
   etkilenmez.
"""
from __future__ import annotations

import uuid

import pytest

from app.push_kanal import (
    KANAL_DUKKAN,
    KANAL_GENEL,
    KANAL_KRITIK,
    KANAL_SESSIZ,
    kanal_sec,
    ses_adi,
)


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


# ==================================================================== #
# 1. KANAL SECIMI
# ==================================================================== #

def test_DUKKAN_TIPLERI_KENDI_KANALINDAN_gider():
    from app.dukkan.bildirim import TIPLER

    for tip in TIPLER:
        assert kanal_sec(tip, sesli=True) == KANAL_DUKKAN, tip


def test_YONETIYOR_TIPLERI_ETKILENMEDI():
    """Ters yon: Dukkan dali eski davranisi DEGISTIRMEMELI."""
    assert kanal_sec("yeni_talep", sesli=True) == KANAL_KRITIK
    assert kanal_sec("duyuru", sesli=True) == KANAL_GENEL
    assert kanal_sec("duyuru", sesli=False) == KANAL_SESSIZ


def test_SESSIZ_TERCIHI_DUKKANI_DA_KAPSAR():
    """`sesli=False` kanal secimindeki ILK karar; Dukkan da buna uyar.

    Aksi halde "sesli gelmesin" diyen kullanici, pazar yeri
    bildirimlerinde sesi duymaya devam ederdi.
    """
    assert kanal_sec("dukkan_teklif_geldi", sesli=False) == KANAL_SESSIZ
    assert ses_adi("dukkan_teklif_geldi", sesli=False) is None


def test_DUKKAN_YONETIYORUN_KIMLIK_SESINI_ALMAZ():
    """`yonetio_bildirim.caf` YALNIZ Yonetiyor'un kritik tiplerinde."""
    assert ses_adi("dukkan_teklif_geldi", sesli=True) == "default"
    assert ses_adi("yeni_talep", sesli=True) == "yonetio_bildirim.caf"


def test_ONEK_ESLEMESI_LISTEDEN_BAGIMSIZ():
    """HENUZ VAR OLMAYAN bir Dukkan tipi de dogru kanaldan gider.

    Elle tutulan bir liste olsaydi, F7'de eklenecek bir tip sessizce
    Yonetiyor kanalina duserdi — ve kullanici pazar yeri bildirimlerini
    kapattigini sanip almaya devam ederdi.
    """
    assert kanal_sec("dukkan_odeme_alindi", sesli=True) == KANAL_DUKKAN
    assert ses_adi("dukkan_gelecekteki_tip", sesli=True) == "default"


def test_ONEK_CAKISMASI_YOK():
    """Yonetiyor'un HICBIR tipi `dukkan_` ile baslamiyor.

    Baslasaydi o tip Dukkan kanalina kayar ve kullanici onu pazar yeri
    anahtariyla kapatabilirdi.
    """
    from app.push_kanal import DUKKAN_ONEK, KRITIK_TIPLER, OZEL_KANALLI_TIPLER

    for tip in set(KRITIK_TIPLER) | set(OZEL_KANALLI_TIPLER):
        assert not tip.startswith(DUKKAN_ONEK), tip


def test_TUM_DUKKAN_TIPLERI_ONEKLI():
    """`TIPLER` sozlugundeki her anahtar `dukkan_` onekli olmali.

    Oneksiz bir tip DOGRU calisiyor gibi gorunur (bildirim satiri yazilir,
    push gider) ama YANLIS KANALDAN gider — sessiz bir kusur.
    """
    from app.dukkan.bildirim import TIPLER
    from app.push_kanal import DUKKAN_ONEK

    for tip in TIPLER:
        assert tip.startswith(DUKKAN_ONEK), tip


# ==================================================================== #
# 2. TERCIH UCU
# ==================================================================== #

def test_TERCIH_VARSAYILAN_ACIK(client):
    """Bildirim bir TERCIHTIR, riza degil. Kapali baslasaydi ilk
    teklifini goremeyen kullanici pazar yerinin bozuk oldugunu
    dusunurdu."""
    k = _giris(client)
    r = client.get("/dukkan/bildirim-tercihi", headers=k["h"])
    assert r.status_code == 200
    assert r.json() == {"bildirim_acik": True, "bildirim_sesli": True}


def test_TERCIH_YAZ_SUNUCUDAKI_HALI_DONER(client):
    k = _giris(client)
    r = client.patch("/dukkan/bildirim-tercihi", headers=k["h"],
                     json={"bildirim_acik": False})
    assert r.status_code == 200
    # Istemcinin yazdigini degil SUNUCUDAKI hali doner (P217).
    assert r.json()["bildirim_acik"] is False
    assert r.json()["bildirim_sesli"] is True
    assert client.get("/dukkan/bildirim-tercihi",
                      headers=k["h"]).json()["bildirim_acik"] is False


def test_BOS_GOVDE_400(client):
    """"Hicbir alan verilmedi" ile "hepsi ayni kaldi" ayni yanit olsaydi,
    istemci hatasini kimse gormezdi."""
    k = _giris(client)
    assert client.patch("/dukkan/bildirim-tercihi", headers=k["h"],
                        json={}).status_code == 400


def test_TERCIH_JETONSUZ_401(client):
    assert client.get("/dukkan/bildirim-tercihi").status_code == 401
    assert client.patch("/dukkan/bildirim-tercihi",
                        json={"bildirim_acik": False}).status_code == 401


def test_TERCIH_BASKASINI_ETKILEMEZ(client):
    """IDOR: A'nin kapatmasi B'yi kapatmamali."""
    a, b = _giris(client), _giris(client)
    client.patch("/dukkan/bildirim-tercihi", headers=a["h"],
                 json={"bildirim_acik": False})
    assert client.get("/dukkan/bildirim-tercihi",
                      headers=b["h"]).json()["bildirim_acik"] is True


# ==================================================================== #
# 3. AKISI GERCEKTEN SUR: `bildir()` NE GONDERIYOR
# ==================================================================== #
# Yukaridaki testler kanal SECIMINI olcuyor. Bu bolum bir adim otesini
# olcuyor: `bildir()` o secimi saglayiciya GERCEKTEN VERIYOR MU. F6'da
# vermiyordu — `send()` cagrisinda `kanal`/`ses` HIC yoktu ve bildirimler
# Android'in isimsiz varsayilan kanalina duserdi (P207'de olculen kusur).
#
# Taklit SAGLAYICI SINIRINA konuyor (P200 dersi): `bildir`in kendisi,
# gercek veritabani oturumu ve gercek tercih sorgusuyla kosuyor. Repo
# duzeyinde taklit, tam da kirilan katmani atlardi.

class _SahteSaglayici:
    name = "sahte"

    def __init__(self):
        self.cagrilar: list[dict] = []

    def send(self, tokens, *, title, body, data=None, kanal=None, ses=None):
        from app.push import PushResult

        self.cagrilar.append({"tokens": list(tokens), "kanal": kanal,
                              "ses": ses, "data": data})
        return PushResult(provider="sahte", sent=len(list(tokens)),
                          status="ok", token_sonuc={})


@pytest.fixture
def sahte_push(monkeypatch):
    s = _SahteSaglayici()
    import app.push

    monkeypatch.setattr(app.push, "get_push_provider", lambda: s)
    return s


@pytest.fixture(autouse=True)
async def _havuzu_bosalt():
    """Her testten SONRA motoru kapat.

    P187 DERSI: asyncpg baglantilari OLUSTURULDUKLARI event loop'a
    baglidir. pytest-asyncio her teste yeni loop verdigi icin, havuzda
    kalan baglanti bir sonraki testin (ya da teardown'un) loop'unda
    "Event loop is closed" ile patlar. Testi degil ALTYAPIYI olcen bir
    kirmizi — ve gercekten bu dosyada bir kez yasandi.

    Prod'da ayni sinif Celery gorevlerinde yasanmisti (idle-in-transaction
    90/100); orada da cozum gorev basina `engine.dispose()`.
    """
    yield
    from app.dukkan.veritabani import engine

    await engine.dispose()


async def _oturum():
    from app.dukkan.veritabani import SessionLocal

    return SessionLocal()


@pytest.fixture
async def kullanici(dukkan_conn):
    """Cihazi kayitli bir Dukkan kullanicisi (dogrudan SQL — bu bolum
    HTTP akisini degil `bildir()`i olcuyor)."""
    kid = uuid.uuid4()
    dukkan_conn.execute(
        "INSERT INTO dukkan.dukkan_kullanici (id, telefon, durum) "
        "VALUES (%s, %s, 'aktif')", (kid, _tel()))
    dukkan_conn.execute(
        "INSERT INTO dukkan.dukkan_cihaz (kullanici_id, fcm_token, platform) "
        "VALUES (%s, %s, 'android')", (kid, f"fcm-{uuid.uuid4().hex}"))
    yield kid
    dukkan_conn.execute("DELETE FROM dukkan.dukkan_kullanici WHERE id=%s", (kid,))


async def test_BILDIR_KANALI_VE_SESI_SAGLAYICIYA_VERIYOR(kullanici, sahte_push):
    from app.dukkan.bildirim import bildir

    db = await _oturum()
    try:
        await bildir(db, kullanici_id=kullanici, tip="dukkan_teklif_geldi",
                     baslik="B", govde="G", veri={"talep_id": str(uuid.uuid4())})
        await db.commit()
    finally:
        await db.close()

    assert len(sahte_push.cagrilar) == 1, "push HIC denenmedi"
    c = sahte_push.cagrilar[0]
    assert c["kanal"] == KANAL_DUKKAN, c
    # Yonetiyor'un kimlik sesi DEGIL.
    assert c["ses"] == "default", c


async def test_TERCIH_KAPALIYSA_PUSH_YOK_AMA_SATIR_VAR(
        kullanici, sahte_push, dukkan_conn):
    """Kapali tercih push'u SUSTURUR, olayi SILMEZ.

    Sira onemli: satir once yaziliyor, tercihe SONRA bakiliyor.
    Tersi olsaydi kullanici uygulamayi actiginda olayi hic goremezdi.
    """
    dukkan_conn.execute(
        "UPDATE dukkan.dukkan_kullanici SET bildirim_acik=false WHERE id=%s",
        (kullanici,))

    from app.dukkan.bildirim import bildir

    db = await _oturum()
    try:
        yeni = await bildir(db, kullanici_id=kullanici, tip="dukkan_yeni_talep",
                            baslik="B", govde="G",
                            veri={"isletme_id": str(uuid.uuid4())})
        await db.commit()
    finally:
        await db.close()

    assert sahte_push.cagrilar == [], "tercih KAPALI iken push gitti"
    n = dukkan_conn.execute(
        "SELECT count(*) FROM dukkan.bildirim WHERE id=%s", (yeni,)).fetchone()[0]
    assert n == 1, "tercih kapaliyken KALICI SATIR da yazilmamis"


async def test_SESSIZ_TERCIHI_KANALI_DEGISTIRIR(kullanici, sahte_push,
                                                dukkan_conn):
    """`bildirim_sesli=false` -> SESSIZ kanal. Android'de kanalin sesi
    sonradan degistirilemedigi icin "sesi kapat" ancak BASKA KANALA
    gecerek yapilabilir."""
    dukkan_conn.execute(
        "UPDATE dukkan.dukkan_kullanici SET bildirim_sesli=false WHERE id=%s",
        (kullanici,))

    from app.dukkan.bildirim import bildir

    db = await _oturum()
    try:
        await bildir(db, kullanici_id=kullanici, tip="dukkan_teklif_geldi",
                     baslik="B", govde="G", veri={"talep_id": str(uuid.uuid4())})
        await db.commit()
    finally:
        await db.close()

    c = sahte_push.cagrilar[0]
    assert c["kanal"] == KANAL_SESSIZ, c
    assert c["ses"] is None, c
