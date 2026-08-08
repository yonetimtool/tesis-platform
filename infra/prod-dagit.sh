#!/usr/bin/env bash
# (P150) PROD DAGITIM KAPISI — kapali test suresince DONDURMA korumasi.
#
# NEDEN VAR: kapali test testcilerin istemcisi MEVCUT kimlik sistemine
# bagli. Backend P142-148 ile degisirse testciler GIRIS YAPAMAZ ve Google'in
# 14 gunluk sayaci SIFIRLANIR. Kaza sonucu tek bir `up -d --build` 14 gunu
# yakar; bu yuzden dagitim artik dogrudan compose ile DEGIL buradan yapilir.
#
# KILIT DOSYASI ile calisir (infra/.prod-dondurma). Dosya VARSA dagitim
# reddedilir. Acmak icin dosyayi silmek YETMEZ — bilerek iki adim:
# ortam degiskeniyle gerekce yazilmasi gerekir ki "elim kaydi" olmasin.
set -euo pipefail
KOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KILIT="$KOK/infra/.prod-dondurma"
COMPOSE=(docker compose -f "$KOK/infra/docker-compose.prod.yml" --env-file "$KOK/infra/.env.prod")

if [ -f "$KILIT" ]; then
  echo "=================================================================="
  echo " PROD DONDURULMUS — dagitim REDDEDILDI"
  echo "=================================================================="
  cat "$KILIT" | sed 's/^/  /'
  echo
  echo "  Kapali test suruyorsa DAGITMA. Testcilerin istemcisi mevcut"
  echo "  kimlik sistemine bagli; backend degisirse giris yapamazlar ve"
  echo "  Google'in 14 gunluk sayaci SIFIRLANIR."
  echo
  echo "  KRITIK HATA DUZELTMESI gerekiyorsa (bkz. docs/MASTER-PLAN P150):"
  echo "    1) Duzeltmeyi kapali test dalindan (play-closed-test-1) TUREVLE"
  echo "       ayir — main'deki P142-148 ile BIRLIKTE gitmesin."
  echo "    2) ACIL_GEREKCE='...' PROD_DONDURMA_BYPASS=1 $0 <servis...>"
  echo "    3) Dagitimdan sonra testcilerin girisini ELLE dogrula."
  echo
  if [ "${PROD_DONDURMA_BYPASS:-0}" != "1" ]; then exit 1; fi
  [ -n "${ACIL_GEREKCE:-}" ] || { echo "  HATA: ACIL_GEREKCE bos — bypass reddedildi."; exit 1; }
  echo "  ! BYPASS: ${ACIL_GEREKCE}"
  printf '%s  BYPASS: %s\n' "$(date -Is)" "$ACIL_GEREKCE" >> "$KOK/infra/.prod-dondurma-gecmis"
fi

# Caddy yapilandirmasi degistiyse ON KONTROL sart (P149: bir Caddyfile
# degisikligi prod'u tamamen dusurmustu).
if [ -f "$KOK/infra/caddy-onkontrol.sh" ]; then
  bash "$KOK/infra/caddy-onkontrol.sh" >/dev/null || {
    echo "HATA: Caddy on kontrolu GECMEDI — dagitim durduruldu."; exit 1; }
  echo "  OK   Caddy on kontrolu gecti"
fi

echo "== Dagitiliyor: ${*:-<tum servisler>}"
"${COMPOSE[@]}" up -d --build "$@"
