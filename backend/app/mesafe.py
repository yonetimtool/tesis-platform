"""(P160) Okutma mesafesi ve ESIK KARARI — saf hesap, veritabani YOK.

===========================================================================
KURAL ISTEMCIYLE BIREBIR AYNI OLMALI
===========================================================================
Ayni karar iki yerde veriliyor:
  * panel haritasi (`admin-web/lib/mesafe.ts`) — GORSELLESTIRME,
  * burasi — ALARM.

Ikisi ayrisirsa harita "esik icinde" derken bildirim "esik disi" der ve
yonetici hangisine inanacagini bilemez. Bu yuzden kural TEK CUMLEYLE
yazildi ve iki dilde ayni: `dogruluk > esik` ise BELIRSIZ, degilse
`mesafe > esik` ise DISINDA, aksi halde ICINDE.

===========================================================================
"BELIRSIZ" NEDEN ZORUNLU
===========================================================================
GPS dogrulugu esikten BUYUKSE karsilastirma KARAR VEREMEZ: ±100 m hatayla
olculmus bir mesafenin 50 m esigini gecip gecmedigi bilinemez. Bunu "esik
disi" saymak, OLCUM HATASINI IHLAL diye raporlamakti — ve alarm uretmek,
haritada renk degistirmekten cok daha agir bir iddiadir: birinin
telefonu caliyor.

Bu bir urun karari DEGIL, ARITMETIK: hata payi esigin tamamindan buyukse
kiyas anlamsizdir. BELIRSIZ olan okutma icin ALARM URETILMEZ.

===========================================================================
HAVERSINE
===========================================================================
Site olceginde duzlemsel yaklasim da yeterdi ama haversine hem kisa hem
dogru ve enlem arttikca bozulmuyor. Yaricap WGS84 ortalama kure yaricapi
— `admin-web/lib/mesafe.ts` ile AYNI sabit.
"""
from __future__ import annotations

from math import asin, cos, radians, sin, sqrt
from typing import Literal

#: Ortalama Dunya yaricapi (m) — WGS84 ortalama kure.
DUNYA_YARICAPI = 6_371_008.8

EsikSonucu = Literal["icinde", "disinda", "belirsiz"]


def mesafe_metre(a_lat: float, a_lon: float, b_lat: float, b_lon: float) -> int:
    """Iki nokta arasi buyuk cember mesafesi — METRE, tam sayiya yuvarli."""
    d_lat = radians(b_lat - a_lat)
    d_lon = radians(b_lon - a_lon)
    h = (
        sin(d_lat / 2) ** 2
        + cos(radians(a_lat)) * cos(radians(b_lat)) * sin(d_lon / 2) ** 2
    )
    return round(2 * DUNYA_YARICAPI * asin(min(1.0, sqrt(h))))


def esik_sonucu(mesafe: int, esik: int, dogruluk: float | None) -> EsikSonucu:
    """Mesafeyi esikle karsilastirir — `mesafe.ts`teki kuralin aynisi.

    `dogruluk` bilinmiyorsa (eski istemci alani gondermez) karsilastirma
    YAPILIR: elde baska bir sey yok ve her okutmayi belirsiz saymak esigi
    tamamen ise yaramaz kilardi.
    """
    if dogruluk is not None and dogruluk > esik:
        return "belirsiz"
    return "disinda" if mesafe > esik else "icinde"
