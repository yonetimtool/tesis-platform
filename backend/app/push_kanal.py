"""(P207 §2) BILDIRIM KANALI VE SESI — sunucu tarafi karar.

===========================================================================
OLCULEN DURUM: BILDIRIMLER SESSIZDI
===========================================================================
FCM govdesi yalnizca `notification{title, body}` + `data` tasiyordu.
Android 8'den beri bildirimin SESI KANALIN ozelligidir ve kanal
belirtilmeyen bildirim, manifest'teki varsayilan kanala duser — o kanal
da tanimli degildi. iOS tarafinda `aps.sound` HIC gonderilmiyordu.
Yani sessizlik bir ayar degil, EKSIKTI.

===========================================================================
ANDROID GERCEGI: KANALIN SESI SONRADAN DEGISTIRILEMEZ
===========================================================================
Bir kanal olusturulduktan sonra sesi PROGRAMLA DEGISTIRILEMEZ (kullanici
sistem ayarlarindan degistirebilir). Ses degisikligi YENI KANAL ister.
Bu yuzden kanal kimlikleri SURUMLU: `..._v1`. Ses dosyasi degisirse
`_v2` acilir ve eskisi silinir — yoksa kullanicinin telefonunda eski
sesli kanal kalir ve "sesi degistirdim ama degismedi" olurdu.

Kanal kimlikleri MOBILDE DE AYNEN yazilidir (`MainActivity.kt`).
`test_p207_push_kanal.py` ikisinin ayrismadigini olcer: kimlik
ayrisirsa sunucu var olmayan bir kanala gonderir ve bildirim
SESSIZ ama GORUNUR olur — yani kusur ancak sahada fark edilir.

===========================================================================
IOS GERCEGI: SES UYGULAMA PAKETINDE
===========================================================================
Ozel ses dosyasi uygulama paketine GOMULUDUR; sunucu yalnizca ADINI
gonderir. Yeni ses = YENI SURUM YAYINI. Ses dosyasi henuz yokken
`aps.sound = "default"` gonderilir: bildirim SISTEM sesiyle calar —
"ses yok" ile "ozel ses yok" ayni sey degil.
"""
from __future__ import annotations

#: Kanal kimlikleri — MOBILDEKI `MainActivity.kt` ile AYNI olmak
#: zorunda. Surum eki (`_v1`) bilincli: Android'de kanalin sesi
#: sonradan degistirilemez, ses degisirse kimlik de degisir.
KANAL_KRITIK = "yonetio_kritik_v1"
KANAL_GENEL = "yonetio_genel_v1"
KANAL_SESSIZ = "yonetio_sessiz_v1"

#: Ozel ses dosyasinin ADI (uzantisiz — Android `res/raw`, iOS paket).
#: DOSYA HENUZ YOK: `SES_HAZIR` false oldugu surece sistem sesi
#: kullanilir. Dosya geldiginde tek satir degisir (ve kanal `_v2`
#: olur — bkz. modul basligi).
OZEL_SES_ADI = "yonetio_bildirim"
SES_HAZIR = False

#: SESLI OLMASI GEREKEN bildirimler (istegin acik sarti: sikayet ve
#: vardiya hatirlatmalari). Bunlar KRITIK kanaldan gider; kullanici
#: sesi kapatsa bile ekranda uyari gorur (mobil tarafta yazili).
KRITIK_TIPLER: frozenset[str] = frozenset({
    # Sikayet/talep hattinin TAMAMI: sakinin actigi talep, yoneticinin
    # gormesi gereken ilk seydir.
    "yeni_talep",
    "talep_is_emri",
    "talep_cozuldu",
    "talep_reddedildi",
    "sikayet_cozuldu",
    "is_emri_atandi",
    # Vardiya: baslamadan once hatirlatma ve BASLAMAYAN vardiya uyarisi
    # (P207 §3). Duyulmayan bir vardiya hatirlatmasi, hic gonderilmemis
    # gibidir.
    "vardiya_hatirlatma",
    "vardiya_baslamadi",
    "vardiya_ozeti",
    # Guvenlik: kacirilan tur ve gecikmis okutma da BEKLEYEN bir is
    # degil, OLMAYAN bir is bildirir.
    "kacirilan_tur",
    "gecikmis_okutma",
    "uzak_okutma",
    "gurultu_uyarisi",
})


def kanal_sec(tip: str | None, *, sesli: bool) -> str:
    """Bildirim tipine ve KULLANICI TERCIHINE gore kanal.

    `sesli=False` (kullanici sesli uyarilari kapatmis) ise KRITIK
    bildirimler bile SESSIZ kanaldan gider. Tercihi gormezden gelmek,
    "kapattim ama caliyor" demekti — ve kullanici bir dahaki sefere
    bildirimlerin TAMAMINI sistemden kapatirdi.
    """
    if not sesli:
        return KANAL_SESSIZ
    if tip and tip in KRITIK_TIPLER:
        return KANAL_KRITIK
    return KANAL_GENEL


def ses_adi(tip: str | None, *, sesli: bool) -> str | None:
    """iOS `aps.sound` degeri. Sessizde `None` (alan HIC gonderilmez)."""
    if not sesli:
        return None
    if SES_HAZIR and tip and tip in KRITIK_TIPLER:
        # iOS ses dosyasi uzantisiyla birlikte gonderilir.
        return f"{OZEL_SES_ADI}.caf"
    return "default"
