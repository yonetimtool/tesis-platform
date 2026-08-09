# TEST SUNUCUSU — sıfırdan kurulum rehberi (AŞAMA A)

> **Bu belge canlı sunucuya (10.10.77.2) DOKUNMAZ.** Amacı, P142–P160
> çalışmasının koşacağı **ayrı** bir sunucuyu sıfır Ubuntu'dan çalışır hale
> getirmektir. Play kapalı testi mevcut canlı sistemle sürüyor; test
> sunucusu ondan **fiziksel ve mantıksal olarak ayrıdır**.

---

## 0. ÖN KOŞUL DOĞRULAMASI — göç 0040

**Durum: GEÇTİ.** `contracts/db/migrations/versions/0040_tetikleyici_search_path.py`
depoda mevcut ve göç zincirinin **başı** (head); `down_revision =
"0039_telefon_kodu_amaci"` ve kendisine bağlanan yeni bir revizyon yok.

İçeriği doğrulandı:

| Nesne | `SET search_path` | Nitelenmiş referans |
|---|---|---|
| `public.tenant_kayit_kodu_ata()` | `''` (boş) — fonksiyon gövdesine gömülü | `FROM public.tenant` ✔ |
| `public.kayit_kodu_uret(text, date)` | `''` — `ALTER FUNCTION ... SET search_path` | gövdede nitelenmemiş nesne yok ✔ |

Yani `create_tenant_with_yoneticis` → 500 `UndefinedTableError` sınıfı
kapalıdır ve tetikleyici **çağıranın search_path'inden bağımsızdır**.

Sunucuda göç koştuktan sonra bunu **kanıtla** (varsaymayın):

```bash
docker compose -f docker-compose.prod.yml --env-file .env.test -p yonetio-test \
  exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "SELECT p.proname, p.proconfig
     FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public'
      AND p.proname IN ('tenant_kayit_kodu_ata','kayit_kodu_uret');"
```

Beklenen: **iki satır**, her ikisinde `proconfig = {search_path=""}`.
`proconfig` NULL gelirse göç uygulanmamıştır — devam etmeyin.

---

## 1. KARAR: yeni compose dosyası YAZILMADI

**Seçenekler tartıldı:**

| Seçenek | Sonuç |
|---|---|
| (a) `docker-compose.test.yml` diye üçüncü bir dosya | **Reddedildi.** Bugün prod'un kopyası olur, yarın prod düzeltmesi ona işlenmez ve test sunucusu sessizce farklı bir yazılım koşar. Tam da "test ortamında çalıştı, prod'da patladı" sınıfını üretir. |
| (b) Mevcut `docker-compose.prod.yml` + **ayrı `.env.test` + ayrı proje adı** | **SEÇİLDİ.** Dosya zaten baştan sona ortam değişkeniyle parametrelenmiş (alan adları, sırlar, sağlayıcılar). Tek fark yapılandırmadır; kod tek kaynaktan gelir. |

`docker-compose.prod.yml` içinde `name: yonetio-prod` sabittir; test
sunucusunda **`-p yonetio-test`** bayrağıyla ezilir. Bu bayrak aşağıdaki
her komutta vardır — atlanırsa konteynerler `yonetio-prod` adıyla açılır
ve iki ortam log/isim düzeyinde karışır.

> **Kolaylık:** aşağıdaki komutlarda tekrarlanan üçlüyü bir kez tanımlayın.
> ```bash
> echo "alias dcT='docker compose -f /opt/yonetio/tesis-platform/infra/docker-compose.prod.yml --env-file /opt/yonetio/tesis-platform/infra/.env.test -p yonetio-test'" >> ~/.bashrc
> source ~/.bashrc
> ```

---

## 2. SUNUCU — paketler ve docker

Ubuntu 24.04 LTS (veya Debian 13) varsayılır. Kullanıcı `root` değil,
`sudo` yetkili bir hesap olsun.

```bash
# --- temel paketler ---
sudo apt-get update
sudo apt-get install -y ca-certificates curl git gnupg ufw openssl

# --- Docker Engine + compose eklentisi (resmi depo) ---
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# kullanıcıyı docker grubuna al (yeniden giriş gerekir)
sudo usermod -aG docker "$USER"
newgrp docker

docker --version && docker compose version   # ikisi de sürüm yazmalı
```

**Güvenlik duvarı** — yalnız 22/80/443:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp     # HTTP/3 (QUIC) — Caddy
sudo ufw --force enable
sudo ufw status verbose
```

**Kaynak notu:** `libretranslate` ilk kalkışta ~1–2 GB argos modeli indirir.
Sunucuda **en az 4 GB RAM ve 40 GB disk** olsun. Daha küçük bir makinede
`TRANSLATE_PROVIDER=noop` yapın (aşağıda ayrıca yazılı) — çeviri kapanır,
içerik yine yazılır.

---

## 3. DİZİN YAPISI VE DEPO

```bash
sudo mkdir -p /opt/yonetio
sudo chown "$USER":"$USER" /opt/yonetio
cd /opt/yonetio

git clone https://github.com/<kullanici>/tesis-platform.git
cd tesis-platform
git checkout main
git log --oneline -1        # hangi sürümü koştuğunuzu NOT EDİN
```

Oluşan yapı:

```
/opt/yonetio/
├── tesis-platform/          # depo (kod)
│   └── infra/
│       ├── docker-compose.prod.yml
│       ├── Caddyfile
│       ├── .env.test        # ← BU SUNUCUYA ÖZEL, repoya GİRMEZ
│       └── secrets/         # FCM json — TEST için AYRI dosya (bkz. §8)
└── backups/                 # BACKUP_DIR
```

```bash
mkdir -p /opt/yonetio/backups
```

---

## 4. `.env.test` — PROD SIRLARI KOPYALANMAZ

> **Kural:** canlı sunucudan hiçbir değer taşınmaz. Ne JWT anahtarı, ne DB
> parolası, ne MinIO kimliği, ne SDM_KEK. Aynı JWT sırrı iki ortamda
> olursa **test sunucusunda üretilen jeton canlıda geçerli olur** — bu tek
> başına bütün ayrımı çöpe atar.

### 4.1 Sırları ÜRET

```bash
cd /opt/yonetio/tesis-platform/infra
cp .env.prod.example .env.test
chmod 600 .env.test

# Üretilen değerleri ekrana bas — sonra .env.test içine yapıştırın.
echo "POSTGRES_PASSWORD=$(openssl rand -base64 36 | tr -d '\n')"
echo "APP_DB_PASSWORD=$(openssl rand -base64 36 | tr -d '\n')"
echo "JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')"
echo "SDM_KEK=$(openssl rand -base64 36 | tr -d '\n')"
echo "MINIO_ROOT_PASSWORD=$(openssl rand -base64 36 | tr -d '\n')"
echo "BACKUP_GPG_PASSPHRASE=$(openssl rand -base64 36 | tr -d '\n')"
echo "DEMO_PAROLA=$(openssl rand -base64 18 | tr -d '\n')"
```

> `tr -d '\n'` **gerekli**: `openssl rand -base64` uzun çıktıyı satır
> sonuyla kırpar; kırpılmış satır `.env` dosyasında ikinci bir anahtar
> gibi okunur ve parola sessizce yanlış olur.

Tek komutla doldurmak isterseniz:

```bash
cd /opt/yonetio/tesis-platform/infra
python3 - <<'PY'
import base64, os, pathlib, re
yol = pathlib.Path(".env.test")
m = yol.read_text(encoding="utf-8")
uret = lambda n: base64.b64encode(os.urandom(n)).decode()
for anahtar, n in [("POSTGRES_PASSWORD",27), ("APP_DB_PASSWORD",27),
                   ("JWT_SECRET",36), ("SDM_KEK",27),
                   ("MINIO_ROOT_PASSWORD",27), ("BACKUP_GPG_PASSPHRASE",27)]:
    m = re.sub(rf"(?m)^{anahtar}=.*$", f"{anahtar}={uret(n)}", m)
yol.write_text(m, encoding="utf-8")
print("sirlar uretildi; .env.test icindeki ALAN ADI ve SAGLAYICI satirlarini elle duzenleyin")
PY
```

### 4.2 `.env.test` içinde ELLE değiştirilecek satırlar

```dotenv
TZ=Europe/Istanbul

# --- ALAN ADLARI — canlıdan FARKLI olmalı -------------------------------- #
API_DOMAIN=api.test.yonetiyor.com
PANEL_DOMAIN=panel.test.yonetiyor.com
STORAGE_DOMAIN=storage.test.yonetiyor.com
PORTAL_DOMAIN=test.yonetiyor.com
# IDN ve ESKİ alan blokları TEST'te KULLANILMAZ; canlının adlarını buraya
# yazmayın. Caddy bu değişkenleri okuyor, boş bırakılamaz: test alan adının
# KENDİSİNİ yazın ki blok kendine 301 atsın (zararsız, çakışma üretmez).
PORTAL_DOMAIN_IDN=test.yonetiyor.com
PANEL_DOMAIN_ESKI=panel.test.yonetiyor.com
PANEL_DOMAIN_IDN=panel.test.yonetiyor.com
PORTAL_DOMAIN_ESKI=test.yonetiyor.com

ACME_EMAIL=<sizin-adresiniz>@gmail.com

# --- Postgres ------------------------------------------------------------ #
POSTGRES_USER=tesis_owner
POSTGRES_DB=tesis
# POSTGRES_PASSWORD / APP_DB_PASSWORD → §4.1'de üretildi
APP_DB_USER=app_rw

# --- CORS ---------------------------------------------------------------- #
CORS_ORIGINS=https://panel.test.yonetiyor.com

# --- Portal ------------------------------------------------------------- #
PORTAL_BASE_URL=https://test.yonetiyor.com

# --- MinIO --------------------------------------------------------------- #
MINIO_ROOT_USER=yonetio_test_minio
MINIO_BUCKET=tesis-foto-test
MINIO_PUBLIC_URL=https://storage.test.yonetiyor.com

# --- PUSH: TEST'te KAPALI (bkz. §8 — canlı ile karışma riski) ------------ #
PUSH_PROVIDER=noop
FCM_PROJECT_ID=
FCM_SERVICE_ACCOUNT_PATH=/secrets/fcm-service-account.json

# --- SMS: TEST'te LOG (Netgsm hesabı canlı ile ORTAK — bkz. §8) ---------- #
# Hiçbir SMS_* verilmezse sağlayıcı LOG'dur: mesaj gönderilmez, günlüğe yazılır.
SMS_SAGLAYICI=
SMS_KULLANICI=
SMS_PAROLA=
SMS_BASLIK=

# --- Ödeme: TEST'te manuel ----------------------------------------------- #
PAYMENT_PROVIDER=manual
IYZICO_API_KEY=
IYZICO_SECRET=
PAYTR_MERCHANT_ID=
PAYTR_MERCHANT_KEY=
PAYTR_MERCHANT_SALT=

# --- Yedek --------------------------------------------------------------- #
BACKUP_DIR=/opt/yonetio/backups

# --- Çeviri -------------------------------------------------------------- #
# 4 GB'ın altındaki bir makinede: TRANSLATE_PROVIDER=noop
TRANSLATE_PROVIDER=libretranslate
TRANSLATE_URL=http://libretranslate:5000
TRANSLATE_LANGS=tr,en,ar,ru,de,fr,es
```

**Doğrulama — canlı sır sızmadığından emin olun:**

```bash
# Canlıya ait bilinen alan adları .env.test'te GEÇMEMELİ (test.* hariç).
grep -nE 'yonetio\.site|xn--ynetiyor|^PORTAL_BASE_URL=https://yönetiyor' .env.test \
  && echo ">>> DUR: canli deger kalmis" || echo "temiz"
# DEGISTIR_ ile başlayan yer tutucu kalmamalı.
grep -n 'DEGISTIR_' .env.test && echo ">>> DUR: uretilmemis sir var" || echo "sirlar dolu"
```

---

## 5. DNS VE CADDY (sertifika)

### Karar: gerçek alt alan adı + Let's Encrypt

**Seçenekler:** (a) ayrı alan adı satın al, (b) `yonetiyor.com` altında
`test.` alt alanı, (c) DNS yok — Caddy iç CA (`tls internal`).

**(b) seçildi.** (a) para ve bekleme demek; (c) her istemcide elle kök
sertifika kurmayı gerektirir ve **mobil uygulama TLS'i reddeder**, yani
cihaz testi imkânsızlaşır. (b) tek DNS kaydıyla gerçek sertifika verir ve
üretimle **aynı** TLS yolunu kullanır — bulacağınız hatalar gerçek.

> **Aynı kayıtlı alan adı bir risk mi?** Çerezler bu kod tabanında
> **host-only** yazılıyor (`Domain=` niteliği verilmiyor), dolayısıyla
> `test.yonetiyor.com` çerezi `yonetiyor.com`a gitmez. Yine de §8'de
> "çerez alanı" maddesi olarak izlenecekler listesindedir.

### DNS kayıtları (alan adı sağlayıcınızda)

Dördü de **test sunucusunun genel IP'sine** bakan A kaydı:

| Ad | Tip | Değer |
|---|---|---|
| `test` | A | `<TEST_SUNUCU_IP>` |
| `api.test` | A | `<TEST_SUNUCU_IP>` |
| `panel.test` | A | `<TEST_SUNUCU_IP>` |
| `storage.test` | A | `<TEST_SUNUCU_IP>` |

Yayılmayı bekleyin ve **kanıtlayın** (Let's Encrypt DNS doğru değilse
sertifika vermez ve Caddy sessizce yeniden dener):

```bash
for h in test api.test panel.test storage.test; do
  printf '%-22s %s\n' "$h.yonetiyor.com" "$(dig +short $h.yonetiyor.com | tail -1)"
done
```

Dördü de test sunucusunun IP'sini yazmalı. **Biri bile canlının IP'sini
yazıyorsa DURUN** — o alt alan canlıya trafik gönderir.

### Caddy ön kontrolü

Depoda hazır betik var; kaldırmadan önce koşun:

```bash
cd /opt/yonetio/tesis-platform
set -a; . infra/.env.test; set +a
bash infra/caddy-onkontrol.sh
```

---

## 6. KALDIRMA, GÖÇLER, SEED

### 6.1 Kaldır

```bash
cd /opt/yonetio/tesis-platform/infra
docker compose -f docker-compose.prod.yml --env-file .env.test -p yonetio-test \
  up -d --build
```

İlk kalkış imaj derlemesi + libretranslate model indirmesi yüzünden uzun
sürer. Takip:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.test -p yonetio-test ps
docker compose -f docker-compose.prod.yml --env-file .env.test -p yonetio-test logs -f caddy
```

### 6.2 Göçler

Göçler ayrı bir **`migrate`** tek-atımlık servisinde koşar
(`alembic -c /contracts/db/alembic.ini upgrade head`, ardından
`setup_app_role.py`); `api` ona bağımlıdır. **Doğrulayın** (varsaymayın):

```bash
DC="docker compose -f docker-compose.prod.yml --env-file .env.test -p yonetio-test"

# migrate servisi hatasız bitmiş mi?
$DC logs migrate | tail -20

# uygulanan revizyon — veritabanından OKUNUR (yorum değil, olgu)
set -a; . .env.test; set +a
$DC exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "SELECT version_num FROM alembic_version;"
```

Beklenen: `0040_tetikleyici_search_path`. Ardından §0'daki `proconfig`
sorgusunu koşun.

### 6.3 Seed — TAMAMEN UYDURMA VERİ

> **KVKK:** canlı veritabanından **hiçbir satır** kopyalanmaz. Aşağıdaki
> iki betik veriyi **kodun içinden** üretir; gerçek kişi verisi içermez.

```bash
cd /opt/yonetio/tesis-platform/infra
DC="docker compose -f docker-compose.prod.yml --env-file .env.test -p yonetio-test"

# (1) Ana test tesisi + bloklar + daireler + her rolden kullanıcı +
#     örnek duyuru/görev/aidat/NFC noktası.
$DC run --rm worker python -m scripts.seed

# (2) Demo tesisi (kilitli kural 2'deki hesaplar). DEMO_PAROLA ZORUNLU:
#     verilmezse betik erken ve net patlar (bilerek — sabit parola
#     bırakmak herkesin bildiği bir hesap demekti).
$DC run --rm -e DEMO_PAROLA='<§4.1de-uretilen-DEMO_PAROLA>' \
  worker python -m scripts.demo_tenant
```

`worker` seçildi, `api` değil: `OWNER_DSN` (superuser) yalnız
`worker`/`beat` konteynerlerinde tanımlıdır; `api`'ye bilinçli olarak
verilmez.

### 6.4 Seed'in oluşturduğu HESAPLAR VE PAROLALAR

**`scripts/seed.py` — ana test tesisi.** Parolalar ortam değişkeniyle
ezilebilir; ezilmezse aşağıdaki varsayılanlar geçerlidir.

| Rol | E-posta | Telefon | Parola | Ezme değişkeni |
|---|---|---|---|---|
| `admin` | (seed.py'deki admin kaydı) | `+905321112200` | `Admin123!` | `SEED_ADMIN_PASSWORD` |
| `yonetici` | — | `+905321112201` | `Yonetici123!` | `SEED_YONETICI_PASSWORD` |
| `yonetici` (2.) | — | `+905321112207` | `Yonetici123!` | `SEED_YONETICI2_PASSWORD` |
| `security` | — | `+905321112202` | `Guard123!` | `SEED_GUARD_PASSWORD` |
| `tesis_gorevlisi` | — | `+905321112204` | `Clean123!` | `SEED_CLEANER_PASSWORD` |
| `resident` (daire `A-12`) | — | `+905321112203` | `Resident123!` | `SEED_RESIDENT_PASSWORD` |
| `resident` (3.) | — | `+905321112205` | `Resident123!` | `SEED_RESIDENT3_PASSWORD` |
| `resident` (2.) | — | `+905321112206` | **parola YOK** — `unit_no=A-12` + tek seferlik geçici kod ile parola belirleme akışı | — |

> Test sunucusunda bu varsayılanları **ezin**; sunucu internete açık:
> ```bash
> $DC run --rm \
>   -e SEED_ADMIN_PASSWORD="$(openssl rand -base64 18 | tr -d '\n')" \
>   -e SEED_YONETICI_PASSWORD="$(openssl rand -base64 18 | tr -d '\n')" \
>   worker python -m scripts.seed
> ```
> Ürettiğiniz değerleri parola yöneticinize yazın; ekranda bir kez görünür.

**`scripts/demo_tenant.py` — demo tesisi.** Beşinin de parolası **tek**
`DEMO_PAROLA` değeridir.

| Ad | E-posta | Rol | Telefon |
|---|---|---|---|
| Demo Yönetici | `yonetici@demo.yonetio.site` | `yonetici` | `+905000000101` |
| Demo Güvenlik | `guvenlik@demo.yonetio.site` | `security` | `+905000000102` |
| Demo Görevli | `gorevli@demo.yonetio.site` | `tesis_gorevlisi` | `+905000000103` |
| Demo Sakin | `sakin@demo.yonetio.site` | `resident` | `+905000000104` |
| Demo Güvenlik Amiri | `amir@demo.yonetio.site` | `guvenlik_amiri` | `+905000000105` |

### 6.5 ⚠ BULGU — `+905777777777` denetçi hesabı depoda YOK

Kilitli kural 2 beş hesap sayıyor ve beşincisi `+905777777777 denetci`.
**Bu hesap hiçbir betikte yok**; canlıda elle açılmış
(`docs/MASTER-PLAN.md:9293` bunu zaten "depoda YOK — elle açılmış" diye
kaydetmiş). Ayrıca briefteki `...103 tesis_gorevlisi` eşleşmesi doğru,
fakat koddaki beşinci hesap `+905000000105 guvenlik_amiri`'dir — brief
onu saymıyor.

**Karar:** test sunucusunda denetçi hesabı **elle** açılır (canlıya
dokunulmaz). `demo_tenant.py`'ye kalıcı olarak eklemek ayrı bir iştir ve
canlıyı da etkileyeceği için bu turda **yapılmadı**:

```bash
$DC run --rm worker python - <<'PY'
import os, psycopg
from app.security import hash_password
parola = os.environ["DENETCI_PAROLA"]
with psycopg.connect(os.environ["OWNER_DSN"]) as c, c.cursor() as k:
    k.execute("SELECT id FROM tenant ORDER BY created_at LIMIT 1")
    tid = k.fetchone()[0]
    k.execute("""
        INSERT INTO app_user (tenant_id, ad, email, password_hash, password_set,
                              role, is_active, telefon, aranabilir, birincil)
        VALUES (%s,'Test Denetçi','denetci@test.yonetiyor.com',%s,true,
                'denetci'::user_role,true,'+905777777777',false,false)
        ON CONFLICT (telefon) DO UPDATE
          SET password_hash = EXCLUDED.password_hash, password_set = true
    """, (tid, hash_password(parola)))
    c.commit()
print("denetci hesabi acildi")
PY
```

Çağırırken `-e DENETCI_PAROLA='<uretilen>'` verin.

---

## 7. `noindex` — arama motoru test sunucusunu indekslemesin

İki katman, çünkü **`robots.txt` tek başına yetmez**: `robots.txt`
taramayı engeller ama başka bir sitenin verdiği bağlantı üzerinden URL
yine de dizine girebilir. `X-Robots-Tag` yanıtın kendisinde durur ve
"dizine ekleme"yi açıkça söyler.

### 7.1 `X-Robots-Tag` — Caddy

`infra/Caddyfile` içindeki `(security_headers)` bloğu tüm konaklara
`import` edilir. Test sunucusunda **yalnız bu sunucudaki kopyaya** şu satırı
ekleyin (depoya commit **edilmez** — canlıya sızmamalı):

```bash
cd /opt/yonetio/tesis-platform
python3 - <<'PY'
import pathlib
y = pathlib.Path("infra/Caddyfile"); m = y.read_text(encoding="utf-8")
if "X-Robots-Tag" not in m:
    m = m.replace("(security_headers) {\n\theader {",
                  "(security_headers) {\n\theader {\n\t\t# TEST SUNUCUSU — depoya girmez\n\t\tX-Robots-Tag \"noindex, nofollow, noarchive\"",
                  1)
    y.write_text(m, encoding="utf-8"); print("eklendi")
else:
    print("zaten var")
PY
```

> Bu yerel değişikliği git'ten gizleyin ki `git pull` çakışmasın:
> ```bash
> git update-index --skip-worktree infra/Caddyfile
> # geri almak için: git update-index --no-skip-worktree infra/Caddyfile
> ```

### 7.2 `robots.txt`

`infra/portal/` dizini Caddy'ye `/srv/portal` olarak salt-okunur bağlanır:

```bash
cat > /opt/yonetio/tesis-platform/infra/portal/robots.txt <<'EOF'
User-agent: *
Disallow: /
EOF
git update-index --skip-worktree infra/portal/robots.txt 2>/dev/null || true
```

### 7.3 Doğrula

```bash
curl -sI https://panel.test.yonetiyor.com | grep -i x-robots-tag
curl -s  https://test.yonetiyor.com/robots.txt
```

İlki `noindex, nofollow, noarchive`, ikincisi `Disallow: /` yazmalı.

---

## 8. ⚠ CANLI İLE KARIŞMA RİSKİ — ayrılan ve ayrılamayan şeyler

Aşağıdaki her satır **paylaşılan bir dış kaynağı** anlatır. Test sunucusu
kendi veritabanına sahip olduğu için "veri karışması" yok; risk
**üçüncü taraf hesaplarında**.

| # | Paylaşılan kaynak | Risk | Kararı / önlem |
|---|---|---|---|
| 1 | **FCM projesi** (`infra/secrets/fcm-service-account.json`) | Aynı proje kullanılırsa test sunucusu **canlı testçilerin cihazlarına** push atar. Jetonlar cihaza değil kullanıcıya bağlı; aynı cihaz iki ortama kayıt olursa jeton çakışır. | **`PUSH_PROVIDER=noop` ile TEST'te push KAPALI.** Push akışı denenecekse Firebase'de **ayrı bir proje** açın, servis hesabı JSON'unu `infra/secrets/` altına **farklı adla** koyup `FCM_SERVICE_ACCOUNT_PATH` ile gösterin. Canlının JSON'unu **kopyalamayın**. |
| 2 | **Push jetonu / `user_device` kaydı** | Aynı fiziksel telefon hem canlı hem test uygulamasına giriş yaparsa aynı FCM jetonu iki `user_device` satırı üretir; canlı bildirim test cihazına düşebilir. | Test için **ayrı cihaz veya ayrı emülatör profili** kullanın. Aynı cihaz kullanılacaksa test derlemesinden önce canlı uygulamayı kaldırın. |
| 3 | **Netgsm SMS hesabı** | Tek Netgsm aboneliği var. Test gönderimi **canlı kredisini harcar**, onaylı başlıkla **gerçek numaralara** SMS gider ve gönderim kotası canlıyla ortak sayılır. | **`SMS_SAGLAYICI` boş → sağlayıcı `LOG`.** Mesaj gönderilmez, günlüğe yazılır; akış uçtan uca denenebilir. Gerçek SMS gerekiyorsa Netgsm'den **ikinci bir alt kullanıcı/başlık** isteyin, canlının kimliğini kullanmayın. |
| 4 | **OAuth geri dönüş adresleri** (Aşama 4) | Google/Microsoft/Apple istemcileri geri dönüş adresini **tam eşleşmeyle** doğrular. Canlı istemciye test adresi eklenirse **canlı istemcinin yapılandırması test için değiştirilmiş** olur. | Her sağlayıcıda **AYRI OAuth istemcisi** açılacak (test istemcisi). Geri dönüş adresleri: `https://panel.test.yonetiyor.com/api/auth/<saglayici>/callback` ve `https://api.test.yonetiyor.com/auth/<saglayici>/callback`. Ayrıntı: Aşama 4 raporu. |
| 5 | **Apple paket kimliği / Play paket adı** (`com.app.yonetiyor`) | Aynı `applicationId` ile test derlemesi yüklenirse cihazdaki **canlı uygulamanın üzerine yazar** ve testçinin oturumu düşer. | **Build numarası ve `applicationId` DEĞİŞTİRİLMEYECEK** (kilitli kural 6). Test cihazına yalnız `flutter build apk --debug` çıktısı **elle** yüklenir; imzası farklı olduğu için Play sürümünün üzerine yazamaz — önce canlı uygulamayı kaldırmak gerekir. Play'e **hiçbir şey yüklenmez**. |
| 6 | **Ödeme sağlayıcı (iyzico/PayTR)** | Canlı anahtarla test **gerçek para** hareketi üretir. | `PAYMENT_PROVIDER=manual`. Sağlayıcı denenecekse sağlayıcının **sandbox** kimliği alınır. |
| 7 | **Let's Encrypt oran sınırı** | Aynı kayıtlı alan adı (`yonetiyor.com`) altında haftada 50 sertifika sınırı **ortaktır**. Test sunucusunda tekrar tekrar kaldırıp indirmek canlının yenilemesini engelleyebilir. | Caddy `caddy_data` volume'unu **silmeyin** (sertifikalar orada kalır). Yeniden kurulum denemeleri için önce `acme-staging-v02.api.letsencrypt.org` kullanın. |
| 8 | **Çerez alanı** | Aynı kayıtlı alan adı; çerezler bu kod tabanında host-only yazılıyor, dolayısıyla bugün sızmıyor. | Aşama 3/4'te oturum çerezine `Domain=` niteliği **eklenmeyecek**. Eklenirse test çerezi canlıya taşar. |
| 9 | **Yedekleme dizini / GPG parolası** | Aynı parola kullanılırsa test yedeği canlı yedeğiyle karışabilir. | `BACKUP_GPG_PASSPHRASE` §4.1'de **ayrı** üretildi; `BACKUP_DIR` bu sunucuya yerel. |
| 10 | **`storage.` presign host'u** | MinIO bucket adı aynı olursa hangi ortamın nesnesi olduğu ayırt edilemez. | `MINIO_BUCKET=tesis-foto-test` (canlıda `tesis-foto`). |

---

## 9. MOBİL UYGULAMAYI TEST SUNUCUSUNA BAĞLAMA

Base URL **derleme zamanında** `--dart-define` ile gömülür
(`mobile/lib/src/core/config/app_config.dart`). Çalışma zamanında
değiştirilemez — P153'te tam da bu yüzden pakete emülatör adresi gömülmüştü.

```bash
cd /opt/yonetio/tesis-platform/mobile   # veya geliştirme makinenizde

flutter build apk --debug \
  --dart-define=API_BASE_URL=https://api.test.yonetiyor.com \
  --dart-define=WEB_BASE_URL=https://test.yonetiyor.com
```

Cihaza yükleme:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Geliştirme sırasında doğrudan koşmak için:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.test.yonetiyor.com \
  --dart-define=WEB_BASE_URL=https://test.yonetiyor.com
```

> **`mobile/yayin-yap.sh` KULLANILMAZ.** O betik Play'e giden **imzalı
> release AAB** üretir ve `versionCode`a dokunur — kilitli kural 6 bunu
> yasaklıyor. Test için yalnız `--debug` derlemesi.

**Gömülü adresi kanıtlayın** (P153'ün dersi — varsaymayın):

```bash
unzip -p build/app/outputs/flutter-apk/app-debug.apk \
  assets/flutter_assets/kernel_blob.bin 2>/dev/null \
  | strings | grep -o 'https://[a-z.]*yonetiyor.com' | sort -u
```

`api.test.yonetiyor.com` görünmeli; `api.yonetiyor.com` **görünmemeli**.

---

## 10. KURULUM SONRASI DOĞRULAMA LİSTESİ

```bash
cd /opt/yonetio/tesis-platform/infra
DC="docker compose -f docker-compose.prod.yml --env-file .env.test -p yonetio-test"

# 1 — tüm servisler ayakta
$DC ps

# 2 — API sağlık
curl -s https://api.test.yonetiyor.com/health

# 3 — göç başı (alembic_version tablosundan)
set -a; . .env.test; set +a
$DC exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "SELECT version_num FROM alembic_version;"           # 0040_...

# 4 — tetikleyici search_path (§0 sorgusu)

# 5 — panel açılıyor
curl -sI https://panel.test.yonetiyor.com | head -1      # 200 ya da 307

# 6 — noindex
curl -sI https://panel.test.yonetiyor.com | grep -i x-robots-tag
curl -s  https://test.yonetiyor.com/robots.txt

# 7 — giriş çalışıyor (demo yönetici)
curl -s -X POST https://api.test.yonetiyor.com/auth/login-phone \
  -H 'content-type: application/json' \
  -d '{"phone":"+905000000101","password":"<DEMO_PAROLA>"}' | head -c 200
# Gövde alanı `phone` (Türkçe `telefon` DEĞİL) — schemas.PhoneLoginRequest.

# 8 — CANLIYA HİÇBİR ŞEY GİTMEDİ
$DC config | grep -iE 'yonetio\.site|xn--ynetiyor' && echo ">>> DUR" || echo "temiz"
```

---

## 11. KEREM'İN YAPMASI GEREKENLER (dış işler)

1. **Sunucu sağla** — Ubuntu 24.04, ≥4 GB RAM, ≥40 GB disk, genel IP,
   80/443 açık. IP'yi bana bildirin.
2. **DNS** — §5'teki dört A kaydını ekleyin.
3. **Parolalar** — §4.1 ve §6.4'te üretilen değerleri parola yöneticisine
   kaydedin.
4. **Firebase** (push denenecekse) — ayrı bir test projesi açın.
5. **Netgsm** (gerçek SMS denenecekse) — ikinci alt kullanıcı/başlık talep
   edin. Aksi hâlde bir şey yapmayın; `LOG` sağlayıcı yeterli.
6. **OAuth** — Aşama 4 raporundaki konsol adımları.

---

## 12. NE YAPILMADI (dürüst kayıt)

* **Sunucu kurulmadı.** Bu belge rehberdir; henüz bir makine yok, dolayısıyla
  **hiçbir komut gerçek bir sunucuda koşturulmadı**. Komutlar depodaki
  `docker-compose.prod.yml`, `Caddyfile`, `.env.prod.example`,
  `scripts/seed.py`, `scripts/demo_tenant.py` ve `app_config.dart`
  okunarak yazıldı; her biri o dosyalardaki gerçek anahtar adlarına
  dayanıyor.
* **Canlı sunucuya bağlanılmadı.** Geliştirme makinesinden canlıya SSH
  yok (yalnız 80/443 açık) — bu bilinen bir kısıt.
* **`robots.txt` ve `X-Robots-Tag` depoya commit edilmedi.** Bilerek:
  ikisi de canlıda **istenmeyen** davranıştır; test sunucusunda yerel
  değişiklik olarak durur (§7'deki `skip-worktree` ile).
