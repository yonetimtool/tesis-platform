#!/usr/bin/env python3
"""IZLENMEYEN KAYNAK DENETIMI — "yapi referans veriyor ama depoda yok".

NEDEN VAR: bu hata sinifi depoda **iki kez** gerceklesti ve ikisinde de
`git status` TEMIZ gorundugu icin fark edilmedi:

  1. `android/app/src/main/res/xml/network_security_config.xml` —
     AndroidManifest `android:networkSecurityConfig` ile referans veriyor,
     dosya hic commit'lenmemis. Taze klonda Android yapisi "resource not
     found" ile duserdi.
  2. `ios/Runner/PrivacyInfo.xcprivacy` + `Runner.entitlements` +
     `en/tr.lproj/InfoPlist.strings` + alti simge (P114) — Kerem'in taze
     klonunda YOKTU. `project.pbxproj` IZLENDIGI icin guncellendi ve bu
     dosyalara referans verdi; yani depo "tutarli gorunup" eksikti.

Ikisinin de kok nedeni ayni: kok `.gitignore`da `mobile/android/` ve
`mobile/ios/` toptan yok sayiliyordu. Kural kaldirildi; bu betik de
AYNI SINIFIN tekrarlamasini yakalar.

OLCTUGU SEY: yapi yapilandirmasinin (pbxproj, asset katalogu,
AndroidManifest, pubspec) adini gectigi her dosya `git ls-files`ta VAR mi.

BILINCLI ISTISNALAR asagida ADIYLA ve GEREKCESIYLE yazilidir; sessiz bir
"ignore listesi" degildir — her istisna, dosyanin ARACLAR TARAFINDAN
URETILDIGI (yani klonda eksik olmasinin sorun olmadigi) anlamina gelir.

Kullanim:  python3 infra/izlenmeyen-kaynak.py   (cikis 0 = temiz)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parent.parent

#: URETILEN dosyalar — klonda bulunmamalari DOGRUDUR; ilk `flutter pub get`
#: / `flutter build` bunlari yeniden yazar. Adiyla ve gerekcesiyle:
URETILEN = {
    # Flutter eklenti kaydi; her `pub get`te yeniden uretilir.
    "GeneratedPluginRegistrant.h",
    "GeneratedPluginRegistrant.m",
    "GeneratedPluginRegistrant.java",
    # Flutter'in derleme-zamani yapilandirmasi (yol/surum bilgisi tasir;
    # makineye ozeldir ve commit'lenmesi zararlidir).
    "Generated.xcconfig",
    "flutter_export_environment.sh",
}


def izlenen_dosyalar() -> set[str]:
    ciktisi = subprocess.run(
        ["git", "ls-files"], cwd=KOK, capture_output=True, text=True, check=True
    ).stdout
    return set(ciktisi.splitlines())


IZLENEN = izlenen_dosyalar()
bulgular: list[tuple[str, str, str]] = []


def kontrol(yol: Path, kaynak: str) -> None:
    """Bir referansin karsiligini denetle."""
    if yol.name in URETILEN:
        return
    # Dizin referansi (asset katalogu gibi): git dizin degil ICERIK izler.
    if yol.is_dir():
        icerik = [
            p for p in IZLENEN if p.startswith(str(yol.relative_to(KOK)) + "/")
        ]
        if not icerik:
            bulgular.append(("DIZIN ICERIGI HIC IZLENMIYOR", str(yol), kaynak))
        return
    goreli = str(yol.relative_to(KOK)) if yol.is_absolute() else str(yol)
    if goreli in IZLENEN:
        return
    if not yol.exists():
        bulgular.append(("DISKTE DE YOK", goreli, kaynak))
        return
    r = subprocess.run(
        ["git", "check-ignore", "-v", goreli], cwd=KOK, capture_output=True, text=True
    )
    kural = r.stdout.strip().split("\t")[0] if r.returncode == 0 else "(ignore kurali yok)"
    bulgular.append((f"IZLENMIYOR <- {kural}", goreli, kaynak))


def _coz(ios_kok: Path, yol: str) -> Path | None:
    """pbxproj `path` degerini gercek dosyaya cozer.

    pbxproj yollari GRUBA GOREDIR ve grup hiyerarsisi burada
    ayristirilmiyor; bu yuzden once bilinen koklar denenir, olmazsa
    agacta ADA gore aranir. Coz(ulemezse) `None` doner ve cagiran
    sessizce gecer — yanlis alarm uretmek, aracin susturulmasina yol
    acar (tur 47 dersi).
    """
    for aday in (ios_kok / "Runner" / yol, ios_kok / yol, ios_kok.parent / yol):
        if aday.exists():
            return aday
    eslesme = list(ios_kok.rglob(Path(yol).name))
    return eslesme[0] if len(eslesme) == 1 else None


# --- 1) Xcode proje dosya referanslari --------------------------------------
for pbx in KOK.rglob("*.xcodeproj/project.pbxproj"):
    ios_kok = pbx.parent.parent
    govde = pbx.read_text()
    for m in re.finditer(r"isa = PBXFileReference;[^}]*?path = ([^;]+);", govde):
        p = m.group(1).strip().strip('"')
        # Derleme CIKTILARI (BUILT_PRODUCTS_DIR) ve ephemeral paketler.
        if p.endswith((".app", ".xctest", ".framework")) or "ephemeral" in p:
            continue
        cozulen = _coz(ios_kok, p)
        if cozulen is not None:
            kontrol(cozulen, str(pbx.relative_to(KOK)))

# --- 2) Asset kataloglari ---------------------------------------------------
for c in KOK.rglob("*.xcassets/**/Contents.json"):
    try:
        veri = json.loads(c.read_text())
    except json.JSONDecodeError:
        continue
    for anahtar in ("images", "assets"):
        for oge in veri.get(anahtar, []):
            if isinstance(oge, dict) and oge.get("filename"):
                kontrol(c.parent / oge["filename"], str(c.relative_to(KOK)))

# --- 3) AndroidManifest kaynak referanslari ---------------------------------
for man in KOK.rglob("AndroidManifest.xml"):
    if "/build/" in str(man):
        continue
    res = man.parent / "res"
    for tur, ad in re.findall(r'"@(xml|drawable|mipmap)/([A-Za-z0-9_]+)"', man.read_text()):
        adaylar = list(res.glob(f"{tur}*/{ad}.*"))
        if not adaylar:
            bulgular.append(
                ("REFERANS KARSILIKSIZ", f"@{tur}/{ad}", str(man.relative_to(KOK)))
            )
            continue
        for a in adaylar:
            kontrol(a, str(man.relative_to(KOK)))

# --- 4) pubspec varliklari --------------------------------------------------
for ps in KOK.rglob("pubspec.yaml"):
    if "/build/" in str(ps) or "/.dart_tool/" in str(ps):
        continue
    icinde = False
    for satir in ps.read_text().splitlines():
        if re.match(r"^\s{2}assets:\s*$", satir):
            icinde = True
            continue
        if not icinde:
            continue
        m = re.match(r"^\s{4}-\s+(\S+)\s*$", satir)
        if not m:
            if satir.strip() and not satir.startswith("      "):
                icinde = False
            continue
        hedef = ps.parent / m.group(1)
        if m.group(1).endswith("/"):
            if not hedef.exists():
                bulgular.append(("DIZIN YOK", str(hedef), str(ps.relative_to(KOK))))
            else:
                for f in sorted(hedef.iterdir()):
                    if f.is_file():
                        kontrol(f, str(ps.relative_to(KOK)))
        else:
            kontrol(hedef, str(ps.relative_to(KOK)))

# --- rapor ------------------------------------------------------------------
if not bulgular:
    print("bulgu: 0 — yapi yapilandirmasinin referans verdigi her dosya izleniyor.")
    sys.exit(0)

print(f"bulgu: {len(bulgular)}")
for durum, yol, kaynak in bulgular:
    print(f"  {durum}\n    dosya : {yol}\n    kaynak: {kaynak}")
print(
    "\nTAZE KLONDA BU DOSYALAR OLMAYACAK. Kaynak/yapilandirma ise `git add`\n"
    "edin; gercekten uretilen bir dosyaysa betikteki URETILEN kumesine\n"
    "ADIYLA VE GEREKCESIYLE ekleyin."
)
sys.exit(1)
