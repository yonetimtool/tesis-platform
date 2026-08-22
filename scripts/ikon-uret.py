#!/usr/bin/env python3
"""(P177 §8) MOBIL IKON + FAVICON URETICISI — tek kaynak, tekrar kosulabilir.

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
KULLANIM
===========================================================================
    python3 scripts/ikon-uret.py            # uret + dogrula
    python3 scripts/ikon-uret.py --onizle   # ek olarak ASCII onizleme

Cikti: assets/marka/ikon/
"""
from __future__ import annotations

import importlib.util
import os
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KAYNAK = os.path.join(KOK, "assets", "marka", "yonetiyor-logo.png")
CIKTI_DIZIN = os.path.join(KOK, "assets", "marka", "ikon")

# --- olculen kaynak ozellikleri (dogrulama icin; uydurulmadi) -------------
BEKLENEN_BOYUT = (1072, 992)
BEKLENEN_SINIR = (303, 182, 768, 810)  # sol, ust, sag, alt (KAPSAYICI)

# --- KARAR VERILDI: kirpma kutusu (sag/alt DISLAYICI) --------------------
KUTU = (303, 182, 769, 641)  # -> 466 x 459

# --- Tuvalde markanin kapladigi oran -------------------------------------
#: Magaza ikonu. Apple'in kendi kilavuzu kenar boslugu birakmayi onerir;
#: %72 hem nefes payi birakir hem 1024'te isareti buyuk tutar.
ORAN_MAGAZA = 0.72
#: Android uyarlanabilir (adaptive) katman. Dis %17 her maskede kirpilir;
#: %66 Android'in kendi belgeledigi GUVENLI BOLGE oranidir.
ORAN_ADAPTIF = 0.66

#: Adaptif zemin katmani rengi — KARAR VERILDI: DUZ BEYAZ.
#: Gerekce docs/P177-kararlar.md'de (olculmus L* farkiyla birlikte).
ADAPTIF_ZEMIN = (0xFF, 0xFF, 0xFF)
BEYAZ = (0xFF, 0xFF, 0xFF)


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
    if (en, boy) != BEKLENEN_BOYUT:
        raise SystemExit(
            f"kaynak boyutu degismis: {en}x{boy}, beklenen {BEKLENEN_BOYUT}. "
            "Kirpma kutusu (KUTU) bu olcume dayaniyor — elle gozden gecirin."
        )
    px = pa.rgba_yap(en, boy, kanal, px)
    olculen = _sinir_kutusu(en, boy, px)
    if olculen != BEKLENEN_SINIR:
        raise SystemExit(
            f"markanin sinir kutusu degismis: {olculen}, beklenen "
            f"{BEKLENEN_SINIR}. Kirpma kutusu elle gozden gecirilmeli."
        )
    return en, boy, px


def _isaret():
    """Kirpilmis isaret: (en, boy, rgba)."""
    en, boy, px = _kaynagi_oku()
    return pa.kutu_kirp(en, boy, px, *KUTU)


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


def _yol(ad):
    return os.path.join(CIKTI_DIZIN, ad)


def uret(onizle=False):
    os.makedirs(CIKTI_DIZIN, exist_ok=True)
    isaret = _isaret()
    print(f"kirpma {KUTU} -> isaret {isaret[0]}x{isaret[1]}")
    if onizle:
        _onizle(*isaret)

    olcumler = {}

    # --- 1) iOS App Store: 1024, ALFASIZ, duz beyaz, yuvarlak kose YOK ---
    # Yuvarlak kose CIZILMEZ: iOS maskeyi kendisi uygular; bizim cizdigimiz
    # kose, sistemin maskesiyle ust uste binip cift kenar birakirdi.
    tuval, olcu = _tuvale_otur(1024, ORAN_MAGAZA, isaret, BEYAZ)
    pa.yaz_opak(_yol("ios-appstore-1024.png"), 1024, 1024, tuval, BEYAZ)
    olcumler["ios-appstore-1024.png"] = (1024, olcu)

    # --- 2) Android adaptif ON KATMAN: saydam, %66 guvenli bolge ---------
    on, olcu_on = _tuvale_otur(1024, ORAN_ADAPTIF, isaret, None)
    pa.yaz(_yol("android-adaptive-foreground.png"), 1024, 1024, on)
    olcumler["android-adaptive-foreground.png"] = (1024, olcu_on)

    # --- 3) Android adaptif ZEMIN: duz renk ------------------------------
    pa.yaz(
        _yol("android-adaptive-background.png"),
        1024, 1024, pa.bos_tuval(1024, ADAPTIF_ZEMIN),
    )

    # --- 4) Android 13+ TEMALI IKON: tek renk beyaz siluet, saydam -------
    mono, olcu_mono = _tuvale_otur(1024, ORAN_ADAPTIF, isaret, None)
    pa.beyaza_boya(1024, 1024, mono)
    pa.yaz(_yol("android-monochrome.png"), 1024, 1024, mono)
    olcumler["android-monochrome.png"] = (1024, olcu_mono)

    # --- 5) Play Store: 512, ALFASIZ, beyaz zemin ------------------------
    tuval, olcu = _tuvale_otur(512, ORAN_MAGAZA, isaret, BEYAZ)
    pa.yaz_opak(_yol("play-store-512.png"), 512, 512, tuval, BEYAZ)
    olcumler["play-store-512.png"] = (512, olcu)

    # --- 6) apple-touch-icon: 180, ALFASIZ -------------------------------
    tuval, olcu = _tuvale_otur(180, ORAN_MAGAZA, isaret, BEYAZ)
    pa.yaz_opak(_yol("apple-touch-icon.png"), 180, 180, tuval, BEYAZ)
    olcumler["apple-touch-icon.png"] = (180, olcu)

    # --- 7) PWA manifest ikonlari: 192 / 512 -----------------------------
    # BEYAZ ZEMINLI ve bu bilincli: `purpose: "any"` ikonu bazi
    # baslaticilarda DUZ cizilir; saydam zeminli koyu lacivert bir isaret
    # koyu temada kaybolurdu.
    for kenar in (192, 512):
        tuval, olcu = _tuvale_otur(kenar, ORAN_MAGAZA, isaret, BEYAZ)
        pa.yaz_opak(_yol(f"icon-{kenar}.png"), kenar, kenar, tuval, BEYAZ)
        olcumler[f"icon-{kenar}.png"] = (kenar, olcu)

    # --- 8) TANITIM SITESI KILIDI: saydam, DOLGUSUZ kare -----------------
    # Tuvale oturtma YOK (`oran=1.0`): baslik kilidinde isaret 36 px
    # yuksekliginde cizilir ve ikon paylari orada isareti okunmaz kilardi.
    # Iki varyant: koyu murekkep (acik zemin) ve beyaz siluet (koyu
    # altbilgi). Ayni dosyayi iki yerde kullanmak, altbilgide lacivert
    # bir lekeye bakmak demekti.
    web, _ = _tuvale_otur(160, 1.0, isaret, None)
    pa.yaz(_yol("web-marka-160.png"), 160, 160, web)
    webBeyaz, _ = _tuvale_otur(160, 1.0, isaret, None)
    pa.beyaza_boya(160, 160, webBeyaz)
    pa.yaz(_yol("web-marka-beyaz-160.png"), 160, 160, webBeyaz)

    # --- 9) favicon.ico: 16 / 32 / 48 ------------------------------------
    # BEYAZ ZEMIN: marka murekkebi koyu lacivert; saydam favicon, koyu
    # temali tarayici sekme seridinde neredeyse gorunmez olurdu.
    katmanlar = []
    for kenar in (16, 32, 48):
        tuval, _ = _tuvale_otur(kenar, ORAN_MAGAZA, isaret, BEYAZ)
        katmanlar.append((kenar, tuval))
    pa.ico_yaz(_yol("favicon.ico"), katmanlar)

    return olcumler, olcu_on


def dogrula(olcumler, olcu_on):
    """ALFA KONTROLU + %66 guvenli bolge kontrolu. Basarisizsa cikis 1."""
    hata = []
    rapor = []

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

    print("\n=== DOGRULAMA ===")
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


if __name__ == "__main__":
    olcumler, olcu_on = uret(onizle="--onizle" in sys.argv)
    for ad, (kenar, olcu) in olcumler.items():
        print(f"  {ad:34s} {kenar}x{kenar}  isaret {olcu[0]}x{olcu[1]}")
    tamam, _, _ = dogrula(olcumler, olcu_on)
    sys.exit(0 if tamam else 1)
