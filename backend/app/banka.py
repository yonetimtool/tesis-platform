"""(P191 §4) BANKA EŞLEŞTİRME ÇEKİRDEĞİ — saf fonksiyonlar, veritabanı YOK.

===========================================================================
NEDEN AYRI BİR ÇEKİRDEK
===========================================================================
Eşleştirme kararı paranın kime yazılacağını belirler; yanlış bir karar
BAŞKASININ borcunu kapatır ve gerçek borçlunun borcunu açık bırakır —
sonradan fark edilmesi zor, düzeltmesi (ters kayıt + yeniden eşleştirme)
pahalı bir hatadır. Bu yüzden karar mantığı veritabanından AYRI ve
tek tek senaryo olarak test edilebilir durur (`test_p191_banka_motor.py`).

`finans.banka_eslestir` (P29/P30) bir ÖNERİ üreticisiydi ve tek satır ->
tek kişi eşlemesi yapıyordu. Bu modül onun yerini almaz, ÜSTÜNE koyar:
burada bir hareket BİRDEN ÇOK borcu kapatabilir (FIFO), fazla ödeme
alacağa yazılır ve her kararın bir GÜVEN PUANI + GEREKÇESİ vardır.

===========================================================================
EŞLEŞTİRME ÖNCELİĞİ (kullanıcının koyduğu sıra)
===========================================================================
  1. Ödeme referansı (`app_user.odeme_kodu`) — açıklamada geçiyorsa KESİN.
  2. Gönderen IBAN — daha önce ONAYLANMIŞ bir eşleşmede görülmüşse.
  3. Gönderen adı + tutar + açık borç.
Eşiğin altı -> MANUEL_INCELEME. Eşit puanlı iki aday -> MANUEL_INCELEME
(seçmek insanın işidir).

===========================================================================
ÇELİŞKİ KURALI — bu tek satır çok şey söyler
===========================================================================
Referans A kişisini, IBAN geçmişi B kişisini gösteriyorsa sonuç
OTOMATİK DEĞİL, MANUEL'dir. "Referans her şeyi ezer" demek, kirasını
kayınbiraderinin hesabından gönderen ya da eski bir referansı kopyalayan
kullanıcıda sessizce yanlış kişiye yazmak olurdu.
"""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field

from .odeme_kodu import ayikla as _kod_ayikla

# --------------------------------------------------------------------------- #
# GÜVEN PUANI EŞİKLERİ — değiştirilebilir, docs/P191-kararlar.md §4'te yazılı.
# --------------------------------------------------------------------------- #
#: Bu puanın ALTI otomatik uygulanmaz; yöneticinin önüne düşer.
ESIK_OTOMATIK = 80
#: Bu puanın altındaki adaylar aday bile sayılmaz (gürültü).
ESIK_ADAY = 40

PUAN_ODEME_KODU = 100
PUAN_IBAN = 85
PUAN_AD_TAM = 60
PUAN_AD_SOYAD = 30
PUAN_TUTAR_TAM = 25
PUAN_TUTAR_ALTINDA = 10


def sadelestir(metin: str) -> str:
    """Ad karşılaştırması için kanonik biçim: aksansız, BÜYÜK, tek boşluk.

    Türkçe tuzağı (P29'dan devralındı): `İ`nin küçüğü `i` DEĞİL `i̇`dir.
    Bu yüzden önce BÜYÜK harfe çevirip aksan ayıklanır; ters sırada
    "ŞAHİN" ile "Sahin" eşleşmez.
    """
    if not metin:
        return ""
    buyuk = metin.upper()
    ayrik = unicodedata.normalize("NFD", buyuk)
    harfler = "".join(c for c in ayrik if not unicodedata.combining(c))
    harfler = harfler.replace("Ğ", "G").replace("Ş", "S")
    return re.sub(r"\s+", " ", harfler).strip()


def iban_normalize(iban: str | None) -> str | None:
    """Boşluk/çizgi atılmış, BÜYÜK IBAN. Geçersizse None.

    Banka ekstreleri IBAN'ı `TR12 3456 ...` diye boşluklu yazar; iki
    biçimi ayrı saymak "aynı IBAN" sorusunu sessizce yanlış cevaplardı.
    """
    if not iban:
        return None
    sade = re.sub(r"[\s\-]", "", iban).upper()
    return sade if re.fullmatch(r"[A-Z]{2}[0-9A-Z]{13,32}", sade) else None


def iban_maskele(iban: str | None) -> str | None:
    """Okuma yolunun gördüğü biçim: `TR** **** 4567`.

    Tam IBAN gereksiz yerde tutulmaz/gösterilmez (güvenlik maddesi).
    """
    sade = iban_normalize(iban)
    if not sade:
        return None
    return f"{sade[:2]}{'*' * max(0, len(sade) - 6)}{sade[-4:]}"


@dataclass(frozen=True)
class Hareket:
    """Eşleştirilecek banka hareketi (yalnız motorun ihtiyacı olan alanlar)."""

    id: str
    tutar_kurus: int
    aciklama: str = ""
    karsi_ad: str | None = None
    karsi_iban: str | None = None
    yon: str = "giris"


@dataclass(frozen=True)
class Borc:
    """Açık bir tahakkuk (kalan tutarıyla)."""

    assessment_id: str
    unit_id: str
    donem: str
    kalan_kurus: int
    #: Vade — FIFO bu alana göre sıralar (yoksa `donem` kullanılır).
    vade: str | None = None


@dataclass(frozen=True)
class Aday:
    """Ödemeyi yapmış OLABİLECEK kişi ve bilinen açık borçları."""

    user_id: str
    ad: str
    unit_id: str | None = None
    odeme_kodu: str | None = None
    #: Bu kişiyle ONAYLANMIŞ geçmiş eşleşmelerde görülen IBAN'lar.
    bilinen_ibanlar: tuple[str, ...] = ()
    borclar: tuple[Borc, ...] = ()

    @property
    def acik_toplam(self) -> int:
        return sum(b.kalan_kurus for b in self.borclar)


@dataclass(frozen=True)
class Karar:
    """Motorun bir hareket için verdiği karar.

    `dagilim`: (assessment_id | None, tutar) — None fazla ödemenin
    daire alacağına yazılan payıdır.
    """

    hareket_id: str
    user_id: str | None
    unit_id: str | None
    match_type: str
    confidence: int
    #: `otomatik` | `manuel_inceleme`
    sonuc: str
    neden: str
    dagilim: tuple[tuple[str | None, int], ...] = field(default=())


def _ad_puani(hareket: Hareket, aday: Aday) -> tuple[int, str]:
    """Ad eşleşmesi — açıklamada VE gönderen adında aranır."""
    metin = f"{sadelestir(hareket.aciklama)} {sadelestir(hareket.karsi_ad or '')}"
    ad = sadelestir(aday.ad)
    if not ad:
        return 0, ""
    if ad and ad in metin:
        return PUAN_AD_TAM, "ad_tam"
    parcalar = [p for p in ad.split(" ") if len(p) > 2]
    if parcalar and parcalar[-1] in metin:
        return PUAN_AD_SOYAD, "soyad"
    return 0, ""


def _tutar_puani(hareket: Hareket, aday: Aday) -> tuple[int, str]:
    if not aday.borclar:
        return 0, ""
    if any(b.kalan_kurus == hareket.tutar_kurus for b in aday.borclar):
        return PUAN_TUTAR_TAM, "tutar_tam"
    if hareket.tutar_kurus == aday.acik_toplam:
        return PUAN_TUTAR_TAM, "tutar_toplam"
    if hareket.tutar_kurus < aday.acik_toplam:
        return PUAN_TUTAR_ALTINDA, "tutar_altinda"
    return 0, ""


def fifo_dagit(tutar_kurus: int, borclar: tuple[Borc, ...]) -> tuple[tuple[str | None, int], ...]:
    """Tutarı EN ESKİ vadeden başlayarak dağıtır; artan pay `None`a yazılır.

    * KISMİ ÖDEME: en eski borçtan başlanır (varsayılan kural). Alternatif
      "en yeni önce" ya da "kullanıcı seçer" — ikisi de gecikme faizini
      büyütürdü.
    * FAZLA ÖDEME: kalan `None` anahtarıyla döner ve çağıran onu DAİRE
      ALACAĞINA yazar (bir sonraki borçtan mahsup edilir).
    """
    sirali = sorted(borclar, key=lambda b: (b.vade or b.donem, b.assessment_id))
    kalan = tutar_kurus
    dagilim: list[tuple[str | None, int]] = []
    for borc in sirali:
        if kalan <= 0:
            break
        pay = min(kalan, borc.kalan_kurus)
        if pay > 0:
            dagilim.append((borc.assessment_id, pay))
            kalan -= pay
    if kalan > 0:
        dagilim.append((None, kalan))
    return tuple(dagilim)


def eslestir(hareket: Hareket, adaylar: list[Aday]) -> Karar:
    """Tek bir hareket için karar üretir. ASLA istisna atmaz.

    Sonuç `otomatik` ise çağıran uygulayabilir; `manuel_inceleme` ise
    yöneticinin önüne düşer (eşleşmeyenler ekranı).
    """
    if hareket.yon != "giris":
        # Çıkış hareketi bir tahsilat DEĞİLDİR: banka masrafı, iade ya da
        # ödeme olabilir. Otomatik gider yazmak yasak (kullanıcı kuralı).
        return Karar(hareket.id, None, None, "manuel", 0, "manuel_inceleme", "cikis_hareketi")

    kod = _kod_ayikla(hareket.aciklama or "")
    iban = iban_normalize(hareket.karsi_iban)
    kod_adayi = next((a for a in adaylar if a.odeme_kodu and a.odeme_kodu == kod), None)
    iban_adayi = (
        next((a for a in adaylar if iban and iban in a.bilinen_ibanlar), None) if iban else None
    )

    # (1) ÖDEME REFERANSI
    if kod_adayi is not None:
        # ÇELİŞKİ: referans A'yı, IBAN geçmişi B'yi gösteriyor -> MANUEL.
        if iban_adayi is not None and iban_adayi.user_id != kod_adayi.user_id:
            return Karar(
                hareket.id, None, None, "odeme_kodu", 50, "manuel_inceleme",
                "referans_iban_celiskisi",
            )
        return Karar(
            hareket.id, kod_adayi.user_id, kod_adayi.unit_id, "odeme_kodu",
            PUAN_ODEME_KODU, "otomatik", "odeme_kodu",
            fifo_dagit(hareket.tutar_kurus, kod_adayi.borclar),
        )

    # (2) GÖNDEREN IBAN (geçmişte onaylanmış eşleşme)
    if iban_adayi is not None:
        # Aynı IBAN birden çok kişiye bağlıysa (ortak hesap) seçim insanın.
        cakisan = [a for a in adaylar if iban in a.bilinen_ibanlar]
        if len(cakisan) > 1:
            return Karar(
                hareket.id, None, None, "iban", 50, "manuel_inceleme", "iban_coklu_kisi"
            )
        return Karar(
            hareket.id, iban_adayi.user_id, iban_adayi.unit_id, "iban",
            PUAN_IBAN, "otomatik", "iban_gecmisi",
            fifo_dagit(hareket.tutar_kurus, iban_adayi.borclar),
        )

    # (3) AD + TUTAR + AÇIK BORÇ
    puanli: list[tuple[int, Aday, str]] = []
    for aday in adaylar:
        ad_puan, ad_neden = _ad_puani(hareket, aday)
        if ad_puan == 0:
            continue  # AD EŞLEŞMESİ YOKSA aday değil: yalnız tutar tutuyor
        tutar_puan, tutar_neden = _tutar_puani(hareket, aday)
        toplam = ad_puan + tutar_puan
        if toplam >= ESIK_ADAY:
            puanli.append((toplam, aday, f"{ad_neden}+{tutar_neden}".strip("+")))
    if not puanli:
        return Karar(hareket.id, None, None, "manuel", 0, "manuel_inceleme", "aday_yok")
    puanli.sort(key=lambda t: -t[0])
    if len(puanli) > 1 and puanli[0][0] == puanli[1][0]:
        return Karar(
            hareket.id, None, None, "ad_tutar", puanli[0][0], "manuel_inceleme", "berabere",
        )
    puan, aday, neden = puanli[0]
    # AD EŞLEŞMESİ TEK BAŞINA YETMEZ (kullanıcı kuralı): eşiğin altındaki
    # her şey manuel incelemeye düşer — otomatik uygulanmaz.
    sonuc = "otomatik" if puan >= ESIK_OTOMATIK else "manuel_inceleme"
    return Karar(
        hareket.id, aday.user_id, aday.unit_id, "ad_tutar", puan, sonuc, neden,
        fifo_dagit(hareket.tutar_kurus, aday.borclar) if sonuc == "otomatik" else (),
    )
