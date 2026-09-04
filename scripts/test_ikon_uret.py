#!/usr/bin/env python3
"""(P211 §7) IKON BORUSUNUN KILIDI — Mac/PIL olmadan kosar.

===========================================================================
NE OLCUYOR
===========================================================================
Ikon uretimi, kaynagi bir gun degistiginde SESSIZCE bozulabilecek bir
zincir: kirpma kutusu kaynaga bagli, magaza ikonlari alfa TASIYAMAZ
(ITMS-90717), Android on katmani %66 guvenli bolgeyi ASAMAZ. Bu dosya
uc seyi kilitler:

  1. `--olc` kipi CALISIR ve yapistirilabilir sabitler ONERIR — yeni
     logo geldiginde betigin kullanilabilir olmasi bunun uzerinde,
  2. YAYINDAKI ciktilar alfa kuralina uyuyor,
  3. Android on katmani %66 sinirinda.

Kosum:  python3 scripts/test_ikon_uret.py   (cikis kodu 0 = gecti)
"""
from __future__ import annotations

import importlib.util
import os
import subprocess
import sys

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IKON = os.path.join(KOK, "assets", "marka", "ikon")
BETIK = os.path.join(KOK, "scripts", "ikon-uret.py")

ALFASIZ = [
    "ios-appstore-1024.png",
    "play-store-512.png",
    "apple-touch-icon.png",
    "icon-192.png",
    "icon-512.png",
]
SAYDAM = ["android-adaptive-foreground.png", "android-monochrome.png"]
ORAN_ADAPTIF = 0.66

#: (P211-ek2) LOGODAN TUREYEN, BASKA PROJELERE YAZILAN dosyalar.
#: Bildirim ikonu ve acilis logosu BEYAZ SILUET + SAYDAM olmak zorunda:
#: Android bildirim ikonunu alfa maskesi olarak boyar (renk atilir) ve
#: acilis ekraninin zemini LACIVERTTIR — lacivert bir isaret orada
#: gorunmezdi (olculen eski durum tam olarak buydu).
MOBIL_RES = "mobile/android/app/src/main/res"
BEYAZ_SILUET = [
    f"{MOBIL_RES}/drawable-{y}/{ad}.png"
    for ad in ("ic_stat_yonetio", "splash_logo")
    for y in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")
]
#: Web yuzeylerinin kopyalari — elle tasindigi surece geride kaliyorlardi.
WEB_KOPYALARI = [
    ("assets/marka/ikon/favicon.ico", "apps/tanitim-web/public/marka/favicon.ico"),
    ("assets/marka/ikon/icon-192.png", "apps/tanitim-web/public/marka/icon-192.png"),
    ("assets/marka/ikon/icon-512.png", "apps/tanitim-web/public/marka/icon-512.png"),
    ("assets/marka/ikon/apple-touch-icon.png",
     "apps/tanitim-web/public/marka/apple-touch-icon.png"),
    ("assets/marka/ikon/web-marka-160.png",
     "apps/tanitim-web/public/marka/web-marka-160.png"),
    ("assets/marka/ikon/web-marka-beyaz-160.png",
     "apps/tanitim-web/public/marka/web-marka-beyaz-160.png"),
    ("assets/marka/ikon/icon-512.png", "admin-web/app/icon.png"),
]


def _arac():
    yol = os.path.join(KOK, "tools", "png-arac.py")
    spec = importlib.util.spec_from_file_location("png_arac", yol)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def main() -> int:
    pa = _arac()
    hata: list[str] = []

    # 1) OLCUM KIPI — yeni logo yolunun ilk adimi.
    r = subprocess.run(
        [sys.executable, BETIK, "--olc"], capture_output=True, text=True
    )
    if r.returncode != 0:
        hata.append(f"--olc cikis kodu {r.returncode}")
    for beklenen in ("alfa sinir", "KUTU = (", "--kaynak-onay"):
        if beklenen not in r.stdout:
            hata.append(f"--olc ciktisinda '{beklenen}' yok")

    # 2) ALFA KURALI — magaza ikonlari alfa TASIYAMAZ (ITMS-90717).
    for ad in ALFASIZ:
        if pa.alfa_var_mi(os.path.join(IKON, ad)):
            hata.append(f"{ad} ALFA TASIYOR (App Store reddi)")
    for ad in SAYDAM:
        if not pa.alfa_var_mi(os.path.join(IKON, ad)):
            hata.append(f"{ad} SAYDAM DEGIL")

    # 3) %66 GUVENLI BOLGE — disi her maskede kirpilir.
    yol = os.path.join(IKON, "android-adaptive-foreground.png")
    en, boy, kanal, px = pa.oku(yol)
    px = pa.rgba_yap(en, boy, kanal, px)
    ust, alt, sol, sag = boy, -1, en, -1
    for y in range(boy):
        for x in range(en):
            if px[((y * en) + x) * 4 + 3] > 8:
                ust, alt = min(ust, y), max(alt, y)
                sol, sag = min(sol, x), max(sag, x)
    g, d = sag - sol + 1, alt - ust + 1
    sinir = int(en * ORAN_ADAPTIF)
    if g > sinir or d > sinir:
        hata.append(f"on katman %66 bolgesini asiyor: {g}x{d} > {sinir}")

    # 4) BEYAZ SILUET + SAYDAM (bildirim ikonu, acilis logosu).
    for yol in BEYAZ_SILUET:
        tam = os.path.join(KOK, yol)
        if not os.path.exists(tam):
            hata.append(f"{yol} YOK")
            continue
        en, boy, kanal, p2 = pa.oku(tam)
        p2 = pa.rgba_yap(en, boy, kanal, p2)
        opak = [(p2[i * 4], p2[i * 4 + 1], p2[i * 4 + 2])
                for i in range(en * boy) if p2[i * 4 + 3] > 200]
        if not opak:
            hata.append(f"{yol} BOS (hic opak piksel yok)")
        elif not all(r > 240 and g > 240 and b > 240 for r, g, b in opak):
            hata.append(f"{yol} BEYAZ SILUET DEGIL")
        if not any(p2[i * 4 + 3] < 8 for i in range(en * boy)):
            hata.append(f"{yol} SAYDAM DEGIL")

    # 5) WEB KOPYALARI GERIDE KALMASIN — birebir ayni dosya olmali.
    import hashlib

    def _ozet(y):
        return hashlib.md5(open(os.path.join(KOK, y), "rb").read()).hexdigest()

    for kaynak, kopya in WEB_KOPYALARI:
        try:
            if _ozet(kaynak) != _ozet(kopya):
                hata.append(f"{kopya} URETILEN SETTEN FARKLI (geride kalmis)")
        except FileNotFoundError as e:
            hata.append(f"{kopya} okunamadi: {e}")

    if hata:
        print("BASARISIZ:")
        for h in hata:
            print("  - " + h)
        return 1
    print(f"ikon kilidi GECTI (on katman {g}x{d} <= {sinir})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
