# Tesis Güvenlik — Mobil (Flutter)

Multi-tenant tesis güvenlik & operasyon SaaS'in saha mobil uygulaması.
Tek doğruluk kaynağı `/contracts/openapi.yaml` + `/contracts/auth.md`'dir.
Backend artık hazır; uygulama **gerçek backend'e** bağlanır (base URL dışarıdan
yapılandırılabilir — mock / yerel / canlı; bkz. §3).

- **Flutter** 3.44.4 · Dart 3.12.x · Android SDK 36 · hedef: Android (kod cross-platform)
- **Mimari:** Clean Architecture (`data` / `domain` / `presentation`)
- **Routing:** `go_router` · **State:** `Riverpod` · **HTTP:** `dio`
- **Güvenli depolama:** `flutter_secure_storage` (Android Keystore destekli)

Bu prompt kapsamı (Faz 0): iskelet + **login** (`tenant_slug` + `email` + `password`
→ access/refresh token) + token'ların güvenli saklanması + **açılışta oturum geri
yükleme** + **401'de otomatik token yenileme (refresh rotation)** + logout.

### 🔐 Örnek test girişi (gerçek backend, seed verisi)

| Alan | Değer |
|------|-------|
| Tesis kodu (`tenant_slug`) | `acme-plaza` |
| E-posta | `admin@acme.com` |
| Parola | `Admin123!` |

> Bu, docker compose ile kalkan yerel backend'in seed kullanıcısıdır; gerçek
> `POST /auth/login` token çifti döndürür.

---

## 1. Gereksinimler

| Araç | Sürüm / Not |
|------|-------------|
| Flutter | 3.44.4 (stable) |
| Android SDK | 36 (build sırasında platform-35 + NDK + CMake otomatik kuruldu) |
| JDK | **17** — Gradle için gereklidir (aşağıya bakın) |
| Node.js veya Docker | Prism mock sunucusunu çalıştırmak için (biri yeterli) |

### JDK notu (önemli)

Bu makinede `java-21` bir JRE'dir (`javac` yok) ve Gradle build'i başarısız eder.
Flutter, tam JDK 17'ye kalıcı olarak yönlendirildi:

```bash
flutter config --jdk-dir=/usr/lib/jvm/java-17-openjdk-amd64
```

Build "Toolchain ... does not provide ... [JAVA_COMPILER]" hatası verirse bu komutu
çalıştırın (tam JDK yolunuzla).

---

## 2. Mock sunucu (Prism) — *opsiyonel*

Birincil hedef artık gerçek backend'dir (§3). Mock yalnızca backend'siz hızlı UI
denemesi için gerekir; gerçek backend ile çalışacaksanız bu adımı atlayabilirsiniz.
Mock, `contracts/openapi.yaml`'den örnek yanıtlar üretir. **Monorepo kökünden** çalıştırın.

### Seçenek A — Node.js / npx (kurulu değilse: `apt install nodejs npm` ya da nvm)

```bash
# Repo kökü: /home/kerem/tesis-platform
npx @stoplight/prism-cli mock contracts/openapi.yaml
# veya global kurulum:
#   npm i -g @stoplight/prism-cli
#   prism mock contracts/openapi.yaml
```

### Seçenek B — Docker (Node istemez)

```bash
docker run --rm -p 4010:4010 -v "$PWD/contracts:/contracts" \
  stoplight/prism:4 mock -h 0.0.0.0 /contracts/openapi.yaml
```

Prism varsayılan olarak **4010** portunda dinler ve **açılışta tüm endpoint'leri
yol-yol listeler**. Çıktıdaki login satırına bakın, base URL'i ona göre ayarlayın:

```
[HTTP SERVER] Prism is listening on http://0.0.0.0:4010
… POST  http://0.0.0.0:4010/auth/login        ← base URL = http://10.0.2.2:4010
```

> ⚠️ `openapi.yaml`'deki `servers` girdileri `/v0` base path içerir
> (`http://localhost:8000/v0`). Prism sürümüne göre endpoint'ler `/auth/login`
> **veya** `/v0/auth/login` altında sunulabilir. **Prism'in başlangıç çıktısındaki
> gerçek yolu** baz alın ve `API_BASE_URL`'i ona göre verin (bkz. §3). Uygulama
> kodundaki istek yolları `/auth/login` şeklindedir; base URL'e `/v0` ekleyip
> eklemeyeceğinizi mock çıktısı belirler.

### Mock'u hızlı doğrulama

```bash
curl -s -X POST http://localhost:4010/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"tenant_slug":"acme-plaza","email":"a@acme.com","password":"password1"}'
# → { "access_token": "...", "refresh_token": "...", "token_type": "Bearer", "expires_in": 900 }
```

---

## 3. Base URL yapılandırması (mock / yerel / canlı)

Base URL **derleme zamanı** `--dart-define=API_BASE_URL=...` ile verilir
(`lib/src/core/config/app_config.dart`). Kod değişmez; aynı APK farklı ortamlara
yönlendirilebilir. **Sondaki `/` olmadan** yazın.

**Varsayılan:** `http://10.0.2.2:8000` — Android emülatöründen yerel (docker
compose) backend'e erişim.

| Senaryo | Emülatör | Gerçek cihaz (aynı Wi-Fi) |
|---------|----------|----------------------------|
| **Yerel backend** (docker compose) — *varsayılan/birincil* | `http://10.0.2.2:8000` | `http://<PC-LAN-IP>:8000` |
| Mock (Prism, §2) | `http://10.0.2.2:4010` | `http://<PC-LAN-IP>:4010` |
| Canlı / uzak sunucu | `http://<sunucu_ip>:8000` veya `https://api.example.com` | (aynı) |

```bash
# Yerel backend, emülatör (varsayılan — define'sız da çalışır):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Yerel backend, fiziksel telefon (PC'nin LAN IP'si — ip addr / ifconfig):
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000

# Mock'a karşı:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4010

# Canlı/uzak sunucu:
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

### 🔑 `10.0.2.2` vs LAN IP — emülatör/cihazdan host'a erişim (önemli)

- **Android emülatörü** ana makineyi (host'taki `localhost`) **`10.0.2.2`**
  üzerinden görür. `127.0.0.1`/`localhost` emülatörün **kendisini** işaret eder,
  host'taki backend'e ulaşmaz. Bu yüzden emülatör varsayılanı `10.0.2.2`'dir.
- **Gerçek (fiziksel) cihaz** host'u `10.0.2.2` ile göremez; telefon ile backend'i
  çalıştıran bilgisayar **aynı Wi-Fi/LAN'da** olmalı ve bilgisayarın **LAN IP**'si
  kullanılmalıdır (`ip addr` / `ifconfig` → ör. `192.168.x.y`). Docker compose
  portu host'ta `8000:8000` map'lendiği için LAN'dan erişilebilir; gerekirse
  bilgisayarın güvenlik duvarında 8000 portuna izin verin.
- **Mock** (Prism) fiziksel cihazdan erişilecekse `0.0.0.0`'a bind edin (Docker
  örneği `-h 0.0.0.0`).
- HTTP (cleartext) erişimi yalnızca **debug** build'de açıktır
  (`android/app/src/debug/AndroidManifest.xml` → `usesCleartextTraffic="true"`).
  Release build cleartext'e izin vermez (prod HTTPS bekler).

> ⚠️ **`/v0` yok.** `openapi.yaml`'deki `servers` `/v0` base path içerse de
> gerçek backend router'ları kök altında (`/auth/login`) sunulur — base URL'e
> `/v0` **eklemeyin**. Uygulamadaki istek yolları `/auth/login`, `/auth/refresh`
> şeklindedir. (Sözleşme tutarsızlığı — bkz. §7.)

### Token yenileme (refresh) akışı

`auth.md §3` rotation akışına uygun olarak `lib/src/core/network/auth_interceptor.dart`
şunu yapar:

1. Login/refresh dışındaki her isteğe `Authorization: Bearer <access>` eklenir.
2. Bir istek **401** dönerse `POST /auth/refresh` ile yeni `access + refresh` çifti
   alınır (eski refresh iptal — rotation), token'lar secure storage'a yazılır ve
   orijinal istek yeni access ile **bir kez** yeniden denenir.
3. Refresh de geçersizse (401/yok): token'lar silinir, auth state
   `unauthenticated` olur → uygulama **login'e döner**.
4. Eşzamanlı 401'lerde tek bir refresh çalışır (single-flight); bekleyenler aynı
   sonucu paylaşır. Login/refresh public olduğu için bu endpoint'lerde refresh
   denenmez (sonsuz döngü engellenir).

---

## 4. Çalıştırma

```bash
cd mobile
flutter pub get

# Emülatörde yerel backend'e karşı çalıştır (varsayılan base URL 10.0.2.2:8000):
flutter run

# Base URL'i açıkça vererek (fiziksel cihaz / mock / canlı — bkz. §3):
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

Akış: login ekranı (örnek giriş: `acme-plaza` / `admin@acme.com` / `Admin123!`) →
`POST /auth/login` → dönen access+refresh çifti secure storage'a yazılır → ana
ekrana geçilir. Sonraki korunan isteklerde access token otomatik eklenir; 401'de
arka planda refresh denenir (§3). Uygulamayı yeniden başlattığınızda saklı oturum
varsa **login atlanır**, doğrudan ana ekran açılır (çıkış için ana ekrandaki
logout ikonu token'ları siler ve login'e döner).

---

## 5. Test & doğrulama (kabul kriterleri)

```bash
flutter analyze                 # → No issues found!
flutter test                    # → birim testleri geçer (TokenPair / ApiException / AuthInterceptor)
flutter build apk --debug       # → build/app/outputs/flutter-apk/app-debug.apk
```

Son durum: `flutter analyze` temiz, `flutter test` **11/11** geçer (refresh akışı
dahil — `test/auth_interceptor_test.dart`: 401→refresh→retry, refresh ölünce
logout, public endpoint'lerde refresh denenmemesi), debug APK üretilir.

---

## 6. Klasör yapısı

```
mobile/
├─ android/                  # debug manifest: INTERNET + cleartext (mock için)
├─ ios/                      # iOS hedefi (sonra Mac'te derlenecek)
├─ lib/
│  ├─ main.dart             # ProviderScope + MaterialApp.router
│  └─ src/
│     ├─ core/
│     │  ├─ config/app_config.dart        # API_BASE_URL (--dart-define)
│     │  ├─ error/api_exception.dart      # { error: { code, message } } parse + ApiErrorKind
│     │  └─ network/
│     │     ├─ dio_provider.dart          # paylaşılan Dio + ham Dio + interceptor
│     │     └─ auth_interceptor.dart      # access header + 401→refresh rotation
│     ├─ features/
│     │  ├─ auth/
│     │  │  ├─ data/
│     │  │  │  ├─ auth_api.dart            # POST /auth/login, /auth/refresh
│     │  │  │  ├─ auth_repository_impl.dart
│     │  │  │  └─ token_storage.dart       # flutter_secure_storage
│     │  │  ├─ domain/
│     │  │  │  ├─ auth_repository.dart
│     │  │  │  └─ token_pair.dart          # TokenPair şeması
│     │  │  └─ presentation/
│     │  │     ├─ auth_controller.dart     # Riverpod Notifier (auth state)
│     │  │     └─ login_screen.dart        # tenant_slug + email + parola
│     │  ├─ home/presentation/home_screen.dart   # ana ekran + NFC kartı
│     │  ├─ nfc/
│     │  │  ├─ data/nfc_service.dart        # nfc_manager 4.x oturum + UID/SDM okuma
│     │  │  ├─ domain/nfc_read_result.dart  # NfcReadResult / NfcTagType / NfcSdmData
│     │  │  └─ presentation/
│     │  │     ├─ nfc_controller.dart       # Riverpod Notifier (hazir/okuyor/sonuc/hata)
│     │  │     └─ nfc_screen.dart           # okuma + "Okutmayı gönder" akışı
│     │  └─ scan/
│     │     ├─ data/scan_api.dart           # POST /scans (Idempotency-Key)
│     │     ├─ domain/scan.dart             # ScanDraft / ScanEvent / ScanSubmitResult
│     │     └─ presentation/scan_controller.dart  # gönderim durumu (created/duplicate/404/error)
│     └─ routing/
│        ├─ app_router.dart                # go_router + auth redirect
│        └─ splash_screen.dart             # oturum geri yüklenirken
└─ test/
   ├─ token_pair_test.dart
   └─ api_exception_test.dart
```

---

## 7. NFC etiket okuma (Faz 1)

Devriye noktalarındaki NFC etiketlerini okuyup UID'i (ve varsa NTAG424 SDM
verisini) çıkaran ekran. Paket: `nfc_manager: ^4.2.1` (+ `ndef_record`,
NDEF tiplerini doğrudan kullandığımız için doğrudan bağımlılık olarak eklendi).

> **nfc_manager 4.x notu:** 3.x'ten tamamen farklı bir API. UID artık platforma
> özel sınıflardan okunuyor: Android'de `NfcTagAndroid.from(tag).id`, iOS'ta
> `MiFareIos.from(tag).identifier`. Müsaitlik için `isAvailable()` deprecate
> oldu; `checkAvailability()` → `NfcAvailability { enabled, disabled, unsupported }`
> kullanılıyor.

### UID format kararı (sözleşme)

UID **BÜYÜK HARF, İKİ NOKTA (`:`) AYRAÇLI hex** olarak üretilir — örn.
`04:A3:B2:C1:90:00`. Tek noktadan: `bytesToHex(Uint8List)` (`nfc_service.dart`).

> **Karar değişikliği (Faz1/Prompt1 → şimdi):** İlk turda "ayraçsız"
> (`04A3B2C190`) seçilmişti; ancak `contracts/openapi.yaml`'da `nfc_tag_uid`
> örnekleri **iki nokta ayraçlı** (`04:A3:B2:C1:90:00` — Checkpoint, ScanCreate).
> Backend UID'i **tam string** eşleştirdiğinden, ayraçsız gönderim hiçbir
> checkpoint ile eşleşmez (404). Bu yüzden mobil **sözleşmeye hizalandı**.
> **Backend'e bu string gönderilir.**

### Tag tipi tespiti (heuristik — kesin değil)

`NfcTagType { ntag2xx, ntag424, unknown }`:

- **Android** — teknoloji listesinden: `IsoDep` varsa `ntag424` (NTAG424 DNA
  ISO 14443-4 sunar), yoksa `MifareUltralight` varsa `ntag2xx` (NTAG213/215/216),
  aksi halde `unknown`.
- **iOS** — `MiFareFamilyIos`: `ultralight → ntag2xx`, `desfire → ntag424`
  (NTAG424 iOS'ta DESFire ailesi görünür), diğer → `unknown`.

> Kesin tip için kart üstünde `GET_VERSION` komutu gerekir; bu tahmin yalnızca
> UI/yönlendirme içindir. Kesin doğrulama **backend** tarafında yapılmalı.

### NTAG424 SDM/SUN bulguları (ne okunabiliyor, backend'e ne gidmeli)

NTAG424, NDEF içindeki bir URL'e dinamik olarak şifreli alanlar gömer
(PICCData + CMAC — "SUN"/"SDM"). Mobil tarafta yapılan:

- **Okunabilen:** NDEF mesajındaki ilk URI kaydı (well-known `U` veya
  absolute-URI; `U` kaydında ön-ek byte'ı çözülür). URL'in sorgu parametreleri
  ayrıştırılıp `NfcSdmData`'ya konur: `piccData` (`picc_data`/`e`),
  `cmac` (`cmac`/`c`), `encData` (`enc`/`d`) + tüm ham `params`.
- **Yapılmayan (bilerek):** **kripto yok.** PICCData çözümü, CMAC doğrulama,
  replay/sayaç kontrolü mobilde **yapılmaz** — anahtar mobile konmaz.
- **Backend'e gönderilecek:** okunan **ham URL** + ayrıştırılmış alanlar
  (`piccData`, `cmac`). Doğrulama (anahtarla CMAC kontrolü, UID/sayaç çözümü)
  **backend'in** işi. Etiket NTAG424 değilse `sdmData` null olur.

Şu an `parseSdm(...)` bir **iskelet**: cached NDEF mesajını parse eder, alan
adlarını en yaygın SDM kalıplarına göre tarar. Etiketin gerçek SDM ayarı
(alan adları, mirror konumu) netleştiğinde bu eşleştirme güncellenmeli.

### Hata davranışı

Servis **hiçbir koşulda exception fırlatıp uygulamayı çökertmez**; her zaman
tiplenmiş sonuç döner:

- NFC yok → "Bu cihaz NFC desteklemiyor."
- NFC kapalı → "NFC kapalı. Lütfen ayarlardan açın."
- Okuma hatası / iptal → `NfcReadResult.failure(...)` → ekranda hata kutusu.

### Okutmayı gönderme — `POST /scans` (Faz1 devam)

Etiket okunduktan sonra ekranda **"Okutmayı gönder"** butonu çıkar; okutma
`POST /scans` ile backend'e gönderilir (`features/scan/`).

- **Gövde (`ScanDraft` → ScanCreate):** `nfc_tag_uid` (sözleşme formatı),
  `okutma_zamani` (okuma anında sabitlenen UTC — `NfcReadResult.readAt`; offline
  gecikmeli gönderime uygun). GPS/checkpoint_id opsiyonel.
- **Idempotency-Key (ZORUNLU):** `"<uid>|<okutma_zamani ISO>"` — okuma anına
  sabitlendiğinden aynı okutma tekrar gönderilirse backend **aynı kaydı** döner
  (yeni kayıt oluşmaz). Ekstra paket gerektirmez (uuid'e gerek yok).
- **Sonuç eşlemesi (ekranda):**
  - `201` → "Okutma kaydedildi." (created)
  - `200` → "Bu okutma zaten kayıtlıydı." (idempotent tekrar)
  - `404` → "Bu etiket hiçbir checkpoint ile eşleşmiyor." (notMatched)
  - ağ/sunucu hatası → mesaj + "Tekrar gönder"

> **Tasarım kararı — ön `GET /checkpoints` yapılmadı:** ScanCreate'e göre
> backend `nfc_tag_uid`'i checkpoint'e kendisi çözüyor ve eşleşme yoksa 404
> dönüyor. Ayrı bir ön-arama (checkpoint adını göstermek için) eklenmedi; bu
> hem fazladan bir online bağımlılık hem de ikinci bir hata noktası olurdu.
> Checkpoint **adını** göstermek istenirse ileride `GET /checkpoints?nfc_tag_uid`
> ile zenginleştirilebilir (ScanEvent yalnızca `checkpoint_id` döndürüyor).
>
> **Offline kuyruk** bu turda yok (senkron gönderim). Idempotency-Key stratejisi
> kuyruk eklendiğinde çift gönderimi zaten güvenli kılacak şekilde seçildi.

### Android yapılandırması

`AndroidManifest.xml` (eklendi):

```xml
<uses-permission android:name="android.permission.NFC"/>
<uses-feature android:name="android.hardware.nfc" android:required="false"/>
```

`required="false"` → NFC'siz cihazlar da uygulamayı kurabilir (okuma denemesi
"desteklenmiyor" döner). **minSdk:** `flutter.minSdkVersion` kullanılıyor;
Flutter 3.44 varsayılanı zaten ≥ 21 olduğundan (NFC için 19+ yeterli)
`build.gradle.kts`'de değişiklik gerekmedi — `flutter_secure_storage` ile de
uyumlu kalır.

### iOS yapılandırması

`ios/Runner/Info.plist`'e `NFCReaderUsageDescription` eklendi (kullanıcıya
gösterilen NFC izin metni).

> **Core NFC entitlement (Mac'te yapılacak):** iOS'ta gerçek okuma için Xcode'da
> Runner hedefine **Near Field Communication Tag Reading** capability'si eklenmeli
> (Apple Developer hesabı + `Runner.entitlements` içinde
> `com.apple.developer.nfc.readersession.formats`). Bu adım entitlement/imzalama
> gerektirdiğinden Linux'ta yapılamaz; iOS build'inden önce eklenmeli.

### Çalıştırma / doğrulama

```bash
cd mobile
flutter pub get
flutter analyze lib/            # temiz olmalı
flutter build apk --debug       # kabul kriteri: BAŞARILI

# cihazda dene (NFC'li gerçek telefon gerekir; emülatörde NFC yok):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Giriş → Ana ekran → "NFC etiket okuma" kartı → "Okumayı başlat" → etiketi yaklaştır
# → UID/tip görünür → "Okutmayı gönder" → POST /scans sonucu (kaydedildi / zaten kayıtlı / 404)
```

---

## 8. Sözleşme notları (DEV-A'ya)

`/contracts/openapi.yaml`'i incelerken görülen küçük tutarsızlıklar (login akışını
engellemez, bilgi amaçlı):

- **`servers` `/v0` ↔ gerçek backend uyuşmazlığı (önemli):** `openapi.yaml`
  `servers` girdileri `/v0` base path içeriyor (`http://localhost:8000/v0`), ancak
  gerçek backend router'ları **kök altında** sunuyor (`backend/app/main.py` →
  `include_router` global prefix yok; `/auth/login` doğrudan). Yani gerçek
  backend'de doğru base URL `http://host:8000` (`/v0` **olmadan**). Mobil tarafta
  varsayılan buna göre `http://10.0.2.2:8000` yapıldı. Sözleşme ile backend'i
  hizalamak için ya `servers`'tan `/v0` kaldırılmalı ya da backend `/v0` prefix'i
  ile mount edilmeli (DEV-A kararı).
- `/notifications` ve `/notifications/{id}` operasyonları `tags: [notifications]`
  kullanıyor ama bu tag, dosyanın üstündeki global `tags` listesinde tanımlı değil
  (yalnızca auth, shifts, checkpoints, patrol-plans, scans, dashboard var).
