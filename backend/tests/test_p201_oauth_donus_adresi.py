"""(P201) OAUTH DONUS ADRESI — 303'un NEREYE gittigi.

===========================================================================
PROD'DA OLCULEN CIKMAZ
===========================================================================
Google ile yonetici kaydi donguye giriyordu. Prod izi:

    POST /auth/oauth/baslat/google        200
    GET  /auth/oauth/callback/google...   303
    GET  /auth/oauth/saglayicilar         200   <- sayfa BASTAN yuklendi

Arada `POST /auth/oauth/sonuc` YOK: 303, sonuc kimligini COZEN bir
sayfaya birakmiyordu.

Kok neden KODDA DEGIL YAPILANDIRMADAYDI (`OAUTH_KAYIT_DONUS` `/kayit`i
gosteriyordu; `?oauth=`i cozen tek sayfa `/giris/oauth`tur). Ama adresin
URETILDIGI yer bir satir arasiydi ve TEST EDILEMIYORDU. Artik
`_donus_url` ayri bir fonksiyon ve davranisi burada kilitli.

GELISTIRMEDE NEDEN GORULMEDI: `OAUTH_KAYIT_DONUS` dev'de BOS, yani SSO
kaydi dev'de hic calismiyor (`basla` 503 doner). Dev bu akisi
olcemezdi — asagidaki son test bunu ACIKCA kaydeder.
"""
from __future__ import annotations

import pytest

from app.routers.oauth import _donus_adresi, _donus_url


def test_SONUC_KIMLIGI_ADRESE_EKLENIR():
    assert (
        _donus_url("https://app.yonetiyor.com/giris/oauth", "abc123")
        == "https://app.yonetiyor.com/giris/oauth?oauth=abc123"
    )


def test_ADRESTE_ZATEN_SORGU_VARSA_ikinci_soru_isareti_URETILMEZ():
    """Ikinci bir `?` parametreyi SESSIZCE kaybettirir — tarayici onu
    yolun parcasi sayar ve sayfa `oauth`u hic gormez. Tam da prod'da
    gorulen belirtinin bir baska uretim yolu."""
    assert (
        _donus_url("https://app.yonetiyor.com/giris/oauth?dil=tr", "abc123")
        == "https://app.yonetiyor.com/giris/oauth?dil=tr&oauth=abc123"
    )


def test_KAYIT_NIYETI_KAYIT_ADRESINE_gider(monkeypatch):
    """Kayit niyeti WEB adresini KULLANMAZ. Ikisi ayrildigi icin
    (P180) yanlis olan biri otekini gizleyemez."""
    from app.config import settings

    monkeypatch.setattr(settings, "oauth_web_donus", "https://app.x.com/giris/oauth")
    monkeypatch.setattr(settings, "oauth_kayit_donus", "https://app.x.com/giris/oauth")
    assert _donus_adresi("web", "kayit") == "https://app.x.com/giris/oauth"
    assert _donus_adresi("web", "giris") == "https://app.x.com/giris/oauth"
    # Mobil niyeti kayit DEGILSE ozel semaya gider.
    monkeypatch.setattr(settings, "oauth_mobil_donus", "com.app.yonetiyor://oauth")
    assert _donus_adresi("mobil", "giris") == "com.app.yonetiyor://oauth"


@pytest.mark.parametrize("niyet", ["kayit", "giris"])
def test_DONUS_BOSSA_ADRES_BOS_DONER_ve_basla_KAPALI_sayar(monkeypatch, niyet):
    """BOS = O YUZEY KAPALI. `basla` bunu kullanici siteden AYRILMADAN
    kontrol eder (503); yanlis yapilandirma saglayicinin sayfasinda
    404 olarak cikmamali."""
    from app.config import settings

    monkeypatch.setattr(settings, "oauth_web_donus", "")
    monkeypatch.setattr(settings, "oauth_kayit_donus", "")
    assert _donus_adresi("web", niyet) == ""


def test_GELISTIRME_ORTAMI_bu_akisi_OLCEMEZ():
    """OLCUM KAYDI, iddia degil.

    Dev'de `OAUTH_KAYIT_DONUS` bostur; yani SSO kaydi gelistirmede HIC
    calismaz ve donus adresi orada DOGRULANAMAZ. Iki tur boyunca
    "gelistirmede olctum" demenin neden yetmedigi budur. Bu test dev'de
    bayragin KAPALI oldugunu KAYDEDER; bir gun dev'de acilirsa duser ve
    o zaman bu not guncellenmelidir.
    """
    from app.config import settings

    if settings.oauth_kayit_donus:
        pytest.skip("dev'de SSO kaydi ACIK — not guncellenmeli")
    assert _donus_adresi("web", "kayit") == ""
