"""`/activity` ESKI metin alanlari — GECIS KODU (tur 15).

Tur 15'te akis satirlari kimlige cevrildi: sunucu `baslik_kimlik` (orn.
`kargo_teslim`) ve `veri` (orn. `{"firma": "...", "daire": "A-12"}`) gonderir,
CUMLEYI istemci kendi dilinde kurar. Boylece Turkce metin SQL'den kalkti.

Bu modul yalnizca **guncellenmemis istemciler** icindir: sozlesmedeki
`baslik`/`alt_metin` alanlari (deprecated) burada, YAPISAL veriden yeniden
uretilir. Yani metin tek yerde durur; SQL'e geri sizmaz.

**TEK DIL (Turkce) — bilincli.** Bu alanlar sozlesmeden KALKACAK; 7 dile
cevirmek, mobil ARB'deki ayni metinlerin ikinci bir kopyasini (ve kacinilmaz
bir kayma riskini) yaratirdi. Guncel istemci bu alanlara BAKMAZ; eski
istemci bugunku davranisini (Turkce) aynen gorur — yani regresyon yok.

KALDIRMA KOSULU: tum istemciler `baslik_kimlik`/`veri` okur duruma gelince
bu modul ve `ActivityItemOut.baslik`/`alt_metin` alanlari silinir.
"""
from __future__ import annotations

from collections.abc import Mapping
from datetime import datetime
from typing import Any

# Baslik kimligi -> eski (Turkce) baslik. Kimlikler `routers/activity.py`
# icindeki SQL parcalarinda uretilir.
_BASLIKLAR: dict[str, str] = {
    "devriye_okutma": "Devriye Okutması",
    "gorev_tamamlama": "Görev Tamamlandı",
    "aidat_odeme": "Aidat Ödemesi",
    "talep_acik": "Talep Açıldı",
    "talep_is_emri": "Talep İş Emrine Dönüştü",
    "talep_cozuldu": "Talep Çözüldü",
    "talep_reddedildi": "Talep Reddedildi",
    "daire_sikayeti": "Daire Şikayeti",
    "alarm_kacirilan_tur": "Kaçırılan Tur",
    "alarm_eksik_checkpoint": "Eksik Checkpoint",
    "alarm_gecikmis_okutma": "Gecikmiş Okutma",
    "ziyaretci_giris": "Ziyaretçi Girişi",
    "ziyaretci_cikis": "Ziyaretçi Çıkışı",
    "kargo": "Kargo Kaydedildi",
    "kargo_teslim": "Kargo Teslim Edildi",
    "arac_giris": "Araç Girişi",
    "arac_cikis": "Araç Çıkışı",
    "ihlal": "İhlal Kaydı",
}


def eski_baslik(kimlik: str) -> str:
    """Kimlik -> eski baslik. Bilinmeyen kimlik kimligin KENDISINI dondurur
    (bos baslik gostermektense makine-okunabilir bir sey gorunsun)."""
    return _BASLIKLAR.get(kimlik, kimlik)


def _daire(veri: Mapping[str, Any]) -> str:
    return f"Daire {veri['daire']}"


def _tl(kurus: Any) -> str:
    """Kurus -> "₺750.00".

    BILINCLI olarak eski SQL bicimi (`to_char(..., 'FM999999990.00')`):
    binlik ayraci YOK, ondalik NOKTA. Bu alan yeni istemcinin gordugu degil,
    ESKI istemcinin gordugu metindir — bicimi degistirmek gorunumu sessizce
    kaydirirdi. Guncel istemci `tutar_kurus` tam sayisini alir ve parayi
    KENDI dil kurallariyla yazar."""
    try:
        tam = int(kurus)
    except (TypeError, ValueError):
        return ""
    return f"₺{tam / 100:.2f}"


def _saat_araligi(veri: Mapping[str, Any]) -> str | None:
    bas, bit = veri.get("baslangic"), veri.get("bitis")
    if not bas or not bit:
        return None
    try:
        b1 = bas if isinstance(bas, datetime) else datetime.fromisoformat(str(bas))
        b2 = bit if isinstance(bit, datetime) else datetime.fromisoformat(str(bit))
    except ValueError:
        return None
    return f"{b1:%H:%M}–{b2:%H:%M}"


def eski_alt_metin(tur: str, veri: Mapping[str, Any]) -> str | None:
    """Yapisal veriden eski alt metni kurar (tur 15 oncesi bicim)."""
    if not veri:
        return None
    match tur:
        case "devriye_okutma" | "gorev_tamamlama":
            return veri.get("ad")
        case "aidat_odeme":
            return f"{_daire(veri)} — {_tl(veri.get('tutar_kurus'))}"
        case "talep" | "ihlal":
            temel = veri.get("baslik") or ""
            konum = veri.get("konum")
            return f"{temel} — {konum}" if konum else temel
        case "daire_sikayeti":
            return f"{_daire(veri)} — {veri.get('kategori', '')}"
        case "alarm":
            # ESKIDEN scheduler'in Turkce cumlesi (`notification.mesaj`)
            # gosteriliyordu; artik plan + pencere. Eski istemci de bu YENI,
            # daha okunakli ozeti gorur (metin degil VERI degisti).
            aralik = _saat_araligi(veri)
            plan = veri.get("plan")
            if plan and aralik:
                return f"{plan} · {aralik}"
            return plan or aralik
        case "ziyaretci_giris" | "ziyaretci_cikis":
            return f"{veri.get('ad', '')} — {_daire(veri)}"
        case "kargo" | "kargo_teslim":
            return f"{veri.get('firma', '')} — {_daire(veri)}"
        case "arac_giris" | "arac_cikis":
            parca = str(veri.get("plaka", ""))
            if "daire" in veri:
                parca += f" — {_daire(veri)}"
            if veri.get("tanim"):
                parca += f" ({veri['tanim']})"
            return parca
        case _:
            return None
