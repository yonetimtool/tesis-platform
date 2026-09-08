"""(DUKKAN F8a) TALEP/TEKLIF/IS AKISINDA PARA YOKTUR — YAPISAL KILIT.

===========================================================================
NEDEN YORUM DEGIL TEST
===========================================================================
"Bu akisa odeme eklemeyin" cumlesini bir dosya basligina yazmak, o dosyayi
okuyani baglar. Alti ay sonra `is_kaydi`ya `odendi_at` eklemek isteyen
kisi, muhtemelen goc dosyasini yazacak ve o basligi hic gormeyecek.

Bu projede ayni ders daha once alindi: "Dukkan Yonetiyor'a yazmaz" kurali
yorumla degil ROL YETKISIYLE zorlandi (goc 0113) ve testle kilitlendi.
Ayni yaklasim burada da: kisit, kirildiginda KIRMIZI YANAN bir sey.

===========================================================================
KILIT DAR TUTULDU — REKLAM TARAFI SERBEST
===========================================================================
Yasak YALNIZ uc tabloya bakiyor: `talep`, `teklif`, `is_kaydi`. Bunlar
sakin<->isletme akisi ve orada para YOK.

Reklam tarafinda (`reklam_*`) odeme GERCEK ve MESRU: isletme -> platform
DOGRUDAN SATIS, aracilik degil. Orayi da yasaklamak, gelir modelini
imkansiz kilardi. Genis bir yasak, ilk mesru ihtiyacta devre disi
birakilir ve o andan sonra hicbir sey korumaz.

===========================================================================
NE OLCULUYOR
===========================================================================
1. Uc tabloda odeme ima eden SUTUN yok.
2. `is_kaydi.durum` icinde `anlasmazlik` yok (platform hakemlik etmez).
3. Teklif kabulu bir ODEME KAYDI URETMIYOR — akis GERCEKTEN surulerek.
4. `teklif.tutar_kurus` hala BEYAN olarak calisiyor (NULL = "yerinde
   gormem gerek"), yani kilit fiyat bilgisini KALDIRMIYOR.
"""
from __future__ import annotations

import uuid

import pytest

#: Bu tablolarda BULUNMAMASI gereken sutun adi parcalari.
#:
#: Parca eslesmesi (substring) bilerek: `odendi_at`, `odeme_id`,
#: `komisyon_kurus` gibi turevlerin hepsini yakalar. Tam ad listesi
#: yazmak, ilk yaratici adlandirmada bosa duserdi.
YASAK_PARCALAR = (
    "odeme", "odendi", "komisyon", "tahsilat", "siparis", "fatura",
    "iade", "bakiye", "mutabakat", "escrow", "kapora", "pos_",
    "payment", "invoice", "refund", "order_",
)

#: Sakin <-> isletme akisinin tablolari. Reklam tablolari BILEREK YOK.
AKIS_TABLOLARI = ("talep", "teklif", "is_kaydi")


def test_AKIS_TABLOLARINDA_ODEME_SUTUNU_YOK(dukkan_conn):
    bulunanlar: list[str] = []
    for tablo in AKIS_TABLOLARI:
        sutunlar = [
            r[0] for r in dukkan_conn.execute(
                "SELECT column_name FROM information_schema.columns "
                "WHERE table_schema='dukkan' AND table_name=%s", (tablo,)
            ).fetchall()
        ]
        for sutun in sutunlar:
            ad = sutun.lower()
            for parca in YASAK_PARCALAR:
                if parca in ad:
                    bulunanlar.append(f"{tablo}.{sutun} (~{parca})")

    assert not bulunanlar, (
        "Talep/teklif/is akisina ODEME IMA EDEN sutun eklenmis: "
        f"{bulunanlar}. Bu akista para YOKTUR — platform hizmet bedeline "
        "dokunmaz. Tahsilat eklemek 6563 anlaminda araci hizmet saglayici "
        "konumuna tasir; hukuki gorus almadan eklemeyin. Reklam tarafi "
        "(reklam_*) bu yasagin DISINDA ve orada odeme mesrudur."
    )


def test_ANLASMAZLIK_DURUMU_YOK(dukkan_conn):
    """Platform hakemlik etmiyor; bir uyusmazlik DURUMU tutmak "platform
    cozer" beklentisi yaratirdi."""
    tanim = dukkan_conn.execute(
        "SELECT pg_get_constraintdef(oid) FROM pg_constraint "
        "WHERE conname = 'is_kaydi_durum_check'"
    ).fetchone()
    assert tanim is not None, "durum CHECK kisiti kaybolmus"
    assert "anlasmazlik" not in tanim[0], tanim[0]
    # Kalan degerler DURUYOR: kilit durum makinesini bosaltmamali.
    for beklenen in ("kabul", "tamamlandi", "iptal"):
        assert beklenen in tanim[0], tanim[0]


def test_ANLASMAZLIK_YAZILAMAZ(dukkan_conn):
    """CHECK gercekten zorluyor mu — yazmayi DENEYEREK."""
    import psycopg

    with pytest.raises(psycopg.errors.CheckViolation):
        dukkan_conn.execute(
            "UPDATE dukkan.is_kaydi SET durum='anlasmazlik' "
            "WHERE id = (SELECT id FROM dukkan.is_kaydi LIMIT 1)"
        )


def test_TUTAR_BEYAN_OLARAK_KALIYOR(dukkan_conn):
    """Kilit fiyat BILGISINI kaldirmiyor: `tutar_kurus` duruyor ve
    NULL olabiliyor ("yerinde gormem gerek")."""
    satir = dukkan_conn.execute(
        "SELECT data_type, is_nullable FROM information_schema.columns "
        "WHERE table_schema='dukkan' AND table_name='teklif' "
        "  AND column_name='tutar_kurus'"
    ).fetchone()
    assert satir is not None, "tutar_kurus kaybolmus — fiyat BILGISI kalmali"
    assert satir[0] == "bigint", satir
    assert satir[1] == "YES", "NULL = 'yerinde gormem gerek' anlamini tasir"
