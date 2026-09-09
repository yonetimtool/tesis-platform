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

# (P221) PAKETIN ICINDEKI GERI KALAN SESSIZ KIRILMALAR.
#
# Gomulu adres tek sessiz kirilma DEGILDI. Asagidakilerin her biri, yapim
# BASARILI gorunurken kullaniciya bozuk ulasan bir seyi olcer:
#
#   * IMZA: hata ayiklama anahtariyla imzalanmis bir paketi Play REDDEDER
#     (ya da daha kotusu, kurulur ama guncelleme zinciri kopar).
#   * SESLER: bildirim kanallari `res/raw` altindaki dosyalari ADIYLA
#     ister; dosya yoksa Android SESSIZCE varsayilan sese duser ve
#     "ozel ses calismiyor" diye geri gelir.
#   * IKON: bayat `mipmap` bir kez daha ciktiyi eski ikonla doldurdu.
echo "== Imza dogrulamasi"
# `keytool -printcert` ILE OLMAZ: paket yalniz APK Signature Scheme v2/v3
# ile imzali, `META-INF/*.RSA` (v1 JAR imzasi) HIC YOK. Ilk yazimda
# oradan okumaya calistim; `unzip` bos dondu, `set -o pipefail` betigi
# hicbir sey yazdirmadan dusurdu — sessiz kirilmanin ta kendisi.
APKSIGNER="${APKSIGNER:-$(ls -1 "$HOME"/Android/Sdk/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)}"
if [ -z "$APKSIGNER" ] || [ ! -x "$APKSIGNER" ]; then
  echo "  HATA apksigner bulunamadi — imza DOGRULANAMADI."
  echo "       Android SDK build-tools kurulu olmali (APKSIGNER=... ile verilebilir)."
  rm -rf "$T"; exit 1
fi
BEKLENEN_SHA256="dd1f5964c4a9cc5659669f8905b4751ddc054174e7b15c5e1cb748f6dd0a20f5"
IMZA=$("$APKSIGNER" verify --print-certs "$APK" 2>/dev/null \
       | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -1)
if [ "$IMZA" = "$BEKLENEN_SHA256" ]; then
  echo "  OK   upload anahtariyla imzali"
else
  echo "  HATA imza BEKLENEN DEGIL: ${IMZA:-(imza okunamadi)}"
  echo "       beklenen: $BEKLENEN_SHA256"
  rm -rf "$T"; exit 1
fi

echo "== Bildirim sesleri"
# DOSYA ADINA BAKMAK YANLIS OLURDU: yayin yapiminda kaynak yollari
# kisaltiliyor — `res/raw/yonetio_bildirim.ogg` pakete `res/KX.ogg`
# olarak giriyor. Ilk yazimda ada baktim ve UCU DE "YOK" cikti; ses
# aslinda oradaydi. Dogru olcum KAYNAK ADI: Android kanali sesi
# `resources.arsc`teki ADLA cozer, dosya adiyla degil.
unzip -qo "$APK" resources.arsc -d "$T"
for SES in yonetio_bildirim yonetio_gurultu yonetio_vardiya; do
  if grep -aq "$SES" "$T/resources.arsc"; then
    echo "  OK   $SES"
  else
    echo "  HATA ses PAKETTE YOK: $SES"; rm -rf "$T"; exit 1
  fi
done
# Uc ses dosyasinin kendisi de pakette olmali (arsc adi var ama dosya
# elenmis olabilirdi).
SES_SAYISI=$(unzip -l "$APK" | grep -c "\.ogg$" || true)
if [ "$SES_SAYISI" -lt 3 ]; then
  echo "  HATA pakette $SES_SAYISI ses dosyasi var, 3 bekleniyor"
  rm -rf "$T"; exit 1
fi
echo "  OK   $SES_SAYISI ses dosyasi pakette"

echo "== Ikon"
# NE OLCULUYOR: (a) ikon kaynagi PAKETTEN YENI degil — yani bakilan
# cikti bayat degil (P184'te bir kez bayat mipmap eski ikonu tasidi);
# (b) `ic_launcher` kaynak tablosunda GERCEKTEN var.
#
# NE OLCULMUYOR: PIKSEL ICERIGI. Yayin yapiminda PNG'ler yeniden
# sikistiriliyor, dosya adlari kisaltiliyor; kaynak dosyanin bayt
# ozeti pakettekiyle ASLA tutmaz. Ikonun gorsel olarak dogru oldugu
# GOZLE dogrulanmali — bu betik bunu iddia etmiyor.
KAYNAK_IKON=$(ls -t android/app/src/main/res/mipmap-*/ic_launcher.png 2>/dev/null | head -1)
if [ -n "$KAYNAK_IKON" ] && [ "$KAYNAK_IKON" -nt "$APK" ]; then
  echo "  HATA ikon kaynagi paketten YENI — yapim bayat: $KAYNAK_IKON"
  rm -rf "$T"; exit 1
fi
if grep -aq "ic_launcher" "$T/resources.arsc"; then
  echo "  OK   ic_launcher pakette, yapim bayat degil"
else
  echo "  HATA ic_launcher kaynak tablosunda YOK"; rm -rf "$T"; exit 1
fi

echo "== Surum"
SURUM=$(grep -m1 "^version:" pubspec.yaml | awk '{print $2}')
echo "  pubspec: $SURUM"

rm -rf "$T"
echo "SONUC: $BICIM hazir — build/app/outputs/"
