"""(P250 §1) Kisi adi: AD + SOYAD, Turkce harf kuraliyla bicim.

KURAL
  * Ad: her kelimenin bas harfi buyuk, gerisi kucuk ("mehmet ali" ->
    "Mehmet Ali"). Tire de kelime ayirir ("ayse-nur" -> "Ayse-Nur").
  * Soyad: tamami buyuk ("yilmaz" -> "YILMAZ").
  * Bosluklar: bas/son kirpilir, ic bosluklar teke iner.

TURKCE HARF KURALI SART: i<->I degil, i<->İ ve ı<->I. Python'un
`str.upper()`i "i"yi "I" yapar ("ilker" -> "ILKER", yanlis) ve
`"İ".lower()` birlesik noktali "i̇" uretir (iki kod noktasi). Bu yuzden
dort harf ONCE elle cevrilir, sonra varsayilan donusum uygulanir.

SAKLAMA KARARI (ayrinti: docs/P250-kararlar.md §1)
  `app_user.ad` TAM GORUNEN AD olarak kalir ("Mehmet Ali YILMAZ"); yeni
  `app_user.soyad` sutunu soyadi AYRICA tutar. Otuzdan fazla okuyucu
  (liste, vardiya, panik, arama...) `ad`i "kisinin adi" diye gosteriyor;
  `ad`i yalniz ilk ada cevirmek her birini degistirmeyi gerektirirdi ve
  eski kayitlarda soyad zaten ayri degil.
"""
from __future__ import annotations

import re

_BOSLUK = re.compile(r"\s+")
# Kelime siniri: bosluk ve tire. Kesme isareti ("O'Neil") bilerek YOK:
# Turkcede kesme ekten once gelir ("Ali'nin"), sonrasi buyutulmez.
_KELIME = re.compile(r"([\s-]+)")


def tr_buyuk(s: str) -> str:
    return s.replace("i", "İ").replace("ı", "I").upper()


def tr_kucuk(s: str) -> str:
    return s.replace("I", "ı").replace("İ", "i").lower()


def _sadelestir(s: str) -> str:
    return _BOSLUK.sub(" ", s).strip()


def ad_bicimle(s: str) -> str:
    """"mehmet ALİ" -> "Mehmet Ali", "ışıl" -> "Işıl", "ilker" -> "İlker"."""
    parcalar = _KELIME.split(_sadelestir(s))
    return "".join(
        p if _KELIME.fullmatch(p) or not p else tr_buyuk(p[0]) + tr_kucuk(p[1:])
        for p in parcalar
    )


def soyad_bicimle(s: str) -> str:
    """"öztürk" -> "ÖZTÜRK", "yılmaz" -> "YILMAZ"."""
    return tr_buyuk(_sadelestir(s))


def tam_ad(ad: str, soyad: str | None) -> str:
    """Saklanan gorunen ad. Soyad yoksa (eski istemci) yalniz ad."""
    return f"{ad} {soyad}" if soyad else ad


def ayir(tam: str, soyad: str | None) -> tuple[str, str | None]:
    """Saklanan `ad` + `soyad`tan (ilk ad, soyad). DUZENLEME ON-DOLUMU icin.

    Soyad sutunu bos (P250 oncesi kayit) ise SON KELIME soyad sayilir:
    Turk adlarinin buyuk cogunlugu "Ad [Ad] Soyad". Bu yalnizca formun
    on-dolumudur; kayit DEGISMEZ, kullanici formu gorup kaydedince
    yeni kural uygulanir. Tek kelimelik eski adda soyad bos gelir ve
    zorunlu alan kullaniciya doldurtur.
    """
    if soyad and tam.endswith(" " + soyad):
        return tam[: -len(soyad) - 1], soyad
    parca = tam.rsplit(" ", 1)
    if len(parca) == 2:
        return parca[0], parca[1]
    return tam, None


def guncelle(obj, data: dict) -> None:
    """PATCH govdesindeki `ad`/`soyad`i `obj`ye uygular ve `data`dan CIKARIR.

    `data`: `model_dump(exclude_unset=True)` — sema bicimi zaten uyguladi.
      * ad + soyad   -> ikisi de yeni,
      * yalniz soyad -> ilk ad mevcut kayittan (`ayir`),
      * yalniz ad    -> ESKI ISTEMCI tam adi gonderdi: soyad bilinmez,
                        sutun bosaltilir ki `ad` ile celismesin.
    """
    ad = data.pop("ad", None)
    soyad_var = "soyad" in data
    soyad = data.pop("soyad", None)
    if ad is None and not soyad_var:
        return
    mevcut_ilk, _ = ayir(obj.ad, obj.soyad)
    ilk = ad if ad is not None else mevcut_ilk
    if soyad_var:
        yeni_soyad = soyad
    elif ad is not None:
        yeni_soyad = None
    else:  # pragma: no cover - yukarida dondu
        yeni_soyad = obj.soyad
    obj.ad = tam_ad(ilk, yeni_soyad)
    obj.soyad = yeni_soyad
