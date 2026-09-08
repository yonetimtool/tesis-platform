"""(DUKKAN F8c) ODEME — saglayici soyutlamasi, kart yasagi, abonelik.

===========================================================================
EN KRITIK IKI KILIT
===========================================================================
1. SAGLAYICI BAGLI DEGILKEN "ODENDI" DENMEZ. SMS turunde olculen kusurun
   (`gonderildi: true` + `gonderim: saglayici_bagli_degil`) odemedeki
   karsiligi cok daha agir: "odendi" diyen bir yanit reklami YAYINA ALIR
   ve platform parasini hic almadan hizmet verir.

2. KART BILGISI HICBIR TABLODA YOK. Kart numarasi, CVV ve son kullanma
   tarihi bizim surecimizden HIC GECMEZ; yalniz saglayicidan gelen token
   saklanir.

===========================================================================
TAKLIT SAGLAYICI SINIRINA KONUYOR (P200 DERSI)
===========================================================================
`SahteOdemeSaglayici` `OdemeSaglayici` arayuzunu uygular; akisin geri
kalani (satin alma satiri, reklam acma, abonelik) GERCEK kodla kosar.
Repo ya da uc duzeyinde taklit, tam da olculmek istenen katmani atlardi.
"""
from __future__ import annotations

import uuid

import pytest

#: Kart bilgisi ima eden sutun adi parcalari.
#:
#: `son_dort` ve `marka` BILEREK yok: ikisi de PCI kapsaminda
#: saklanabilir ve kullanicinin "hangi kart" sorusunu ancak onlar
#: yanitlar. Yasak KART NUMARASI ve dogrulama verisi icin.
#:
#: PARCA DEGIL SOZCUK ESLEMESI: ilk yazimda duz `in` kullanildi ve
#: "pan" parcasi `kapanis`, `kapandi_at`, `kapanis_sebebi` sutunlarini
#: YAKALADI. Yanlis alarm veren bir kilit, ilk kirmizida devre disi
#: birakilir — ve o andan sonra hicbir sey korumaz. Sutun adi `_` ile
#: bolunup SOZCUK olarak karsilastiriliyor.
YASAK_KART_SOZCUKLERI = frozenset({
    "pan", "cvv", "cvc", "cardnumber", "kartno",
})
#: Bunlar sozcuk sinirina gerek duymayacak kadar ozgun.
YASAK_KART_PARCALARI = (
    "kart_no", "card_number", "guvenlik_kodu", "son_kullanma",
    "expiry", "expire", "exp_month", "exp_year", "kart_sahibi",
)


def _kart_ihlali(sutun: str) -> str | None:
    ad = sutun.lower()
    for parca in YASAK_KART_PARCALARI:
        if parca in ad:
            return parca
    for sozcuk in ad.split("_"):
        if sozcuk in YASAK_KART_SOZCUKLERI:
            return sozcuk
    return None


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
# 1. KART BILGISI HICBIR YERDE
# ==================================================================== #

def test_KART_ALANI_HICBIR_TABLODA_YOK(dukkan_conn):
    """Kart numarasi bizim surecimizden HIC GECMEZ.

    Tablolari TARIYOR — belirli bir tabloyu degil: yarin eklenecek bir
    tabloda belirse de yakalansin.
    """
    sutunlar = dukkan_conn.execute(
        "SELECT table_name, column_name FROM information_schema.columns "
        "WHERE table_schema = 'dukkan'"
    ).fetchall()
    bulunanlar = [
        f"{t}.{c} (~{ihlal})" for t, c in sutunlar
        if (ihlal := _kart_ihlali(c))
    ]
    assert not bulunanlar, (
        f"KART BILGISI ima eden sutun(lar): {bulunanlar}. Kart numarasi, "
        "CVV ve son kullanma tarihi hicbir kosulda bizde tutulmaz — "
        "saglayici token doner, biz yalniz token'i sakleriz."
    )


def test_KART_SAKLA_ISTEGI_KART_ALANI_TASIMIYOR():
    """Istek modeli tip duzeyinde de kart tasimamali.

    Modele kart alani eklemek isteyen kisi, once bu testi ve modelin
    basligindaki gerekceyi silmek zorunda kalir.
    """
    from app.dukkan.odeme_akisi import KartSaklaIstek

    alanlar = set(KartSaklaIstek.model_fields)
    assert alanlar == {"takma_ad"}, alanlar


def test_ODEME_SONUCU_KART_TASIMIYOR():
    """Saglayici yanit tipleri de kart bilgisi tasimamali."""
    from dataclasses import fields

    from app.odeme import KartSonucu, OdemeSonucu

    for tip in (OdemeSonucu, KartSonucu):
        for f in fields(tip):
            assert _kart_ihlali(f.name) is None, (tip, f.name)


# ==================================================================== #
# 2. SAGLAYICI BAGLI DEGILKEN
# ==================================================================== #

def test_VARSAYILAN_SAGLAYICI_KAPALI():
    """Yapilandirma unutulursa hicbir sey tahsil edilmez.

    Ters yonde hata yapmak — "yapilandirilmadi" iken "odendi" demek —
    platformun parasini almadan hizmet vermesi demekti.
    """
    from app.odeme import KapaliOdemeSaglayici, odeme_saglayicisi

    s = odeme_saglayicisi()
    assert isinstance(s, KapaliOdemeSaglayici)
    assert s.yapilandirildi_mi() is False


def test_KAPALI_SAGLAYICI_ODENDI_DEMEZ():
    from app.odeme import DURUM_YAPILANDIRILMADI, KapaliOdemeSaglayici

    s = KapaliOdemeSaglayici()
    r = s.odeme_baslat(tutar_kurus=1000, aciklama="x", siparis_no="S1",
                       donus_url="", alici={})
    assert r.basarili is False
    assert r.durum == DURUM_YAPILANDIRILMADI
    # `basarili` ve `durum` ASLA CELISMEZ.
    assert not (r.basarili and r.durum != "basarili")


def test_TANINMAYAN_SAGLAYICI_KAPALIYA_DUSER(monkeypatch):
    """"Belki calisir" diye denemek yerine ACIKCA kapali."""
    from app import odeme
    from app.config import settings

    monkeypatch.setattr(settings, "odeme_saglayici", "boyle-bir-sey-yok",
                        raising=False)
    assert isinstance(odeme.odeme_saglayicisi(), odeme.KapaliOdemeSaglayici)


def test_SATIN_ALMA_UCU_503_DONER(client):
    """200 + `basarili: false` DEGIL: istemci basarili yanit dalina girip
    "odeme alindi" ekrani gosterirdi."""
    k = _giris(client)
    r = client.post("/dukkan/reklam/satin-al", headers=k["h"],
                    params={"isletme_id": str(uuid.uuid4())},
                    json={"paket_id": str(uuid.uuid4()),
                          "kategori_slug": "elektrikci",
                          "mahalle_id": str(uuid.uuid4()),
                          "fatura": {"unvan": "Test Ltd",
                                     "vkn": "1234567890",
                                     "adres": "Bir adres"}})
    assert r.status_code == 503, r.text
    assert r.json()["error"]["code"] == "odeme_yapilandirilmadi", r.text


def test_KART_SAKLAMA_UCU_503_DONER(client):
    k = _giris(client)
    r = client.post("/dukkan/odeme-yontemi", headers=k["h"],
                    json={"takma_ad": "Is karti"})
    assert r.status_code == 503, r.text
    assert r.json()["error"]["code"] == "odeme_yapilandirilmadi", r.text


def test_ABONELIK_GOREVI_SAGLAYICISIZ_SAYAC_SISIRMEZ():
    """Cekim denemeden once yapilandirma sorulur.

    Denemek ve "yapilandirilmadi" ile basarisiz saymak, abonelikleri
    KULLANICININ HATASI OLMADAN durdururdu.
    """
    from app.dukkan.gorevler import abonelik_cekimi

    sonuc = abonelik_cekimi()
    assert sonuc["atlandi"] == 1, sonuc
    assert sonuc["denenen"] == 0 and sonuc["basarisiz"] == 0, sonuc


# ==================================================================== #
# 3. SAHTE SAGLAYICI ILE AKISI GERCEKTEN SUR
# ==================================================================== #
# `SahteOdemeSaglayici` ADI ACIKCA SAHTE ve varsayilan DEGIL. Buradaki
# testler saglayiciyi SURECICINDE degistiriyor; `client` fixture'i canli
# sunucuya gittigi icin HTTP ucu degil, akis fonksiyonlari surulur.

@pytest.fixture
def sahte(monkeypatch):
    from app import odeme

    s = odeme.SahteOdemeSaglayici()
    monkeypatch.setattr(odeme, "odeme_saglayicisi", lambda: s)
    return s


def test_SAHTE_SAGLAYICI_BASARILI_ve_REDDEDEN_DALI_VAR(sahte):
    """Basarisizlik yolunu test edememek, onu ilk gercek hatada
    ogrenmek demektir."""
    sahte.reddet_tutari = 9999
    ok = sahte.sakli_kartla_cek(kart_token="t", kullanici_token="u",
                                tutar_kurus=1000, aciklama="x",
                                siparis_no="S1")
    assert ok.basarili and ok.islem_id

    red = sahte.sakli_kartla_cek(kart_token="t", kullanici_token="u",
                                 tutar_kurus=9999, aciklama="x",
                                 siparis_no="S2")
    assert red.basarili is False
    assert red.durum == "reddedildi"
    # SAGLAYICI HAM KODU TASINIR: destek yazismasinda gerekiyor.
    assert red.saglayici_kodu


def test_KDV_TAM_SAYI_ARITMETIGI():
    """`float` ile hesaplanan KDV, yuvarlama farkiyla faturayi bir kurus
    kaydirir ve mutabakati bozar."""
    from app.dukkan.odeme_akisi import _kdv_hesapla

    kdv, toplam = _kdv_hesapla(50000, 20.00)  # 500,00 TL + %20
    assert (kdv, toplam) == (10000, 60000), (kdv, toplam)

    # Kusuratli oran da tam sayi kalmali.
    kdv2, toplam2 = _kdv_hesapla(12345, 18.00)
    assert isinstance(kdv2, int) and isinstance(toplam2, int)
    assert toplam2 == 12345 + kdv2


def test_ABONELIK_TABLOSU_KART_YERINE_TOKEN_TUTUYOR(dukkan_conn):
    """Abonelik karta DOGRUDAN degil, `odeme_yontemi` uzerinden bagli."""
    sutunlar = [
        r[0] for r in dukkan_conn.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema='dukkan' AND table_name='abonelik'"
        ).fetchall()
    ]
    assert "odeme_yontemi_id" in sutunlar
    for sutun in sutunlar:
        assert _kart_ihlali(sutun) is None, sutun


def test_SAHIPSIZ_TAHSILAT_INDEKSI_VAR(dukkan_conn):
    """Odeme basarili + reklam acilamadi = IADE EDILECEK PARA.

    O satirlarin GORUNMESI sart; kismi indeksin varligi hem sorguyu
    ucuzlatiyor hem sorunun SORULACAGINI belgeliyor.
    """
    n = dukkan_conn.execute(
        "SELECT count(*) FROM pg_indexes WHERE schemaname='dukkan' "
        "AND indexname='ix_reklam_satin_alma_sahipsiz'"
    ).fetchone()[0]
    assert n == 1


def test_FATURA_ALANLARI_SATIN_ALMADA_DONDURULMUS(dukkan_conn):
    """Fatura kesildigi ANDAKI bilgilerle kesilir; isletme yarin unvan
    degistirirse gecen ayin faturasi DEGISMEMELI."""
    sutunlar = {
        r[0] for r in dukkan_conn.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema='dukkan' AND table_name='reklam_satin_alma'"
        ).fetchall()
    }
    for gerekli in ("fatura_unvan", "fatura_vkn", "fatura_vergi_dairesi",
                    "fatura_adres", "fatura_il", "fatura_ilce",
                    "tutar_kurus", "kdv_orani", "kdv_kurus",
                    "toplam_kurus", "fatura_no", "fatura_tarihi"):
        assert gerekli in sutunlar, gerekli


def test_PARA_ALANLARI_BIGINT_KURUS(dukkan_conn):
    """`float` ile saklanan para her zaman yanlis toplanir."""
    for tablo, sutun in (("reklam_satin_alma", "tutar_kurus"),
                         ("reklam_satin_alma", "toplam_kurus"),
                         ("reklam_paketi", "fiyat_kurus")):
        tip = dukkan_conn.execute(
            "SELECT data_type FROM information_schema.columns "
            "WHERE table_schema='dukkan' AND table_name=%s "
            "  AND column_name=%s", (tablo, sutun)).fetchone()[0]
        assert tip == "bigint", (tablo, sutun, tip)


def test_TEK_VARSAYILAN_KART(dukkan_conn):
    """Iki varsayilan kart olsaydi tekrarlayan cekimin hangisinden
    yapilacagi belirsiz olurdu."""
    n = dukkan_conn.execute(
        "SELECT count(*) FROM pg_indexes WHERE schemaname='dukkan' "
        "AND indexname='uq_odeme_yontemi_varsayilan'"
    ).fetchone()[0]
    assert n == 1


# ==================================================================== #
# 4. IDOR — GUVENLIK TARAMASINDA BULUNAN KUSURUN KILIDI
# ==================================================================== #
# Kart silme ucunda abonelik guncellemesi YALNIZ `odeme_yontemi_id` ile
# eslesiyordu; sahiplik kosulu YOKTU. Baskasinin kart kimligini gonderen
# saldirgan `silinen: 0` alirdi AMA O KULLANICININ ABONELIKLERI
# DURAKLATILIRDI — rakip bir isletmenin reklam yenilemesi disaridan
# durdurulabilirdi.
#
# Kart guncellemesi sahibe baglaydi; ikinci sorgu DEGILDI. Yani kusur
# "eksik bir kontrol" degil, "bir sorguda unutulmus" bir kontroldu — ve
# yanit gorunurde dogruydu (`silinen: 0`).

@pytest.fixture
def iki_kullanici_kartli(client, dukkan_conn):
    """A'nin bir karti ve o kartla bir abonelig; B ise yabanci."""
    a, b = _giris(client), _giris(client)
    kart_id = dukkan_conn.execute(
        "INSERT INTO dukkan.odeme_yontemi (kullanici_id, saglayici, "
        " kart_token, son_dort, marka, takma_ad) "
        "VALUES (%s, 'sahte', %s, '4242', 'visa', 'A karti') RETURNING id",
        (a["id"], f"tok-{uuid.uuid4().hex}")).fetchone()[0]

    # Aboneligin baglanabilmesi icin isletme + paket + kategori gerekli.
    isl_id = dukkan_conn.execute(
        "INSERT INTO dukkan.isletme (ad, slug, telefon, sahip_kullanici_id, "
        " durum) VALUES (%s, %s, %s, %s, 'onayli') RETURNING id",
        (f"IDOR {uuid.uuid4().hex[:6]}", f"idor-{uuid.uuid4().hex[:8]}",
         _tel(), a["id"])).fetchone()[0]
    paket_id = dukkan_conn.execute(
        "INSERT INTO dukkan.reklam_paketi (ad, kapsam, gun, fiyat_kurus) "
        "VALUES (%s, 'il', 30, 1000) RETURNING id",
        (f"IDOR {uuid.uuid4().hex[:6]}",)).fetchone()[0]
    il_id = dukkan_conn.execute(
        "SELECT id FROM dukkan.il ORDER BY id LIMIT 1").fetchone()[0]
    kat_id = dukkan_conn.execute(
        "SELECT id FROM dukkan.kategori WHERE ust_id IS NOT NULL "
        "ORDER BY id LIMIT 1").fetchone()[0]
    ab_id = dukkan_conn.execute(
        "INSERT INTO dukkan.abonelik (isletme_id, paket_id, "
        " odeme_yontemi_id, kapsam, il_id, kategori_id, sonraki_cekim) "
        "VALUES (%s, %s, %s, 'il', %s, %s, now() + interval '30 days') "
        "RETURNING id", (isl_id, paket_id, kart_id, il_id, kat_id)
    ).fetchone()[0]

    yield {"a": a, "b": b, "kart": str(kart_id), "abonelik": str(ab_id)}
    dukkan_conn.execute("DELETE FROM dukkan.abonelik WHERE id=%s", (ab_id,))
    dukkan_conn.execute("DELETE FROM dukkan.isletme WHERE id=%s", (isl_id,))
    dukkan_conn.execute("DELETE FROM dukkan.reklam_paketi WHERE id=%s",
                        (paket_id,))
    dukkan_conn.execute("DELETE FROM dukkan.odeme_yontemi WHERE id=%s",
                        (kart_id,))


def test_YABANCI_KART_SILME_ABONELIGI_DURAKLATMAZ(
        client, dukkan_conn, iki_kullanici_kartli):
    """B, A'nin kart kimligiyle A'nin aboneligini duraklatamamali."""
    v = iki_kullanici_kartli
    r = client.delete(f"/dukkan/odeme-yontemi/{v['kart']}",
                      headers=v["b"]["h"])
    assert r.status_code == 200, r.text
    assert r.json() == {"silinen": 0, "etkilenen_abonelik": 0}, r.text

    durum = dukkan_conn.execute(
        "SELECT durum FROM dukkan.abonelik WHERE id=%s",
        (v["abonelik"],)).fetchone()[0]
    assert durum == "aktif", (
        "YABANCI istek aboneligi duraklatti — IDOR")


def test_SAHIBI_SILINCE_ABONELIK_DURAKLAR(
        client, dukkan_conn, iki_kullanici_kartli):
    """Ters yon: duzeltme MESRU davranisi bozmamali.

    Kart silme yaniti `etkilenen_abonelik` DONER — kullanicinin o kartla
    yenilenen aboneliklerin duracagini BILMESI icin.
    """
    v = iki_kullanici_kartli
    r = client.delete(f"/dukkan/odeme-yontemi/{v['kart']}",
                      headers=v["a"]["h"])
    assert r.status_code == 200, r.text
    assert r.json()["silinen"] == 1, r.text
    assert r.json()["etkilenen_abonelik"] == 1, r.text

    durum = dukkan_conn.execute(
        "SELECT durum FROM dukkan.abonelik WHERE id=%s",
        (v["abonelik"],)).fetchone()[0]
    assert durum == "duraklatildi", durum
