"""(P134) GUNLUK GORUNURLUGU + PII MASKELEME.

IKI SORU OLCULUR:
  1. INFO satirlari GERCEKTEN cikiyor mu? (P134'e kadar cikmiyordu — kok
     logger WARNING'deydi ve hicbir yapilandirma yoktu)
  2. Gorunur olurken KISISEL VERI de gorunur oldu mu? (olmamali)

Ikincisi bu turun asil bulgusudur: "INFO'yu ac" isini duz yapmak telefon
numaralarini, e-posta adreslerini, mesaj govdelerini ve daire/ad
alanlarini konteyner gunluguune yazmaya baslardi. `audit_log`un gecelik
saklama gorevi VAR; konteyner gunlugunun YOK.
"""
from __future__ import annotations

import logging

import pytest

from app.gunlukleme import (
    govde_ozeti,
    guvenli_alanlar,
    maskele_kimlik,
    yapilandir,
)


@pytest.fixture(autouse=True)
def _pii_kapali(monkeypatch):
    """Varsayilan GUVENLI taraf: her test acikca aksini soylemedikce."""
    monkeypatch.delenv("LOG_PII", raising=False)


@pytest.fixture(autouse=True)
def _kok_handlerlari_geri_ver():
    """`yapilandir()` KOK HANDLER'LARI SIFIRLAR — pytest'inkini de.

    `logging.basicConfig(force=True)` uretimde DOGRU davranistir (iki
    handler ayni satiri iki kez yazar) ama testte yan etkisi vardir:
    pytest'in `caplog` handler'ini da soker ve o testten SONRAKI butun
    testler icin kayit toplanmaz. Bu depoda `caplog` kullanan baska dosya
    YOK (olculdu) ama kilit ileride biri ekledigde sessizce bozulmasin
    diye burada duruyor: her testten sonra kok handler listesi geri konur.
    """
    kok = logging.getLogger()
    onceki = list(kok.handlers)
    onceki_seviye = kok.level
    yield
    kok.handlers[:] = onceki
    kok.setLevel(onceki_seviye)


# --------------------------- 1. GORUNURLUK -------------------------------- #
def test_INFO_gercekten_cikiyor(caplog):
    """P134 oncesi bu test DUSERDI: kok logger WARNING'deydi.

    `caplog` kendi handler'ini taktigi icin tek basina yeterli kanit
    degildir — asil kanit `test_kok_logger_INFO_seviyesinde`. Bu test
    cagri yolunun calistigini olcer.
    """
    yapilandir("INFO")
    # `yapilandir` caplog'un handler'ini sokmus olur; geri tak (fixture
    # test sonunda kok listesini zaten eski hâline dondurur).
    logging.getLogger().addHandler(caplog.handler)
    with caplog.at_level(logging.INFO):
        logging.getLogger("scheduler.notify").info("EXTERNAL_NOTIFY: %s", "deneme")
    assert any("EXTERNAL_NOTIFY" in r.message for r in caplog.records)


def test_kok_logger_INFO_seviyesinde():
    """Asil olcum: uygulama logger'i INFO'yu GECIRIYOR mu.

    P134 oncesi canli konteynerde
    `logging.getLogger("scheduler.notify").isEnabledFor(INFO)` **False**
    donuyordu; bu satir tam olarak onu kilitler.
    """
    yapilandir("INFO")
    assert logging.getLogger("scheduler.notify").isEnabledFor(logging.INFO)
    assert logging.getLogger("app.push").isEnabledFor(logging.INFO)
    assert logging.getLogger().handlers, "kok logger'da handler yok"


def test_GECERSIZ_seviye_gunlugu_KAPATMAZ():
    """Yanlis yazilmis bir `LOG_LEVEL` sessizce her seyi susturmasin."""
    yapilandir("SACMALIK")
    assert logging.getLogger("app.push").isEnabledFor(logging.INFO)


def test_GURULTULU_kutuphaneler_kisilir():
    """Kutuphane INFO'lari uygulamanin kaydini bogmasin."""
    yapilandir("INFO")
    assert not logging.getLogger("httpx").isEnabledFor(logging.INFO)
    # Ama uygulama logger'i acik kalir.
    assert logging.getLogger("app.mesajlasma").isEnabledFor(logging.INFO)


def test_handler_IKIYE_katlanmaz():
    """`yapilandir` iki kez cagrilirsa satirlar iki kez yazilmasin."""
    yapilandir("INFO")
    once = len(logging.getLogger().handlers)
    yapilandir("INFO")
    assert len(logging.getLogger().handlers) == once


# ------------------------ 2. PII MASKELEME -------------------------------- #
@pytest.mark.parametrize(
    "ham,beklenen_yok",
    [
        ("+905321234567", "5321234"),
        ("05321234567", "3212345"),
        ("ornek.kisi@site.com", "ornek.kisi"),
    ],
)
def test_kimlik_MASKELENIR(ham, beklenen_yok):
    maskeli = maskele_kimlik(ham)
    assert beklenen_yok not in maskeli, maskeli
    assert "*" in maskeli


def test_eposta_ALAN_ADI_korunur():
    """"Hangi kuruma gitti" teshis icin gerekli; alan adi tek basina bir
    kisiyi tanimlamaz."""
    assert maskele_kimlik("ali@acmeplaza.com").endswith("@acmeplaza.com")


def test_kisa_deger_TAMAMEN_maskelenir():
    # 4 karakter ve altinda "bas 3 + son 4" kurali degeri OLDUGU GIBI
    # birakirdi; o durumda maskeleme hicbir sey yapmamis olurdu.
    assert set(maskele_kimlik("1234")) == {"*"}
    assert maskele_kimlik(None) == "-"


def test_GOVDE_yazilmaz_uzunluk_yazilir():
    ozet = govde_ozeti("Aidat borcunuz 1.250 TL, A-12 dairesi.")
    assert "Aidat" not in ozet
    assert "A-12" not in ozet
    assert "karakter" in ozet


def test_bildirim_parametreleri_ANAHTARLA_yazilir():
    alanlar = guvenli_alanlar({"ad": "Ayşe Yılmaz", "daire": "A-12", "plan": "Gece"})
    metin = str(alanlar)
    assert "Ayşe" not in metin and "A-12" not in metin
    # Anahtarlar KALIR: "hangi bildirim, hangi alanlarla" sorusu yanitlanir.
    assert "ad" in alanlar and "daire" in alanlar


def test_LOG_PII_acikken_ham_deger_gelir(monkeypatch):
    """Yerel gelistirme anahtari — ACIK bir secim olmali."""
    monkeypatch.setenv("LOG_PII", "1")
    assert maskele_kimlik("+905321234567") == "+905321234567"
    assert govde_ozeti("merhaba") == "merhaba"
    assert guvenli_alanlar({"ad": "Ayşe"}) == {"ad": "Ayşe"}


# ------------------- 3. CAGRI YERLERI GERCEKTEN MASKELI ------------------- #
def test_SMS_saglayicisi_numarayi_YAZMIYOR(caplog):
    """Yardimci dogru olup CAGRI YERININ onu kullanmamasi mumkundur.

    Bu yuzden saglayici GERCEKTEN cagrilir ve uretilen kayit denetlenir.
    """
    from app.mesajlasma import LogSmsSaglayici

    yapilandir("INFO")
    logging.getLogger().addHandler(caplog.handler)
    with caplog.at_level(logging.INFO):
        LogSmsSaglayici().gonder("+905321234567", None, "Aidat borcunuz 1.250 TL.")
    kayit = "\n".join(r.getMessage() for r in caplog.records)
    assert "5321234" not in kayit, kayit
    assert "Aidat" not in kayit, kayit
    # Ve satir GERCEKTEN yazildi (bos kayit "gecti" demesin).
    assert "[SMS/log]" in kayit


def test_EPOSTA_saglayicisi_adresi_YAZMIYOR(caplog):
    from app.mesajlasma import LogEpostaSaglayici

    yapilandir("INFO")
    logging.getLogger().addHandler(caplog.handler)
    with caplog.at_level(logging.INFO):
        LogEpostaSaglayici().gonder(
            "ali.veli@site.com", "Aidat bildirimi", "A-12 dairesi icin borc."
        )
    kayit = "\n".join(r.getMessage() for r in caplog.records)
    assert "ali.veli" not in kayit, kayit
    assert "A-12" not in kayit, kayit
    # Konu KALIR: kisisel veri tasimaz, "hangi bildirim"i soyler.
    assert "Aidat bildirimi" in kayit


def test_EXTERNAL_NOTIFY_deger_YAZMIYOR(caplog):
    """Ucuncu cagri yeri — hafizadaki ertelenmis isin ASIL hedefi.

    Not soyle diyordu: "EXTERNAL_NOTIFY push gunlukleri gorunmuyor". Artik
    goruunuyor; bu test gorunur olurken `ad`/`daire` degerlerinin de
    gorunur OLMADIGINI olcer. Yardimci dogru olup cagri yerinin onu
    kullanmamasi mumkundur, bu yuzden fonksiyon GERCEKTEN cagrilir.
    """
    from app.scheduler.notify import dispatch_external

    yapilandir("INFO")
    logging.getLogger().addHandler(caplog.handler)
    with caplog.at_level(logging.INFO):
        dispatch_external(
            "kacirilan_tur",
            params={"ad": "Ayşe Yılmaz", "daire": "A-12", "plan": "Gece"},
        )
    kayit = "\n".join(r.getMessage() for r in caplog.records)
    assert "EXTERNAL_NOTIFY" in kayit, "satir HIC yazilmadi"
    assert "Ayşe" not in kayit, kayit
    assert "A-12" not in kayit, kayit
    # Alan ADLARI kalir: "hangi bildirim, hangi alanlarla" yanitlanir.
    assert "daire" in kayit and "plan" in kayit
