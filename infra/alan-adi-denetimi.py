#!/usr/bin/env python3
"""(P120) IDN ALAN ADI DENETIMI — punycode elle yazilan her yeri olcer.

NEDEN VAR: gorev metni `yönetiyor.com`un punycode karsiligini
`xn--ynetiyor-vpb.com` diye veriyordu. YANLIS. Dogrusu
`xn--ynetiyor-n4a.com` (DNS'te dogrulandi: `-vpb` kayitli bile degil).
Yanlis bicimle devam edilseydi Caddy o ad icin sertifika almaya calisir,
ACME dogrulamasi surekli duser ve site HIC acilmazdi — ustelik hata
mesaji "sertifika alinamadi" derdi, "alan adini yanlis yazdiniz" demezdi.

Punycode INSAN TARAFINDAN DOGRULANAMAZ: `xn--ynetiyor-n4a` ile
`xn--ynetiyor-vpb` goz kararinda ayni derecede inandiricidir. Bu yuzden
depodaki her `xn--` dizesi, unicode kaynagindan YENIDEN URETILIP
karsilastirilir.

OLCULENLER
  1 URETILEBILIR  depodaki her `xn--...` etiketi, bildigimiz unicode
                  alan adlarindan uretilen kume icinde mi?
  2 KAPSAM        yapilandirmanin (Caddyfile/compose/.env ornegi) her
                  konagi punycode mu? Unicode yazilan bir site blogu
                  ESLESMEZ: TLS SNI ve Host basligi daima punycode gelir.
  3 SAHIPLIK      kaynakta gecen her `http(s)://...` adresi BIZE AIT bir
                  alan adina mi bakiyor?

                  BULUNAN GERCEK HATA (P120): `routers/mesajlar.py` icinde
                  `https://yonetio.app/ode` sabit koduydu ve **yonetio.app
                  bize ait DEGIL** (NS'i Cloudflare; bizim alanlarimizin
                  hepsi Hostinger'da). Bu adres, aidat hatirlatma
                  SMS/e-postalarindaki `{odeme_linki}` etiketine giriyordu:
                  sakinlere BIZIM gonderdigimiz mesajda UCUNCU BIR TARAFIN
                  alan adi. O alani elinde tutan biri icin hazir bir kimlik
                  avi yuzeyi. Bir harf farkli bir alan adi (`.app` / `.site`)
                  gozden kacar; bu kontrol onu her kosumda arar.

DENEY MODU (arac kendini sinar):
  DENEY=1  yanlis punycode (`-vpb`) enjekte eder   -> 1
  DENEY=2  Caddyfile'a unicode konak enjekte eder  -> 2
  DENEY=3  bize ait olmayan bir adres enjekte eder -> 3

KULLANIM:  python3 infra/alan-adi-denetimi.py
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parent.parent
DENEY = os.environ.get("DENEY", "0")

#: Sahip oldugumuz unicode alan adlari. Punycode BURADAN URETILIR —
#: elle yazilmaz, yoksa denetimin kendisi yanlis sabiti dogrulardi.
UNICODE_ALANLAR = ["yönetiyor.com"]

#: Punycode konabilecek alt alanlar (Caddyfile/compose'da gecenler).
ALT_ALANLAR = ["", "www.", "panel.", "api.", "storage."]


def ace(ad: str) -> str:
    return ad.encode("idna").decode("ascii")


BEKLENEN = {ace(f"{alt}{ad}") for ad in UNICODE_ALANLAR for alt in ALT_ALANLAR}

bulgular: list[str] = []
# Kaynak metinler tek yerde: DENEY enjeksiyonlari KOPYA uzerinde yapilir,
# kaynak dosyalara dokunulmaz.
#
# HENUZ COMMIT EDILMEMIS dosyalar DA taranir (`--others`): kapi commit'ten
# ONCE kosar, yani YENI eklenen bir dosya yalniz `ls-files` ile bakildiginda
# GORUNMEZDI — ve tam olarak yeni dosyalar hata getirir. Bu, bu kapinin ilk
# kosumunda gerceklesti: bulguyu ANLATAN yeni belge, kendisi taranmadigi icin
# sessizce gecti. `--exclude-standard` .gitignore'a uyar (build ciktisi girmez).
IZLENEN = subprocess.run(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
    cwd=KOK, capture_output=True, text=True, check=True
).stdout.splitlines()

YAPILANDIRMA = ["infra/Caddyfile", "infra/docker-compose.prod.yml",
                "infra/.env.prod.example"]

metinler: dict[str, str] = {}
for yol in IZLENEN:
    p = KOK / yol
    if not p.is_file():
        continue
    try:
        metinler[yol] = p.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue

if DENEY == "1":
    print("   (DENEY=1: yanlis punycode enjekte ediliyor)")
    metinler["infra/Caddyfile"] = metinler["infra/Caddyfile"].replace(
        "xn--ynetiyor-n4a.com", "xn--ynetiyor-vpb.com", 1)
if DENEY == "2":
    print("   (DENEY=2: Caddyfile'a unicode konak enjekte ediliyor)")
    metinler["infra/Caddyfile"] = metinler["infra/Caddyfile"].replace(
        "{$PORTAL_DOMAIN}, www.{$PORTAL_DOMAIN}",
        "panel.yönetiyor.com, www.{$PORTAL_DOMAIN}", 1)

if DENEY == "3":
    print("   (DENEY=3: bize ait olmayan bir adres enjekte ediliyor)")
    metinler["infra/Caddyfile"] = (
        metinler["infra/Caddyfile"] + '\n# ornek: https://yonetio.app/ode\n')

#: Taranmayan dosyalar. `.next/` ve kilit dosyalari URETILMIS yapilardir;
#: bu betigin KENDISI ise KARSI ORNEK ICERIR — DENEY kipi, yanlis punycode'u
#: ve bize ait olmayan bir adresi bilerek enjekte eder. Kendini taramak,
#: aracin kendi sinama verisini "bulgu" saymasi olurdu.
#: (Ilk kosumda tam bu oldu: `--others` eklenince arac kendi DENEY=1
#: dizesini yakaladi.)
ATLA = (".next/", "package-lock.json", "pnpm-lock.yaml",
        "infra/alan-adi-denetimi.py")

# --------------------------------------------------------------------------- #
# 1 — URETILEBILIR
ETIKET = re.compile(r"\bxn--[a-z0-9-]+\.[a-z]{2,}\b", re.I)
for yol, metin in sorted(metinler.items()):
    if any(p in yol for p in ATLA):
        continue
    for bulunan in set(ETIKET.findall(metin)):
        if bulunan.lower() not in BEKLENEN:
            bulgular.append(
                f"1: {yol}: `{bulunan}` bizim alan adlarimizdan URETILEMIYOR.\n"
                f"     beklenen kume: {', '.join(sorted(BEKLENEN))}"
            )

# --------------------------------------------------------------------------- #
# 2 — KAPSAM: yapilandirmada unicode konak olmamali.
# YALNIZ yapilandirma dosyalari taranir; belgeler (docs/) unicode YAZAR ve
# yazmalidir — insan orada okur.
UNICODE_KONAK = re.compile(
    r"(?<![\w.-])((?:[\w-]+\.)*[\w-]*[^\x00-\x7F][\w-]*(?:\.[\w-]+)+)")
for yol in YAPILANDIRMA:
    metin = metinler.get(yol)
    if metin is None:
        bulgular.append(f"2: {yol} okunamadi (yol degisti mi?)")
        continue
    for satir_no, satir in enumerate(metin.splitlines(), 1):
        # Yorum satirlari HARIC: gerekce metinleri unicode yazar (yazmali).
        kod = satir.split("#", 1)[0]
        # SEMASI OLAN ADRESLER HARIC. Bu kontrolun gerekcesi "site adresi
        # Host basligiyla eslesmeli"dir; `https://` tasiyan bir deger site
        # adresi DEGIL, BAGLANTIDIR (orn. `PORTAL_BASE_URL` — sakine giden
        # mesaj metnine girer; orada unicode DOGRUDUR, `xn--...` bicimi
        # SMS'te kimlik avi gibi gorunur). Caddy site adresleri ve
        # `*_DOMAIN` degiskenleri sema TASIMAZ, yani kapsam disi kalmazlar.
        kod = re.sub(r"https?://\S+", " ", kod)
        for m in UNICODE_KONAK.findall(kod):
            bulgular.append(
                f"2: {yol}:{satir_no}: yapilandirmada UNICODE konak `{m}`. "
                f"TLS SNI ve Host basligi daima punycode gelir -> bu satir "
                f"HIC eslesmez. Punycode yazin: {ace(m)}"
            )

# --------------------------------------------------------------------------- #
# 3 — SAHIPLIK
#: BIZE AIT alan adlari (unicode + punycode; alt alanlar serbest).
SAHIP = {"yonetio.site", *(ace(a) for a in UNICODE_ALANLAR), *UNICODE_ALANLAR}

#: Bize aitmis GIBI DURAN ama olmayan adlari yakalamak icin: markamizin
#: gectigi her adres denetlenir. Baska markalar (pub.dev, apple.com...)
#: kapsam disidir — burada aranan sey KARISTIRILABILIR alan adidir.
MARKA = re.compile(r"yonetio|yönetiyor|ynetiyor", re.I)
ADRES = re.compile(r"https?://([^/\s\"'`)\]}>,]+)", re.I)


#: ADIYLA VE GEREKCESIYLE istisnalar — sessiz bir "yok say" listesi DEGIL.
#: Buradaki dosyalar BULGUYU ANLATIR; alan adi orada bir KANIT olarak
#: gecer, urunun kullandigi bir baglanti olarak degil. Belgeler kullaniciya
#: baglanti GONDERMEZ; asil kural (urun kodunda bize ait olmayan adres
#: BULUNAMAZ) bu yuzden mutlak kalir.
#:
#: Yeni bir satir eklemeden once sorun: bu adres bir gun BIR KULLANICIYA
#: gosterilebilir mi? Cevap "belki" ise istisna DEGIL, duzeltme gerekir.
ISTISNA = {
    # P120 bulgusunun kaydi: `mesajlar.py` icindeki sabit kodun ne oldugu.
    ("docs/MASTER-PLAN.md", "yonetio.app"),
    ("docs/alan-adi-gecisi.md", "yonetio.app"),
}

for yol, metin in sorted(metinler.items()):
    if any(p in yol for p in ATLA):
        continue
    for konak in set(ADRES.findall(metin)):
        ad = konak.split("@")[-1].split(":")[0].lower().rstrip(".")
        if not MARKA.search(ad):
            continue
        if any(ad == s or ad.endswith("." + s) for s in SAHIP):
            continue
        if (yol, ad) in ISTISNA:
            continue
        bulgular.append(
            f"3: {yol}: `{ad}` markamiza BENZIYOR ama SAHIP OLDUGUMUZ "
            f"alanlardan degil ({', '.join(sorted(SAHIP))}). Kaynakta gecen "
            f"bir adres bize ait degilse, o adresi elinde tutan taraf bizim "
            f"gonderdigimiz baglantiyi devralir."
        )

# --------------------------------------------------------------------------- #
if not bulgular:
    print(f"bulgu: 0 — punycode'lar unicode kaynagindan uretilebiliyor "
          f"({', '.join(sorted(BEKLENEN))}); yapilandirmada unicode konak yok.")
    sys.exit(0)

print(f"bulgu: {len(bulgular)}")
for b in bulgular:
    print(f"  {b}")
print(
    "\nPUNYCODE'U ELLE YAZMAYIN. Uretin:\n"
    "  python3 -c \"print('yönetiyor.com'.encode('idna').decode())\""
)
sys.exit(1)
