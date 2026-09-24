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
from fastapi import Depends, Request

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


# ========================================================================= #
# (E2E 2026-09) PAROLA GIRISI — YALNIZ BASARISIZ DENEMELER SAYILIR
# ========================================================================= #
# OLCULEN KUSUR: `/auth/login` ve `/auth/login-phone` HIC sinirli degildi
# (20/20 yanlis parola -> 401, 429 yok); ayni yuzeyin ucuncu kapisi
# `tesislerim` sinirliydi. Saldirgan kilitsiz kapiyi kullanir.
#
# NEDEN YALNIZ BASARISIZLAR: basarili giris bir KULLANICI eylemidir —
# ayni hesapla gun icinde defalarca giris yapan bir yonetici (web + mobil +
# tarayici degisimi) kilitlenmemeli. Sayac kimlik icin (var olsun olmasin)
# HER basarisizlikta artar; yani sinir hesap varligini sizdirmaz.
#
# Basarili giris sayaci SIFIRLAR: dogru parolayi bilen biri zaten
# saldirgan degildir.


def _giris_anahtari(kimlik: str) -> str:
    return f"hiz:giris_parola:{kimlik.lower()}"


async def giris_kilidi_denetle(redis: aioredis.Redis | None, kimlik: str) -> None:
    """Kimlik icin basarisiz deneme siniri asildiysa 429 (parola DENENMEDEN)."""
    if redis is None:
        return
    try:
        sayi = await redis.get(_giris_anahtari(kimlik))
    except Exception as e:  # pragma: no cover - Redis dususu (fail-open)
        _log.warning("giris sayaci okunamadi: %s", e)
        return
    if sayi is not None and int(sayi) >= DENEME_SINIRI:
        raise DENEME_ASILDI


async def giris_basarisiz(redis: aioredis.Redis | None, kimlik: str) -> None:
    if redis is None:
        return
    anahtar = _giris_anahtari(kimlik)
    try:
        sayi = await redis.incr(anahtar)
        if sayi == 1:
            await redis.expire(anahtar, KOD_ISTEK_PENCERE_SN)
    except Exception as e:  # pragma: no cover
        _log.warning("giris sayaci yazilamadi: %s", e)


async def giris_basarili(redis: aioredis.Redis | None, kimlik: str) -> None:
    if redis is None:
        return
    try:
        await redis.delete(_giris_anahtari(kimlik))
    except Exception as e:  # pragma: no cover
        _log.warning("giris sayaci silinemedi: %s", e)


async def kod_istegi_geri_al(
    redis: aioredis.Redis | None, anahtar_kimlik: str, *, kapsam: str
) -> None:
    """GONDERILEMEYEN kod istegini sayactan dusur.

    Kullanici kodu hic almadiysa (saglayici hatasi) "tekrar gonder" hakki
    yanmamali — Dukkan SMS kuraliyla ayni (basarisiz gonderim hiz sinirini
    yemez).
    """
    if redis is None:
        return
    try:
        await redis.decr(f"hiz:{kapsam}:{anahtar_kimlik}")
    except Exception as e:  # pragma: no cover
        _log.warning("kod sayaci geri alinamadi: %s", e)


# ========================================================================= #
# (P247 §6) KULLANICI BASINA HIZ SINIRI — arama ve disa aktarim
# ========================================================================= #
# Uc guvenlik envanterinde arama (`/arama`, `/units/ara`, `/konum/ara`) ve
# disa aktarim/PDF uclari SINIRSIZDI. Ikisi de tek istekle cok veri
# ceker/uretir: arama bir "rehber cekme" aracina, rapor/PDF ucu ise bir
# kaynak tuketme aracina donusebilir. Sinir KIMLIGE baglidir (jeton `sub`):
# IP'ye guvenilmez (bkz. modul basligi).

ISTEK_ASILDI = APIError(429, "rate_limited", "cok_fazla_istek_genel")


def kullanici_siniri(kapsam: str, sinir: int, pencere_sn: int):
    """FastAPI bagimliligi: `kapsam` icin kullanici basina `sinir`/`pencere_sn`.

    Uretilen islev `hiz_siniri_kapsami` ozniteligini tasir — uc guvenlik
    kilidi (`test_p247_uc_guvenlik.py`) hangi ucun sinirli oldugunu
    KODDAN okur, beyandan degil.
    """
    from .deps import get_access_claims

    # `Request` MODUL duzeyinde ice aktarildi: bu dosya `from __future__
    # import annotations` kullaniyor ve FastAPI tip ipucunu fonksiyonun
    # GLOBAL'lerinde cozer — yerel import edilen `Request` cozulemeyince
    # parametre SORGU parametresi sanildi (422 "query.request").
    async def _dep(request: Request, claims=Depends(get_access_claims)) -> None:
        redis = getattr(request.app.state, "redis", None)
        if redis is None:
            return
        anahtar = f"hiz:k:{kapsam}:{claims.get('sub')}"
        try:
            sayi = await redis.incr(anahtar)
            if sayi == 1:
                await redis.expire(anahtar, pencere_sn)
        except Exception as e:  # pragma: no cover - fail-open
            _log.warning("kullanici hiz sayaci yazilamadi: %s", e)
            return
        if sayi > sinir:
            raise ISTEK_ASILDI

    _dep.hiz_siniri_kapsami = kapsam  # type: ignore[attr-defined]
    return _dep


#: Hazir kapsamlar — sayilar mesru kullanimin ~10 kati.
ARAMA_SINIRI = kullanici_siniri("arama", 120, 60)
DISA_AKTARIM_SINIRI = kullanici_siniri("disa_aktarim", 60, 60)
