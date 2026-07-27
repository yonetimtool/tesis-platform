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

### 🔐 Örnek test girişleri (gerçek backend, seed verisi)

**Mobil giriş TELEFONLADIR** (`POST /auth/login-phone`) — tesis kodu/e-posta
istenmez, tenant numaradan çözülür. E-posta + `tenant_slug` girişi
(`POST /auth/login`) **yalnız admin-web panelindedir**.

| Rol | Telefon | Parola |
|---|---|---|
| admin (platform admini) | `+905321112200` | `Admin123!` |
| yonetici (birincil) | `+905321112201` | `Yonetici123!` |
| security | `+905321112202` | `Guard123!` |
| tesis_gorevlisi | `+905321112204` | `Clean123!` |
| resident | `+905321112203` | `Resident123!` |

> Bunlar docker compose ile kalkan yerel backend'in seed kullanıcılarıdır.
> Admin'in telefonu sonradan eklendi: numarası olmadığı için mobilde **hiç**
> giriş yapamıyordu (panelde e-postayla giriyor). Mobilde admin, yönetim
> düzenini görür (`HomeGate`: admin → yönetici varyantı).

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

Akış: login ekranı (örnek giriş: `+905321112201` / `Yonetici123!` — tam liste
yukarıda) → `POST /auth/login-phone` → dönen access+refresh çifti secure
storage'a yazılır → rolün ana ekranına geçilir. Sonraki korunan isteklerde
access token otomatik eklenir; 401'de arka planda refresh denenir (§3).

Soğuk açılış **her zaman login ekranına düşer** (sessiz auto-login bilerek yok);
"Beni hatırla" işaretliyse alanlar ön-dolu gelir ve kullanıcı Giriş'e basar.
Çıkış app-bar avatarındaki hesap menüsündedir.

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

---

## 14. Ana sayfa yeniden tasarımı — 3 rol, referans görseller (DEV-B)

Ana ekran(lar) `docs/design-refs/` altındaki üç referans görsele göre yeniden
kuruldu: `gorevli.jpeg` (güvenlik görevlisi), `site-sakini.jpeg` (site sakini),
`yonetici.jpeg` (yönetici). Bu bölüm **mimari kararı**, **mock/gerçek veri
sınırını** ve **gerçek uca bağlanacak noktaları** kayda geçirir.

### Mimari karar: 3 ekran + tek paylaşımlı komponent seti

Seçenekler "tek `HomeScreen` + rol konfigürasyonu" ve "3 ekran + paylaşımlı
komponentler" idi. **İkincisi** seçildi:

- Üç varyantın **UI'ı** neredeyse tamamen ortak (kabuk, kartlar, bölümler) —
  bu yüzden **tüm görsel kod tek yerde**: `home/presentation/widgets/`. Kopya
  üçüz UI kodu **yok**.
- Farklılaşan şey UI değil, **veri kablolaması ve RBAC**: sakin `/me/dues`,
  `/kargo`, `/visitors` izler; saha `/shifts` + `/cameras` izler (ve
  `tesis_gorevlisi` KVKK gereği kargo/ziyaretçi/kamera **görmez**); yönetim
  `/reports/financial-summary` + `/notifications` izler. Bunları tek bir
  ekranda `if (role == ...)` ile toplamak, izinsiz rollerde **401/403
  üretecek provider'ları da izlemek** anlamına gelirdi.
- Bu yüzden her rol ekranı yalnızca ~150 satırlık **kablolama** dosyasıdır;
  düzeni `HomeGovde` + paylaşılan bölüm widget'ları kurar.

Rol → varyant eşlemesi **tek fonksiyondadır**: `homeVaryantForRole`
(`home/domain/home_varyant.dart`). Eşleşmeyen/eksik rol (`unknown`) için
güvenli varsayılan **görevli** düzenidir. `admin` → yönetici varyantı
(`YoneticiHomeScreen(role: admin)`).

### Tasarım token'ları

Tüm renk/ölçü/tipografi `lib/src/core/theme/home_tokens.dart` içinde; ekranlarda
ve bölüm widget'larında **ham değer yazılmaz**.

| Token | Değer |
|---|---|
| primary / green / orange / purple / red | `#2563EB` / `#16A34A` / `#F59E0B` / `#8B5CF6` / `#EF4444` |
| arka plan / kart / ayraç | `#F4F6FA` / `#FFFFFF` / `#F1F2F6` |
| metin: başlık / gövde / ikincil | `#111827` / `#374151` / `#6B7280` |
| kart | radius 16, gölge yok + %4 siyah 1px kenarlık |
| ikon konteyneri | 56×56, radius 14, tint (%12) zemin, 26px ikon |
| chip | radius 8, tint zemin + accent metin, 11px semibold |
| FAB | 56px, alt bar'ın 18px üstüne taşar |

Vurgu renkleri iki temada da aynıdır; yüzey/metin renkleri `HomeSurface.of(context)`
ile **koyu moda** çözülür (ana ekran koyu temada da okunur).

### Veri kuralı (tek cümle) — UYDURMA SAYI YOK

> **Ekrandaki her sayı gerçek bir uçtan gelir; karşılığı olmayan kart sayı
> yerine "Yakında" (ya da "—") gösterir.**

`MockHomeRepository` (`home/data/home_repository.dart`) artık **veri taşımaz**;
yalnızca referans görsellerin *düzenini* (ikon / başlık / accent renk / sıra /
rota) ve sözleşmede karşılığı olmayan kartların "Yakında" etiketini tutar. Her
kartın sayacı `null` başlar:

| Durum | Kartta görünen |
|---|---|
| Veri yükleniyor | nötr iskelet çubuğu (`HomeSayacIskeleti`) — düzen kaymaz |
| Veri geldi | gerçek değer |
| Uç hata verdi (403/500/offline) | `—` |
| Sözleşmede karşılığı yok | `Yakında` (gri) + kartın rotası yok |

Bölümler (Ödeme ve Aidat Durumu / Son Hareketler / Duyurular) için aynı kural
bölüm ölçeğinde uygulanır: yüklenirken iskelet kart, hatada **"Yüklenemedi" +
"Yeniden dene"** (`HomeBolumHatasi`). Hiçbir bölüm boş beyaz kalmaz, hata
uygulamayı düşürmez.

> Riverpod hatalı bir sağlayıcıyı otomatik yeniden dener ve bu sırada durumu
> tekrar `AsyncLoading` olur; düz `when(...)` hata dalını hiç çalıştırmaz. Bu
> yüzden ekranlar `home_async.dart` içindeki `durum(...)` uzantısını kullanır —
> sıralama **veri → hata → yükleme**'dir.

### Ana ekran veri eşlemesi (UI alanı → uç)

Kaynak: `contracts/openapi.yaml` (salt okunur). **Sözleşme boşluğu (MISSING)
kalmadı:** G1–G7 backend'de kapandı (`bf1dc84`) ve bu tur ile mobil tarafa
bağlandı — ana ekranda artık "Yakında" gösteren hiçbir kart/kutu yok.
Tarihçe ve backend'in bilinçli sapmaları için → **[G1–G7 kapanış notları](#g1g7-kapanış-notları-sözleşme-boşlukları-kapandı)**.

**Ortak (üç ekran)**

| UI alanı | Uç → alan |
|---|---|
| "Merhaba, {ad}" | `GET /me/profile` → `ad` |
| Başlık hava bloğu | `GET /weather` → `sicaklik_c` / `durum` / `konum_ad` (G7 ile sözleşmeye yazıldı) |
| Zil / sekme okunmamış rozeti | `GET /notifications?okundu=false&limit=1` → `meta.total` (RBAC: admin+yönetici+security; sakin/tesis görevlisinde rozet **yok**) |

**Görevli (security) — `gorevli.jpeg` düzeni, artık 4'LÜ IZGARA**

| UI alanı | Uç → alan |
|---|---|
| Alt başlık "Mavi Residence ⌄" | `GET /tenant/settings` → `ad` (yoksa satır çizilmez) |
| "Vardiya Durum → N Aktif" | `GET /shifts` → o an aktif vardiya sayısı (istemcide `aktifMi(now)`) |
| "Kargo → N Bekliyor" | `GET /kargo` → `durum='bekliyor'` sayısı |
| "Ziyaretçi → N İçeride" | `GET /visitors?icerde=true&limit=1` → `meta.total` — G3 |
| "Araç Plaka → N Giriş" | `GET /vehicle-passes?baslangic=<yerel gün başı>&limit=1` → `meta.total` — G1 |
| "İhlaller → N Yeni" | `GET /violations?durum=yeni&limit=1` → `meta.total` — G2 |
| "Görevlerim → N Bekliyor" | `GET /tasks?aktif=true&limit=1` → `meta.total` (sunucu saha görünürlüğünü kendi uygular: rol grubuna atanan + atanmamış) |
| "Demirbaş → N Zimmetli" | `GET /assets?checked_out_by=me&limit=1` → `meta.total` (üzerimdeki açık zimmet) |
| "Turlarım → Devriye" | bölüm etiketi (devriye ekranı kendi durumunu gösterir) — sayaç değil |
| Vardiya Durumu şeridi | `GET /shifts` (+ `personel[]` avatar/sayı) + son kart `GET /yonetici-iletisim` → `yoneticiler[0].ad_soyad` |
| Son Hareketler | `GET /activity?limit=5` (G5) — **tek uç**; sunucu birleştirir/sıralar/rol süzer (tesis_gorevlisi yalnız `gorev_tamamlama` görür) |
| Canlı Kamera şeridi | `GET /cameras` → `ad` / `konum` / `stream_url` / `tur` / `oynatilabilir` (liste **sunucuda rol-süzgeçli**) |
| Gönderim Kuyruğu (koşullu) | yerel outbox (uç değil) — `pending>0` iken 9. hücre |

**Tesis görevlisi — KENDİ 4'lü ızgarası (KVKK)**

Ziyaretçi/kargo/plaka/ihlal kartları **yok** (bu rolün uçları 403 döner; kart
kalıcı `—` gösterirdi). Kart seti yalnız rolün çağırabildiği uçlardan:

| UI alanı | Uç → alan |
|---|---|
| "Vardiya Durum → N Aktif" | `GET /shifts` |
| "Görevlerim → N Bekliyor" | `GET /tasks?aktif=true&limit=1` → `meta.total` |
| "Demirbaş → N Zimmetli" | `GET /assets?checked_out_by=me&limit=1` → `meta.total` |
| "Talep / Arıza → N Açık" | `GET /complaints?durum=acik&limit=1` → `meta.total` (sunucu kendi taleplerine kısıtlar) |
| "Duyurular → N Yeni" | `GET /announcements` → son 3 günde yayınlananlar |
| "Etkinlikler → N Yaklaşan" | `GET /events?aktif=true&limit=1` → `meta.total` |
| "Site Kuralları → Kurallar" | bölüm etiketi — sayaç değil |
| "Yönetici → İletişim" | bölüm etiketi (`GET /yonetici-iletisim` ekranı) |
| Canlı Kamera şeridi | `GET /cameras` — sunucu bu role **yalnız `aktif && sakin_gorebilir`** kameraları döner |

**Site sakini — `site-sakini.jpeg`**

| UI alanı | Uç → alan |
|---|---|
| Alt başlık "Daire X • Kat Maliki" | `GET /me/dues` → `items[].no` |
| "Ziyaretçiler → N Kayıt" | `GET /visitors` (sunucu yalnız kendisine hedeflenenleri döner) |
| "Kargolarım → N Bekliyor" | `GET /kargo` → `durum='bekliyor'` |
| "Aidat Bilgileri → ₺X / Borç Yok\|Var" | `GET /me/dues` → `bakiye_kurus` (borç varsa borç, yoksa `toplam_tahakkuk_kurus`) |
| "Gürültü Şikayeti → N Açık" | `GET /unit-complaints/mine?kategori=gurultu&durum=acik&limit=1` → `meta.total` (G6; kategori süzgeci **sunucuda**) |
| "Geri Bildirim → N Açık" | `GET /complaints?durum=acik&limit=1` → `meta.total` (sunucu kendi taleplerine kısıtlar) |
| "Şikayetlerim → N Açık" | `GET /unit-complaints/mine?durum=acik&limit=1` → `meta.total` |
| "Duyurular → N Yeni" | `GET /announcements` → son 3 günde yayınlananların sayısı |
| "Site Raporları → Aylık Özet" | bölüm etiketi (şeffaflık ekranı) — sayaç değil |
| Ödeme kartı: Bu Ayki Aidat / Ödendi / Son Ödeme / Gelecek Ödeme | `GET /me/dues` → `assessments[]` (son dönem `tutar_kurus`, `son_odeme_tarihi`) + `payments[]` (`durum='basarili'`) + `bakiye_kurus` |
| Son Hareketler | `GET /activity?limit=5` (G5) — sunucu sakini yalnız kendi/dairesinin olaylarıyla sınırlar |
| Duyuru kartı | `GET /announcements` → en yeni kayıt (`baslik`, `govde`, `created_at`, `foto_url`); 3 günden yeniyse "Yeni" çipi |
| **"Site Kuralları" bölümü** (3 kayıt) | `GET /site-rules?limit=3` → `baslik` / `icerik` / `foto_url` (görsel yoksa yer tutucu); "Tümünü Gör" → kural listesi |
| **"Etkinlikler" bölümü** (3 kayıt) | `GET /events?aktif=true&limit=3` → `baslik` / `konum` / `aciklama` / `tarih` / `foto_url`; çip **Sürüyor** (yeşil, `tarih<now<bitiş`) veya **Yaklaşan** (mavi). Satıra dokunma → `/etkinlik?etkinlik_id=` (detay + görsel) |

**Yönetici / admin — `yonetici.jpeg`**

| UI alanı | Uç → alan |
|---|---|
| "Vardiya Durumu → N Aktif" | `GET /shifts` |
| "Görevler → N Bekliyor" | `GET /tasks?aktif=true&limit=1` → `meta.total` |
| "Aidat Durumu → N Daire" | `GET /reports/financial-summary` → `tahsilat.geciken_daire_sayisi` |
| "Otopark Kullanımı → dolu / kapasite" | `GET /parking/occupancy` → `dolu` + `kapasite` (G4; kapasite yoksa "N araç" — aşağıdaki kurala bakın) |
| "İhlaller → N Yeni" | `GET /violations?durum=yeni&limit=1` → `meta.total` (G2) |
| "Geri Bildirim → N Açık" | `GET /complaints?durum=acik&limit=1` → `meta.total` |
| "Şikayetler → N Açık" | `GET /unit-complaints?durum=acik&limit=1` → `meta.total` |
| "Raporlar → Aylık Özet" | bölüm etiketi — sayaç değil |
| Vardiya Durumu şeridi | `GET /shifts`; son kart oturumun kendi adı (`/me/profile`) |
| Hızlı Özet "Toplam Daire" | `GET /units?aktif=true&limit=1` → `meta.total` · **dokunma → Bina Düzenleme** (blok/kat/daire listesi) |
| Hızlı Özet "Toplam Tahsilat" | `GET /reports/financial-summary` → `tahsilat.tahsilat_kurus` · **dokunma → Finansal Özet** |
| Hızlı Özet "Aidat Tahsilat Oranı" | ↑ aynı yanıt → `tahsilat.tahsilat_orani_yuzde` (null ise "—") · **dokunma → Finansal Özet** |
| Hızlı Özet "Otopark Doluluk" | ↑ **aynı yanıt** (tek istek) → `oran` ("%2"); `oran` null ise "—". **Dokunma hedefi YOK** — mobilde araç geçişi/otopark ekranı henüz yok; dokunma "yakında" bildirimi verir (uydurma bir hedefe yönlendirilmedi) |
| Son Hareketler | `GET /activity?limit=5` (G5) — sunucu süzer; **yönetim bu akışta ziyaretçi/kargo olaylarını görmez** (KVKK, aşağıya bakın) |

Sayaç sorguları `?limit=1` ile atılır ve yalnız `meta.total` okunur (sayfa
verisi taşınmaz) — `home/data/home_api.dart`. Birleşik akış ayrı bir dosyadadır:
`home/data/activity_api.dart`.

**Otopark: `kapasite = null` render kuralı.** `GET /parking/occupancy` kapasite
tenant ayarında tanımsız (ya da 0) iken `kapasite` **ve** `oran` alanlarını
`null` döner; `dolu` her zaman gerçek sayıdır. Mobil bu durumda:

| Alan | kapasite VAR | kapasite `null` |
|---|---|---|
| İzgara kartı "Otopark Kullanımı" | `3 / 120` | `3 araç` (payda uydurulmaz) |
| Hızlı Özet "Otopark Doluluk" | `%2` | `—` (yüzde uydurulmaz) |

Kart hiçbir durumda çökmez ve **uydurma kapasite/yüzde göstermez**
(`home/domain/parking_occupancy.dart` → `doluMetni` / `oranMetni`).

**Sayacı olan ama ekranı olmayan kartlar.** "Araç Plaka", "İhlaller" ve
"Otopark Kullanımı" gerçek sayacı gösterir ama mobilde henüz liste/detay
ekranları yoktur → `rota == null`, dokunulunca "Bu bölüm yakında" bildirimi
çıkar. Sayaç gerçektir, eksik olan **ekran**dır.

### G1–G7 kapanış notları (sözleşme boşlukları KAPANDI)

Bu bölüm eskiden **CONTRACT GAPS** listesiydi: yedi kart/bölüm için uç yoktu ve
ekranda "Yakında"/"—" duruyordu. Backend hepsini kapattı (`bf1dc84`,
`contracts/openapi.yaml`), mobil de bu tur ile gerçek uçlara bağlandı. Aşağıda
**ne bağlandı** ve backend'in taslak öneriden **bilinçli sapmaları** durur —
sapmalar mobil tarafta neyi değiştirdiği için önemlidir.

| # | Konu | Bağlanan uç | Kart / bölüm |
|---|---|---|---|
| G1 | Araç geçişi | `GET /vehicle-passes?baslangic=&acik=&plaka=` | görevli şeridi "Araç Plaka → N Giriş" |
| G2 | İhlal kaydı | `GET /violations?durum=yeni` | görevli + yönetici "İhlaller → N Yeni" |
| G3 | Ziyaretçi çıkışı | `GET /visitors?icerde=true` (+ `POST /visitors/{id}/checkout`) | görevli "Ziyaretçi → N İçeride" |
| G4 | Otopark | `GET /parking/occupancy` | yönetici kartı + Hızlı Özet kutusu (**tek istek**) |
| G5 | Birleşik akış | `GET /activity?limit&cursor` | üç ekranda "Son Hareketler" |
| G6 | Gürültü sayacı | `GET /unit-complaints/mine?kategori=gurultu&durum=acik` | sakin "Gürültü Şikayeti → N Açık" |
| G7 | Sözleşme geri-doldurması | `/weather` + `/cameras` artık `openapi.yaml`'da | başlık hava bloğu + Canlı Kamera |

**Backend'in bilinçli sapmaları (mobili etkileyenler)**

1. **G1 tek-satır geçiş modeli.** Taslak `yon=giris|cikis` ile iki satır
   öneriyordu; sözleşme tek satır tutar (`giris_zamani` dolu, `cikis_zamani`
   null → **araç içeride**). Sonuç: `yon` parametresi **yok**; "içeride"
   sayısı `?acik=true`, "bugün N giriş" ise `?baslangic=<gün başı>` ile alınır.
   Mobil şerit kartı **bugünkü giriş akışını** ("N Giriş") gösterir; anlık
   iceride sayısı zaten otopark doluluğu olarak yöneticide durur — aynı sayıyı
   iki kartta tekrarlamamak için bu ayrım seçildi.
2. **G5: yönetim akışta ziyaretçi/kargo görmez.** `/visitors` ve `/kargo`
   yönetim rollerine **varsayılan kapalı**dır (daire bazlı tek-seferlik izinle
   açılır); birleşik akış o kapıyı bypass eden yan kanal olmamalı (KVKK). Mobil
   bu olayları admin/yönetici için **istemcide geri eklemez** — sunucu ne
   gönderirse doğrudur.
3. **G5 imleç, offset değil.** `offset` araya giren kayıtta sayfayı kaydırıp
   olay tekrarlatır; `meta.total` de yoktur (13 kaynağın birleşik sayımı her
   istekte tam tarama). "Daha var mı" bilgisi `meta.next_cursor != null`
   iledir. İmleç **opaktır** — istemci ayrıştırmaz, aynen geri gönderir
   (`ActivityApi.sayfa(cursor:)`).
4. **G4 `dolu` ayrı sayaç değil.** Doluluk açık geçişlerin `COUNT`'udur; sayım
   ile kayıt asla ayrışamaz. Kapasite tanımsızsa `kapasite` **ve** `oran` null
   gelir → yukarıdaki `kapasite = null` render kuralı.

**Son Hareketler: istemci birleştirmesi KALDIRILDI**

Eski hâl: rol başına 3–4 uç + istemcide `sort` + `take(5)`
(`domain/son_hareketler.dart`, ~240 satır + testleri). Yeni hâl: tek uç, tek
eşleme. Satır metinleri (`baslik`, `alt_metin`) **sunucudan** gelir; istemci
yalnız ikon + modül rengi + zaman etiketi ekler, nokta rengini de sunucunun
`renk_ipucu` alanından alır (durum **tahmin etmez**).

Olay türü (`tur`) tanınmıyorsa (sunucu ileride tür eklerse) satır **düşmez**:
nötr zil ikonuyla çizilir — "hiçbir şey olmadı" yalanı üretilmez.

Ana ekran istek sayısı (seed verisiyle, rol başına):

| Rol | Önce | Sonra | Not |
|---|---|---|---|
| görevli (security) | 11 | 12 | akış 2 uç → 1; **+2** yeni sayaç (plaka, ihlal); `/visitors` tam liste → `?icerde=true&limit=1` |
| görevli (tesis_gorevlisi) | 6 | 6 | akış `/task-completions` → `/activity` |
| yönetici / admin | 13 | 12 | akış 4 uç → 1; **+2** yeni sayaç (ihlal, otopark) |
| sakin | 9 | 10 | akış 1 ek uç → 1; **+1** yeni sayaç (gürültü) |

Kazanç istek **sayısında** değil doğrulukta ve taşınan veride: kronoloji
sunucuda, sayfalama imleçle mümkün, ve dört yeni kart artık gerçek sayı
gösteriyor (önce hiç veri yoktu). Akış artık üç ekranda **tek** sağlayıcıdır
(`sonHareketlerProvider`), rol parametresi yoktur.


### Kamera oynatıcı + kamera yönetimi (WP-I)

**Paket kararı: `video_player` tek başına — `chewie` EKLENMEDİ.**
`video_player` Flutter takımının paketidir ve HLS'i **platform oynatıcısıyla**
çalar (Android ExoPlayer, iOS AVPlayer) — ek yapılandırma gerekmez. `chewie`
hazır bir kontrol çubuğu getirirdi ama (a) ihtiyacımız olan kontrol seti küçük
(oynat/durdur + hata + yeniden dene + yatay), (b) kendi materyal tasarım dilini
dayatıp onaylanmış ana ekran diline yabancı bir görünüm katıyor, (c) ek bağımlılık
yüzeyi. Bu yüzden ince bir oynatıcı ekranı yazıldı:

| Durum | Ekran |
|---|---|
| Yükleniyor | ortada spinner (`Key('kamera-yukleniyor')`) |
| Hazır | video + **gövdenin tamamı dokunmatik** (oynat/durdur); duraklatınca büyük oynat ikonu |
| Hata | "Yayın açılamadı" + "Kamera kapalı olabilir ya da ağ yayına ulaşamıyor." + **Yeniden dene** (yeni controller kurar, eskisini atar) |
| Yatay | ekran açıkken landscape serbest, çıkışta eski yön kısıtı geri yüklenir |

Controller **her yolda** atılır (hata, erken çıkış, yeniden deneme) ve durum
değişimi `controller.addListener` ile dinlenir — platformdan gelen duraklama/
tamponlama da ekrana yansır. (`setState`'e `Future` dönen bir geri çağrım
vermek Flutter'da assertion hatasıdır; ilk sürümde bu vardı, test yakaladı.)

**RTSP:** sunucu `oynatilabilir=false` döner. Kart listede **kalır**, "Canlı"
yerine **"Oynatılamıyor"** yazar ve dokunma oynatıcı değil bilgi kartı açar
(ad/konum/tür + "RTSP yayınlar şu an uygulama içinde oynatılamıyor").

**Kamera yönetimi (admin + yönetici).** Kameralar ekranı 2'li ızgaradır (ana
ekran kart diliyle aynı `KameraKarti`); yönetim rollerinde FAB "Kamera Ekle" +
kart altında düzenle/sil. Form alanları sözleşmeyle birebir: Ad, Konum
(opsiyonel), **Tür (HLS/MP4/RTSP)**, Yayın URL'si, **Aktif**, **"Site sakinleri
görebilsin"**. İstemci doğrulaması sunucudaki 422 kuralının aynısıdır
(`hls`/`mp4` → `http(s)://`, `rtsp` → `rtsp://`) ve **tür değişince URL alanı
yeniden doğrulanır**; sunucu 422/409 dönerse mesaj **aynen** gösterilir. RTSP
seçilince satır-içi uyarı çıkar. Kaydetme sonrası `camerasProvider` invalidate
edilir → ana ekran şeridi ve ızgara **anında** tazelenir.

**Görünürlük istemcide TEKRARLANMAZ.** `GET /cameras` sunucuda rol-süzgeçlidir
(admin/yönetici/security tümü; resident/tesis_gorevlisi yalnız
`aktif && sakin_gorebilir`). Mobil hiçbir yerde `sakin_gorebilir=false`
kayıtlarını eleyen bir "sahte güvenlik" katmanı **çalıştırmaz** — gelen liste
çizilir (`test/kamera_yonetim_test.dart` bunu kilitler).

### Canlı veri yenileme — 4 tetikleyici (bayat sayaç hatası)

Ana ekran bir kez yüklenip bir daha sorulmuyordu ("53 daire" bir daire silindikten
sonra bile duruyordu). `home_refresh.dart` dört tetikleyiciyi tek bir yenileme
fonksiyonuna bağlar:

| # | Tetikleyici | Nasıl | Kapsam |
|---|---|---|---|
| 1 | Başka ekrandan **dönüş** | `RouteAware.didPopNext` (`homeRouteObserver` GoRouter'a `observers` ile takılı) | tam |
| 2 | Uygulama **ön plana** | `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` | tam |
| 3 | **Aşağı çekip** yenileme | `HomeGovde.onYenile` → `RefreshIndicator` (üç varyantta da bağlı) | tam |
| 4 | **Periyodik** yumuşak yenileme | `Timer.periodic(45 sn)` — ana ekran görünürken | yalnız sayaç + akış |

* **Yumuşak** kapsam sayaçlar + `/activity`'dir: video yok, ağır liste yok.
* Zamanlayıcı arka planda **durur** (`paused/inactive`) ve üstüne ekran açılınca
  da durur (`didPushNext`), dönüşte yeniden başlar → pil/veri.
* **Titreme yok:** yenileme `ref.invalidate` iledir; Riverpod yeniden hesaplarken
  önceki değeri korur (`hasValue` true kalır) ve `durum()`/`sayac()` yardımcıları
  veriyi önce okur — **iskelet yalnız ilk yüklemede** görünür.
* Rol başına yenilenen sağlayıcı kümesi `_sayacProviderlari()` /
  `_tamProviderlar()` içinde tek yerdedir; dinleyicisi olmayan `autoDispose`
  sağlayıcıyı invalidate etmek istek üretmez (fazladan trafik yok).

### 4'lü ızgara düzenleri (rol başına)

| Rol | Izgara | Kartlar |
|---|---|---|
| security | 4×2 (8 kart) | Vardiya Durum · Kargo · Ziyaretçi · Araç Plaka · İhlaller · **Görevlerim** · **Demirbaş** · **Turlarım** |
| tesis_gorevlisi | 4×2 (8 kart) | Vardiya Durum · Görevlerim · Demirbaş · Talep / Arıza · Duyurular · Etkinlikler · Site Kuralları · Yönetici |
| resident | 4×2 (8 kart) | (değişmedi) |
| yönetici/admin | 4×2 (8 kart) | (değişmedi) + **Hızlı Özet kutuları artık tıklanabilir** |

Görevli ekranındaki **yatay 5'li şerit kaldırıldı**: aynı kart tipi/ölçüsüyle
yönetici ızgarasına hizalandı. Gerekçe: şerit 5 kartta sabitti, "Görevlerim"/
"Demirbaş"/"Turlarım" gibi günlük işler yalnız çekmecede duruyordu; ızgara 8
kartı tek ekranda ve dengeli iki satırda verir. `pending>0` iken "Gönderim
Kuyruğu" 9. hücre olarak eklenir (çevrimdışı kanıt görünür kalsın).

**Kart eklenirken kural:** bir kart YALNIZ rolün çağırabildiği bir uca
bağlanıyorsa eklenir. Tesis görevlisi ızgarasında ziyaretçi/kargo/plaka/ihlal
kartı yoktur — o uçlar bu role 403 döner ve kart kalıcı olarak `—` gösterirdi.

### Tasarımda kalan yer tutucular (uç gerektirmez)

| Alan | Not |
|---|---|
| **Duyuru görseli** | `foto_url` boşsa gri yer tutucu çizilir |
| **Canlı kamera karesi** | kart içinde video **oynatılmaz**; 16:10 yer tutucu + oynat butonu, dokunma mevcut oynatıcı ekranına gider |

### Referans düzenden bilinçli sapmalar

1. **Marka adı.** Referans görsellerdeki kelime işareti "YÖNETİYOR"dur (hazır
   mockup markası). Ürünün gerçek adı **Yönetio**'dur ve launcher ikonu, splash,
   admin-web ve android kaynakları buna bağlıdır; mockup metnini kopyalamak ürünü
   kendi markasından koparırdı. **Dizilim** (kalkan işareti + kelime işareti +
   harf aralı "GÜVENLİK & DANIŞMANLIK" alt başlığı) görselle birebir, **kelime
   işareti** gerçek markadır.
2. **"Tüm Modüller" → hamburger çekmecesi.** Referans ana ekranlarda hızlı erişim
   8 (görevlide 5) sabit karta indi. Kalan modüller (Turlarım, Görevlerim,
   Demirbaş, Rezervasyon, Entegrasyonlar…) erişilebilir kalsın diye **app-bar'daki
   hamburger menüye** taşındı (`HomeDrawer`). Görünürlüğün tek kaynağı yine
   `homeMenuForRole`.
3. **Gönderim Kuyruğu kartı.** Referans şeritte yok; ancak bekleyen çevrimdışı
   okutma varken (`pending > 0`) saha şeridine **ek bir kart** girer — çevrimdışı
   saha kanıtı ana ekrandan kaybolmasın diye. `pending = 0` iken (normal durum)
   şerit referansla birebir 5 karttır.
4. **İkon konteyneri ölçeği.** Spesifikasyondaki 56×56 kutu, 4 sütunlu izgarada
   hücre ~83dp'ye düştüğü için kartı boğuyordu; izgarada kutu **hücre
   genişliğinin ~%42'sine** ölçeklenir (referans görseldeki ikon/kart oranıyla
   aynı), şeritte spesifikasyon değeri korunur.
5. **Şerit kart genişliği.** Spesifikasyon ~110dp der; referans görselde 5 kartın
   tamamı ekrana sığar — telefon genişliğinde ikisi aynı anda sağlanamaz
   (5×110 + boşluklar ≈ 610dp). Şerit **~4.5 kart görünecek şekilde** ölçeklenir
   (min 84dp, geniş ekranda 110dp) ve kaydırılabilir kalır.
6. **İzgara hücreleri referanstan bir miktar uzun.** "Otopark Kullanımı" gibi
   Türkçe başlıklar telefon genişliğinde iki satıra sarıyor; taşma üretmemek için
   hücre oranı 0.70'tir.
7. **Sakin bildirim rozeti yok.** Referansta zilde "3" rozeti var; `/notifications`
   backend RBAC'inde sakine kapalı olduğu için sakin ekranında rozet gösterilmez
   (uydurma sayı yerine yokluk).

### Öz-denetim ekran görüntüsü üretimi

Üç ekranın PNG çıktısı — referans görsellerle yan yana karşılaştırmak için:

```bash
flutter test --dart-define=HOME_GOLDEN=true --update-goldens \
  test/tools/home_referans_golden_test.dart
# → test/tools/goldens/{gorevli,site_sakini,yonetici}.png
```

Bu bir regresyon testi **değildir** (font/Skia sürümüne duyarlı): normal
`flutter test` koşusunda atlanır, çıktılar git'e girmez.

### Dosya haritası

```
core/theme/home_tokens.dart              tasarım token'ları (tek kaynak)
features/home/
  domain/home_varyant.dart               rol → referans düzen eşlemesi
  domain/home_view_models.dart           bölümlerin saf görünüm modelleri
  domain/home_tabs.dart                  alt-bar yuvaları (aktif/pasif ikon)
  domain/home_menu.dart                  rol → modül görünürlüğü (değişmedi)
  domain/activity_models.dart            GET /activity öğe/sayfa modelleri (imleç)
  domain/parking_occupancy.dart          GET /parking/occupancy + "kapasite null" metinleri
  data/home_repository.dart              düzen tabanı (ikon/başlık/renk/sıra/rota)
  data/home_api.dart                     sayaç sorguları (?limit=1 → meta.total)
  data/activity_api.dart                 "Son Hareketler" tek uç + tek sağlayıcı
  presentation/home_refresh.dart         canlı veri: 4 tetikleyici + invalidate kümeleri
  presentation/home_gate.dart            rol yönlendirme
  presentation/home_async.dart           AsyncValue → veri/hata/iskelet (retry-dayanıklı)
  presentation/home_mappers.dart         gerçek API → görünüm modeli
  presentation/{saha,resident,yonetici}_home_screen.dart   veri kablolaması
  presentation/widgets/
    home_shell.dart      app-bar (hamburger+marka+zil+avatar) + taşan FAB'lı alt bar
    home_drawer.dart     hamburger çekmecesi: rolün tüm modülleri
    home_marka.dart      marka kilidi
    home_govde.dart      karşılama + sıralı bölümler
    home_header.dart     "Merhaba, X" + rol alt satırı + hava
    home_card.dart       beyaz kart, tint ikon kutusu, chip, nokta
    section_header.dart  bölüm başlığı + "Tümünü Gör ›"
    hizli_erisim.dart    yatay şerit (görevli) + 4×2 izgara (sakin/yönetici)
    vardiya_seridi.dart + shift_status_card.dart   "Vardiya Durumu"
    stat_tile.dart       "Hızlı Özet" kutuları + izgarası
    son_hareketler_karti.dart + activity_row.dart  tek kart, 1px ayraçlı satırlar
    icerik_bolumu.dart   sakin "Site Kuralları"/"Etkinlikler" bölümleri (görsel + çip)
    kamera_seridi.dart   "Canlı Kamera" şeridi (kart: features/cameras/.../kamera_karti.dart)
    odeme_karti.dart     "Ödeme ve Aidat Durumu" iki sütun
    duyuru_karti.dart    duyuru kartı (96×72 görsel + "Yeni" çipi)
    kamera_seridi.dart   "Canlı Kamera" 16:10 yer tutucu şeridi
    home_states.dart     iskelet çubuğu + bölüm iskeleti + "Yüklenemedi"/yenile
```

## 15. Çoklu dil (i18n) — 7 dil + RTL

**Durum:** altyapı **tam**; çevrilen modüller: **Ayarlar**, **Kameralar**, ortak
durum metinleri (tur 1), **Ana ekran (home)** (tur 2 — üç rol varyantı, hızlı
erişim ızgarası, Hızlı Özet, son hareketler/duyuru/etkinlik kartları, kabuk +
çekmece + modül adları), **Görevler + Devriye** (tur 3 — liste/detay/form,
kategori yönetimi, foto-kanıtı ve NFC akış metinleri, tur pencereleri, plan
formu, tarama günlüğü), **Bina (şema + düzenleme) + Talep/Arıza** (tur 4 —
blok/kat/daire yerleşimi, toplu daire ekleme, yoğunluk göstergesi, daire
şikayet formu, talep sekmeleri/detay/durum geçmişi, iş emrine dönüştürme) ve
**Rezervasyon + Etkinlik + Görüntüleme izni** (tur 5 — ortak alan/slot ızgarası,
alan formu, RSVP akışı, etkinlik formu, izin isteği/onayı + tek-seferlik kayıt
görüntüleme) **Bütçe + Demirbaş + Kargo** (tur 6 — bütçe özeti/hareketler/
kategoriler, finansal özet, sakin "Site Bütçesi" şeffaflık ekranı, NFC zimmet
akışı + üzerimdekiler, kargo listesi/detay/kayıt formu) ve **Site Kuralları +
Duyurular + Site Sakinleri** (tur 7 — kural listesi/arama/detay/form, duyuru
kartı/menüsü/formu + tam ekran görsel, sakin listesi/ekle/düzenle/parola
sıfırlama ve ortak **geçici kod dialogu**). Kalan modüllerin dışa alımı mekanik
bir iştir ve aşağıdaki envanterle sürdürülür — bkz. "Kalan iş".

### Mimari

| Parça | Yer |
|---|---|
| ARB kaynakları (7 dil) | `lib/l10n/app_{tr,en,ar,ru,de,fr,es}.arb` (**797 anahtar × 7**, boşluk yok) |
| gen-l10n yapılandırması | `l10n.yaml` (şablon: `app_tr.arb`) |
| Üretilen sınıf | `lib/l10n/gen/app_localizations.dart` (**repoda tutulur** → taze klonda `analyze`/`test` ek adım istemez; yenilemek için `flutter gen-l10n`) |
| Dil seçimi + kalıcılık | `lib/src/core/i18n/locale_controller.dart` (`AppDil`, `LocaleController`, `ui.locale` anahtarı — tema ile aynı güvenli depo) |
| Ergonomi + biçimlendirme | `lib/src/core/i18n/l10n.dart` (`context.l10n`, `tlIsaretli`, `tlSonEkli`, `tarihBicimi`, `baslikBuyuk`, `ltrIzole`) |
| Uygulama bağlaması | `lib/main.dart` (`localizationsDelegates`, `supportedLocales`, `localeResolutionCallback`) |
| Açılış ön-okuması | `lib/src/core/startup/acilis_tercihleri.dart` — dil + tema `runApp`'ten **önce** okunur, `acilisTercihleriProvider` ile tohumlanır |
| Dil seçici | Ayarlar → "Dil / Language" (alt sayfa, 7 dil kendi adıyla) |

**Dil çözümleme sırası:** kullanıcı seçimi (kalıcı) → cihaz dili (destekleniyorsa;
ülke kodu yok sayılır, `en_US → en`) → **Türkçe**. Seçim **anında** uygulanır
(uygulama yeniden başlamaz) ve kalıcıdır.

> **Dikkat (davranış değişikliği):** seçim yapılmamışsa uygulama artık **cihaz
> dilini** izler. Türkçe olmayan bir telefonda arayüz İngilizce/Almanca… açılır.
> Bilinçli tasarım kararıdır; Türkçe'ye sabitlemek isteyen kullanıcı Ayarlar →
> "Dil / Language" ile seçer.

**İlk kare doğru dilde boyanır.** Dil ve tema tercihi `runApp`'ten **önce**
okunur (`acilisTercihleriniOku`) ve denetleyicilere tohumlanır. Eskiden bu
okuma asenkron yapıldığı için ilk kare varsayılan dille (cihaz dili) çizilip
hemen yenileniyordu — görünen **metin titremesi** buydu. Regresyon testi:
`test/acilis_dil_titremesi_test.dart` (eski davranış da ölçülür; ikisinin farkı
kusurun kaydıdır). Yeni bir açılış ekranı **eklenmedi**; tek depo okuması
platformun kendi açılış ekranında geçer.

**Eksik çeviri derlemeyi kırmaz:** gen-l10n şablon (TR) değerine düşer.

### Bir metin nasıl eklenir (ARB akışı)

1. `lib/l10n/app_tr.arb`'ye anahtarı yaz (gerekiyorsa `@anahtar` altında
   `description` + `placeholders`).
2. Diğer 6 ARB'ye çevirisini ekle (`app_en/ar/ru/de/fr/es.arb`).
3. `flutter gen-l10n` → `AppLocalizations` yenilenir.
4. Kodda `context.l10n.anahtar` (veya parametreliyse `context.l10n.anahtar(x)`).
   **String birleştirme yok**: sayı/isim geçen metinler ICU placeholder/plural
   ile yazılır.

Her ARB'nin başında `@@x-glossary` bloğu vardır: aidat=dues, vardiya=shift,
devriye=patrol, checkpoint, demirbaş/zimmet=asset/checkout, daire=unit,
blok=block, sakin=resident... Çeviriler bu terminolojiye uyar (native gözden
geçirme öncesi tutarlılık şartı).

### ICU çoğul (ru/ar)

Sayaç metinleri çoğul kategorileriyle yazılır; `ru` (one/few/many) ve `ar`
(zero/one/two/few/many) davranışı `test/i18n_test.dart` ile kilitlidir:
`1 ожидает` · `3 ожидают` · `11 ожидают` · `21 ожидает` /
`لا شيء بالانتظار` · `عنصر واحد` · `عنصران` · `عناصر` · `عنصراً`.
Türkçe/Almanca/Fransızca/İspanyolca tek biçim kullanır (sayıdan sonra çoğul eki
yok) — bu **bilinçli**, dilbilgisi gereği.

### RTL (Arapça)

* Yön `Directionality` ile gelir (`MaterialApp.locale=ar` → RTL); chevron ve
  geri okları **kendiliğinden** aynalanır.
* Kenar boşlukları yön-duyarlı: `EdgeInsetsDirectional.fromSTEB` (dil seçici
  başlığı), hizalama `CrossAxisAlignment.start/end` — `left/right` kullanılmaz.
* **LTR izolasyon:** plaka, telefon, tutar gibi diziler RTL gövde içinde ters
  görünmesin diye `ltrIzole()` ile Unicode FSI/PDI (U+2068/U+2069) arasına
  alınır. `tlIsaretli()` bunu para için zaten uygular.
* Uygulanan düzeltmeler bu turda: dil seçici başlığı `EdgeInsetsDirectional`,
  dil adları kendi yönünde (`textDirection` per satır), kamera kartı/oynatıcı
  metinleri yön-nötr, para/tutar biçimleyici izolasyonlu. RTL denetimi
  `test/i18n_test.dart` içinde **Ayarlar** ve **Kamera formu** ekranlarında
  doğrulanır.

### Para ve sayı politikası (bilinçli)

> **Tutarlar UI dili ne olursa olsun ₺ ve Türkçe gruplamayla gösterilir**
> (`₺1.250,00`).

İki biçimleyici vardır: `tlIsaretli` (**₺ ön ekli**, kartlar) ve `tlSonEkli`
(**"TL" son ekli**, bütçe/finans ekranları — hareket satırlarında `onEk: '+'/'-'`
işaretiyle). Gruplama tek kaynaktan gelir (`tlTutar`); `budget_models.dart`
içindeki `formatKurusAsTl` bunun i18n-öncesi ikizidir ve henüz çevrilmemiş
şeffaflık panosunda durur — **çıktı eşitliği tur 6 testinde kilitlidir**.
Arapça'da tutar (işaretiyle birlikte) LTR izole edilir.

Gerekçe: para **site-yereldir** — aidat TL toplanır, dekont/İBAN TL'dir. Dile
göre `$`/`€` göstermek ya da `1,250.00` biçimi kullanmak muhasebeyle çelişir.
Tarih/saat ve ay/gün adları ise **aktif dile** göre biçimlenir
(`DateFormat.yMd(dil)`, `DateFormat.EEEE(dil)`).

Başlık BÜYÜK HARF kuralı da dile duyarlıdır (`baslikBuyuk`): `tr` için i→İ /
ı→I, **Arapçada büyük harf yoktur** (metin aynen), diğerlerinde standart.

### Sunucu metni sınırı — `SERVER-LOCALIZED(next round)`

Sunucudan gelen metinler bu turda **çevrilmez, olduğu gibi gösterilir**
(backend yerelleştirmesi ayrı tur). İşaretli sınırlar:

| Sınır | Dosya |
|---|---|
| Tüm API hata metinleri (422/409/503...) | `lib/src/core/error/api_exception.dart` (sınıf başı) |
| Akış satırları (`baslik`/`alt_metin`, 13 kaynak) | `lib/src/features/home/presentation/home_mappers.dart` → `hareketSatirlari` |
| Kamera listesi hata metni | `lib/src/features/cameras/presentation/kameralar_screen.dart` |
| Kamera formu 422 mesajı | `lib/src/features/cameras/presentation/kamera_form_sheet.dart` |

`ApiException.message` **66 dosyada** tüketilir (snackbar/hata kartı); tek sınır
işaretlenmiştir çünkü çeviri sunucuda çözülünce hepsi kendiliğinden düzelir —
`grep -rn "SERVER-LOCALIZED(next round)" lib/` ile bulunur, tüketici listesi
`grep -rln "e.message" lib/` ile üretilir.

### Kimlik / metin ayrımı — kart id refactor (ana ekran)

> **Kural:** alan katmanları (domain/data) **kimlik** döndürür, yerelleştirilmiş
> metin **çizim anında** çözülür. Kontrol akışında (`switch`, `if`, harita
> anahtarı) **metin kullanılmaz**.

Ana ekran kartları eskiden Türkçe başlığı hem ekranda gösteriyor hem de
`switch (k.baslik)` ile sayaç/rota eşleme **anahtarı** olarak kullanıyordu — dil
değişince yönlendirme bozulurdu. Artık:

| Kimlik | Yer | Metin çözümü |
|---|---|---|
| `HomeKartId` (27 kart) | `features/home/domain/home_kart_id.dart` | `kartBasligi(l10n, id)` |
| `HomeKartEtiketId` (sayaç değil, sabit alt etiket) | aynı dosya | `kartEtiketi(l10n, id)` |
| `OzetKutuId` ("Hızlı Özet" 4 kutu) | aynı dosya | `ozetEtiketi` / `ozetAltEtiketi` |
| `HomeMenuEntry` (çekmece/modül adları) | `presentation/module_card_spec.dart` | `moduleBaslik(l10n, entry)` |
| `taskKategoriStyle().ad` **(null = kategorisiz)** | `tasks/presentation/task_tip_style.dart` | `style.ad ?? l10n.gorevKategoriDiger` |
| `TaskOncelik` (düşük/orta/yüksek) | aynı dosya | `oncelikEtiketi(l10n, kimlik)` |
| `GorevAkisHatasi` / `DevriyeAkisHatasi` | `*/domain/*_hata.dart` | `gorevHataMetni` / `devriyeHataMetni` |
| `UserRole` (rol adları) | `auth/domain/user_role.dart` | `rolAdi(l10n, rol)` (`auth/presentation/rol_adi.dart` — tur 4'te tasks'tan taşındı: ikinci tüketici çıktı) |
| `DensityRenk` | `building_map/domain/building_map_models.dart` | **`label` alanı KALDIRILDI** (ölü TR metin; gösterge eşik sayısı yazar) |
| `UnitComplaintKategori` | `unit_complaints/domain/unit_complaint_models.dart` | `unitComplaintKategoriAdi(l10n, k)` |
| `TalepDurum` | `complaints/domain/complaint_models.dart` | `_durumLabel(l10n, durum)` |
| `AkisHatasi` (ortak) / `TalepAkisHatasi` | `core/error/akis_hatasi.dart` · `complaints/domain/talep_hata.dart` | `akisHataMetni` / `talepHataMetni` |
| `RezervasyonDurum` · `SlotSebep` | `rezervasyon/domain/rezervasyon_models.dart` | `rezDurumAdi` / `slotSebepAdi` (`rez_etiket.dart`) |
| `OrtakAlan.musaitlikOzeti` · `Slot.sebepEtiketi` | — | **ÜYELER KALDIRILDI** (domain metin üretmez); yerine `musaitlikOzeti(l10n, alan)` + `SlotSebep` kimliği |
| `KatilimDurum` | `etkinlik/domain/etkinlik_models.dart` | `katilimDurumAdi` (`etk_etiket.dart`) |
| `AccessRequestDurum` | `unit_access/domain/unit_access_models.dart` | `erisimDurumAdi` (`izin_etiket.dart`) |
| `KargoDurum` | `kargo/domain/kargo_models.dart` | `kargoDurumAdi` (`kargo/presentation/`) — çözücü tur 5'te (`unit_access` çizdiği için) eklendi, **`label` alanı tur 6'da KALDIRILDI** |
| `BudgetTip` | `budget/domain/budget_models.dart` | `butceTipAdi` (`budget/presentation/`) — **`label` alanı KALDIRILDI** |
| `DemirbasMesaj` (**sealed**) + `DemirbasMesajKimlik` | `assets/domain/demirbas_mesaj.dart` | `demirbasMesajMetni` (`assets/presentation/`) |

**Parametre taşıyan mesaj kimlikleri (tur 6).** Diğer modüllerde denetleyici
hatası tek bir `enum` + ayrı `errorMessage` alanıyla taşınıyordu. Demirbaş
mesajlarının bir kısmı **parametre** taşır (okutulan UID, çatışan demirbaşın
adı), bu yüzden `DemirbasMesaj` bir **sealed sınıftır**: kimlik ve parametreleri
birlikte tutar, `DemirbasSunucuMetni` de sunucu kanalını temsil eder. Denetleyici
hâlâ **metin üretmez**; `assets_screen` çizim anında çözer.

`switch`'lerin `default` dalı **yoktur**: yeni kart eklenince derleyici çeviriyi
zorlar. `ParkingOccupancy` gibi alan tiplerinden görüntü metni üreten üyeler
(`doluMetni`/`oranMetni`) kaldırıldı — ekran `l10n.otoparkDoluKapasite` ile
biçimler (`CameraUrlHatasi` emsali).

Doğrulama: `grep -rnE "(switch|case|==)\s*\(?\s*['\"][^'\"]*[çğıöşü…]" lib/src/features/home`
→ **boş**.

### Test kapsamı

`test/i18n_test.dart` (20 test): dil listesi/çözümleme, dil değiştirme
(tr→en→ar→ru ile örnek widget kümesi), "Language" bulunabilirliği, eksik
çeviri düşüşü, RTL yön + iki ekran denetimi, ICU çoğul (ru/ar/en/tr/de/fr/es),
para/tarih/büyük-harf kuralları, **kalıcılık** (seç → yeni `ProviderContainer`
= yeniden başlatma → aynı dil).

`test/uygulama_acilis_giris_test.dart` (7 test): **gerçek uygulama kökü**
(`TesisGuvenlikApp`/main.dart) ile soğuk açılış → giriş → rol ana ekranı
(yönetici/admin/security/resident) + kayıtlı dil (ar) altında aynı akış. Bu
dosyadan önce main.dart'ı çizen **hiçbir** test yoktu; i18n bağlaması tam orada
yaşadığı için açılış yolu kapsamsızdı.

`test/home_i18n_test.dart` (6 test): kart **kimliği** dilden bağımsız / başlık
dile bağlı (taban kartlar metin taşımaz), ana ekranda **tr→en→ru** dil
değiştirme (başlıklar + ICU sayaç metinleri değişir, düzen aynı kalır), bölüm
başlıkları + kamera şeridi, ve **RTL** denetimi: Arapça görevli ana ekranında
yön `rtl`, ızgara + son hareketler satırları çizilir, plaka `34 ABC 123` LTR
izolasyonlu kalır, uzun Arapça metinlerde ızgara **taşmaz**.

`test/tasks_patrol_i18n_test.dart` (8 test — tur 3): görev listesinde **tr→en→ru**
ve devriye planlarında **tr→de→ar** dil değişimi (metin çevrilir, düzen + sunucu
verisi aynı kalır), kategori **kimliğinin** dilden bağımsızlığı (renk/ikon sabit,
`ad` null = metin yok), denetleyici hata **kimliğinin** ekranda çevrilmesi, tüm
hata kimliklerinin 7 dilde karşılığı olduğu, ICU çoğul (ru one/few/many + ar
zero/one/two) ve **RTL**: Arapça **görev formu** ile **devriye plan formu**
(iki form-yoğun ekran) yön `rtl` çizilir, taşma yok, UID LTR izolasyonlu.

> **RTL denetiminin yakaladığı gerçek kusur:** Arapça çeviriler TR'den uzun
> olduğu için görev formunda iki yerde taşma vardı (yükleme satırı 4 px,
> "Atanan personel" açılır listesi 90 px). Düzeltme, kontrol noktası listesinde
> zaten kullanılan desendir: satırda `Expanded`, açılır listede `isExpanded`.
> Grep bunu **bulamazdı** — ölçüm metin sayar, yerleşim denemez.

`test/bina_complaints_i18n_test.dart` (9 test — tur 4): şemada **tr→en→ru**,
bina düzenlemede **tr→de**, taleplerde **tr→en→fr** dil değişimi (metin çevrilir,
düzen + sunucu verisi aynı kalır), `DensityRenk`/`UnitComplaintKategori`
kimliklerinin metin taşımadığı, denetleyici hata kimliğinin ekranda çevrildiği,
tüm hata kimliklerinin 7 dilde karşılığı olduğu ve **RTL**: Arapça şema,
bina düzenleme (toplu daire formu) ve yeni talep formu — yön `rtl`, taşma yok.

> **RTL/çeviri denetiminin yakaladığı gerçek kusur (tur 4):** daire detay
> başlığı `Daire {no}` + `Spacer()` + `{n} açık şikayet` düzeniydi; İngilizce
> ("6 open complaints") ve Rusça ("6 открытых жалоб") çeviriler TR'den uzun
> olduğu için **81 px taşıyordu** (TR'de sığıyordu, bu yüzden görünmemişti).
> Düzeltme: başlık `Expanded`, sayaç `Flexible` + `textAlign.end`, `Spacer`
> yerine sabit boşluk. Tur 3'teki bulgu (görev formu 4 px + 90 px) ile aynı
> desen: **grep taşmayı görmez, ölçüm metin sayar.**

`test/rez_etk_izin_i18n_test.dart` (10 test — tur 5): rezervasyonda **tr→en→ru**,
etkinlikte **tr→de**, izinde **tr→fr** dil değişimi; üç alan enum'unun metin
taşımadığı; `musaitlikOzeti`/`SlotSebep` çözücülerinin domain'den taşındığı;
ICU çoğul (ru/ar) katılım sayaçları; **çok-placeholder sıra kilidi** (yukarıdaki
sessiz hata sınıfı) ve **RTL**: Arapça rezervasyon alan formu, etkinlik formu ve
izin kartı — yön `rtl`, taşma yok.

`test/butce_demirbas_kargo_i18n_test.dart` (17 test — tur 6): bütçede
**tr→en→de**, demirbaşta **tr→en→ru**, kargoda **tr→en→es** dil değişimi;
`BudgetTip`/`KargoDurum` çözücülerinin 7 dilde karşılığı; `DemirbasMesaj`
kimlik + **parametre** çözümü ve sunucu kanalının olduğu gibi geçişi;
`tlSonEkli` ↔ `formatKurusAsTl` **çıktı eşitliği** + Arapça LTR izolasyonu;
çok-placeholder **sıra kilidi**; süre parçasının **edatı taşıması** (aşağıdaki
not) ve **RTL**: Arapça bütçe hareket formu, demirbaş durum kartı, kargo formu
ve kargo detayı — yön `rtl`, taşma yok. Ayrıca **320 dp dar ekran** senaryosu
(milyonluk bütçe + en uzun TR etiketler) aşağıdaki taşma düzeltmelerini kilitler.

> **Tur 6'nın çeviri tasarım kararı — cümleye giren PARÇA edatı taşır.**
> Demirbaş kartı "SENDE — {süre} üzerinde." kurar; `{süre}` = "3 saattir".
> İngilizce şablon "WITH YOU — {süre}." olur ve parça "for 3 hours" gelir.
> Edat **parçanın** içinde olmasa şablon her dilde ya iki kez ("for for
> 3 hours") ya hiç yazardı. `@demSende` bu kuralı ARB'de not eder.

> **Tur 7 RTL/dar-ekran taramasının bulguları — iki yön, bir taşma (×3 yer).**
> Yön: görsel-hatası şeridindeki `Alignment.centerLeft` (kural detayı ve duyuru
> kartı) Arapça'da yanlış kenara yapışıyordu → `AlignmentDirectional.centerStart`.
> Taşma: aynı şeritteki `Row(ikon + "Görsel yüklenemedi")` 320–360 dp'de satıra
> sığmıyordu (**Türkçe'de de**, 4,5–45 px) → metin `Expanded`. Aynı desen
> **kargo detayında da vardı**; tur 6 sondasında sahte kaydın `fotoUrl`'ü boş
> olduğu için errorBuilder hiç çizilmemiş ve bulunamamıştı — üçü birlikte
> düzeltildi ve `kural_duyuru_sakin_i18n_test.dart` içinde kilitlendi.
> **Ders:** sonda verisi *hata yollarını* da tetiklemelidir; yoksa tarama
> "temiz" görünür.

> **Tur 6 RTL/dar-ekran taramasının bulguları — üçü yön, üçü taşma.**
> Yön: `Alignment.centerRight` (tahsilat yüzdesi) ve `Alignment.centerLeft`
> (kargo görsel hatası) Arapça'da yanlış kenara yapışıyordu →
> `AlignmentDirectional.centerEnd/Start`. Taşma (320–360 dp): tutar kartında
> `trailing:` 7 haneli tutarla **tüm tile genişliğini tüketip ListTile'ı
> düşürüyordu**; hareket satırındaki "Otomatik" rozeti sabit genişlikteydi;
> kargo formunda "Paket fotoğrafı (opsiyonel)" satıra sığmıyordu. Düzeltmeler:
> etiket `Expanded` + ellipsis, tutar `Flexible` + `FittedBox(scaleDown)`,
> rozet `Flexible`, form etiketi `Expanded`. **Bu üç taşma Türkçe'de de
> oluşuyordu** (i18n kaynaklı değil, mevcut kusur); Arapça sadece iki satırda
> daha erken tetikliyordu. Tur 3/4 bulgularıyla aynı ders: **grep taşmayı
> görmez.**

`test/kural_duyuru_sakin_i18n_test.dart` (15 test — tur 7): kuralda
**tr→en→ru**, duyuruda **tr→en→fr**, sakinlerde **tr→en→es** dil değişimi;
boş-liste metninin **role göre** seçilip çevrilmesi; kullanıcı verisinin
(kural başlığı, sakin adı) **placeholder** olarak cümleye girmesi ve tırnakların
korunması; yazarı boş duyurunun "Yönetim" çevirisine düşmesi + "düzenlendi"
eki; `duyuruMeta` **sıra kilidi**; geçici kod dialogu metinlerinin 7 dilde
varlığı; **RTL** (kural formu, duyuru kartı+formu, sakin listesi+formu) ve
**320 dp** dar ekran senaryoları.

> **Tur 7'nin test altyapısı tuzağı (kayda geçti):** aynı `ProviderScope`
> tipini üst üste `pumpWidget` etmek **kabı yenilemez** — Riverpod
> override'ları YERİNDE güncellemeye çalışır. Sonuç: denetleyici bir önceki
> senaryonun yüklenmiş durumunu korur (rol/veri değişmemiş gibi davranır),
> `overrideWith` listesi farklıysa "provider was not overridden" fırlar. Dil
> döngülerinde senaryolar arasında **boş bir ağaç** çizip kabı söktürmek
> gerekir (`_sifirla`). Tur 3–6 döngüleri aynı override kümesini kullandığı
> için bu tuzak o turlarda görünmemişti.

`test/flutter_test_config.dart` süite başına bir kez `initializeDateFormatting()`
çağırır: eşleyicileri doğrudan çağıran saf birim testleri aksi halde
`LocaleDataException` ile düşer (uygulamada bu `main.dart`'ta yapılır).

Widget testleri yerelleştirme delegelerine ihtiyaç duyar: `test/helpers/l10n_test_app.dart`
(`l10nApp(...)` / `l10nScaffold(...)`, varsayılan **tr**). Yalın `MaterialApp`
ile çizilen yerelleştirilmiş ekran "Null check operator used on a null value"
ile düşer.

> **Her turun sabit adımı:** o modülün MEVCUT widget testleri `MaterialApp` →
> `l10nApp` geçişi yapar. Tur 4'te `bina_duzenleme_test`,
> `building_schematic_test` ve `complaints_screen_test` (33 test), tur 6'da
> `budget_screen_test`, `financial_summary_screen_test`,
> `site_budget_screen_test` ve `kargo_screen_test`, tur 7'de
`site_kurali_screen_test` ve `announcements_screen_test` böyle geçirildi; TR metin
> beklentileri **değişmediği** için başka düzeltme gerekmedi (çeviri
> anahtarlarının TR değerleri birebir korundu). Tur 6'da ek olarak
> `budget_models_test` içindeki iki `BudgetTip.label` iddiası düştü — alan
> kaldırıldı, karşılığı `butceTipAdi` testidir.

**Altın görseller (golden) TÜRKÇE'ye sabitlendi** (`test/tools/home_referans_golden_test.dart`):
referans görseller TR'dir ve dil başına golden üretmek 7 kat çıktı demektir;
çeviri doğruluğu metin bazlı testlerle güvence altındadır.

### Kalan iş (dışa alınacak metinler)

Ölçüm yöntemi (grep-doğrulanabilir): Türkçe'ye özgü karakter (`çğıöşüİ...`)
**veya** yaygın TR UI kelimesi içeren string literalleri say (yorumlar hariç):

```bash
# mobile/ içinde
python3 - <<'EOF'
import re, pathlib
tr=set('çğıöşüÇĞİÖŞÜ')
kw=re.compile(r'\b(Yeni|Aktif|Bekliyor|Kayıt|Açık|Giriş|Sil|Kaydet|Ekle|Düzenle|Tamam|İptal|Vazgeç)\b')
n=0
for f in pathlib.Path('lib').rglob('*.dart'):
    if 'l10n/gen' in str(f): continue
    body='\n'.join(l for l in f.read_text().split('\n') if not l.strip().startswith('//'))
    for m in re.finditer(r"'([^'\\\n]{2,})'|\"([^\"\\\n]{2,})\"", body):
        v=m.group(1) or m.group(2) or ''
        if any(c in tr for c in v) or kw.search(v): n+=1
print(n)
EOF
```

**Tur 2 (home) ölçümü — aynı komut, önce/sonra:**

| | Toplam string | Dosya | `home` modülü |
|---|---|---|---|
| Tur 2 öncesi | 1.115 | 100 | **123** (16 dosya) |
| Tur 2 sonrası | **994** | 91 | **2** (1 dosya) |

**Tur 3 (tasks + patrol) ölçümü — aynı komut, önce/sonra:**

| | Toplam string | Dosya | `tasks` | `patrol` |
|---|---|---|---|---|
| Tur 3 öncesi | 994 | 91 | **110** (9 dosya) | **81** (6 dosya) |
| Tur 3 sonrası | **803** | 75 | **0** | **0** |

**Tur 4 (building_map + complaints) ölçümü — aynı komut, önce/sonra:**

| | Toplam string | Dosya | `building_map` | `complaints` |
|---|---|---|---|---|
| Tur 4 öncesi | 803 | 75 | **84** (4 dosya) | **65** (2 dosya) |
| Tur 4 sonrası | **654** | 68 | **0** | **0** |

**Tur 5 (rezervasyon + etkinlik + unit_access) ölçümü — aynı komut:**

| | Toplam string | Dosya | `rezervasyon` | `etkinlik` | `unit_access` |
|---|---|---|---|---|---|
| Tur 5 öncesi | 654 | 68 | **51** | **44** | **41** |
| Tur 5 sonrası | **518** | 58 | **0** | **0** | **0** |

136 string dışa alındı; **133 yeni ARB anahtarı × 7 dil** (498 → 631).

**Tur 6 (budget + assets + kargo) ölçümü — aynı komut:**

| | Toplam string | Dosya | `budget` | `assets` | `kargo` |
|---|---|---|---|---|---|
| Tur 6 öncesi | 518 | 58 | **39** | **36** | **30** |
| Tur 6 sonrası | **413** | 50 | **0** | **0** | **0** |

105 string dışa alındı; **96 yeni ARB anahtarı × 7 dil** (631 → 727) + mevcut
anahtarların yeniden kullanımı (`ortakKaydet`, `ortakKaydediliyor`, `ortakYenile`,
`ortakNotOpsiyonel`, `ortakBeklenmeyenHata`, `binaDaireSayisi` (ICU çoğul —
geciken daire sayacı), `kargoDurumTeslimAlindi`, `devriyeDurumBekliyor/Bilinmiyor`,
`gorevEtiketBekleniyor`, `gorevEtiketOkunamadi`, `gorevAciklamaOpsiyonel`,
`gorevKamera`, `gorevYenidenCek`, `gorevGaleridenSec`, `gorevTekrarYukle`,
`gorevKaldir`, `gorevFoto*`, `talepGorselYuklenemedi`) ve **yeni ortak anahtar**
`ortakTekrarDene` (henüz çevrilmemiş 5 modülde de aynı metin geçiyor).

Tur 6'da **kontrol akışı denetimi boş döndü** — bu üç modülde hiçbir TR string
`switch`/`==` anahtarı değildi, id-split gerekmedi; yapılan üç ayrım
**görünen ad alanlarının kaldırılmasıydı** (`BudgetTip.label`,
`KargoDurum.label`) ve denetleyici mesaj kanallarının kimliğe çevrilmesiydi
(`DemirbasMesaj`, `KargoState.hataKimligi`, bütçe ekranlarında `AkisHatasi`).

**Tur 7 (site_kurali + announcements + residents) ölçümü — aynı komut:**

| | Toplam string | Dosya | `site_kurali` | `announcements` | `residents` | `core/ui` |
|---|---|---|---|---|---|---|
| Tur 7 öncesi | 413 | 50 | **32** | **31** | **30** | **3** |
| Tur 7 sonrası | **317** | 44 | **0** | **0** | **0** | **0** |

96 string dışa alındı; **70 yeni ARB anahtarı × 7 dil** (727 → 797) + mevcut
anahtarların yoğun yeniden kullanımı (`ortakKaydet`, `ortakEkle`, `ortakSil`,
`ortakDuzenle`, `ortakVazgec`, `ortakIptal`, `ortakTamam`, `ortakYenile`,
`ortakTekrarDene`, `ortakBeklenmeyenHata`, `modulDuyurular`, `talepBaslikAlan`,
`etkGorselAlan`, `devriyePasif`, `devriyeKaydedilemedi`, `butAdZorunlu`,
`binaDaireNo`, `gorevDaireEtiket`, `gorevGonderiliyor`, `gorevKamera`,
`gorevYenidenCek`, `gorevGaleridenSec`, `gorevTekrarYukle`, `gorevKaldir`,
`gorevFotoAlinamadi`, `gorevFotoOnlineGerekli`, `gorevFotoHenuzYuklenmedi`,
`talepGorselYuklenemedi`) — bu tur eklenen anahtarların **beşi `ortak*`**
olduğu için henüz çevrilmemiş modüllere de hazır geliyor (`ortakAdSoyad`,
`ortakCepTelefonu`, `ortakTelefonIpucu`, `ortakTelefonZorunlu`,
`ortakDaireNoIpucu`, `ortakIslemler`, `ortakGeciciKodBaslik`, `ortakKopyala`,
`ortakKopyalandi`).

Tur 7'de de **kontrol akışı denetimi boş döndü** ve `label` taşıyan enum
kalmadı — bu üç modülün domain'i zaten metin üretmiyordu. Yapılan ayrımlar:
iki denetleyiciye `hataKimligi` (`AkisHatasi`) eklendi ve ortak
`showTempCodeDialog` (core/ui) kendi metinlerini `l10n`'dan alır hâle geldi —
**açıklama satırı** çağıranda kalır, çünkü bağlama göre değişir (sakin ekleme /
parola sıfırlama / personel ekleme).

> **Bilinçli olarak ERTELENEN (tur 7 kapsam notu):** sakin ekleme formundaki
> opsiyonel parola alanı hâlâ `core/validators/password_rule.dart` içindeki
> **Türkçe** metinlerle doğrular ("En az 8 karakter olmalı" vb.). `passwordError`
> 4 çağrı yerine sahiptir ve **üçü bu turun kapsamı dışındadır** (`auth`,
> `profile`, `staff`); doğru çözüm bir kimlik enum'u + çözücü ve dört çağrı
> yerinin AYNI turda taşınmasıdır — `auth` turuna bırakıldı. §15 sayımında
> `validators: 5` olarak görünür.

> **Tur 5'te bulunan SESSİZ HATA SINIFI — ICU placeholder sırası.** ARB'de
> `placeholders` metadata'sı **yoksa** gen-l10n parametreleri **alfabetik**
> sıralar. Çağrı yeri mesajın okuma sırasını varsayarsa metin sessizce yanlış
> kurulur: `rezMusaitOzeti` "08:00–**60** · **22:00** dk slot" veriyordu.
> Denetim 6 anahtarda hata buldu ve **3'ü daha eski turlardan sızmıştı**:
> `sureSaatDakika` (tur 3 — "1 sa 30 dk" yerine "30 sa 01 dk"),
> `binaTopluOnizleme` ve `binaDaireEklendi` (tur 4). Kalıcı çözüm: **tüm
> çok-placeholder'lı anahtarlara MESAJ SIRASINDA `placeholders` metadata'sı**
> (tip verilmez → `Object` korunur, yalnız sıra sabitlenir). Sıra
> `test/rez_etk_izin_i18n_test.dart` içinde kilitlendi. Yeni çok-parametreli
> anahtar eklerken metadata ZORUNLUDUR.

149 string dışa alındı (building_map 84 + complaints 65); **139 yeni ARB
anahtarı × 7 dil** (359 → 498) + mevcut ortak/görev anahtarlarının yeniden
kullanımı (`ortakSil`, `ortakVazgec`, `ortakKaydet`, `ortakEkle`, `ortakYenile`,
`ortakKaydediliyor`, `ortakBeklenmeyenHata`, `modulBinaYapisi`,
`modulSikayetHaritasi`, `kartTalepAriza`, `talepDurum*` (tur 3),
`gorevOncelik*`, `gorevGaleridenSec`, `gorevFoto*`, `gorevAtananPersonel`,
`gorevKategoriDiger/Silinmis`, `devriyeDurumBilinmiyor`).

191 string dışa alındı (tasks 110 + patrol 81); **177 yeni ARB anahtarı × 7 dil**
(182 → 359) + 12 mevcut ortak anahtarın yeniden kullanımı (`ortakSil`,
`ortakVazgec`, `ortakKaydet`, `ortakDuzenle`, `ortakEkle`, `ortakYenidenDene`,
`ortakKaydediliyor`, `ortakBeklenmeyenHata`, `cipAktif`, `modulGorevlerim`,
`modulGorevYonetimi`, `modulTurlarim`).

Doğrulama (tur 2'deki `home` denetiminin sonraki turlardaki karşılığı) —
**boş dönmeli**:

```bash
grep -rnE "(switch|case|==)\s*\(?\s*['\"][^'\"]*[çğıöşü…]" \
  lib/src/features/tasks lib/src/features/patrol \
  lib/src/features/budget lib/src/features/assets lib/src/features/kargo \
  lib/src/features/site_kurali lib/src/features/announcements \
  lib/src/features/residents
```

Kalan 2 `home` stringi `home_marka.dart` içindeki **marka kilidi**dir (`Yönetio`,
`GÜVENLİK & DANIŞMANLIK`) — aşağıdaki bilinçli istisna.

> **Ölçümün kör noktası (kayda geçti):** bu grep yalnızca Türkçe'ye özgü karakter
> **veya** listedeki anahtar kelimeyi arar. `'Merhaba, '` gibi ikisini de
> içermeyen Türkçe metinler sayıma **girmez**. Nitekim ana ekran karşılaması
> (`home_header.dart`) sayım 0 gösterirken çevrilmemiş kalmıştı; canlı 7-dil
> sürüşünde yakalandı ve `anaKarsilama` anahtarıyla çevrildi. Bir modülü
> "bitti" ilan etmeden önce grep'e **ek olarak** o modülü yabancı bir dilde
> gözle sürmek gerekir.
>
> **Tur 3'te bulunan ikinci kör nokta:** betik yalnızca `//` ile **başlayan**
> satırları ayıklar; satır **sonundaki** yorum (`final x; // null -> "Diğer"`)
> string sayılır. `task_models.dart` tam çevrildiği hâlde sayaç 1 gösteriyordu.
> Yorumlar Türkçe görünen metni alıntılamak yerine **l10n anahtarına** işaret
> edecek şekilde yazıldı (`// null -> l10n.gorevKategoriDiger`) — hem sayaç
> doğru hem yorum daha bilgilendirici. Ayrıca grep, `'Planlanan: '` gibi
> Türkçe'ye özgü karakter taşımayan metinleri de kaçırır; tur 3'te bunlar
> dosya dosya okunarak bulundu (elle `_fmtDateTime` biçimleyicileri de
> `tarihSaatBicimi`/`saatBicimi` ile değiştirildi — tarih artık dile duyarlı). Yani ana ekran modülü
sayıma **sıfır** katkı verir. (Tur 1 sonunda bu bölümde yazan ~1.125/106
rakamı ölçümün o anki halidir; tur 2 başında aynı komut 1.115/100 verdi —
arada başka modüle dokunulmadı, fark ara commit'lerdeki küçük düzenlemelerden
gelir.)

Kalan envanter (modül başına, **tur 7 sonrası**; `tasks`, `patrol`,
`building_map`, `complaints`, `rezervasyon`, `etkinlik`, `unit_access`, `budget`,
`assets`, `kargo`, `site_kurali`, `announcements` ve `residents` listeden
düştü):

| Modül | Kalan string |
|---|---|
| `dis_hizmet` | 26 |
| `staff` | 25 |
| `nfc` | 25 |
| `integrations` | 23 |
| `transparency` | 22 |
| `visitors` | 22 |
| `auth` | 20 |
| `reports` | 20 |
| `dues` | 18 |
| `profile` | 18 |
| `checkpoints` | 16 |
| `scan` | 14 |
| `support` | 13 |
| `tenant` | 9 |
| `unit_complaints` | 8 |
| `shifts` | 7 |
| `yonetici_iletisim` | 6 |
| `settings` | 6 |
| `validators` | 5 (parola kuralı — `auth` turuna bırakıldı) |
| `error` | 3 |
| `home` | 2 (marka kilidi — istisna) |
| `i18n` | 2 |
| `branding` | 2 (marka kilidi — istisna) |
| `call` | 2 |
| `main.dart` | 1 |
| `notifications` | 1 |
| `push` | 1 |

**Bilinçli istisnalar (çevrilmez):**

* **Marka kilidi** — `Yönetio` kelime işareti ve `GÜVENLİK & DANIŞMANLIK` alt
  başlığı logo lockup'ının parçasıdır (`home_marka.dart`, `yonetio_logo.dart`);
  marka adı dile göre değişmez.
* **Teknik sabitler** — enum tel değerleri (`hls`, `mp4`, `rtsp`, `acik`,
  `kapali`), rota yolları, `HLS`/`MP4`/`RTSP` etiketleri, URL örnekleri.
* **Seed/demo metinleri** — backend seed verisi (kamera adları, kural
  başlıkları) sunucudan gelir; istemci çevirmez.
* **Kod içi yorum ve `debugPrint`** — kullanıcıya görünmez.
