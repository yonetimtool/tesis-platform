# Tesis Güvenlik — Mobil (Flutter)

Multi-tenant tesis güvenlik & operasyon SaaS'in saha mobil uygulaması.
Backend (DEV-A) hazır olana kadar geliştirme **mock sunucuya** karşı yapılır;
tek doğruluk kaynağı `/contracts/openapi.yaml`'dir.

- **Flutter** 3.44.4 · Dart 3.12.x · Android SDK 36 · hedef: Android (kod cross-platform)
- **Mimari:** Clean Architecture (`data` / `domain` / `presentation`)
- **Routing:** `go_router` · **State:** `Riverpod` · **HTTP:** `dio`
- **Güvenli depolama:** `flutter_secure_storage` (Android Keystore destekli)

Bu prompt kapsamı (Faz 0): iskelet + **login** (`tenant_slug` + `email` + `password`
→ access/refresh token) + token'ların güvenli saklanması + açılışta oturum geri yükleme.

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

## 2. Mock sunucu (Prism)

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

## 3. Base URL yapılandırması (dev/prod ayrımı)

Base URL **derleme zamanı** `--dart-define=API_BASE_URL=...` ile verilir
(`lib/src/core/config/app_config.dart`). Sondaki `/` olmadan yazın.

| Senaryo | API_BASE_URL |
|---------|--------------|
| **Mock — Android emülatör** (varsayılan) | `http://10.0.2.2:4010` |
| Mock — gerçek cihaz (USB/aynı Wi-Fi) | `http://PC-LAN-IP:4010` (ör. `http://192.168.1.20:4010`) |
| Gerçek backend — local | `http://10.0.2.2:8000/v0` |
| Prod | `https://api.example.com/v0` |

### 🔑 Emülatör/cihazdan localhost'a erişim farkı (önemli)

- **Android emülatörü** ana makineyi (`localhost`) **`10.0.2.2`** üzerinden görür.
  `127.0.0.1`/`localhost` emülatörün **kendisini** işaret eder, mock'a ulaşmaz.
  Bu yüzden varsayılan base URL `http://10.0.2.2:4010`'dur.
- **Gerçek cihaz** USB/Wi-Fi'da: bilgisayarınızın LAN IP'sini kullanın
  (`ip addr` / `ifconfig` → ör. `192.168.x.y`). Mock'u `0.0.0.0`'a bind ettiğinizden
  emin olun (Docker örneği `-h 0.0.0.0`; Node'da `-p 4010 --host 0.0.0.0`).
- HTTP (cleartext) erişimi yalnızca **debug** build'de açıktır
  (`android/app/src/debug/AndroidManifest.xml` → `usesCleartextTraffic="true"`).
  Release build cleartext'e izin vermez (prod HTTPS bekler).

---

## 4. Çalıştırma

```bash
cd mobile
flutter pub get

# Emülatörde mock'a karşı çalıştır (varsayılan base URL zaten 10.0.2.2:4010):
flutter run

# Base URL'i açıkça vererek (ör. mock /v0 altındaysa veya gerçek cihazda):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4010
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:4010
```

Akış: login ekranı → mock'a `POST /auth/login` → dönen token çifti
secure storage'a yazılır → ana ekrana geçilir. Uygulamayı yeniden başlattığınızda
saklı refresh token varsa **login atlanır**, doğrudan ana ekran açılır
(çıkış için ana ekrandaki logout ikonu token'ları siler).

---

## 5. Test & doğrulama (kabul kriterleri)

```bash
flutter analyze                 # → No issues found!
flutter test                    # → birim testleri (TokenPair / ApiException) geçer
flutter build apk --debug       # → build/app/outputs/flutter-apk/app-debug.apk
```

Son durum: `flutter analyze` temiz, `flutter test` 4/4 geçer, debug APK üretilir.

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
│     │  ├─ error/api_exception.dart      # { error: { code, message } } parse
│     │  └─ network/dio_provider.dart     # paylaşılan Dio
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

- `/notifications` ve `/notifications/{id}` operasyonları `tags: [notifications]`
  kullanıyor ama bu tag, dosyanın üstündeki global `tags` listesinde tanımlı değil
  (yalnızca auth, shifts, checkpoints, patrol-plans, scans, dashboard var).
- `servers` girdileri `/v0` base path içeriyor; mock (Prism) bu base path'i sürüme
  göre farklı ele alabildiğinden base URL mobil tarafta `--dart-define` ile
  esnek bırakıldı (bkz. §3). Gerçek backend'de yolun `/v0` ile mi sunulacağı
  netleşince varsayılan güncellenebilir.
