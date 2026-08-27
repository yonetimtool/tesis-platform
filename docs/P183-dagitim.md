# P183 — Dağıtım notları (mobil)

P183 **yalnız mobil (Flutter)**. **Backend DEĞİŞMEDİ** — göç YOK, yeni uç YOK,
yeni env YOK. Kullanılan uçların hepsi zaten prod'da: `POST/DELETE /devices`,
`GET/PATCH /me/bildirim-tercihleri` (göç 0055). FCM gönderim tarafı P181'de
dağıtıldı.

## Ne değişti (mobil)

- **Yeni:** bildirim tercihleri ekranı (Ayarlar → Bildirimler) — 3 kanal
  toggle'ı (`bildirim_eposta/sms/mobil`), kısmi PATCH.
- **Yeni:** cihaz bildirim izni durumu görünürlüğü + ret UX (Ayarlar kartında).
- **Değişti:** push izin isteği artık durum döndürür ve state'e yazılır.
- **Sertleştirme:** derin bağlantı yönlendirmesi çökmesiz (ana ekrana düşer).
- **i18n:** 11 yeni anahtar × 7 dil + `lib/l10n/gen/` yeniden üretildi.

## Kullanıcının yapacağı (APK üretimi + cihaz testi)

1. **APK üret (KRİTİK — elle `flutter build` DEĞİL):**
   ```
   bash mobile/yayin-yap.sh apk        # ya da appbundle
   ```
   Elle `flutter build apk` `--dart-define=API_BASE_URL=https://api.yonetio.site`'ı
   atlar → APK emülatör adresine (`10.2.2:8000`) gider ve prod'a ULAŞAMAZ. Script
   doğru adresi geçer + release `google-services.json` gerektirir.

2. **google-services.json:** release derlemesi bunsuz KASITLI başarısız olur
   (`android/app/build.gradle.kts`). Prod paket kimliği (`com.app.yonetiyor`
   Android) ile eşleşen dosya `android/app/`de olmalı; `.gitignore`'da olduğu
   için repoda gelmez.

3. **Cihazda doğrula (kod tarafında test EDİLEMEYEN — bkz. P183-kararlar.md son
   bölüm):** kapalıyken teslim (1), dokunma→ekran + soğuk başlatma (2), iOS izin
   istemi + ret (3), jeton yenileme→backend (4), çıkış→jeton pasif (5), mobil
   toggle kapatınca push gelmemesi ama uygulama içi listenin etkilenmemesi (6).

4. **iOS:** `CFBundleURLTypes` P181'de eklendi; yeni iOS build gerekir. APNs
   yetkilendirme anahtarı + FCM eşleşmesi prod Firebase projesinde tanımlı olmalı
   (bildirim iOS'a düşsün).

## Dev makinesinde doğrulanan (bu oturum)

- `flutter analyze` → **No issues found**.
- `flutter test` → tüm paket yeşil (yeni: `bildirim_tercih_test`, `push_registrar`
  izin testleri; ratchet `sozluk_denetimi` 7-dil yeşil).
- `flutter build apk --debug` → başarılı (yerel `google-services.json` ile).

Bağımlılık/native değişiklik YOK (`permission_handler` gibi yeni eklenti
eklenmedi — bkz. kararlar §2). Geri alma = önceki `admin-web` değil, önceki APK.
