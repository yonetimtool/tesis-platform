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
from decimal import ROUND_DOWN, ROUND_HALF_UP, Decimal

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


def oransal_dagit(
    toplam_kurus: int, agirliklar: list[Decimal | float | int | None]
) -> list[int | None]:
    """Tutari AGIRLIGA gore dagit — KURUS KAYBI OLMADAN (P192 §3.3).

    Arsa payi (KMK md. 20) ve metrekare dagitimlarinin ORTAK cekirdegi:
    ikisi de "toplami agirliklara oranla bol" demektir; iki ayri fonksiyon
    yazmak ayni yuvarlama kuralini iki yerde tutmak olurdu.

    AGIRLIGI OLMAYAN (`None`) ya da SIFIR/NEGATIF olan daire `None` alir ve
    ATLANIR — sessizce sifir borclandirmak, yonetimin fark etmedigi eksik
    tahakkuk uretirdi (`tipe_gore_dagit` ile ayni ilke).

    YUVARLAMA: EN BUYUK KALAN yontemi. Once taban paylar (asagi yuvarlama)
    verilir, artan kurus en buyuk kesirli kalana sahip dairelere BIRER BIRER
    dagitilir. Boylece dagitilan toplam HER ZAMAN girdiye esittir; her
    payi tek tek yuvarlamak toplamda kurusler kaybettirirdi.

    Hesap DECIMAL: float ile 1/3 payi 0.3333333333333333 olur ve buyuk
    tutarlarda kurus kayar. Para hesabinda float YOK (proje kurali).
    """
    temiz: list[Decimal | None] = []
    for a in agirliklar:
        if a is None:
            temiz.append(None)
            continue
        d = Decimal(str(a))
        temiz.append(d if d > 0 else None)

    toplam_agirlik = sum((d for d in temiz if d is not None), Decimal(0))
    if toplam_agirlik <= 0:
        return [None] * len(temiz)

    paylar: list[int | None] = [None] * len(temiz)
    kalanlar: list[tuple[Decimal, int]] = []
    dagitilan = 0
    for i, d in enumerate(temiz):
        if d is None:
            continue
        ham = Decimal(toplam_kurus) * d / toplam_agirlik
        taban = int(ham.to_integral_value(rounding=ROUND_DOWN))
        paylar[i] = taban
        dagitilan += taban
        kalanlar.append((ham - taban, i))

    # Artan kurus: en buyuk kesirli kalandan basla. Beraberlikte KUCUK
    # INDEKS once — sonuc deterministik olmali, yoksa ayni girdi iki farkli
    # dagitim uretirdi.
    kalanlar.sort(key=lambda t: (-t[0], t[1]))
    artan = toplam_kurus - dagitilan
    for _, i in kalanlar[:artan]:
        paylar[i] = (paylar[i] or 0) + 1
    return paylar


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
    # (P192 §6.4) ARA HESAP DA DECIMAL. Once `fark` float olarak
    # hesaplaniyordu: `ana - sum(bolumler)` ve ardindan `* yuzde / 100.0`.
    # Ikili gosterimde 12.3 - 12.0 = 0.2999999999999989 gibi degerler cikar
    # ve birim fiyatla carpilinca kurus kayardi. Para hesabinda float YOK.
    kendi = [
        int(Decimal(str(t)) * birim_fiyat_kurus) for t in bolum_tuketimleri
    ]
    fark = Decimal(str(ana_tuketim)) - sum(
        (Decimal(str(t)) for t in bolum_tuketimleri), Decimal(0)
    )
    if fark < 0:
        fark = Decimal(0)
    if ortak_alan_yuzde is not None:
        fark = fark * Decimal(str(ortak_alan_yuzde)) / Decimal(100)
    # Yuvarlama KURALI degismedi (asagi kesme, `kendi` ile ayni); degisen
    # tek sey ara degerin ikili float yerine Decimal olmasi.
    ortak_kurus = int(fark * birim_fiyat_kurus)
    paylar = esit_dagit(ortak_kurus, len(bolum_tuketimleri))
    return [k + p for k, p in zip(kendi, paylar)], ortak_kurus
