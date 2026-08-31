# App Privacy anketi — cevap tablosu (P115)

> App Store Connect → App Privacy bölümüne **bu tablo** girilir. Tablo,
> `mobile/ios/Runner/PrivacyInfo.xcprivacy` ile **birebir aynı** olmak
> zorundadır: bildirimde "toplanıyor" deyip ankette "toplanmıyor" demek
> (ya da tersi) denetimde tutarsızlık olarak okunur ve ret sebebidir.
> Değişiklik yaparken **ikisini birlikte** güncelleyin; `mobile/test/
> ios_yapilandirma_test.dart` bildirimin bozulmasını yakalar.

## Genel cevaplar

| Soru | Cevap | Neden |
|---|---|---|
| Veri topluyor musunuz? | **Evet** | Hesap tabanlı bir yönetim uygulaması; ad/telefon olmadan çalışamaz. |
| Kullanıcıyı **izliyor** musunuz? (Tracking) | **HAYIR** | Reklam kimliği (IDFA) okunmuyor, cihazlar arası eşleştirme yok, veri veri simsarlarına satılmıyor. `NSPrivacyTracking = false`. |
| Üçüncü taraf reklam/analitik SDK'sı | **YOK** | Uygulamada reklam SDK'sı, analitik SDK'sı ve çerez tabanlı izleme bulunmuyor. |

## Toplanan veri tipleri

Tümü **kullanıcıya bağlı** (hesapla ilişkili) ve tümünün amacı
**App Functionality**. Hiçbiri izleme (tracking) için kullanılmıyor.

| App Store veri tipi | Kategori | Toplanıyor | Bağlı | İzleme | Nerede kullanılıyor (kod) |
|---|---|---|---|---|---|
| Name | Contact Info | Evet | Evet | Hayır | `app_user.ad`; talep/duyuru yazarı olarak görünür. |
| Email Address | Contact Info | Evet | Evet | Hayır | **Artık zorunlu** (P185/P186): kayıt, davet ve tek-kullanımlık kod kanalı. |
| Phone Number | Contact Info | Evet | Evet | Hayır | **Opsiyonel** (P187): verilirse giriş/SMS kanalı. |
| Photos or Videos | User Content | Evet | Evet | Hayır | Yalnız kullanıcı seçtiğinde: profil fotoğrafı, görev kanıtı, talep/şikâyet, kargo, duyuru görseli (`image_picker`). |
| Customer Support | User Content | Evet | Evet | Hayır | Uygulama içi destek talebi: konu + açıklama (+ opsiyonel foto) — `support_api.dart`. |
| Other User Content | User Content | Evet | Evet | Hayır | Talep/şikâyet metinleri, duyurular, karar defteri. |
| Precise Location | Location | Evet | Evet | Hayır | **Yalnız okutma anında** (`LocationAccuracy.high`, `konum_servisi.dart`) — devriye/görev okutması ve acil bildirim. Arka planda **toplanmaz**; sürekli takip yok. |
| User ID | Identifiers | Evet | Evet | Hayır | Tesis içi hesap kimliği (`app_user.id`). |
| **Device ID** | Identifiers | **Evet** | Evet | Hayır | **(P193 — YENİ)** FCM kayıt jetonu + uygulamanın ürettiği **kurulum kimliği** (`user_device.fcm_token`, `user_device.cihaz_kimligi`). Push açıldığı için artık toplanıyor. |
| Other Financial Info | Financial Info | Evet | Evet | Hayır | Aidat bakiyesi ve tahsilat kaydı. **Payment Info DEĞİL** — kart/banka hesabı bilgisi toplanmıyor; "Öde" ekranında gösterilen IBAN **tesisin** kasasıdır. |

## Toplanmayanlar (açıkça)

| Veri tipi | Durum |
|---|---|
| Contacts (rehber) | **Hayır** — rehbere erişilmiyor. |
| Health & Fitness | Hayır |
| Financial Info (kart/banka) | **Hayır** — kartla ödeme etkin değil; etkinleşince veri doğrudan iyzico'ya gider ve bizde tutulmaz. |
| Browsing History / Search History | Hayır |
| Identifiers → Advertising Data (IDFA) | **Hayır** |
| Diagnostics / Crash Data | **Hayır** — çökme/performans SDK'sı yok (Crashlytics, Sentry vb. bağımlılıklarda YOK). |
| Usage Data (Product Interaction, Advertising Data) | **Hayır** — analitik SDK yok. |
| Coarse Location | **Hayır** — yalnız `LocationAccuracy.high` kullanılıyor, arka plan konumu yok. |
| Payment Info (kart/banka hesabı) | **Hayır** — bkz. üstteki "Other Financial Info" satırı. |
| Banka ekstresi / IBAN eşleştirme (P191 §4) | **Hayır** — bu özellik **yalnız web panelinde**; iOS uygulaması ekstre yüklemez, banka verisi göndermez. |
| Sensitive Info | Hayır |

## Gerekçe zorunlu API'ler (Required Reason APIs)

`PrivacyInfo.xcprivacy` içindeki beyanla aynıdır.

| Kategori | Gerekçe | Nereden geliyor |
|---|---|---|
| UserDefaults | `CA92.1` | `flutter_secure_storage` / `shared_preferences` — yalnız uygulamanın kendi verisi. |
| File Timestamp | `C617.1` | `path_provider` / `image_picker` — kullanıcıya görünür dosya işlemleri. |
| Disk Space | `E174.1` | Fotoğraf yazarken yer kontrolü. |
| System Boot Time | `35F9.1` | Çevrimdışı kuyrukta geçen süreyi ölçmek. |

## Bildirim ve ödeme — bugünkü durum

* **Push bildirim (Firebase/FCM): AÇIK** (P191). Prod'da `PUSH_PROVIDER=fcm`.
  Cihaz jetonu Google'a gider ve sunucuda hesaba bağlı saklanır → tabloya
  **Identifiers → Device ID** satırı eklendi. Belgenin eski sürümü bu adımı
  zaten öngörüyordu; bu tur uygulandı.
* **Kartla ödeme (iyzico):** hâlâ **etkin değil** (`PAYMENT_PROVIDER=manual`).
  Açıldığında kart verisi **bize gelmez** (sağlayıcıya gider), ama
  "Financial Info" satırı yine gözden geçirilmelidir.

## Firebase / SPM bağımlılıkları — analitik var mı? (P193)

Xcode'un SPM listesinde `GoogleAppMeasurement` ve
`google-ads-on-device-conversion` **görünür**; bu, veri toplandığı anlamına
**gelmez**. Kanıt:

| Kontrol | Bulgu |
|---|---|
| `pubspec.yaml` | Yalnız `firebase_core` + `firebase_messaging`. `firebase_analytics` **YOK**. |
| `firebase_messaging` iOS SPM hedefi | Yalnız `.product(name: "FirebaseMessaging", package: "firebase-ios-sdk")` ve `firebase-core` bağlanıyor — **Analytics ürünü bağlanmıyor** (`~/.pub-cache/.../firebase_messaging/ios/firebase_messaging/Package.swift`). |
| CocoaPods podspec | `s.dependency 'Firebase/Messaging'` — Analytics yok. |
| `GoogleService-Info.plist` | `IS_ANALYTICS_ENABLED = false`, `IS_ADS_ENABLED = false`. |

**Neden listede görünüyorlar:** SPM, `firebase-ios-sdk` paketinin **bildirdiği
tüm bağımlılıkları çözer** (indirir); `GoogleAppMeasurement`,
`FirebaseAnalytics` ürününün bağımlılığıdır. Çözülmek ile **bağlanmak** ayrı
şeylerdir — uygulama ikilisine yalnız referans verilen ürünler girer.

**Mac'te tek komutla teyit** (arşiv/derleme sonrası):

```bash
otool -L "<...>/Runner.app/Runner" | grep -i -E "measurement|analytics|conversion"
# Çıktı BOŞSA analitik ikilisi bağlanmamıştır.
```

Kilit: `mobile/test/ios_yapilandirma_test.dart` — analitik/çökme/reklam
paketlerinden biri `pubspec.yaml`'a eklenirse test düşer ve bu beyanın
gözden geçirilmesi gerektiğini söyler.

İki özellik de açılınca **bu tablo, `PrivacyInfo.xcprivacy` ve
`/gizlilik` sayfası birlikte** güncellenir.
