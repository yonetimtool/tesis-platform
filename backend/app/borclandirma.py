"""Borclandirma CEKIRDEGI (P28) — saf fonksiyonlar, veritabani YOK.

Buradaki her sey girdi->cikti bir hesaptir; testler bunlari veritabanina
dokunmadan surer ve router yalnizca "kimi/neyi" toplayip bu fonksiyonlara
verir. Hesabin router'a gomulmesi, ayni kurali toplu/tekil/sayac yollarinda
UC KEZ yazmak demekti.
"""
from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

#: `unit_resident.rol_tipi` degerleri (P23).
MALIK = "malik"
KIRACI = "kiraci"


@dataclass(frozen=True)
class Bag:
    """Bir dairenin AKTIF sakin bagi (P23 verisinden)."""

    user_id: str
    rol_tipi: str | None


def hedef_sec(baglar: list[Bag], kural: str) -> str | None:
    """Borcun yazilacagi kisiyi sec (P28 hedefleme kurali).

    `kiraci_oncelikli` — kiraci varsa ONA, yoksa malike (aidat, faturalar:
    kullanan oder).
    `malik`            — her zaman malike (yatirim, demirbas: mulk sahibi
    oder; kiraci tasinsa da yukumluluk malikte kalir).

    HICBIRI BULUNAMAZSA `None` DONER ve borc DAIREYE yazilir. Uydurma bir
    kisi secmek (orn. "ilk bag") yanlis kisiyi borclandirirdi; daireye
    yazmak ise mevcut davranistir ve tahsilat yine daire uzerinden yapilir.

    ROL_TIPI BOS olan baglar MALIK SAYILMAZ: P23'te tip opsiyoneldir ve
    "bilinmiyor"u malik saymak, yatirim giderini yanlis kisiye yazardi.
    Boyle bir bag yalnizca `kiraci_oncelikli` kuralinin SON CARESIDIR.
    """
    malikler = [b for b in baglar if b.rol_tipi == MALIK]
    kiracilar = [b for b in baglar if b.rol_tipi == KIRACI]
    belirsiz = [b for b in baglar if b.rol_tipi not in (MALIK, KIRACI)]

    if kural == "malik":
        return malikler[0].user_id if malikler else None

    # kiraci_oncelikli
    for aday in (kiracilar, malikler, belirsiz):
        if aday:
            return aday[0].user_id
    return None


def _ay_farki(baslangic: date, bitis: date) -> int:
    """Tam gecen AY sayisi (gun bazli degil).

    Gecikme tazminati AYLIK bir orandir; 45 gunluk gecikme "1 ay" degil
    "1 tam ay + 15 gun"dur ve mevzuatta kismi ay ORANTILANMAZ, tam ay
    sayilir. Gun bazli hesap her gun degisen bir borc uretirdi ve
    kullaniciya gosterilen tutar bir sonraki gun tutmazdi.
    """
    if bitis <= baslangic:
        return 0
    ay = (bitis.year - baslangic.year) * 12 + (bitis.month - baslangic.month)
    # Ayin gunu henuz gelmediyse o ay TAMAMLANMAMISTIR.
    son_gun = calendar.monthrange(bitis.year, bitis.month)[1]
    esdeger_gun = min(baslangic.day, son_gun)
    if bitis.day < esdeger_gun:
        ay -= 1
    return max(ay, 0)


def gecikme_kurus(
    tutar_kurus: int,
    son_odeme_tarihi: date | None,
    bugun: date,
    aylik_yuzde: Decimal | float | int,
    *,
    uygula: bool = True,
) -> int:
    """Gecikme tazminati (kurus) — BASIT faiz, tam ay uzerinden.

    BILESIK DEGIL BASIT: bilesik faiz aylik oranin ustune ay sayisi kadar
    us alir ve uzun gecikmelerde ana paranin katlarina cikar; site
    yonetiminde uygulanan kural aylik sabit orandir.

    `son_odeme_tarihi` YOKSA gecikme YOKTUR (vade belirlenmemis bir borc
    gecikmis sayilamaz). `uygula=False` olan kalemler (orn. tek seferlik
    duzeltmeler) hep 0 doner.
    """
    if not uygula or son_odeme_tarihi is None:
        return 0
    oran = Decimal(str(aylik_yuzde))
    if oran <= 0:
        return 0
    ay = _ay_farki(son_odeme_tarihi, bugun)
    if ay <= 0:
        return 0
    ham = Decimal(tutar_kurus) * oran / Decimal(100) * Decimal(ay)
    # KURUSA yuvarlama: tahsilatta kurus altinda bakiye kalmasin.
    return int(ham.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def esit_dagit(toplam_kurus: int, adet: int) -> list[int]:
    """Tutari `adet` daireye ESIT dagit — KURUS KAYBI OLMADAN.

    `toplam // adet` ile bolup gecmek, 100,01 TL'yi 3 daireye bolerken
    1 kurus BUHARLASTIRIRDI. Kalan kurus ilk dairelere birer birer
    dagitilir; toplam HER ZAMAN girdiye esittir (testle kilitli).
    """
    if adet <= 0:
        return []
    taban, kalan = divmod(toplam_kurus, adet)
    return [taban + (1 if i < kalan else 0) for i in range(adet)]


def tipe_gore_dagit(
    varsayilan_kuruslar: list[int | None], yedek_kurus: int | None
) -> list[int | None]:
    """Her daireye KENDI tipinin varsayilan aidatini ver (P26).

    Tipi olmayan / tipinde tutar tanimsiz olan daire icin `yedek_kurus`
    kullanilir; o da yoksa `None` doner ve o daire ATLANIR — sessizce 0
    borclandirmak, yonetimin fark etmedigi eksik tahakkuk uretirdi.
    """
    return [
        v if v is not None else yedek_kurus for v in varsayilan_kuruslar
    ]


def sayac_tuketim_dagitimi(
    ana_tuketim: float,
    bolum_tuketimleri: list[float],
    birim_fiyat_kurus: int,
    ortak_alan_yuzde: float | None,
) -> tuple[list[int], int]:
    """Sayac okumasindan daire borclarini uret (P28 sihirbaz 4. adim).

    Doner: (daire basina borc kurus, ortak alan payi kurus toplami).

    ORTAK ALAN: ana sayac ile daire sayaclarinin TOPLAMI arasindaki fark
    ortak tuketimdir (kacak, ortak alan, olcum farki). `ortak_alan_yuzde`
    verilmisse ortak tuketimin O YUZDESI dairelere esit dagitilir; verilmemis
    ise FARKIN TAMAMI dagitilir. Yuzdeyi 0 vermek "ortak alani dagitma"
    demektir ve bu bilincli bir secimdir.

    NEGATIF FARK (daire toplami anadan buyuk — olcum hatasi) SIFIRLANIR:
    dairelere NEGATIF borc yazmak alacak uretirdi.
    """
    kendi = [
        int(Decimal(str(t)) * birim_fiyat_kurus) for t in bolum_tuketimleri
    ]
    fark = ana_tuketim - sum(bolum_tuketimleri)
    if fark < 0:
        fark = 0.0
    if ortak_alan_yuzde is not None:
        fark = fark * float(ortak_alan_yuzde) / 100.0
    ortak_kurus = int(Decimal(str(fark)) * birim_fiyat_kurus)
    paylar = esit_dagit(ortak_kurus, len(bolum_tuketimleri))
    return [k + p for k, p in zip(kendi, paylar)], ortak_kurus
