#!/usr/bin/env bash
# (P149-fix) CADDY ON KONTROLU — dagitimdan ONCE, GERCEK .env.prod ile.
#
# NEDEN VAR: bir Caddyfile degisikligi prod'u tamamen dusurdu
# ("ambiguous site definition: panel.yonetio.site"). `caddy validate`
# calistirilmisti ve GECMISTI — ama BENIM env degerlerimle. Gercek
# `.env.prod`da PANEL_DOMAIN hala eski adi tasiyordu ve ayni ad iki blokta
# gorunuyordu.
#
# DERS: yapilandirma DEGISKENLIYSE, dogrulama da GERCEK DEGISKENLERLE
# yapilmalidir. Bos ortamla gecen bir validate hicbir sey kanitlamaz.
set -euo pipefail

KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVDOSYA="${1:-$KOK/infra/.env.prod}"
CADDYFILE="$KOK/infra/Caddyfile"

[ -f "$ENVDOSYA" ] || { echo "HATA: env dosyasi yok: $ENVDOSYA"; exit 2; }
[ -f "$CADDYFILE" ] || { echo "HATA: Caddyfile yok: $CADDYFILE"; exit 2; }

# .env.prod'daki DEGISKENLERI konteynere aktar (degerleri EKRANA YAZMA —
# dosyada parolalar da var).
echo "== Caddy on kontrolu: $CADDYFILE  (env: $ENVDOSYA)"
# `grep -q` KULLANMA: eslesince erken cikar, `pipefail` altinda boru
# hattini HATALI sayar ve CALISAN yapilandirmayi reddeder (ilk yazimda
# tam olarak bu oldu). Once yakala, sonra ara.
docker run --rm \
      -v "$CADDYFILE:/etc/caddy/Caddyfile:ro" \
      --env-file "$ENVDOSYA" \
      caddy:2-alpine \
      caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile \
      > /tmp/caddy-onkontrol.log 2>&1 || true

if grep -q "Valid configuration" /tmp/caddy-onkontrol.log; then
  echo "  OK   yapilandirma GERCEK env ile yuklenebiliyor"
else
  echo "  HATA yapilandirma YUKLENEMEDI — dagitim YAPMA."
  echo "  --- caddy ciktisi ---"
  grep -iE "ambiguous|error|invalid" /tmp/caddy-onkontrol.log | head -10 \
    || tail -10 /tmp/caddy-onkontrol.log
  exit 1
fi

# ALAN ADI -> BLOK HARITASI, Caddyfile'in KENDISINDEN.
#
# Uretilen JSON'u saymak YANILTICIYDI: bir ad orada matcher, yonlendirme
# hedefi ve otomatik-HTTPS listesi olarak MESRU sekilde tekrar eder;
# "3 yerde" ciktisi cakisma KANITI DEGILDIR. Blok basliklarini kaynaktan
# okuyup degiskenleri gercek degerleriyle acmak ise kesin bilgi verir.
echo "== Alan adi -> blok haritasi (kaynaktan)"
set -a; . "$ENVDOSYA"; set +a
grep -nE '^[^[:space:]#].*\{$' "$CADDYFILE" \
  | grep -v '^[0-9]*:(' \
  | while IFS= read -r satir; do
      no="${satir%%:*}"; govde="${satir#*:}"; govde="${govde%\{}"
      echo "  satir $no: $(eval echo "$govde" | tr -d '{}')"
    done

# CAKISMA = ayni ad IKI FARKLI BLOKTA. Ayni blok icindeki tekrar
# ZARARSIZDIR (Caddy kabul eder) ve yalnizca "eski degisken kanonikle ayni
# degere ayarlanmis" demektir — uyarilir, dagitim durdurulmaz. Ilk yazimda
# ikisini ayirt etmiyordum ve dogru yapilandirmayi HATALI sayiyordum.
tmpb=$(mktemp)
grep -E '^[^[:space:]#].*\{$' "$CADDYFILE" | grep -v '^(' | nl -ba \
  | while IFS=$'\t' read -r idx b; do
      for ad in $(eval echo "${b%\{}" | tr ',' ' '); do
        echo "$idx $(printf %s "$ad" | tr -d '{}')"
      done
    done | sort -u > "$tmpb"

cakisma=$(awk '{print $2}' "$tmpb" | sort | uniq -d)
rm -f "$tmpb"
if [ -n "$cakisma" ]; then
  echo "  ! CAKISMA: ayni ad IKI FARKLI blokta — Caddy acilmaz:"
  echo "$cakisma" | sed 's/^/    /'
  exit 1
fi
echo "  OK  hicbir ad iki FARKLI blokta degil"

echo "SONUC: on kontrol GECTI — dagitilabilir."
