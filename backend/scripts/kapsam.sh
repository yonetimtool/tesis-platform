#!/usr/bin/env sh
# BACKEND KAPSAM OLCUMU — dogru yol (tur 69-70).
#
# Bu betik var, cunku backend kapsamini olcmenin UC tuzagi var ve ucu de
# yasandi. Komutu ezberden yazmak yerine burada kilitlendi.
#
#  1. YANLIS SUREC. Testler canli sunucuya HTTP ile gidiyor (`conftest.py`
#     `client` fixture'i). `pytest --cov=app` yalnizca TEST surecini olcer;
#     istek isleme ayri uvicorn surecinde oldugu icin router'lar hic sayilmaz.
#     -> Sunucu da araclandirilir.
#
#  2. YANLIS IZLEYICI. coverage'in varsayilan C izleyicisi bu kurulumda async
#     uc govdelerini GUVENILMEZ izliyor: `POST /residents` sunucu gunlugunde
#     "201 Created" gorunurken govdesi "kapsanmamis" raporlaniyordu (tur 69).
#     Python 3.12'nin `sys.monitoring` cekirdegi dogru olcuyor.
#     -> `COVERAGE_CORE=sysmon` SART. Tek dosyada %31 -> %92, toplamda
#        %72 -> %89 fark yaratti.
#
#  3. TEK SUREC YETMEZ. Zamanlayici/Celery kodu (`retention.py`,
#     `scheduler/*`, `tasks.py`) HTTP ile degil DOGRUDAN testlerden cagriliyor,
#     yani PYTEST surecinde kosuyor. Yalniz sunucuyu olcmek onlari %0
#     gosteriyordu — "test yok" degil, "bu surecte kosmuyor" demekti.
#     -> Iki surec `--parallel-mode` + `coverage combine` ile birlestirilir.
#
# KULLANIM (konteyner icinde):
#   docker compose exec -T api sh /app/scripts/kapsam.sh
# Tek dosya icin:
#   docker compose exec -T api sh /app/scripts/kapsam.sh tests/test_residents.py
set -eu

PORT="${KAPSAM_PORT:-8007}"
HEDEF="${1:-}"

cd /app
rm -f .coverage .coverage.*

export COVERAGE_CORE=sysmon

coverage run --parallel-mode --source=app \
  -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT" >/tmp/kapsam-uvicorn.log 2>&1 &
SRV=$!

# Sunucu ayaga kalksin (health).
i=0
while [ "$i" -lt 60 ]; do
  if python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:$PORT/health')" >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 1
done
echo "[kapsam] sunucu hazir (sysmon, port $PORT)"

# Test sureci de araclandirilir: zamanlayici/Celery kodu burada kosuyor.
API_URL="http://127.0.0.1:$PORT" coverage run --parallel-mode --source=app \
  -m pytest -q ${HEDEF:+$HEDEF} 2>&1 | tail -3

# Sunucuyu nazikce kapat: coverage verisi cikista yazilir.
kill -INT "$SRV" 2>/dev/null || true
wait "$SRV" 2>/dev/null || true

coverage combine >/dev/null 2>&1
# Rapor DOSYAYA yazilir: `coverage report | head` erken kapanan boruda
# BrokenPipeError veriyor (ilk kosumda oldu).
coverage report --sort=cover >/tmp/kapsam-rapor.txt 2>&1 || true
echo "[kapsam] --- EN DUSUK 15 ---"
head -19 /tmp/kapsam-rapor.txt
echo "[kapsam] --- TOPLAM ---"
tail -2 /tmp/kapsam-rapor.txt
