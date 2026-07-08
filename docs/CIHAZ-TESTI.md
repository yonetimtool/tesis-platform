# Fiziksel Cihaz Testi Rehberi

Bu rehber, tesis platformunun (backend + yönetim paneli + Flutter mobil uygulama)
**gerçek Android telefon ve gerçek NFC etiketleriyle** uçtan uca denenmesi içindir.
Kod tarafı tamamlandı (backend 194, mobil 95 test geçiyor); bu rehberdeki hiçbir adım
kod değişikliği gerektirmez. Her adımı `[ ]` kutusunu işaretleyerek ilerleyin.

> **Kaynak dosyalar:** buradaki her komut/parola repo'daki `backend/README.md`,
> `mobile/README.md`, `admin-web/README.md`, `contracts/README.md`,
> `infra/.env.example` ve `infra/docker-compose*.yml` dosyalarından doğrulanmıştır.
> Bir şey uyuşmazsa güncel doğruluk kaynağı o dosyalardır.

---

## 1) Ön hazırlık — alışveriş ve gereksinim listesi

### NFC etiketleri

- [ ] **NTAG213 / NTAG215 sticker — en az 3-4 adet** (temel akışlar: checkpoint,
  görev, zimmet). NTAG216 da olur; önemli olan NTAG21x ailesi olması.
  25 mm yuvarlak sticker formu pratik.
- [ ] **NTAG424 DNA — 1-2 adet** (yalnızca S9 imza testi için; diğer 8 senaryo
  NTAG21x ile yapılır. İlk turda atlanabilir).
- Nereden: yurt içi e-ticaret sitelerinde "NTAG213 sticker" / "NTAG215 kart"
  aramasıyla bulunur; NTAG424 DNA daha nadirdir — elektronik komponent satıcıları
  (yurt dışı: Digi-Key, Mouser; NXP yetkili distribütörleri) veya "NTAG 424 DNA"
  aramasıyla özel NFC mağazaları. Amiibo vb. için satılan NTAG215'ler de uygundur
  (boş/yazılabilir olmasına dikkat).

### Telefon

- [ ] **NFC'li Android telefon** (Android 8+ önerilir; NFC şart — emülatörde NFC yok).
- [ ] Geliştirici seçenekleri + **USB hata ayıklama (USB debugging)** açık:
  Ayarlar → Telefon hakkında → "Yapı numarası"na 7 kez dokun → Geliştirici
  seçenekleri → USB hata ayıklama.
- [ ] USB kablosu (veri destekli).

### Bilgisayar

- [ ] **Docker**: Linux'ta Docker Engine + compose eklentisi; Windows'ta Docker Desktop
  (WSL2 backend).
- [ ] **Flutter SDK 3.44.x** + **Android SDK** (`flutter doctor` temiz olmalı).
  - JDK **17** gerekir; Gradle "Toolchain ... [JAVA_COMPILER]" hatası verirse:
    `flutter config --jdk-dir=<tam-JDK-17-yolu>`
    (Linux ör. `/usr/lib/jvm/java-17-openjdk-amd64`).
- [ ] **Node.js + npm** (yönetim paneli için).
- [ ] **git** ve repo erişimi.
- [ ] Telefon ve bilgisayar **aynı Wi-Fi ağına** bağlanabilmeli (misafir ağı /
  istemci izolasyonu olan ağlarda cihazlar birbirini göremez — ev/ofis ağı ya da
  telefonun hotspot'u kullanılabilir; hotspot kullanılırsa "LAN IP" hotspot ağındaki
  bilgisayar IP'sidir).
- [ ] **Firebase Console erişimi** (yalnızca S8 push için): `tesis-platform`
  projesine erişebilen Google hesabı.

### Windows / Linux notları

| Konu | Linux | Windows |
|---|---|---|
| LAN IP öğrenme | `ip a` (ör. `192.168.1.20`) | `ipconfig` → "IPv4 Address" |
| Güvenlik duvarı | `sudo ufw allow 8000/tcp && sudo ufw allow 9000/tcp` (ufw kullanıyorsanız) | Defender Güvenlik Duvarı → Gelen kuralı → TCP 8000 ve 9000'e izin |
| adb | Android SDK platform-tools ile gelir | aynı; sürücü sorunu olursa üreticinin USB sürücüsü |

> 8000 = API, 9000 = MinIO (foto yükleme). İkisi de telefondan erişilecek.

---

## 2) Yerel kurulum (bilgisayar)

- [ ] **Repo'yu klonla:**

  ```bash
  git clone <repo-adresi> tesis-platform
  cd tesis-platform
  ```

- [ ] **`google-services.json` dosyasını yerleştir** (push için; push denemeyecekseniz
  atlanabilir — dosya yokken build yine geçer, yalnız push sessizce devre dışı kalır):
  Firebase Console → `tesis-platform` projesi → Android uygulaması
  (`com.tesisguvenlik.mobile`) → `google-services.json` indir →
  **`mobile/android/app/google-services.json`** yoluna koy.
  Bu dosya `.gitignore`'dadır ve **repoya girmez** (Firebase istemci kimliği içerir;
  herkes kendi kopyasını Console'dan indirir).

- [ ] **`infra/.env` oluştur:**

  ```bash
  cd infra
  cp .env.example .env
  ```

  `.env` içinde en azından şunları düzenle:
  - `JWT_SECRET` ve `SDM_KEK`: 32+ karakter rastgele değerler
    (`SDM_KEK` boş/varsayılan kalırsa S9'daki anahtar kaydı çalışmaz).
  - **`MINIO_PUBLIC_ENDPOINT=http://<LAN-IP>:9000`** ← **ÖNEMLİ.** Varsayılan
    `http://localhost:9000`'dır; bu değer presigned foto yükleme URL'lerinin
    host'u olur ve telefon `localhost`'a erişemez. Bilgisayarın LAN IP'sini yazın
    (bkz. §3'te IP bulma). Yazmazsanız S5'te foto yükleme telefondan **başarısız olur**.

- [ ] **Servisleri kaldır:**

  ```bash
  # hâlâ infra/ dizinindeyken:
  docker compose up -d --build
  ```

  Kalkan servisler: `db` (Postgres), `redis`, `minio` + `minio-init`,
  `migrate` (one-shot), `api` (8000), `worker`, `beat`.

- [ ] **Sağlık kontrolü:**

  ```bash
  curl localhost:8000/health
  # beklenen: {"status":"ok","checks":{"database":true,"redis":true}}
  ```

- [ ] **Seed (örnek veri) yükle:**

  ```bash
  docker compose exec api python -m scripts.seed
  # alternatif (api kapalıyken): docker compose --profile seed run --rm seed
  ```

  Seed idempotenttir (tekrar çalıştırmak güvenli). Oluşturduğu hesaplar:

  | Rol | E-posta | Parola | Tesis kodu (tenant_slug) |
  |---|---|---|---|
  | admin (platform admini — panel) | `admin@acme.com` | `Admin123!` | `acme-plaza` |
  | yonetici (site yöneticisi — mobil) | `yonetici@acme.com` | `Yonetici123!` | `acme-plaza` |
  | security (güvenlik) | `guard@acme.com` | `Guard123!` | `acme-plaza` |
  | tesis_gorevlisi (temizlik+bahçıvan+teknik) | `cleaner@acme.com` | `Clean123!` | `acme-plaza` |
  | resident (site sakini) | `resident@acme.com` | `Resident123!` | `acme-plaza` |

  > Rol modeli notu: **panel (admin-web) yalnız `admin` içindir**; `yonetici`
  > mobil kullanır ve kendi tesisiyle sınırlıdır (görev atama/takip, rapor okuma,
  > acil durum, demirbaş görüntüleme). Tam RBAC matrisi: `contracts/auth.md` §4.

  Ayrıca: `A-12` dairesi + 2026-06 dönemi 750 TL tahakkuk + acil durum telefonu
  `+902120000000` (panelden değiştirilebilir).

- [ ] **Login duman testi (curl):**

  ```bash
  curl -s localhost:8000/auth/login -H 'content-type: application/json' \
    -d '{"tenant_slug":"acme-plaza","email":"admin@acme.com","password":"Admin123!"}'
  # beklenen: access_token + refresh_token içeren JSON
  ```

- [ ] **Yönetim panelini kur ve başlat:**

  ```bash
  cd ../admin-web
  cp .env.example .env.local     # varsayılan http://localhost:8000 — dokunmaya gerek yok
  npm install
  npm run build && npm run start # http://localhost:3000  (geliştirme: npm run dev)
  ```

- [ ] **Panele giriş:** tarayıcıda `http://localhost:3000` → Tesis: `acme-plaza`,
  E-posta: `admin@acme.com`, Parola: `Admin123!` → Canlı Panel (dashboard) açılmalı.

---

## 3) Telefona kurulum

- [ ] **Bilgisayarın LAN IP'sini bul:**
  - Linux: `ip a` → Wi-Fi/ethernet arayüzündeki `192.168.x.y` benzeri adres.
  - Windows: `ipconfig` → aktif bağdaştırıcının "IPv4 Address" satırı.
  - Aşağıda `<LAN-IP>` yazan her yere bu değeri koyun. (Not: `10.0.2.2` yalnızca
    **emülatör** içindir, fiziksel cihazda ÇALIŞMAZ.)

- [ ] **§2'deki `infra/.env` içinde `MINIO_PUBLIC_ENDPOINT`'i bu IP ile yazdığınızı**
  doğrulayın; değiştirdiyseniz `docker compose up -d` ile api'yi tazeleyin.

- [ ] **Debug APK derle** (base URL derleme zamanı `--dart-define=API_BASE_URL=...`
  ile verilir; sonda `/` olmadan, `/v0` EKLEMEDEN):

  ```bash
  cd mobile
  flutter pub get
  flutter build apk --debug --dart-define=API_BASE_URL=http://<LAN-IP>:8000
  # çıktı: build/app/outputs/flutter-apk/app-debug.apk
  ```

  > **Neden debug build:** HTTP (şifresiz) erişime yalnızca debug build izin verir;
  > release build cleartext'i engeller (prod HTTPS bekler).

- [ ] **Telefona kur** (telefon USB ile bağlı, hata ayıklama istemi onaylı):

  ```bash
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  # veya doğrudan çalıştırmak için:
  # flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:8000
  ```

- [ ] **Telefon ile bilgisayar aynı Wi-Fi'da mı?** Telefonun tarayıcısından
  `http://<LAN-IP>:8000/health` açın — JSON dönerse ağ tamam. Dönmezse §5/İlk madde.

- [ ] **İlk giriş denemesi:** uygulamayı aç → Tesis kodu `acme-plaza`, e-posta
  `guard@acme.com`, parola `Guard123!` → ana ekran açılmalı (ACİL DURUM kartı,
  Turlarım, NFC etiket okuma, Görevlerim, Demirbaş, Gönderim kuyruğu kartları).

---

## 4) Saha provası — 9 senaryo

> Genel notlar:
> - Mobil, UID'yi her zaman **BÜYÜK HARF, iki nokta ayraçlı hex** üretir
>   (ör. `04:A3:B2:C1:90:00`) — panelde checkpoint/demirbaş tanımlarken UID'yi
>   telefon ekranında göründüğü **gibi** girin.
> - Tüm yazma uçları Idempotency-Key kullanır: aynı işlemi yanlışlıkla iki kez
>   göndermek çift kayıt OLUŞTURMAZ (200 "zaten kayıtlıydı" döner). Bu bir hata değil,
>   tasarımdır.

### S1 — Login + roller

- [ ] Telefonda sırayla `guard@acme.com`, `cleaner@acme.com`, `yonetici@acme.com`,
  `admin@acme.com` ile girip çıkın (tenant hep `acme-plaza`).
- [ ] Uygulamayı tamamen kapatıp açın → login **atlanmalı** (oturum geri yükleme).
- [ ] Logout ikonu → login ekranına dönmeli.
- **Beklenen:** dört rol de girebilir; yanlış parola net hata gösterir. Rol farkları
  ileriki senaryolarda görülür (ör. Turlarım verisi cleaner/yonetici'de 403 kibar
  mesajı gösterebilir — bu doğru davranıştır: "Turlarım" saha turu verisidir,
  admin+security'ye açıktır). Mobil menünün yonetici rolüne göre hizalanması ayrı
  turda gelecek; bu turda yonetici login olabilir, yetkisiz ekranlar 403 gösterir.

### S2 — Checkpoint tanımlama (NTAG21x UID eşleme)

- [ ] Telefon (herhangi bir rol) → ana ekran → **NFC etiket okuma** → "Okumayı başlat"
  → NTAG213/215 sticker'ı telefonun arkasına yaklaştır.
- [ ] Ekranda UID (ör. `04:1A:2B:3C:4D:50:80`) ve tahmini tip (`ntag2xx`) görünmeli.
  UID'yi not alın. (Bu okutma "eşleşmedi" diye kuyruğa kalıcı-hata düşebilir — normal,
  checkpoint henüz yok.)
- [ ] Panel → **Checkpoints** sayfası → yeni checkpoint: ad (ör. "Ana Giriş") +
  `nfc_tag_uid` alanına telefondaki UID'yi aynen gir → kaydet.
- [ ] Telefonla etiketi tekrar okut → gönder.
- **Beklenen:** telefonda "Gönderildi ✓ — okutma kaydedildi" (201). Aynı etiketi
  hemen tekrar okutup göndermek yeni bir kayıt (yeni okutma zamanı → yeni kayıt) oluşturur;
  bu da normaldir.

### S3 — Devriye turu (plan → pencere → okutma → canlı izleme)

- [ ] Panel → **Patrol Plans** → yeni plan: başlangıç/bitiş saati **şu anı kapsayacak**
  şekilde (ör. şimdi 14:20 ise 14:00–18:00), periyot ör. 60 dk, S2'deki checkpoint('ler)i
  plana ata.
- [ ] Pencereler saat başı otomatik üretilir (beat servisi). Beklemeden üretmek için:

  ```bash
  cd infra
  docker compose exec api python -m scripts.run_scheduler --generate
  ```

- [ ] Telefon → `guard@acme.com` ile → **Turlarım** → aktif pencere + nokta listesi
  ("Bekliyor" durumlu) görünmeli.
- [ ] Karttaki **"Nokta okut (NFC)"** → etiketi okut → Turlarım'a dön.
- **Beklenen:**
  - Telefonda ilgili nokta **"Okutuldu ✓"** olur (sunucu verisi `GET /me/patrol-window`).
  - Panel → **Dashboard** (15 sn'de bir yenilenir): bugünkü turda
    okutulan/beklenen sayacı artar.
  - Pencere bitince (veya `--detect` ile) durum `tamamlandi`/`kacirildi`ya döner;
    kaçırılan tur Dashboard "son alarmlar"a düşer.

### S4 — OFFLINE okutma (outbox)

- [ ] Telefonu **uçak moduna** al (Wi-Fi da kapalı).
- [ ] NFC ekranından tanımlı etiketi okut.
- **Beklenen:** anında "Kaydedildi ✓ — bağlantı gelince otomatik gönderilecek" +
  AppBar'da bekleyen rozeti (ör. "1").
- [ ] Uygulamayı öldürüp yeniden aç → ana ekranda "Gönderim kuyruğu: 1 okutma
  gönderim bekliyor" (kayıt kalıcı — diske yazıldı).
- [ ] Uçak modunu kapat.
- **Beklenen:** bağlantı tetikleyicisi kuyruğu boşaltır; rozet düşer, kuyruk ekranında
  (`Gönderim kuyruğu` kartı) "Gönderildi". Gecikirse uygulamayı öne getirin veya
  kuyruk ekranındaki **"Şimdi senkronla"** butonunu kullanın. Panelde okutma sayacı artar.
- [ ] Ek kontrol: sistemde OLMAYAN bir etiketi okutun → kuyrukta kırmızı
  "Kalıcı hata: ... eşleşmiyor" satırı; retry edilmez, "Kalıcı hataları temizle" ile silinir.

### S5 — Görev + foto kanıtı

- [ ] Panel (admin) → **Tasks** → yeni görev: tip ör. `temizlik`, ad ör. "Lobi temizliği",
  atanan: cleaner kullanıcısı, istersen S2 checkpoint'ini bağla ve **foto zorunlu**
  işaretle.
- [ ] Telefon → `cleaner@acme.com` ile → **Görevlerim** → görev listede ("Foto zorunlu"
  rozetiyle) → göreve gir.
- [ ] (Checkpoint bağladıysan) **Etiketi okut** → doğru etiket.
- [ ] **Foto çek** → "Yüklendi ✓" bekle (bu adım interneti VE §2'deki
  `MINIO_PUBLIC_ENDPOINT=<LAN-IP>` ayarını gerektirir).
- [ ] Not yaz (opsiyonel) → **Tamamla**.
- **Beklenen:** "kayıt oluşturuldu" (201). Panel → görev/tamamlama geçmişinde tamamlama
  foto işaretiyle görünür. Foto olmadan "Tamamla" denemesi istemcide erken uyarıyla durur.
  Yanlış etiket okutulursa 422 mesajı aynen gösterilir.

### S6 — Acil durum (panik)

- [ ] Telefon → `guard@acme.com` (veya cleaner) → ana ekrandaki kırmızı **ACİL DURUM**
  kartı → not (opsiyonel) → **ACİL DURUM BİLDİR** → onay dialogunda **BİLDİR**
  (ilk kez konum izni sorulur; reddedilirse alarm konumsuz gider — yine iletilir).
- **Beklenen:**
  - Telefonda "Alarm iletildi ✓" + **"Yönetimi ara"** kartı → dokununca cihazın arama
    ekranı `+902120000000` ile açılır (numara panel → **Settings**'ten değiştirilebilir).
  - Panel → **Emergency** sayfası: kırmızı "açık" alarm, not + (izin verildiyse)
    GPS koordinatları. Admin alarmı "çözüldü" yapabilir.
- [ ] Offline varyant: uçak modunda bildir → NET kırmızı "ALARM İLETİLEMEDİ" uyarısı
  (sessiz kuyruklama YOK — bilinçli tasarım); bağlantı gelince "Tekrar dene" → tek alarm
  (çift kayıt oluşmaz).

### S7 — Demirbaş zimmet (checkout/checkin + sahiplik)

- [ ] Boş bir NTAG21x etiketi daha okutup UID'sini not al (S2'deki gibi NFC ekranından).
- [ ] Panel (admin) → **Assets** → yeni demirbaş (ör. "Çim biçme makinesi") +
  `nfc_tag_uid` alanına bu UID.
- [ ] Telefon → `guard@acme.com` → **Demirbaş** → **Etiket okut** → yeşil "Kimsede değil"
  kartı → **Zimmetine al**.
- **Beklenen:** kart maviye döner ("SENDE — X dakikadır"); panel Assets'te durum
  `zimmetli` + kimde bilgisi guard.
- [ ] `cleaner@acme.com` ile girip aynı etiketi okut → turuncu **"Başkasında"** kartı,
  bırak/al butonu YOK. (API düzeyinde de başkasının checkin denemesi **403** döner —
  sahiplik kuralı backend'de zorlanır.)
- [ ] guard'a dönüp **Üzerimdekiler** sekmesi → **Bırak**.
- **Beklenen:** liste boşalır; panelde `musait`. Kartın altında son hareketler
  (kim aldı/bıraktı, ne zaman) görünür.
- [ ] Uçak modunda zimmet işlemi dene → "internet bağlantısı gerekli" uyarısı
  (zimmet bilinçli olarak offline kuyruklanmaz — canlı durum işi).

### S8 — PUSH bildirimi (gerçek FCM)

Ön koşullar: telefondaki APK `google-services.json` **ile** derlenmiş olmalı (§2) ve
`infra/secrets/fcm-service-account.json` mevcut olmalı (Firebase Console →
Project settings → Service accounts → "Generate new private key"; dosya
`.gitignore`'dadır, repoya girmez).

- [ ] `infra/.env` içine: `PUSH_PROVIDER=fcm`
- [ ] Backend'i push override'ıyla yeniden kaldır:

  ```bash
  cd infra
  docker compose -f docker-compose.yml -f docker-compose.push.yml up -d
  ```

- [ ] Duman testi (push ATMAZ, yalnız Google'dan OAuth2 token alarak kimliği doğrular):

  ```bash
  docker compose -f docker-compose.yml -f docker-compose.push.yml \
    exec api python -m scripts.push_smoke
  # beklenen: "token alindi, project=tesis-platform, expiry=..."
  ```

- [ ] Telefonda `guard@acme.com` ile login ol (login sonrası bildirim izni istenir —
  **izin ver**; token otomatik `POST /devices` ile kaydolur).
- [ ] Acil durum tetikle (S6'daki gibi telefondan; acil durum push'u admin+security
  rollerinin kayıtlı cihazlarına gider — guard security olduğundan bu telefona düşer).
- **Beklenen:**
  - Uygulama **ön plandayken**: alt tarafta SnackBar ("başlık — gövde").
  - Uygulama **arka planda/kapalıyken**: sistem bildirim tepsisine düşer; dokununca
    uygulama açılır.
- [ ] Test bitince normale dönmek isterseniz: `.env`'de `PUSH_PROVIDER=noop` +
  `docker compose up -d`.

### S9 — NTAG424 DNA imza doğrulaması (İLERİ SEVİYE)

> **Dürüst not:** NTAG424 etikete SDM anahtarı yazma (provisioning) bu repo'nun
> kapsamı DIŞINDA ayrı bir iştir — NXP **TagWriter** (Android) veya **TagXplorer**
> (PC) gibi araçlarla, AN12196'daki örnek konfigürasyona uygun yapılır:
> UID+CTR aynalı, ENCPICCData'lı, SDMMAC girdisi boş; etiket NDEF URL'ine
> `picc_data=<32 hex>` + `cmac=<16 hex>` parametreleri aynalanır. Backend kripto
> doğruluğu AN12196'nın yayınlı test vektörleriyle kanıtlıdır; bu senaryo "gerçek
> etiket + gerçek anahtar" halkasını kapatır. Provisioning'de kullandığınız
> SDM dosya-okuma anahtarını (32 hex) not edin.

- [ ] S2'deki gibi NTAG424 etiketin UID'siyle bir checkpoint tanımla (etiket tipi
  telefonda `ntag424` görünür).
- [ ] Anahtarı backend'e kaydet (panelde SDM alanı YOK — curl ile; yalnız admin):

  ```bash
  # 1) admin token al:
  TOKEN=$(curl -s localhost:8000/auth/login -H 'content-type: application/json' \
    -d '{"tenant_slug":"acme-plaza","email":"admin@acme.com","password":"Admin123!"}' \
    | python -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')

  # 2) checkpoint id'sini bul:
  curl -s "localhost:8000/checkpoints" -H "Authorization: Bearer $TOKEN"

  # 3) anahtarı yaz (sayaç sıfırlanır; anahtar hiçbir yanıtta geri dönmez):
  curl -s -X PUT "localhost:8000/checkpoints/<CHECKPOINT-ID>/sdm-key" \
    -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' \
    -d '{"key":"<32-hex-sdm-anahtari>"}'
  ```

  > 500 `config_error` dönerse `infra/.env`'de `SDM_KEK` 32+ karakter değil demektir
  > (§2) — düzeltip `docker compose up -d` ile api'yi tazeleyin.

- [ ] Telefonla NTAG424 etiketi okut → gönder.
- **Beklenen:** okutma kabul edilir ve kayıtta **`imza_dogrulandi=true`** olur
  (doğrulamak için: aynı etiketi anahtar kayıtlıyken okutup panel sayaçlarının
  arttığını görmek + istenirse DB'den `docker compose exec db psql -U tesis_owner
  -d tesis -c "SELECT imza_dogrulandi FROM scan_event ORDER BY created_at DESC LIMIT 3;"`).
- [ ] **Sahte kopya testi:** aynı UID'yi taşıyan ama SDM imzası olmayan/bozuk bir
  istek (ör. bir NTAG21x'e aynı URL'i sabit `picc_data/cmac` ile yazmak = eski
  imzayı kopyalamak) → **422 `invalid_signature`**, tekrarlanan eski imza →
  **422 `replay_detected`**; telefon "Etiket imzası doğrulanamadı — sahte veya
  yanlış etiket olabilir." / "Bu okutma daha önce işlendi." gösterir ve kayıt oluşmaz.

---

## 5) Sorun giderme

**Telefon backend'e ulaşamıyor** (login'de ağ hatası)
- [ ] Telefon tarayıcısından `http://<LAN-IP>:8000/health` açılıyor mu?
- [ ] Telefon ve bilgisayar AYNI Wi-Fi'da mı? (Misafir ağı/istemci izolasyonu olabilir —
  telefon hotspot'u deneyin.)
- [ ] Bilgisayar güvenlik duvarı 8000'e izin veriyor mu? (§1 tablo.)
- [ ] APK doğru IP ile mi derlendi? IP değiştiyse (DHCP) yeniden derleyin —
  base URL derleme zamanı gömülür. `10.0.2.2` fiziksel cihazda çalışmaz.
- [ ] APK **debug** mu? (Release build HTTP'ye izin vermez.)

**NFC okumuyor**
- [ ] Telefonda NFC açık mı? (Ayarlar → Bağlantı → NFC.)
- [ ] Etiket telefonun NFC anteninin olduğu bölgeye (genelde arka-orta/üst) değiyor mu?
  Kılıf kalınsa çıkarın; 1-2 sn sabit tutun.
- [ ] Etiket tipi doğru mu? (NTAG21x/424 kullanın; bazı 125 kHz etiketler NFC değildir.)
- [ ] Uygulama "Bu cihaz NFC desteklemiyor" diyorsa cihazda NFC donanımı yoktur.

**Push gelmiyor**
- [ ] Telefonda bildirim izni verildi mi? (Android 13+ login sonrası sorar;
  Ayarlar → Uygulamalar → bildirim izni.)
- [ ] APK `google-services.json` İLE mi derlendi? (Dosya yokken push sessizce devre dışı.)
- [ ] Backend `PUSH_PROVIDER=fcm` + override compose ile mi ayakta? Duman testi geçiyor mu? (S8.)
- [ ] Token kaydoldu mu?

  ```bash
  cd infra
  docker compose exec db psql -U tesis_owner -d tesis -c \
    "SELECT platform, aktif, LEFT(fcm_token,20) FROM user_device ORDER BY created_at DESC LIMIT 5;"
  ```

  Kayıt yoksa: telefonda çıkıp yeniden login olun (kayıt login sonrası tetiklenir;
  ağ hatası sonraki açılışta yeniden denenir).
- [ ] Alıcı rol doğru mu? Acil durum push'u **admin+security** cihazlarına gider —
  cleaner ile login'li telefona düşmez.
- [ ] `docker compose logs api worker | grep -i push` çıktısına bakın
  (`push_unconfigured` görünüyorsa kimlik dosyası mount edilmemiş demektir).

**Foto yüklenmiyor** ("Yüklendi ✓" gelmiyor)
- [ ] MinIO ayakta mı? `docker compose ps` → `minio` "running"; bilgisayardan
  `http://localhost:9001` konsolu açılıyor mu (`minioadmin`/`minioadmin12345` —
  `.env`'deki değerler)?
- [ ] **En sık neden:** `MINIO_PUBLIC_ENDPOINT` LAN IP değil. Presigned URL'in host'u
  bu değişkenden gelir; `localhost` kalırsa telefon URL'e erişemez. `infra/.env`'de
  `MINIO_PUBLIC_ENDPOINT=http://<LAN-IP>:9000` yapıp `docker compose up -d`
  ile api'yi tazeleyin. Telefon tarayıcısından `http://<LAN-IP>:9000` bir XML/erişim
  yanıtı veriyorsa ağ tarafı tamamdır.
- [ ] Güvenlik duvarında 9000 açık mı?
- [ ] Presigned URL kısa ömürlüdür — "Foto çek" ile "Tamamla" arasında çok beklediyseniz
  "Tekrar yükle" deneyin.

**Turlarım boş / "aktif devriye yok"**
- [ ] Plan saat aralığı ŞU ANI kapsıyor mu? (Tenant saat dilimi Europe/Istanbul.)
- [ ] Pencereler üretildi mi? `docker compose exec api python -m scripts.run_scheduler --generate`
- [ ] Login'li rol admin veya security mi? (cleaner/yonetici "Turlarım" göremez —
  403 beklenir; yonetici devriye TAKİBİNİ panel-benzeri uçlardan okur: patrol-windows,
  dashboard/live.)

**Panel açılmıyor / login dönmüyor**
- [ ] Backend `http://localhost:8000/health` 200 mü? Panel BFF ile backend'e sunucu
  tarafından bağlanır — `admin-web/.env.local` içindeki `NEXT_PUBLIC_API_BASE_URL`
  backend adresini göstermeli (varsayılan doğru).

---

## 6) Sonuç kaydı

Her senaryodan sonra tabloyu doldurun:

| Senaryo | Sonuç (✅/❌/⚠️) | Tarih | Not / bulgu |
|---|---|---|---|
| S1 Login + roller | | | |
| S2 Checkpoint tanımlama | | | |
| S3 Devriye turu | | | |
| S4 Offline outbox | | | |
| S5 Görev + foto | | | |
| S6 Acil durum | | | |
| S7 Zimmet | | | |
| S8 Push (FCM) | | | |
| S9 NTAG424 imza | | | |

**Bulgu alışkanlığı:** ❌/⚠️ olan her satır için bir **GitHub issue** açın
(başlık: `cihaz-testi: S<no> — <kısa özet>`) ve şunları ekleyin: telefon modeli +
Android sürümü, etiket tipi, tam hata mesajı/ekran görüntüsü ve ilgili log
(`docker compose logs api --since 10m`). Testi bitirince bu dosyadaki işaretli
haliyle tabloyu commit'lemek, "hangi donanımla ne zaman ne doğrulandı"nın kalıcı
kaydı olur.
