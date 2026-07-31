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


def yeniden_deneme_gecikmesi(deneme: int) -> timedelta:
    """Katlanan geri cekilme: 1., 2., 3. deneme -> 1, 5, 25 dakika.

    Sabit aralik, gecici olarak dusmus bir uca dakikada bir vurmak olurdu;
    katlanan aralik hem yuku dagitir hem de kalici arizada kuyrugu hizla
    boaltir (MAX_DENEME'de durur).
    """
    ussu = max(0, deneme)
    return timedelta(minutes=5 ** ussu)


def yeniden_denenmeli(
    *, deneme: int, son_deneme_at: datetime | None, simdi: datetime
) -> bool:
    """Bu satirin siradaki denemesinin vadesi geldi mi?

    `son_deneme_at` YOKSA (henuz hic denenmemis kayit) HEMEN denenir.
    """
    if deneme >= MAX_DENEME:
        return False
    if son_deneme_at is None:
        return True
    return simdi >= son_deneme_at + yeniden_deneme_gecikmesi(deneme)
