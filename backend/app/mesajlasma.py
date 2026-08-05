"""Mesaj CEKIRDEGI (P32) — etiket interpolasyonu + SMS sayaci + saglayicilar.

Saf fonksiyonlar + saglayici arayuzu; veritabani YOK. Router veriyi toplar,
burasi metni kurar ve gonderir.
"""
from __future__ import annotations

import logging
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass

from .gunlukleme import govde_ozeti, maskele_kimlik

logger = logging.getLogger(__name__)

#: Desteklenen etiketler. Bilinmeyen bir etiket METINDE OLDUGU GIBI KALIR
#: (bos birakmak degil): "{bakiyee}" yazan kullanici mesajda bos bir bosluk
#: gorup sorunu fark etmezdi; etiketi gormek yazim hatasini ANINDA gosterir.
ETIKETLER = (
    "adi_soyadi", "adres", "site_adi", "tarih",
    "bakiye", "borc", "aidat_tutari", "kiraci_bakiyesi",
    "bakiye_detayli", "borcu_detayli", "odeme_linki",
)

_DESEN = re.compile(r"\{([a-z_]+)\}")


def etiketleri_coz(sablon: str, degerler: dict[str, str]) -> str:
    """Etiketleri degerleriyle degistir.

    BILINMEYEN ETIKET KORUNUR (bkz. ETIKETLER notu). Deger `None` ise BOS
    yazilir — "None" metninin mesaja girmesi kullaniciya saygisizlik olurdu.
    """
    def _degistir(m: re.Match) -> str:
        ad = m.group(1)
        if ad not in degerler:
            return m.group(0)
        deger = degerler[ad]
        return "" if deger is None else str(deger)

    return _DESEN.sub(_degistir, sablon)


def kullanilan_etiketler(sablon: str) -> list[str]:
    """Sablondaki etiketler (sirali, tekrarsiz) — onizleme ve dogrulama icin."""
    gorulen: list[str] = []
    for m in _DESEN.finditer(sablon):
        if m.group(1) not in gorulen:
            gorulen.append(m.group(1))
    return gorulen


def bilinmeyen_etiketler(sablon: str) -> list[str]:
    return [e for e in kullanilan_etiketler(sablon) if e not in ETIKETLER]


# ------------------------------ SMS sayaci ---------------------------------- #
#: GSM-7 temel kumesi. TURKCE HARFLER BURADA YOK (ı, ğ, ş, İ, Ğ, Ş) —
#: `ç/ö/ü` ve `Ä/Ö/Ü` GSM-7'de VARDIR ama `ı/ğ/ş` YOKTUR. Bu ayrim SMS
#: maliyetini IKIYE KATLAR ve kullaniciya SAYAC olarak gosterilmelidir.
_GSM7 = set(
    "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?"
    "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà"
)
#: GSM-7'de IKI karakter yer kaplayan genisletilmis isaretler.
_GSM7_CIFT = set("^{}\\[~]|€")

TEK_GSM7 = 160
COK_GSM7 = 153  # coklu SMS'te basliga 7 karakter gider
TEK_UCS2 = 70
COK_UCS2 = 67


@dataclass(frozen=True)
class SmsOlcum:
    """SMS uzunluk olcumu — kullaniciya GOSTERILIR."""

    karakter: int
    #: True ise mesaj UCS-2 kodlanir ve sinir 160 degil 70'tir.
    unicode_mi: bool
    parca: int
    #: Bu parcada kalan karakter.
    kalan: int
    #: UCS-2'ye ZORLAYAN karakterler (kullanici gorup degistirebilsin).
    zorlayan: list[str]


def sms_olc(metin: str) -> SmsOlcum:
    """SMS parca sayisini ve kodlamayi olc.

    TURKCE TUZAGI: tek bir `ş` mesaji UCS-2'ye dusurur ve 160 karakterlik
    sinir 70'e iner — yani "biraz uzun" bir mesaj birden UC SMS olur.
    Sayac bunu ve ZORLAYAN karakterleri gosterir ki kullanici bilincli
    secsin.
    """
    zorlayan: list[str] = []
    uzunluk = 0
    for ch in metin:
        if ch in _GSM7:
            uzunluk += 1
        elif ch in _GSM7_CIFT:
            uzunluk += 2
        else:
            if ch not in zorlayan:
                zorlayan.append(ch)
            uzunluk += 1

    unicode_mi = bool(zorlayan)
    if unicode_mi:
        uzunluk = len(metin)  # UCS-2'de her karakter 1 birim
        tek, cok = TEK_UCS2, COK_UCS2
    else:
        tek, cok = TEK_GSM7, COK_GSM7

    if uzunluk <= tek:
        parca = 1 if uzunluk else 0
        kalan = tek - uzunluk
    else:
        parca = -(-uzunluk // cok)  # yukari yuvarla
        kalan = parca * cok - uzunluk
    return SmsOlcum(uzunluk, unicode_mi, parca, kalan, zorlayan)


# ----------------------------- saglayicilar --------------------------------- #
@dataclass(frozen=True)
class GonderimSonucu:
    durum: str
    saglayici: str
    hata: str | None = None


class MesajSaglayici(ABC):
    ad: str

    @abstractmethod
    def gonder(self, hedef: str, konu: str | None, govde: str) -> GonderimSonucu: ...


class LogSmsSaglayici(MesajSaglayici):
    """VARSAYILAN SMS saglayicisi — GERCEKTEN GONDERMEZ, loglar.

    Gercek bir SMS hesabi [DIŞ] bir istir. Mimari, saglayiciyi bir
    YAPILANDIRMA DEGISIKLIGIYLE degistirebilmeli: bu yuzden gonderim yolu
    bugun de sonuna kadar calisir (gecmis yazilir, durum isaretlenir) ve
    yalnizca bu sinif degisir.
    """

    ad = "log-sms"

    def gonder(self, hedef: str, konu: str | None, govde: str) -> GonderimSonucu:
        # (P134) ALICI MASKELI, GOVDE YAZILMAZ. Bu satir INFO'dur ve
        # P134'e kadar hic gorunmuyordu; gorunur olurken telefon
        # numaralarini ve mesaj metnini konteyner gunluguune tasimasin
        # (konteyner gunlugunun KVKK saklama gorevi YOK). `LOG_PII=1`
        # yerel gelistirmede hamini acar.
        logger.info(
            "[SMS/log] %s <- %s", maskele_kimlik(hedef), govde_ozeti(govde)
        )
        # "gonderildi" DENIR ama "iletildi" DENMEZ: iletim bilgisini yalnizca
        # gercek saglayici verebilir ve uydurmak, panelde YANLIS bir teslim
        # kaniti gosterirdi.
        return GonderimSonucu("gonderildi", self.ad)


class LogEpostaSaglayici(MesajSaglayici):
    """VARSAYILAN e-posta saglayicisi — SMTP yapilandirilmamissa loglar."""

    ad = "log-eposta"

    def gonder(self, hedef: str, konu: str | None, govde: str) -> GonderimSonucu:
        # (P134) Alici maskeli, govde yazilmaz — bkz. LogSmsSaglayici.
        # KONU yazilir: kisisel veri tasimaz ve "hangi bildirim" sorusunu
        # yanitlar.
        logger.info(
            "[E-POSTA/log] %s <- %s | %s",
            maskele_kimlik(hedef),
            konu,
            govde_ozeti(govde),
        )
        return GonderimSonucu("gonderildi", self.ad)


class SmtpEpostaSaglayici(MesajSaglayici):
    """SMTP ile gercek gonderim (yapilandirilmissa).

    Baglanti hatasi GONDERIMI DUSURUR ama ISTEGI DUSURMEZ: toplu gonderimde
    tek adresin SMTP hatasi, kalan 200 kisiye mesaj gitmesini engellememeli.
    """

    ad = "smtp"

    def __init__(self, sunucu: str, port: int, kullanici: str | None,
                 parola: str | None, gonderen: str) -> None:
        self._sunucu, self._port = sunucu, port
        self._kullanici, self._parola = kullanici, parola
        self._gonderen = gonderen

    def gonder(self, hedef: str, konu: str | None, govde: str) -> GonderimSonucu:
        import smtplib
        from email.message import EmailMessage

        mesaj = EmailMessage()
        mesaj["From"] = self._gonderen
        mesaj["To"] = hedef
        mesaj["Subject"] = konu or ""
        mesaj.set_content(govde)
        try:
            with smtplib.SMTP(self._sunucu, self._port, timeout=10) as s:
                s.starttls()
                if self._kullanici:
                    s.login(self._kullanici, self._parola or "")
                s.send_message(mesaj)
            return GonderimSonucu("gonderildi", self.ad)
        except Exception as exc:  # noqa: BLE001 — hata METNI gecmise yazilir
            return GonderimSonucu("basarisiz", self.ad, str(exc)[:300])


#: Varsayilan sablon seti (seed) — (kanal, ad, konu, govde, amac).
#: HEPSI OPERASYONEL: finansal bildirim ve toplanti cagrisi KMK
#: yukumluluguyle gonderilir; pazarlama sablonu VARSAYILAN OLARAK YOKTUR
#: (riza gerektirir, bkz. P36).
VARSAYILAN_SABLONLAR: tuple[tuple[str, str, str | None, str, str], ...] = (
    ("sms", "Bakiye Bildirimi", None,
     "Sayın {adi_soyadi}, {site_adi} {adres} bağımsız bölüm bakiyeniz "
     "{bakiye} TL'dir. Ödeme: {odeme_linki}", "operasyonel"),
    ("sms", "Borç Girişi", None,
     "Sayın {adi_soyadi}, {tarih} tarihinde {borc} TL borç kaydedilmiştir. "
     "Toplam bakiye: {bakiye} TL.", "operasyonel"),
    ("sms", "Tahsilat Girişi", None,
     "Sayın {adi_soyadi}, ödemeniz alınmıştır. Güncel bakiyeniz: "
     "{bakiye} TL. Teşekkür ederiz.", "operasyonel"),
    ("sms", "Toplantı Çağrısı", None,
     "{site_adi} olağan genel kurul toplantısı {tarih} tarihinde "
     "yapılacaktır. Katılımınızı rica ederiz.", "operasyonel"),
    ("eposta", "Bakiye Bildirimi", "{site_adi} — Bakiye Bildirimi",
     "Sayın {adi_soyadi},\n\n{adres} bağımsız bölümünüze ait güncel "
     "bakiyeniz {bakiye} TL'dir.\n\n{bakiye_detayli}\n\n"
     "Ödeme için: {odeme_linki}\n\nSaygılarımızla,\n{site_adi} Yönetimi",
     "operasyonel"),
    ("eposta", "Davetiye", "{site_adi} — Davet",
     "Sayın {adi_soyadi},\n\n{tarih} tarihli toplantımıza davetlisiniz.\n\n"
     "Saygılarımızla,\n{site_adi} Yönetimi", "operasyonel"),
    ("eposta", "Yeni Duyuru", "{site_adi} — Yeni Duyuru",
     "Sayın {adi_soyadi},\n\n{site_adi} için yeni bir duyuru "
     "yayınlanmıştır. Uygulamadan görüntüleyebilirsiniz.\n\n"
     "Saygılarımızla,\n{site_adi} Yönetimi", "operasyonel"),
    ("eposta", "Kiracı Bakiyesi", "{site_adi} — Kiracı Bakiye Bildirimi",
     "Sayın {adi_soyadi},\n\n{adres} bağımsız bölümünde oturan kiracının "
     "güncel bakiyesi {kiraci_bakiyesi} TL'dir.\n\n{borcu_detayli}\n\n"
     "Saygılarımızla,\n{site_adi} Yönetimi", "operasyonel"),
)
