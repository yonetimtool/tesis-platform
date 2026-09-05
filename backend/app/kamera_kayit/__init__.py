"""(P213 §6) Gecmis kayit adaptorleri — SECIM burada yapilir.

`saglayici_kur` tek giristir: kamera kaydini alir, dogru adaptoru kurar.
Taninmayan saglayici icin ISTISNA atar (fail-closed) — varsayilan bir
adaptore dusmek, yanlis markaya yanlis istekler gondermek olurdu ve
teshis edilmesi cok zor bir hata sinifi uretirdi.
"""
from __future__ import annotations

from urllib.parse import urlsplit

import httpx

from ..kamera_kimlik import kimligi_uygula, parola_coz
from .dahua import DahuaSaglayici
from .hikvision import HikvisionSaglayici
from .sablon import SablonSaglayici
from .taban import AramaDesteklenmiyor, KayitAraligi, KayitSaglayici

__all__ = [
    "AramaDesteklenmiyor",
    "KayitAraligi",
    "KayitSaglayici",
    "SAGLAYICILAR",
    "saglayici_kur",
]

#: Kullanicinin secebilecegi degerler. `onvif` BILEREK YOK: standart olmasi
#: cazip ama sahada guvenilmez (Profile G cogu cihazda eksik). Iki satici
#: adaptoru gercek cihazda dogrulandiktan SONRA eklenecek — once eklemek,
#: dogrulanmamis bir yolu varsayilan gibi gosterirdi.
SAGLAYICILAR: tuple[str, ...] = ("sablon", "hikvision", "dahua")


class SaglayiciTaninmiyor(Exception):
    pass


def _konak(url: str, port_dahil: bool = True) -> str:
    """Adresin `konak[:port]` parcasi (kimliksiz)."""
    p = urlsplit(url)
    konak = p.hostname or ""
    if ":" in konak:
        konak = f"[{konak}]"
    return f"{konak}:{p.port}" if (port_dahil and p.port) else konak


def kayit_tabani(kamera) -> str:
    """NVR'in HTTP tabani. Bos ise kameranin konagi kullanilir.

    Cogu kurulumda kamera adresi ZATEN NVR'i gosterir (kanal kanal
    yayin veren tek cihaz); ayri alan istemek, yoneticiye ayni bilgiyi
    iki kez yazdirmak olurdu.
    """
    if kamera.kayit_adres:
        return kamera.kayit_adres
    # PORT TASINMAZ. Kameranin portu RTSP portudur (554); arama API'si
    # HTTP portundadir (80/443). `http://10.0.0.4:554` uretmek, her
    # aramayi RTSP portuna gonderip "cihaz beklenmeyen yanit verdi"
    # demekti — teshis edilmesi zor, kok nedeni gorunmez bir hata.
    return f"http://{_konak(kamera.stream_url or '', port_dahil=False)}"


def saglayici_kur(kamera, istemci: httpx.AsyncClient) -> KayitSaglayici:
    """Kameraya gore adaptor. `istemci` disaridan verilir ki testler
    tasima katmanini (HTTP) degistirebilsin — P200 dersi: taklit
    ADAPTORE konur, olculen katmanin sinirina degil."""
    ad = (kamera.kayit_saglayici or "").strip()
    if ad not in SAGLAYICILAR:
        raise SaglayiciTaninmiyor(ad or "(bos)")

    kanal = (kamera.kayit_kanal or "").strip()
    kullanici = kamera.kayit_kullanici
    parola = parola_coz(kamera.kayit_parola_sifreli)

    if ad == "sablon":
        # Sablon RTSP adresi `kayit_adres` alaninda tasinir: bu adaptorde
        # HTTP tabani zaten kullanilmiyor, alani ikinci bir amac icin
        # kullanmak yerine ANLAMINI adaptore gore degistirmek — ve bunu
        # burada ACIKCA yazmak — ek bir sutundan iyi.
        sablon = kimligi_uygula(kamera.kayit_adres or "", kullanici, parola)
        return SablonSaglayici(sablon, kanal)

    taban = kayit_tabani(kamera)
    rtsp_konak = kimligi_uygula(
        f"rtsp://{_konak(kamera.stream_url or '')}", kullanici, parola
    ).removeprefix("rtsp://")
    sinif = HikvisionSaglayici if ad == "hikvision" else DahuaSaglayici
    return sinif(istemci, taban, rtsp_konak, kanal, kullanici, parola)
