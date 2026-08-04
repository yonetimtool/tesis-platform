#!/usr/bin/env bash
# CADDY TESHISI — KOSAN yapilandirma ile BAGLI dosyayi karsilastirir.
#
# SUNUCUDA kosulur (Caddy kabina erisim gerekir).
#
# NEDEN: "depoda dogru ama sitede yanlis" durumunda tek belirleyici veri,
# Caddy'nin BELLEGINDEKI yapilandirmadir. Caddyfile prod'a bind-mount ile
# giriyor ve `docker compose up -d` bagli dosyanin ICERIGI degisti diye kabi
# yeniden olusturmaz — yani `git pull` sonrasi bagli dosya YENI, bellekteki
# yapilandirma ESKI olabilir. Bu betik ikisini yan yana koyar; tahmin
# gerekmez.
#
# CIKIS KODU: yapilandirmalar ayrisiyorsa 1.
set -uo pipefail

C=(docker compose -f "$(dirname "$0")/docker-compose.prod.yml" --env-file "$(dirname "$0")/.env.prod")

echo "== 1) BAGLI dosyanin uyarlanmis hali (caddy adapt)"
# `adapt` yalniz dosyayi okur, kosan yapilandirmaya DOKUNMAZ.
if ! "${C[@]}" exec -T caddy caddy adapt --config /etc/caddy/Caddyfile \
	>/tmp/caddy-bagli.json 2>/tmp/caddy-adapt.err; then
	echo "HATA: bagli Caddyfile UYARLANAMADI — su an yuklenmesi de mumkun degil:"
	cat /tmp/caddy-adapt.err
	exit 1
fi

echo "== 2) KOSAN yapilandirma (admin API :2019)"
if ! "${C[@]}" exec -T caddy wget -qO- http://127.0.0.1:2019/config/ \
	>/tmp/caddy-kosan.json 2>/dev/null; then
	echo "UYARI: admin API'ye ulasilamadi (kapali olabilir: `admin off`)."
	echo "       Karsilastirma yapilamiyor; yine de konak listesi asagida."
fi

ozet() { # ozet <json dosyasi> — konak -> isleyici ozeti
	python3 - "$1" <<'PY'
import json, sys
try:
    c = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  (okunamadi: {e})"); sys.exit(0)
srv = c.get("apps", {}).get("http", {}).get("servers", {})
def gez(x, bul):
    if isinstance(x, dict):
        h = x.get("handler")
        if h == "reverse_proxy":
            bul.append("proxy:" + ",".join(u.get("dial", "?") for u in x.get("upstreams", [])))
        elif h in ("file_server", "static_response", "vars", "rewrite"):
            bul.append(h)
        for v in x.values():
            gez(v, bul)
    elif isinstance(x, list):
        for v in x:
            gez(v, bul)
    return bul
satirlar = []
for s in srv.values():
    for r in s.get("routes", []):
        konaklar = [h for m in r.get("match", []) for h in m.get("host", [])]
        if konaklar:
            satirlar.append(f"  {','.join(sorted(konaklar))} -> {sorted(set(gez(r, [])))}")
print("\n".join(sorted(satirlar)) or "  (konak eslesmesi yok)")
PY
}

echo
echo "-- BAGLI dosya:"
ozet /tmp/caddy-bagli.json
echo
echo "-- KOSAN yapilandirma:"
ozet /tmp/caddy-kosan.json

echo
echo "== 3) Caddy kabinin ICINDEN yukari-akis denemesi"
# Vekilin hedefi ayakta mi? (Caddy 502 veriyorsa sorun admin-web'dedir.)
"${C[@]}" exec -T caddy wget -qS -O /dev/null http://admin-web:3000/login 2>&1 |
	sed -n '1,6p' | sed 's/^/  /'

echo
if diff <(ozet /tmp/caddy-bagli.json) <(ozet /tmp/caddy-kosan.json) >/dev/null 2>&1; then
	echo "SONUC: kosan yapilandirma = bagli dosya (Caddy GUNCEL)."
	exit 0
fi
echo "SONUC: KOSAN YAPILANDIRMA BAGLI DOSYADAN FARKLI — Caddy eski configle kosuyor."
echo
echo "  ${C[*]} exec caddy caddy validate --config /etc/caddy/Caddyfile"
echo "  ${C[*]} exec caddy caddy reload   --config /etc/caddy/Caddyfile"
exit 1
