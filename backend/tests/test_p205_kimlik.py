"""(P205 §1) TEK GIRIS ALANI — kimlik ayrimi."""
from __future__ import annotations

import pytest

from app.kimlik import kimligi_coz


@pytest.mark.parametrize("ham", [
    "kerem@ornek.com", "KEREM@ORNEK.COM", " kerem@ornek.com ",
    # Rakamla BASLAYAN e-posta: uzunluk/rakam sezgisi burada YANILIRDI.
    "1234@ornek.com", "0532@ornek.com",
])
def test_AT_ISARETI_VARSA_EPOSTA(ham):
    k = kimligi_coz(ham)
    assert k is not None and k.eposta_mi
    assert k.deger == ham.strip().lower()


@pytest.mark.parametrize("ham,beklenen", [
    ("05321112203", "+905321112203"),
    ("0532 111 22 03", "+905321112203"),
    ("+90 532 111 22 03", "+905321112203"),
    # OLCULEN KUSUR: `normalize_phone("905...")` -> `+90905...`
    # (ulke kodunu IKINCI kez ekliyor). `905...` numarayi yazmanin cok
    # yaygin bir bicimi; giris yolunda telafi edildi.
    ("905321112203", "+905321112203"),
    ("(0532) 111-22-03", "+905321112203"),
])
def test_TELEFON_NORMALIZE_edilir(ham, beklenen):
    """Ayni kisi, bes farkli yazim. Normalize etmeden aramak,
    kullanicinin bosluk koyup koymamasina gore giris yaptirmakti."""
    k = kimligi_coz(ham)
    assert k is not None and not k.eposta_mi
    assert k.deger == beklenen


@pytest.mark.parametrize("ham", ["", "   ", None, "abc", "123", "+", "@"])
def test_COZULEMEYEN_girdi_None(ham):
    """`None` -> cagiri JENERIK hata doner. "Bu bir e-posta degil"
    demek, saldirgana girdisinin hangi dala girdigini soylerdi."""
    if ham == "@":
        # "@" iceriyor -> e-posta dali; bicim dogrulamasi BURADA
        # yapilmaz (bkz. modul basligi) ve uc bulamayinca jenerik
        # hata doner.
        assert kimligi_coz(ham) is not None
        return
    assert kimligi_coz(ham) is None


def test_ULKE_KODU_IKI_KEZ_EKLENMEZ():
    """Kusurun kendisi kayit altinda.

    `normalize_phone` DEGISTIRILMEDI (kullanici yaratmada da calisiyor
    ve saklama bicimini belirliyor); telafi yalniz GIRIS yolunda.
    """
    from app.security import normalize_phone

    assert normalize_phone("905321112203") == "+90905321112203", (
        "normalize_phone duzeltilmisse bu notu ve telafiyi guncelle"
    )
    assert kimligi_coz("905321112203").deger == "+905321112203"


def test_TELAFI_DAR_baska_bicimleri_ETKILEMEZ():
    """11 haneli ya da 90 ile baslamayan girdi telafiden GECMEZ."""
    assert kimligi_coz("05321112203").deger == "+905321112203"
    assert kimligi_coz("+905321112203").deger == "+905321112203"
    # 90 ile baslayan ama 12 hane OLMAYAN: telafi uygulanmaz.
    assert kimligi_coz("9053211122").deger == "+909053211122"
