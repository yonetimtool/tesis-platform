"""Tur gecikme alarmi CEKIRDEGI (P34) — saf zaman hesabi, veritabani YOK.

"Kacirildi" ile "gecikti" AYNI SEY DEGILDIR: kacirildi pencere BITTIKTEN
sonra sabittir ve yapilacak bir sey kalmamistir; gecikti pencere ACIKKEN
olur ve tur HALA KURTARILABILIR. Bu yuzden ayri bir alarm ve ayri bir metin.

TEKRARLI ALARM, ARTAN ARALIKLA: tek bir bildirim telefonun sessizde
oldugu bir anda kaybolur; sabit araliklarla tekrar etmek ise dakikada bir
titreyen bir cihaz uretir ve alarm ANLAMINI kaybeder. Araliklar KATLANIR:
tolerans 10 dk icin 10 → 30 → 70. dakikalarda uc alarm.
"""
from __future__ import annotations

from datetime import datetime, timedelta


def alarm_gecikmeleri(tolerans_dk: int, tekrar: int) -> list[timedelta]:
    """Pencere BASLANGICINDAN itibaren alarm anlari (artan araliklarla).

    k'inci alarm `tolerans * (2^(k+1) - 1)` dakikada calisir: aralar
    tolerans, 2×tolerans, 4×tolerans... seklinde KATLANIR.
    `tekrar <= 0` => alarm KAPALI (gecerli bir tenant tercihi).
    """
    if tolerans_dk <= 0 or tekrar <= 0:
        return []
    return [timedelta(minutes=tolerans_dk * (2 ** (k + 1) - 1)) for k in range(tekrar)]


def vadesi_gelen_adim(
    *,
    pencere_baslangic: datetime,
    pencere_bitis: datetime,
    simdi: datetime,
    tolerans_dk: int,
    tekrar: int,
) -> int | None:
    """Su an gonderilmesi gereken alarmin sira numarasi (0 tabanli) ya da None.

    EN SON vadesi gelen adim doner, hepsi degil: scheduler bir tur
    duraksadiysa (bakim, dagitim) biriken alarmlarin TOPTAN gonderilmesi,
    gorevliye ayni saniyede uc bildirim atmak olurdu. Gecmis adimlar
    cagiranin dedup anahtariyla zaten atlanir.

    Pencere BITMISSE None: bitmis pencere artik "gecikmis" degil
    KACIRILMIStir (o ayri alarmin isi) — ikisini birden gondermek ayni
    olayi iki kez bildirmek olurdu.
    """
    if simdi >= pencere_bitis:
        return None
    vadeler = alarm_gecikmeleri(tolerans_dk, tekrar)
    adim: int | None = None
    for k, gecikme in enumerate(vadeler):
        an = pencere_baslangic + gecikme
        if an <= simdi < pencere_bitis:
            adim = k
    return adim


def gecen_dakika(pencere_baslangic: datetime, simdi: datetime) -> int:
    """Bildirim metnindeki "kac dakikadir okutma yok" degeri (asagi yuvarlar)."""
    return max(0, int((simdi - pencere_baslangic).total_seconds() // 60))
