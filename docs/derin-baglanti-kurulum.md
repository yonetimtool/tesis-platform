# Derin bağlantı + davet kurulumu (P155 §7/§8)

Davet bağlantısı — `https://<portal>/davet/‹jeton›` — üç davranış ister:

1. **Uygulama kuruluysa:** bağlantı doğrudan uygulamada davet ekranını açar
   (Universal Links / App Links).
2. **Kurulu değilse:** kullanıcı cihazına göre mağazaya ya da tarayıcıdaki
   web yedeğine düşer (`/davet/‹jeton›` sayfası).
3. **Her durumda** jeton çözülünce tesis/rol/daire/telefon bellidir;
   kullanıcı yalnız yöntem seçer.

Kodun tamamı hazır ve testlidir. **Bu belge yalnız KONSOL işlerini** (Apple
Developer, Play Console, Google Cloud, Azure) ve iki yer tutucu dosyayı
listeler. Bunlar yapılmadan derin bağlantı **doğrulanmaz** (kod çalışır ama
iOS/Android bağlantıyı uygulamaya yönlendirmez).

> **UYARI (şartname §8):** App Store'daki **build 3** bu yetkilendirmelere
> sahip değil. Derin bağlantı ancak **yeni bir sürümle** çalışır. Bu tur
> test ortamında (`test.yonetio.site`) doğrulanacak.

---

## 0. Sabitler (koda gömülü, DEĞİŞMEZ)

| Alan | Değer |
|---|---|
| iOS bundle id | `site.yonetio.app` |
| Android applicationId | `com.app.yonetiyor` |
| Davet yolu öneki | `/davet/` |
| Alan adları | `test.yonetio.site` (test) · `yonetiyor.com` + `yonetio.site` (prod) |

---

## 1. Sunucudaki iki yer tutucu dosya

`infra/portal/.well-known/` altında iki dosya var; Caddy onları portal alan
adının kökünde `application/json` ile, **yönlendirmesiz** servis ediyor
(`infra/Caddyfile` → `(wellknown)` snippet'i). İçlerindeki yer tutucular:

### 1a. `apple-app-site-association` → `REPLACE_TEAMID`
- **Nereden:** Apple Developer → **Membership** → **Team ID** (10 karakter).
- `appID` = `TEAMID.site.yonetio.app`.

### 1b. `assetlinks.json` → `REPLACE_WITH_PLAY_APP_SIGNING_SHA256_FINGERPRINT`
- **Nereden — adım adım (Play App Signing kullanıyoruz):**
  1. [Play Console](https://play.google.com/console) → uygulamayı seç.
  2. Sol menü → **Test and release → Setup → App integrity**.
  3. **App signing** sekmesi → **App signing key certificate**.
  4. **SHA-256 certificate fingerprint** değerini kopyala (iki nokta ile
     ayrılmış 32 bayt: `AB:CD:...`).
- **DİKKAT:** Bu, Play'in **imzalama** anahtarının parmak izidir, senin
  **yükleme (upload)** anahtarının değil. Karıştırırsan App Links doğrulaması
  sessizce başarısız olur. (Ayrı bir test imzası da varsa parmak izini
  diziye ikinci eleman olarak ekle — dizi çokludur.)

Dosyaları düzenledikten sonra sunucuda Caddy'yi yeniden başlatmaya gerek
yok (salt-okunur mount, dosya değişince yansır); **doğrula:**
```bash
curl -sI https://test.yonetio.site/.well-known/apple-app-site-association | grep -i content-type
# beklenen: application/json  ·  301/302 OLMAMALI
curl -s  https://test.yonetio.site/.well-known/assetlinks.json | jq .
```

---

## 2. Apple Developer + App Store Connect

### 2a. App ID'ye "Associated Domains" yeteneği
1. [developer.apple.com](https://developer.apple.com) → **Certificates,
   Identifiers & Profiles → Identifiers**.
2. `site.yonetio.app` App ID'sini aç.
3. **Capabilities** listesinde **Associated Domains**'i işaretle → **Save**.
   (Bu, mevcut provisioning profillerini geçersiz kılar; Xcode otomatik
   yeniden üretir ya da manuel profili yenile.)

> Kod tarafı hazır: `ios/Runner/Runner.entitlements` içinde
> `com.apple.developer.associated-domains` = `applinks:test.yonetio.site`,
> `applinks:yonetiyor.com`, `applinks:yonetio.site`. Xcode'da **Signing &
> Capabilities**'te "Associated Domains" satırı görünmeli (entitlements
> dosyasından okunur).

### 2b. Doğrulama (yeni build TestFlight'ta)
- iOS bağlantı doğrulamasını **AASA'yı Apple'ın CDN'inden** çeker; dosyayı
  güncelledikten sonra yayılması birkaç saat sürebilir. Test için cihazda
  **ayarlar sıfırlanmadan** önce uygulamayı silip yeniden kur.

---

## 3. Play Console (App Links)

1. Yukarıdaki §1b ile `assetlinks.json`'daki parmak izini doldur.
2. Play Console → **Test and release → App integrity → App Links** —
   yeni build yüklendikten sonra Play, alan adları için doğrulama durumunu
   burada gösterir (yeşil = doğrulandı).
3. `autoVerify="true"` manifest'te hazır (`android/app/src/main/
   AndroidManifest.xml`); sistem `assetlinks.json`'ı otomatik doğrular.

---

## 4. Sosyal yöntem (davet içinden Google / Microsoft / Apple)

Davet ekranındaki sosyal düğmeler mevcut OAuth altyapısını kullanır
(P154'te kuruldu). Yeni konsol işi **yok** — ama sağlayıcılar zaten
yapılandırılmış olmalı (bkz. `docs/oauth-kurulum.md`). Davet yolunun
farkı: **SMS gönderilmez** (jeton + sağlayıcı kimliği yeterli); geri dönüş
adresleri OAuth ile aynıdır.

Sağlayıcı **henüz yapılandırılmamışsa** davet ekranında sosyal düğmeler
**çizilmez**, yalnız "Parola oluştur" kalır — akış tıkanmaz.

---

## 5. SMS + e-posta sağlayıcısı (davet gönderimi)

Davet gönderimi SMS'i **asıl**, e-postayı **ek** kanal yapar. Sağlayıcı
seçimi tek yerdedir (`gonderim.saglayici`) ve **ortam değişkeniyle**
bağlanır — kod değişmez:

- **SMS (Netgsm):** `SMS_SAGLAYICI=netgsm` + `NETGSM_*` değişkenleri
  (bkz. `mesajlasma.NetgsmSmsSaglayici`).
- **E-posta (SMTP):** `EPOSTA_SAGLAYICI` + SMTP değişkenleri.

Bağlanana kadar davetler **"gönderilemedi"** görünür; yönetici panelde
(`/davetler`) durumu görür, **tesis kodunu kopyalayıp** elle iletebilir
(kişi §4 yedek yoluyla kaydolur) ve sağlayıcı gelince **"yeniden gönder"**
ile taze jeton üretip yollar.

---

## 6. Özet — senin yapman gerekenler

| # | Nerede | Ne |
|---|---|---|
| 1 | Apple Developer → Membership | **Team ID**'yi al → `apple-app-site-association`'daki `REPLACE_TEAMID` |
| 2 | Apple Developer → Identifiers → `site.yonetio.app` | **Associated Domains** yeteneğini aç |
| 3 | Play Console → App integrity → App signing | **SHA-256** parmak izini al → `assetlinks.json`'daki yer tutucu |
| 4 | Sunucu | İki well-known dosyasını doldur, `curl` ile içerik tipini + yönlendirmesizliği doğrula |
| 5 | `.env` (test + prod) | `SMS_SAGLAYICI` / SMTP değişkenleri (davet gönderimi için) — kod değişmez |
| 6 | (Opsiyonel) `.env` | `NEXT_PUBLIC_APPLE_APP_ID` = App Store numeric id → web yedeğinde iOS "App Store'dan indir" düğmesi (yoksa gizli) |
| 7 | Yeni mobil build | TestFlight + Play internal — derin bağlantı **ancak yeni sürümle** doğrulanır |
