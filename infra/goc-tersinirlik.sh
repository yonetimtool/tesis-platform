#!/usr/bin/env bash
# GOC TERSINIRLIK OLCUMU — downgrade yolu hic kosulmamisti (tur 71).
#
# `contracts/db/migrations/versions/*.py` dosyalarinin hepsinde `downgrade()`
# var, ama otomatik hicbir olcum onlari CALISTIRMIYORDU: `migrate` servisi
# yalnizca `upgrade head` yapar, testler zaten kurulu semaya baglanir. Yani
# geri alma kodu "yazilmis ama denenmemis" durumdaydi.
#
# OLCTUGU UC SEY (uc ayri hata sinifi):
#
#   1. ARTIK: `downgrade base` sonrasi public sema BOS mu? Bir migration
#      olusturdugu tabloyu/tipi/fonksiyonu/sequence'i dusurmeyi atlarsa burada
#      cikar. (Eklentilerin — pgcrypto, btree_gist — fonksiyonlari ve alembic'in
#      kendi `alembic_version` tablosu haric tutulur; onlar migration'in isi
#      degil.)
#
#   2. TERSINIRLIK: upgrade -> downgrade base -> upgrade sonrasi sema, DUZ
#      upgrade ile AYNI mi? "Hata vermedi" yetmez; geri alma sema kaybi ya da
#      kalinti birakabilir. Iki tek-kullanimlik veritabaninin `pg_dump
#      --schema-only` ciktilari karsilastirilir.
#
#   3. SALINIM: her revizyon icin `downgrade -1` + `upgrade +1` IKI KEZ. Bu,
#      yalnizca toplu geri alista calisan ama tek adimda bozulan (ornegin
#      `CREATE` yolu `IF NOT EXISTS`siz olup yarim dusurulen bir nesneye
#      carpan) migration'lari yakalar.
#
# GECERLILIK KOSULU: dev veritabanina DOKUNULMAZ. Olcum `goc_a`/`goc_b` adli
# iki tek-kullanimlik veritabaninda yapilir ve sonunda dusurulur.
#
# DENEY MODU — bu betik de bir olcum aracidir, o yuzden kendisi sinanir:
#   DENEY=1  downgrade base sonrasi kasten bir artik tablo birakir  -> 1 patlamali
#   DENEY=2  ikinci upgrade sonrasi kasten bir kolon dusurur        -> 2 patlamali
#   DENEY=3  salinimdan once `camera`ya bagli bir gorunum yaratir; 0005'in
#            `DROP TABLE camera`i bagimlilik yuzunden patlar             -> 3
# Uc deneyde de ilgili kontrol KIRMIZI donmezse arac KOR demektir.
#
# KULLANIM:  infra/goc-tersinirlik.sh          (olcum)
#            DENEY=1 infra/goc-tersinirlik.sh  (aracin kendi sinamasi)
set -uo pipefail

cd "$(dirname "$0")"
set -a; . ./.env; set +a

DENEY="${DENEY:-0}"
CIKTI="${CIKTI:-/tmp/goc-tersinirlik}"
mkdir -p "$CIKTI"
INI=/contracts/db/alembic.ini
HATA=0

pg() { docker compose exec -T db psql -U "$POSTGRES_USER" -d "$1" -Atq -v ON_ERROR_STOP=1 "${@:2}"; }
alem() {
  local db="$1"; shift
  docker compose run --rm --no-deps \
    -e DATABASE_URL="postgresql+psycopg://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$db" \
    migrate sh -c "alembic -c $INI $*" 2>&1
}

echo "== tek-kullanimlik veritabanlari kuruluyor"
for d in goc_a goc_b; do
  pg postgres -c "DROP DATABASE IF EXISTS $d;" -c "CREATE DATABASE $d;" >/dev/null
done

echo "== goc_a: duz upgrade head (referans sema)"
alem goc_a upgrade head > "$CIKTI/a-ileri.log"
grep -qi "error\|Traceback" "$CIKTI/a-ileri.log" && { echo "!! referans upgrade PATLADI"; HATA=1; }

echo "== goc_b: upgrade head"
alem goc_b upgrade head > "$CIKTI/b-ileri1.log"

echo "== goc_b: downgrade base (ilk kez kosuyor)"
alem goc_b downgrade base > "$CIKTI/b-geri.log"
if grep -qi "error\|Traceback" "$CIKTI/b-geri.log"; then
  echo "!! [1] GERI ALMA PATLADI — $CIKTI/b-geri.log"; HATA=1
fi

if [ "$DENEY" = "1" ]; then
  echo "   (DENEY=1: kasten artik tablo birakiliyor)"
  pg goc_b -c "CREATE TABLE public.deney_artik(id int);" >/dev/null
fi

# --- KONTROL 1: ARTIK -------------------------------------------------------
# Eklenti fonksiyonlari (pg_depend uzerinden) ve alembic_version haric tutulur.
ARTIK=$(pg goc_b -c "
  select 'TABLO '||tablename from pg_tables
    where schemaname='public' and tablename <> 'alembic_version'
  union all
  select 'TIP '||t.typname from pg_type t join pg_namespace n on n.oid=t.typnamespace
    where n.nspname='public' and t.typtype='e'
  union all
  select 'FONKSIYON '||p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and not exists (select 1 from pg_depend d
                      where d.objid=p.oid and d.deptype='e')
  union all
  select 'SEQ '||sequencename from pg_sequences where schemaname='public'
  union all
  select 'GORUNUM '||viewname from pg_views where schemaname='public'
  order by 1;")
if [ -n "$ARTIK" ]; then
  echo "!! [1] ARTIK KALDI ($(echo "$ARTIK" | wc -l) nesne):"; echo "$ARTIK" | sed 's/^/     /'
  HATA=$((HATA + 1))
else
  echo "OK [1] downgrade base sonrasi public sema bos"
fi

echo "== goc_b: upgrade head (tekrar)"
alem goc_b upgrade head > "$CIKTI/b-ileri2.log"
if grep -qi "error\|Traceback" "$CIKTI/b-ileri2.log"; then
  echo "!! [2] GERI ALMA SONRASI YENIDEN ILERI PATLADI — $CIKTI/b-ileri2.log"; HATA=$((HATA + 1))
fi

if [ "$DENEY" = "2" ]; then
  echo "   (DENEY=2: kasten bir kolon dusuruluyor)"
  pg goc_b -c "ALTER TABLE notification DROP COLUMN mesaj_kimlik;" >/dev/null
fi

# --- KONTROL 2: TERSINIRLIK -------------------------------------------------
# pg_dump her kosumda rastgele bir \restrict belirteci basar; o satirlar atilir.
for d in goc_a goc_b; do
  docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$d" \
    --schema-only --no-owner --no-acl --no-comments \
    | grep -v '^\\\(un\)\?restrict ' > "$CIKTI/sema-$d.sql"
done
if diff -u "$CIKTI/sema-goc_a.sql" "$CIKTI/sema-goc_b.sql" > "$CIKTI/sema-diff.txt"; then
  echo "OK [2] gidis-donus sonrasi sema duz upgrade ile AYNI ($(wc -l < "$CIKTI/sema-goc_a.sql") satir)"
else
  echo "!! [2] SEMA FARKLI ($(grep -c '^[+-][^+-]' "$CIKTI/sema-diff.txt") satir) — $CIKTI/sema-diff.txt"
  head -20 "$CIKTI/sema-diff.txt" | sed 's/^/     /'
  HATA=$((HATA + 1))
fi

# --- KONTROL 3: SALINIM ----------------------------------------------------
# head'ten base'e ADIM ADIM inerken her sinirda -1/+1/-1: net bir adim asagi,
# ama o sinir IKI KEZ geri alinip BIR KEZ yeniden uygulanmis olur. Revizyon adi
# gerekmez; alembic'in goreli adimlamasi kullanilir.
SAY=$(ls ../contracts/db/migrations/versions/*.py | wc -l)
SALINIM_HATA=0
if [ "$DENEY" = "3" ]; then
  echo "   (DENEY=3: camera'ya bagli gorunum — 0005'in DROP TABLE'ini bloke eder)"
  pg goc_b -c "CREATE VIEW public.deney_bagli AS SELECT id FROM public.camera;" >/dev/null
fi
for i in $(seq 1 "$SAY"); do
  CIK=$(alem goc_b "downgrade -1 && alembic -c $INI upgrade +1 && alembic -c $INI downgrade -1")
  if [ $? -ne 0 ] || echo "$CIK" | grep -qi "Traceback\|FAILED\|sqlalchemy\.exc"; then
    echo "!! [3] SALINIM PATLADI (head'ten $i. adim)"
    echo "$CIK" | grep -i "error\|Traceback" | head -3 | sed 's/^/     /'
    SALINIM_HATA=$((SALINIM_HATA + 1))
  fi
done
if [ "$SALINIM_HATA" -eq 0 ]; then
  echo "OK [3] $SAY sinirin her biri iki kez geri alinip yeniden uygulandi"
else
  HATA=$((HATA + SALINIM_HATA))
fi

echo "== temizlik"
for d in goc_a goc_b; do pg postgres -c "DROP DATABASE IF EXISTS $d;" >/dev/null; done

if [ "$DENEY" != "0" ]; then
  echo "== DENEY=$DENEY: yukarida ilgili kontrol KIRMIZI donmediyse arac KOR."
fi
echo "== bulgu: $HATA"
exit $((HATA > 0 ? 1 : 0))
