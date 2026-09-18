"""(P240 §2) SIP SAGLAYICISI — OPTIONS (saglik) + MESSAGE (metin anons).

===========================================================================
NEDEN KUTUPHANE YOK: SIP DUZ METIN BIR PROTOKOL
===========================================================================
Kullandigimiz iki istek (OPTIONS, MESSAGE) HTTP'ye benzeyen duz metin
mesajlardir ve UDP uzerinden tek pakette gider. pjsip/baresip gibi bir
medya yigini SES icin gerekir — biz ses GONDERMIYORUZ (bkz. taban.py).
Bir medya yiginini konteynere koymak, kullanmadigimiz bir bagimliligi
ve onunla gelen derleme/guvenlik yukunu tasimak olurdu.

===========================================================================
UDP: TEK PAKET, TEK YANIT
===========================================================================
SIP varsayilan tasima UDP/5060'tir. TCP de destekleniyor ama cihazlarin
neredeyse tamami UDP dinler. Yanit gelmezse ZAMAN ASIMI = "ulasilamiyor"
(RFC 3261 T1/T2 geri cekilmesi UYGULANMADI: tek deneme, kisa zaman
asimi — bu bir SIP ISTEMCISI DEGIL, bir YOKLAMA).

===========================================================================
SSRF: IC AG ADRESLERI BURADA SERBEST — ve bu bilincli
===========================================================================
`safe_http` kapisi WEBHOOK icindir: kullanicinin yazdigi bir URL'e
sunucunun istek atmasi, ic aga sizmanin klasik yoludur. DIYAFON ISE
TANIMI GEREGI IC AGDADIR (192.168.x.x'teki kapi paneli). Ayni kapiyi
buraya koymak, ozelligin kendisini imkansiz kilardi.

Bunun yerine SINIR DAR TUTULDU: yalniz SIP mesaji gonderiliyor (HTTP
DEGIL), yanit govdesi OKUNMUYOR ve KULLANICIYA DONMEZ — yani bu yol bir
ic-ag tarayicisina cevrilemez. Panel yapilandirmasi ZATEN admin/yonetici
yetkisi ister.
"""
from __future__ import annotations

import socket
import uuid
from urllib.parse import quote

from .taban import (
    HATA_REDDEDILDI,
    HATA_ULASILAMIYOR,
    HATA_YAPILANDIRMA,
    SIP,
    VARSAYILAN_PORT,
    DiyafonSonuc,
)

#: Yanit bekleme suresi — saniye.
#:
#: 3 sn: ayni yerel agdaki bir panel milisaniyelerde yanitlar. Uzun
#: beklemek, onlarca diyafonu yoklayan saglik gorevini dakikalarca
#: surdururdu.
ZAMAN_ASIMI_SN = 3.0

#: Yanit tamponu — SIP yanitlari birkac yuz bayttir.
#:
#: 4 KiB: buyuk bir yanit (cok basligi olan OPTIONS 200) bile sigar;
#: sinirsiz okumak, kotu niyetli bir cihazin bellegi doldurmasina izin
#: vermek olurdu.
TAMPON = 4096


def _yerel_ip(host: str, port: int) -> str:
    """Hedefe giden arayuzun IP'si — `Via`/`Contact` basliklari icin.

    UDP soketi BAGLANMAZ (veri gitmez); cekirdegin yonlendirme tablosuna
    "bu hedefe hangi arayuzden cikarim" diye sorar. Sabit bir IP yazmak
    (orn. 127.0.0.1) cihazin yaniti nereye gonderecegini bilememesi
    demekti.
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect((host, port))
        return s.getsockname()[0]
    except OSError:
        return "0.0.0.0"
    finally:
        s.close()


def _istek(
    metot: str,
    *,
    host: str,
    port: int,
    hedef: str,
    yerel_ip: str,
    govde: str = "",
    icerik_turu: str | None = None,
) -> bytes:
    """RFC 3261 bicimli bir SIP istegi kurar."""
    dal = f"z9hG4bK{uuid.uuid4().hex[:16]}"
    etiket = uuid.uuid4().hex[:8]
    cagri_id = f"{uuid.uuid4().hex}@{yerel_ip}"
    hedef_uri = hedef if hedef.startswith("sip:") else f"sip:{hedef}@{host}"
    satirlar = [
        f"{metot} {hedef_uri} SIP/2.0",
        f"Via: SIP/2.0/UDP {yerel_ip}:5060;branch={dal};rport",
        "Max-Forwards: 70",
        f"To: <{hedef_uri}>",
        f"From: <sip:yonetiyor@{yerel_ip}>;tag={etiket}",
        f"Call-ID: {cagri_id}",
        f"CSeq: 1 {metot}",
        f"Contact: <sip:yonetiyor@{yerel_ip}:5060>",
        "User-Agent: Yonetiyor/1.0",
    ]
    if icerik_turu:
        satirlar.append(f"Content-Type: {icerik_turu}")
    govde_bayt = govde.encode("utf-8")
    satirlar.append(f"Content-Length: {len(govde_bayt)}")
    bas = ("\r\n".join(satirlar) + "\r\n\r\n").encode("utf-8")
    return bas + govde_bayt


def _gonder(host: str, port: int, paket: bytes) -> tuple[int | None, str]:
    """Tek UDP paketi yollar, tek yanit okur. Donus: (durum kodu, ozet)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(ZAMAN_ASIMI_SN)
    try:
        s.sendto(paket, (host, port))
        veri, _ = s.recvfrom(TAMPON)
    except (socket.timeout, OSError) as exc:
        return None, f"{type(exc).__name__}: {exc}"
    finally:
        s.close()
    ilk = veri.split(b"\r\n", 1)[0].decode("utf-8", "replace")
    parcalar = ilk.split(" ")
    if len(parcalar) >= 2 and parcalar[0].startswith("SIP/2.0"):
        try:
            return int(parcalar[1]), ilk
        except ValueError:
            return None, ilk
    return None, ilk


class SipDiyafon:
    """SIP cihazi ya da PBX koprusu. Ikisi de AYNI sinyallesmeyi kullanir."""

    def __init__(
        self,
        *,
        host: str,
        port: int | None,
        hedef: str | None,
        yontem: str = SIP,
    ) -> None:
        self.host = host
        self.port = port or VARSAYILAN_PORT.get(yontem, 5060)
        self.hedef = hedef or ""
        self.yontem = yontem

    def saglik(self) -> DiyafonSonuc:
        """OPTIONS — cihazi CALISTIRMAZ, yalniz "orada misin" sorar.

        SIP'te OPTIONS tam olarak bunun icindir (RFC 3261 §11): zil
        caldirmaz, arama baslatmaz. Saglik yoklamasinin cihazi
        calistirmamasi kurali (P240 §4) burada da gecerli.
        """
        if not self.host:
            return DiyafonSonuc(False, HATA_YAPILANDIRMA, "host yok")
        yerel = _yerel_ip(self.host, self.port)
        kod, ozet = _gonder(
            self.host,
            self.port,
            _istek(
                "OPTIONS",
                host=self.host,
                port=self.port,
                hedef=self.hedef or self.host,
                yerel_ip=yerel,
            ),
        )
        if kod is None:
            return DiyafonSonuc(False, HATA_ULASILAMIYOR, ozet)
        # 200 en yaygin; 4xx de CIHAZIN YANIT VERDIGINI kanitlar.
        # Sunucunun "405 Method Not Allowed" demesi bile "ayakta" demektir
        # — bunu "kopuk" saymak, calisan bir kurulumu kirmizi gostermek
        # olurdu.
        if 200 <= kod < 700:
            return DiyafonSonuc(True, ayrinti=ozet)
        return DiyafonSonuc(False, HATA_REDDEDILDI, ozet)

    def metin_anons(self, mesaj: str) -> DiyafonSonuc:
        """MESSAGE (RFC 3428) — panelin EKRANINA metin dusurur.

        SES GONDERMEZ. Sesli anons medya yigini ister ve bu turda
        yapilmadi (bkz. `taban.py` modul basligi).
        """
        if not self.host or not self.hedef:
            return DiyafonSonuc(False, HATA_YAPILANDIRMA, "host/hedef yok")
        yerel = _yerel_ip(self.host, self.port)
        kod, ozet = _gonder(
            self.host,
            self.port,
            _istek(
                "MESSAGE",
                host=self.host,
                port=self.port,
                hedef=self.hedef,
                yerel_ip=yerel,
                govde=mesaj,
                icerik_turu="text/plain;charset=UTF-8",
            ),
        )
        if kod is None:
            return DiyafonSonuc(False, HATA_ULASILAMIYOR, ozet)
        if 200 <= kod < 300:
            return DiyafonSonuc(True, ayrinti=ozet)
        return DiyafonSonuc(False, HATA_REDDEDILDI, ozet)

    def kapi_ac(self) -> DiyafonSonuc:
        # Yetenek tablosunda `kapi_ac=False`: SIP cihazinda kapi acmak
        # cihazin HTTP kontrol API'sini ya da DTMF'li bir cagriyi
        # gerektirir; ikisi de bu turda yapilandirilmiyor.
        return DiyafonSonuc(False, HATA_YAPILANDIRMA, "sip kapi acma yok")

    def zil_cal(self) -> DiyafonSonuc:
        return DiyafonSonuc(False, HATA_YAPILANDIRMA, "sip zil yok")


def quote_hedef(hedef: str) -> str:
    """URI'ye gomulecek hedefi kacisla (bosluk/ozel karakter)."""
    return quote(hedef, safe="@:.-_")
