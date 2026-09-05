"""(P213 §6) Dahua CGI adaptoru — arama + oynatma.

===========================================================================
PROTOKOL (cihaz belgelerinden; SAHADA DOGRULANMADI)
===========================================================================
ARAMA — UC ADIMLI ve DURUMLU (Hikvision'dan farki budur):
    1. GET {taban}/cgi-bin/mediaFileFind.cgi?action=factory.create
         -> `result=1234`  (bir "bulucu" nesnesi acilir)
    2. GET .../mediaFileFind.cgi?action=findFile&object=1234
         &condition.Channel=1&condition.StartTime=2026-09-05 14:00:00
         &condition.EndTime=...
    3. GET .../mediaFileFind.cgi?action=findNextFile&object=1234&count=100
         -> `items[0].StartTime=...` bicimli DUZ METIN
    4. GET .../mediaFileFind.cgi?action=close&object=1234   (TEMIZLIK)

Dorduncu adim ONEMLI: acilan bulucu kapatilmazsa cihazda tukeniyor ve bir
sure sonra arama TAMAMEN calismaz hale geliyor. Bu yuzden `finally` icinde
ve hatasi YUTULARAK (kapatma basarisizligi kullaniciya gosterilecek bir
sey degil) cagriliyor.

OYNATMA:
    rtsp://{konak}/cam/playback?channel={kanal}
      &starttime=2026_09_05_14_00_00&endtime=...
    (Dahua'nin zaman bicimi ALT CIZGILI — Hikvision'inkinden farkli.)

===========================================================================
ELIMDE CIHAZ YOK
===========================================================================
Hikvision adaptorundeki not burada da gecerli: her adim ayrintili gunluk
yazar, cozumlenemeyen yanit sessizce bos donmez.
"""
from __future__ import annotations

import datetime as dt
import logging
import re

import httpx

from .taban import KayitAraligi

logger = logging.getLogger(__name__)


class KayitCozumlenemedi(Exception):
    """Cihaz yanit verdi ama beklenen yapida degil."""


def _zaman(an: dt.datetime) -> str:
    return an.astimezone(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


def _rtsp_zaman(an: dt.datetime) -> str:
    return an.astimezone(dt.timezone.utc).strftime("%Y_%m_%d_%H_%M_%S")


_SATIR = re.compile(r"items\[(\d+)\]\.(StartTime|EndTime)=(.+)")


class DahuaSaglayici:
    ad = "dahua"

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
        self._kanal = kanal or "1"
        self._kimlik = (kullanici or "", parola or "")

    async def _cgi(self, sorgu: str) -> httpx.Response:
        adres = f"{self._taban}/cgi-bin/mediaFileFind.cgi?{sorgu}"
        yanit = await self._istemci.get(
            adres, auth=httpx.DigestAuth(*self._kimlik)
        )
        logger.info(
            "[kayit/dahua] %s durum=%s govde_bas=%r",
            sorgu.split("&", 1)[0], yanit.status_code, yanit.text[:200],
        )
        return yanit

    async def araliklari_listele(
        self, bas: dt.datetime, bit: dt.datetime
    ) -> list[KayitAraligi]:
        ac = await self._cgi("action=factory.create")
        if ac.status_code in (401, 403):
            raise KayitCozumlenemedi(f"kimlik reddedildi ({ac.status_code})")
        m = re.search(r"result\s*=\s*(\S+)", ac.text)
        if ac.status_code >= 400 or not m:
            raise KayitCozumlenemedi(
                f"bulucu acilamadi (HTTP {ac.status_code}): {ac.text[:120]!r}"
            )
        nesne = m.group(1).strip()
        try:
            bul = await self._cgi(
                f"action=findFile&object={nesne}"
                f"&condition.Channel={self._kanal}"
                f"&condition.StartTime={_zaman(bas)}"
                f"&condition.EndTime={_zaman(bit)}"
            )
            if bul.status_code >= 400:
                raise KayitCozumlenemedi(f"findFile HTTP {bul.status_code}")
            sonuc = await self._cgi(
                f"action=findNextFile&object={nesne}&count=100"
            )
            if sonuc.status_code >= 400:
                raise KayitCozumlenemedi(
                    f"findNextFile HTTP {sonuc.status_code}"
                )
            return self._coz(sonuc.text)
        finally:
            # TEMIZLIK: kapatilmayan bulucular cihazda birikir ve bir sure
            # sonra arama TAMAMEN calismaz olur. Kapatma hatasi
            # kullanicinin gorecegi bir sey degil — yalnizca gunluge.
            try:
                await self._cgi(f"action=close&object={nesne}")
            except Exception as exc:  # noqa: BLE001
                logger.warning("[kayit/dahua] bulucu kapatilamadi: %s", exc)

    @staticmethod
    def _coz(govde: str) -> list[KayitAraligi]:
        """`items[0].StartTime=...` duz metnini araliklara cevirir."""
        kayitlar: dict[int, dict[str, str]] = {}
        for satir in govde.splitlines():
            m = _SATIR.match(satir.strip())
            if m:
                kayitlar.setdefault(int(m.group(1)), {})[m.group(2)] = m.group(3).strip()
        araliklar: list[KayitAraligi] = []
        for _, alan in sorted(kayitlar.items()):
            if "StartTime" not in alan or "EndTime" not in alan:
                continue
            try:
                araliklar.append(
                    KayitAraligi(
                        dt.datetime.strptime(alan["StartTime"], "%Y-%m-%d %H:%M:%S")
                        .replace(tzinfo=dt.timezone.utc),
                        dt.datetime.strptime(alan["EndTime"], "%Y-%m-%d %H:%M:%S")
                        .replace(tzinfo=dt.timezone.utc),
                    )
                )
            except ValueError:
                logger.warning("[kayit/dahua] zaman cozulemedi: %r", alan)
        logger.info("[kayit/dahua] %d aralik bulundu", len(araliklar))
        return araliklar

    async def oynatma_adresi(self, bas: dt.datetime, bit: dt.datetime) -> str:
        return (
            f"rtsp://{self._rtsp_konak}/cam/playback?channel={self._kanal}"
            f"&starttime={_rtsp_zaman(bas)}&endtime={_rtsp_zaman(bit)}"
        )
