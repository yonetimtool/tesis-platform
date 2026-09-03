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
KANAL_KRITIK = "yonetio_kritik_v2"
KANAL_GENEL = "yonetio_genel_v2"
KANAL_SESSIZ = "yonetio_sessiz_v2"
#: (P208 §2) GURULTU UYARISININ KENDI KANALI — kendi sesiyle.
#:
#: NEDEN AYRI KANAL: Android'de ses KANALIN ozelligidir; "ayni kanaldan
#: farkli ses" diye bir sey YOK. Ayirt edilebilir bir ses istiyorsak
#: ayri kanal SART. Ve bu, kullaniciya sistem ayarlarinda da ayri bir
#: satir verir: gurultu uyarisini susturup vardiya hatirlatmasini acik
#: birakabilir.
KANAL_GURULTU = "yonetio_gurultu_v2"
#: (P210) VARDIYA HATIRLATMASININ KENDI KANALI — kendi anonsuyla.
#:
#: Ses, vardiyasi YAKLASAN gorevliye "hazirlan" der. Ayri kanal
#: olmasinin sebebi P208'dekiyle ayni: Android'de ses KANALIN
#: ozelligidir, "ayni kanaldan farkli ses" diye bir sey yok.
KANAL_VARDIYA = "yonetio_vardiya_v2"

#: Ozel ses dosyasinin ADI (uzantisiz — Android `res/raw`, iOS paket).
#: DOSYA HENUZ YOK: `SES_HAZIR` false oldugu surece sistem sesi
#: kullanilir. Dosya geldiginde tek satir degisir (ve kanal `_v2`
#: olur — bkz. modul basligi).
OZEL_SES_ADI = "yonetio_bildirim"
#: (P208 §2) GURULTU UYARISININ AYRI SESI: sakin, bildirimi GORMEDEN
#: ne oldugunu anlayabilmeli (istegin acik sarti).
GURULTU_SES_ADI = "yonetio_gurultu"
#: (P210) Vardiyasi yaklasan gorevliye giden anons.
VARDIYA_SES_ADI = "yonetio_vardiya"
#: (P210) DOSYALAR GELDI — ses artik SISTEM SESI DEGIL, kendi
#: dosyalarimiz. Kanal kimlikleri bu yuzden `_v2`: Android'de var olan
#: bir kanalin sesi PROGRAMLA degistirilemez; kimlik ayni kalsaydi
#: guncelleyen kullanicida ESKI (sessiz) kanal kalir ve "ses ekledik
#: ama calmiyor" olurdu.
SES_HAZIR = True

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
    # (P208 §2) KACAN VARDIYA OZEL SES ALMAZ — istegin karari: "normal
    # alarm sesi yeterli". Kritik kanaldan gider (sesli + high
    # oncelikli), kendi kanalini ACMIYORUZ.
    "vardiya_hatirlatma",
    "vardiya_baslamadi",
    "vardiya_ozeti",
    # Guvenlik: kacirilan tur ve gecikmis okutma da BEKLEYEN bir is
    # degil, OLMAYAN bir is bildirir.
    "kacirilan_tur",
    "gecikmis_okutma",
    "uzak_okutma",
    "gurultu_uyarisi",
    # (P208 §1) Sakine giden uyari ve yoneticiye giden esik bilgisi.
    "gurultu_uyari_sakin",
    "gurultu_esik_yonetim",
})


#: (P208 §2) KENDI KANALI/SESI OLAN TIPLER. Bugun yalniz gurultu
#: uyarisi: "kacan vardiya normal alarm sesi yeterli" (istegin karari);
#: sikayet ve vardiya hatirlatmasi P207'deki kritik kanaldan devam
#: ediyor. Sinirsiz buyumemeli — her yeni kanal, kullanicinin sistem
#: ayarlarinda gordugu bir satir daha demek.
OZEL_KANALLI_TIPLER: dict[str, tuple[str, str]] = {
    # tip -> (kanal, ses adi)
    "gurultu_uyari_sakin": (KANAL_GURULTU, GURULTU_SES_ADI),
    # (P210) VARDIYA HATIRLATMASI: vardiyasi YAKLASAN gorevliye.
    "vardiya_hatirlatma": (KANAL_VARDIYA, VARDIYA_SES_ADI),
    #
    # ================================================================
    # `vardiya_baslamadi` BILINCLI OLARAK BURADA YOK
    # ================================================================
    # Kacan vardiya uyarisi YONETICIYE gider ("gorevli gelmedi"),
    # hatirlatma ise GOREVLIYE ("vardiyan basliyor"). Ikisine ayni sesi
    # vermek, sesin TEK ISINI bozardi: bakmadan ne oldugunu anlatmak.
    # Kendisi de bir vardiya listesinde olan bir yonetici, "vardiyan
    # basliyor" sesini duyup kendi vardiyasini sanirdi — oysa gidip
    # birini yerine gondermesi gerekiyor.
    #
    # Ayri UCUNCU bir kanal da acmadik: nadir bir olay icin kullanicinin
    # sistem ayarlarina bir satir daha eklemek, ayar ekranini
    # okunmaz yapmaya dogru giden yoldur. Kacan vardiya KRITIK
    # kanaldan, genel kritik sesle (`yonetio_bildirim`) gider —
    # "onemli, simdi bak" demenin ortak sesi.
}


def kanal_sec(tip: str | None, *, sesli: bool) -> str:
    """Bildirim tipine ve KULLANICI TERCIHINE gore kanal.

    `sesli=False` (kullanici sesli uyarilari kapatmis) ise KRITIK
    bildirimler bile SESSIZ kanaldan gider. Tercihi gormezden gelmek,
    "kapattim ama caliyor" demekti — ve kullanici bir dahaki sefere
    bildirimlerin TAMAMINI sistemden kapatirdi.
    """
    if not sesli:
        return KANAL_SESSIZ
    if tip and tip in OZEL_KANALLI_TIPLER:
        return OZEL_KANALLI_TIPLER[tip][0]
    if tip and tip in KRITIK_TIPLER:
        return KANAL_KRITIK
    return KANAL_GENEL


def ses_adi(tip: str | None, *, sesli: bool) -> str | None:
    """iOS `aps.sound` degeri. Sessizde `None` (alan HIC gonderilmez)."""
    if not sesli:
        return None
    if SES_HAZIR and tip and tip in OZEL_KANALLI_TIPLER:
        # iOS ses dosyasi uzantisiyla birlikte gonderilir.
        return f"{OZEL_KANALLI_TIPLER[tip][1]}.caf"
    if SES_HAZIR and tip and tip in KRITIK_TIPLER:
        return f"{OZEL_SES_ADI}.caf"
    return "default"
