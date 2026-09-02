"""(P154) Kaba kuvvet / SMS taskini hiz siniri — Redis sayaci.

NEDEN YENI BIR MODUL: depoda hiz siniri YOKTU. `auth.kayit_basla` bir
`redis` bagimliligi tasiyordu ama HIC KULLANMIYORDU (olculdu) — yani
kod, sinir koyulacagini varsayan bir iskelet birakmis ama koymamisti.

NEYI KORUR: kod gonderen uclar her cagrida bir SMS uretir. Sinirsiz
birakildiginda iki ayri zarar dogar:
  1. PARA — her SMS ucretlidir; bir betik gece boyunca kotayi tuketir.
  2. TACIZ — hedef numaraya saniyede bir kod mesaji gonderilebilir.

`kayit_dogrulama.deneme` sayaci YETMEZ: o, KOD DENEMESINI sinirlar
(yanlis kod girme). Buradaki sinir KOD ISTEMEYI sinirlar; ikisi farkli
saldirilardir ve biri otekini kapatmaz.

=========================================================================
NEDEN TELEFON BASINA, NEDEN IP BASINA DEGIL
=========================================================================
IP sayaci ancak GUVENILIR bir istemci adresi varken anlamlidir; bu
kurulumda istekler Caddy'nin arkasindan gelir ve `X-Forwarded-For`a
guvenmek, basligi uyduran birine sinirsiz hak vermek olurdu. Ayrica
korunmak istenen sey oncelikle NUMARANIN SAHIBI ve SMS butcesidir —
ikisi de telefon eksenindedir. IP sinirlamasi, ters vekil yapilandirmasi
guvenilir hâle geldiginde EK bir katman olarak dusunulmeli.

=========================================================================
SAYAC DOGRULAMADAN **ONCE** ARTAR — bilincli
=========================================================================
Once dogrulayip sonra saymak, ucu bir SORGULAMA ARACINA cevirirdi:
eslesmeyen numara icin sayac artmazsa, saldirgan sinirsiz deneme yapip
"hangi numara bu tesiste kayitli" sorusunu yanitlayabilirdi. Sayac herkes
icin artar; eslesme sonucu sayaci DEGISTIRMEZ.

REDIS YOKSA ISTEK GECER (fail-open): sinir bir GUVENLIK KATMANI'dir,
kimlik dogrulamasinin kendisi degil. Redis dustugunde kayit akisini
tumden kapatmak, saldiriyi degil kullaniciyi cezalandirirdi. Dusme
gunluge yazilir.
"""
from __future__ import annotations

import logging

import redis.asyncio as aioredis

from .errors import APIError

_log = logging.getLogger(__name__)

#: Kod isteme: pencere basina kac istek. Uc deneme, "SMS gelmedi, tekrar
#: gonder"e yer birakir; dorduncusu artik kullanici degil betiktir.
KOD_ISTEK_SINIRI = 3
#: Pencere (saniye). 15 dakika, kodun 10 dakikalik omrunden UZUN secildi:
#: kisa pencere, suresi dolan kodu yenilemeyi serbest birakirdi.
KOD_ISTEK_PENCERE_SN = 15 * 60

ASILDI = APIError(429, "rate_limited", "cok_fazla_kod_istegi")

#: (P203 §2) PAROLA DENEME yuzeyleri icin AYRI mesaj. `tesislerim` bir
#: kod istegi DEGIL; kullaniciya "cok fazla kod istegi" demek, yapmadigi
#: bir seyi yaptigini soylemekti.
DENEME_ASILDI = APIError(429, "rate_limited", "cok_fazla_deneme")

#: Parola denemesi kod istemekten SIKTIR: "SMS gelmedi, tekrar gonder"
#: gibi mesru bir tekrar yok. On deneme, parolasini yanlis hatirlayan
#: kullaniciya yer birakir; on birincisi betiktir.
DENEME_SINIRI = 10


async def kod_istegi_say(
    redis: aioredis.Redis | None,
    telefon: str,
    *,
    kapsam: str = "kod",
    sinir: int = KOD_ISTEK_SINIRI,
    hata: APIError = ASILDI,
) -> None:
    """Telefon basina kod isteme sayacini artirir; sinir asilirsa 429.

    `kapsam` farkli akislari AYIRIR (`kayit`, `giris`, `hesap_silme`):
    kayit icin kod isteyen biri, girisin sayacini tuketmemeli.
    """
    if redis is None:
        return
    anahtar = f"hiz:{kapsam}:{telefon}"
    try:
        sayi = await redis.incr(anahtar)
        if sayi == 1:
            # TTL YALNIZ ILK ARTISTA: her istekte yenilemek pencereyi
            # KAYAN hâle getirir ve surekli istek gonderen biri sayaci
            # hic sifirlatmadan pencereyi sonsuza uzatirdi.
            await redis.expire(anahtar, KOD_ISTEK_PENCERE_SN)
    except Exception as e:  # pragma: no cover - Redis dususu
        # Bkz. modul basligi: fail-open.
        _log.warning("hiz siniri sayaci yazilamadi (%s): %s", anahtar, e)
        return
    if sayi > sinir:
        raise hata
