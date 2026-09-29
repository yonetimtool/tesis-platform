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
#: (DUKKAN) PAZAR YERI BILDIRIMLERININ KENDI KANALI.
#:
#: ===================================================================
#: NEDEN AYRI KANAL — VE NEDEN YALNIZ BIR TANE
#: ===================================================================
#: Bu dosyada tekrar tekrar yazilan bir kural var: "nadir bir olay icin
#: kullanicinin sistem ayarlarina bir satir daha eklemek, o ekrani
#: okunmaz yapmaya dogru giden yoldur." Dukkan icin YINE DE ayri kanal
#: aciliyor, cunku burada ayrisan sey OLAY TIPI degil URUN.
#:
#: Android'de kanal, kullaniciya SISTEM AYARLARINDA bir acma/kapama
#: verir. Dukkan bildirimleri `yonetio_genel_v2`den gitseydi, pazar yeri
#: pinglerinden bunalan bir sakin SITESININ duyurularini da susturmak
#: zorunda kalirdi. Tersi de dogru: is bekleyen bir usta tesis
#: duyurularini kapatip tekliflerini acik tutabilmeli.
#:
#: TEK KANAL, OLAY BASINA DEGIL: "teklif geldi", "is verildi", "isletmen
#: onaylandi" ayri kanallar olsaydi ayar ekrani okunmaz olurdu — bu
#: dosyanin baska yerlerinde verilen kararin aynisi.
#:
#: SES: SISTEM SESI (`default`). `yonetio_bildirim` Yonetiyor'un kimlik
#: sesidir ve "binanla ilgili bir sey oldu" der. Bir teklif bildirimi
#: onemlidir ama o degildir; ayni sesi vermek, sesin TEK ISINI
#: (bakmadan ne oldugunu anlatmak) bozardi. Ayrica ozel ses YENI SURUM
#: YAYINI ister; sistem sesiyle baslamak bu fazi bir ses dosyasina
#: BAGIMLI kilmiyor.
#:
#: `_v1`: henuz ozel ses yok. Ses eklenirse `_v2` acilir (Android'de var
#: olan bir kanalin sesi programla degistirilemez — modul basligi).
KANAL_DUKKAN = "yonetio_dukkan_v1"
#: (P249 §1c) SOS ALARM KANALI — kritik kanaldan AYRI.
#:
#: OLCULEN KUSUR: SOS, sikayet ve vardiya hatirlatmalariyla AYNI
#: `yonetio_kritik_v2` kanalindan, ayni sesle gidiyordu. O kanalin ses
#: turu `USAGE_NOTIFICATION`: telefon sessizde CALMAZ, Rahatsiz Etmeyin
#: acikken SUSTURULUR. Alarm kanali:
#:   * ses turu `USAGE_ALARM` + bildirim kategorisi `ALARM` — Android
#:     alarm sesini zil modundan BAGIMSIZ calar ve Rahatsiz Etmeyin'in
#:     varsayilan ayari ("alarmlara izin ver") onu gecirir,
#:   * sesi SISTEM ALARM SESI — ozel dosya gelince kanal `_v2` olur
#:     (Android'de var olan kanalin sesi programla degistirilemez).
#: Mobilde `MainActivity.kt` ayni kimlikle olusturur.
KANAL_ALARM = "yonetio_alarm_v1"

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
    # (P240 §1) PANIK — kritik kanalin var olma nedeni budur. Duyulmayan
    # bir panik bildirimi, hic gonderilmemis olanla AYNI SEYDIR.
    #
    # `panik_yanlis_alarm` da KRITIK: sahaya kosan kisiyi geri cagiran
    # mesaj, alarmin kendisi kadar zaman-kritiktir. `panik_kapandi`
    # kritik DEGIL (asagida yok) — o bir sonuc bildirimidir, kosarak
    # yapilacak bir sey kalmamistir.
    "panik_alarm",
    "panik_yanlis_alarm",
    # (P240 §3) YANGIN/DUMAN — panikle ayni siniftadir: duyulmayan bir
    # duman alarmi hic gonderilmemis olanla aynidir. `akilli_ev_kacak`
    # KRITIK DEGIL (asagida yok): onemli ama gece uyandirmayi
    # gerektirmez.
    "akilli_ev_yangin",
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
    # (P212 §3) ESKALASYON: guvenlige "kontrol edin, gerekirse polise
    # haber verin" ve yoneticiye bilgi. Duyulmayan bir eskalasyon, hic
    # gonderilmemis gibidir — ikisi de KRITIK kanaldan gider.
    #
    # NEDEN `yonetio_gurultu` DEGIL: o ses SAKINE yapilan ANONSTUR
    # (7,4 sn) ve amaci daireye "sesini kis" demek. Gorevlinin ihtiyaci
    # bir anons degil, KISA bir "simdi bak" isaretidir — kacan vardiya
    # uyarisinda verilen kararin aynisi (P208 §2). Ayri UCUNCU bir
    # kanal da acmadik: nadir bir olay icin kullanicinin sistem
    # ayarlarina bir satir daha eklemek, o ekrani okunmaz yapardi.
    "gurultu_eskalasyon_guvenlik",
    "gurultu_eskalasyon_yonetim",
    # (P249 §3) KAPIDA BEKLEYEN BIRI VAR: onay istegi, yaniti, cevapsizlik
    # ve sesli mesaj dakikalar icinde anlamini yitirir — sesli, ekranin
    # ustunde. Alarm sinifi DEGIL (dongulu siren gerekmez).
    "ziyaretci_onay_istegi",
    "ziyaretci_onaylandi",
    "ziyaretci_reddedildi",
    "ziyaretci_onay_cevap_yok",
    "sesli_mesaj",
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


#: (DUKKAN) Bu onekle baslayan tipler Dukkan kanalindan gider.
#:
#: ONEK ESLEMESI, LISTE DEGIL: Dukkan bildirim tipleri buyuyecek
#: (F7'de odeme, mesajlasma...). Elle tutulan bir liste, yeni bir tip
#: eklendiginde SESSIZCE Yonetiyor kanalina duserdi — ve kullanici
#: pazar yeri bildirimini kapattigini sanip almaya devam ederdi.
DUKKAN_ONEK = "dukkan_"


#: (E2E 2026-09) KATEGORILI PANIK de panik alarmidir. P243 §5c push
#: kimligini `panik_kategori_<k>` yapti (metin kategoriye gore degissin
#: diye) ve bu kimlik `KRITIK_TIPLER`de olmadigi icin yangin/deprem/gaz
#: alarmlari GENEL kanaldan, sistem sesiyle gidiyordu. Kategori METNI
#: degistirir, KANALI degil.
PANIK_KATEGORI_ONEK = "panik_kategori_"
#: (P249 §2) Tatbikat metinleri — kanal ve ses gercek alarmla AYNI
#: (gerekce docs/P249-kararlar.md §2: gercek sesi tanitmak).
PANIK_TATBIKAT_ONEK = "panik_tatbikat_"

#: (P249 §1c) ALARM SINIFI: kendi kanalindan (alarm sesi), kullanicinin
#: "sesli uyari" ve "mobil bildirim" tercihlerinden BAGIMSIZ gider.
#:
#: NEDEN TERCIH YOK SAYILIYOR: tercih bir RAHATSIZLIK ayaridir ("duyuru
#: pinglerinden bunaldim"). Olculen durumda mobil bildirimi kapatan
#: kullanici deprem alarmini da kapatmis oluyordu; sesi kapatan kullanici
#: alarmi sessiz kanaldan, ekranin ustunde belirmeden aliyordu. Hayati
#: bir uyari, bir rahatsizlik ayarina rehin birakilamaz. Kullanici
#: alarmi isterse isletim sisteminin KANAL ayarindan kapatabilir — o
#: bilincli ve ayri bir karardir.
#:
#: `panik_yanlis_alarm` ve `panik_kapandi` BURADA YOK: onlar bir sonuc
#: bildirimidir, dongulu alarm sesiyle calmalari paniği uzatirdi.
ALARM_TIPLERI: frozenset[str] = frozenset({"panik_alarm", "panik_yardim_talebi"})


def alarm_mi(tip: str | None) -> bool:
    return bool(tip) and (
        tip in ALARM_TIPLERI
        or tip.startswith(PANIK_KATEGORI_ONEK)
        or tip.startswith(PANIK_TATBIKAT_ONEK)
    )


#: (P249 §1c) iOS CRITICAL ALERT KAPSAMI — Apple basvurusundaki BEYANLA
#: AYNI (docs/dis-basvurular.md, Request ID A5HC6338GM): yalniz GERCEK
#: deprem, yangin, gaz kacagi ve tahliye. TATBIKAT kritik DEGIL, yardim
#: cagrilari (saglik, guvenlik tehdidi, diger, yardim talebi) kritik
#: DEGIL — onlar time-sensitive ile gider. Beyanin disina cikmak yetkinin
#: geri alinmasina yol acabilir; kume GENISLETILMEDEN once basvuru
#: guncellenmeli.
KRITIK_UYARI_KIMLIKLERI: frozenset[str] = frozenset({
    "panik_kategori_deprem",
    "panik_kategori_yangin",
    "panik_kategori_gaz",
    "panik_kategori_tahliye",
})


def kritik_uyari_mi(kimlik: str | None) -> bool:
    return kimlik in KRITIK_UYARI_KIMLIKLERI


#: (P249 §1c) ALARM SES DOSYASI HENUZ YOK — sistem alarm sesi calar.
#: Dosya gelince (bicim: docs/P249-kararlar.md §1c) `True` yapilir, iOS
#: paketine `yonetio_alarm.caf`, Android `res/raw/yonetio_alarm` eklenir
#: ve Android kanali `yonetio_alarm_v2` olarak YENIDEN acilir.
ALARM_SES_HAZIR = False
ALARM_SES_ADI = "yonetio_alarm"


def _kritik_mi(tip: str | None) -> bool:
    return bool(tip) and (tip in KRITIK_TIPLER or tip.startswith(PANIK_KATEGORI_ONEK))


def kanal_sec(tip: str | None, *, sesli: bool) -> str:
    """Bildirim tipine ve KULLANICI TERCIHINE gore kanal.

    `sesli=False` (kullanici sesli uyarilari kapatmis) ise KRITIK
    bildirimler bile SESSIZ kanaldan gider. Tercihi gormezden gelmek,
    "kapattim ama caliyor" demekti — ve kullanici bir dahaki sefere
    bildirimlerin TAMAMINI sistemden kapatirdi.
    """
    # (P249 §1c) ALARM TERCIHTEN ONCE: sesi kapatmis kullanici da alarmi
    # alarm kanalindan alir (gerekce `ALARM_TIPLERI`).
    if alarm_mi(tip):
        return KANAL_ALARM
    if not sesli:
        return KANAL_SESSIZ
    # DUKKAN URUN AYRIMI — tip kontrollerinden ONCE: bir Dukkan tipi
    # yanlislikla `KRITIK_TIPLER`e benzer adlandirilirsa bile Yonetiyor
    # kanalina DUSMEZ.
    if tip and tip.startswith(DUKKAN_ONEK):
        return KANAL_DUKKAN
    if tip and tip in OZEL_KANALLI_TIPLER:
        return OZEL_KANALLI_TIPLER[tip][0]
    if _kritik_mi(tip):
        return KANAL_KRITIK
    return KANAL_GENEL


def ses_adi(tip: str | None, *, sesli: bool) -> str | None:
    """iOS `aps.sound` degeri. Sessizde `None` (alan HIC gonderilmez)."""
    if alarm_mi(tip):
        # ALARM TERCIHTEN BAGIMSIZ calar. Dosya yokken sistem sesi.
        return f"{ALARM_SES_ADI}.caf" if ALARM_SES_HAZIR else "default"
    if not sesli:
        return None
    # DUKKAN: sistem sesi. Yonetiyor'un kimlik sesi "binanla ilgili bir
    # sey oldu" der; bir teklif bildirimi onemlidir ama o degildir.
    if tip and tip.startswith(DUKKAN_ONEK):
        return "default"
    if SES_HAZIR and tip and tip in OZEL_KANALLI_TIPLER:
        # iOS ses dosyasi uzantisiyla birlikte gonderilir.
        return f"{OZEL_KANALLI_TIPLER[tip][1]}.caf"
    if SES_HAZIR and _kritik_mi(tip):
        return f"{OZEL_SES_ADI}.caf"
    return "default"
