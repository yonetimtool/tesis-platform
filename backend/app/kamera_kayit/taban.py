"""(P213 §6) GECMIS KAYIT ADAPTOR ARAYUZU — markadan bagimsiz tek agiz.

===========================================================================
NEDEN ADAPTOR
===========================================================================
NVR'lar ayni isi UC AYRI dille yapiyor:
  * ONVIF Profile G  — standart; sahada GUVENILMEZ (Profile S her cihazda
    var, G cogunda eksik ya da hic yok). Bu turda YAZILMADI, sonraki tura
    birakildi (gerekce: analiz belgesi §5).
  * Hikvision ISAPI  — XML arama + `playbackURI`.
  * Dahua CGI        — `mediaFileFind.cgi` + `cam/playback` adresi.
Ustune, arama API'sine hic erisilemeyen kurulumlar var (yalniz 554
yonlendirilmis site): onlar icin ARAMASIZ `sablon` adaptoru.

Dort ayri cagri yerini uce bolmek yerine TEK arayuz: uclar ve web ekrani
hangi markayla konustugunu BILMEZ.

===========================================================================
IKI METOT, IKI AYRI SORU
===========================================================================
`araliklari_listele` : "bu aralikta HANGI dakikalarda kayit var?"
`oynatma_adresi`     : "su araligi oynatmak icin hangi RTSP adresi?"

Ayri olmalari onemli: arama API'si kapali bir kurulumda listeleme
CALISMAZ ama oynatma CALISIR. Tek metotta birlestirmek, ikinci yetenegi
birincinin eksikligine kurban ederdi.
"""
from __future__ import annotations

import dataclasses
import datetime as dt
from typing import Protocol


@dataclasses.dataclass(frozen=True, slots=True)
class KayitAraligi:
    """Kayit BULUNAN bir zaman araligi (UTC)."""

    bas: dt.datetime
    bit: dt.datetime


class AramaDesteklenmiyor(Exception):
    """Adaptor oynatabiliyor ama ARAYAMIYOR (`sablon`).

    Ozel bir istisna, cunku bu bir HATA DEGIL bir YETENEK SINIRIDIR ve
    arayuzde "kayit yok" ile ayni sekilde gosterilmesi yaniltici olurdu:
    kullanici "kayit yok" gorup vazgecerdi, oysa kayit VAR ve
    oynatilabilir.
    """


class KayitSaglayici(Protocol):
    """Tum adaptorlerin uydugu agiz."""

    ad: str

    async def araliklari_listele(
        self, bas: dt.datetime, bit: dt.datetime
    ) -> list[KayitAraligi]:
        """Kayit bulunan araliklar. Arama desteklenmiyorsa
        `AramaDesteklenmiyor` atar (bos liste DONDURMEZ)."""

    async def oynatma_adresi(self, bas: dt.datetime, bit: dt.datetime) -> str:
        """Verilen araligi oynatan RTSP adresi (kimlik GOMULU)."""
