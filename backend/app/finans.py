"""Finansal hareket CEKIRDEGI (P29) — saf fonksiyonlar, veritabani YOK.

Bakiye kurali, banka eslestirme puanlamasi ve virman dogrulamasi burada;
router yalnizca satirlari toplayip bu fonksiyonlara verir.
"""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass

#: `yon` -> bakiyeye etkisi. Tutar HER ZAMAN POZITIF saklanir; isaret
#: burada uygulanir (negatif tutar "iade" ile "eksi gider"i ayirt edilemez
#: kilardi).
ISARET = {"giris": 1, "cikis": -1}


def kasa_bakiye(acilis_kurus: int, hareketler: list[tuple[str, int]]) -> int:
    """Kasa bakiyesi = ACILIS + hareketlerin ISARETLI toplami.

    Bakiye SAKLANMAZ, TURETILIR: saklanan bir bakiye her yazma yolunda elle
    guncellenmek zorunda kalir ve bir yol unutuldugunda defterle bakiye
    sessizce ayrilir.
    """
    return acilis_kurus + sum(ISARET[yon] * tutar for yon, tutar in hareketler)


def _sadelestir(metin: str) -> str:
    """Ad eslestirmesi icin kanonik bicim: aksansiz, buyuk, tek bosluk.

    Turkce'ye ozgu tuzak: `İ`nin kucugu `i` DEGIL `i̇`dir ve `I`nin kucugu
    `ı`dir. Bu yuzden once BUYUK harfe cevirip aksan ayiklamak, "ŞAHİN" ile
    "Sahin"i esitler; ters sirada calisirsa esitlemez.
    """
    buyuk = metin.upper()
    ayrik = unicodedata.normalize("NFD", buyuk)
    sadece_harf = "".join(c for c in ayrik if not unicodedata.combining(c))
    # Turkce'de aksan ayiklamanin cozmedigi iki harf.
    sadece_harf = sadece_harf.replace("Ğ", "G").replace("Ş", "S")
    return re.sub(r"\s+", " ", sadece_harf).strip()


@dataclass(frozen=True)
class BankaSatiri:
    """Banka ekstresinden bir satir (istemci ayristirir, sunucu eslestirir)."""

    satir_no: int
    aciklama: str
    tutar_kurus: int


@dataclass(frozen=True)
class BorcAdayi:
    """Eslestirme adayi: acik borcu olan kisi."""

    user_id: str
    ad: str
    kalan_kurus: int
    assessment_id: str | None = None


@dataclass(frozen=True)
class EslestirmeOnerisi:
    satir_no: int
    user_id: str | None
    assessment_id: str | None
    #: 0..100 — 100 "kesin", 0 "oneri yok".
    guven: int
    neden: str


#: Bu esigin ALTINDAKI oneriler DONULMEZ. Zayif bir oneri, kullaniciyi
#: "sistem buldu" diye yanlis kisiye tahsilat yazmaya iter — bos birakmak
#: yanlis eslestirmekten iyidir.
ESIK = 40


def banka_eslestir(
    satirlar: list[BankaSatiri], adaylar: list[BorcAdayi]
) -> list[EslestirmeOnerisi]:
    """Banka satirlarini acik borclara ESLESTIRME ONERISI uret.

    ONERI'dir, otomatik tahsilat DEGILDIR: banka aciklamasi serbest metindir
    ve yanlis eslesen bir satir, baskasinin borcunu kapatip gercek borclunun
    borcunu acik birakirdi. Karar kullanicinin (tek tikla onaylar).

    PUANLAMA (toplanabilir, en fazla 100):
      * ad aciklamada TAM gecerse         +60
      * adin SOYADI gecerse (tek parca)   +30
      * tutar kalan borca TAM esitse      +40
      * tutar kalanin ALTINDAysa           +10 (kismi odeme olabilir)
    Ayni satir icin en yuksek puanli aday secilir; berabere kalirsa ONERI
    URETILMEZ (iki kisi ayni tutari yatirdiysa secmek kullanicinin isidir).
    """
    oneriler: list[EslestirmeOnerisi] = []
    for satir in satirlar:
        aciklama = _sadelestir(satir.aciklama)
        puanli: list[tuple[int, BorcAdayi, str]] = []
        for aday in adaylar:
            ad = _sadelestir(aday.ad)
            puan = 0
            nedenler = []
            if ad and ad in aciklama:
                puan += 60
                nedenler.append("ad")
            else:
                parcalar = [p for p in ad.split(" ") if len(p) > 2]
                if parcalar and parcalar[-1] in aciklama:
                    puan += 30
                    nedenler.append("soyad")
            if satir.tutar_kurus == aday.kalan_kurus:
                puan += 40
                nedenler.append("tutar_tam")
            elif satir.tutar_kurus < aday.kalan_kurus:
                puan += 10
                nedenler.append("tutar_kismi")
            if puan >= ESIK:
                puanli.append((puan, aday, "+".join(nedenler)))

        if not puanli:
            oneriler.append(
                EslestirmeOnerisi(satir.satir_no, None, None, 0, "eslesme_yok")
            )
            continue
        puanli.sort(key=lambda x: -x[0])
        # BERABERLIK: iki kisi ayni tutari yatirdiysa secmek KULLANICININ isi.
        if len(puanli) > 1 and puanli[0][0] == puanli[1][0]:
            oneriler.append(
                EslestirmeOnerisi(satir.satir_no, None, None, 0, "belirsiz")
            )
            continue
        puan, aday, neden = puanli[0]
        oneriler.append(
            EslestirmeOnerisi(
                satir.satir_no, aday.user_id, aday.assessment_id,
                min(puan, 100), neden,
            )
        )
    return oneriler
