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

from .taban import AramaDesteklenmiyor, KayitAraligi


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
        u = dt.timezone.utc
        b, s = bas.astimezone(u), bit.astimezone(u)
        return self._sablon.format(
            bas=_damga(b), bit=_damga(s),
            bas_tarih=b.strftime("%Y-%m-%d"), bit_tarih=s.strftime("%Y-%m-%d"),
            bas_saat=b.strftime("%H:%M:%S"), bit_saat=s.strftime("%H:%M:%S"),
            bas_unix=int(b.timestamp()), bit_unix=int(s.timestamp()),
            kanal=self._kanal,
        )
