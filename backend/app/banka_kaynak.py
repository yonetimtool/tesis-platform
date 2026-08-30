"""(P191 §4) HAREKET KAYNAĞI — TAKILABİLİR katman.

===========================================================================
NEDEN AYRI KATMAN
===========================================================================
Kullanıcının şartı: *"Kaynak katmanı TAKILABİLİR olsun — açık bankacılık
sonra ikinci kaynak olarak aynı motora bağlanacak, motor değişmeyecek."*

Bu modülün tek işi, geldiği yer ne olursa olsun bir banka hareketini
`HamHareket`e çevirmek. Eşleştirme motoru (`banka.py`) ve uygulama
katmanı (`banka_servis.py`) yalnız `HamHareket` görür; CSV'nin sütun
adını, MT940'ın `:61:` etiketini ya da yarınki API'nin JSON şemasını
HİÇBİRİ bilmez.

===========================================================================
XLSX SUNUCUDA AYRIŞTIRILMAZ — depo kararı (P28/P29 ile aynı)
===========================================================================
XLSX ayrıştırma bir saldırı yüzeyidir (zip bombası, XXE, formül
enjeksiyonu) ve panel dosyayı zaten kullanıcıya önizleme göstermek için
okumak zorunda. Bu yüzden **CSV/Excel panelde ayrıştırılır** ve sunucuya
YAPILANDIRILMIŞ satır listesi gelir; sunucu her satırı doğrular.

**MT940 SUNUCUDA ayrıştırılır** ve bu bir çelişki değil: MT940 düz
metindir (zip yok, formül yok, XML yok), ayrıştırıcısı ~60 satırdır ve
bankadan gelen dosya çoğu zaman panelin okuyamayacağı bir uzantıyla
(`.sta`, `.940`) iner.

===========================================================================
MÜKERRER KORUMASI — `external_transaction_id`
===========================================================================
Banka bir referans numarası veriyorsa O kullanılır. Vermiyorsa
(tarih|tutar|yön|açıklama|gün-içi-sıra) beşlisinden KARARLI bir kimlik
türetilir: aynı ekstre iki kez yüklenince aynı kimlik çıkar ve ikinci
yükleme yeni satır AÇMAZ. Sıra numarası şart — aynı gün aynı tutarda
aynı açıklamayla iki gerçek havale olabilir ve onları tek satıra
indirmek GERÇEK bir ödemeyi yok saymak olurdu.
"""
from __future__ import annotations

import hashlib
import re
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from datetime import date, datetime

from .banka import iban_normalize


@dataclass(frozen=True)
class HamHareket:
    """Kaynaktan bağımsız, normalize edilmiş banka hareketi."""

    external_transaction_id: str
    islem_tarihi: date
    #: HER ZAMAN POZİTİF; işaret `yon`da (finansal_hareket kuralı).
    tutar_kurus: int
    yon: str  # giris | cikis
    aciklama: str = ""
    karsi_ad: str | None = None
    karsi_iban: str | None = None
    para_birimi: str = "TRY"
    raw: Mapping[str, object] = field(default_factory=dict)


class KaynakHatasi(ValueError):
    """Ayrıştırma/doğrulama hatası — çağıran 422'ye çevirir."""


def kimlik_uret(
    *, islem_tarihi: date, tutar_kurus: int, yon: str, aciklama: str, sira: int
) -> str:
    """Bankanın referansı yoksa KARARLI kimlik. Bkz. modül başlığı."""
    ham = f"{islem_tarihi.isoformat()}|{tutar_kurus}|{yon}|{aciklama.strip()}|{sira}"
    return "auto:" + hashlib.sha256(ham.encode("utf-8")).hexdigest()[:32]


def _tarih_coz(deger: object) -> date:
    if isinstance(deger, date):
        return deger
    metin = str(deger or "").strip()
    for bicim in ("%Y-%m-%d", "%d.%m.%Y", "%d/%m/%Y", "%Y/%m/%d"):
        try:
            return datetime.strptime(metin, bicim).date()
        except ValueError:
            continue
    raise KaynakHatasi(f"tarih cozulemedi: {metin!r}")


def _tutar_coz(deger: object) -> int:
    """Kuruşa çevir. Tam sayı geldiyse ZATEN kuruştur (panel öyle gönderir).

    Metin geldiğinde Türkçe biçim (`1.234,56`) ve İngilizce biçim
    (`1,234.56`) AYRI AYRI çözülür: son ayıraç ondalık kabul edilir.
    Bunu tahmin etmeye bırakmak, 1.234'ü bin iki yüz otuz dört ile bir
    virgül iki üç dört arasında sallandırırdı.
    """
    if isinstance(deger, int):
        return deger
    if isinstance(deger, float):
        return round(deger * 100)
    metin = str(deger or "").strip().replace(" ", "")
    if not metin:
        raise KaynakHatasi("tutar bos")
    metin = re.sub(r"[^0-9,.\-]", "", metin)
    son_nokta, son_virgul = metin.rfind("."), metin.rfind(",")
    if son_nokta > son_virgul:
        sade = metin.replace(",", "")
    elif son_virgul > son_nokta:
        sade = metin.replace(".", "").replace(",", ".")
    else:
        sade = metin
    try:
        return round(float(sade) * 100)
    except ValueError as exc:
        raise KaynakHatasi(f"tutar cozulemedi: {deger!r}") from exc


def ekstre_satirlarindan(satirlar: Iterable[Mapping[str, object]]) -> list[HamHareket]:
    """Panelin ayrıştırdığı CSV/Excel satırlarını `HamHareket`e çevirir.

    Beklenen alanlar: `tarih`, `tutar` (kuruş ya da metin), `aciklama`,
    ve isteğe bağlı `yon`, `referans`, `karsi_ad`, `karsi_iban`.
    `yon` verilmezse tutarın İŞARETİNDEN türetilir (negatif = çıkış).
    """
    sonuc: list[HamHareket] = []
    for sira, satir in enumerate(satirlar, start=1):
        tarih = _tarih_coz(satir.get("tarih"))
        ham_tutar = _tutar_coz(satir.get("tutar"))
        yon = str(satir.get("yon") or "").strip().lower()
        if yon not in ("giris", "cikis"):
            yon = "cikis" if ham_tutar < 0 else "giris"
        tutar = abs(ham_tutar)
        if tutar == 0:
            raise KaynakHatasi(f"satir {sira}: tutar sifir")
        aciklama = str(satir.get("aciklama") or "").strip()
        referans = str(satir.get("referans") or "").strip()
        sonuc.append(
            HamHareket(
                external_transaction_id=referans
                or kimlik_uret(
                    islem_tarihi=tarih, tutar_kurus=tutar, yon=yon,
                    aciklama=aciklama, sira=sira,
                ),
                islem_tarihi=tarih,
                tutar_kurus=tutar,
                yon=yon,
                aciklama=aciklama,
                karsi_ad=(str(satir.get("karsi_ad") or "").strip() or None),
                karsi_iban=iban_normalize(str(satir.get("karsi_iban") or "")),
                para_birimi=(str(satir.get("para_birimi") or "TRY").strip().upper() or "TRY"),
                raw=dict(satir),
            )
        )
    return sonuc


# --------------------------------------------------------------------------- #
# MT940 (SWIFT hesap ekstresi) — düz metin, sunucuda ayrıştırılır.
#
# İlgilendiğimiz iki etiket:
#   :61:  hareket satırı — YYMMDD [MMDD] C/D tutar işlem-kodu referans
#   :86:  bir önceki hareketin AÇIKLAMASI (çok satırlı olabilir)
# Diğer etiketler (:20:, :25:, :60F:, :62F:) bakiye/başlık bilgisidir ve
# hareket üretmez; yok sayılır.
# --------------------------------------------------------------------------- #
_MT940_61 = re.compile(
    r"^:61:(?P<vade>\d{6})(?P<kayit>\d{4})?(?P<isaret>RC|RD|C|D)(?P<tutar>[\d,\.]+)"
    r"(?P<kod>[A-Z][A-Z0-9]{3})?(?P<ref>[^\n]*)$"
)
#: IBAN benzeri diziyi açıklamadan yakalar (TR + 24 hane; genel biçim de kabul).
_IBAN_DESEN = re.compile(r"\b([A-Z]{2}\d{2}[A-Z0-9]{11,30})\b")


def mt940_ayristir(metin: str) -> list[HamHareket]:
    """MT940 metnini `HamHareket` listesine çevirir.

    `RC`/`RD` (ters kayıt) işaretleri normal C/D gibi ele alınır ama
    açıklamaya dokunulmaz: bir hareketin İADE olduğu kararı motorun
    değil, yöneticinin işidir (ters kayıt ekranı).
    """
    if not metin or ":61:" not in metin:
        raise KaynakHatasi("mt940_gecersiz")
    # Satır sonlarını normalize et; :86: devam satırları etiketsiz gelir.
    satirlar = [s.rstrip() for s in metin.replace("\r\n", "\n").split("\n")]
    hareketler: list[HamHareket] = []
    aciklamalar: list[list[str]] = []
    aktif_86 = False
    for satir in satirlar:
        m = _MT940_61.match(satir)
        if m:
            aktif_86 = False
            yil = 2000 + int(m.group("vade")[:2])
            tarih = date(yil, int(m.group("vade")[2:4]), int(m.group("vade")[4:6]))
            isaret = m.group("isaret")
            yon = "giris" if isaret in ("C", "RC") else "cikis"
            tutar = _tutar_coz(m.group("tutar"))
            hareketler.append(
                HamHareket(
                    external_transaction_id=(m.group("ref") or "").strip()
                    or kimlik_uret(
                        islem_tarihi=tarih, tutar_kurus=tutar, yon=yon,
                        aciklama="", sira=len(hareketler) + 1,
                    ),
                    islem_tarihi=tarih,
                    tutar_kurus=tutar,
                    yon=yon,
                    raw={"mt940_61": satir},
                )
            )
            aciklamalar.append([])
            continue
        if satir.startswith(":86:"):
            aktif_86 = True
            if aciklamalar:
                aciklamalar[-1].append(satir[4:].strip())
            continue
        if aktif_86 and satir and not satir.startswith(":"):
            if aciklamalar:
                aciklamalar[-1].append(satir.strip())
            continue
        aktif_86 = False

    tamam: list[HamHareket] = []
    for hareket, parcalar in zip(hareketler, aciklamalar):
        aciklama = " ".join(p for p in parcalar if p).strip()
        iban = None
        m = _IBAN_DESEN.search(aciklama.replace(" ", ""))
        if m:
            iban = iban_normalize(m.group(1))
        tamam.append(
            HamHareket(
                external_transaction_id=hareket.external_transaction_id,
                islem_tarihi=hareket.islem_tarihi,
                tutar_kurus=hareket.tutar_kurus,
                yon=hareket.yon,
                aciklama=aciklama,
                karsi_iban=iban,
                raw={**dict(hareket.raw), "mt940_86": aciklama},
            )
        )
    if not tamam:
        raise KaynakHatasi("mt940_hareket_yok")
    return tamam


#: Kayıtlı kaynaklar — YENİ KAYNAK BURAYA EKLENİR, motor DEĞİŞMEZ.
#: `acik_bankacilik` ikinci aşamadır; bugün yok ve sözü verilmiyor.
KAYNAKLAR = ("ekstre", "acik_bankacilik")
