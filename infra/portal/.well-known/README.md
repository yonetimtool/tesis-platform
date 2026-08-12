# `.well-known/` — derin bağlantı doğrulama dosyaları (P155 §8)

Bu iki dosya, davet bağlantısının (`https://<portal>/davet/‹jeton›`)
uygulamada **kullanıcı hiçbir şey aramadan** açılmasını sağlar. Caddy
onları portal alan adının **kökünde**, `application/json` içerik tipiyle ve
**yönlendirmesiz** servis eder (bkz. `infra/Caddyfile` — `(wellknown)`
snippet'i ve portal bloğundaki `handle @wellknown`).

## DOLDURULACAK YER TUTUCULAR (konsol işi)

### `apple-app-site-association` → `REPLACE_TEAMID`
- **Nereden:** Apple Developer → Membership → **Team ID** (10 karakter, örn.
  `A1B2C3D4E5`).
- `appID` biçimi `TEAMID.BUNDLE_ID`; bundle id **`site.yonetio.app`** (sabit,
  `ios/Runner.xcodeproj`ten okundu).
- Sonuç örn.: `"appID": "A1B2C3D4E5.site.yonetio.app"`.
- Dosyanın **uzantısı yok** ve olmamalı; Caddy içerik tipini elle veriyor.

### `assetlinks.json` → `REPLACE_WITH_PLAY_APP_SIGNING_SHA256_FINGERPRINT`
- **Nereden:** Play Console → uygulama → **Test and release → App integrity
  → App signing** → *App signing key certificate* → **SHA-256 certificate
  fingerprint** (iki nokta ile ayrılmış 32 bayt).
- **Play App Signing kullanıyoruz**, yani parmak izi Play'in imzalama
  anahtarınındır (upload anahtarınınki DEĞİL). İkisini karıştırmak App
  Links doğrulamasını sessizce başarısız kılar.
- `package_name` **`com.app.yonetiyor`** (sabit, `android/app/build.gradle.kts`).

## TEST vs PROD — hangi alan adı?

Caddy bu dosyaları **portal bloğunun tüm konaklarında** servis eder
(`PORTAL_DOMAIN` + eski + IDN). Yani:
- **Test:** `.env.test`'te `PORTAL_DOMAIN=test.yonetio.site` → dosyalar
  `https://test.yonetio.site/.well-known/...` adresinde.
- **Prod:** `PORTAL_DOMAIN=yonetiyor.com` (+ eski `yonetio.site`) → aynı
  dosyalar orada.

Uygulama **her iki** alan adını da Associated Domains / intent-filter
host'una yazmalı (test'te doğrulamak, prod'da çalışmak için). Ayrıntı:
`docs/derin-baglanti-kurulum.md`.

> Aynı iki dosya hem test hem prod için kullanılır çünkü **appID/package
> aynıdır**; yalnız alan adı değişir ve o Caddy env değişkeninden gelir.
> Parmak izi farklıysa (ayrı test imzası) `sha256_cert_fingerprints`
> dizisine ikinci parmak izini eklemeniz yeterli — dizi çoklu değeri kabul
> eder.
