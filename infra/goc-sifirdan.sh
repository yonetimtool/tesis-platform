#!/usr/bin/env bash
# (P171 duzeltme) SIFIRDAN GOC KAPISI — gercek migrate konteyneri, bos veritabani.
#
# =========================================================================
# NEDEN VAR: "UC TAKIM YESIL" ORTAMDA CALISTIGI ANLAMINA GELMIYOR
# =========================================================================
# P171'de backend/web/mobil takimlarinin ucu de yesildi ve dagitim
# ORTAMI DUSURDU. Goc 0066 `app.temizleme`yi ithal ediyordu; geliştiricinin
# imaji TAZE oldugu icin ithal basariliydi ve kusur hicbir yerde gorunmedi.
# Dagitilan ortamda `contracts/` (canli mount) YENIYDI ama imaj ESKIYDI ->
# `ModuleNotFoundError` -> goc dustu -> `api`, `admin-web` ve `worker`
# (migrate'e `service_completed_successfully` ile bagli) HIC BASLAMADI.
#
# Bu kapinin olctugu sey: DEPODAKI HALIYLE kurulan bir migrate imaji, BOS
# bir veritabaninda zinciri BASTAN SONA kosabiliyor mu.
#
# =========================================================================
# NEDEN MEVCUT KAPILAR YETMEDI
# =========================================================================
#   * `goc-tersinirlik.sh` gercek konteynerde kosar ama O AN KURULU imajla
#     ve mevcut veritabani sunucusundaki tek-kullanimlik semalarda. Imajin
#     depoyla UYUMLU olup olmadigini olcmez.
#   * `test_goc_bagimsizligi.py` statik olcumdur: `app.*` ithalini yakalar
#     ama "imajda gercekten kosuyor mu" sorusunu yanitlamaz (ornegin
#     `nh3` eksikse orada gorunmez).
# Ikisi TAMAMLAYICIDIR; biri sinifi, oteki calisirligi kapatir.
#
# =========================================================================
# GECERLILIK KOSULLARI
# =========================================================================
#   * IMAJ YENIDEN KURULUR (`--no-cache` DEGIL ama `build`): bayat bir imaj
#     tam olarak kacirdigimiz kusuru yeniden kacirirdi.
#   * VERITABANI SIFIRDAN: `alembic_version` bos. Mevcut dev veritabanina
#     DOKUNULMAZ; ayri, tek kullanimlik bir veritabani acilip dusurulur.
#   * SON REVIZYON, dosyalardan hesaplanan HEAD ile ESLESMELI. "Hata
#     vermedi" yetmez: zincir ortada durmus olabilir.
#
# DENEY MODU: `--deney` gecici bir bozuk goc yazip kapinin GERCEKTEN
# kirildigini gosterir — bir kapi, kirilabildigini kanitlayana kadar
# kapi degildir.
set -euo pipefail

KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$KOK/infra"

# shellcheck disable=SC1091
set -a; . ./.env 2>/dev/null || true; set +a
: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_PASSWORD:=postgres}"

DB="goc_sifir_$$"
INI=/contracts/db/alembic.ini
DENEY=0
[ "${1:-}" = "--deney" ] && DENEY=1

pg() { docker compose exec -T db psql -U "$POSTGRES_USER" -d postgres -Atq -v ON_ERROR_STOP=1 -c "$1"; }

temizle() {
  pg "DROP DATABASE IF EXISTS \"$DB\";" >/dev/null 2>&1 || true
  [ -n "${DENEY_DOSYA:-}" ] && rm -f "$DENEY_DOSYA"
  return 0
}
trap temizle EXIT

echo ">> 1/4 migrate imaji DEPODAKI haliyle kuruluyor..."
docker compose build migrate >/dev/null

echo ">> 2/4 bos veritabani: $DB"
pg "CREATE DATABASE \"$DB\";" >/dev/null

if [ "$DENEY" = 1 ]; then
  # Kapinin KIRILABILDIGINI kanitla: uygulama kodunu ithal eden bir goc.
  DENEY_DOSYA="$KOK/contracts/db/migrations/versions/9999_deney_bozuk.py"
  SON=$(grep -h '^revision = ' "$KOK"/contracts/db/migrations/versions/*.py \
        | sed 's/.*"\(.*\)"/\1/' | sort | tail -1)
  cat > "$DENEY_DOSYA" <<EOF
"""DENEY — kapinin kirildigini gosterir. Betik bunu kendisi siler."""
revision = "9999_deney_bozuk"
down_revision = "$SON"
branch_labels = None
depends_on = None


def upgrade() -> None:
    import app.bulunmayan_modul  # noqa: F401


def downgrade() -> None:
    pass
EOF
  echo ">> DENEY: bozuk goc yazildi ($SON -> 9999_deney_bozuk)"
fi

echo ">> 3/4 zincir kosuluyor: alembic upgrade head"
CIKIS=0
docker compose run --rm --no-deps \
  -e DATABASE_URL="postgresql+psycopg://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$DB" \
  migrate sh -c "alembic -c $INI upgrade head" || CIKIS=$?

if [ "$DENEY" = 1 ]; then
  if [ "$CIKIS" = 0 ]; then
    echo "!! DENEY BASARISIZ: bozuk goc GECTI — kapi olcmuyor." >&2
    exit 1
  fi
  echo ">> DENEY OK: kapi bozuk gocta kirildi (cikis $CIKIS)."
  exit 0
fi

if [ "$CIKIS" != 0 ]; then
  echo "!! GOC ZINCIRI SIFIR VERITABANINDA DUSTU (cikis $CIKIS)." >&2
  echo "   Bu, dagitimda 'api/admin-web/worker hic baslamadi' demektir:" >&2
  echo "   ucu de migrate'e 'service_completed_successfully' ile baglidir." >&2
  exit 1
fi

echo ">> 4/4 son revizyon dogrulaniyor"
VARILAN=$(pg "SELECT version_num FROM \"$DB\".pg_catalog.pg_class LIMIT 0;" >/dev/null 2>&1; \
          docker compose exec -T db psql -U "$POSTGRES_USER" -d "$DB" -Atq \
            -c "SELECT version_num FROM alembic_version;")
BEKLENEN=$(python3 - "$KOK/contracts/db/migrations/versions" <<'PY'
import pathlib, re, sys
d = pathlib.Path(sys.argv[1])
rev, onceki = set(), set()
for f in d.glob("*.py"):
    g = f.read_text(encoding="utf-8")
    r = re.search(r'^revision = "([^"]+)"', g, re.M)
    p = re.search(r'^down_revision = "([^"]+)"', g, re.M)
    if r: rev.add(r.group(1))
    if p: onceki.add(p.group(1))
uc = rev - onceki
print(uc.pop() if len(uc) == 1 else "")
PY
)
if [ -z "$BEKLENEN" ]; then
  echo "!! Zincirde TEK UC yok — HEAD belirsiz." >&2
  exit 1
fi
if [ "$VARILAN" != "$BEKLENEN" ]; then
  echo "!! Zincir ORTADA DURDU: varilan '$VARILAN', beklenen '$BEKLENEN'." >&2
  exit 1
fi

echo "OK — sifir veritabaninda zincir bastan sona kostu: $VARILAN"
