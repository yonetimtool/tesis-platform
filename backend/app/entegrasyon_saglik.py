"""(P240 §4) ENTEGRASYON SAGLIK KONTROLU.

===========================================================================
SAGLIK KONTROLU TETIKLEME DEGILDIR
===========================================================================
Bu modulun en onemli karari NE YAPMADIGIDIR: entegrasyona HTTP istegi
GONDERMEZ.

"Duzenli saglik kontrolu" isteginin en kolay yorumu "periyodik olarak
tetikle"dir ve kanallar dusunuldugunde bu bir kusur olurdu:

  * `megaphone` — siteye anons yapan hoparlor,
  * `smarthome` — kapi acan, vana kapatan cihaz.

15 dakikada bir tetiklemek, gunde 96 kez anons yapmak ya da kapi acmak
demekti. Bir "izleme" ozelliginin, izledigi sistemi CALISTIRMASI kabul
edilemez.

===========================================================================
PEKI NE OLCULUYOR
===========================================================================
SSRF kapisindan gecirilmis adrese TCP baglantisi acilir ve KAPATILIR:
   1. adres cozuluyor mu (DNS),
   2. hedef IP public mi (SSRF kapisi — ayni kapi, ayni kurallar),
   3. port kabul ediyor mu (TCP).

Bu, "BAGLANTI VAR MI" sorusunun yanitidir. "Cihaz isini dogru yapiyor
mu" sorusunun yaniti DEGILDIR ve arayuz de oyle sunmaz — ikisi FARKLI
IDDIALAR. Gercek kanit, gercek bir tetigin basarili olmasidir; o da
`son_basarili_at`i gunceller.

===========================================================================
TLS DOGRULAMASI YAPILMAZ (bilincli)
===========================================================================
Saha cihazlarinin (diyafon paneli, akilli ev kopru kutusu) cogu
SELF-SIGNED sertifika tasir. TLS el sikismasini basari kosulu yapmak,
calisan kurulumlari "hata" gostermek olurdu. Guvenlik acisindan da bir
sey kaybedilmiyor: burada VERI GONDERILMIYOR, yalnizca kapinin acik
olup olmadigina bakiliyor.
"""
from __future__ import annotations

import datetime as dt
import logging
import socket
from urllib.parse import urlparse

from .safe_http import SSRFBlocked, validate_public_url

logger = logging.getLogger(__name__)

#: TCP baglanti zaman asimi — saniye.
#:
#: 5 sn: saha cihazlari yavastir (mobil hat arkasinda olabilir), ama
#: 30 sn beklemek onlarca entegrasyonu olcen bir gorevi dakikalarca
#: surdururdu. Zaman asimi bir KOPUS degil "yanit yok"tur ve ayni
#: kimlikle raporlanir — cunku kullanici acisindan sonuc aynidir.
TCP_ZAMAN_ASIMI_SN: float = 5.0

#: Hata KIMLIKLERI — metin `hata_metinleri`nden, kullanicinin dilinde.
HATA_SSRF = "entegrasyon_adres_engelli"
HATA_DNS = "entegrasyon_adres_cozulemedi"
HATA_BAGLANTI = "entegrasyon_baglanti_yok"
HATA_BICIM = "entegrasyon_adres_gecersiz"


class SaglikSonucu:
    """Tek bir kontrolun sonucu."""

    __slots__ = ("bagli", "hata_kod", "ayrinti")

    def __init__(
        self, bagli: bool, hata_kod: str | None = None, ayrinti: str | None = None
    ) -> None:
        self.bagli = bagli
        self.hata_kod = hata_kod
        self.ayrinti = ayrinti


def baglanti_dene(url: str, *, zaman_asimi: float = TCP_ZAMAN_ASIMI_SN) -> SaglikSonucu:
    """Adrese TCP baglantisi acip kapatir. HICBIR HTTP ISTEGI GONDERMEZ."""
    ayristirilmis = urlparse(url)
    if ayristirilmis.scheme not in ("http", "https") or not ayristirilmis.hostname:
        return SaglikSonucu(False, HATA_BICIM, "sema/host yok")

    # DNS ONCE, SSRF SONRA — ve bu SIRA bilincli.
    #
    # `validate_public_url` cozulemeyen bir adi da `SSRFBlocked` ile
    # reddediyor (guvenlik acisindan dogru: cozulemeyen adres
    # dogrulanamaz). Ama KULLANICIYA "adres guvenlik kurallarina takildi"
    # demek, basit bir yazim hatasini guvenlik sorunu gibi gosterirdi ve
    # kullaniciyi yanlis yere bakmaya gonderirdi (olculdu: `.invalid`
    # bir adres SSRF kimligi donuyordu).
    #
    # Bu yuzden adi ONCE kendimiz cozuyoruz: cozulmuyorsa "adres
    # cozulemedi", cozuluyorsa SSRF kapisi karar veriyor. GUVENLIK
    # ZAYIFLAMAZ — kapi hala `validate_public_url`dir, yalnizca HATA
    # MESAJI dogru olani secer.
    try:
        socket.getaddrinfo(
            ayristirilmis.hostname,
            ayristirilmis.port or (443 if ayristirilmis.scheme == "https" else 80),
            proto=socket.IPPROTO_TCP,
        )
    except socket.gaierror as exc:
        return SaglikSonucu(False, HATA_DNS, f"{type(exc).__name__}: {exc}")

    try:
        ips = validate_public_url(url)
    except SSRFBlocked as exc:
        # SSRF ENGELI BIR AG HATASI DEGIL, YAPILANDIRMA HATASIDIR:
        # kullaniciya "baglanti yok" demek onu aga bakmaya gonderirdi.
        return SaglikSonucu(False, HATA_SSRF, str(exc))
    except Exception as exc:
        return SaglikSonucu(False, HATA_DNS, type(exc).__name__)

    port = ayristirilmis.port or (443 if ayristirilmis.scheme == "https" else 80)
    if not ips:
        return SaglikSonucu(False, HATA_DNS, "ip yok")

    son_hata: str | None = None
    for ip in ips:
        try:
            with socket.create_connection((ip, port), timeout=zaman_asimi):
                return SaglikSonucu(True)
        except OSError as exc:
            son_hata = f"{type(exc).__name__}: {exc}"
    return SaglikSonucu(False, HATA_BAGLANTI, son_hata)


def simdi() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)
