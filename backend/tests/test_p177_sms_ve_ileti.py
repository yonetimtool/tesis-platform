"""(P177 §6 + §9.11) SMS GONDERILMIYOR — ve bu bir KARAR, eksiklik degil.

===========================================================================
NEDEN AYRI BIR DOSYA
===========================================================================
"Hicbir yerde SMS gonderilmiyor" bir KABUL KRITERIDIR (§9.11) ve tek bir
akisin degil, TUM GONDERIM KATMANININ ozelligidir. Kayit akisi
testlerinin icine gomulseydi, kayit akisi kapaliyken (varsayilan)
olculmeden kalirdi.

OLCUM SUNUCUYA DEGIL KODA: SMS'in gitmedigi, saglayici SECIMINDEN
okunuyor. "Gonderilmedi"yi HTTP uzerinden olcmenin yolu yok — gitmeyen
bir SMS'in gozlenebilir bir izi yoktur.
"""
from __future__ import annotations

import pytest

from app.config import settings
from app.mesajlasma import (
    DURUM_YAPILANDIRILMADI,
    KapaliSmsSaglayici,
    LogSmsSaglayici,
    SaglayiciAyari,
    sms_saglayicisi,
)


def test_varsayilan_SMS_KAPALI():
    """§9.11 — varsayilan yapilandirmada SMS kanali kapalidir."""
    assert settings.sms_aktif is False


def test_kapali_bayrak_saglayiciyi_EZER():
    """Tesis kendi Netgsm bilgilerini girmis OLSA BILE SMS gitmez.

    Bu, testin asil degeri: kontrol `_ayardan_veya_env`DEN ONCE olmali.
    Sonra bakilsaydi, arayuzden SMS ayari girmis bir tesiste ana salter
    ETKISIZ kalirdi ve kimse fark etmezdi.
    """
    ayar = SaglayiciAyari(
        sms_saglayici="netgsm",
        sms_kullanici="kullanici",
        sms_parola="parola",
        sms_baslik="BASLIK",
    )
    saglayici = sms_saglayicisi(ayar)
    assert isinstance(saglayici, KapaliSmsSaglayici), (
        f"tesis ayari ana salteri ezdi: {type(saglayici).__name__}"
    )


def test_kapali_saglayici_GONDERILDI_DEMEZ():
    """P168'in kusuru tekrarlanmiyor: gonderilmemis mesaj 'gonderildi' olamaz.

    Bir SMS'in gidip gitmedigi HUKUKI bir sorudur (bildirim kaniti);
    yanlis bir "gonderildi" kaydi, olmayan bir bildirimi ISPAT gibi
    gosterirdi.
    """
    sonuc = KapaliSmsSaglayici().gonder("+905321112203", None, "deneme")
    assert sonuc.durum == DURUM_YAPILANDIRILMADI
    assert sonuc.durum != "gonderildi"
    # SEBEP AYIRT EDILEBILIR: "yapilandirilmadi" ile "kapali" farkli
    # eylemler gerektirir (birinde ayar doldurulur, otekinde yapilacak
    # bir sey yoktur).
    assert sonuc.hata == "sms_kanali_kapali"


def test_kapali_ile_yapilandirilmamis_AYIRT_EDILIYOR():
    """Iki sinif ayni sey degil ve arayuz farkli davranmali."""
    assert KapaliSmsSaglayici().ad != LogSmsSaglayici().ad


def test_ticari_ileti_VARSAYILAN_KAPALI():
    """§4 — riza SAKLANIR, gonderim KAPALI (sirket ve IYS kaydi yok)."""
    assert settings.ticari_ileti_aktif is False


def test_davet_yolu_SMS_DENEMEZ(monkeypatch):
    """Davet gonderimi SMS saglayicisini cagirsa da GONDERMEZ.

    `davet.davet_gonder` telefonu olan her kullaniciya once SMS dener.
    Bu test o cagrinin KAPALI saglayiciya dustugunu dogrular — yani davet
    akisina dokunmadan SMS'in kesildigini.
    """
    from app.gonderim import saglayici

    assert isinstance(saglayici("sms"), KapaliSmsSaglayici)


def test_ticari_ileti_kapisi_GONDERIM_YOLUNDA():
    """Bayrak DEKORATIF DEGIL: gonderim yolunda GERCEKTEN okunuyor.

    Bir ayar tanimlayip hicbir yerde okumamak, en sinsi kusur
    turlerinden biridir: yapilandirmada "kapali" yazar, mesaj yine
    gider. Bu test kaynagi TARAR — davranisi HTTP uzerinden olcmenin
    yolu yok, cunku olculmesi gereken sey GONDERILMEMESI.

    Kaynak taramasi kirilgan gorunur ama alternatifi yok ve kirilma
    yonu GUVENLI: satir tasinirsa test duser ve insan bakar.
    """
    from pathlib import Path

    kaynak = Path(__file__).resolve().parents[1] / "app" / "routers" / "mesajlar.py"
    metin = kaynak.read_text(encoding="utf-8")
    assert "settings.ticari_ileti_aktif" in metin, (
        "pazarlama gonderim yolu TICARI_ILETI_AKTIF bayragini okumuyor"
    )
    # Kapi RIZA KONTROLUNDEN ONCE olmali: rizasi olan kisi icin de
    # gonderim yapilmamali.
    assert metin.index("settings.ticari_ileti_aktif") < metin.index(
        "kisi.pazarlama_sms if sablon.kanal"
    ), "bayrak kapisi riza kontrolunden SONRA — rizali kisiye ileti giderdi"


# =========================================================================== #
# (§9.8) EKLENEN KISIYE GIDEN E-POSTA — icerigi kilitleniyor
# =========================================================================== #
def test_davet_metni_TESIS_ID_icerir_CALISMA_ALANI_BAGLANTISI_ICERMEZ():
    """Sartname §6: "Eklenen kisiye giden e-posta TESIS ID icerir;
    app.yonetiyor.com baglantisi ICERMEZ. Bu kisiler web panele
    girmez, sadece mobil uygulamayi kullanir."

    METIN URETICISINDEN OLCULUYOR, gonderilmis bir e-postadan degil:
    gonderim SMTP'ye baglidir ve dev'de yapilandirilmamistir. Olculmesi
    gereken sey ZATEN METNIN KENDISI — kanal degil.

    ILERIDE KIRILMA YONU DOGRU: biri metne "web'den giris" satiri
    eklerse bu test duser ve kararin bilincli olmasi gerektigi anlasilir.
    """
    from app.davet import davet_mesaji

    govde = davet_mesaji(
        "Oltu Sitesi",
        "https://yonetiyor.com/davet/ORNEKJETON",
        "OLTU-260821",
    )
    # TESIS ID VAR.
    assert "OLTU-260821" in govde, govde
    # CALISMA ALANI (panel/app) BAGLANTISI YOK.
    # NOT: 'app.'/'panel.' SEMA ONEKIYLE capali ('://app.'), bare DEGIL —
    # cunku Play Store paket id'si `com.app.yonetiyor` icinde 'app.' geciyor
    # ve bu bir calisma-alani LINKI degil (yanlis pozitif). Asil yasak, metne
    # `https://app.yonetiyor.com` gibi bir web workspace HOST'unun sizmasi.
    for yasak in ("://app.", "://panel."):
        assert yasak not in govde, f"davet metninde '{yasak}' gecmemeli: {govde}"


def test_yonetici_hosgeldin_metni_TESIS_ID_ve_GIRIS_BAGLANTISI_icerir():
    """Sartname §4: yoneticiye giden e-posta magaza baglantilarini VE
    web'den giris baglantisini icerir.

    Yonetici, sakinin AKSINE web paneline girer — iki metnin farki
    bilinclidir ve iki test bu farki karsilikli kilitler.
    """
    from app.config import settings
    from app.routers.kayit import _yonetici_hosgeldin_metni

    govde = _yonetici_hosgeldin_metni("Oltu Sitesi", "OLTU-260821")
    assert "OLTU-260821" in govde, govde
    assert settings.portal_base_url.rstrip("/") in govde, govde
    # Magaza baglantisi YAPILANDIRILMISSA metinde olmali; bos ise
    # HIC OLMAMALI (kirik baglanti gondermemek icin).
    if settings.play_store_url:
        assert settings.play_store_url in govde, govde
    if not settings.app_store_url:
        assert "App Store" not in govde and "iOS" not in govde, govde
