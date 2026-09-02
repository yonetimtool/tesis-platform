"""(P205 §1) TEK GIRIS ALANI — e-posta mi telefon mu?

===========================================================================
NEDEN SISTEM KARAR VERIYOR
===========================================================================
Giris ekraninda TEK alan var: "E-posta veya telefon numarasi". Kullaniciya
"hangisini yaziyorsun" diye sormak, bilgisayarin kolayca yapabilecegi bir
ayrimi INSANA yaptirmakti — ve her sorulan soru bir yanlis cevap firsati.

===========================================================================
AYRIM NASIL YAPILIYOR
===========================================================================
`@` VARSA E-POSTADIR. Bu bir tahmin degil: hicbir telefon numarasi `@`
icermez ve hicbir e-posta adresi `@`siz olamaz (RFC 5321). Rakam sayisina
ya da uzunluga bakan bir sezgi, `1234@ornek.com` gibi adreslerde yanilirdi.

Telefon E.164'e NORMALIZE EDILIR (`security.normalize_phone`): "0532 111
22 03", "+90 532 111 22 03" ve "905321112203" AYNI kisidir ve veritabani
tek bicimde saklar. Normalize etmeden aramak, kullanicinin bosluk koyup
koymamasina gore giris yaptirmak demekti.

===========================================================================
GECERSIZ GIRDI SIZDIRMAZ
===========================================================================
Ayristirma BASARISIZ olursa (ne e-posta ne gecerli telefon) cagiri
`None` alir ve *ayni jenerik hatayi* dondurur. "Bu bir e-posta degil"
demek, saldirgana girdisinin hangi dala girdigini soylerdi.
"""
from __future__ import annotations

from dataclasses import dataclass

from .security import normalize_phone


@dataclass(frozen=True)
class Kimlik:
    """Cozulmus giris kimligi."""

    #: `"eposta"` | `"telefon"`
    tur: str
    #: Aramada kullanilacak NORMALIZE deger.
    deger: str

    @property
    def eposta_mi(self) -> bool:
        return self.tur == "eposta"


def kimligi_coz(ham: str | None) -> Kimlik | None:
    """`"0532..."` -> telefon · `"a@b.com"` -> eposta · bozuk -> `None`."""
    if not ham:
        return None
    s = ham.strip()
    if not s:
        return None
    if "@" in s:
        # E-POSTA: bicim dogrulamasi BURADA YAPILMAZ. Uc zaten
        # bulamazsa jenerik hata donecek; ayrica dogrulamak, gecersiz
        # bicimi FARKLI bir hataya ayirmak (yani sizdirmak) olurdu.
        return Kimlik(tur="eposta", deger=s.lower())
    try:
        return Kimlik(tur="telefon", deger=normalize_phone(_ulke_kodunu_duzelt(s)))
    except ValueError:
        return None


def _ulke_kodunu_duzelt(s: str) -> str:
    """`"905321112203"` -> `"+905321112203"`.

    =======================================================================
    OLCULEN KUSUR — ve NEDEN `normalize_phone`U DEGISTIRMIYORUM
    =======================================================================
    `normalize_phone("905321112203")` -> `+90905321112203` (olculdu):
    `+` YOKSA ve rakamla basliyorsa basina `+90` ekliyor, girdinin ZATEN
    ulke kodu tasidigini gormuyor. Ve `905...` numarayi yazmanin cok
    yaygin bir bicimidir — yeni TEK ALANDA bu, girisin sessizce
    basarisiz olmasi demekti.

    `normalize_phone` DEGISTIRILMEDI ve bu bilincli: o fonksiyon
    KULLANICI YARATMA aninda da calisiyor ve saklama bicimini
    belirliyor. Davranisini degistirmek, eskiden o yolla yazilmis
    satirlari erisilemez kilabilirdi — bu tur onlari olcmedi.

    Telafi BURADA, yalniz GIRIS yolunda: girdi tamamen rakamsa, `90`
    ile basliyorsa ve TR cep numarasi uzunlugundaysa (12 hane = ulke
    kodu + 10) basina `+` konur. Dar bir kural; baska hicbir bicimi
    etkilemez.
    """
    ham = s.replace(" ", "")
    if ham.isdigit() and ham.startswith("90") and len(ham) == 12:
        return "+" + ham
    return s
