"""(P240 §3) HOME ASSISTANT KOPRUSU — REST API.

===========================================================================
NEDEN HOME ASSISTANT
===========================================================================
Zigbee/Z-Wave/Matter cihazlarinin sahada en yaygin toplandigi yer HA'dir
ve API'si duz HTTP+JSON: `GET /api/states/<entity>` durumu verir,
`POST /api/services/<domain>/<servis>` komut calistirir. Yani kopru
katmani icin EK BIR BAGIMLILIK GEREKMEZ.

===========================================================================
SSRF: IC AG SERBEST — diyafondaki gerekcenin aynisi
===========================================================================
Hub SITEDEDIR (192.168.x.x). `safe_http` kapisi kullanicinin yazdigi
webhook URL'leri icindir; buraya koymak ozelligin kendisini imkansiz
kilardi. Sinir dar: yalniz iki yol cagrilir (`/api/states/...`,
`/api/services/...`), yanit GOVDESI yalniz DURUM okumada donulur ve o da
cihaz durumudur — ic-ag tarayicisina cevrilemez.

===========================================================================
JETON BASLIKTA, LOGDA DEGIL
===========================================================================
HA uzun-omurlu jetonu `Authorization: Bearer ...` ile gider ve HICBIR
log satirina yazilmaz. Hata ayrintilarinda da yalniz durum kodu tutulur.
"""
from __future__ import annotations

import json
import socket

from .taban import (
    EYLEM_AC,
    EYLEM_KAPAT,
    EYLEM_KILIT_AC,
    EYLEM_VANA_KAPAT,
    HATA_DESTEKLENMIYOR,
    HATA_REDDEDILDI,
    HATA_ULASILAMIYOR,
    HATA_YAPILANDIRMA,
    HOME_ASSISTANT,
    KopruSonuc,
    eylem_gecerli,
)

ZAMAN_ASIMI_SN = 5.0
#: Yanit tamponu — durum JSON'lari birkac KB'dir.
TAMPON = 64 * 1024

#: Eylem -> (HA alan adi, servis). `entity_id` govdede gider.
#:
#: KILIT ACMA `lock.unlock`: `lock.open` her cihazda YOK ve olmayan bir
#: servisi cagirmak 400 doner. Vana kapatma `switch.turn_off`: HA'da
#: vanalar cogunlukla `switch` ya da `valve` olarak gorunur ve `switch`
#: EVRENSEL olandir.
SERVIS: dict[str, tuple[str, str]] = {
    EYLEM_AC: ("homeassistant", "turn_on"),
    EYLEM_KAPAT: ("homeassistant", "turn_off"),
    EYLEM_KILIT_AC: ("lock", "unlock"),
    EYLEM_VANA_KAPAT: ("homeassistant", "turn_off"),
}


class HomeAssistantKopru:
    tur = HOME_ASSISTANT

    def __init__(self, *, host: str, port: int | None, token: str | None) -> None:
        self.host = host
        self.port = port or 8123
        self.token = token

    # ----------------------------- HTTP ------------------------------- #
    def _istek(
        self, metot: str, yol: str, govde: dict | None = None
    ) -> tuple[int | None, str]:
        """Ham HTTP/1.1 — `httpx` DEGIL.

        `safe_http` kullanmiyoruz (ic ag; bkz. modul basligi) ve bunu
        AYRI BIR YOL olarak yazmak, "bu istek SSRF kapisindan gecmiyor"
        gercegini GORUNUR kilar (diyafondaki ayni karar).
        """
        if not self.host:
            return None, "host yok"
        veri = json.dumps(govde or {}).encode("utf-8") if govde is not None else b""
        basliklar = [
            f"{metot} {yol} HTTP/1.1",
            f"Host: {self.host}",
            "User-Agent: Yonetiyor/1.0",
            "Connection: close",
            "Accept: application/json",
        ]
        if self.token:
            basliklar.append(f"Authorization: Bearer {self.token}")
        if govde is not None:
            basliklar.append("Content-Type: application/json")
            basliklar.append(f"Content-Length: {len(veri)}")
        ham = ("\r\n".join(basliklar) + "\r\n\r\n").encode("utf-8") + veri
        try:
            with socket.create_connection(
                (self.host, self.port), timeout=ZAMAN_ASIMI_SN
            ) as s:
                s.sendall(ham)
                parcalar: list[bytes] = []
                toplam = 0
                while True:
                    p = s.recv(8192)
                    if not p:
                        break
                    parcalar.append(p)
                    toplam += len(p)
                    # SINIRSIZ OKUMA YOK: kotu niyetli ya da bozuk bir
                    # hub'in bellegi doldurmasina izin verilmez.
                    if toplam >= TAMPON:
                        break
        except OSError as exc:
            return None, f"{type(exc).__name__}: {exc}"
        yanit = b"".join(parcalar).decode("utf-8", "replace")
        ilk = yanit.split("\r\n", 1)[0]
        alanlar = ilk.split(" ")
        kod = None
        if len(alanlar) >= 2 and alanlar[0].upper().startswith("HTTP/"):
            try:
                kod = int(alanlar[1])
            except ValueError:
                kod = None
        govde_metni = yanit.split("\r\n\r\n", 1)[1] if "\r\n\r\n" in yanit else ""
        return kod, govde_metni

    # ---------------------------- ARAYUZ ------------------------------ #
    def saglik(self) -> KopruSonuc:
        """`GET /api/` — HA'nin "API calisiyor" ucu. CIHAZ CALISTIRMAZ."""
        if not self.token:
            return KopruSonuc(False, HATA_YAPILANDIRMA, "jeton yok")
        kod, govde = self._istek("GET", "/api/")
        if kod is None:
            return KopruSonuc(False, HATA_ULASILAMIYOR, govde[:200])
        if kod == 401 or kod == 403:
            # YETKI HATASI BIR AG HATASI DEGIL: kullaniciyi aga degil
            # JETONA bakmaya gondermeli.
            return KopruSonuc(False, HATA_REDDEDILDI, f"HTTP {kod}")
        if 200 <= kod < 300:
            return KopruSonuc(True)
        return KopruSonuc(False, HATA_REDDEDILDI, f"HTTP {kod}")

    def durum(self, dis_kimlik: str) -> KopruSonuc:
        kod, govde = self._istek("GET", f"/api/states/{dis_kimlik}")
        if kod is None:
            return KopruSonuc(False, HATA_ULASILAMIYOR, govde[:200])
        if not (200 <= kod < 300):
            return KopruSonuc(False, HATA_REDDEDILDI, f"HTTP {kod}")
        try:
            return KopruSonuc(True, veri=json.loads(govde))
        except ValueError:
            return KopruSonuc(False, HATA_REDDEDILDI, "gecersiz JSON")

    def komut(self, dis_kimlik: str, eylem: str, tip: str) -> KopruSonuc:
        if not eylem_gecerli(tip, eylem):
            # TIP/EYLEM UYUMSUZLUGU HUB'A GITMEZ: bir duman dedektorune
            # "ac" demek 400 doner ve kullanici NEDEN oldugunu anlamaz.
            return KopruSonuc(False, HATA_DESTEKLENMIYOR, f"{tip}/{eylem}")
        alan, servis = SERVIS[eylem]
        kod, govde = self._istek(
            "POST", f"/api/services/{alan}/{servis}", {"entity_id": dis_kimlik}
        )
        if kod is None:
            return KopruSonuc(False, HATA_ULASILAMIYOR, govde[:200])
        if 200 <= kod < 300:
            return KopruSonuc(True)
        return KopruSonuc(False, HATA_REDDEDILDI, f"HTTP {kod}")
