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
#: (P168 §4) HIC DENENMEDI durumu — "gonderildi" de "basarisiz" da degil.
DURUM_YAPILANDIRILMADI = "yapilandirilmadi"


@dataclass(frozen=True)
class GonderimSonucu:
    durum: str
    saglayici: str
    hata: str | None = None


class MesajSaglayici(ABC):
    ad: str

    @abstractmethod
    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None, headers: dict[str, str] | None = None) -> GonderimSonucu: ...


class LogSmsSaglayici(MesajSaglayici):
    """SAGLAYICI YOK — gercekten gondermez, loglar ve BUNU SOYLER.

    ===========================================================================
    (P168 §4) BU SINIF "GONDERILDI" DIYORDU VE BU BIR KUSURDU
    ===========================================================================
    Onceki hâl hicbir sey gondermeden `"gonderildi"` donuyordu. Sonuc
    ekranda gorunuyordu: yonetici "Gonderim" listesinde yesil bir
    "Gonderildi" satiri goruyor, sakin ise hicbir sey almiyordu.

    Bir SMS'in gidip gitmedigi HUKUKI bir sorudur (bildirim kaniti);
    yanlis bir "gonderildi" kaydi, olmayan bir bildirimi ISPAT gibi
    gosterirdi.

    `basarisiz` da DOGRU DEGIL: o "denedik, olmadi" der ve kullaniciyi
    "tekrar dene"ye iter — oysa tekrar denemek ayni sonucu verir ve
    yapilmasi gereken sey AYARLARI DOLDURMAKTIR. Ayri bir durum,
    arayuzun DOGRU EYLEMI onerebilmesini saglar.

    Gonderim yolu yine SONUNA KADAR calisir (gecmis yazilir, alici
    cozulur): saglayici bir yapilandirma degisikligiyle takildiginda
    baska hicbir sey degismemeli.
    """

    ad = "log-sms"

    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None, headers: dict[str, str] | None = None) -> GonderimSonucu:
        # (P134) ALICI MASKELI, GOVDE YAZILMAZ. Bu satir INFO'dur ve
        # P134'e kadar hic gorunmuyordu; gorunur olurken telefon
        # numaralarini ve mesaj metnini konteyner gunluguune tasimasin
        # (konteyner gunlugunun KVKK saklama gorevi YOK). `LOG_PII=1`
        # yerel gelistirmede hamini acar.
        logger.info(
            "[SMS/log] %s <- %s", maskele_kimlik(hedef), govde_ozeti(govde)
        )
        return GonderimSonucu(
            DURUM_YAPILANDIRILMADI,
            self.ad,
            # HATA METNI KULLANICIYA GOSTERILIR ve NE YAPILACAGINI soyler.
            # "saglayici yok" demek teshis, "Ayarlar sekmesinden gir"
            # demek COZUMDUR.
            "sms_saglayici_yapilandirilmadi",
        )


class KapaliSmsSaglayici(MesajSaglayici):
    """(P177 §6) SMS KANALI KAPALI — KARAR, EKSIKLIK DEGIL.

    ===========================================================================
    `LogSmsSaglayici`DAN NEDEN AYRI
    ===========================================================================
    Ikisi de gondermez ama SOYLEDIKLERI SEY farkli ve arayuz farkli
    davranmali:

      * `LogSmsSaglayici` "saglayici YAPILANDIRILMADI" der -> yapilacak sey
        AYARLARI DOLDURMAKTIR ve panel kullaniciyi oraya yollar.
      * Bu sinif "SMS KAPALI" der -> yapilacak bir sey YOK. Yonetici
        ayarlar sayfasina gidip SMTP/SMS bilgilerini doldursa bile SMS
        gitmeyecektir; onu oraya yollamak bosuna bir yolculuk olurdu.

    Kapali olmasinin sebebi teknik degil: onayli bir GONDERICI BASLIGIMIZ
    yok. Onaysiz baslikla gonderilen SMS operatorde reddedilir ya da spam
    sayilir. Telefon bu urunde ILETISIM BILGISIDIR — dogrulama e-posta
    koduyla yapilir.

    `DURUM_YAPILANDIRILMADI` KULLANILIYOR, `basarisiz` DEGIL: "denedik,
    olmadi" demek yanlis olurdu — HIC DENENMEDI. Ve en onemlisi
    "gonderildi" DEMEZ: gonderilmemis bir bildirimi gonderilmis gostermek,
    P168'de olculen kusurun ta kendisiydi.
    """

    ad = "sms-kapali"

    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None, headers: dict[str, str] | None = None) -> GonderimSonucu:
        # ALICI MASKELI, GOVDE YAZILMAZ (P134 kurali).
        logger.info("[SMS/kapali] %s — gonderim YAPILMADI", maskele_kimlik(hedef))
        return GonderimSonucu(
            DURUM_YAPILANDIRILMADI, self.ad, "sms_kanali_kapali"
        )


class NetgsmSmsSaglayici(MesajSaglayici):
    """(P150) Gercek SMS gecidi — Netgsm HTTP API.

    NEDEN NETGSM: Turkiye'de bu urun tipinin yaygin saglayicisi ve basit
    bir HTTP GET arayuzu var. SECIM BAGLAYICI DEGIL: saglayici
    `MesajSaglayici` arayuzunun arkasinda ve `SMS_SAGLAYICI` ile secilir;
    baskasina gecmek bu dosyaya BIR SINIF eklemek demek.

    GOVDE VE NUMARA GUNLUGE YAZILMAZ (P134): hata halinde bile yalniz
    saglayicinin kod/mesaji kaydedilir.

    ZAMAN ASIMI ZORUNLU: SMS gonderimi bir kullanici isteginin ICINDE
    calisiyor; zaman asimsiz bir cagri, saglayici yavasladiginda giris
    ucunu de kilitlerdi.
    """

    ad = "netgsm"
    ZAMAN_ASIMI_SN = 8

    def __init__(
        self, kullanici: str, parola: str, baslik: str, url: str
    ) -> None:
        self._kullanici = kullanici
        self._parola = parola
        self._baslik = baslik
        self._url = url

    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None, headers: dict[str, str] | None = None) -> GonderimSonucu:
        import httpx

        try:
            yanit = httpx.get(
                self._url,
                params={
                    "usercode": self._kullanici,
                    "password": self._parola,
                    "gsmno": hedef.lstrip("+"),
                    "message": govde,
                    "msgheader": self._baslik,
                },
                timeout=self.ZAMAN_ASIMI_SN,
            )
        except Exception as exc:  # ag hatasi: kaydi KIRMAZ
            logger.warning("[SMS/netgsm] gonderilemedi: %s", type(exc).__name__)
            return GonderimSonucu("hata", self.ad, hata="baglanti")

        # Netgsm "00 <jobid>" ile basari, iki haneli kod ile hata doner.
        govde_yanit = (yanit.text or "").strip()
        kod = govde_yanit.split()[0] if govde_yanit else ""
        if yanit.status_code == 200 and kod in {"00", "01", "02"}:
            logger.info("[SMS/netgsm] %s <- gonderildi", maskele_kimlik(hedef))
            # "gonderildi" DENIR, "iletildi" DENMEZ — teslim bilgisi ayri
            # bir sorgudur ve uydurmak panelde YANLIS kanit gosterirdi.
            return GonderimSonucu("gonderildi", self.ad)
        logger.warning("[SMS/netgsm] saglayici reddetti: %s", kod or "bos")
        return GonderimSonucu("hata", self.ad, hata=kod or "bos_yanit")


class KonsolEpostaSaglayici(MesajSaglayici):
    """(P196) GELISTIRME/TEST TASIYICISI — teslimat KONSOLA yapilir.

    =======================================================================
    NEDEN VAR
    =======================================================================
    P196'da kod gonderimi "sessizce basarisiz olamaz" kuralina baglandi:
    saglayici mesaji kabul etmezse uc 502 doner. DOGRU davranis, ama bir
    yan etkisi vardi — dev ortaminda hic SMTP YOK, dolayisiyla e-posta
    kodu isteyen HER akis (hesap silme, profil e-postasi) artik 502
    doner ve o akislar dev'de HIC calistirilamaz hale gelir. Yedi test
    bu yuzden dustu; testleri zayiflatmak, kaybedilen seyin ta kendisini
    (uctan uca kapsam) atmak olurdu.

    Bu tasiyici mesaji GERCEKTEN teslim eder — hedefi konsoldur. Dev'de
    kod, konteyner gunlugunde okunabilir; akis uctan uca calisir.

    =======================================================================
    NASIL SECILIR (ve neden GLOBAL BIR ANAHTAR DEGIL)
    =======================================================================
    SMTP SUNUCU ADI `konsol` yazilarak — tesis ayarindan ya da ENV'den.
    Ilk yazim global bir ortam degiskeniydi ve TESIS/ENV AYARINDAN ONCE
    geliyordu; OLCULDU: "hicbir yapilandirma yok" durumunu ortadan
    kaldirdigi icin urunun cekirdek garantisini olcen 14 test dustu
    ("yapilandirma yokken 'gonderildi' DEME", P168 §4). Yapilandirma
    DEGERI olarak secilince o garanti dokunulmadan kalir.

    Yanlislikla secilirse gorunur olsun diye:
      * her gonderimde WARNING loglanir (INFO degil),
      * `mesaj_gonderim` govdesine tasiyici adi yazilir.
    Yani "gonderildi" yazan bir satirin gercekte nereye gittigi
    gecmisten okunabilir.
    """

    ad = "konsol-eposta"

    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None, headers: dict[str, str] | None = None) -> GonderimSonucu:
        # GOVDE TAM YAZILIR — bu tasiyicinin BUTUN AMACI kodu okunabilir
        # kilmak. Uretimde asla acilmamali; WARNING seviyesi bunu
        # operatorun gozune sokar.
        logger.warning(
            "[E-POSTA/konsol] TESLIMAT KONSOLA: %s <- %s\n%s",
            maskele_kimlik(hedef), konu, govde,
        )
        return GonderimSonucu("gonderildi", self.ad)


class LogEpostaSaglayici(MesajSaglayici):
    """VARSAYILAN e-posta saglayicisi — SMTP yapilandirilmamissa loglar."""

    ad = "log-eposta"

    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None, headers: dict[str, str] | None = None) -> GonderimSonucu:
        # (P134) Alici maskeli, govde yazilmaz — bkz. LogSmsSaglayici.
        # KONU yazilir: kisisel veri tasimaz ve "hangi bildirim" sorusunu
        # yanitlar.
        logger.info(
            "[E-POSTA/log] %s <- %s | %s",
            maskele_kimlik(hedef),
            konu,
            govde_ozeti(govde),
        )
        # (P168 §4) SMS ile AYNI GEREKCE: gonderilmeyen bir e-postayi
        # "gonderildi" diye kaydetmek, olmayan bir bildirimi kanit gibi
        # gostermekti.
        return GonderimSonucu(
            DURUM_YAPILANDIRILMADI, self.ad, "smtp_yapilandirilmadi"
        )


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

    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None, headers: dict[str, str] | None = None) -> GonderimSonucu:
        import smtplib
        from email.message import EmailMessage
        from email.utils import formatdate, make_msgid

        mesaj = EmailMessage()
        mesaj["From"] = self._gonderen
        mesaj["To"] = hedef
        mesaj["Subject"] = konu or ""
        # (P190) DATE + MESSAGE-ID: smtplib/EmailMessage bunlari OTOMATIK
        # EKLEMEZ ve eksikligi bir SPAM SINYALIDIR. Message-ID alan adi gonderen
        # adresinden turetilir (ornek: no-reply@yonetiyor.com -> yonetiyor.com).
        mesaj["Date"] = formatdate(localtime=True)
        alan = self._gonderen.rsplit("@", 1)[-1].strip(" <>") or "yonetiyor.com"
        mesaj["Message-ID"] = make_msgid(domain=alan)
        # (P190) Ek basliklar (orn. List-Unsubscribe / -Post). Zaten koydugumuz
        # sabit basliklarin (From/Date/Message-ID...) uzerine YAZILMAZ.
        for ad, deger in (headers or {}).items():
            if ad not in mesaj:
                mesaj[ad] = deger
        # (P186 §3.3) COK-PARCALI: `govde` her zaman text/plain koku;
        # `html` verilirse text/html ALTERNATIF eklenir. Istemci HTML'i
        # cizemezse (ya da metin tercih ederse) duz metne duser — davet
        # e-postasinin duz-metin paritesi bu yolla garanti edilir.
        mesaj.set_content(govde)
        if html:
            mesaj.add_alternative(html, subtype="html")
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
    # (P168 §4.2) Brief'te adi "Kiracı Bakiyesi Bildirimi".
    ("eposta", "Kiracı Bakiyesi Bildirimi", "{site_adi} — Kiracı Bakiye Bildirimi",
     "Sayın {adi_soyadi},\n\n{adres} bağımsız bölümünde oturan kiracının "
     "güncel bakiyesi {kiraci_bakiyesi} TL'dir.\n\n{borcu_detayli}\n\n"
     "Saygılarımızla,\n{site_adi} Yönetimi", "operasyonel"),

    # ---- (P168 §4) BRIEF'IN HAZIR SABLON LISTESINDEN EKSIK OLANLAR ----
    # Olculdu: SMS'te "Davetiye" ve "Yeni Duyuru", e-postada "Borç
    # Girişi", "Tahsilat Girişi" ve "Toplantı Çağrısı" YOKTU. Yeni bir
    # tesis acildiginda kullanici bunlari sifirdan yazmak zorunda
    # kaliyordu.
    ("sms", "Davetiye", None,
     "Sayın {adi_soyadi}, {site_adi} uygulamasına davet edildiniz. "
     "Kurulum: {odeme_linki}", "operasyonel"),
    ("sms", "Yeni Duyuru", None,
     "{site_adi}: yeni bir duyuru yayınlandı. Uygulamadan "
     "görüntüleyebilirsiniz.", "operasyonel"),
    ("eposta", "Borç Girişi", "{site_adi} — Borç Bildirimi",
     "Sayın {adi_soyadi},\n\n{tarih} tarihinde {adres} bağımsız bölümü "
     "için {borc} TL borç kaydedilmiştir.\n\n{bakiye_detayli}\n\n"
     "Saygılarımızla,\n{site_adi} Yönetimi", "operasyonel"),
    ("eposta", "Tahsilat Girişi", "{site_adi} — Ödemeniz Alındı",
     "Sayın {adi_soyadi},\n\nÖdemeniz alınmıştır. Güncel bakiyeniz "
     "{bakiye} TL'dir.\n\nTeşekkür ederiz,\n{site_adi} Yönetimi",
     "operasyonel"),
    ("eposta", "Toplantı Çağrısı", "{site_adi} — Genel Kurul Çağrısı",
     "Sayın {adi_soyadi},\n\n{site_adi} olağan genel kurul toplantısı "
     "{tarih} tarihinde yapılacaktır. Katılımınızı rica ederiz.\n\n"
     "Saygılarımızla,\n{site_adi} Yönetimi", "operasyonel"),
)


@dataclass(frozen=True)
class SaglayiciAyari:
    """(P168 §4) Tek bir tesisin saglayici ayarlari.

    Router bunu veritabanindan (`mesaj_yapilandirma`) okur ve buraya
    verir. Cekirdek veritabanini TANIMAZ — bu dosyanin tamami saf
    kalmali (modul basindaki not).
    """

    sms_saglayici: str | None = None
    sms_kullanici: str | None = None
    sms_parola: str | None = None
    sms_baslik: str | None = None
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_kullanici: str | None = None
    smtp_parola: str | None = None
    smtp_gonderen: str | None = None


def _ayardan_veya_env(ayar: SaglayiciAyari | None) -> SaglayiciAyari:
    """Tesis ayari VARSA o, yoksa ENV — **KANAL BASINA**.

    ENV YEDEK KALIR ve bu bilincli: saglayici bilgisi bugune kadar
    ENV'deydi ve calisan kurulumlar var. Tesis kaydini zorunlu kilsaydik,
    goc anindan itibaren HER TESISTE gonderim durur ve kimse sebebini
    anlamazdi.

    =======================================================================
    (P172 §1) KARAR KANAL BASINA VERILIR — KAYIT BASINA DEGIL
    =======================================================================
    Ilk yazim su seklideydi:

        if ayar is not None and (ayar.sms_saglayici or ayar.smtp_host):
            return ayar          # <-- KAYDIN TAMAMI

    Yani tesis YALNIZ SMS'ini girdiyse, ayni kayit e-posta icin de
    "tesisin ayari" sayiliyor ve `smtp_host` bos oldugu icin e-posta
    LOG'a dusuyordu — ENV'de calisan bir SMTP DURURKEN.

    Bu, bu turun kurulumunda gercek bir arizaydi: Resend ENV'de genel
    ayar olarak duruyor; kendi SMS bayiligini giren ilk tesis, e-posta
    gonderimini SESSIZCE kaybederdi. "Sessizce" cunku LOG saglayicisi
    `yapilandirilmadi` doner ve kimse ENV'de calisan bir SMTP oldugunu
    bilmez.

    Dogru kural: HER KANAL kendi ayarina bakar. Tesis SMS'ini girdiyse
    SMS tesisin, SMTP'sini girmediyse e-posta ENV'in.
    """
    from .config import settings
    # `getattr` BILINCLI: testler `settings`i alanlarin yalnizca bir
    # kismini tasiyan sahte bir nesneyle degistiriyor (SMS testinde SMTP
    # alanlari yok). Dogrudan erisim, ilgisiz bir testi AttributeError ile
    # dusururdu — `eposta_saglayicisi` de ayni gerekceyle `getattr`
    # kullaniyordu.
    def _al(ad: str, varsayilan=None):
        return getattr(settings, ad, varsayilan)

    # SMS KANALI: tesis kendi saglayicisini SECMISSE tesisin, yoksa ENV'in.
    sms_tesiste = ayar is not None and bool(ayar.sms_saglayici)
    # E-POSTA KANALI: ayni soru, AYRI yanit.
    smtp_tesiste = ayar is not None and bool(ayar.smtp_host)

    return SaglayiciAyari(
        sms_saglayici=(ayar.sms_saglayici if sms_tesiste else _al("sms_saglayici")),
        sms_kullanici=(ayar.sms_kullanici if sms_tesiste else _al("sms_kullanici")),
        sms_parola=(ayar.sms_parola if sms_tesiste else _al("sms_parola")),
        sms_baslik=(ayar.sms_baslik if sms_tesiste else _al("sms_baslik")),
        smtp_host=(ayar.smtp_host if smtp_tesiste else _al("smtp_host")),
        smtp_port=int(
            (ayar.smtp_port if smtp_tesiste else _al("smtp_port", 587)) or 587
        ),
        smtp_kullanici=(
            ayar.smtp_kullanici if smtp_tesiste else _al("smtp_user")
        ),
        smtp_parola=(ayar.smtp_parola if smtp_tesiste else _al("smtp_password")),
        smtp_gonderen=(
            ayar.smtp_gonderen if smtp_tesiste else _al("smtp_from")
        ),
    )


def sms_saglayicisi(ayar: SaglayiciAyari | None = None) -> MesajSaglayici:
    """(P150) YAPILANDIRMAYA gore SMS saglayicisi — TEK SECIM NOKTASI.

    (P168 §4) Artik TESIS AYARINI da kabul eder; verilmezse ENV'e duser.

    Eksik/yarim yapilandirmada LOG saglayicisina duser ve bunu UYARIR.
    Yarim yapilandirmayi "calisiyor" saymak, kodlarin sessizce hicbir yere
    gitmemesi demekti — kullanici giris yapamaz, sebebi de gorunmezdi.
    LOG saglayicisi artik `yapilandirilmadi` doner, "gonderildi" DEMEZ.
    """
    from .config import settings

    # (P177 §6) ANA SALTER — HER SEYDEN ONCE.
    #
    # Tesis kendi Netgsm bilgilerini arayuzden girmis olsa bile burasi
    # kapiyi kapatir. Kontrol `_ayardan_veya_env`DEN ONCE cunku o, tesis
    # ayarini env'in USTUNE koyar; sonra bakmak, tesis ayari olan bir
    # kurulumda salterin ETKISIZ kalmasi demekti.
    if not settings.sms_aktif:
        return KapaliSmsSaglayici()

    a = _ayardan_veya_env(ayar)
    ad = (a.sms_saglayici or "").strip().lower()
    if not ad:
        return LogSmsSaglayici()
    if ad == "netgsm":
        eksik = [
            k
            for k, v in (
                ("SMS_KULLANICI", a.sms_kullanici),
                ("SMS_PAROLA", a.sms_parola),
                ("SMS_BASLIK", a.sms_baslik),
            )
            if not v
        ]
        if eksik:
            logger.error(
                "[SMS] saglayici '%s' secildi ama %s eksik — LOG'a dusuldu",
                ad, ", ".join(eksik),
            )
            return LogSmsSaglayici()
        return NetgsmSmsSaglayici(
            a.sms_kullanici,  # type: ignore[arg-type]
            a.sms_parola,  # type: ignore[arg-type]
            a.sms_baslik,  # type: ignore[arg-type]
            settings.sms_url,
        )
    logger.error("[SMS] bilinmeyen saglayici '%s' — LOG'a dusuldu", ad)
    return LogSmsSaglayici()
