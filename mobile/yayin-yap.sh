#!/usr/bin/env bash
# (P153) YAYIN YAPIMI — adresler BURADA sabit, elle verilmez.
#
# NEDEN VAR: kapali test paketi "sunucuya baglanirken zaman asimi" verdi.
# Sebep: `flutter build appbundle --release` ELLE kosulmustu ve
# `--dart-define=API_BASE_URL=...` UNUTULMUSTU. Varsayilan
# `http://10.0.2.2:8000` — Android EMULATORUNUN ana makineye giden takma
# adresi; fiziksel telefonda boyle bir adres YOKTUR ve baglanti 15 saniye
# sonra zaman asimina duser. Tam olarak gorulen hata budur.
#
# Varsayilani "guvenli" bir adrese cekmek YETMEZDI: sessizce YANLIS bir
# sunucuya baglanan bir paket, hic baglanmayandan daha kotudur. Cozum
# degeri BURADA sabitlemek ve yapimdan sonra GOMULU DEGERI DOGRULAMAK.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

API_BASE_URL="${API_BASE_URL:-https://api.yonetio.site}"
WEB_BASE_URL="${WEB_BASE_URL:-https://yonetiyor.com}"
BICIM="${1:-appbundle}"   # appbundle | apk

# Emulator/yerel adres YAYIN paketine giremez.
case "$API_BASE_URL" in
  *10.0.2.2*|*localhost*|*127.0.0.1*|*192.168.*|http://*)
    echo "HATA: yayin paketine YEREL/SIFRESIZ adres gomulemez: $API_BASE_URL"
    exit 1;;
esac

echo "== AD_ID on kontrolu"
bash android/ad-id-yok-dogrula.sh >/dev/null || { echo "HATA: AD_ID kontrolu gecmedi"; exit 1; }

echo "== Yapim ($BICIM)"
echo "   API_BASE_URL=$API_BASE_URL"
echo "   WEB_BASE_URL=$WEB_BASE_URL"
flutter build "$BICIM" --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=WEB_BASE_URL="$WEB_BASE_URL"

# GOMULU DEGERI DOGRULA — bu adim olmasaydi hata yine fark edilmezdi.
echo "== Gomulu adres dogrulamasi"
APK=build/app/outputs/flutter-apk/app-release.apk
if [ "$BICIM" = "appbundle" ]; then
  # AAB'nin icindeki .so'lar dogrudan okunamaz; ayni tanimlarla APK uretip
  # onun uzerinden dogrularız (ayni derleme girdileri, ayni gomulu deger).
  flutter build apk --release \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=WEB_BASE_URL="$WEB_BASE_URL" >/dev/null
fi
T=$(mktemp -d); unzip -q -o "$APK" -d "$T"
if grep -aq "$API_BASE_URL" "$T"/lib/arm64-v8a/libapp.so; then
  echo "  OK   pakete gomulu: $API_BASE_URL"
else
  echo "  HATA gomulu adres BEKLENEN DEGIL:"
  grep -a -o -E "https?://[a-zA-Z0-9.:-]+" "$T"/lib/arm64-v8a/libapp.so | sort -u | head -5
  rm -rf "$T"; exit 1
fi
if grep -aq "10.0.2.2" "$T"/lib/arm64-v8a/libapp.so; then
  echo "  HATA emulator adresi HALA gomulu"; rm -rf "$T"; exit 1
fi
echo "  OK   emulator adresi yok"
rm -rf "$T"
echo "SONUC: $BICIM hazir — build/app/outputs/"
