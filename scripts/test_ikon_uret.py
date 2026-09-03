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

    if hata:
        print("BASARISIZ:")
        for h in hata:
            print("  - " + h)
        return 1
    print(f"ikon kilidi GECTI (on katman {g}x{d} <= {sinir})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
