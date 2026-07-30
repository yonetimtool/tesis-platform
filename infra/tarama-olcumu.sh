#!/usr/bin/env bash
# TARAMA OLCUMU — hangi uc, kac satiri SIRAYLA okuyor? (tur 77)
#
# NEDEN: "indeks var mi" ile "sorgu onu KULLANIYOR mu" ayri sorulardir. Tur 76
# semadaki indeksleri dogruladi (indekssiz FK yok) ama kullanimi olcmedi. Dev
# veritabaninda olcmek de ISE YARAMAZ: tablolarda 2-8 satir var ve o hacimde
# Postgres ZATEN seq scan secer — tam tarama orada kusur DEGILDIR.
#
# Bu betik tek-kullanimlik bir veritabanina temsil edici hacim yazar
# (`hacim-verisi.sql`: ~700 bin satir), API'nin GECICI bir ornegini o
# veritabanina yonlendirir, TUM GET uclarini surer ve her uc icin
# `pg_stat_user_tables.seq_tup_read` sayaclarini SIFIRLAYIP okur — yani hangi
# ucun kac satiri sirayla okudugunu UCA ATFEDER.
#
# ILK KOSUMUN BULDUGU (tur 77): `GET /activity` TEK istekte 350 BIN satir
# okuyordu. 13 kaynak `UNION ALL` ile birlesiyor ve LIMIT YALNIZ DIS sorguda
# uygulaniyordu; Postgres her kaynagin tamamini materyalize edip siraliyordu
# (EXPLAIN ANALYZE: `Parallel Seq Scan on scan_event`, top-N heapsort).
# Duzeltme: siralama+LIMIT her dala itildi (+ eksik dal indeksleri, 0009).
# Ayni olcum sonrasinda: 3 istek toplam 4 satir sirali okuma.
#
# ATIF ESIGI: bir istekte >= 10.000 satiri SIRAYLA okumak "tam tarama"
# sayilir. Agregat uclar (SUM) icin tam tarama DOGRU plandir; bu yuzden cikti
# bir KUSUR LISTESI degil, INCELEME listesidir.
#
# KAPSAM SINIRI: hacim yalniz 8 tabloya yazilir (scan_event, notification,
# audit_log, dues_payment, visitor, kargo, task, dues_assessment). Bos
# tablolar uzerinden gecen uclar bu olcumde SESSIZ kalir — "bulgu yok" onlar
# icin kanit DEGILDIR.
#
# KULLANIM:  infra/tarama-olcumu.sh
#            KORU=1 infra/tarama-olcumu.sh   (olcum db'sini silmez)
set -uo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a

DB="${OLCUM_DB:-hacim}"
PORT="${OLCUM_PORT:-8009}"
ESIK="${ESIK:-10000}"
C=(docker compose)

temizle() {
  [ -n "${CID:-}" ] && docker rm -f "$CID" >/dev/null 2>&1
  if [ "${KORU:-0}" != "1" ]; then
    "${C[@]}" exec -T db psql -U "$POSTGRES_USER" -d postgres \
      -c "DROP DATABASE IF EXISTS $DB;" >/dev/null 2>&1
  fi
}
trap temizle EXIT

echo "== [1/5] tek-kullanimlik veritabani: $DB"
"${C[@]}" exec -T db psql -U "$POSTGRES_USER" -d postgres \
  -c "DROP DATABASE IF EXISTS $DB;" -c "CREATE DATABASE $DB;" >/dev/null

echo "== [2/5] sema + app_rw rolu"
"${C[@]}" run --rm --no-deps \
  -e DATABASE_URL="postgresql+psycopg://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$DB" \
  -e OWNER_DSN="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$DB" \
  migrate sh -c 'alembic -c /contracts/db/alembic.ini upgrade head >/dev/null \
                 && python /scripts/setup_app_role.py >/dev/null' 2>&1 | grep -vi container || true

echo "== [3/5] sentetik hacim yukleniyor (dakikalar surebilir)"
"${C[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$DB" -q < hacim-verisi.sql 2>&1 | grep -i error || true
"${C[@]}" exec -T db psql -U "$POSTGRES_USER" -d "$DB" -Atc \
  "select 'satir toplami = '||coalesce(sum(n_live_tup),0) from pg_stat_user_tables where schemaname='public';"
# Giris icin gecerli bir admin (e-posta dogrulayici `.test` TLD'sini REDDEDER;
# ilk denemede login 422 dondu).
"${C[@]}" run --rm --no-deps \
  -e OWNER_DSN="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$DB" \
  migrate python -m scripts.create_admin --email admin@example.com \
  --password 'Hacim1!x' --tenant-slug hacim --tenant-name Hacim >/dev/null 2>&1

echo "== [4/5] gecici API ornegi (port $PORT)"
CID=$("${C[@]}" run -d --rm --no-deps -p "$PORT:8000" \
  -e DATABASE_URL="postgresql+asyncpg://$APP_DB_USER:$APP_DB_PASSWORD@db:5432/$DB" \
  api 2>/dev/null | tail -1)
for _ in $(seq 1 60); do
  curl -sf "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break; sleep 1
done
curl -sf "http://127.0.0.1:$PORT/health" >/dev/null || { echo "!! gecici API kalkmadi"; exit 1; }

echo "== [5/5] TUM GET uclari suruluyor + uca atif"
OLCUM_PORT="$PORT" OLCUM_DB="$DB" ESIK="$ESIK" \
  POSTGRES_USER="$POSTGRES_USER" python3 - <<'PY'
import json, os, re, subprocess, time, urllib.error, urllib.request, uuid, yaml
PORT = os.environ["OLCUM_PORT"]; DB = os.environ["OLCUM_DB"]
ESIK = int(os.environ["ESIK"]); BASE = f"http://127.0.0.1:{PORT}"
BEKLE = float(os.environ.get("BEKLE", "1.0"))

def psql(sql):
    return subprocess.run(
        ["docker", "compose", "exec", "-T", "db", "psql", "-U",
         os.environ["POSTGRES_USER"], "-d", DB, "-Atc", sql],
        capture_output=True, text=True).stdout

def istek(metot, yol, tok=None, govde=None):
    r = urllib.request.Request(BASE + yol, method=metot)
    if tok:
        r.add_header("Authorization", "Bearer " + tok)
    if govde is not None:
        r.add_header("Content-Type", "application/json")
        r.data = json.dumps(govde).encode()
    try:
        with urllib.request.urlopen(r, timeout=180) as f:
            return f.status, f.read()
    except urllib.error.HTTPError as e:
        return e.code, b""
    except Exception as e:                      # noqa: BLE001
        return str(e), b""

kod, gov = istek("POST", "/auth/login", govde={
    "tenant_slug": "hacim", "email": "admin@example.com", "password": "Hacim1!x"})
assert kod == 200, (kod, gov[:300])
tok = json.loads(gov)["access_token"]

spec = yaml.safe_load(open("../contracts/openapi.yaml", encoding="utf-8"))
bulgular, surulen = [], 0
for yol, ops in spec["paths"].items():
    if "get" not in ops:
        continue
    u = yol
    for ad in re.findall(r"\{([^}]+)\}", yol):
        u = u.replace("{" + ad + "}", str(uuid.uuid4()))
    # YARIS: pg_stat sayaclari ASENKRON flush edilir (~500ms). Reset ile istek
    # arasinda ve istek ile okuma arasinda beklemezsek bir ucun taramasi BASKA
    # bir uca atfedilir. Ilk kosumda tam olarak bu oldu: /dues/payments 125.754
    # + /budget/categories 74.246 = 200.000 (tek tablonun tamami iki uca
    # BOLUNMUS gorunuyordu).
    psql("select pg_stat_reset();")
    time.sleep(BEKLE)
    kod, _ = istek("GET", u, tok)
    time.sleep(BEKLE)
    if not (isinstance(kod, int) and kod < 300):
        continue
    surulen += 1
    agir = []
    for satir in psql(
        "select relname||':'||seq_tup_read from pg_stat_user_tables "
        "where schemaname='public' and seq_tup_read >= %d "
        "order by seq_tup_read desc" % ESIK
    ).strip().splitlines():
        if satir:
            t, _, n = satir.partition(":")
            agir.append(f"{t}={int(n)}")
    if agir:
        bulgular.append((yol, agir))

print(f"\n{surulen} GET ucu 2xx dondu; {len(bulgular)} tanesi tek istekte "
      f">= {ESIK} satiri SIRAYLA okuyor:")
for yol, agir in sorted(bulgular, key=lambda x: -max(int(a.split("=")[1]) for a in x[1])):
    print(f"   {yol:44} {' '.join(agir)}")
if not bulgular:
    print("   (yok)")
PY
