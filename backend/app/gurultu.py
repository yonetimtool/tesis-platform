"""Gurultu caydirici CEKIRDEGI (P37) — saf hesap, veritabani YOK.

Esik/imza/geri-cekilme mantigi burada; router veriyi toplar, burasi karari
verir. Boylece "4'te tetiklenmez, 5'te tetiklenir" gibi sinir davranislari
bir HTTP istegi kurmadan olculebilir.
"""
from __future__ import annotations

import hashlib
import hmac
import json
from datetime import datetime, timedelta

from .yeniden_deneme import denenmeli as _denenmeli, gecikme as _gecikme

#: Varsayilan uyari metni (tenant kendi metnini yazabilir). Ton BILINCLI
#: OLARAK NOTR: caydirici bir CEZA DEGIL hatirlatmadir ve suclayici bir
#: metin, hakkinda haksiz sikayet birikmis bir daireye de aynen giderdi.
VARSAYILAN_UYARI = (
    "Gürültü kirliliği nedeniyle uyarı aldınız. "
    "Lütfen komşularınızı rahatsız etmeyin."
)

#: Yeniden deneme SAYISI. Sinirsiz deneme, kalici olarak yanlis
#: yapilandirilmis bir uca sonsuza dek istek atmak olurdu.
MAX_DENEME = 3

#: `X-Yonetio-Timestamp` bu kadar saniyeden eskiyse alici REDDETMELIDIR
#: (tekrar oynatma penceresi). Belgede yazili olmasi, alicinin bunu
#: dogrulamasi icin gerekli.
IMZA_PENCERESI_SN = 300


def esik_asildi(sayac: int, esik: int) -> bool:
    """Sinir DAHILDIR: esik 5 ise 4 tetiklemez, 5 TETIKLER.

    `>` yerine `>=`: "5 sikayete ulasinca" ifadesinin dogal okunusu budur ve
    `>` olsaydi esik ayari kullaniciya soyledigi sayidan bir fazlasinda
    calisirdi.
    """
    if esik <= 0:
        return False
    return sayac >= esik


def uyari_metni(tenant_metni: str | None) -> str:
    """Tenant metni YOKSA varsayilan.

    BOS METIN ile NULL AYRIMI: bos/bosluk metin de varsayilana duser —
    "anons metnini bilerek bosalttim" diye bir kullanim yok; iceriksiz bir
    anons gonderilmesi kullanicinin niyeti olamaz.
    """
    if tenant_metni is None:
        return VARSAYILAN_UYARI
    temiz = tenant_metni.strip()
    return temiz or VARSAYILAN_UYARI


def govde_uret(*, daire_no: str, metin: str, zaman: datetime) -> bytes:
    """Webhook JSON govdesi — ALICI ICIN SABIT SEMA.

    Anahtar SIRASI sabittir (`sort_keys`) ve bosluk yoktur: imza GOVDENIN
    BAYTLARI uzerinden hesaplanir; alicinin yeniden serilestirip ayni imzayi
    uretebilmesi icin uretimin deterministik olmasi SART.
    """
    return json.dumps(
        {
            "daire": daire_no,
            "metin": metin,
            "zaman": zaman.astimezone().isoformat(),
            "tip": "gurultu_uyarisi",
        },
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def imzala(gizli: str, govde: bytes, zaman_damgasi: int) -> str:
    """HMAC-SHA256(`<zaman>.<govde>`) — GitHub/Stripe deseni.

    ZAMAN DAMGASI IMZAYA GIRER: yalnizca govdeyi imzalamak, ele gecirilmis
    bir istegin SONSUZA DEK yeniden oynatilabilmesi demekti. Alici hem
    imzayi hem damganin tazeligini dogrular (bkz. IMZA_PENCERESI_SN).
    """
    mesaj = f"{zaman_damgasi}.".encode("utf-8") + govde
    return hmac.new(gizli.encode("utf-8"), mesaj, hashlib.sha256).hexdigest()


def imza_dogrula(gizli: str, govde: bytes, zaman_damgasi: int, imza: str) -> bool:
    """Alici tarafinin yapmasi gerekeni gosteren referans dogrulama.

    `compare_digest`: normal `==` karsilastirmasi ilk farkli baytta doner ve
    zamanlama uzerinden imza tahmin edilebilir hale gelirdi.
    """
    return hmac.compare_digest(imzala(gizli, govde, zaman_damgasi), imza)


# (P154 / Asama 9) POLITIKA `yeniden_deneme.py`YE TASINDI. Mesaj kuyrugu
# TAM OLARAK ayni seye ihtiyac duyuyordu; kopyalamak iki politika
# uretirdi — biri duzeltilir, oteki unutulurdu. Buradaki iki sarmalayici
# CAGRI YERLERI DEGISMESIN diye duruyor ve `MAX_DENEME`yi baglar.


def yeniden_deneme_gecikmesi(deneme: int) -> timedelta:
    """Bkz. `yeniden_deneme.gecikme`."""
    return _gecikme(deneme)


def yeniden_denenmeli(
    *, deneme: int, son_deneme_at: datetime | None, simdi: datetime
) -> bool:
    """Bkz. `yeniden_deneme.denenmeli` — webhook icin MAX_DENEME bagli."""
    return _denenmeli(
        deneme=deneme, son_deneme_at=son_deneme_at,
        simdi=simdi, max_deneme=MAX_DENEME,
    )
