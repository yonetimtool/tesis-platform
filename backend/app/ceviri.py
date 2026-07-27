"""Icerik cevirisi — SAF cekirdek (DB/HTTP bilmez, testte dogrudan cagrilir).

Kapsam: yayin icerigi (duyuru / site kurali / etkinlik) yonetimin yazdigi dilde
saklanir, YAZMA aninda 6 hedef dile cevrilir, OKUMA Accept-Language ile servis
edilir. Orijinal metin HER ZAMAN korunur (bkz. [ORIJINAL] notu).

Bu modulde YALNIZ karar mantigi vardir:
  * desteklenen dil kumesi + entity kaydi (registry),
  * kaynak metin ozeti (hash) — elle duzeltme kuralinin anahtari,
  * Accept-Language ayristirma/eslestirme + geri-dusme zinciri,
  * yerelestirme karari (hangi metin, hangi durum bayraklariyla).

Saglayici cagrisi `translate.py`, DB yazimi `ceviri_service.py` (worker, sync)
ve `ceviri_api.py` (istek yolu, async) modullerindedir.
"""
from __future__ import annotations

import hashlib
from collections.abc import Mapping, Sequence
from dataclasses import dataclass

# Mobil UI ile AYNI kume (tr varsayilan + 6). Genisletmek MIGRATION ister
# (ceviri tablolarindaki ck_*_dil CHECK kisiti).
DESTEKLENEN_DILLER: tuple[str, ...] = ("tr", "en", "ar", "ru", "de", "fr", "es")

# Kaynak dil varsayilani. Admin secimi sonraki tur; simdilik tr sabit.
VARSAYILAN_DIL = "tr"

# Ceviri durumu (DB'deki ceviri_durum enum'u ile birebir).
DURUM_HAZIR = "hazir"
DURUM_BEKLIYOR = "bekliyor"
DURUM_HATA = "hata"


@dataclass(frozen=True)
class CevrilebilirTip:
    """Cevrilebilir bir icerik tipinin sema kaydi.

    `alanlar`: CEVRILEN alanlar. Ceviriye girmeyenler bilincli olarak disarida
    (konum = yer adi, foto_key = gorsel, tarih/sira = veri) — bunlar cevrilmez.
    """

    ad: str            # kuyruk/istek sozlesmesindeki kimlik ("duyuru" vb.)
    kaynak_tablo: str  # "announcement"
    ceviri_tablo: str  # "announcement_ceviri"
    fk_kolon: str      # "announcement_id"
    alanlar: tuple[str, ...]


# Migration 0007'deki tablo ucluleri ile AYNI (tek dogruluk kaynagi: orada).
TIPLER: dict[str, CevrilebilirTip] = {
    "duyuru": CevrilebilirTip(
        ad="duyuru",
        kaynak_tablo="announcement",
        ceviri_tablo="announcement_ceviri",
        fk_kolon="announcement_id",
        alanlar=("baslik", "govde"),
    ),
    "site_kurali": CevrilebilirTip(
        ad="site_kurali",
        kaynak_tablo="site_kurali",
        ceviri_tablo="site_kurali_ceviri",
        fk_kolon="site_kurali_id",
        alanlar=("baslik", "icerik"),
    ),
    "etkinlik": CevrilebilirTip(
        ad="etkinlik",
        kaynak_tablo="etkinlik",
        ceviri_tablo="etkinlik_ceviri",
        fk_kolon="etkinlik_id",
        alanlar=("baslik", "aciklama"),
    ),
}


def tip(ad: str) -> CevrilebilirTip:
    """Kayittan tip getir; bilinmeyen ad ProgrammingError degil ValueError."""
    try:
        return TIPLER[ad]
    except KeyError:
        raise ValueError(f"bilinmeyen cevrilebilir tip: {ad}")


def hedef_diller(kaynak_dil: str) -> tuple[str, ...]:
    """Kaynak dil DISINDAKI desteklenen diller (6 dil)."""
    return tuple(d for d in DESTEKLENEN_DILLER if d != kaynak_dil)


# --------------------------------------------------------------------------- #
# Kaynak ozeti — elle duzeltme kuralinin anahtari
# --------------------------------------------------------------------------- #
def kaynak_hash(alanlar: Mapping[str, str | None]) -> str:
    """Kaynak metinlerin DETERMINISTIK ozeti (sha256, 32 hex).

    Anahtar sirasindan bagimsiz olmasi icin siralanir; alan ayirici olarak
    metinde bulunmayacak kontrol karakterleri kullanilir (yoksa "ab"+"c" ile
    "a"+"bc" ayni ozeti verirdi).
    """
    h = hashlib.sha256()
    for anahtar in sorted(alanlar):
        deger = alanlar[anahtar] or ""
        h.update(anahtar.encode("utf-8"))
        h.update(b"\x1f")
        h.update(deger.encode("utf-8"))
        h.update(b"\x1e")
    return h.hexdigest()[:32]


# --------------------------------------------------------------------------- #
# Accept-Language
# --------------------------------------------------------------------------- #
def accept_language_coz(header: str | None) -> list[str]:
    """"tr-TR,tr;q=0.9,en;q=0.8" -> ["tr", "en"] (q'ya gore azalan).

    * Bolge eki DUSURULUR (tr-TR -> tr): desteklenen kume dil bazlidir.
    * `*` (joker) ve q=0 atlanir; q yoksa 1.0 varsayilir (RFC 9110).
    * Bozuk parcalar sessizce atlanir — Accept-Language kullanici girdisidir,
      istegi 400 ile dusurmek dogru olmaz.
    """
    if not header:
        return []
    adaylar: list[tuple[float, int, str]] = []
    for sira, parca in enumerate(header.split(",")):
        parca = parca.strip()
        if not parca:
            continue
        bolumler = parca.split(";")
        etiket = bolumler[0].strip().lower()
        if not etiket or etiket == "*":
            continue
        q = 1.0
        for bolum in bolumler[1:]:
            bolum = bolum.strip()
            if bolum.startswith("q="):
                try:
                    q = float(bolum[2:])
                except ValueError:
                    q = 0.0
        if q <= 0:
            continue
        adaylar.append((q, sira, etiket.split("-")[0]))

    # q azalan, esitlikte header sirasi korunur (stabil).
    adaylar.sort(key=lambda t: (-t[0], t[1]))
    sonuc: list[str] = []
    for _q, _sira, dil in adaylar:
        if dil not in sonuc:
            sonuc.append(dil)
    return sonuc


def dil_sec(
    *,
    accept_language: str | None,
    kaynak_dil: str,
    istek_dil: str | None = None,
) -> str:
    """Servis edilecek dili sec — GERI-DUSME ZINCIRI.

    Sira: `?dil=` (acik istek, panel/dogrulama icin) -> Accept-Language'daki
    ilk DESTEKLENEN dil -> icerigin kaynak dili (orijinal).

    `?dil=orijinal` ozel degeri kaynak dili zorlar. Desteklenmeyen bir dil
    istenirse hata DEGIL geri-dusme uygulanir (icerik okunamaz kalmasin).
    """
    if istek_dil:
        istek = istek_dil.strip().lower()
        if istek in ("orijinal", "original"):
            return kaynak_dil
        if istek in DESTEKLENEN_DILLER:
            return istek
        # Desteklenmeyen acik istek: sessizce zincire devam (400 atmiyoruz).

    for dil in accept_language_coz(accept_language):
        if dil in DESTEKLENEN_DILLER:
            return dil
    return kaynak_dil


# --------------------------------------------------------------------------- #
# Yeniden ceviri plani — ELLE DUZELTME KURALI
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class CeviriSatiri:
    """Bir dildeki cevirinin karar icin gereken alanlari."""

    dil: str
    alanlar: Mapping[str, str]
    durum: str
    cevirildi_mi: bool
    elle_duzeltildi: bool
    kaynak_hash: str


def korunur_mu(satir: CeviriSatiri | None, yeni_hash: str) -> bool:
    """ELLE DUZELTME KURALI (tek cumle): elle duzeltilmis bir ceviri, YALNIZCA
    uretildigi kaynak metin DEGISMEDIYSE korunur.

    Gerekce: yonetici bir dildeki makine cevirisini duzeltmisse ve sonraki
    duzenleme ILGISIZ bir alani (foto, tarih, sira) degistirdiyse, duzeltme
    kaybolmamali. Ama kaynak METIN degistiyse duzeltme artik YANLIS bir metnin
    duzeltmesidir — korunursa sakin guncellenmemis icerik okur; bu yuzden
    gecersizdir ve yeniden cevrilir.
    """
    return (
        satir is not None
        and satir.elle_duzeltildi
        and satir.kaynak_hash == yeni_hash
    )


def cevrilecek_diller(
    *,
    mevcut: Mapping[str, CeviriSatiri],
    yeni_hash: str,
    hedefler: Sequence[str],
) -> tuple[str, ...]:
    """Ceviri gereken diller (idempotent yeniden kosum icin guvenli).

    Ceviri GEREKMEZ ise:
      * elle duzeltilmis + kaynak ayni ([korunur_mu]), ya da
      * zaten `hazir` + kaynak ayni (tekrar cevirmek bosa istek olurdu).
    Digerlerinde (satir yok / kaynak degismis / durum bekliyor|hata) cevrilir.
    """
    sonuc: list[str] = []
    for dil in hedefler:
        satir = mevcut.get(dil)
        if korunur_mu(satir, yeni_hash):
            continue
        if (
            satir is not None
            and satir.durum == DURUM_HAZIR
            and satir.kaynak_hash == yeni_hash
        ):
            continue
        sonuc.append(dil)
    return tuple(sonuc)


# --------------------------------------------------------------------------- #
# Okuma yolu — yerelestirme karari
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class Yerel:
    """Okuma yolunun sonucu: hangi metin + istemciye gidecek bayraklar."""

    alanlar: dict[str, str]  # servis edilecek (yerelestirilmis) metinler
    dil: str                 # metnin GERCEK dili (geri-dusme sonrasi)
    durum: str               # hazir | bekliyor | hata
    cevirildi_mi: bool       # metin MAKINE cevirisi mi?


def yerelestir(
    *,
    orijinal: Mapping[str, str],
    satir: CeviriSatiri | None,
    istenen_dil: str,
    kaynak_dil: str,
) -> Yerel:
    """Istenen dile gore servis edilecek metni ve durumu belirle.

    [ORIJINAL] Ceviri hazir DEGILSE (bekliyor/hata/satir yok) ORIJINAL metin
    servis edilir ve `durum` gercegi soyler — istemci "çeviri hazırlanıyor"
    gosterebilir ama ekran BOS KALMAZ.
    """
    temiz_orijinal = {a: (orijinal.get(a) or "") for a in orijinal}

    if istenen_dil == kaynak_dil:
        # Kaynak dil: ceviri yok, makine cevirisi degil.
        return Yerel(
            alanlar=temiz_orijinal,
            dil=kaynak_dil,
            durum=DURUM_HAZIR,
            cevirildi_mi=False,
        )

    if satir is not None and satir.durum == DURUM_HAZIR:
        # Eksik alan varsa orijinaliyle tamamlanir (yarim ceviri servis etmeyiz).
        alanlar = {
            a: (satir.alanlar.get(a) or temiz_orijinal.get(a, ""))
            for a in temiz_orijinal
        }
        return Yerel(
            alanlar=alanlar,
            dil=satir.dil,
            durum=DURUM_HAZIR,
            # Elle duzeltilen ceviri artik makine cikti degildir.
            cevirildi_mi=satir.cevirildi_mi and not satir.elle_duzeltildi,
        )

    # Hazir degil: orijinal + gercek durum. Satir yoksa "bekliyor" (kuyruga
    # girmis ya da girecek) — istemci icin anlami aynidir.
    return Yerel(
        alanlar=temiz_orijinal,
        dil=kaynak_dil,
        durum=satir.durum if satir is not None else DURUM_BEKLIYOR,
        cevirildi_mi=False,
    )
