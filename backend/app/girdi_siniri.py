"""(P248 §3a) GIRDI UZUNLUK SINIRLARI — tek kaynak.

===========================================================================
NEDEN
===========================================================================
Kullanici: "Metin alanlarina istenildigi kadar yazilabiliyor." Olculen:
P247 §6'dan sonra bile 156 govde alani ve 60 sorgu parametresi yalniz
200.000 karakterlik TABAN tavana dayaniyordu (`schemas.METIN_TAVANI`).
Taban tavan bir SON HATTIR — "ad" alanina 200 bin karakter yazilabilmesi
hem veri kalitesi (listeyi kiran ad) hem kaynak (arama, PDF, push govdesi)
sorunudur.

===========================================================================
KURAL
===========================================================================
* Sunucu ASIL korumadir (istemci atlatilabilir): her girdi `str` alani
  `Field(max_length=...)` ya da `pattern`/`Literal`/Enum ile DAR sinirli.
* Degerler BU MODULDEN gelir; web (`admin-web/lib/girdi-siniri.ts`) ve
  mobil (`mobile/lib/src/core/girdi_siniri.dart`) ayni sayilari tasir ve
  kilit testleri esitligi olcer.
* Mevcut alanlarda P247 oncesinden kalan acik sayilar (ornegin firma adi
  150 — DB CHECK kisiti) KORUNDU: sinir DUSURULMEDI, cunku eski kaydi
  PATCH eden kullanici kendi verisiyle kilitlenirdi. Yeni sinirlar mevcut
  verinin EN UZUNUNDAN buyuk secildi (dev DB'de olculdu, bkz. kararlar).

===========================================================================
SINIF TABLOSU (alan adi -> tavan) — `SINIF_KURALLARI`
===========================================================================
Kilit (`tests/test_p248_girdi_siniri.py`) her alanin sinirini adina gore
bu tabloyla karsilastirir: "email" adli bir alan 254'u, "ad" adli bir alan
200'u ASAMAZ. Tabloya uymayan bilincli istisna gerekcesiyle
`UZUN_ISTISNALAR`a yazilir.
"""
from __future__ import annotations

import re

# ----------------------------------------------------------------- sabitler
AD = 100                 # kisi / kayit / etiket adi
BASLIK = 200             # baslik, konu
EPOSTA = 254             # RFC 5321 yol siniri
TELEFON_HAM = 32         # ham giris (bosluk/parantez dahil); E.164 <= 16
PAROLA = 128             # kullanici parolasi (bcrypt 72 bayt keser)
GIZLI = 500              # entegrasyon kullanici/parola/secret
URL = 2048               # tarayici/RTSP pratik siniri (DB CHECK ile ayni)
ADRES = 500
NOT = 2000               # not, aciklama, mesaj, gerekce
UZUN_NOT = 5000          # duyuru govdesi, destek yaniti
UZUN_METIN = 20000       # karar defteri metni, site kurali icerigi
YASAL_METIN = 100_000    # KVKK / aydinlatma metni
KOD = 64                 # kod, kisa kimlik, surum, tip/durum anahtari
SLUG = 120               # URL parcasi (il/ilce/mahalle/kategori)
JETON = 4096             # oturum/baglama/kurulum jetonu, FCM token
DOSYA_ANAHTARI = 500     # nesne deposu anahtari
DOSYA_ADI = 255          # dosya sistemi siniri
ICERIK_TIPI = 150        # MIME tipi
ARAMA = 100              # arama kutusu (`q`)
HUCRE = 1000             # ice aktarim satirinda tek hucre
BLOK = 32                # blok adi (unit.blok)
DAIRE_NO = 50            # daire no (unit.no)
NFC_UID = 64             # NFC etiket kimligi (7 bayt hex = 14; payli)
IBAN = 42                # 34 karakter + bosluklar
SAAT_DILIMI = 64         # IANA adi ("America/Argentina/ComodRivadavia" = 32)
MT940 = 2_000_000        # banka ekstresi dosya METNI (govde siniri 5 MB altinda)

#: Istemcilerin tasidigi sabitler (kilit bunlari web/mobil ile karsilastirir).
ISTEMCI_SABITLERI = {
    "AD": AD, "BASLIK": BASLIK, "EPOSTA": EPOSTA, "PAROLA": PAROLA,
    "GIZLI": GIZLI, "URL": URL, "ADRES": ADRES, "NOT": NOT,
    "UZUN_NOT": UZUN_NOT, "UZUN_METIN": UZUN_METIN, "YASAL_METIN": YASAL_METIN,
    "KOD": KOD, "SLUG": SLUG, "DOSYA_ADI": DOSYA_ADI, "ARAMA": ARAMA,
    "BLOK": BLOK, "DAIRE_NO": DAIRE_NO, "NFC_UID": NFC_UID, "IBAN": IBAN,
}

#: Dar sayilan en buyuk genel sinir; ustu gerekceli istisna ister.
GENEL_UST = UZUN_METIN

#: (alan adi deseni, tavan, sinif) — ILK eslesen kural gecerli.
SINIF_KURALLARI: tuple[tuple[re.Pattern[str], int, str], ...] = tuple(
    (re.compile(d), t, s) for d, t, s in (
        (r"^(kimlik|smtp_gonderen)$|(^|_)(email|eposta)$", EPOSTA, "e-posta"),
        (r"(^|_)(telefon|phone|whatsapp)$", 40, "telefon"),
        (r"(^|_)(password|parola|sifre)$", GIZLI, "parola/gizli"),
        (r"(^|_)url$", URL, "url"),
        (r"(^|_)(jeton|token|refresh_token|setup_token)$", JETON, "jeton"),
        (r"(^|_)(key|anahtari)$", DOSYA_ANAHTARI * 2, "anahtar"),
        (r"(^|_)slug$", SLUG, "slug"),
        (r"(^|_)(ad|soyad|ad_soyad)$", BASLIK, "ad"),
        (r"(^|_)(baslik|konu|title)$", 500, "baslik"),
        (r"^(adres|adres_detay|acik_adres)$", ADRES, "adres"),
        (r"(^|_)(not|not_|notlar|not_metni|note|aciklama|mesaj|message|"
         r"gerekce|sebep|neden|cozum_notu|kapanis_notu|admin_cevap)$",
         UZUN_NOT, "not"),
        (r"(^|_)(kod|no|surum|tip|tur|durum|rol|dil|yon|kaynak)$", 128, "kod"),
    )
)

#: GENEL_UST'u asan bilincli alanlar: (sinif, alan) -> gerekce.
UZUN_ISTISNALAR: dict[tuple[str, str], str] = {
    ("KvkkMetinCreate", "govde"):
        "KVKK aydinlatma metni: mevzuat metni, 100.000 karaktere kadar (YASAL_METIN)",
    ("BankaIceAktarIstek", "mt940"):
        "banka ekstresi dosya METNI JSON'da tasiniyor; 5 MB govde siniri altinda",
}


def sinif_tavani(alan_adi: str) -> tuple[int, str] | None:
    for desen, tavan, sinif in SINIF_KURALLARI:
        if desen.search(alan_adi):
            return tavan, sinif
    return None
