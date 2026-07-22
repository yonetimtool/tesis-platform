# Yönetio — Üretim Kurulum Runbook'u (Debian 13)

Tek sunucuda, pfSense NAT arkasında (yalnız TCP **80/443** iletilir) üretim
kurulumu. Tüm servisler Docker Compose ile çalışır; dışarıya yalnız **Caddy**
açıktır ve otomatik Let's Encrypt TLS sağlar.

**Alan adları (bu sunucunun genel IP'sine A kaydı):**
`api.yonetio.site` · `panel.yonetio.site` · `storage.yonetio.site`

---

## 0. Ön koşul: DNS

Kuruluma başlamadan **önce** üç A kaydı da sunucunun genel IP'sine çözülmeli
(Let's Encrypt HTTP-01 doğrulaması bunu gerektirir):

```
api.yonetio.site       A   <SUNUCU_GENEL_IP>
panel.yonetio.site     A   <SUNUCU_GENEL_IP>
storage.yonetio.site   A   <SUNUCU_GENEL_IP>
```

pfSense'te WAN → bu sunucuya **yalnız 80 ve 443** (TCP) yönlendirmesi olmalı.
Doğrulama: `dig +short api.yonetio.site` → sunucu IP'sini vermeli.

---

## 1. Debian 13 sunucu hazırlığı

```bash
sudo apt update && sudo apt -y upgrade
sudo apt -y install ca-certificates curl git gnupg
sudo timedatectl set-timezone Europe/Istanbul
```

## 2. Docker + Compose kurulumu (resmi repo)

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"    # sonra oturumu kapatıp açın (grup için)
docker compose version             # doğrulama
```

## 3. Repo'yu klonla

```bash
sudo mkdir -p /opt/yonetio && sudo chown "$USER" /opt/yonetio
cd /opt/yonetio
git clone <REPO_URL> tesis-platform
cd tesis-platform/infra
```

## 4. Üretim env dosyasını doldur

```bash
cp .env.prod.example .env.prod
```

`.env.prod` içindeki her **DEGISTIR_** değerini güçlü rastgele değerle doldurun:

```bash
openssl rand -base64 36    # POSTGRES_PASSWORD, APP_DB_PASSWORD, MINIO_ROOT_PASSWORD,
                           # SDM_KEK, BACKUP_GPG_PASSPHRASE için
openssl rand -base64 48    # JWT_SECRET için (daha uzun)
```

Doldurulması zorunlu: `ACME_EMAIL`, tüm parolalar, `JWT_SECRET`, `SDM_KEK`,
`BACKUP_GPG_PASSPHRASE`. Alan adları örnekle aynıysa dokunmayın.

> ⚠️ `.env.prod` **gizlidir** (.gitignore'da) — asla commit etmeyin.
> `BACKUP_GPG_PASSPHRASE` kaybolursa yedekler geri yüklenemez; ayrı/güvenli yerde saklayın.

## 5. (Opsiyonel) FCM push kimliği

Push bildirimleri **varsayılan kapalıdır** (hiçbir şey çökmez). Gerçek FCM için:

```bash
# Firebase → Proje Ayarları → Servis hesapları → "Yeni özel anahtar üret" (JSON)
cp <indirilen>.json /opt/yonetio/tesis-platform/infra/secrets/fcm-service-account.json
```

Sonra `.env.prod` içinde: `PUSH_PROVIDER=fcm` yapın. `project_id` JSON'dan okunur.
`infra/secrets/` klasörü api & worker'a `/secrets` olarak salt-okunur bağlanır.

## 6. Ayağa kaldır (build + up)

```bash
cd /opt/yonetio/tesis-platform/infra
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

İlk açılışta Caddy sertifikaları alır (birkaç saniye–dakika). Durum:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod ps
```

`api` ve `admin-web` **healthy**, `migrate`/`minio-init` **exited (0)** olmalı.

## 7. İlk platform admin'i oluştur (seed YOK)

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  run --rm api python -m scripts.create_admin --email admin@firmaniz.com
# Parola güvenli şekilde sorulur (ekranda görünmez, 8+ karakter, büyük harf+rakam+sembol).
```

Çıktıdaki **Tenant (slug)** değeri (varsayılan `yonetio`) panel girişindeki
"Tesis" alanına yazılır. (Bu komut idempotenttir; tekrar çalıştırmak admin
parolasını sıfırlamanın da yoludur.)

## 8. Duman testleri (smoke)

1. **Sertifika/health:**
   ```bash
   curl -sS https://api.yonetio.site/health           # {"status":"ok",...}
   ```
2. **Panel girişi:** Tarayıcıda `https://panel.yonetio.site` → slug (`yonetio`) +
   admin e-posta + parola → Dashboard açılmalı. (Panel yalnız `admin` rolüne açıktır.)
3. **Tesis (tenant) oluştur:** Panel → Tesisler → yeni tesis + yönetici oluştur;
   dönen tek-seferlik yönetici kimliği not edilir.
4. **Mobil bağlantı:** Release APK'yı `--dart-define=API_BASE_URL=https://api.yonetio.site`
   ile derleyin (bkz. §9), yöneticiyle giriş yapın, bir foto yükleyin → foto
   `storage.yonetio.site` üzerinden yüklenip görüntülenmeli.

## 9. Mobil release APK derleme

Geliştirici makinesinde (Flutter kurulu):

```bash
cd mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yonetio.site
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

Mobil, foto presigned URL'lerini API'den alır ve doğrudan `storage.yonetio.site`'a
PUT/GET yapar — ayrı yapılandırma gerekmez.

## 10. Şifreli yedekleme cron'u

```bash
chmod +x /opt/yonetio/tesis-platform/infra/backup.sh
sudo apt -y install gnupg     # gpg yoksa
# Elle bir kez test:
/opt/yonetio/tesis-platform/infra/backup.sh
# Cron (her gece 03:15):
crontab -e
```
Ekleyin:
```
15 3 * * * /opt/yonetio/tesis-platform/infra/backup.sh >> /var/log/yonetio-backup.log 2>&1
```
Yedekler `$BACKUP_DIR` (varsayılan `/opt/yonetio/backups`) altında, AES-256 gpg ile
şifreli; son **14** tutulur. MinIO (foto) volume yedeği için `backup.sh` sonundaki
nota bakın.

**Geri yükleme (felaket kurtarma):**
```bash
source /opt/yonetio/tesis-platform/infra/.env.prod
gpg --batch --decrypt --passphrase "$BACKUP_GPG_PASSPHRASE" \
     /opt/yonetio/backups/yonetio-db-YYYYMMDD-HHMMSS.sql.gz.gpg \
  | gunzip \
  | docker compose -f docker-compose.prod.yml --env-file .env.prod \
      exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```
(Boş bir sunucuya geri yüklerken önce §6 ile stack'i ayağa kaldırın; `migrate`
`app_rw` rolünü kurar, sonra dump'ı yükleyin.)

## 11. Güncelleme prosedürü

```bash
cd /opt/yonetio/tesis-platform
git pull
cd infra
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
# migrate her açılışta idempotent çalışır (alembic upgrade head).
docker image prune -f     # eski katmanları temizle (opsiyonel)
```

## 12. Log inceleme

```bash
C="docker compose -f docker-compose.prod.yml --env-file .env.prod"
$C logs -f api            # API
$C logs -f admin-web      # panel
$C logs -f worker beat    # celery
$C logs caddy | tail -50  # TLS/sertifika sorunları
$C ps                     # sağlık durumları
```

## 13. Sorun giderme

| Belirti | Kontrol / Çözüm |
|---|---|
| **Sertifika alınamıyor** | `$C logs caddy`. DNS üç alanı da sunucu IP'sine mi çözüyor (`dig +short ...`)? pfSense 80 **ve** 443'ü iletiyor mu? Let's Encrypt oran limiti aşıldıysa geçici bekleyin (staging için Caddyfile'daki `acme_ca` satırını açın). |
| **api unhealthy** | `$C logs api`. DB healthy mi (`$C ps`)? `.env.prod` DB parolaları tutarlı mı? `migrate` 0 ile bitti mi? |
| **panel 502 / boş** | `admin-web` healthy mi? BFF API'ye ic agdan gidiyor (`API_BASE_URL=http://api:8000`) — değiştirmeyin. |
| **Girişte "yalnız platform admini"** | Doğru; yönetici/saha hesapları **mobil** kullanır. Panel yalnız `admin` rolüne açık. |
| **Foto yüklenmiyor/görünmüyor** | `storage.yonetio.site` sertifikası var mı? `$C logs minio`. `MINIO_PUBLIC_URL=https://storage.yonetio.site` mi? Caddy Host'u koruyor (imza için şart). |
| **Foto 403 SignatureDoesNotMatch** | `MINIO_PUBLIC_URL` ile gerçek erişilen host birebir aynı olmalı; `storage.` alanı Caddy'de tanımlı ve `minio:9000`'e proxy'li olmalı. |
| **Push gelmiyor** | Beklenen (varsayılan noop). FCM için §5 + `PUSH_PROVIDER=fcm`; `$C logs worker` "unconfigured" diyorsa JSON yolu/`project_id` eksik. |
| **create_admin RLS hatası** | Komut `api` imajından `run --rm` ile çalışmalı (OWNER_DSN taşır); `--env-file .env.prod` verildiğinden emin olun. |

---

### İçindekiler (TOC)
0. Ön koşul: DNS · 1. Sunucu hazırlığı · 2. Docker kurulumu · 3. Repo klonlama ·
4. .env.prod · 5. FCM (ops.) · 6. Ayağa kaldırma · 7. İlk admin · 8. Duman testleri ·
9. Mobil APK · 10. Yedekleme cron · 11. Güncelleme · 12. Loglar · 13. Sorun giderme
