"""(P206 §3) IBAN — normalize, DOGRULA (mod 97), bicimle, BANKAYI COZ.

===========================================================================
NEDEN ULKE SINIRI KOYULMADI
===========================================================================
Onceki denetim `^TR[0-9]{24}$` bir REGEX'ti ve iki ucta birden yanlisti:

  * COK DAR: sistem yalniz Turkiye'de calismak zorunda degil. Yurt
    disindaki bir tesis kendi IBAN'ini giremezdi — ve hata mesaji
    "bicim gecersiz" derdi, yani kullanici NEDEN olmadigini anlamazdi.
  * COK GEVSEK: "TR" + 24 rakamin HERHANGI biri gecerli sayiliyordu.
    Tek hane yanlis yazilmis bir IBAN kabul ediliyor, para YANLIS
    HESABA gidiyordu — ve bu, ancak odeme kaybolunca fark edilirdi.

Cozum ikisini de karsilar:
  1. ULKE KODU + UZUNLUK: bilinen ulkeler icin TAM uzunluk denetlenir
     (TR=26). Bilinmeyen ulke icin yalniz genel sinir (15-34) uygulanir
     — listede olmayan bir ulkeyi reddetmek, dogru IBAN'i olan bir
     kullaniciyi kilitlemek olurdu.
  2. MOD 97 SAGLAMA TOPLAMI (ISO 13616): tek hane hatasini yakalar.
     Regex'in yapamadigi tam olarak buydu.

===========================================================================
DEPODA BOSLUKSUZ, EKRANDA BOSLUKLU
===========================================================================
Ayni IBAN'in "TR33 0006..." ve "TR330006..." diye iki kayit uretmesi,
IBAN'i esleme anahtari olarak kullanan her yeri (banka ekstresi
eslestirme, P191) bozardi. Depoda KANONIK bicim durur; okunabilirlik
CIZIM katmanininin isidir (`iban_bicimle`).
"""
from __future__ import annotations

import re

#: ISO 13616 uzunluklari — sik kullanilanlar. Liste TAM DEGIL ve olmak
#: zorunda da degil: bilinmeyen ulke genel sinira duser (asagi bak).
IBAN_UZUNLUK: dict[str, int] = {
    "AT": 20, "BE": 16, "BG": 22, "CH": 21, "CY": 28, "CZ": 24, "DE": 22,
    "DK": 18, "EE": 20, "ES": 24, "FI": 18, "FR": 27, "GB": 22, "GR": 27,
    "HR": 21, "HU": 28, "IE": 22, "IT": 27, "LT": 20, "LU": 20, "LV": 21,
    "MT": 31, "NL": 18, "NO": 15, "PL": 28, "PT": 25, "RO": 24, "RS": 22,
    "SE": 24, "SI": 19, "SK": 24, "TR": 26, "UA": 29, "AE": 23, "SA": 24,
    "QA": 29, "KW": 30, "BH": 22, "AZ": 28, "GE": 22, "MD": 24, "MK": 19,
    "ME": 22, "BA": 20, "AL": 28, "IS": 26, "LI": 21, "MC": 27, "SM": 27,
}

#: Genel ISO siniri. Bilinmeyen ulke kodu icin TEK denetim budur
#: (mod 97 ile birlikte).
ASGARI_UZUNLUK = 15
AZAMI_UZUNLUK = 34

_TEMIZ = re.compile(r"[\s\-]")
_BICIM = re.compile(r"^[A-Z]{2}[0-9]{2}[A-Z0-9]+$")


def iban_temizle(ham: str | None) -> str:
    """Bosluk/tire at, buyuk harfe cevir. KANONIK BICIM budur."""
    if not ham:
        return ""
    return _TEMIZ.sub("", ham).upper()


def iban_bicimle(iban: str | None) -> str:
    """Dorderli gruplarla okunabilir hâl: `TR33 0006 1005 ...`.

    Insan gozu 26 haneyi tek blokta karsilastiramaz; IBAN'i EKRANDA
    gruplamak, yanlis hesaba odeme yapmayi engelleyen en ucuz onlem.
    """
    t = iban_temizle(iban)
    return " ".join(t[i : i + 4] for i in range(0, len(t), 4))


def _mod97(iban: str) -> int:
    """ISO 13616: ilk dort hane sona alinir, harfler sayiya cevrilir."""
    tasinmis = iban[4:] + iban[:4]
    sayi = "".join(
        str(ord(c) - 55) if c.isalpha() else c for c in tasinmis
    )
    # BUYUK SAYI PARCA PARCA: 34 haneli IBAN Python'da sorun degil ama
    # ayni algoritma istemcide de yazili ve orada `Number` tasar —
    # AYNI yontemi kullanmak ikisinin ayrismasini onler.
    kalan = 0
    for basamak in sayi:
        kalan = (kalan * 10 + int(basamak)) % 97
    return kalan


def iban_hatasi(ham: str | None) -> str | None:
    """Gecersizse HATA KIMLIGI, gecerliyse `None`.

    Kimlik doner, metin DEGIL: metin `hata_metinleri`nden cevrilir
    (yeni uc/kimlik kurallari, README §15).
    """
    iban = iban_temizle(ham)
    if not iban:
        return "iban_bos"
    if not _BICIM.match(iban):
        return "iban_bicim"
    if not (ASGARI_UZUNLUK <= len(iban) <= AZAMI_UZUNLUK):
        return "iban_uzunluk"
    beklenen = IBAN_UZUNLUK.get(iban[:2])
    if beklenen is not None and len(iban) != beklenen:
        # ULKEYI BILIYORSAK TAM UZUNLUK: "TR" + 23 hane, genel sinira
        # uyar ama Turkiye IBAN'i DEGILDIR.
        return "iban_uzunluk"
    if _mod97(iban) != 1:
        return "iban_saglama"
    return None


def iban_gecerli_mi(ham: str | None) -> bool:
    return iban_hatasi(ham) is None


# ===================== (P206 §3.2) BANKA KODU -> AD ========================= #
#
# TR IBAN'inda 5-9. haneler BANKA KODUDUR (EFT kodu). IBAN girilince
# bankayi otomatik doldurmak, kullaniciyi bir yazim hatasindan kurtarir:
# ekstre eslestirme (P191) banka adina bakmaz ama INSAN bakar ve yanlis
# banka adi tasiyan bir kasa, mutabakatta saatler kaybettirir.
#
# LISTE KAPALI DEGIL: burada olmayan bir banka icin SERBEST GIRIS
# korunuyor (karar K3.2). Katilim bankalari, yeni lisans alanlar ve
# yabanci subeler bu listeyi her zaman geride birakir; kapali liste
# gercek bir hesabi kaydedilemez yapardi.
TR_BANKA_KODLARI: dict[str, str] = {
    "0001": "T.C. Merkez Bankası",
    "0010": "Ziraat Bankası",
    "0012": "Halkbank",
    "0015": "Vakıfbank",
    "0032": "Türk Ekonomi Bankası (TEB)",
    "0046": "Akbank",
    "0059": "Şekerbank",
    "0062": "Garanti BBVA",
    "0064": "Türkiye İş Bankası",
    "0066": "Türkiye İş Bankası",
    "0067": "Yapı Kredi",
    "0092": "Citibank",
    "0099": "ING Bank",
    "0103": "Fibabanka",
    "0108": "Turkland Bank",
    "0111": "QNB Finansbank",
    "0123": "HSBC",
    "0124": "Alternatifbank",
    "0125": "Burgan Bank",
    "0134": "Denizbank",
    "0135": "Anadolubank",
    "0138": "Deutsche Bank",
    "0143": "Aktif Yatırım Bankası",
    "0146": "Odeabank",
    "0203": "Albaraka Türk",
    "0205": "Kuveyt Türk",
    "0206": "Türkiye Finans",
    "0209": "Ziraat Katılım",
    "0210": "Vakıf Katılım",
    "0211": "Emlak Katılım",
    "0800": "PTT Bank",
}


def banka_kodu(ham: str | None) -> str | None:
    """TR IBAN'indaki BANKA KODU (EFT kodu).

    TR IBAN'i: `TR` + 2 kontrol + **5 hane banka kodu** + 1 rezerv + 16
    hane hesap. EFT kodlari DORT hanedir ve IBAN alanina SOLDAN SIFIRLA
    doldurulur ("0062" -> "00062"), o yuzden SON DORT hane alinir. Ilk
    dordu almak, Garanti'yi ("00062") "0006" diye okuyup listede
    bulamamak demekti (ilk yazimda oyleydi; ornek IBAN ile goruldu).

    TR disinda `None`: banka kodunun yeri ulkeye gore degisir ve
    UYDURMAK yanlis banka adi yazdirirdi.
    """
    iban = iban_temizle(ham)
    if len(iban) < 9 or not iban.startswith("TR"):
        return None
    return iban[4:9][-4:]


def banka_adi_coz(ham: str | None) -> str | None:
    kod = banka_kodu(ham)
    return TR_BANKA_KODLARI.get(kod) if kod else None
