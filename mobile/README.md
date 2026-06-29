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
│     │  └─ home/presentation/home_screen.dart   # placeholder ana ekran
│     └─ routing/
│        ├─ app_router.dart                # go_router + auth redirect
│        └─ splash_screen.dart             # oturum geri yüklenirken
└─ test/
   ├─ token_pair_test.dart
   └─ api_exception_test.dart
```

---

## 7. Sözleşme notları (DEV-A'ya)

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
