#!/usr/bin/env bash
# KAPILAR — plan kural 6'daki kapıları DOĞRU koşan tek giriş.
#
# NEDEN BİR BETİK: kuralı yazmak yetmedi. Aynı iki tuzağa bu oturumda üç
# kez düşüldü (P74 backend, P87 mobil):
#   1. `komut | tail` — boru hattının çıkış kodu SON komutunkidir, yani
#      `pytest`in hatası kaybolur ve "Failing tests" bloğu görünmez olur.
#      P87'de kanıt ilk seferde yok oldu ve kök neden BULUNAMADI.
#   2. `docker compose build api` unutulur — imaj kodu içine gömer ve
#      ESKİ kod test edilir (P75'te tam bu oldu).
# Betik ikisini de yapısal olarak engeller: çıktı DOSYAYA yazılır, çıkış
# kodu doğrudan okunur, backend'de imaj önce yeniden kurulur.
#
# Kullanım:  infra/kapilar.sh [depo] [web] [mobile] [backend] [goc]
#            (argümansız: hepsi)
set -uo pipefail

KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUNLUK="${KAPILAR_GUNLUK:-$KOK/.kapilar}"
mkdir -p "$GUNLUK"

declare -a SONUC=()
HATA=0

# Bir kapıyı koşar: çıktı DOSYAYA, çıkış kodu DOĞRUDAN.
kapi() {
  local ad="$1"; shift
  local log="$GUNLUK/$ad.log"
  printf '== %s\n' "$ad"
  ( "$@" ) >"$log" 2>&1
  local kod=$?
  # OZET: SON ANLAMLI SATIR. Once `tail -n 3 | tr '\n' ' '` kullaniliyordu
  # ve sonuc yaniltici oluyordu: uc satirlik pencerenin BASI gorunuyordu,
  # yani `flutter test`in son satiri "+1559 All tests passed!" iken ozette
  # ara satirdaki "+1557" yaziyordu. P89'da bunu "flutter'in sayaci
  # kirpiliyor" diye NOT DUSTUM — yanlisti; sebep bu satirdi (P90).
  local ozet
  ozet="$(grep -v '^[[:space:]]*$' "$log" | tail -n 1 | tr -d '\r' | cut -c1-88)"
  # BOS GUNLUK SESSIZ BASARIDIR (orn. `tsc` bir sey yazmaz). Ozeti bos
  # birakmak "okuyamadim" ile "diyecek bir sey yok"u ayirt edilemez
  # kilardi (P61'in bos-durum dersi, arac tarafinda).
  [ -z "$ozet" ] && ozet="(cikti yok)"
  if [ "$kod" -eq 0 ]; then
    SONUC+=("OK   $ad — $ozet")
  else
    # HATADA SON SATIR YETMEZ. Ilk denemede "son anlamli satir"
    # basiliyordu ve `vitest` icin bu **Duration** satiriydi — yani ozet,
    # "neden dustu"yu degil "ne kadar surdu"yu soyluyordu. Once BASARISIZLIK
    # IMZASI aranir; yoksa son satira dusulur.
    local sebep=""
    # (P92) FLUTTER ONCE: `flutter test` bir "Failing tests:" blogu basar
    # ve ise yarar bilgi o blogun ILK SATIRIDIR (dusun testin adi).
    # Imza taramasi burada `tail -1` ile blogun BASLIGINI secerdi ("Failing
    # tests:"), yani "dustu" der ama NE dustugunu soylemezdi.
    if grep -qaE '^Failing tests' "$log"; then
      sebep="$(grep -aA1 -E '^Failing tests' "$log" | sed -n '2p' \
               | tr -d '\r' | sed 's/^[[:space:]]*//' | cut -c1-88)"
    fi
    # Genel imzalar: pytest ("1 error", "3 failed"), vitest ("Tests N failed"),
    # flutter ozet satiri ("Some tests failed"), yapim ("Failed to compile").
    if [ -z "$sebep" ]; then
      sebep="$(grep -aiE "([0-9]+ (failed|error))|^(FAIL|ERROR)|Tests +[0-9]+ failed|Some tests failed|Failed to compile" "$log" \
               | tail -n 1 | tr -d '\r' | sed 's/^[[:space:]]*//' | cut -c1-88)"
    fi
    [ -z "$sebep" ] && sebep="$ozet"
    SONUC+=("HATA $ad (cikis $kod) — $sebep")
    SONUC+=("     gunluk: $log")
    HATA=1
  fi
}

web() {
  kapi web-tsc     bash -c "cd '$KOK/admin-web' && npx tsc --noEmit"
  kapi web-vitest  bash -c "cd '$KOK/admin-web' && npx vitest run"
  kapi web-build   bash -c "cd '$KOK/admin-web' && npm run build"
}

mobile() {
  kapi mobil-analyze bash -c "cd '$KOK/mobile' && flutter analyze"
  kapi mobil-test    bash -c "cd '$KOK/mobile' && flutter test"
  kapi mobil-apk     bash -c "cd '$KOK/mobile' && flutter build apk --debug"
}

backend() {
  # IMAJ ONCE: aksi halde konteynerde ESKI kod kosar (P75).
  kapi backend-build bash -c "cd '$KOK' && docker compose -f infra/docker-compose.yml build api"
  kapi backend-up    bash -c "cd '$KOK' && docker compose -f infra/docker-compose.yml up -d api"
  # Tek kosum: ikinci bir pytest fixture tenant'larini siler; conftest'teki
  # oneri kilit bunu zaten reddeder (P75).
  kapi backend-pytest bash -c "cd '$KOK' && docker compose -f infra/docker-compose.yml exec -T api python -m pytest -q"
}

goc() {
  kapi goc-uyum       bash -c "cd '$KOK' && bash infra/goc-uyum-dogrula.sh"
  kapi goc-tersinir   bash -c "cd '$KOK' && bash infra/goc-tersinirlik.sh"
}

# DEPO KAPISI — "yapi referans veriyor ama depoda yok".
#
# Bu sinif iki kez gerceklesti (android network_security_config, iOS
# PrivacyInfo/entitlements/simgeler) ve IKISINDE DE `git status` TEMIZ
# gorundugu icin fark edilmedi: kok `.gitignore` platform agaclarini
# toptan yok sayiyordu. Diger kapilar YEREL agaci olcer; bu kapi
# DEPONUN KENDISINI olcer — taze klonda ne bulunacagini.
#
# ALAN LISTESINE DAHIL: argumansiz kosumda calisir. Saniyeler surer,
# derleme gerektirmez.
depo() {
  kapi depo-izlenmeyen bash -c "cd '$KOK' && python3 infra/izlenmeyen-kaynak.py"
  # (P120) IDN alan adi: punycode elle yazilir ve GOZLE DOGRULANAMAZ
  # (`xn--ynetiyor-n4a` ile `xn--ynetiyor-vpb` ayni derecede inandiricidir).
  # Yanlis bicim, ACME dogrulamasi surekli dusen ve HIC acilmayan bir site
  # birakir; hata da "alan adini yanlis yazdiniz" demez. Yeniden uretip
  # karsilastirir; saniyeler surer, ag/derleme istemez.
  kapi depo-alan-adi bash -c "cd '$KOK' && python3 infra/alan-adi-denetimi.py"
}

ALANLAR=("$@")
[ ${#ALANLAR[@]} -eq 0 ] && ALANLAR=(depo web mobile backend goc)
for a in "${ALANLAR[@]}"; do
  case "$a" in
    depo|web|mobile|backend|goc) "$a" ;;
    *) echo "bilinmeyen alan: $a" >&2; exit 2 ;;
  esac
done

echo
echo "===== KAPILAR ====="
printf '%s\n' "${SONUC[@]}"
echo "gunlukler: $GUNLUK"
exit "$HATA"
