"""(P241 §2) VARDIYA PLANI — Excel disa/ice aktarim bicimi.

===========================================================================
KIMLIK E-POSTAYLA TASINIR, ADLA DEGIL
===========================================================================
Excel'de "Ali Veli" yazan bir satir, sitede iki Ali Veli varsa hangisi?
Ad benzersiz DEGIL; e-posta tesis icinde benzersiz (uq_app_user_tenant_email)
ve zaten her personelde var (P197'den beri zorunlu). Adi da yaziyoruz ama
YALNIZ OKUNURLUK icin — eslemede kullanilmiyor.

===========================================================================
SUNUCU EXCEL'I AYRISTIRMAZ — ISTEMCI AYRISTIRIR
===========================================================================
Depoda ice aktarimin kurulu deseni bu (`routers/ice_aktarim.py`):
istemci dosyayi okur, satirlari JSON gonderir, sunucu DOGRULAR ve
ONIZLEME dondurur. Ayni deseni izlemek, kolon esleme arayuzunu ve
onizleme akisini ikinci kez yazmamak demek.

DISA AKTARIM ise sunucuda uretiliyor: cikti bir RAPOR ve rapor
uretimi (`rapor_ciktilari`) zaten sunucuda.
"""
from __future__ import annotations

import datetime as dt

from openpyxl import Workbook
from openpyxl.styles import Font
from openpyxl.utils import get_column_letter

from .hucre_guvenligi import guvenli_kaydet

#: Kolon sirasi — sablon, disa aktarim ve ice aktarim AYNI listeyi
#: kullanir. Ayri ayri yazilsaydi biri degistiginde oteki eskir ve
#: kullanici kendi indirdigi sablonu geri yukleyemezdi.
KOLONLAR: tuple[tuple[str, str], ...] = (
    ("tarih", "2026-03-02"),
    ("eposta", "guvenlik@ornek.com"),
    ("ad", "Ali Veli"),
    ("baslangic_saat", "08:00"),
    ("bitis_saat", "16:00"),
    ("mola_dakika", "30"),
    ("vardiya_rolu", "guvenlik"),
    ("alan", "A Blok"),
    ("not", ""),
)
KOLON_KODLARI = tuple(k for k, _ in KOLONLAR)


def _baslik_yaz(ws) -> None:
    ws.append(list(KOLON_KODLARI))
    for h in ws[1]:
        h.font = Font(bold=True)
    for i, kod in enumerate(KOLON_KODLARI, start=1):
        ws.column_dimensions[get_column_letter(i)].width = max(12, len(kod) + 4)


def ornek_sablon() -> bytes:
    """Bos sablon + BIR ornek satir.

    Ornek satir SART: bos bir sablon "tarih nasil yazilacak" sorusunu
    yanitlamaz ve kullanici 02.03.2026 yazip ice aktarimin neden
    calismadigini arar (P234'te olculen desen).
    """
    wb = Workbook()
    ws = wb.active
    ws.title = "vardiya"
    _baslik_yaz(ws)
    ws.append([ornek for _, ornek in KOLONLAR])
    # (P248 §3c) formul enjeksiyonu kapisi (bkz. hucre_guvenligi).
    return guvenli_kaydet(wb)


def plan_disa_aktar(satirlar: list[dict], site_ad: str) -> bytes:
    """Donemdeki plani XLSX olarak yaz.

    SAATLER METIN DEGIL "HH:MM" METNI: Excel saat hucresi yerel bicime
    gore 08:00'i 0,3333 diye saklar ve geri yuklerken bicim kayar.
    Metin yazmak, disa aktarilan dosyanin AYNEN geri yuklenebilmesini
    saglar — ki istegin maddesi tam olarak bu dongudur.
    """
    wb = Workbook()
    ws = wb.active
    ws.title = "vardiya"
    _baslik_yaz(ws)
    for s in satirlar:
        ws.append([str(s.get(kod, "") or "") for kod in KOLON_KODLARI])
    # (P248 §3c) formul enjeksiyonu kapisi (bkz. hucre_guvenligi).
    return guvenli_kaydet(wb)


def saat_coz(deger: str) -> dt.time | None:
    """"08:00" / "8:00" / "08:00:00" -> time. Cozulemezse None."""
    metin = (deger or "").strip()
    if not metin:
        return None
    # (E2E 2026-09) "22,00" ve yalniz saat ("22") da KABUL: Excel sayi
    # hucresi `22.00`'i "22" / "22,0" olarak dokebiliyor ve TR kullanicisi
    # virgulle yaziyor; ikisi de "08:00 bicimi" hatasina dusuyordu.
    if metin.replace(",", ".").replace(".", "", 1).isdigit() and "." in metin.replace(",", "."):
        saat, _, dakika = metin.replace(",", ".").partition(".")
        metin = f"{saat}:{dakika.ljust(2, '0')[:2]}"
    elif metin.isdigit() and len(metin) <= 2:
        metin = f"{metin}:00"
    for bicim in ("%H:%M", "%H:%M:%S", "%H.%M"):
        try:
            return dt.datetime.strptime(metin, bicim).time()
        except ValueError:
            continue
    return None


def tarih_coz(deger: str) -> dt.date | None:
    """ISO once; `gg.aa.yyyy` de KABUL EDILIR.

    Turkiye'de Excel varsayilani nokta ayracli tarihtir ve kullanicinin
    kendi dosyasini reddetmek, ozelligi kullanilamaz kilardi. Belirsiz
    bicim (`03/02/2026`) KABUL EDILMEZ: ay mi gun mu oldugunu bilemeyiz
    ve yanlis tahmin, vardiyayi baska bir gune yazardi.
    """
    metin = (deger or "").strip()
    if not metin:
        return None
    for bicim in ("%Y-%m-%d", "%d.%m.%Y"):
        try:
            return dt.datetime.strptime(metin, bicim).date()
        except ValueError:
            continue
    return None
