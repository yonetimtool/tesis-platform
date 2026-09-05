"""(P213 §6) Hikvision ISAPI adaptoru — arama + oynatma.

===========================================================================
PROTOKOL (cihaz belgelerinden; SAHADA DOGRULANMADI)
===========================================================================
ARAMA:
    POST {taban}/ISAPI/ContentMgmt/search      (HTTP Digest)
    Govde: <CMSearchDescription> ... <trackIDList><trackID>101</trackID>
    Yanit: <CMSearchResult><matchList><searchMatchItem>
             <timeSpan><startTime>..</startTime><endTime>..</endTime>
             <mediaSegmentDescriptor><playbackURI>rtsp://...

OYNATMA (aramasiz da kurulabilir):
    rtsp://{konak}/Streaming/tracks/{kanal}?starttime=..&endtime=..
    Zaman damgasi ISO temel + `Z` (`20260905T140000Z`).

`playbackURI` VARSA O KULLANILIR: cihazin kendi urettigi adres, elle
kurulan sablondan her zaman daha dogrudur (bazi modeller ozel parametre
ekler).

===========================================================================
ELIMDE CIHAZ YOK — ve bu koda yansidi
===========================================================================
Bu adaptor gercek bir Hikvision NVR'da DENENMEDI (analiz belgesi §5'te
acikca yazildi). Bu yuzden:
  * her adim AYRINTILI gunluk yazar (durum kodu, govde basi, secilen yol),
  * cozumlenemeyen yanit SESSIZCE bos donmez, `KayitCozumlenemedi` atar,
  * arama basarisiz olsa bile OYNATMA denenebilir (uc bunu ayirir).
Ilk gercek cihaz denemesinin TESHIS EDILEBILIR olmasi, dogru calismasi
kadar onemli — P213 §2'de MediaMTX 401'ini bulan sey tam olarak buydu.
"""
from __future__ import annotations

import datetime as dt
import logging
import re
from xml.etree import ElementTree as ET

import httpx

from .taban import KayitAraligi

logger = logging.getLogger(__name__)

_ZAMAN = "%Y-%m-%dT%H:%M:%SZ"


class KayitCozumlenemedi(Exception):
    """Cihaz yanit verdi ama beklenen yapida degil."""


def _damga(an: dt.datetime) -> str:
    return an.astimezone(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _isaret(an: dt.datetime) -> str:
    return an.astimezone(dt.timezone.utc).strftime(_ZAMAN)


def _zaman_coz(metin: str) -> dt.datetime:
    """`2026-09-05T14:00:00Z` ve `...+03:00` biciminlerini kabul eder."""
    m = metin.strip()
    if m.endswith("Z"):
        m = m[:-1] + "+00:00"
    return dt.datetime.fromisoformat(m).astimezone(dt.timezone.utc)


def _etiket(e: ET.Element) -> str:
    """Ad alani onekini atar (`{http://...}timeSpan` -> `timeSpan`)."""
    return e.tag.rsplit("}", 1)[-1]


class HikvisionSaglayici:
    ad = "hikvision"

    def __init__(
        self,
        istemci: httpx.AsyncClient,
        taban: str,
        rtsp_konak: str,
        kanal: str,
        kullanici: str | None,
        parola: str | None,
    ) -> None:
        self._istemci = istemci
        self._taban = taban.rstrip("/")
        self._rtsp_konak = rtsp_konak
        self._kanal = kanal or "101"
        self._kimlik = (kullanici or "", parola or "")

    # ------------------------------ arama ------------------------------- #
    def _arama_govdesi(self, bas: dt.datetime, bit: dt.datetime) -> str:
        return (
            '<?xml version="1.0" encoding="utf-8"?>'
            '<CMSearchDescription>'
            f"<searchID>{_damga(bas)}-{self._kanal}</searchID>"
            f"<trackIDList><trackID>{self._kanal}</trackID></trackIDList>"
            "<timeSpanList><timeSpan>"
            f"<startTime>{_isaret(bas)}</startTime>"
            f"<endTime>{_isaret(bit)}</endTime>"
            "</timeSpan></timeSpanList>"
            "<maxResults>100</maxResults><searchResultPostion>0</searchResultPostion>"
            "<metadataList><metadataDescriptor>//recordType.meta.std-cgi.com"
            "</metadataDescriptor></metadataList>"
            "</CMSearchDescription>"
        )

    async def araliklari_listele(
        self, bas: dt.datetime, bit: dt.datetime
    ) -> list[KayitAraligi]:
        adres = f"{self._taban}/ISAPI/ContentMgmt/search"
        yanit = await self._istemci.post(
            adres,
            content=self._arama_govdesi(bas, bit).encode(),
            headers={"Content-Type": "application/xml"},
            auth=httpx.DigestAuth(*self._kimlik),
        )
        logger.info(
            "[kayit/hikvision] arama %s durum=%s govde_bas=%r",
            adres, yanit.status_code, yanit.text[:200],
        )
        if yanit.status_code in (401, 403):
            raise KayitCozumlenemedi(f"kimlik reddedildi ({yanit.status_code})")
        if yanit.status_code >= 400:
            raise KayitCozumlenemedi(f"HTTP {yanit.status_code}")
        try:
            kok = ET.fromstring(yanit.text)
        except ET.ParseError as exc:
            raise KayitCozumlenemedi(f"XML cozulemedi: {exc}") from exc

        araliklar: list[KayitAraligi] = []
        for e in kok.iter():
            if _etiket(e) != "timeSpan":
                continue
            alan = {_etiket(c): (c.text or "") for c in e}
            if "startTime" not in alan or "endTime" not in alan:
                continue
            try:
                araliklar.append(
                    KayitAraligi(_zaman_coz(alan["startTime"]),
                                 _zaman_coz(alan["endTime"]))
                )
            except ValueError:
                logger.warning("[kayit/hikvision] zaman cozulemedi: %r", alan)
        # BOS LISTE GECERLI BIR SONUCTUR (o aralikta kayit yok) — bunu
        # hata saymak, gercekten bos bir gunu "cihaz bozuk" gibi
        # gosterirdi. Yanit HIC `timeSpan` icermiyorsa da ayni: cihaz
        # `<numOfMatches>0</numOfMatches>` doner.
        logger.info("[kayit/hikvision] %d aralik bulundu", len(araliklar))
        return araliklar

    # ----------------------------- oynatma ------------------------------ #
    async def oynatma_adresi(self, bas: dt.datetime, bit: dt.datetime) -> str:
        """Once cihazin kendi `playbackURI`si; olmazsa standart sablon."""
        try:
            uri = await self._playback_uri(bas, bit)
            if uri:
                return uri
        except Exception as exc:  # noqa: BLE001
            # Arama coktugunde OYNATMA VAZGECILMEZ: sablon yolu hâlâ
            # calisabilir ve kullanicinin gormek istedigi sey kayittir.
            logger.warning(
                "[kayit/hikvision] playbackURI alinamadi (%s) — sablona dusuyorum",
                exc,
            )
        return (
            f"rtsp://{self._rtsp_konak}/Streaming/tracks/{self._kanal}"
            f"?starttime={_damga(bas)}&endtime={_damga(bit)}"
        )

    async def _playback_uri(self, bas: dt.datetime, bit: dt.datetime) -> str | None:
        yanit = await self._istemci.post(
            f"{self._taban}/ISAPI/ContentMgmt/search",
            content=self._arama_govdesi(bas, bit).encode(),
            headers={"Content-Type": "application/xml"},
            auth=httpx.DigestAuth(*self._kimlik),
        )
        if yanit.status_code >= 400:
            return None
        m = re.search(r"<playbackURI>(.*?)</playbackURI>", yanit.text, re.S)
        return m.group(1).strip() if m else None
