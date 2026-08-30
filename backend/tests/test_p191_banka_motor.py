"""(P191 §4) BANKA EŞLEŞTİRME MOTORU — senaryo senaryo.

Kullanıcının listelediği senaryoların HEPSİ burada ya da uçtan uca
testte (`test_p191_banka_uc.py`) ölçülür. Motor saf olduğu için her
senaryo tek bir çağrıyla ve kesin bir beklentiyle yazılabiliyor —
"eşleştirme galiba çalışıyor" diyecek bir gri alan kalmıyor.

KURAL: şüphede kalınan her durum `manuel_inceleme`dir. Yanlış eşleşme
BAŞKASININ borcunu kapatır ve gerçek borçlunun borcunu açık bırakır;
boş bırakmak yanlış eşleştirmekten iyidir.
"""
from __future__ import annotations

import pytest

from app.banka import (
    ESIK_OTOMATIK,
    Aday,
    Borc,
    Hareket,
    eslestir,
    fifo_dagit,
    iban_maskele,
    iban_normalize,
    sadelestir,
)

IBAN_A = "TR330006100519786457841326"
IBAN_B = "TR120006200519786457841399"


def _borc(aid: str, kalan: int, donem: str, vade: str | None = None) -> Borc:
    return Borc(assessment_id=aid, unit_id="u1", donem=donem, kalan_kurus=kalan, vade=vade)


def _aday(**kw) -> Aday:
    varsayilan = dict(user_id="u-1", ad="Ayşe Yılmaz", unit_id="d-1")
    varsayilan.update(kw)
    return Aday(**varsayilan)


# ============================== YARDIMCILAR ================================= #
def test_TURKCE_BUYUK_HARF_TUZAGI():
    """`İ`nin küçüğü `i` DEĞİL. Önce büyütüp sonra aksan ayıklanmalı."""
    assert sadelestir("ŞAHİN") == sadelestir("Sahin") == "SAHIN"
    assert sadelestir("Çağrı  Öz") == "CAGRI OZ"


def test_IBAN_bosluklu_ve_bosluksuz_AYNI_sayilir():
    assert iban_normalize("TR33 0006 1005 1978 6457 8413 26") == IBAN_A
    assert iban_normalize("tr330006100519786457841326") == IBAN_A
    assert iban_normalize("cop") is None


def test_IBAN_maskesi_yalniz_son_4_hane_gosterir():
    maske = iban_maskele(IBAN_A)
    assert maske.startswith("TR") and maske.endswith("1326")
    assert IBAN_A[4:20] not in maske


# ================================ FIFO ====================================== #
def test_FIFO_en_eski_vadeden_kapatir():
    dagilim = fifo_dagit(
        30000,
        (_borc("a", 10000, "2026-01"), _borc("b", 10000, "2026-02"), _borc("c", 10000, "2026-03")),
    )
    assert dagilim == (("a", 10000), ("b", 10000), ("c", 10000))


def test_KISMI_odeme_en_eskiyi_kapatir_kalani_boler():
    dagilim = fifo_dagit(15000, (_borc("a", 10000, "2026-01"), _borc("b", 10000, "2026-02")))
    assert dagilim == (("a", 10000), ("b", 5000))


def test_FAZLA_odeme_alacaga_yazilir():
    """Artan `None` anahtarıyla döner: daire alacağında bekler."""
    dagilim = fifo_dagit(25000, (_borc("a", 10000, "2026-01"),))
    assert dagilim == (("a", 10000), (None, 15000))


def test_BORC_YOKKEN_pesin_odeme_tamami_alacaga():
    assert fifo_dagit(50000, ()) == ((None, 50000),)


def test_VADE_VARSA_donem_degil_VADE_sirasi():
    """Vade alanı doluysa FIFO onu izler: 'en eski borç' vade demektir."""
    dagilim = fifo_dagit(
        10000,
        (
            _borc("yeni-donem-eski-vade", 10000, "2026-05", vade="2026-01-10"),
            _borc("eski-donem-yeni-vade", 10000, "2026-01", vade="2026-09-10"),
        ),
    )
    assert dagilim[0][0] == "yeni-donem-eski-vade"


# ========================== 1) ÖDEME REFERANSI ============================== #
def test_REFERANS_DOGRU_ve_TAM_odeme():
    aday = _aday(odeme_kodu="TS-A7K2M9", borclar=(_borc("a", 50000, "2026-01"),))
    karar = eslestir(
        Hareket(id="h1", tutar_kurus=50000, aciklama="AIDAT TS-A7K2M9 TESEKKURLER"), [aday]
    )
    assert karar.sonuc == "otomatik"
    assert karar.match_type == "odeme_kodu" and karar.confidence == 100
    assert karar.dagilim == (("a", 50000),)


def test_REFERANS_EKSIK_odeme_en_eskiyi_kapatir():
    aday = _aday(
        odeme_kodu="TS-A7K2M9",
        borclar=(_borc("a", 50000, "2026-01"), _borc("b", 50000, "2026-02")),
    )
    karar = eslestir(Hareket(id="h", tutar_kurus=60000, aciklama="TS-A7K2M9"), [aday])
    assert karar.dagilim == (("a", 50000), ("b", 10000))


def test_REFERANS_FAZLA_odeme_alacaga_gider():
    aday = _aday(odeme_kodu="TS-A7K2M9", borclar=(_borc("a", 50000, "2026-01"),))
    karar = eslestir(Hareket(id="h", tutar_kurus=75000, aciklama="TS-A7K2M9"), [aday])
    assert karar.dagilim == (("a", 50000), (None, 25000))


def test_TEK_TRANSFERLE_BIRKAC_AY():
    aday = _aday(
        odeme_kodu="TS-A7K2M9",
        borclar=(
            _borc("oca", 40000, "2026-01"),
            _borc("sub", 40000, "2026-02"),
            _borc("mar", 40000, "2026-03"),
        ),
    )
    karar = eslestir(Hareket(id="h", tutar_kurus=120000, aciklama="TS-A7K2M9 3 AYLIK"), [aday])
    assert [d[0] for d in karar.dagilim] == ["oca", "sub", "mar"]


def test_YANLIS_REFERANS_IBAN_GECMISIYLE_CELISIYORSA_MANUEL():
    """Kullanıcının açık kuralı. Referans A'yı, IBAN B'yi gösteriyorsa
    otomatik yazmak, kirasını başkasının hesabından gönderen kullanıcıda
    sessizce yanlış kişiye tahsilat yazmak olurdu."""
    a = _aday(user_id="A", ad="Ali Veli", odeme_kodu="TS-AAAAAA", borclar=(_borc("x", 1000, "2026-01"),))
    b = _aday(user_id="B", ad="Veli Ali", bilinen_ibanlar=(IBAN_A,), borclar=(_borc("y", 1000, "2026-01"),))
    karar = eslestir(
        Hareket(id="h", tutar_kurus=1000, aciklama="TS-AAAAAA", karsi_iban=IBAN_A), [a, b]
    )
    assert karar.sonuc == "manuel_inceleme"
    assert karar.neden == "referans_iban_celiskisi"
    assert karar.user_id is None


def test_AYNI_KISININ_IBANI_CELISKI_DEGIL():
    a = _aday(user_id="A", odeme_kodu="TS-AAAAAA", bilinen_ibanlar=(IBAN_A,),
              borclar=(_borc("x", 1000, "2026-01"),))
    karar = eslestir(
        Hareket(id="h", tutar_kurus=1000, aciklama="TS-AAAAAA", karsi_iban=IBAN_A), [a]
    )
    assert karar.sonuc == "otomatik"


# ============================ 2) GÖNDEREN IBAN ============================== #
def test_REFERANSSIZ_ama_IBAN_TANIDIK():
    a = _aday(user_id="A", bilinen_ibanlar=(IBAN_A,), borclar=(_borc("x", 30000, "2026-01"),))
    karar = eslestir(
        Hareket(id="h", tutar_kurus=30000, aciklama="HAVALE", karsi_iban=IBAN_A), [a]
    )
    assert karar.sonuc == "otomatik" and karar.match_type == "iban"
    assert karar.confidence >= ESIK_OTOMATIK


def test_AYNI_IBAN_IKI_KISIYE_BAGLIYSA_MANUEL():
    """Bir daire çok kişi (eşler/kiracı): ortak hesaptan gelen para hangi
    kişiye yazılacak? Seçim insanın."""
    a = _aday(user_id="A", bilinen_ibanlar=(IBAN_A,), borclar=(_borc("x", 100, "2026-01"),))
    b = _aday(user_id="B", ad="Es Kisi", bilinen_ibanlar=(IBAN_A,), borclar=(_borc("y", 100, "2026-01"),))
    karar = eslestir(Hareket(id="h", tutar_kurus=100, karsi_iban=IBAN_A), [a, b])
    assert karar.sonuc == "manuel_inceleme" and karar.neden == "iban_coklu_kisi"


def test_TANIMAYAN_IBAN_ad_yolunu_ENGELLEMEZ():
    a = _aday(user_id="A", ad="Ayşe Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    karar = eslestir(
        Hareket(id="h", tutar_kurus=30000, aciklama="AYSE YILMAZ AIDAT", karsi_iban=IBAN_B), [a]
    )
    assert karar.match_type == "ad_tutar"


# ========================= 3) AD + TUTAR + AÇIK BORÇ ======================== #
def test_AD_TAM_ve_TUTAR_TAM_otomatik_esige_ulasir():
    a = _aday(ad="Ayşe Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    karar = eslestir(Hareket(id="h", tutar_kurus=30000, aciklama="AYSE YILMAZ ODEME"), [a])
    assert karar.confidence >= ESIK_OTOMATIK and karar.sonuc == "otomatik"


def test_AD_ESLESMESI_TEK_BASINA_YETMEZ():
    """Kullanıcının açık kuralı: ad eşleşmesi denenir ama tek başına
    yeterli değildir — manuel incelemeye düşer."""
    a = _aday(ad="Ayşe Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    # Tutar borçla ilgisiz ve borç toplamının ÜSTÜNDE: yalnız ad tutuyor.
    karar = eslestir(Hareket(id="h", tutar_kurus=999999, aciklama="AYSE YILMAZ"), [a])
    assert karar.sonuc == "manuel_inceleme"


def test_SOYAD_eslesmesi_TEK_BASINA_asla_otomatik_degil():
    a = _aday(ad="Ayşe Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    karar = eslestir(Hareket(id="h", tutar_kurus=30000, aciklama="YILMAZ"), [a])
    assert karar.sonuc == "manuel_inceleme"


def test_TUTAR_TUTUYOR_ama_AD_TUTMUYOR_ADAY_DEGIL():
    """Ad eşleşmesi yoksa aday sayılmaz: yalnız tutara bakıp yazmak,
    aynı aidatı ödeyen 200 kişilik bir sitede kura çekmek olurdu."""
    a = _aday(ad="Ayşe Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    karar = eslestir(Hareket(id="h", tutar_kurus=30000, aciklama="HAVALE FAST"), [a])
    assert karar.sonuc == "manuel_inceleme" and karar.neden == "aday_yok"


def test_BERABERE_kalan_iki_aday_ONERI_URETMEZ():
    a = _aday(user_id="A", ad="Ali Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    b = _aday(user_id="B", ad="Ali Yılmaz", borclar=(_borc("y", 30000, "2026-01"),))
    karar = eslestir(Hareket(id="h", tutar_kurus=30000, aciklama="ALI YILMAZ"), [a, b])
    assert karar.sonuc == "manuel_inceleme" and karar.neden == "berabere"


def test_HIC_ESLESMEYEN_hareket():
    a = _aday(ad="Ayşe Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    karar = eslestir(Hareket(id="h", tutar_kurus=777, aciklama="BILINMEYEN GONDERIM"), [a])
    assert karar.sonuc == "manuel_inceleme" and karar.user_id is None


def test_ACIKLAMA_BOS_ya_da_KESIK():
    a = _aday(ad="Ayşe Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    for aciklama in ("", "   ", "AYS"):
        karar = eslestir(Hareket(id="h", tutar_kurus=30000, aciklama=aciklama), [a])
        assert karar.sonuc == "manuel_inceleme", aciklama


def test_GONDEREN_ADI_ALANI_da_okunur():
    """Bazı bankalar adı açıklamaya değil ayrı bir alana yazar."""
    a = _aday(ad="Ayşe Yılmaz", borclar=(_borc("x", 30000, "2026-01"),))
    karar = eslestir(
        Hareket(id="h", tutar_kurus=30000, aciklama="FAST", karsi_ad="AYSE YILMAZ"), [a]
    )
    assert karar.sonuc == "otomatik"


# =============================== ÇIKIŞLAR =================================== #
@pytest.mark.parametrize("aciklama", ["BANKA MASRAFI", "EFT KOMISYON", "IADE"])
def test_CIKIS_hareketi_ASLA_otomatik_degil(aciklama):
    """Banka masrafı/komisyon YÖNETİCİ ONAYINA düşer; otomatik gider
    YAZILMAZ (kullanıcının açık kuralı)."""
    a = _aday(odeme_kodu="TS-A7K2M9", borclar=(_borc("x", 100, "2026-01"),))
    karar = eslestir(
        Hareket(id="h", tutar_kurus=1500, aciklama=f"{aciklama} TS-A7K2M9", yon="cikis"), [a]
    )
    assert karar.sonuc == "manuel_inceleme" and karar.neden == "cikis_hareketi"


def test_BIR_KISI_COK_DAIRE_her_daire_ayri_aday():
    """Aynı kişi iki daireye bağlıysa iki ayrı aday üretilir (servis
    katmanı böyle topluyor); referans kodu ikisinde de aynıdır ve motor
    ÇAKIŞMAYI görür -> berabere değil, ilk eşleşen kod adayı seçilir.
    Bu testin işi davranışın TANIMLI olduğunu kilitlemek."""
    d1 = _aday(user_id="A", unit_id="d1", odeme_kodu="TS-A7K2M9",
               borclar=(_borc("x", 10000, "2026-01"),))
    d2 = _aday(user_id="A", unit_id="d2", odeme_kodu="TS-A7K2M9",
               borclar=(_borc("y", 10000, "2026-01"),))
    karar = eslestir(Hareket(id="h", tutar_kurus=10000, aciklama="TS-A7K2M9"), [d1, d2])
    assert karar.sonuc == "otomatik"
    assert karar.unit_id == "d1"  # listedeki İLK bağ; sıra servis katmanında belirli
