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

`api` ve `admin-web` **healthy**, `migrate`/`minio-init`/`libretranslate-init`
**exited (0)** olmalı.

> **`libretranslate` ilk açılışta uzun sürer.** Çeviri modelleri (~1-2 GB)
> indirilir ve `ltmodels` volume'una yazılır; bu sürede servis **starting**
> görünür (healthcheck `start_period` 120 sn, 40 deneme). Bu **bloklayıcı
> değildir**: duyuru/kural/etkinlik yazılmaya ve **orijinal dilde** okunmaya
> devam eder; çeviriler hazır olunca kendiliğinden görünür. İlerleme:
> `$C logs -f libretranslate`.

## 7. İlk platform admin'i oluştur (seed YOK)

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  run --rm worker python -m scripts.create_admin --email admin@firmaniz.com
# Parola güvenli şekilde sorulur (ekranda görünmez, 8+ karakter, büyük harf+rakam+sembol).
```

> ⚠️ **`worker`, `api` değil.** Betik RLS'i bypass etmek için OWNER (superuser)
> bağlantısı ister; prod'da `api` servisine superuser DSN'i **bilinçli olarak
> verilmez** (internete bakan süreç yalnız RLS'e tabi `app_rw` taşır).
> `worker`/`beat` aynı imajdır ve `OWNER_DSN` taşır. (Tur 72'ye kadar burada
> `api` yazıyordu — prod'da `OWNER_DSN` tanımsız olduğu için komut
> "password authentication failed for user" ile düşerdi.)

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
| **Çeviri gelmiyor (içerik hep Türkçe)** | Beklenen olabilir: modeller inmemiş olabilir (`$C logs libretranslate`, `$C ps`). Kontrol: `$C exec api python -c "import urllib.request;print(urllib.request.urlopen('http://libretranslate:5000/languages').status)"` → 200 olmalı. `TRANSLATE_PROVIDER=libretranslate` mi? `worker` ayakta mı (çeviri işi orada koşar)? |
| **`ceviri_durumu: hata` kalıyor** | Motor erişilemiyor ya da model yok. İçerik **etkilenmez** (orijinal servis edilir). `$C logs worker` çeviri hatasını yazar; motor healthy olunca içerik düzenlenince (ya da yeniden kuyruklanınca) tekrar denenir. |
| **`migrate` exit 1, "column ... does not exist"** | §14. Veri kaybı yok (tek işlem, atomik geri alma); güncel kodu çekip `up -d` yeterli. |
| **create_admin "OWNER_DSN tanımsız"** | Komutu `api` değil **`worker`** ile çalıştırın (`run --rm worker ...`); OWNER_DSN yalnız worker/beat'te tanımlıdır. `--env-file .env.prod` verildiğinden emin olun. |


---

## 14. Şema uyumlama — "migrate exit 1" (bir kez yapılır)

**Belirti:** `docker compose ... up -d` sırasında
`service "migrate" didn't complete successfully: exit 1` ve migrate loglarında:

```
psycopg.errors.UndefinedColumn: column "cikis_zamani" does not exist
[SQL: CREATE INDEX IF NOT EXISTS ix_visitor_tenant_cikis ON visitor (...)]
File "/contracts/db/migrations/versions/0009_akis_indeksleri.py", line 65
```

**Sebep:** Prod göç ettikten sonra bazı şema eklemeleri, yeni revizyon yerine
mevcut revizyon dosyalarına **yerinde** yazılmıştı (bkz.
`docs/MIGRATION-POLITIKASI.md`). Alembic o revizyonları uygulanmış saydığı için
eklemeler prod'a hiç gitmedi.

**Veri durumu — önemli:** `env.py` tüm revizyonları **tek işlemde** koşar.
0009 patladığında aynı işlemdeki 0007/0008 de geri alındı. Yani **kısmi
uygulama yok**: veritabanınız hâlâ eski, tutarlı revizyonunda. Elle temizlik
gerekmiyor.

**Çözüm:** `0008b_uyum_yakalama` revizyonu (0008 ile 0009 arasında koşar)
eksikleri ekleyici ve idempotent biçimde tamamlıyor. Yapılacak tek şey güncel
kodu çekip `up -d` demek.

### 14.1 Komutlar (sırayla, kopyala-yapıştır)

```bash
cd /opt/yonetio/tesis-platform/infra
C="docker compose -f docker-compose.prod.yml --env-file .env.prod"
# Asagidaki psql komutlari $POSTGRES_USER / $POSTGRES_DB kullaniyor; yukle:
set -a; . ./.env.prod; set +a

# 1) TAZE YEDEK (bu dağıtımda alınmış olsa bile bir kez daha alın)
./backup.sh
ls -lt "${BACKUP_DIR:-/opt/yonetio/backups}" | head -3     # yeni dosya görünmeli

# 2) Mevcut revizyonu KAYDEDIN (sorun olursa referans)
$C run --rm migrate sh -c 'alembic -c /contracts/db/alembic.ini current'

# 3) Güncel kodu çek
cd /opt/yonetio/tesis-platform && git pull && cd infra

# 4) Uygula (migrate + servisler)
$C up -d --build

# 5) migrate 0 ile bitti mi?
$C ps migrate            # State: exited (0) olmalı
$C logs migrate | tail -25
```

### 14.2 Başarı doğrulaması (spot-check)

```bash
# a) Revizyon head'te mi
$C run --rm migrate sh -c 'alembic -c /contracts/db/alembic.ini current'
#    -> 0028_vezne_idempotency (head)
#
#    DIKKAT: buradaki ad SON revizyondur ve her yeni gocte DEGISIR. Sabit
#    bir ada bakip "esit mi" diye kontrol etmeyin; onemli olan ciktinin
#    "(head)" ile bitmesidir. (Bu satir bir kez 0010'da unutulmustu ve
#    18 revizyon boyunca yaniltici kaldi.)

# b) Eklenen TABLOLAR var mı (2 satır dönmeli)
$C exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc \
  "select tablename from pg_tables where schemaname='public'
     and tablename in ('vehicle_pass','violation') order by 1;"

# c) Eklenen KOLONLAR var mı (8 satır dönmeli)
#    NOT: (b)-(d) maddeleri, bu runbook'un ILK yazildigi gocun (vehicle_pass/
#    violation) spot-check'idir ve ORNEK olarak korunuyor. Her yeni gocte
#    ONUN eklediklerine bakin; asagidaki liste otomatik guncellenmiyor.
#    En son goc 0028 icin karsiligi:
#      select count(*) from information_schema.columns
#       where table_name='finansal_hareket'
#         and column_name in ('idempotency_key','idem_satir');   -- 2 donmeli
$C exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc \
  "select table_name||'.'||column_name from information_schema.columns
    where table_schema='public' and
      (table_name,column_name) in (('camera','tur'),('camera','aktif'),
        ('camera','konum'),('camera','sakin_gorebilir'),
        ('etkinlik','bitis_zamani'),('etkinlik','foto_key'),
        ('tenant','otopark_kapasite'),('visitor','cikis_zamani'))
    order by 1;"

# d) Yeni tablolar RLS altında mı (ikisi de enable=true force=true olmalı)
$C exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc \
  "select relname||' enable='||relrowsecurity||' force='||relforcerowsecurity
     from pg_class where relname in ('vehicle_pass','violation') order by 1;"

# e) VERİ YERİNDE mi (sayılar yedek öncesiyle aynı olmalı)
$C exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc \
  "select 'tenant='||(select count(*) from tenant)
       ||' app_user='||(select count(*) from app_user)
       ||' unit='||(select count(*) from unit)
       ||' scan_event='||(select count(*) from scan_event);"

# f) Uygulama ayakta mı
curl -sS https://api.yonetio.site/health          # {"status":"ok",...}
$C ps                                              # api & admin-web healthy
```

### 14.3 YAPILMAYACAKLAR

| ❌ Asla | Neden |
|---|---|
| `docker compose ... down -v` | `-v` **named volume'ları siler** → `pgdata` ve `miniodata` gider, yani tüm veritabanı ve fotoğraflar. Prod'da **hiçbir koşulda**. Servisleri durdurmak gerekirse `down` (v'siz) ya da `stop`. |
| `alembic downgrade ...` | Uyumlama ileri yönlüdür; geri almak eklenen kolonları düşürür. Gerekmiyor. |
| `alembic stamp head` | Revizyonu koşmadan "koşmuş" işaretler — eksik kolonlar eksik kalır ve sorun sessizleşir. |
| Tabloyu elle `DROP`/`CREATE` | Uyumlama zaten idempotent; elle müdahale şemayı revizyon geçmişinden ayırır. |
| Yedek almadan başlamak | §14.1 adım 1 atlanmaz. |

### 14.4 Bir şeyler ters giderse

`migrate` yine exit 1 verirse: **veri kaybı olmaz** (tek işlem, atomik geri
alma). Logları alın ve revizyonu bildirin:

```bash
$C logs migrate | tail -40
$C run --rm migrate sh -c 'alembic -c /contracts/db/alembic.ini current'
```

Geri yükleme gerekirse §10'daki "Geri yükleme" adımları geçerlidir.

### 14.5 Doğrulama kanıtı (dev'de koşuldu)

`infra/goc-uyum-dogrula.sh` iki yolu karşılaştırır:

* **A** taze veritabanı → güncel dosyalar → head
* **B** taze veritabanı → prod'un göç ettiği ağacın dosyaları → head, sonra
  güncel dosyalar → head (0008b burada koşar)

Sonuç: **1323 şema olgusunda fark yok.** İki farklı "eski ağaç" referansıyla
(`bf1dc84^` ve `f72467f`) ayrı ayrı doğrulandı; 0008b ikinci kez koşturulduğunda
da şema değişmedi (idempotent).

---

### İçindekiler (TOC)
0. Ön koşul: DNS · 1. Sunucu hazırlığı · 2. Docker kurulumu · 3. Repo klonlama ·
4. .env.prod · 5. FCM (ops.) · 6. Ayağa kaldırma · 7. İlk admin · 8. Duman testleri ·
9. Mobil APK · 10. Yedekleme cron · 11. Güncelleme · 12. Loglar · 13. Sorun giderme ·
14. Şema uyumlama ("migrate exit 1")
