#!/usr/bin/env bash
# (P232) KOSAN TAKIMIN ALTINDAN KONTEYNER CEKMEYI ENGELLEYEN SARMALAYICI.
#
# =============================================================================
# NEDEN VAR
# =============================================================================
# Tek bir seansta BES KEZ ayni sey oldu: tam test takimi kosarken
# `docker compose build api && up -d --force-recreate api` calistirildi,
# konteyner yeniden kuruldu ve kosum EXIT=137 ile oldu. Her seferinde
# 40-70 dakikalik bir kosum bastan basladi; bir keresinde de OLMEYEN ama
# ESKI IMAJLA kosan bir takim, duzeltilmis kodu "kirmizi" raporladi
# (P230 §4 — uc sahte kirmizi).
#
# "Dikkat edecegim" bir mekanizma degildir; bu dosya mekanizmadir.
#
# =============================================================================
# NEDEN KILIT DOSYASI DEGIL, CANLI DURUM
# =============================================================================
# Ilk akla gelen cozum "kosum basinda bir kilit dosyasi birak" idi.
# REDDEDILDI: bu depoda kilidin BAYATLAMASI bilinen bir sorun —
# oldurulen `docker compose exec pytest` konteynerde YETIM kaliyor ve
# ileriki kosumlari bloke ediyor (hafizada kayitli). Bayat bir kilit
# dosyasi da mesru derlemeleri engellerdi ve insan/ajan bunu "--zorla"
# ile atlamayi OGRENIRDI; o noktada engel yok demektir.
#
# Bu betik GERCEK DURUMA bakar: api konteynerinde pytest sureci var mi?
# Yanit her zaman guncel, bayatlayamaz.
#
# =============================================================================
# KONTEYNER OKUNAMAZSA NE OLUR
# =============================================================================
# FAIL-CLOSED: durum OKUNAMIYORSA derleme YAPILMAZ. Fail-open, tam olarak
# onlemeye calistigimiz kusuru geri getirirdi (kontrol basarisiz -> "bir
# sey yoktur" -> derle -> kosum olur).
set -euo pipefail

cd "$(dirname "$0")"

ZORLA=0
SERVISLER=()
for arg in "$@"; do
  case "$arg" in
    --zorla) ZORLA=1 ;;
    *) SERVISLER+=("$arg") ;;
  esac
done
[ ${#SERVISLER[@]} -eq 0 ] && SERVISLER=(api)

# `/proc` OKUNUR, `ps` DEGIL.
#
# ILK YAZIMDA `ps -eo ...` kullanilmisti ve BETIK SESSIZCE ISE YARAMADI:
# `python:3.12-slim` imajinda `ps` YOK, komut hata verdi, sondaki
# `|| true` hatayi YUTTU ve kontrol "kosan yok" dedi. Yani engelin
# kendisi FAIL-OPEN'di — onlemeye calistigi kusurun aynisi. Kanit
# denemesinde yakalandi: kosan takim gercekten olduruldu.
#
# `/proc` her Linux konteynerinde vardir ve ek paket istemez.
# PROB KENDINI GORMEMELI.
#
# Ikinci kusur da kanit denemesinde yakalandi: `case $satir in *pytest*)`
# yazan probun KENDI komut satiri "pytest" kelimesini iceriyor ve
# `/proc`ta kendini buluyordu — hicbir takim kosmazken bile derlemeyi
# engelliyordu (yanlis pozitif, ki o da zararli: engel guvenilmez olunca
# insan `--zorla` aliskanligi edinir).
#
# Aranan kelime PARCALANARAK kurulur; boylece probun kendi cmdline'inda
# butun halde GECMEZ.
kosan_pytest() {
  docker compose exec -T api sh -c '
    aranan="py""test"
    for d in /proc/[0-9]*; do
      [ -r "$d/cmdline" ] || continue
      satir=$(tr "\0" " " < "$d/cmdline" 2>/dev/null)
      case "$satir" in
        *"$aranan"*) echo "${d##*/}  $satir" ;;
      esac
    done
  '
}

if [ "$ZORLA" -eq 0 ]; then
  if ! docker compose ps --status running --format '{{.Service}}' 2>/dev/null | grep -qx api; then
    echo "!! api konteyneri CALISMIYOR — kosum durumu okunamiyor." >&2
    echo "   Fail-closed: derleme yapilmadi." >&2
    echo "   Konteyner gercekten kapaliysa: $0 ${SERVISLER[*]} --zorla" >&2
    exit 2
  fi
  # PROB'UN KENDISI CALISMAZSA FAIL-CLOSED: `|| true` ile yutmak, ilk
  # yazimin sessizce ise yaramamasina yol acmisti.
  if ! KOSAN="$(kosan_pytest)"; then
    echo "!! kosum durumu OKUNAMADI (prob basarisiz) — derleme yapilmadi." >&2
    exit 2
  fi
  if [ -n "$KOSAN" ]; then
    echo "!! API KONTEYNERINDE PYTEST KOSUYOR — derleme DURDURULDU." >&2
    echo "" >&2
    echo "$KOSAN" >&2
    echo "" >&2
    echo "   Yeniden kurmak kosumu EXIT=137 ile oldururdu (bu seansta 5 kez oldu)." >&2
    echo "   Bekleyin, ya da kosumu bilerek iptal ediyorsaniz:" >&2
    echo "     $0 ${SERVISLER[*]} --zorla" >&2
    exit 1
  fi
fi

echo ">> derleniyor: ${SERVISLER[*]}"
docker compose build "${SERVISLER[@]}"
echo ">> yeniden kuruluyor: ${SERVISLER[*]}"
docker compose up -d --force-recreate "${SERVISLER[@]}"
# Konteynerin ayaga kalkmasini BEKLE: hemen ardindan pytest calistiran
# cagrilar "container is restarting" hatasi aliyordu.
# HAZIR = UYGULAMA YANIT VERIYOR, "python calisiyor" DEGIL.
#
# Ilk yazimda `python -c pass` kullanilmisti ve YETERSIZDI: konteyner
# ayaga kalkmis ama uvicorn heniz dinlemiyorken ">> hazir" yaziyordu;
# hemen ardindan kosan testler 14 tanesini "API erisilemiyor" diye
# ATLADI (olculdu). Atlanan test, gecmis test gibi gorunur — sessiz bir
# yanlis guven.
for _ in $(seq 1 45); do
  if docker compose exec -T api python -c "
import urllib.request, sys
try:
    urllib.request.urlopen('http://localhost:8000/health', timeout=2)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
    echo ">> hazir"
    exit 0
  fi
  sleep 2
done
echo "!! konteyner 60 sn icinde hazir olmadi" >&2
exit 3
