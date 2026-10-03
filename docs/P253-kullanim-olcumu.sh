#!/usr/bin/env bash
# (P253 §B) WEB SAYFA KULLANIMI — SALT OKUMA. Son 30 gunde hangi tesis
# sayfasi (app.*) kac kez ACILDI.
#
# KVKK: girdi zaten kisisel veri tasimaz — Caddy `erisim_gunlugu`
# (infra/Caddyfile) IP'yi, basliklari ve URI sorgusunu KAYNAKTA siler;
# on-yuklemeler, statik dosyalar ve /api/* hic yazilmaz. Bu betik yalniz
# YOL ve SAYI cikarir; kimlik iceren yol parcalari ([id]) maskelenir.
#
# KULLANIM (prod sunucusunda, depo kokunde):
#   bash docs/P253-kullanim-olcumu.sh            # son 30 gun
#   GUN=7 bash docs/P253-kullanim-olcumu.sh      # son 7 gun
#
# Gunluk ilk dagitimdan ITIBAREN birikir; acilmadan onceki gunler yoktur.
set -euo pipefail
GUN="${GUN:-30}"
COMPOSE=(docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod)

# Gunluk caddy konteynerinin /data biriminde; doner (rotated) dosyalar gzip.
"${COMPOSE[@]}" exec -T caddy sh -c '
  ls /data/erisim/ >/dev/null 2>&1 || { echo "GUNLUK YOK: /data/erisim (erisim_gunlugu dagitildi mi?)" >&2; exit 3; }
  for f in /data/erisim/*; do
    case "$f" in *.gz) zcat "$f" ;; *.log) cat "$f" ;; esac
  done
' | GUN="$GUN" python3 -c '
import json, os, re, sys, time
from collections import Counter
sinir = time.time() - int(os.environ["GUN"]) * 86400
KIMLIK = re.compile(r"/(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\d+)(?=/|$)", re.I)
sayac, ilk, son, toplam = Counter(), None, None, 0
for satir in sys.stdin:
    try:
        k = json.loads(satir)
    except ValueError:
        continue
    ts = k.get("ts", 0)
    if ts < sinir:
        continue
    r = k.get("request", {})
    if r.get("method") != "GET" or k.get("status") not in (200, 304):
        continue
    yol = KIMLIK.sub("/[id]", (r.get("uri") or "/").split("?")[0]) or "/"
    sayac[yol] += 1
    toplam += 1
    ilk = ts if ilk is None or ts < ilk else ilk
    son = ts if son is None or ts > son else son
if not toplam:
    print("Kayit yok (son %s gun)." % os.environ["GUN"]); sys.exit(0)
fmt = lambda t: time.strftime("%Y-%m-%d", time.localtime(t))
print("Donem: %s .. %s  ·  toplam sayfa acilisi: %d" % (fmt(ilk), fmt(son), toplam))
print("%8s  %6s  %s" % ("ACILIS", "%", "ROTA"))
for yol, n in sayac.most_common():
    print("%8d  %5.1f%%  %s" % (n, 100.0 * n / toplam, yol))
'
