#!/usr/bin/env bash
# (P152) REKLAM KIMLIGI YOK — Play beyaniyla derlenmis ciktinin ORTUSMESI.
#
# NEDEN VAR: Play formunda "reklam kimligi kullanilmiyor" diyoruz. Play,
# birlestirilmis manifest'te `com.google.android.gms.permission.AD_ID`
# bulursa surumu ENGELLER. Bu izin BIZIM manifest'imizde degil, BAGIMLI
# SDK'lardan (play-services-ads-identifier, play-services-measurement,
# firebase-analytics) OTOMATIK birlesir — yani bir bagimlilik yukseltmesi
# beyani sessizce gecersiz kilabilir.
#
# YUKLEMEDEN ONCE kosulmalidir: yukleme aninda takilmak zaman kaybi.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
hata=0

echo "== 1) Bagimlilik agaci (release) — AD_ID getiren bilesenler"
dep=$(timeout 700 ./gradlew :app:dependencies --configuration releaseRuntimeClasspath 2>&1)
if [ "$(printf %s "$dep" | wc -l)" -lt 50 ]; then
  echo "  HATA gradle taramasi kosmadi — bos cikti 'yok' DEMEK DEGIL"; exit 2
fi
suclu=$(printf %s "$dep" | grep -oE "(ads-identifier|play-services-measurement[a-z-]*|firebase-analytics)" | sort -u)
if [ -n "$suclu" ]; then
  echo "  ! AD_ID getirebilecek bilesen(ler):"; printf %s "$suclu" | sed 's/^/    /'; hata=1
else
  echo "  OK   ads-identifier / measurement / analytics YOK"
fi

echo "== 2) Birlestirilmis manifest"
m=$(find ../build/app/intermediates -name AndroidManifest.xml -path "*merged*" 2>/dev/null | head -1)
if [ -z "$m" ]; then
  echo "  ATLANDI birlestirilmis manifest yok — once `flutter build` kos"
elif grep -q "AD_ID" "$m"; then
  echo "  ! AD_ID birlestirilmis manifest'te VAR: $m"; hata=1
else
  echo "  OK   AD_ID birlestirilmis manifest'te YOK"
fi

if [ $hata -ne 0 ]; then
  cat <<'NOT'

  YAPILACAK: AndroidManifest.xml'e ekle ve TEKRAR dogrula —
    <uses-permission android:name="com.google.android.gms.permission.AD_ID"
                     tools:node="remove" />
  (kok <manifest> etiketinde xmlns:tools bildirimi gerekir)
NOT
  exit 1
fi
echo "SONUC: reklam kimligi beyani DERLENMIS CIKTIYLA ORTUSUYOR."
