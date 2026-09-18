"""(P240 §2) DIYAFON SOYUTLAMASI — cagiran kod YONTEMI BILMEZ.

===========================================================================
TEK KAPI, UC YONTEM
===========================================================================
SMS (`mesajlasma.sms_saglayicisi`) ve odeme soyutlamalarindaki desen:
cagiran `saglayici(diyafon)` der, bir nesne alir ve `anons()` /
`kapi_ac()` cagirir. Musteri SIP'ten kuru kontaga gecerse cagiran kod
DEGISMEZ.

===========================================================================
YETENEK: VERI DEGIL DAVRANIS
===========================================================================
Kuru kontak SESLI MESAJ VEREMEZ — bir role kapatir, o kadar. Bunu
tabloya "anons_yapabilir" diye yazmak, yanlis isaretlendiginde
sunucunun olmayan bir yetenegi denemesi demekti. Yetenek YONTEMIN
kendisinden gelir ve burada SABITTIR; arayuz de bu listeyi okur
(istegin "hangi yontem ne yapabiliyor listelensin" maddesi).

===========================================================================
SIP'TE NE YAPILDI, NE YAPILMADI — ACIK SINIR
===========================================================================
YAPILDI: SIP sinyallesme duzeyinde iki islem, ikisi de duz metin
protokol ve taklit bir SIP sunucusuyla uctan uca olculuyor:
  * OPTIONS — saglik yoklamasi (cihazi CALISTIRMAZ),
  * MESSAGE — panelin ekranina METIN anonsu (RFC 3428).

YAPILMADI: SESLI anons (INVITE + RTP medya akisi). Bunun icin bir medya
yigini (pjsip/baresip) ve gercek ses kodlama gerekir; donanimsiz
dogrulanamaz ve "yazdim ama denemedim" bir guvenlik ozelliginde kabul
edilemez. Sesli anons isteyen kurulumlarda iki yol var ve ikisi de
docs'ta yazili: (1) cihazin HTTP kontrol API'si, (2) PBX tarafinda bir
playback dahili numarasi.

Bu ayrim `yetenekler()` cikisinda da gorunur: `sesli_anons` HICBIR
yontemde true DONMEZ.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

#: Yontem kimlikleri — veritabani enum'unun aynasi.
SIP = "sip"
SIP_KOPRU = "sip_kopru"
KURU_KONTAK = "kuru_kontak"

#: Yontem basina VARSAYILAN port.
VARSAYILAN_PORT: dict[str, int] = {SIP: 5060, SIP_KOPRU: 5060, KURU_KONTAK: 80}


@dataclass(frozen=True)
class Yetenekler:
    """Bir yontemin NE YAPABILDIGI.

    `metin_anons` — panelin ekranina yazi dusurur (SIP MESSAGE).
    `sesli_anons` — hoparlorden SES calar. HICBIR yontemde true DEGIL
                    (bkz. modul basligi); arayuz bunu acikca yazar.
    `kapi_ac`     — kapi rolesini tetikler.
    `zil_cal`     — zili calar.
    """

    metin_anons: bool
    sesli_anons: bool
    kapi_ac: bool
    zil_cal: bool


YETENEK: dict[str, Yetenekler] = {
    # SIP cihazi: MESSAGE ile ekrana yazi; kapi/zil cihazin HTTP kontrol
    # API'sini gerektirir ve o bu turda YAPILANDIRILMIYOR.
    SIP: Yetenekler(metin_anons=True, sesli_anons=False, kapi_ac=False, zil_cal=False),
    # PBX kopru: ayni sinyallesme, hedef PBX dahilisi.
    SIP_KOPRU: Yetenekler(
        metin_anons=True, sesli_anons=False, kapi_ac=False, zil_cal=False
    ),
    # Kuru kontak: role kapatir. SES YOK — bu yontemin YAPISAL siniri.
    KURU_KONTAK: Yetenekler(
        metin_anons=False, sesli_anons=False, kapi_ac=True, zil_cal=True
    ),
}


@dataclass(frozen=True)
class DiyafonSonuc:
    """Bir islemin sonucu. `kod` bir KIMLIKTIR, cumle degil."""

    ok: bool
    kod: str | None = None
    ayrinti: str | None = None


class DiyafonSaglayici(Protocol):
    """Uc yontemin ortak arayuzu."""

    yontem: str

    def saglik(self) -> DiyafonSonuc: ...

    def metin_anons(self, mesaj: str) -> DiyafonSonuc: ...

    def kapi_ac(self) -> DiyafonSonuc: ...

    def zil_cal(self) -> DiyafonSonuc: ...


#: Hata kimlikleri — metin `hata_metinleri`nden, kullanicinin dilinde.
HATA_DESTEKLENMIYOR = "diyafon_yontem_desteklemiyor"
HATA_YAPILANDIRMA = "diyafon_yapilandirma_eksik"
HATA_ULASILAMIYOR = "diyafon_ulasilamiyor"
HATA_REDDEDILDI = "diyafon_reddedildi"


def yetenekler(yontem: str) -> Yetenekler:
    return YETENEK.get(
        yontem,
        Yetenekler(
            metin_anons=False, sesli_anons=False, kapi_ac=False, zil_cal=False
        ),
    )
