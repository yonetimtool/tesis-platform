#!/usr/bin/env python3
"""URETIM DAGITIM YOLU DENETIMI — hicbir otomatik olcumde yoktu (tur 72).

`docker-compose.prod.yml` (353 satir), `Caddyfile` (61), `backup.sh` (66) ve
`RUNBOOK-PROD.md` (229) tur 41'den beri repoda duruyor ama HICBIR test, sürüş
ya da lint bunlara dokunmuyor. Prod yigini yerelde ayaga kaldirilmadan da
olculebilen bir sey var: **dosyalar arasi tutarlilik**. Buradaki her kontrol,
"operatör runbook'u harfiyen uygular ve yine de bozuk bir kurulum elde eder"
sinifindan bir hatayi arar.

OLCULENLER
  A ENV-KAPSAM     compose/Caddyfile'in okudugu her degisken .env.prod.example'da
                   var mi (ya da compose'da varsayilani/:? muhafizi var mi)?
                   Yoksa operatör dosyayi kopyalayip doldurdugunda o deger
                   SESSIZCE BOS kalir.
  B OLU-ANAHTAR    .env.prod.example'da olup hicbir tuketici (compose, Caddyfile,
                   backup.sh) tarafindan okunmayan anahtar — operatör doldurur,
                   hicbir sey okumaz.
  C SESSIZ-SIR     Guvenlik acisindan kritik degiskenler (JWT_SECRET, SDM_KEK,
                   parolalar) :? muhafizi olmadan referans veriliyorsa, eksik
                   olduklarinda servis BOS SIR ile ayaga kalkar.
  D PORT-SIZINTISI caddy disinda host portu yayinlayan servis (prod tasarimi:
                   yalniz 80/443 disa acik).
  E DEV-SAPMA      dev compose'da bir servise verilen ortam anahtari prod'da
                   eksik mi (dagitimda "calisiyordu ama prod'da yok" sinifi).
  F RUNBOOK-COZUK  runbook/backup.sh icindeki komutlarin refere ettigi compose
                   servisi, dosya yolu, python modulu ve docker volume adi
                   gercekten var mi (belge cürumesi).
  G ALAN-TUTARLI   compose varsayilan alan adlari == .env.prod.example ==
                   runbook'ta yazan alanlar.
  H SIR-SIZINTISI  .env.prod / infra/secrets git'te izleniyor mu.
  I UPSTREAM       Caddyfile'in `reverse_proxy <servis>:<port>` hedefleri prod
                   compose'da GERCEKTEN var mi ve o port o serviste geciyor mu
                   (yazim hatasi = 502; TLS calisir, site bos doner).

DENEY MODU — bu arac da bir olcum aracidir, kendisi sinanir:
  DENEY=1  compose'a tanimsiz bir ${...} referansi enjekte eder      -> A
  DENEY=2  db servisine host portu enjekte eder                      -> D
  DENEY=3  runbook'a var olmayan bir compose servisi enjekte eder    -> F
  DENEY=4  Caddyfile'da upstream portunu bozar                       -> I
  DENEY=5  compose'un varsayilan alan adini degistirir               -> G
  DENEY=6  .gitignore'dan secrets desenini siler                     -> H
Enjeksiyonlar GECICI kopyalar uzerinde yapilir; kaynak dosyalara dokunulmaz.

KULLANIM:  python3 infra/prod-denetimi.py
           DENEY=1 python3 infra/prod-denetimi.py
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

INFRA = Path(__file__).resolve().parent
KOK = INFRA.parent
DENEY = os.environ.get("DENEY", "0")

bulgular: list[str] = []


def bulgu(kod: str, mesaj: str) -> None:
    bulgular.append(f"{kod}: {mesaj}")


def oku(yol: Path) -> str:
    return yol.read_text(encoding="utf-8")


# --------------------------------------------------------------------------- #
# Kaynaklar (DENEY enjeksiyonlari burada, kopya metin uzerinde).
prod_metin = oku(INFRA / "docker-compose.prod.yml")
dev_metin = oku(INFRA / "docker-compose.yml")
caddy_metin = oku(INFRA / "Caddyfile")
backup_metin = oku(INFRA / "backup.sh")
runbook_metin = oku(INFRA / "RUNBOOK-PROD.md")
ornek_metin = oku(INFRA / ".env.prod.example")

if DENEY == "1":
    print("   (DENEY=1: tanimsiz ${DENEY_YOK_DEGISKEN} enjekte ediliyor)")
    prod_metin = prod_metin.replace(
        "      REDIS_URL: redis://redis:6379/0",
        "      REDIS_URL: redis://redis:6379/0\n      DENEY_ANAHTAR: ${DENEY_YOK_DEGISKEN}",
        1,
    )
if DENEY == "2":
    print("   (DENEY=2: db servisine host portu enjekte ediliyor)")
    prod_metin = prod_metin.replace(
        "    volumes:\n      - pgdata:/var/lib/postgresql/data",
        '    ports:\n      - "5432:5432"\n    volumes:\n      - pgdata:/var/lib/postgresql/data',
        1,
    )
if DENEY == "3":
    print("   (DENEY=3: runbook'a var olmayan servis adi enjekte ediliyor)")
    runbook_metin = runbook_metin.replace("$C logs -f api", "$C logs -f apii", 1)
if DENEY == "4":
    print("   (DENEY=4: Caddyfile upstream portu bozuluyor)")
    caddy_metin = caddy_metin.replace("reverse_proxy api:8000", "reverse_proxy api:8001", 1)
if DENEY == "5":
    print("   (DENEY=5: compose varsayilan alan adi degistiriliyor)")
    prod_metin = prod_metin.replace("api.yonetio.site", "api.baska.site", 1)
gitignore_metin = oku(KOK / ".gitignore")
if DENEY == "6":
    print("   (DENEY=6: .gitignore'dan infra/secrets/ desenini siliyor)")
    gitignore_metin = gitignore_metin.replace("infra/secrets/", "")

import yaml  # noqa: E402  (DENEY enjeksiyonlarindan sonra)

prod = yaml.safe_load(prod_metin)
dev = yaml.safe_load(dev_metin)
prod_servisler = prod.get("services", {})
dev_servisler = dev.get("services", {})

# --------------------------------------------------------------------------- #
# A — ENV-KAPSAM
# compose sozdizimi: ${VAR}, ${VAR:-default}, ${VAR:?mesaj}, ${VAR-default}
REF = re.compile(r"\$\{([A-Z_][A-Z0-9_]*)(:?[-?][^}]*)?\}")
ornek_anahtarlar = set(re.findall(r"^([A-Z_][A-Z0-9_]*)=", ornek_metin, re.M))

compose_refler: dict[str, set[str]] = {}
for ad, ek in REF.findall(prod_metin):
    compose_refler.setdefault(ad, set()).add(ek or "")
# Caddyfile sozdizimi FARKLI: {$VAR}. Bu degiskenler caddy servisinin
# environment'inda tanimli olmali (compose'dan gecer), .env'de degil.
# YORUMLAR ATILIR: Caddyfile'in bas yorumu ornek olarak literal `{$VAR}` yazar;
# suzulmezse arac var olmayan bir "VAR" degiskeni bildirir (ilk kosumda oldu).
caddy_kod = "\n".join(
    satir for satir in caddy_metin.splitlines() if not satir.lstrip().startswith("#"))
caddy_refler = set(re.findall(r"\{\$([A-Z_][A-Z0-9_]*)\}", caddy_kod))
caddy_env = set((prod_servisler.get("caddy", {}).get("environment") or {}).keys())

for ad, ekler in sorted(compose_refler.items()):
    varsayilan_var = any(e.startswith((":-", "-")) for e in ekler)
    muhafiz_var = any(e.startswith((":?", "?")) for e in ekler)
    if ad in ornek_anahtarlar or varsayilan_var or muhafiz_var:
        continue
    bulgu("A", f"${{{ad}}} compose'da okunuyor ama .env.prod.example'da YOK "
               f"ve varsayilani/muhafizi yok -> sessizce bos kalir")

for ad in sorted(caddy_refler):
    if ad not in caddy_env:
        bulgu("A", f"Caddyfile {{${ad}}} okuyor ama caddy servisinin "
                   f"environment'inda tanimli degil")

# --------------------------------------------------------------------------- #
# B — OLU-ANAHTAR
tuketici_metin = prod_metin + backup_metin
# backup.sh degiskenleri $VAR / ${VAR} / "${VAR:?}" bicimlerinde okur.
kabuk_refler = set(re.findall(r"\$\{?([A-Z_][A-Z0-9_]*)", backup_metin))
okunanlar = set(compose_refler) | kabuk_refler
# Caddy degiskenleri compose environment'i uzerinden gelir; onlar zaten
# compose_refler'de gorunur (ACME_EMAIL vb.).
for ad in sorted(ornek_anahtarlar - okunanlar):
    bulgu("B", f"{ad} .env.prod.example'da var ama hicbir tuketici okumuyor "
               f"(compose/Caddyfile/backup.sh) -> olu yapilandirma")

# --------------------------------------------------------------------------- #
# C — SESSIZ-SIR
KRITIK = {
    "JWT_SECRET", "SDM_KEK", "POSTGRES_PASSWORD", "APP_DB_PASSWORD",
    "MINIO_ROOT_PASSWORD", "BACKUP_GPG_PASSPHRASE",
}
# Muhafizsiz olmasi SORUN OLMAYANLAR — her biri icin gerekce dogrulanmistir:
MUHAFIZ_MUAF = {
    # Bos = SDM anahtar kaydi KAPALI; config.py'de `sdm_kek: str = ""` ve
    # nfc_sdm.py uzunluk kontrolunde ValueError -> 500 config_error. Yani
    # sessizce zayif bir anahtarla calismaz, KAPANIR. Bilincli tasarim.
    "SDM_KEK",
    # backup.sh zaten `: "${BACKUP_GPG_PASSPHRASE:?}"` ile kendi muhafizini
    # yapiyor; compose bu degiskeni hic okumaz.
    "BACKUP_GPG_PASSPHRASE",
}
for ad in sorted(KRITIK & set(compose_refler) - MUHAFIZ_MUAF):
    ekler = compose_refler[ad]
    if not any(e.startswith((":?", "?")) for e in ekler):
        bulgu("C", f"{ad} kritik bir sir ama compose'da `:?` muhafizi yok — "
                   f"eksikse BOS STRING olarak gecer")

# --------------------------------------------------------------------------- #
# D — PORT-SIZINTISI
for ad, tanim in sorted(prod_servisler.items()):
    if tanim and tanim.get("ports") and ad != "caddy":
        bulgu("D", f"{ad} servisi host portu yayinliyor: {tanim['ports']} "
                   f"(prod tasariminda yalniz caddy 80/443 acmali)")

# --------------------------------------------------------------------------- #
# E — DEV-SAPMA
# Dev'e ozgu, prod'da BILINCLI olmayan anahtarlar (gerekce ile).
SAPMA_MUAF = {
    "SEED_ON_START",    # prod'da seed yok (compose basinda yazili)
    "EXTERNAL_NOTIFY",  # dev-only push kopyasi
    "PYTHONUNBUFFERED", # log tamponu, dev kolayligi
    "WATCHFILES_FORCE_POLLING",
    "UVICORN_RELOAD",
    # api'ye superuser/senkron DSN'leri BILINCLI verilmez: internete (Caddy)
    # bakan surec yalniz RLS'e tabi app_rw tasir. Zamanlayici kodu worker/beat'te
    # kosar ve orada tanimlidir. create_admin da `worker` ile cagrilir (tur 72).
    "OWNER_DSN", "APP_DSN",
    # Dev'de testlerin canli sunucuya gittigi adres; prod'da anlamsiz.
    "API_URL",
}
for ad in sorted(set(prod_servisler) & set(dev_servisler)):
    d_env = dev_servisler[ad].get("environment") or {}
    p_env = prod_servisler[ad].get("environment") or {}
    if not isinstance(d_env, dict) or not isinstance(p_env, dict):
        continue
    eksik = set(d_env) - set(p_env) - SAPMA_MUAF - {"<<"}
    for k in sorted(eksik):
        bulgu("E", f"{ad}: dev'de `{k}` var, prod'da YOK")

# --------------------------------------------------------------------------- #
# F — RUNBOOK-COZUK
belge = runbook_metin + backup_metin
# compose alt-komutlarindan servis adi: exec/run/logs [-f|-T|--rm] SERVIS
SERVIS_KOM = re.compile(
    r"\b(?:exec|run|logs)\b((?:\s+(?:-T|-f|--rm|-d))*)\s+([a-z][a-z0-9-]*)")
YOKSAY_SERVIS = {"docker", "compose", "-f", "-t", "prune", "version"}
for _bayrak, ad in SERVIS_KOM.findall(belge):
    if ad in YOKSAY_SERVIS or ad in prod_servisler:
        continue
    bulgu("F", f"belgedeki komut `{ad}` servisini cagiriyor ama "
               f"docker-compose.prod.yml'de boyle bir servis yok")

# python -m <modul>
for modul in re.findall(r"python -m ([a-z_][a-z0-9_.]*)", belge):
    yol = KOK / "backend" / (modul.replace(".", "/") + ".py")
    if not yol.exists():
        bulgu("F", f"belge `python -m {modul}` diyor ama {yol.relative_to(KOK)} yok")

# repo icindeki dosya yollari (infra/... , mobile/... , docs/...)
# Operatörün KURULUM SIRASINDA olusturdugu yollar repoda YOKTUR (olmamali):
OPERATOR_YOLLARI = {"infra/.env.prod", "infra/secrets/fcm-service-account.json"}
for iz in set(re.findall(r"(?:tesis-platform/)?((?:infra|mobile|backend|admin-web|docs|contracts)/[A-Za-z0-9_./-]+)", belge)):
    if iz.endswith((".", "/")) or "<" in iz or iz in OPERATOR_YOLLARI:
        continue
    if not (KOK / iz).exists():
        bulgu("F", f"belgede gecen yol yok: {iz}")

# docker volume adi: <proje>_<volume>
proje = prod.get("name", "")
for vol in set(re.findall(r"-v ([a-z0-9_]+_[a-z0-9_]+):", belge)):
    on, _, kisa = vol.partition("_")
    beklenen = {f"{proje.replace('-', '')}_{v}" for v in (prod.get("volumes") or {})}
    beklenen |= {f"{proje}_{v}" for v in (prod.get("volumes") or {})}
    if vol not in beklenen:
        bulgu("F", f"belgede gecen docker volume adi `{vol}` compose'un "
                   f"uretecegi adlarla ({sorted(beklenen)[:3]}...) uyusmuyor")

# --------------------------------------------------------------------------- #
# G — ALAN-TUTARLI
ALAN = ("API_DOMAIN", "PANEL_DOMAIN", "STORAGE_DOMAIN",
        # (P120) yeni birincil alan + korunan eski kok.
        "PORTAL_DOMAIN", "PANEL_DOMAIN_YENI", "PORTAL_DOMAIN_ESKI")
for ad in ALAN:
    m = re.search(rf"\$\{{{ad}:-([^}}]+)\}}", prod_metin)
    o = re.search(rf"^{ad}=(.+)$", ornek_metin, re.M)
    if not m or not o:
        bulgu("G", f"{ad} icin compose varsayilani ya da .env.prod.example "
                   f"girdisi bulunamadi")
        continue
    if m.group(1).strip() != o.group(1).strip():
        bulgu("G", f"{ad}: compose varsayilani `{m.group(1)}` != "
                   f".env.prod.example `{o.group(1)}`")
    if m.group(1).strip() not in runbook_metin:
        bulgu("G", f"{ad} varsayilani `{m.group(1)}` runbook'ta hic gecmiyor")

# --------------------------------------------------------------------------- #
# H — SIR-SIZINTISI
izlenen = subprocess.run(
    ["git", "ls-files", "infra/secrets", "infra/.env.prod"],
    cwd=KOK, capture_output=True, text=True).stdout.strip()
if izlenen:
    for satir in izlenen.splitlines():
        bulgu("H", f"SIR GIT'TE IZLENIYOR: {satir}")
gi = gitignore_metin
for desen in ("infra/secrets/", ".env.prod"):
    if desen not in gi:
        bulgu("H", f".gitignore `{desen}` desenini icermiyor")

# --------------------------------------------------------------------------- #
# I — UPSTREAM
# Yazim hatasi TLS'i bozmaz: Caddy sertifikayi alir, site 502 doner. Yani
# "https calisiyor" bu sinifi GORMEZ.
# IMA EDILEN PORTLAR: bazi imajlar API portunu compose'da HIC yazmaz, imaj
# varsayilanini dinler. Port-taniminda-geciyor-mu sezgisi bunlari yanlis
# bildirir (ilk kosumda minio:9000 icin oldu). Gerekcesiyle muaf:
#   minio 9000 -> MinIO S3 API'sinin imaj varsayilani; compose'da yalniz
#   konsol portu (`--console-address ":9001"`) yazili.
IMA_EDILEN_PORTLAR = {("minio", "9000")}
for svc, port in re.findall(r"reverse_proxy\s+([a-z][a-z0-9-]*):(\d+)", caddy_kod):
    if svc not in prod_servisler:
        bulgu("I", f"Caddyfile `{svc}:{port}`e proxy'liyor ama compose'da `{svc}` "
                   f"servisi yok -> 502")
        continue
    # Port o servisin taniminda (healthcheck/command/console-address) gecmeli.
    if (svc, port) in IMA_EDILEN_PORTLAR:
        continue
    tanim_metin = yaml.safe_dump(prod_servisler[svc], allow_unicode=True)
    if port not in tanim_metin:
        bulgu("I", f"Caddyfile `{svc}:{port}`e proxy'liyor ama {port} portu "
                   f"`{svc}` servisinin taniminda hic gecmiyor -> 502 riski")

# --------------------------------------------------------------------------- #
# --------------------------------------------------------------------------- #
# J — GOC-SIRASI
# Dagitim komutlari belgelerde kod bloklarinda yasar. `api`yi ADIYLA hedefleyen
# her blok, ayni blokta gocu de kosmalidir.
import glob  # noqa: E402

BELGELER = ["infra/RUNBOOK-PROD.md", *sorted(glob.glob("docs/*.md"))]
API_HEDEF = re.compile(r"up\s+-d\b[^\n]*\bapi\b")
GOC = re.compile(r"\bmigrate\b")

for _yol in BELGELER:
    _p = KOK / _yol
    if not _p.is_file():
        continue
    _metin = _p.read_text(encoding="utf-8")
    if DENEY == "7" and _yol == "docs/alan-adi-gecisi.md":
        print("   (DENEY=7: dagitim blogundan `migrate` satiri siliniyor)")
        _metin = _metin.replace("$C run --rm migrate\n", "", 1)
    # ``` ile ayrilmis kod bloklari (cift indisliler blok ICIDIR).
    for _i, _blok in enumerate(_metin.split("```")):
        if _i % 2 == 0:
            continue
        if not API_HEDEF.search(_blok):
            continue
        if GOC.search(_blok):
            continue
        bulgu("J", f"{_yol}: bir dagitim blogu `api`yi tek basina ayaga "
                   f"kaldiriyor ama ayni blokta `migrate` YOK — kod yeni "
                   f"semayi isterse GET /cameras gibi uclar 500 verir "
                   f"(P124'te gerceklesti)")

BASLIK = {
    "A": "ENV-KAPSAM", "B": "OLU-ANAHTAR", "C": "SESSIZ-SIR",
    "D": "PORT-SIZINTISI", "E": "DEV-SAPMA", "F": "RUNBOOK-COZUK",
    "G": "ALAN-TUTARLI", "H": "SIR-SIZINTISI", "I": "UPSTREAM",
    "J": "GOC-SIRASI",
}
print(f"== prod dagitim denetimi — {len(prod_servisler)} servis, "
      f"{len(ornek_anahtarlar)} env anahtari, {len(runbook_metin.splitlines())} satir runbook")
for kod, ad in BASLIK.items():
    kendi = [b for b in bulgular if b.startswith(kod + ":")]
    if kendi:
        print(f"!! [{kod}] {ad} — {len(kendi)} bulgu")
        for b in kendi:
            print("     " + b.split(": ", 1)[1])
    else:
        print(f"OK [{kod}] {ad}")

if DENEY != "0":
    print(f"== DENEY={DENEY}: ilgili kontrol KIRMIZI donmediyse arac KOR.")
print(f"== bulgu: {len(bulgular)}")
sys.exit(1 if bulgular else 0)
