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
│     │  ├─ home/presentation/home_screen.dart   # ana ekran: Turlarım + NFC + kuyruk kartları
│     │  ├─ nfc/
│     │  │  ├─ data/nfc_service.dart        # nfc_manager 4.x oturum + UID/SDM okuma
│     │  │  ├─ domain/nfc_read_result.dart  # NfcReadResult / NfcTagType / NfcSdmData
│     │  │  └─ presentation/
│     │  │     ├─ nfc_controller.dart       # Riverpod Notifier (hazir/okuyor/sonuc/hata)
│     │  │     └─ nfc_screen.dart           # okuma + "Okutmayı gönder" akışı
│     │  ├─ patrol/                          # Faz 2: tur akışı ekranları (§9)
│     │  │  ├─ data/patrol_api.dart           # dashboard/live + plan checkpoints + patrol-windows
│     │  │  ├─ domain/patrol_models.dart      # PatrolWindow/CheckpointStatus + yerel birleşim
│     │  │  └─ presentation/
│     │  │     ├─ patrol_controller.dart      # aktif tur state (otomatik yenileme + outbox dinleme)
│     │  │     ├─ patrol_history_controller.dart
│     │  │     └─ patrol_screen.dart          # "Turlarım": Aktif + Geçmiş sekmeleri
│     │  └─ scan/
│     │     ├─ data/
│     │     │  ├─ scan_api.dart             # POST /scans (Idempotency-Key)
│     │     │  ├─ scan_outbox.dart          # offline kuyruk motoru + tetikleyiciler (§8)
│     │     │  └─ scan_outbox_store.dart    # kalıcı JSON depo (atomik yazım)
│     │     ├─ domain/
│     │     │  ├─ scan.dart                 # ScanDraft / ScanEvent / ScanSubmitResult
│     │     │  └─ outbox_entry.dart         # OutboxEntry / OutboxStatus (durum makinesi)
│     │     └─ presentation/
│     │        ├─ scan_controller.dart      # (eski manuel gönderim — outbox akışına devredildi)
│     │        └─ outbox_screen.dart        # kuyruk ekranı: liste + senkron + hata temizleme
│     └─ routing/
│        ├─ app_router.dart                # go_router + auth redirect (+ /outbox)
│        └─ splash_screen.dart             # oturum geri yüklenirken
└─ test/
   ├─ token_pair_test.dart
   ├─ api_exception_test.dart
   ├─ auth_interceptor_test.dart
   ├─ scan_outbox_test.dart                # outbox durum makinesi + kalıcılık testleri
   └─ patrol_merge_test.dart               # nokta durumu yerel birleşim mantığı (§9)
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

### NTAG424 SDM/SUN akışı (uçtan uca — mobil ayağı)

NTAG424, NDEF içindeki bir URL'e dinamik olarak şifreli alanlar gömer
(PICCData + CMAC — "SUN"/"SDM"). Backend bunları sunucuda doğrular
(`contracts/README.md` SDM bölümü); mobilin işi yalnızca **ayrıştırıp
iletmek**:

- **v0 provisioning varsayımı** (backend AN12196 konfigürasyonu ile hizalı —
  UID+CTR aynalı, ENCPICCData'lı, SDMMAC girdisi boş): etiket, NDEF URI
  kaydındaki URL'e sorgu parametresi olarak `picc_data=<32 hex>` (ENCPICCData,
  16B) + `cmac=<16 hex>` (SDMMAC, 8B) aynalar. Kısa adlar (`e`/`c`, NXP
  örnekleri) ve `piccdata` de kabul edilir; anahtar adları büyük/küçük harf
  duyarsız.
- **Format süzgeci:** değerler yalnız sözleşme formatına uyuyorsa alınır
  (tam 32/16 hex karakter; BÜYÜK harfe normalize). Uymayan değer null kalır —
  bozuk alan backend'e hiç gitmez.
- **Gövdeye giriş (`ScanDraft`):** `sdm_picc_data` + `sdm_cmac` yalnız **ikisi
  birlikte** geçerliyse `POST /scans` gövdesine eklenir. Deprecated
  `imza_dogrulandi` **gönderilmez** — değeri artık yalnız sunucu hesaplar.
- **NTAG21x / ayrıştırılamayan etiket:** SDM alanları null → gövde eskisiyle
  birebir aynı; scan yine kabul edilir (`imza_dogrulandi=false`, geçiş dönemi).
  Mevcut akışta hiçbir değişiklik yok.
- **Offline:** SDM alanları `OutboxEntry` ile diske yazılır — bekleyen kayıt
  uygulama yeniden açıldığında da SDM verisiyle gönderilir. Tekrar gönderim
  güvenli: aynı Idempotency-Key'de backend SDM doğrulamasını atlar
  (tekrar ≠ replay).
- **422 SDM hataları (kalıcı — retry YAPILMAZ, 404 ile aynı sınıf):**
  - `invalid_signature` → "Etiket imzası doğrulanamadı — sahte veya yanlış
    etiket olabilir."
  - `replay_detected` → "Bu okutma daha önce işlendi."
- **Yapılmayan (bilerek):** **kripto yok.** PICCData çözümü, CMAC doğrulama,
  replay/sayaç kontrolü mobilde **yapılmaz** — anahtar mobile konmaz.

Birim testleri: `test/nfc_sdm_parse_test.dart` (örnek NDEF/URL girdileri,
AN12196 vektörü), `test/scan_sdm_test.dart` (gövde/outbox kalıcılığı),
`test/scan_outbox_test.dart` (422 sınıflandırması).

> **Fiziksel doğrulama cihaz testinde:** gerçek NTAG424 etiketiyle uçtan uca
> deneme (provisioning → okuma → sunucu doğrulaması) henüz yapılmadı; kripto
> doğruluğu backend'de AN12196 yayınlı vektörleriyle test edildi. Farklı bir
> SDM konfigürasyonu (örn. farklı mirror/parametre düzeni) gerekirse
> `parseSdm(...)` eşleştirmesi güncellenmeli.

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
  gecikmeli gönderime uygun). GPS/checkpoint_id opsiyonel; NTAG424 okumasında
  `sdm_picc_data` + `sdm_cmac` birlikte eklenir (üstteki SDM bölümü).
  Deprecated `imza_dogrulandi` gönderilmez.
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
> ~~**Offline kuyruk** bu turda yok (senkron gönderim).~~ Offline outbox
> **eklendi** — bkz. §8. Okutma artık doğrudan gönderilmez; önce kalıcı
> kuyruğa yazılır, bağlantı varsa arka planda anında gönderilir.

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

## 8. Offline outbox — kalıcı scan kuyruğu (Faz 1 / Prompt 2)

Kapsama olmayan yerlerde (bodrum/otopark) okutulan NFC **kaybolmaz**: okutma
ANINDA kalıcı yerel kuyruğa (outbox) yazılır, bağlantı gelince arka planda
**sırayla (FIFO)** gönderilir. Kod: `features/scan/data/scan_outbox.dart`
(motor), `scan_outbox_store.dart` (depo), `domain/outbox_entry.dart` (model),
`presentation/outbox_screen.dart` (kuyruk ekranı).

### Depo seçimi ve gerekçesi

**Dosya-tabanlı JSON** (`<uygulama-belgeleri>/scan_outbox.json`, `path_provider`
ile). sqflite/hive/drift yerine bunun seçilme nedeni:

- Kuyruk **küçük** (onlarca kayıt) ve tek-yazarlı; ilişkisel sorgu, indeks,
  migration altyapısı gerekmiyor — DB bu iş için gereksiz ağırlık.
- **Atomik yazım**: önce `scan_outbox.json.tmp`'ye yazılır, sonra `rename`
  edilir. Yazım ortasında uygulama ölse bile eski geçerli dosya bozulmaz.
  (Eşzamanlı `save` çağrıları da store içinde bir kilit zinciriyle sıralanır.)
- Bozuk dosya sessizce silinmez: `.corrupt` uzantısıyla kenara alınır, kuyruk
  boş başlar (teşhis için veri durur).
- `shared_preferences` bilinçli olarak **kullanılmadı**: liste büyüdükçe tek
  string'e serileştirme kırılganlaşır ve atomiklik garantisi platforma göre
  değişir.
- Liste sırası = FIFO sırası; ayrıca `enqueued_at` alanı teşhis için tutulur.

### Durum makinesi

```
            enqueue (NFC okuma anında)
                    │
                    ▼
  ┌─► bekliyor ─► gonderiliyor ─► gonderildi   (201 yeni / 200 idempotent)
  │                   │
  │   ağ/timeout/5xx/ │ 404 (etiket eşleşmedi), 400/422 (geçersiz gövde)
  │   auth (refresh   │
  │   ölü)            ▼
  └───────────── kalici_hata   ← retry YAPILMAZ; listede görünür, temizlenebilir
```

- **`gonderiliyor`da çökme kurtarması:** gönderim ortasında uygulama ölürse
  açılışta kayıt `bekliyor`a geri alınır — sonuç bilinmese de yeniden göndermek
  güvenlidir (aşağıda "en az bir kez" bölümü).
- `gonderildi` kayıtların son 20'si UI geri bildirimi için dosyada tutulur,
  eskileri budanır (dosya sınırsız büyümez).

### Retry stratejisi (pil/veri dostu)

- Geçici hatada (ağ, timeout, 5xx, auth) tur **kesilir** (bağlantı yoksa
  sıradakiler de başarısız olur; boşa deneme yapılmaz) ve **üstel geri çekilme**
  ile zamanlanır: `15s × 2^(ardışık hata−1)`, tavan **10 dk**.
- Bağlantı geri gelince / manuel senkronda sayaç sıfırlanır → beklemeden dener.
- **401**: mevcut refresh interceptor'ı token'ı arka planda yeniler; refresh de
  ölürse kayıtlar `bekliyor`da kalır ve **login başarılı olunca** otomatik devam
  eder (tetikleyiciye bağlı).
- Kalıcı hatada (404 — etiket sistemde yok; 400/422 — gövde geçersiz, tekrar
  göndermek aynı sonucu verir) **hiç retry yapılmaz**.

### Tetikleyiciler (pump ne zaman çalışır)

| Tetikleyici | Nerede |
|---|---|
| Yeni scan kuyruğa eklenince | `ScanOutbox.enqueue` |
| Uygulama öne gelince | `AppLifecycleListener.onResume` (`outboxAutoSyncProvider`) |
| Bağlantı geri gelince | `connectivity_plus` `onConnectivityChanged` akışı |
| Login başarılı olunca | `authControllerProvider` durum dinleyicisi |
| Manuel "Şimdi senkronla" | Kuyruk ekranı (`/outbox`) butonu |
| Zamanlanmış retry | backoff `Timer`'ı |

`outboxAutoSyncProvider` uygulama kökünde (`main.dart`) watch edilir; dinleyiciler
uygulama boyunca canlı kalır. Paket seçimi: **`connectivity_plus`** (Flutter
ekosisteminin standart bağlantı-durumu paketi; yalnızca "çevrimiçi olabiliriz"
sinyali olarak kullanılır, gerçek doğrulama isteğin kendisidir).

### "En az bir kez gönder" + backend idempotency güvencesi

Idempotency-Key **okuma anında sabitlenir**: `"<uid>|<okutma_zamani ISO>"`
(`ScanDraft.idempotencyKey`). Kuyruk bu anahtarla "en az bir kez gönder"
(at-least-once) stratejisi uygular: sonucu belirsiz her gönderim (timeout,
çökme, çift tetik) güvenle **tekrar** gönderilebilir — backend aynı anahtarı
görünce yeni kayıt açmaz, **200 + mevcut kaydı** döner. Yani çift gönderim
riski yoktur; kaybolma riski de kalıcı depo sayesinde kapanır.

### Kullanıcıya yansıyan durumlar

- NFC ekranı, okuma biter bitmez kaydı kuyruğa yazar ve durumunu canlı gösterir:
  - `bekliyor` → "Kaydedildi ✓ — bağlantı gelince otomatik gönderilecek."
  - `gonderiliyor` → spinner "Kaydedildi ✓ — gönderiliyor..."
  - `gonderildi` (201) → "Gönderildi ✓ — okutma kaydedildi."
  - `gonderildi` (200) → "Gönderildi ✓ — bu okutma zaten kayıtlıydı."
  - `kalici_hata` (404) → "Bu etiket hiçbir checkpoint ile eşleşmiyor."
- **Rozet:** NFC ekranı AppBar'ında ve ana ekrandaki "Gönderim kuyruğu"
  kartında bekleyen sayısı (örn. "3").
- **Kuyruk ekranı** (`/outbox`): tüm kayıtlar durumlarıyla listelenir,
  "Şimdi senkronla" ve "Kalıcı hataları temizle" aksiyonları.

> Not: eski `scan_controller.dart` (manuel "Okutmayı gönder" akışı) yerini
> outbox akışına bıraktı; `ScanApi.submit` imzası/davranışı değişmedi — outbox
> onu kullanır.

### Cihazda doğrulama (kabul senaryosu)

```bash
cd mobile && flutter pub get && flutter test && flutter build apk --debug
flutter run --dart-define=API_BASE_URL=http://<PC-LAN-IP>:8000   # gerçek cihaz
```

1. **Uçak modunu aç** → NFC ekranında etiket okut → anında
   "Kaydedildi ✓ — bağlantı gelince otomatik gönderilecek" + AppBar rozetinde "1".
2. Uygulamayı **öldür, yeniden aç** → ana ekranda "Gönderim kuyruğu: 1 okutma
   gönderim bekliyor" (kayıt kalıcı).
3. **Uçak modunu kapat** → bağlantı tetikleyicisi pump'ı çalıştırır → rozet
   düşer, kuyruk ekranında "Gönderildi (yeni kayıt)". (Tetik gecikirse
   uygulamayı öne getirmek veya "Şimdi senkronla" da yeterli.)
4. Sistemde olmayan bir etiket okut + gönderilsin → kuyruk ekranında kırmızı
   "Kalıcı hata: ... eşleşmiyor" satırı; retry yapılmaz, "Kalıcı hataları
   temizle" ile silinebilir.
5. Aynı okutma bir şekilde iki kez gönderilirse (örn. timeout sonrası tekrar)
   backend 200 döner → "zaten kayıtlıydı" (çift kayıt oluşmaz).

---

## 9. Tur akışı ekranları — "Turlarım" (Faz 2 / Prompt 1)

Güvenlik elemanının asıl çalışma ekranı: aktif devriye penceresi + nokta
ilerlemesi + geçmiş. Kod: `features/patrol/` (data / domain / presentation),
rota: `/patrol` (ana ekrandaki "Turlarım" kartı).

### Veri kaynakları (sözleşme doğrulaması sonucu)

| Veri | Uç | RBAC (security) |
|---|---|---|
| Aktif/sıradaki pencere + okutulan/beklenen **sayıları** | `GET /dashboard/live` → `aktif_turlar[]` (AktifTur) | ✅ |
| Aktif planın **sıralı nokta listesi** | `GET /patrol-plans/{id}/checkpoints` | ✅ |
| Nokta adı/UID zenginleştirme (genişletilmiş `checkpoint` gelmezse) | `GET /checkpoints` (sayfalı, 200'lük) | ✅ |
| Pencere **geçmişi** + özet sayılar | `GET /patrol-windows` (pencere_baslangic DESC) | ✅ |

- **Aktif pencere seçimi:** `aktif_turlar` içinden `durum=bekliyor` ve
  `pencere_baslangic ≤ şimdi < pencere_bitis` olan (en erken başlayan) pencere.
  Yoksa "şu an aktif devriye yok" + varsa **sıradaki** pencere bilgisi.
- **Yenileme:** pull-to-refresh + 60 sn'de bir sessiz otomatik yenileme.
  Kalan süre sayacı saniyelik yerel `Timer`'dır (ağ çağrısı yapmaz).
- Plan nokta listesi, plan değişmedikçe tekrar çekilmez (önbellek).

### Nokta bazında durum — YEREL BİRLEŞİM (neden ve nasıl)

> **GÜNCELLEME (Faz 2 / Prompt 2):** Bu bölüm tarihçedir. Eksik uç kapandı —
> nokta durumu artık **sunucudan** gelir (`GET /me/patrol-window`), yerel
> birleşim yalnızca outbox'ta bekleyen okutmaların bindirmesine indirgendi.
> Güncel akış: **§10 (KAPANDI ✓)**.

**Sözleşme bulgusu (kritik):** mevcut uçların hiçbiri "bu pencerede **hangi**
checkpoint'ler okutuldu" bilgisini nokta bazında vermiyor:

- `GET /dashboard/live` ve `GET /patrol-windows` yalnızca
  `okutulan/beklenen_checkpoint_sayisi` **SAYILARINI** döndürür.
- Scan'lerin GET ucu yok (`/scans` yalnızca POST); `ScanEvent` listelenemez.

Bu yüzden nokta durumu **uydurulmadı**; eldeki veriyle şu birleşim yapılır
(`domain/patrol_models.dart → mergeCheckpointStatuses`, birim testli):

1. Plan nokta listesi (sunucu) taban alınır.
2. **Bu cihazın** okutma kaydı (outbox: bekleyen + gönderilmiş kayıtlar)
   pencere aralığına (`[baslangic, bitis)`) süzülür; `kalici_hata` (404 vb.)
   sayılmaz.
3. Eşleştirme: önce `checkpoint_id`, yoksa **normalize edilmiş NFC UID**
   (büyük/küçük harf duyarsız). Aynı noktaya birden çok kayıtta en "ileri"
   durum kazanır.
4. Satır durumu: `gonderildi` → **Okutuldu ✓**, kuyrukta → **"Okutuldu ✓ —
   gönderiliyor"** (offline'da bile ilerleme görünür), yoksa **Bekliyor**.

Kısıtlar (ekranda da not düşülür):

- Nokta bazlı ✓'ler **yalnızca bu cihazın** okutmalarını gösterir; başka
  görevlinin okutması sadece sunucu sayısına yansır. Sunucu sayısı yereldan
  büyükse kart üstünde "sunucuda N okutma kayıtlı (diğer cihazlar dahil
  olabilir)" bilgisi gösterilir. İlerleme çubuğu `max(sunucu, yerel)` kullanır
  (offline'da ilerleme geri gitmez).
- Outbox `gonderildi` kayıtlarının son 20'sini tutar; 1 saatlik pencere için
  fazlasıyla yeterlidir, ama uygulama verisi silinirse yerel ✓'ler kaybolur
  (sunucu sayısı kalır).

### Okutma entegrasyonu

Karttaki **"Nokta okut (NFC)"** → mevcut `/nfc` ekranı → okutma **mevcut
outbox akışıyla** kaydedilir/gönderilir (yeni gönderim yolu YOK). Tur
controller'ı outbox'ı dinlediği için listeye dönüldüğünde ✓ **anında** görünür
(201 yeni / 200 zaten / offline kuyrukta → "gönderiliyor"; 404 → sayılmaz,
NFC ekranı zaten "eşleşmedi" gösterir). NFC dönüşünde ayrıca sessiz bir sunucu
yenilemesi tetiklenir (sayılar için).

### Rol duyarlılığı

Ana menü **role göre bileşir** (`features/home/domain/home_menu.dart`; JWT
`role` claim'i → `features/auth/domain/user_role.dart`; kurallar
`contracts/auth.md` §4'ün UX aynasıdır — gerçek yetki backend RBAC'ta):

| Rol | Gördüğü kartlar |
|---|---|
| `admin` (Admin — platform) | Duyurular, Turlarım, Görevlerim, Demirbaş, NFC, Kuyruk (**Yönetici İletişim YOK** — yönetimin kendisi) |
| `security` (Güvenlik) | admin ile aynı + **Yönetici İletişim** (menüde EN ALTTA) |
| `tesis_gorevlisi` (Tesis Görevlisi — eski `cleaning`) | Turlarım HARİÇ hepsi (`/me/patrol-window` admin+security) + **Yönetici İletişim** (EN ALTTA) |
| `yonetici` (Yönetici — site yöneticisi) | **Duyurular** (gönder/düzenle/sil) + **Devriye takibi** (bugünün turları + geçmiş, salt izleme) + **Görev yönetimi** (oluştur/ata/düzenle/sil — atama yalnız saha personeline; tamamlama akışı detayda gizli) + **Aylık raporlar** (devriye/görev/aidat özeti). **Yönetici İletişim YOK** — kendisi yönetimdir |
| `resident` (Site Sakini) | **Duyurular** (salt okuma) + **Aidatim** (daire borç durumu + tahakkuk/ödeme geçmişi) + **Yönetici İletişim** (menüde EN ALTTA) |

**Devriye takibi** (`features/patrol/presentation/patrol_tracking_*`):
yonetici için salt-izleme ekranı — panelin canlı özetinin mobil karşılığı.
"Bugün" sekmesi `GET /dashboard/live`den bugünün pencerelerini durum çipi
(Şimdi aktif / Yaklaşan / Tamamlandı / Kaçırıldı) ve okutulan/beklenen
ilerleme çubuğuyla listeler (`trackingOzet` saf fonksiyonu birim testli);
"Geçmiş" sekmesi Turlarım'ın geçmişiyle AYNI paylaşılan görünümü kullanır
(`patrol_history_view.dart` — `GET /patrol-windows` özet + son pencereler).
Okutma/scan bu ekranda yoktur; saha kanıtı Turlarım'ın işidir.

**Aidatim** (`features/dues/`): resident'ın kendi dairelerinin borç durumu
(`GET /me/dues` — yalnız resident; sunucu sakinin dairelerine süzer). Daire
kartı: tahakkuk/ödenen/bakiye (sunucu hesabı — istemci yeniden hesaplamaz,
yalnız görüntüler) + "Borç var/yok" çipi; genişleyen tahakkuk listesi (dönem,
son ödeme tarihi, açıklama) ve ödeme geçmişi (tarih, yöntem, durum rozeti:
başarılı/bekliyor/iptal, makbuz no). Birden çok dairede toplam bakiye kartı.
Ödeme bu ekrandan YAPILAMAZ — durum yalnızca sağlayıcı webhook'uyla değişir
(ekranda not olarak da yazar). Para biçimi `kurusToTl` (ortak kural).

**Görev yönetimi** (`features/tasks/` — yönetim katmanı): admin + yonetici
listede "Yeni görev" FAB'ı ve detayda Düzenle/Sil menüsü görür
(`TasksState.canManage`). Bottom-sheet form: tip, ad, açıklama, **atanan
personel** (yalnız aktif security/tesis_gorevlisi listelenir —
`assignableFromUsersJson` saf süzgeci, `GET /users`'tan), periyot, foto
zorunlu, aktif anahtarı. `TaskDraft` TAM-GÖVDE gönderir (null alanlar dahil →
PATCH'te atama/açıklama temizlenebilir). Backend kısıtı aynen geçerli:
yonetici saha dışı role atarsa 422 mesajı formda gösterilir. Saha dışı
yönetim rollerinde liste varsayılanı "Herkes"tir ("Bana atanan" yonetici için
boş olurdu).

**Aylık raporlar** (`features/reports/`): yonetici için ay bazlı salt-okuma
özet — ‹ ay › gezinme (içinde bulunulan aydan ileri gidilmez). Üç bölüm +
son tamamlamalar: **Devriye** (`GET /patrol-windows?baslangic&bitis`, yalnız
`ozet` kullanılır — filtrelenmiş tüm küme), **Görev tamamlama**
(`GET /task-completions?baslangic&bitis` — özet + son 10, NFC/foto rozetli),
**Aidat** (`GET /dues/assessments|payments?donem` tüm sayfalar toplanır;
yalnız `durum='basarili'` ödemeler tahsilat sayılır — `aidatOzet` saf
fonksiyonu birim testli). Para kuruş cinsinden tam sayı aritmetiğiyle
biçimlenir (`kurusToTl`, panel `money.ts` kuralı); ay sınırları yarı-açık
(`ayAralik`).

**Duyurular** (`features/announcements/`): tüm roller okur (en yeni önde,
gönderen adı + tarih + "düzenlendi" rozeti, pull-to-refresh); admin/yonetici
FAB ile yayınlar, kart menüsünden düzenler/siler (bottom-sheet form,
başlık ≤200 / gövde ≤5000 — sunucu sınırlarının aynısı). Yayınlama backend'de
tesisin TÜM kayıtlı cihazlarına push dener (auth.md §4). FAB/menü görünürlüğü
UX kapısıdır; gerçek yetki backend RBAC'ta.

Menüden ulaşılan ekranlarda kalan `403`'ler için kibar mesaj davranışı
korunur; `401` mevcut refresh interceptor'ının işidir (gerekirse login'e
döner). Yönetici için devriye takibi / rapor ekranları sonraki tur işidir
(backend uçları hazır: `patrol-windows`, `dashboard/live`, raporlar).

---

## 10. Sözleşme notları (DEV-A'ya)

### ✅ KAPANDI ✓ — checkpoint bazında okutma durumu (Faz 2 bulgusu)

**Durum:** `GET /me/patrol-window` yayında (DEV-A CEVAP bloğu aşağıda) ve mobil
bu uca bağlandı. Yeni veri akışı:

- **Sunucu tek kaynak:** nokta listesi + `okutuldu/okutma_zamani/okutan_user_id`
  artık `GET /me/patrol-window`'dan gelir (pencere-geneli — başka elemanın
  okutması da listede ✓ görünür). Gönderilmiş scan'ler için yerel kayda
  bakılmaz.
- **Outbox bindirmesi:** bu cihazın outbox'ta BEKLEYEN (henüz gönderilmemiş)
  okutmaları sunucuda görünmediği için sunucu verisinin üzerine
  "okutuldu (gönderiliyor)" olarak bindirilir (`mergeCheckpointStatuses` —
  rolü buna indirgendi). Gönderim tamamlanınca sunucu verisi sessizce
  tazelenir; satır sunucu ✓'sine geçer. Offline'da ilerleme görünür,
  online'da ekip görünümü tam — iki dünyanın iyisi.
- **Çoklu pencere:** `windows[]` birden fazlaysa ekranda basit bir seçici
  çıkar; varsayılan sunucunun `window`'u (bitişi en yakın pencere).
- **`window: null`** → mevcut "şu an aktif devriye yok" kartı (200, retry yok).
- `GET /patrol-plans/{id}/checkpoints` yalnızca NFC UID haritası için kalır
  (outbox kayıtları çoğunlukla checkpoint_id taşımaz); başarısız olursa
  bindirme checkpoint_id eşleşmesine düşer, ekran sunucu verisiyle çalışır.

Orijinal bulgu ve DEV-A cevabı tarihçe olarak aşağıda korunuyor.

### 🚩 Eksik uç — checkpoint bazında okutma durumu (Faz 2 bulgusu, ÖNEMLİ)

Mobilin "aktif turumda hangi noktaları okuttum" listesi için sözleşmede
**nokta bazlı sunucu verisi yok**:

- `GET /dashboard/live` (AktifTur) ve `GET /patrol-windows` yalnızca
  `okutulan/beklenen_checkpoint_sayisi` **sayılarını** döndürüyor.
- Scan'lerin GET ucu yok (`/scans` yalnızca POST) — pencereye ait ScanEvent'ler
  listelenemiyor.

Mobil şimdilik plan nokta listesi + **bu cihazın yerel okutma kaydı** (outbox)
birleşimiyle çalışıyor (bkz. §9), ancak bu **cihaz-yerel** bir görünümdür:
aynı pencerede başka görevlinin okuttuğu noktalar listede ✓ görünmez (yalnızca
sunucu sayısına yansır); uygulama verisi silinirse yerel ✓'ler kaybolur.

**Öneri:** şu ikisinden biri eklenirse mobil çok daha sağlam olur:

1. `GET /me/patrol-window` — aktif pencere + checkpoint bazında okutma durumu:
   `{ window: {...AktifTur}, checkpoints: [{ checkpoint_id, ad, sira,
   okutuldu: bool, okutma_zamani?, okutan_user_id? }] }` (tercih edilen; tek
   istekte tüm ekran verisi), **veya**
2. `GET /patrol-windows/{id}/scans` — pencereye bağlanmış ScanEvent listesi
   (mobil eşleştirmeyi kendisi yapar).

RBAC: admin + security (dashboard ile tutarlı). Eklendiğinde mobil tarafta tek
değişiklik `PatrolApi` + birleşim kaynağıdır; UI aynı kalır.

### Önceki notlar

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
### CEVAP (DEV-A / backend) — cozuldu: `GET /me/patrol-window` yayinda (main, `7f9c448`)

Yerel kayit cozumunu sokebilirsiniz; onerdiginiz semaya sadik kalindi, birkac
ekleme var:

- **Sekil:** `{ generated_at, window, checkpoints, windows }`. `window` +
  `checkpoints` onerdiginiz sade yapi; ek olarak `windows[]` TUM aktif
  pencereleri doner (birden cok plan ayni anda aktif olabildigi icin, her biri
  kendi checkpoint listesiyle, `pencere_bitis` ASC). `window` = bitisi en yakin
  aktif pencere. Tek pencereli kullanim icin `window`/`checkpoints` yeterli.
- **Aktif pencere yoksa:** `window: null` + bos listeler, **200** (hata degil) —
  retry/hata akisi kurmayin.
- **`okutuldu` pencere-geneli:** baska elemanin okutmasi da gorunur
  (scheduler'in "tamamlandi" mantigiyla ayni eslesme). `okutma_zamani` /
  `okutan_user_id` penceredeki **ilk** scan'den; checkpoint alanlari:
  `checkpoint_id, ad, sira, okutuldu, okutma_zamani?, okutan_user_id?`
  (alan adlari onerdiginiz gibi).
- **RBAC:** admin + security (cleaning/resident 403). Detay:
  `contracts/openapi.yaml` → `/me/patrol-window` ve `contracts/README.md` →
  "Aktif devriye durumu (me/patrol-window)".

---

## 11. Görev ekranları — "Görevlerim" (Faz 3 / Prompt 1)

### ✅ KAPANDI ✓ — §11 sözleşme bulguları (uyarlama turu)

Aşağıda flag'lenen 3 bulgu backend'de kapandı (DEV-A cevabı:
`contracts/README.md` → "Birikmiş flag temizliği") ve mobil uyarlandı:

1. **"Bana atananlar" sunucuda ✓:** varsayılan görünüm artık
   `GET /tasks?atanan_user_id=me` ile TEK istekte yalnız benim görevlerim.
   İstemcideki "bana atananlar öne" sıralaması kaldırıldı (kalan istemci
   işi yalnız tarih sırası — `sortTasksByPlan`). "Herkes" chip'i eski
   tam-liste görünümünü korur (havuz/atanmamış görevler; "Sana atanmış"
   rozeti yalnız bu görünümde anlamlı olduğundan orada gösterilir). JWT
   `sub` çözümü bu rozet için duruyor.
2. **`foto_zorunlu` geldi ✓:** listede ve detayda "Foto zorunlu" rozeti;
   foto'suz "Tamamla" denemesi İSTEMCİDE erken uyarıyla durdurulur
   ("bu görev için foto kanıtı zorunlu"), backend 422 mesajı da yakalanır.
3. **NFC normalize backend'de ✓:** karşılaştırma artık strip+upper —
   mobil zaten sözleşme formatı ürettiği için davranış değişikliği yok.

**İstek özeti:** "Görevlerim" önce TÜM aktif görevleri çekip istemcide
sıralıyordu; şimdi varsayılan görünüm sunucu süzmesiyle tek (ve daha
küçük) istek. Orijinal bulgular tarihçe olarak aşağıda.

---

Temizlik/kontrol personelinin (role=cleaning; security de erişir) görev
listesi ve NFC + foto kanıtlı tamamlama akışı.
Kod: `features/tasks/` (data / domain / presentation), rota: `/tasks`
(ana ekrandaki "Görevlerim" kartı) → detay `/tasks/detail`.

### Veri kaynakları (sözleşme doğrulaması sonucu)

| Veri | Uç | RBAC (cleaning) |
|---|---|---|
| Görev listesi (tip/aktif filtreli, sayfalı) | `GET /tasks` | ✅ |
| Görev tamamlama (kanıt gönderimi) | `POST /tasks/{id}/completions` (**Idempotency-Key zorunlu**) | ✅ |
| Foto yükleme bileti | `POST /uploads/presign` → `{foto_key, upload_url, method:PUT, expires_in}` | ✅ |

### Görev akışı

1. **Liste:** aktif görevler; tip rozeti renkli (temizlik/kontrol/ilaçlama/
   bakım/peyzaj/diğer), `sonraki_planlanan` varsa tarih, **bana atananlar
   önde ve "Sana atanmış" vurgulu**. Tip filtresi chip'leri sunucuya `tip`
   parametresi olarak gider. Pull-to-refresh. 403'te kibar mesaj.
2. **Detay/tamamlama:** akış açıldığı anda `tamamlanma_zamani` +
   **Idempotency-Key sabitlenir** (`task-completion|{taskId}|{zaman}` —
   scan desenindeki gibi deterministik). Adımlar:
   - **NFC** (görevde `checkpoint_id` doluysa): mevcut `features/nfc`
     servisi **yeniden kullanılır** (kopya yok); okunan UID completion'a
     gider. Eşleşme doğrulaması **backend'dedir**: etiket görevin
     noktasıyla uyuşmazsa `422 invalid_reference` döner ve mesaj kullanıcıya
     aynen gösterilir.
   - **Foto** (opsiyonel kanıt): çek/galeriden seç → aşağıdaki presign akışı
     → `foto_key` taslağa işlenir. Önizleme + "Yeniden çek" + "Tekrar
     yükle" + "Kaldır".
   - **Not** (opsiyonel) → **"Tamamla"** → `POST /tasks/{id}/completions`.
     **201 → "kayıt oluşturuldu"**, **200 → "zaten kayıtlıydı (çift kayıt
     oluşmadı)"** ayrımı sonuç kartında ve liste rozetinde görünür.

### Foto / presign akışı

```
image_picker (kamera|galeri, maxWidth 1600, quality 80)
   → POST /uploads/presign {content_type, dosya_adi}   (auth'lu ana Dio)
   → yanıt: {foto_key, upload_url (kısa ömürlü), method: PUT}
   → HTTP PUT upload_url  (TEMİZ Dio: Authorization YOK — presigned imza
     bozulmasın; Content-Type presign'daki ile aynı)
   → foto_key → TaskCompletionDraft.fotoKey → completion gövdesinde gider
```

### İzin / platform yapılandırması

- **Android** (`AndroidManifest.xml`): ek runtime izni GEREKMEZ —
  `image_picker` çekimi sistem kamera uygulamasına devreder. Android 11+
  paket görünürlüğü için `<queries>` içine
  `android.media.action.IMAGE_CAPTURE` eklendi.
- **iOS** (`Info.plist`): `NSCameraUsageDescription` +
  `NSPhotoLibraryUsageDescription` eklendi (kamera + galeri).

### Paket seçimi + gerekçe

- **image_picker** (flutter.dev resmî paketi): kamera + galeri tek API,
  platform tarafında bakımlı, ek native kod/izin karmaşası yok. `camera`
  paketi (tam ekran özel kamera) bu iş için gereksiz ağır; kanıt fotosu
  için sistem kamerası yeterli ve daha az bakım yükü.

### Offline kısıtı (bilinen, bilinçli sade)

- **Fotoğraflı tamamlama ONLINE gerektirir**: presigned URL kısa ömürlü
  olduğundan foto yüklemesi ertelenemez. Bağlantı yokken foto yükleme /
  tamamlama denemesi kullanıcıya **net uyarı** gösterir ("internet
  bağlantısı gerekli"); Idempotency-Key sabit olduğu için bağlantı gelince
  aynı "Tamamla" güvenle tekrarlanır (çift kayıt oluşmaz).
- Fotosuz tamamlamanın outbox'a alınıp ertelenmesi **bu turda yok** —
  sonraki tur adayı (scan outbox deseni birebir uygulanabilir).

### Cihaz doğrulama senaryosu

1. `cleaner@acme.com / Clean123!` ile login (tenant: acme).
2. Ana ekran → **Görevlerim** → liste tip rozetleriyle gelir; "Sana
   atanmış" görevler önde.
3. Göreve gir → (varsa) **Etiketi okut** → **Foto çek** ("Yüklendi ✓"
   bekle) → not yaz → **Tamamla** → "kayıt oluşturuldu".
4. Aynı ekranda "Tamamla"nın tekrarı mümkün değil; ağ hatasında tekrar
   basmak 200 "zaten kayıtlıydı" gösterir.
5. Panel (admin) → görev raporları/`GET /task-completions` → tamamlama
   foto/NFC kanıt bayraklarıyla anında görünür.

### 🚩 Sözleşme bulguları (tarihçe — TAMAMI KAPANDI ✓, üstteki bloğa bakın)

1. **"Bana atananlar" filtresi yok:** `GET /tasks` yalnızca `tip` + `aktif`
   + sayfa parametreleri sunuyor; `atanan_user_id` filtresi YOK. Mobil tüm
   aktif görevleri çekip **istemcide** sıralıyor (bana atananlar öne; JWT
   `sub` claim'i yalnızca bu vurgu için çözülür, yetki kararı değil).
   **Öneri:** `GET /tasks?atanan_user_id=me` (veya `atanan=me` kısayolu)
   eklenirse büyük tenant'larda liste küçülür.
2. **Foto zorunluluğu alanı yok:** Task şemasında "foto kanıtı zorunlu"
   bayrağı yok (`foto_key` nullable). Mobil fotoyu **opsiyonel** kanıt
   olarak sunuyor. **Öneri:** görev bazında `foto_zorunlu: bool` alanı
   (panel'de işaretlenebilir) eklenirse saha disiplini kurulabilir.
3. **NFC eşleşmesi büyük/küçük harfe duyarlı:** backend completion'da
   `cp.nfc_tag_uid != body.nfc_tag_uid` ile **birebir** karşılaştırıyor
   (`backend/app/routers/tasks.py`). Mobil UID'yi her zaman sözleşme
   formatında (BÜYÜK HARF, `:` ayraçlı) üretir, sorun çıkmaz; ama panelden
   farklı formatta etiket girilirse eşleşme düşer. **Öneri:** backend
   karşılaştırmayı normalize etsin (scan ucundaki davranışla tutarlılık).

---

## 12. Demirbaş zimmet — NFC ile checkout/checkin (Faz 3 / Prompt 3)

### ✅ KAPANDI ✓ — §12 sözleşme bulguları (Faz 3 / Prompt 4 sadeleştirmesi)

**Durum:** Aşağıda flag'lenen 6 bulgunun tamamı backend'de kapandı (DEV-A
cevabı: `contracts/README.md` → "Mobil §13 bulguları kapatıldı") ve mobil
sadeleştirildi. **Davranış/UI aynı, veri yolu kısaldı:**

- **UID→asset:** `GET /assets?nfc_tag_uid=...` TEK istek (0/1 sonuç).
  İstemci UID indeksi (`buildUidIndex`/`lookupByUid`) kaldırıldı.
- **"Kimde":** Asset yanıtındaki `acik_zimmet {alan_user_id, alan_user_ad,
  alinma_zamani}` alanından. History taraması (`findOpenCheckout` +
  toplam-öğren/son-sayfa-çek hilesi) kaldırıldı. Kart artık **gerçek adla**
  çizilir: "Başkasında: Ahmet — 2 saattir üzerinde."
- **Üzerimdekiler:** `GET /assets?checked_out_by=me` TEK istek (N+1 history
  süzmesi kaldırıldı).
- **Geçmiş:** varsayılan **DESC** → son N hareket doğrudan ilk sayfa;
  satırlarda `alan_user_ad` (ad boş gelen eski kayıtta kısa id fallback).
- **Checkin sahiplik:** backend artık yalnız sahibi/admin'e izin veriyor
  (başkası → 403); mobil zaten butonu göstermiyordu, 403 mesajı da mevcut
  hata kartında kibarca görünür.

**İstek sayısı (önce → sonra):**

| Akış | Önce | Sonra |
|---|---|---|
| Etiket okut → kart | liste sayfaları (≥1) + detay + history×2 = **≥4** | UID sorgusu + history = **2** |
| Üzerimdekiler | zimmetli liste + N×(history×2) = **1+2N** | **1** |
| Aksiyon sonrası tazeleme | detay + history×2 + (1+2N) = **≥4+2N** | detay + history + 1 = **3** |

Orijinal bulgular ve eski veri yolu anlatımı tarihçe olarak aşağıda korunuyor.

---

"Çim biçme makinesini kim aldı?" — saha personeli demirbaşı alırken/bırakırken
üzerindeki NFC etiketini okutur; panel kimde olduğunu anlık görür.
Kod: `features/assets/`, rota: `/assets` (ana ekrandaki "Demirbaş" kartı).
RBAC (auth.md doğrulandı): liste/checkout/checkin/history → admin + security +
cleaning ✅ (resident ❌).

### Akış ve durum makinesi

Büyük **"Etiket okut"** (mevcut `features/nfc` servisi — kopya yok) → UID →
asset çözümü → taze `GET /assets/{id}` + geçmiş → karta göre aksiyon:

| Durum | Karar (`zimmetVerdict`) | Kart | Aksiyon |
|---|---|---|---|
| `musait` | **kimsedeDegil** | yeşil "Kimsede değil" | **Zimmetine al** (checkout) |
| `zimmetli` + açık zimmet **bende** | **sende** | mavi "SENDE — X saattir üzerinde" | **Bırak / iade et** (checkin) |
| `zimmetli` + açık zimmet **başkasında** | **baskasinda** | turuncu "Başkasında (kısa-id) — X saattir" | YOK — "zorla devralma yok, o bırakmalı" |
| `zimmetli` ama açık kayıt çözülemedi | **baskasinda** (temkinli) | turuncu | YOK (yanlış "al" göstermekten iyidir) |
| `bakimda` | **bakimda** | gri "Bakımda" | YOK |

Kayıtsız etiket → net mesaj ("etiket kayıtlı bir demirbaşla eşleşmiyor —
panelden tanımlanmalı"). Kartın altında **son 5 hareket** (kim aldı/bıraktı,
ne zaman — history ucundan). **Üzerimdekiler** sekmesi: şu an bende olanlar
(alınma zamanı + "X saattir") + hızlı **Bırak**.

### UID → asset çözümü (tarihçe — kısıt kapandı, üstteki KAPANDI bloğuna bakın)

`GET /assets`'ta `nfc_tag_uid` araması YOK (filtreler: kategori/durum/aktif).
Bu yüzden çözüm İSTEMCİDE: aktif asset listesi (200'lük sayfalarla) çekilir,
normalize UID (BÜYÜK HARF, kırpılmış) → asset indeksi kurulur, okutulan UID
oradan bulunur; ardından **taze** `GET /assets/{id}` ile güncel durum alınır
(liste bayat olabilir). Envanter küçük olduğu için her okutmada tazelenir.

### İşlem semantiği (backend'den doğrulandı)

- **Idempotency-Key** her iki işlemde ZORUNLU; mobilde aksiyona **basış
  anında sabitlenir** (`asset-alma|{assetId}|{an}` / `asset-birakma|...`) —
  çift dokunuş/tekrar aynı isteği atar; checkout 200-idempotent, checkin'in
  tekrarı da 200 döner.
- **409 yarışı** (sen okurken başkası aldı → "Demirbaş zaten zimmetli." /
  çoktan bırakılmış → "Açık zimmet yok"): kibar mesaj + kart taze durumla
  otomatik yeniden çizilir.
- `nfc_tag_uid` gövdede gönderilir (okutmalı akışta) → backend asset
  etiketiyle eşleşmesini doğrular (422). "Üzerimdekiler"deki hızlı Bırak'ta
  etiket okutulmaz → alan gönderilmez (sözleşmede opsiyonel).

### Offline kararı (README'ye yazılması istendi)

**Zimmet CANLI durum işidir** — "kimde" bilgisi anlık gerçektir. Bağlantı
yokken checkout/checkin YAPILMAZ ve kuyruklanmaz: sıraya alınmış bir "aldım"
kaydı yanıltıcıdır (panel yanlış kişi gösterir) ve yarış riski üretir (aynı
makineyi iki kişi "almış" olur). Offline'da net uyarı: *"İnternet bağlantısı
gerekli. Zimmet kimde-olduğu ANLIK bir kayıttır; offline işlem yapılmaz."*
Scan/görev outbox'ı bu karara KARIŞMAZ (onlar geçmişe dönük kanıt kayıtları).

### 🚩 Sözleşme bulguları (tarihçe — TAMAMI KAPANDI ✓, üstteki bloğa bakın)

1. **UID araması yok:** `GET /assets?nfc_tag_uid=...` (veya
   `GET /assets/by-tag/{uid}`) eklenirse etiket çözümü tek istek olur;
   şimdilik tüm liste + istemci indeksi.
2. **"Kimde" bilgisi Asset'te yok:** durum `zimmetli` ama açık zimmetin
   sahibi/zamanı için `GET /assets/{id}/history` taranmak zorunda. Öneri:
   Asset'e `acik_zimmet: {alan_user_id, alan_user_ad?, alma_zamani} | null`
   gömülsün — "başkasında (Ahmet, 2 saattir)" tek istekle çizilir.
3. **"Üzerimdekiler" filtresi yok:** `GET /assets?checked_out_by=me`
   önerilir. Şimdilik: `durum=zimmetli` liste + her asset için history
   kuyruğu (N+1 istek) + istemcide `alan_user_id == ben` süzmesi.
4. **History sıralaması ASC:** `alma_zamani` ARTAN sıralı (en yeni SONDA) —
   mobil "son N hareket" için önce toplamı öğrenip son sayfayı çekiyor.
   Öneri: DESC (en yeni önce) veya `order` parametresi.
5. **Kullanıcı adı çözümü yok:** history yalnızca `alan_user_id` veriyor;
   `/users` admin-only olduğundan saha rolü isim çözemez → "başkasında"
   kartında kısa id gösteriliyor. Öneri: AssetCheckout'a `alan_user_ad`
   eklensin.
6. **Checkin'de sahiplik kontrolü yok (backend):** açık zimmeti HERHANGİ bir
   saha rolü kapatabiliyor (`assets.py` — alan kullanıcı kontrolü yok).
   Mobil UX "başkasında → yalnızca bilgi" kuralını koyuyor ama API bunu
   zorlamıyor. Öneri: checkin'i zimmet sahibi (veya admin) ile sınırla ya da
   bilinçli "devir" ucu ekle.

### Cihaz doğrulama senaryosu

1. `guard@acme.com / Guard123!` ile login → **Demirbaş** → **Etiket okut** →
   makinenin NFC'si → yeşil "Kimsede değil" → **Zimmetine al** → "Zimmetine
   alındı ✓", kart maviye döner ("SENDE").
2. Panel (admin) → assets ekranı → makine `zimmetli`, guard'ın üzerinde.
3. Uygulama → **Üzerimdekiler (1)** → makine + "X dakikadır" → **Bırak** →
   liste boşalır; panel `musait` gösterir.
4. İkinci kullanıcı (cleaner) aynı etiketi okutursa turuncu "Başkasında
   (kısa-id) — X dakikadır" görür; al butonu YOK.
5. Yarış testi: iki cihaz aynı anda "Zimmetine al" → biri 201, diğeri 409
   "Demirbaş zaten zimmetli." + kart otomatik tazelenir.
6. Uçak modunda okutma/işlem → net "bağlantı gerekli" uyarısı.

## 13. Push bildirim — FCM entegrasyonu (Faz 4)

Backend gerçek FCM (HTTP v1) ile push atabiliyor (`contracts/README.md`
"Push bildirim" bölümü); mobil ayağı: **token al → `POST /devices` kaydet →
bildirimi göster**. Kod: `lib/src/features/push/`.

### google-services.json (repoya GİRMEZ)

Firebase Android uygulaması kayıtlı: `com.tesisguvenlik.mobile`. Yapılandırma
dosyası **`mobile/android/app/google-services.json`** — kök `.gitignore`'da,
**commit edilmez**. Locale çeken herkes Firebase Console'dan
(tesis-platform → Android app) kendi kopyasını indirip aynı yola koyar.

- **Dosya VARSA:** `google-services` Gradle plugin'i uygulanır (app
  `build.gradle.kts`'de koşullu `apply`), Firebase çalışır.
- **Dosya YOKSA:** build YİNE geçer (plugin uygulanmaz); çalışma zamanında
  `Firebase.initializeApp` hata verir, yakalanır → push **sessizce devre
  dışı** (`PushDurum.devreDisi`), uygulamanın geri kalanı normal çalışır
  (kabul kriteri — CI/yeni geliştirici senaryosu).

### Token yaşam döngüsü (`push_registrar.dart`)

- **Login/oturum geri yükleme sonrası** (`pushSetupProvider` tetikler):
  `Firebase.initializeApp` → bildirim izni istemi (Android 13+
  `POST_NOTIFICATIONS`; manifest'e eklendi) → `getToken()` →
  `POST /devices {fcm_token, platform:"android"}`. Backend **idempotent
  upsert** — her açılışta göndermek güvenli; kayıt hatası (ağ vb.) yutulur,
  sonraki açılışta yeniden denenir.
- **`onTokenRefresh`:** eski token `DELETE /devices/{token}` ile
  pasifleştirilir (best-effort), yenisi kaydedilir. Yerel işaret yoksa
  (logout olmuş) kayıt DENENMEZ (oturumsuz 401 olurdu).
- **Logout:** `AuthController.logout`, auth token'lar HENÜZ geçerliyken
  `PushRegistrar.onLogout()` çağırır → `DELETE /devices/{fcm_token}` (404
  başarı sayılır) + yerel işaret temizlenir. Push hatası logout'u asla
  engellemez.
- Kayıtlı token `flutter_secure_storage`'da tutulur
  (`push.registered_fcm_token`) — uygulama yeniden açılıp logout olsa bile
  hangi token'ın pasifleştirileceği bilinir.
- Mimari not: `PushRegistrar` auth'a bağımlı DEĞİLDİR (logout kancası ters
  yönde bağımlılık kurduğundan, auth→push köprüsü ayrı `pushSetupProvider`
  glue'sunda — aksi provider döngüsü olurdu).

### Bildirim gösterimi

- **Arka plan / kapalı:** backend `notification` bloğu (title+body) + `data`
  gönderdiği için (`backend/app/push.py`) FCM bildirimi **sistem tepsisine
  kendisi düşürür**; ek kod yok. Dokununca uygulama açılır (ana ekran) —
  şimdilik yeterli.
- **Ön planda:** `onMessage` yakalanır → kök `ScaffoldMessenger` ile basit
  **SnackBar** ("başlık — gövde"). Bilinçli dar kapsam:
  `flutter_local_notifications` EKLENMEDİ; **zengin ön-plan bildirimi
  ileride**.
- **İleride (derin-link):** `data.tip` mevcut (`duyuru`, `kacirilan_tur`) —
  bildirime dokununca ilgili ekrana gitme (`onMessageOpenedApp` + go_router)
  sonraki iş.

### iOS

**Yapılandırılmadı** (bilerek): iOS push, Mac + Apple Developer hesabı +
APNs anahtarı + `GoogleService-Info.plist` gerektirir — **ayrı iş**. Kod
tarafı hazır (platform `ios` gönderimi destekli); yalnız yapılandırma eksik.

### Testler

`test/push_registrar_test.dart` (sahte `PushMessaging`/`DeviceApi` ile):
login→kayıt, restore→kayıt, Firebase yok→devre dışı (çökme yok), token
null→kayıt yok, kayıt hatası yutulur, refresh→eski pasif + yeni kayıt,
logout→unregister+temizlik (hata yutulur), logout sonrası refresh kayıt
denemez, ön plan mesajı state'e yansır, çift abonelik yok.

> **Gerçek uçtan uca push cihaz testinde:** fiziksel cihaz + backend
> `PUSH_PROVIDER=fcm` ile doğrulanacak (backend duman testi geçti; mobil
> birim testleri Firebase'i sahteler).
