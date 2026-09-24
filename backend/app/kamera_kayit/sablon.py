"""(P213 §6) `sablon` adaptoru — ARAMASIZ oynatma, marka bilinmeden.

===========================================================================
NE ISE YARAR
===========================================================================
Pilot sitenin NVR markasi HENUZ BILINMIYOR ve iki durumda tek calisan yol
budur:
  1. Arama API'si (80/443) sunucumuza acik degil — yalniz RTSP (554)
     yonlendirilmis. Sahada en sik karsilasilan kurulum.
  2. Marka taninmiyor ya da adaptoru yok.

Kullanici NVR'in oynatma adres SABLONUNU yazar; biz zaman damgalarini
yerine koyariz. Arama YOK, yani "hangi saatlerde kayit var" bilinmez ve
`araliklari_listele` bilerek `AramaDesteklenmiyor` atar — bos liste
donmek "kayit yok" demek olurdu ve KULLANICIYI YANILTIRDI.

===========================================================================
SABLON DILI — kasten kucuk
===========================================================================
Desteklenen yer tutucular:
    {bas}  {bit}          -> `20260905T140000Z` (ISO temel, UTC)
    {bas_tarih} {bit_tarih} -> `2026-09-05`
    {bas_saat}  {bit_saat}  -> `14:00:00`
    {bas_unix}  {bit_unix}  -> saniye
    {kanal}                 -> `kayit_kanal`
Genel amacli bir sablon motoru (jinja vb.) KULLANILMADI: sablonu yazan
kisi kamera formundan gelen bir kullanici ve o metin sunucuda
degerlendirilecek — sinirli bir sozluk, sunucu tarafi sablon enjeksiyonu
yuzeyini sifirlar.
"""
from __future__ import annotations

import datetime as dt
import string

from .taban import AramaDesteklenmiyor, KayitAraligi

#: Sablonda kullanilabilecek yer tutucularin TAMAMI (docstring'deki liste).
YER_TUTUCULAR: frozenset[str] = frozenset({
    "bas", "bit", "bas_tarih", "bit_tarih", "bas_saat", "bit_saat",
    "bas_unix", "bit_unix", "kanal",
})


class SablonGecersiz(ValueError):
    """(E2E 2026-09 / GUVENLIK-03) Sablon cozulemiyor — `str(exc)` sorunlu
    parcayi (`{yokalan}`, `{`) tasir; kullaniciya gosterilebilir, sir
    icermez (sablon parolasiz saklanir, kimlik oynatmada takilir)."""


def sablon_dogrula(sablon: str) -> None:
    """(E2E 2026-09 / GUVENLIK-03) Sablonu KAYIT ANINDA dogrular.

    OLCULEN KUSUR: `{yokalan}` ya da tek `{` iceren bir sablon 200 ile
    kaydediliyor, hata ancak OYNATMADA `str.format`in KeyError/ValueError'i
    olarak cikiyordu — 500, ustelik bunu goren kisi sablonu yazan yonetici
    degil kaydi acmaya calisan guvenlik amiriydi.

    Iki adim: (1) `Formatter.parse` ile her alan adi IZINLI kumede mi
    (nokta/koseli parantezli erisim — `{bas.__class__}` — da burada
    reddedilir, cunku alan adi kumede birebir aranir); (2) ornek degerlerle
    DENEME bicimlemesi: bicim belirteci (`{bas_unix:q}`) gibi parse'in
    yakalamadigi hatalar icin.
    """
    try:
        parcalar = list(string.Formatter().parse(sablon or ""))
    except ValueError as exc:
        raise SablonGecersiz("{") from exc
    for _metin, alan, bicim, _donusum in parcalar:
        if alan is None:
            continue
        if alan not in YER_TUTUCULAR:
            raise SablonGecersiz("{" + alan + "}")
        if bicim and "{" in bicim:
            # Ic ice alan (`{bas:{kanal}}`) — sablon dili bilerek kucuk.
            raise SablonGecersiz("{" + alan + ":" + bicim + "}")
    an = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc)
    try:
        _bicimle(sablon or "", an, an, "1")
    except (KeyError, IndexError, ValueError, TypeError, AttributeError) as exc:
        raise SablonGecersiz(str(exc)[:80] or "{") from exc


def _bicimle(sablon: str, bas: dt.datetime, bit: dt.datetime, kanal: str) -> str:
    u = dt.timezone.utc
    b, s = bas.astimezone(u), bit.astimezone(u)
    return sablon.format(
        bas=_damga(b), bit=_damga(s),
        bas_tarih=b.strftime("%Y-%m-%d"), bit_tarih=s.strftime("%Y-%m-%d"),
        bas_saat=b.strftime("%H:%M:%S"), bit_saat=s.strftime("%H:%M:%S"),
        bas_unix=int(b.timestamp()), bit_unix=int(s.timestamp()),
        kanal=kanal,
    )


def _damga(an: dt.datetime) -> str:
    return an.astimezone(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


class SablonSaglayici:
    ad = "sablon"

    def __init__(self, sablon: str, kanal: str | None = None) -> None:
        self._sablon = sablon
        self._kanal = kanal or ""

    async def araliklari_listele(
        self, bas: dt.datetime, bit: dt.datetime
    ) -> list[KayitAraligi]:
        raise AramaDesteklenmiyor(self.ad)

    async def oynatma_adresi(self, bas: dt.datetime, bit: dt.datetime) -> str:
        # (E2E 2026-09 / GUVENLIK-03) Kayit aninda dogrulama yeni kayitlari
        # korur; bu yakalama, dogrulama ONCESI kaydedilmis bozuk sablonlar
        # icin: 500 yerine adlandirilmis hata (uc 422'ye cevirir).
        try:
            return _bicimle(self._sablon, bas, bit, self._kanal)
        except (KeyError, IndexError, ValueError, TypeError, AttributeError) as exc:
            raise SablonGecersiz(str(exc)[:80] or "{") from exc
