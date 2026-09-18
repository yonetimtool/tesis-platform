"""(P240 §2) KURU KONTAK KOPRUSU — analog diyafon icin role modulu.

===========================================================================
NE YAPAR, NE YAPAMAZ
===========================================================================
Analog (sesli olmayan) diyafon sistemleri bir SIP ucu sunmaz; tek giris
noktalari elektriksel bir KONTAKTIR. Piyasadaki role modulleri (Shelly,
KMtronic, Sonoff benzeri) bu kontagi bir HTTP cagrisiyla kapatir.

YAPABILDIGI: zil calmak, kapi rolesini tetiklemek.
YAPAMADIGI:  SESLI MESAJ ya da METIN ANONSU. Bu bir eksiklik degil,
             yontemin YAPISAL siniridir — bir kontak "bilgi" tasimaz,
             yalnizca "kapan/ac" der. Arayuz bunu ACIKCA yazar (istegin
             "bu sınırı arayüzde açıkça göster" maddesi).

===========================================================================
MQTT BU TURDA YAPILMADI
===========================================================================
Istekte "HTTP veya MQTT" geciyor. HTTP yapildi; MQTT YAPILMADI ve
gerekcesi: bir MQTT istemcisi + broker baglantisi (kalici oturum,
yeniden baglanma, QoS secimi) yeni bir altyapi demek ve DONANIMSIZ
dogrulanamaz. Piyasadaki role modullerinin tamami HTTP de sunuyor;
yani bugun hicbir musteri bu yuzden disarida kalmiyor.

===========================================================================
ZIL VE KAPI AYRI YOLLAR
===========================================================================
Tek bir "tetik yolu" olsaydi "zil cal" ile "kapi ac" ayirt edilemezdi —
ve bir role modulunde bu ikisi FARKLI kanallardir (rele 1 / rele 2).
Yapilandirmada ikisi ayri alan; biri bossa o eylem DESTEKLENMIYOR
sayilir (sessizce zil calmaya calisip kapi acmak kabul edilemez).
"""
from __future__ import annotations

import base64
import socket
from urllib.parse import urlparse

from .taban import (
    HATA_REDDEDILDI,
    HATA_ULASILAMIYOR,
    HATA_YAPILANDIRMA,
    KURU_KONTAK,
    VARSAYILAN_PORT,
    DiyafonSonuc,
)

ZAMAN_ASIMI_SN = 5.0


class KuruKontakDiyafon:
    """HTTP ile tetiklenen role modulu."""

    def __init__(
        self,
        *,
        host: str,
        port: int | None,
        kullanici: str | None,
        sifre: str | None,
        zil_yolu: str | None,
        kapi_yolu: str | None,
    ) -> None:
        self.host = host
        self.port = port or VARSAYILAN_PORT[KURU_KONTAK]
        self.kullanici = kullanici
        self.sifre = sifre
        self.zil_yolu = zil_yolu
        self.kapi_yolu = kapi_yolu
        self.yontem = KURU_KONTAK

    def _istek(self, yol: str) -> DiyafonSonuc:
        """Ham HTTP/1.1 GET — `httpx` DEGIL.

        Role modulleri cogu zaman HTTP/1.0 konusan, `Host` basligina
        duyarsiz gomulu sunuculardir; `httpx` bunlarin bazilarinda
        baglanti kurar ama yanit ayristirmada takilir (olculemedi, ama
        risk gercek). Daha onemlisi: BURADA SSRF KAPISI YOK (cihaz zaten
        ic agda) ve `safe_http` kullanmak yaniltici olurdu — ayri bir
        yol acmak, "bu istek kapidan gecmiyor" gercegini GORUNUR kilar.
        """
        try:
            with socket.create_connection(
                (self.host, self.port), timeout=ZAMAN_ASIMI_SN
            ) as s:
                basliklar = [
                    f"GET {yol} HTTP/1.1",
                    f"Host: {self.host}",
                    "User-Agent: Yonetiyor/1.0",
                    "Connection: close",
                ]
                if self.kullanici:
                    ham = f"{self.kullanici}:{self.sifre or ''}".encode("utf-8")
                    basliklar.append(
                        "Authorization: Basic "
                        + base64.b64encode(ham).decode("ascii")
                    )
                s.sendall(("\r\n".join(basliklar) + "\r\n\r\n").encode("utf-8"))
                # YANIT GOVDESI OKUNMAZ: yalniz durum satiri gerekli ve
                # govdeyi okumak, ic agdaki bir cihazin icerigini
                # kullaniciya tasiyan bir yol acardi.
                veri = s.recv(256)
        except OSError as exc:
            return DiyafonSonuc(False, HATA_ULASILAMIYOR, f"{type(exc).__name__}: {exc}")

        ilk = veri.split(b"\r\n", 1)[0].decode("utf-8", "replace")
        parcalar = ilk.split(" ")
        if len(parcalar) >= 2 and parcalar[0].upper().startswith("HTTP/"):
            try:
                kod = int(parcalar[1])
            except ValueError:
                return DiyafonSonuc(False, HATA_REDDEDILDI, ilk)
            if 200 <= kod < 400:
                return DiyafonSonuc(True, ayrinti=ilk)
            return DiyafonSonuc(False, HATA_REDDEDILDI, ilk)
        return DiyafonSonuc(False, HATA_REDDEDILDI, ilk or "yanit yok")

    def saglik(self) -> DiyafonSonuc:
        """TCP baglantisi — HICBIR ROLE TETIKLENMEZ.

        P240 §4'un kurali burada da gecerli: saglik kontrolu cihazi
        CALISTIRMAZ. Zil yolunu "test icin" cagirmak, 15 dakikada bir
        zil calmak olurdu.
        """
        if not self.host:
            return DiyafonSonuc(False, HATA_YAPILANDIRMA, "host yok")
        try:
            with socket.create_connection(
                (self.host, self.port), timeout=ZAMAN_ASIMI_SN
            ):
                return DiyafonSonuc(True)
        except OSError as exc:
            return DiyafonSonuc(
                False, HATA_ULASILAMIYOR, f"{type(exc).__name__}: {exc}"
            )

    def metin_anons(self, mesaj: str) -> DiyafonSonuc:
        # YAPISAL SINIR: kontak bilgi tasimaz.
        return DiyafonSonuc(False, "diyafon_yontem_desteklemiyor", "kuru kontak")

    def kapi_ac(self) -> DiyafonSonuc:
        if not self.kapi_yolu:
            return DiyafonSonuc(False, HATA_YAPILANDIRMA, "kapi yolu yok")
        return self._istek(self.kapi_yolu)

    def zil_cal(self) -> DiyafonSonuc:
        if not self.zil_yolu:
            return DiyafonSonuc(False, HATA_YAPILANDIRMA, "zil yolu yok")
        return self._istek(self.zil_yolu)


def yol_gecerli(yol: str | None) -> bool:
    """Yol `/`, ile baslamali ve konak icermemeli.

    Tam URL kabul etmek, yapilandirmadaki `host` alanini ANLAMSIZ
    kilardi ve iki farkli hedefi (host + URL konagi) ayni kayda
    sikistirirdi.
    """
    if not yol:
        return True
    if not yol.startswith("/"):
        return False
    return not urlparse(yol).netloc
