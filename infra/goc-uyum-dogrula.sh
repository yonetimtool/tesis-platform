#!/usr/bin/env bash
# GOC UYUM DOGRULAMASI — "taze kurulan sema" == "zaten goc etmis + yakalama".
#
# NEDEN: bu depoda uzun sure sema degisiklikleri MEVCUT revizyon dosyalari
# YERINDE duzenlenerek yazildi ("kanonik migration" kurali). Dev her seferinde
# sifirdan kuruldugu icin bu hic gorunmedi; prod bir kez goc ettigi icin o
# duzenlemeler ona ULASMADI ve `alembic upgrade head` 0009'da patladi:
#
#   psycopg.errors.UndefinedColumn: column "cikis_zamani" does not exist
#
# `0008b_uyum_yakalama` bu bosluğu kapatir. Bu betik KAPATTIGINI KANITLAR:
#
#   YOL A (taze)  : bos veritabani -> GUNCEL dosyalar -> head
#   YOL B (prod)  : bos veritabani -> ESKI dosyalar (prod'un goc ettigi agac)
#                   -> head ; sonra GUNCEL dosyalar -> head (0008b burada kosar)
#
# Iki semanin AYNI olmasi gerekir. Karsilastirma SIRA-DUYARSIZ yapilir:
# `ADD COLUMN` kolonu tablonun SONUNA ekler, kanonik dosyada ise ortada
# tanimlidir. Kolon ORDINAL POZISYONU semantik bir fark DEGILDIR (uygulama
# kolonlara ADLA erisir) ve tabloyu yeniden yazmadan duzeltilemez. Bu yuzden
# betik iki sey yapar:
#   1) SEMANTIK karsilastirma — kolon adi/tipi/nullable/varsayilan, kisitlar,
#      indeksler, enum etiketleri, RLS bayraklari, politikalar, fonksiyonlar,
#      app_rw yetkileri; hepsi SIRALI KUME olarak. Bu farkin BOS olmasi sart.
#   2) Ham `pg_dump` farkini gosterir ve farkin YALNIZ kolon sirasindan
#      geldigini ayrica belirtir (seffaflik icin; kabul kriteri 1'dir).
#
# ESKI AGAC: prod'un goc ettigi tarihteki dosyalar. Varsayilan `bf1dc84^` —
# 0001'i yerinde duzenleyen ILK commit'in ebeveyni (git gecmisinden: 0001 ve
# 0005 disinda hicbir revizyon dosyasi degismemis).
#
# KULLANIM:  infra/goc-uyum-dogrula.sh [eski-commit-ish]
set -uo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a

ESKI_REF="${1:-bf1dc84^}"
KOK="$(cd .. && pwd)"
ESKI_DIR="$(mktemp -d)"
CIKTI="${CIKTI:-/tmp/goc-uyum}"
mkdir -p "$CIKTI"
A=uyumdog_taze
B=uyumdog_prod
HATA=0

temizle() {
  rm -rf "$ESKI_DIR"
  if [ "${KORU:-0}" != "1" ]; then
    for d in "$A" "$B"; do
      docker compose exec -T db psql -U "$POSTGRES_USER" -d postgres \
        -c "DROP DATABASE IF EXISTS $d;" >/dev/null 2>&1
    done
  fi
}
trap temizle EXIT

alem() {  # <db> <contracts-dizini> <alembic-argumanlari>
  docker run --rm --network tesis_default -v "$2":/contracts:ro \
    -e DATABASE_URL="postgresql+psycopg://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$1" \
    tesis-migrate:latest sh -c "alembic -c /contracts/db/alembic.ini $3" 2>&1
}

kur() {
  docker compose exec -T db psql -U "$POSTGRES_USER" -d postgres \
    -c "DROP DATABASE IF EXISTS $1;" -c "CREATE DATABASE $1;" >/dev/null
}

# --- SEMANTIK SEMA DOKUMU (sira-duyarsiz) --------------------------------- #
sema_dok() {
  local db="$1" out="$2"
  {
    docker compose exec -T db psql -U "$POSTGRES_USER" -d "$db" \
      -v app_rol="$APP_DB_USER" -At -f - < sema-olgular.sql
  } | LC_ALL=C sort > "$out"
}

ham_dok() {
  docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$1" \
    --schema-only --no-owner --no-acl --no-comments \
    | grep -v '^\\\(un\)\?restrict ' > "$2"
}

echo "== ESKI agac cikariliyor: $ESKI_REF"
(cd "$KOK" && git archive "$ESKI_REF" contracts) | tar -x -C "$ESKI_DIR"
echo "   $(ls "$ESKI_DIR"/contracts/db/migrations/versions/*.py | wc -l) revizyon dosyasi"

echo "== YOL A: taze veritabani -> GUNCEL dosyalar -> head"
kur "$A"
alem "$A" "$KOK/contracts" "upgrade head" | grep -c "Running upgrade" | sed 's/^/   uygulanan revizyon: /'

echo "== YOL B/1: taze veritabani -> ESKI dosyalar -> head (prod'un ilk gocu)"
kur "$B"
alem "$B" "$ESKI_DIR/contracts" "upgrade head" | grep -c "Running upgrade" | sed 's/^/   uygulanan revizyon: /'
alem "$B" "$ESKI_DIR/contracts" "current" | tail -1 | sed 's/^/   revizyon: /'

echo "== YOL B/2: ayni veritabani -> GUNCEL dosyalar -> head (0008b burada kosar)"
B2="$(alem "$B" "$KOK/contracts" "upgrade head")"
if echo "$B2" | grep -qiE "Traceback|UndefinedColumn|sqlalchemy\.exc"; then
  echo "!! YOL B PATLADI:"; echo "$B2" | grep -iE "Error|does not exist|\[SQL:" | head -4 | sed 's/^/     /'
  HATA=$((HATA + 1))
else
  echo "$B2" | grep "Running upgrade" | sed 's/.*-> /   uygulanan: /;s/,.*//'
fi

# --- KARSILASTIRMA -------------------------------------------------------- #
sema_dok "$A" "$CIKTI/semantik-A.txt"
sema_dok "$B" "$CIKTI/semantik-B.txt"
ham_dok  "$A" "$CIKTI/ham-A.sql"
ham_dok  "$B" "$CIKTI/ham-B.sql"

echo "== [1] SEMANTIK KARSILASTIRMA ($(wc -l < "$CIKTI/semantik-A.txt") olgu)"
if diff -u "$CIKTI/semantik-A.txt" "$CIKTI/semantik-B.txt" > "$CIKTI/semantik-fark.txt"; then
  echo "OK   fark YOK — iki yol AYNI semayi uretiyor"
else
  echo "!!   $(grep -c '^[+-][^+-]' "$CIKTI/semantik-fark.txt") satir fark — $CIKTI/semantik-fark.txt"
  grep '^[+-][^+-]' "$CIKTI/semantik-fark.txt" | head -20 | sed 's/^/     /'
  HATA=$((HATA + 1))
fi

echo "== [2] HAM pg_dump farki (bilgi amacli — kolon SIRASI beklenir)"
if diff -u "$CIKTI/ham-A.sql" "$CIKTI/ham-B.sql" > "$CIKTI/ham-fark.txt"; then
  echo "OK   ham fark da YOK"
else
  echo "     $(grep -c '^[+-][^+-]' "$CIKTI/ham-fark.txt") satir; etkilenen tablolar:"
  grep -oE "^CREATE TABLE public\.[a-z_]+" -B0 "$CIKTI/ham-fark.txt" 2>/dev/null | sort -u | sed 's/.*public\./       /'
  awk '/^@@/{blok=$0} /^[+-][^+-]/{print blok"|"$0}' "$CIKTI/ham-fark.txt" \
    | grep -oE "^@@[^|]*" | sort -u | head -8 | sed 's/^/       /'
fi

echo "== bulgu: $HATA"
exit $((HATA > 0 ? 1 : 0))
