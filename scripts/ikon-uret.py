#!/usr/bin/env python3
"""(P177 §8 / P184 ek) MOBIL IKON + FAVICON URETICISI — tek kaynak, tekrar kosulabilir.

===========================================================================
NEDEN BETIK, NEDEN ELLE DEGIL
===========================================================================
Magaza ikonlari elle uretildiginde iki sey oluyor: (1) hangi kirpmadan
hangi boyutun ciktigi kimsenin hatirlamadigi bir bilgi hâline geliyor,
(2) logo guncellendiginde dokuz dosyanin birkaci unutuluyor. Bu betik
ikisini de kapatir: kaynak TEK dosya (`assets/marka/yonetiyor-logo.png`),
kararlar sabit olarak burada yazili, cikti her kosumda AYNI.

Bagimlilik YOK: `tools/png-arac.py` saf Python'dur (zlib stdlib'de).
Bu makinede PIL/ImageMagick/sharp kurulu degil ve uretim paketine
girmeyecek bir is icin ucuncu parti kurmak dogru olmazdi.

===========================================================================
KIRPMA KUTUSU — KARAR VERILDI (bkz. docs/P177-kararlar.md)
===========================================================================
Kaynak 1072x992 RGBA. Markanin ALFA SINIR KUTUSU olculdu:
(303, 182) - (768, 810), yani 466x629 — DIKEY bir isaret.

Kirpma: (sol=303, ust=182, sag=769, alt=641) -> 466x459, neredeyse kare.
Altigen + kisa govde. Gerekce:
  * TAM marka dikey oldugu icin kare tuvale oturtuldugunda 48 px'lik
    launcher boyutunda insan figurleri okunmuyor;
  * yalniz altigeni kirpmak ise alttaki govdeyi yok edip markayi
    taninmaz kiliyor.

`kutu_kirp()` kullaniliyor, `kirp()` DEGIL: kutu bir KARARDIR ve her
kosumda yeniden OLCULMEMELIDIR. Kaynak dosya bir gun degisirse kutu da
bilincli olarak yeniden secilmeli, sessizce kaymamali. Betik kaynagin
boyutunu ve sinir kutusunu DOGRULAR ve uymuyorsa ACIKCA durur.

===========================================================================
ZEMIN VARYANTLARI (P184) — KARSILASTIRMA + SECIM
===========================================================================
Eski karar duz BEYAZ zemindi; launcher'da isaret kirpilmis/zoom'lu
gorunuyordu (asil sebep: flutter_launcher_icons kaynak degistikten sonra
tekrar kosulmamis, gomulu mipmap'ler bayat kalmisti). Bu turda iki zemin
varyanti URETILIR ki karsilastirilabilsin:

  * "acik"     -> zemin #EAF1FA (acik mavi), isaret OLDUGU GIBI (lacivert)
  * "lacivert" -> zemin #102060 (lacivert), isaret BEYAZ SILUET
                  (lacivert logo koyu zeminde gorunmez; `beyaza_boya`)

VARSAYILAN: "lacivert". Modern, ayirt edici, isaret one cikiyor. Magaza
ikonu (iOS 1024 / Play 512 / apple-touch) da AYNI zemin+siluet ile
uretilir ki magazalar arasi tutarli olsun. Alfasiz olmasi gerekenler
`yaz_opak` ile GERCEKTEN alfasiz yazilir (ITMS-90717).

===========================================================================
KULLANIM
===========================================================================
    python3 scripts/ikon-uret.py                 # her iki onizleme + VARSAYILANI ikon/'a yaz
    python3 scripts/ikon-uret.py --varsayilan acik   # varsayilani "acik" yap
    python3 scripts/ikon-uret.py --onizle        # ek olarak ASCII onizleme

Cikti:
    assets/marka/ikon/                 (flutter_launcher_icons'un okudugu — VARSAYILAN varyant)
    assets/marka/ikon-onizleme/acik/       (tam onizleme seti)
    assets/marka/ikon-onizleme/lacivert/   (tam onizleme seti)
"""
from __future__ import annotations

import importlib.util
import os
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KAYNAK = os.path.join(KOK, "assets", "marka", "yonetiyor-logo.png")
CIKTI_DIZIN = os.path.join(KOK, "assets", "marka", "ikon")
#: (P211-ek2) TUKETEN PROJELER. Ikonlar burada uretilip ORAYA da yazilir.
#: NEDEN TEK KOMUT: P184'te olculen kusur "araci kosmayi unutmak"ti;
#: ciktiyi elle kopyalamak da ayni sinifin ikinci yarisi — kopya bir gun
#: geride kalir ve kimse fark etmez (nitekim favicon'lar eski logoda
#: kalmisti).
MOBIL_RES = os.path.join(KOK, "mobile", "android", "app", "src", "main", "res")
TANITIM_MARKA = os.path.join(KOK, "apps", "tanitim-web", "public", "marka")
ADMIN_IKON = os.path.join(KOK, "admin-web", "app", "icon.png")
ONIZLEME_DIZIN = os.path.join(KOK, "assets", "marka", "ikon-onizleme")

# --- olculen kaynak ozellikleri (dogrulama icin; uydurulmadi) -------------
#: (P211-ek) YENI LOGO (2026-09-03): arka plani kaldirilmis, %87 saydam,
#: 512x512 RGBA. Isaret lacivert (#002060 - #2060A0).
#: OLCULDU: `--olc` kipi ile; degerler elle sayilmadi.
BEKLENEN_BOYUT = (512, 512)
BEKLENEN_SINIR = (144, 93, 367, 418)  # sol, ust, sag, alt (KAPSAYICI)

# --- KARAR VERILDI: kirpma kutusu (sag/alt DISLAYICI) --------------------
#: (P211-ek) TAM MARKA, KARE KUTU -> 326x326.
#: Eski kaynakta govdenin bir kismi KIRPILIYORDU (466x459) cunku o dosyada
#: isaret 466x629 ile cok uzundu ve 48 px'te figurler okunmuyordu. YENI
#: logo daha derli toplu (224x326) ve tamami kare kutuya sigiyor: gövdeyi
#: kesmeye GEREK KALMADI — marka butun haliyle cikiyor.
KUTU = (93, 93, 419, 419)  # -> 326 x 326

#: (P211 §7) YENI LOGO GELDIGINDE: `--kutu` ve `--kaynak-onay` ile
#: sabitleri DEGISTIRMEDEN kosulabilir. Ikisi de acik birer INSAN
#: kararidir — betik kendi basina yeni kutuya gecmez.
KAYNAK_ONAY = False

# --- Tuvalde markanin kapladigi oran -------------------------------------
#: Magaza ikonu. Apple'in kendi kilavuzu kenar boslugu birakmayi onerir;
#: %72 hem nefes payi birakir hem 1024'te isareti buyuk tutar.
ORAN_MAGAZA = 0.72
#: Android uyarlanabilir (adaptive) katman. Dis %17 her maskede kirpilir;
#: %66 Android'in kendi belgeledigi GUVENLI BOLGE oranidir.
ORAN_ADAPTIF = 0.66

BEYAZ = (0xFF, 0xFF, 0xFF)

#: (P211-ek2) ANDROID BILDIRIM KUCUK IKONU — yogunluk -> piksel.
#: Android bu ikonu ALFA MASKESI olarak boyar: renk ATILIR, yalniz
#: saydamlik kalir. Bu yuzden BEYAZ SILUET + saydam zemin; renkli bir
#: ikon durum cubugunda bir lekeye donusur.
STAT_YOGUNLUKLARI = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72,
                     "xxxhdpi": 96}
#: Sistem ikonlarinda adet olan optik pay.
ORAN_STAT = 0.86

#: (P211-ek2) ACILIS EKRANI LOGOSU — yogunluk -> piksel. Launcher ikonu
#: 48dp icin olceklidir ve splash'ta bulanik kalirdi; ayri ve daha buyuk
#: bir drawable uretilir (`launch_background.xml` bunu ortalar).
SPLASH_YOGUNLUKLARI = {"mdpi": 96, "hdpi": 144, "xhdpi": 192,
                       "xxhdpi": 288, "xxxhdpi": 384}
ORAN_SPLASH = 0.86

# --- ZEMIN VARYANTLARI (P184) --------------------------------------------
#: Her varyant: zemin rengi + isaretin BEYAZ SILUETE cevrilip cevrilmeyecegi.
#: "acik"     -> acik mavi zemin, lacivert isaret oldugu gibi.
#: "lacivert" -> lacivert zemin, isaret beyaz siluet (koyu zeminde gorunsun).
VARYANTLAR = {
    # (P211-ek) VARSAYILAN ARTIK BEYAZ.
    #
    # Istek "zemin olmasin, sadece sekil" idi. TELEFON IKONU SAYDAM
    # OLAMAZ ve bu bir tercih degil, platform kurali:
    #   * iOS magaza ikonu alfa TASIYAMAZ (ITMS-90717) ve ana ekranda
    #     saydam pikseller SIYAH cikar,
    #   * Android adaptive ikonun ZEMIN KATMANI zorunludur; saydam
    #     birakilirsa launcher'a gore siyah/tanimsiz gorunur.
    # "Zeminsiz" gorunume en yakin sonuc DUZ BEYAZdir; isaret lacivert
    # kaldigi icin hem acik hem koyu temada okunur.
    #
    # SAYDAMLIK KORUNAN YERLER: Android on katmani, monokrom (Android 13
    # temali ikon) ve web marka gorselleri — onlar zaten alfali yaziliyor.
    "beyaz": {"zemin": (0xFF, 0xFF, 0xFF), "beyaz_siluet": False},
    "acik": {"zemin": (0xEA, 0xF1, 0xFA), "beyaz_siluet": False},
    "lacivert": {"zemin": (0x10, 0x20, 0x60), "beyaz_siluet": True},
}
VARSAYILAN_VARYANT = "beyaz"


def _arac():
    """`tools/png-arac.py`yi yol uzerinden yukler (tire iceren dosya adi)."""
    yol = os.path.join(KOK, "tools", "png-arac.py")
    spec = importlib.util.spec_from_file_location("png_arac", yol)
    modul = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modul)
    return modul


pa = _arac()


def _sinir_kutusu(en, boy, piksel, esik=8):
    ust, alt, sol, sag = boy, -1, en, -1
    for y in range(boy):
        satir = y * en
        for x in range(en):
            if piksel[(satir + x) * 4 + 3] > esik:
                if y < ust: ust = y
                if y > alt: alt = y
                if x < sol: sol = x
                if x > sag: sag = x
    return sol, ust, sag, alt


def _kaynagi_oku():
    en, boy, kanal, px = pa.oku(KAYNAK)
    px = pa.rgba_yap(en, boy, kanal, px)
    if KAYNAK_ONAY:
        # (P211 §7) YENI LOGO YOLU. Dogrulama ATLANIR ama sessizce degil:
        # kullanici `--olc` ile kutuyu OLCMUS ve `--kutu` ile ACIKCA
        # vermis olmali. Kutu bir KARARDIR; betigin kendi basina yeniden
        # olcmesi, markanin kirpmasinin sessizce kaymasi demekti.
        return en, boy, px
    if (en, boy) != BEKLENEN_BOYUT:
        raise SystemExit(
            f"kaynak boyutu degismis: {en}x{boy}, beklenen {BEKLENEN_BOYUT}. "
            "Kirpma kutusu (KUTU) bu olcume dayaniyor — elle gozden gecirin.\n"
            "YENI LOGO ICIN: `python3 scripts/ikon-uret.py --olc` ile olcun, "
            "sonra `--kutu sol,ust,sag,alt --kaynak-onay` ile kosun."
        )
    olculen = _sinir_kutusu(en, boy, px)
    if olculen != BEKLENEN_SINIR:
        raise SystemExit(
            f"markanin sinir kutusu degismis: {olculen}, beklenen "
            f"{BEKLENEN_SINIR}. Kirpma kutusu elle gozden gecirilmeli.\n"
            "YENI LOGO ICIN: `--olc` -> `--kutu ... --kaynak-onay`."
        )
    return en, boy, px


def olc():
    """(P211 §7) YENI KAYNAGI OLCER ve kirpma kutusu ONERIR — yazmaz.

    Neden ayri bir kip: betigin kutuyu her kosumda yeniden olcmesi
    yasak (karar sessizce kaymasin). Ama yeni bir logo geldiginde
    kullanicinin elle piksel saymasi da gercekci degil. Bu kip olcumu
    yapar, ONERIR ve yapistirmaya hazir satirlari basar; kutuyu
    kabul etmek yine INSANIN isi.
    """
    en, boy, kanal, px = pa.oku(KAYNAK)
    px = pa.rgba_yap(en, boy, kanal, px)
    sol, ust, sag, alt = _sinir_kutusu(en, boy, px)
    g, y = sag - sol + 1, alt - ust + 1
    print(f"kaynak      : {KAYNAK}")
    print(f"boyut       : {en}x{boy}")
    print(f"alfa sinir  : ({sol}, {ust}) - ({sag}, {alt})  ->  {g}x{y}")
    print(f"en/boy orani: {g / y:.3f} ({'yatay' if g > y else 'dikey'})")
    # ONERI: tam markayi KARE bir kutuya alir (kisa kenar uzun kenara
    # tamamlanir, merkezden). Kare oneri, tuvale oturtmada isareti en
    # buyuk tutar; dikey bir markada eski karar (govdeyi kismen kirpma)
    # gibi bir tercih gerekiyorsa ONU insan verir.
    kenar = max(g, y)
    ksol = max(0, sol - (kenar - g) // 2)
    kust = max(0, ust - (kenar - y) // 2)
    print("\nONERI (tam marka, kare kutu; sag/alt DISLAYICI):")
    print(f"    KUTU = ({ksol}, {kust}, {ksol + kenar}, {kust + kenar})")
    print("\nYAPISTIR (kalici hâle getirmek icin betikteki sabitler):")
    print(f"    BEKLENEN_BOYUT = ({en}, {boy})")
    print(f"    BEKLENEN_SINIR = ({sol}, {ust}, {sag}, {alt})")
    print(f"    KUTU = ({ksol}, {kust}, {ksol + kenar}, {kust + kenar})")
    print("\nDENEME KOSUMU (sabitleri degistirmeden):")
    print(f"    python3 scripts/ikon-uret.py --kutu {ksol},{kust},"
          f"{ksol + kenar},{kust + kenar} --kaynak-onay --onizle")


def _isaret(beyaz_siluet=False):
    """Kirpilmis isaret: (en, boy, rgba). `beyaz_siluet` ise beyaza boyanir."""
    en, boy, px = _kaynagi_oku()
    en, boy, kirpik = pa.kutu_kirp(en, boy, px, *KUTU)
    if beyaz_siluet:
        # Kaynagi BOZMADAN kopya uzerinde: her varyant temiz isaret alsin.
        kopya = bytearray(kirpik)
        pa.beyaza_boya(en, boy, kopya)
        return en, boy, kopya
    return en, boy, kirpik


def _tuvale_otur(kenar, oran, isaret, zemin=None):
    """Isareti `oran` kadar kaplayacak sekilde ORTALAYARAK tuvale oturtur."""
    en, boy, px = isaret
    # TABANA YUVARLAMA (round DEGIL): `%66'yi ASMAYACAK` bir sinirda
    # yukari yuvarlamak 1024*0.66 = 675.84'u 676 yapiyor ve kurali bir
    # pikselle ihlal ediyordu.
    hedef = int(kenar * oran)
    olcek = hedef / max(en, boy)
    yEn, yBoy = max(1, int(en * olcek)), max(1, int(boy * olcek))
    olcekli = pa.yeniden_boyutla(en, boy, px, yEn, yBoy)
    tuval = pa.bos_tuval(kenar, zemin)
    pa.uzerine_ciz(
        kenar, tuval, yEn, yBoy, olcekli, (kenar - yEn) // 2, (kenar - yBoy) // 2
    )
    return tuval, (yEn, yBoy)


def uret(varyant, cikti_dizin, onizle=False):
    """Bir zemin varyantinin TAM setini `cikti_dizin`e yazar.

    `varyant`: VARYANTLAR anahtari ("acik" | "lacivert").
    Doner: (olcumler dict, android on-katman isaret olcusu).
    """
    ayar = VARYANTLAR[varyant]
    zemin = tuple(ayar["zemin"])
    beyaz_siluet = ayar["beyaz_siluet"]

    os.makedirs(cikti_dizin, exist_ok=True)

    # Magaza/zemin ikonlari icin: siluet varyantinda isaret beyaz, degilse
    # olcusundeki lacivert. Adaptif ON KATMAN ile TEMALI IKON ise HER
    # varyantta beyaz siluettir (adaptif on katman saydam zemin uzerine
    # cizilir; lacivert zeminde beyaz isaret istiyoruz, acik zeminde ise
    # foreground yine lacivert isaret olabilir — asagida ayrica ele alinir).
    isaret_zemin = _isaret(beyaz_siluet=beyaz_siluet)
    isaret_koyu = _isaret(beyaz_siluet=False)  # her zaman orijinal (lacivert)
    isaret_beyaz = _isaret(beyaz_siluet=True)   # her zaman beyaz siluet

    print(f"[{varyant}] zemin #{zemin[0]:02X}{zemin[1]:02X}{zemin[2]:02X} "
          f"beyaz_siluet={beyaz_siluet} -> {cikti_dizin}")
    print(f"  kirpma {KUTU} -> isaret {isaret_zemin[0]}x{isaret_zemin[1]}")
    if onizle:
        _onizle(*isaret_zemin)

    def _yol(ad):
        return os.path.join(cikti_dizin, ad)

    # Adaptif ON KATMAN isareti: zemin duz renk oldugundan, isaret zemine
    # gore SECILIR — lacivert zeminde beyaz, acik zeminde lacivert.
    on_isaret = isaret_beyaz if beyaz_siluet else isaret_koyu

    olcumler = {}

    # --- 1) iOS App Store: 1024, ALFASIZ, varyant zemini, kose YOK -------
    # Yuvarlak kose CIZILMEZ: iOS maskeyi kendisi uygular; bizim cizdigimiz
    # kose, sistemin maskesiyle ust uste binip cift kenar birakirdi.
    tuval, olcu = _tuvale_otur(1024, ORAN_MAGAZA, on_isaret, zemin)
    pa.yaz_opak(_yol("ios-appstore-1024.png"), 1024, 1024, tuval, zemin)
    olcumler["ios-appstore-1024.png"] = (1024, olcu)

    # --- 2) Android adaptif ON KATMAN: saydam, %66 guvenli bolge --------
    on, olcu_on = _tuvale_otur(1024, ORAN_ADAPTIF, on_isaret, None)
    pa.yaz(_yol("android-adaptive-foreground.png"), 1024, 1024, on)
    olcumler["android-adaptive-foreground.png"] = (1024, olcu_on)

    # --- 3) Android adaptif ZEMIN: duz varyant rengi --------------------
    pa.yaz(
        _yol("android-adaptive-background.png"),
        1024, 1024, pa.bos_tuval(1024, zemin),
    )

    # --- 4) Android 13+ TEMALI IKON: tek renk beyaz siluet, saydam ------
    mono, olcu_mono = _tuvale_otur(1024, ORAN_ADAPTIF, isaret_beyaz, None)
    pa.yaz(_yol("android-monochrome.png"), 1024, 1024, mono)
    olcumler["android-monochrome.png"] = (1024, olcu_mono)

    # --- 5) Play Store: 512, ALFASIZ, varyant zemini --------------------
    tuval, olcu = _tuvale_otur(512, ORAN_MAGAZA, on_isaret, zemin)
    pa.yaz_opak(_yol("play-store-512.png"), 512, 512, tuval, zemin)
    olcumler["play-store-512.png"] = (512, olcu)

    # --- 6) apple-touch-icon: 180, ALFASIZ ------------------------------
    tuval, olcu = _tuvale_otur(180, ORAN_MAGAZA, on_isaret, zemin)
    pa.yaz_opak(_yol("apple-touch-icon.png"), 180, 180, tuval, zemin)
    olcumler["apple-touch-icon.png"] = (180, olcu)

    # --- 7) PWA manifest ikonlari: 192 / 512 ----------------------------
    # `purpose: "any"` ikonu bazi baslaticilarda DUZ cizilir; varyant
    # zeminiyle alfasiz yazilir ki koyu/acik temada tutarli gorunsun.
    for kenar in (192, 512):
        tuval, olcu = _tuvale_otur(kenar, ORAN_MAGAZA, on_isaret, zemin)
        pa.yaz_opak(_yol(f"icon-{kenar}.png"), kenar, kenar, tuval, zemin)
        olcumler[f"icon-{kenar}.png"] = (kenar, olcu)

    # --- 8) TANITIM SITESI KILIDI: saydam, DOLGUSUZ kare ----------------
    # Tuvale oturtma YOK (`oran=1.0`): baslik kilidinde isaret 36 px
    # yuksekliginde cizilir. Iki dosya: koyu murekkep (acik zemin) ve
    # beyaz siluet (koyu altbilgi). Zemin varyantindan BAGIMSIZ — tanitim
    # sitesinin iki kullanim yeri var ve ikisi de her zaman gerekir.
    web, _ = _tuvale_otur(160, 1.0, isaret_koyu, None)
    pa.yaz(_yol("web-marka-160.png"), 160, 160, web)
    webBeyaz, _ = _tuvale_otur(160, 1.0, isaret_beyaz, None)
    pa.yaz(_yol("web-marka-beyaz-160.png"), 160, 160, webBeyaz)

    # --- 9) favicon.ico: 16 / 32 / 48 -----------------------------------
    # Varyant zeminli: saydam favicon koyu temali sekme seridinde gorunmez.
    katmanlar = []
    for kenar in (16, 32, 48):
        tuval, _ = _tuvale_otur(kenar, ORAN_MAGAZA, on_isaret, zemin)
        katmanlar.append((kenar, tuval))
    pa.ico_yaz(_yol("favicon.ico"), katmanlar)

    return olcumler, olcu_on


def mobil_drawable_uret():
    """(P211-ek2) BILDIRIM KUCUK IKONU + ACILIS LOGOSU — tum yogunluklar.

    =======================================================================
    NEDEN ARTIK BURADA (kodla cizen arac DEGIL)
    =======================================================================
    Bu iki gorsel `mobile/test/tools/generate_branding_assets.dart` icinde
    KODLA CIZILEN basitlestirilmis bir isaretten uretiliyordu. Ana ekran
    ikonu yeni logoya gecince ikisi ESKI CIZIMDE kaldi: kullanicinin
    ana ekranda gordugu simge ile bildirim cubugunda gordugu isaret
    AYRISTI. Tek kaynak kurali burada da gecerli — ikisi de logodan
    turer.

    IKISI DE BEYAZ SILUET, SAYDAM ZEMIN:
      * bildirim ikonunu Android ALFA MASKESI olarak boyar (renk atilir),
      * acilis ekraninin zemini LACIVERTTIR (`@color/yonetio_navy`);
        lacivert bir isaret orada neredeyse gorunmezdi — olculen eski
        durum tam olarak buydu (opak renkler #002060/#004080).
    """
    isaret_beyaz = _isaret(beyaz_siluet=True)
    yazilan = []
    for ad, yogunluklar, oran in (
        ("ic_stat_yonetio", STAT_YOGUNLUKLARI, ORAN_STAT),
        ("splash_logo", SPLASH_YOGUNLUKLARI, ORAN_SPLASH),
    ):
        for yogunluk, kenar in yogunluklar.items():
            dizin = os.path.join(MOBIL_RES, f"drawable-{yogunluk}")
            if not os.path.isdir(dizin):
                raise SystemExit(f"yok: {dizin}")
            tuval, olcu = _tuvale_otur(kenar, oran, isaret_beyaz, None)
            yol = os.path.join(dizin, f"{ad}.png")
            pa.yaz(yol, kenar, kenar, tuval)
            yazilan.append((yol, kenar, olcu))
    print(f"\n>>> MOBIL DRAWABLE ({MOBIL_RES})")
    for yol, kenar, olcu in yazilan:
        kisa = os.path.join(*yol.split(os.sep)[-2:])
        print(f"  {kisa:38s} {kenar}x{kenar}  isaret {olcu[0]}x{olcu[1]}")
    return [y for y, _, _ in yazilan]


def web_kopyala():
    """(P211-ek2) WEB YUZEYLERININ FAVICON'LARI — ayni setten.

    Kopyalar elle tasindigi icin bir gun geride kalmisti: tanitim sitesi
    ve panel eski logoyla gorunurken uygulama yenilenmisti. Artik ayni
    komut yaziyor.
    """
    import shutil
    yazilan = []
    os.makedirs(TANITIM_MARKA, exist_ok=True)
    for ad in ("favicon.ico", "icon-192.png", "icon-512.png",
               "apple-touch-icon.png", "web-marka-160.png",
               "web-marka-beyaz-160.png"):
        hedef = os.path.join(TANITIM_MARKA, ad)
        shutil.copyfile(os.path.join(CIKTI_DIZIN, ad), hedef)
        yazilan.append(hedef)
    # Panelin favicon'u: Next `app/icon.png` dosyasini favicon olarak sunar.
    shutil.copyfile(os.path.join(CIKTI_DIZIN, "icon-512.png"), ADMIN_IKON)
    yazilan.append(ADMIN_IKON)
    print("\n>>> WEB KOPYALARI")
    for y in yazilan:
        print("  " + os.path.relpath(y, KOK))
    return yazilan


def dogrula(cikti_dizin, olcumler, olcu_on):
    """ALFA KONTROLU + %66 guvenli bolge kontrolu. Basarisizsa (False, ...)."""
    hata = []
    rapor = []

    def _yol(ad):
        return os.path.join(cikti_dizin, ad)

    # --- ALFASIZ OLMASI GEREKENLER ---
    # (§8) iOS ve Play ikonlari alfa TASIYAMAZ; alfali bir iOS ikonu
    # App Store yuklemesinde ITMS-90717 ile reddedilir.
    alfasiz = [
        "ios-appstore-1024.png",
        "play-store-512.png",
        "apple-touch-icon.png",
        "icon-192.png",
        "icon-512.png",
    ]
    for ad in alfasiz:
        var = pa.alfa_var_mi(_yol(ad))
        rapor.append(f"  {ad:34s} alfa kanali: {'VAR' if var else 'YOK'}")
        if var:
            hata.append(f"{ad} ALFA TASIYOR")

    # --- SAYDAM OLMASI GEREKENLER ---
    for ad in ("android-adaptive-foreground.png", "android-monochrome.png"):
        var = pa.alfa_var_mi(_yol(ad))
        rapor.append(f"  {ad:34s} alfa kanali: {'VAR' if var else 'YOK'}")
        if not var:
            hata.append(f"{ad} SAYDAM DEGIL")

    # --- %66 GUVENLI BOLGE ---
    yEn, yBoy = olcu_on
    sinir = int(1024 * ORAN_ADAPTIF)
    rapor.append(
        f"  android on katman isaret kutusu: {yEn}x{yBoy} "
        f"(sinir {sinir}x{sinir}) -> %{max(yEn, yBoy) / 1024 * 100:.1f}"
    )
    if yEn > sinir or yBoy > sinir:
        hata.append(f"android on katman %66 bolgesini asiyor: {yEn}x{yBoy}")

    # Dairesel maskede kose kaybi — OLCULUR, kural degil rapor.
    en, boy, kanal, px = pa.oku(_yol("android-adaptive-foreground.png"))
    px = pa.rgba_yap(en, boy, kanal, px)
    merkez = en / 2
    yaricap = en * ORAN_ADAPTIF / 2
    disarida = toplam = 0
    for y in range(0, en, 2):
        for x in range(0, en, 2):
            a = px[(y * en + x) * 4 + 3]
            if a <= 8:
                continue
            toplam += 1
            if ((x - merkez) ** 2 + (y - merkez) ** 2) ** 0.5 > yaricap:
                disarida += 1
    oran = (disarida / toplam * 100) if toplam else 0.0
    rapor.append(
        f"  dairesel maske disinda kalan isaret pikseli: %{oran:.2f} "
        "(kose bosluklari; kural degil olcum)"
    )

    print(f"\n=== DOGRULAMA ({cikti_dizin}) ===")
    for satir in rapor:
        print(satir)
    if hata:
        print("\nBASARISIZ:")
        for h in hata:
            print("  - " + h)
        return False, rapor, oran
    print("\nTUM DENETIMLER GECTI")
    return True, rapor, oran


def _onizle(en, boy, px, W=56, H=34):
    ramp = " .:-=+*#%@"
    print("--- kirpilan isaretin onizlemesi ---")
    for gy in range(H):
        satir = ""
        for gx in range(W):
            x, y = gx * en // W, gy * boy // H
            k = (y * en + x) * 4
            a = px[k + 3]
            lum = px[k] * 0.3 + px[k + 1] * 0.59 + px[k + 2] * 0.11
            satir += ramp[min(9, int(a / 255.0 * (1 - lum / 255.0) * 10))]
        print(satir)


def main(argv):
    global KUTU, KAYNAK_ONAY, KAYNAK
    if "--kaynak" in argv:
        KAYNAK = argv[argv.index("--kaynak") + 1]
    if "--olc" in argv:
        olc()
        return 0
    if "--kutu" in argv:
        p = argv[argv.index("--kutu") + 1].split(",")
        if len(p) != 4:
            raise SystemExit("--kutu sol,ust,sag,alt bicimindedir")
        KUTU = tuple(int(x) for x in p)
    if "--kaynak-onay" in argv:
        KAYNAK_ONAY = True
    onizle = "--onizle" in argv
    varsayilan = VARSAYILAN_VARYANT
    if "--varsayilan" in argv:
        varsayilan = argv[argv.index("--varsayilan") + 1]
    if varsayilan not in VARYANTLAR:
        raise SystemExit(f"bilinmeyen varyant: {varsayilan} / {list(VARYANTLAR)}")

    tum_gecti = True

    # 1) Her iki varyantin TAM onizleme setini uret + dogrula.
    for varyant in VARYANTLAR:
        dizin = os.path.join(ONIZLEME_DIZIN, varyant)
        olcumler, olcu_on = uret(varyant, dizin, onizle=onizle)
        for ad, (kenar, olcu) in olcumler.items():
            print(f"  {ad:34s} {kenar}x{kenar}  isaret {olcu[0]}x{olcu[1]}")
        tamam, _, _ = dogrula(dizin, olcumler, olcu_on)
        tum_gecti = tum_gecti and tamam

    # 2) VARSAYILAN varyanti gercek cikti dizinine (flutter kaynagi) yaz.
    print(f"\n>>> VARSAYILAN varyant '{varsayilan}' -> {CIKTI_DIZIN}")
    olcumler, olcu_on = uret(varsayilan, CIKTI_DIZIN, onizle=False)
    for ad, (kenar, olcu) in olcumler.items():
        print(f"  {ad:34s} {kenar}x{kenar}  isaret {olcu[0]}x{olcu[1]}")
    tamam, _, _ = dogrula(CIKTI_DIZIN, olcumler, olcu_on)
    tum_gecti = tum_gecti and tamam

    # 3) TUKETEN PROJELER — ayni komutta. Elle kopyalamak, kopyanin bir
    #    gun geride kalmasi demekti (olculdu: favicon'lar eski logodaydi).
    mobil_drawable_uret()
    web_kopyala()

    return 0 if tum_gecti else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
