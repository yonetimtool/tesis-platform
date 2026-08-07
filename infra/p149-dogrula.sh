#!/usr/bin/env bash
# (P149) Alan adi tasimasi — DAGITIM SONRASI dogrulama.
# Kullanim: bash infra/p149-dogrula.sh
set -u
# DAGITIMDAN ONCE: bash infra/caddy-onkontrol.sh  (GERCEK .env.prod ile
# yapilandirmanin yuklenebildigini dogrular — bu betik DAGITIM SONRASIDIR).
YENI="yonetiyor.com"; IDN="xn--ynetiyor-n4a.com"; ESKI="yonetio.site"
hata=0

kod() { curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$1" 2>/dev/null || echo 000; }

bekle() { # url beklenen etiket
  local g; g=$(kod "$1")
  if [ "$g" = "$2" ]; then echo "  OK   $3 ($g)"; else echo "  HATA $3 -> $g (beklenen $2)"; hata=1; fi
}

echo "== ASIL HIZMET (200 bekleniyor)"
bekle "https://$YENI/hesap-silme" 200 "$YENI/hesap-silme"   # Play formuna girilecek
bekle "https://$YENI/gizlilik"    200 "$YENI/gizlilik"
bekle "https://$YENI/"            200 "$YENI/"
bekle "https://www.$YENI/"        200 "www.$YENI/"
bekle "https://app.$YENI/"        200 "app.$YENI/"
bekle "https://panel.$YENI/"      200 "panel.$YENI/"

echo "== YONLENDIRME (301 bekleniyor)"
bekle "https://$IDN/hesap-silme"   301 "$IDN -> yeni"
bekle "https://$ESKI/hesap-silme"  301 "$ESKI -> yeni"
bekle "https://app.$IDN/"          301 "app.$IDN -> yeni"
bekle "https://panel.$ESKI/"       301 "panel.$ESKI -> yeni"

echo "== YONLENDIRME YOLU KORUYOR MU"
h=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 15 "https://$ESKI/hesap-silme")
[ "$h" = "https://$YENI/hesap-silme" ] && echo "  OK   yol korunuyor" || { echo "  HATA yol kayboldu -> $h"; hata=1; }

echo "== API/STORAGE 301'LENMEMELI (incelemedeki yapim bunlara bagli)"
bekle "https://api.$ESKI/healthz" 200 "api.$ESKI (301 OLMAMALI)"

echo "== SERTIFIKA"
for k in "$YENI" "app.$YENI" "panel.$YENI"; do
  if curl -sI --max-time 15 "https://$k/" >/dev/null 2>&1; then echo "  OK   $k sertifikasi gecerli";
  else echo "  HATA $k TLS dogrulanamadi"; hata=1; fi
done

[ $hata -eq 0 ] && echo "SONUC: HEPSI GECTI" || echo "SONUC: HATA VAR (yukari bak)"
exit $hata
