# DUKKAN F1 — DAĞITIM NOTU

> **Prod'a sen alacaksın.** Bu belge ne değiştiğini, hangi sırayla
> uygulanacağını ve **nasıl doğrulanacağını** yazıyor.
>
> F1 kullanıcıya görünen bir özellik getirmiyor: `dukkan.yonetiyor.com` henüz
> yayına açılmıyor. Getirdiği şey **altyapı ve bir güvenlik sınırı**.

---

## 1. Yeni ortam değişkenleri — **prod'da ZORUNLU**

`.env.prod` dosyasına eklenecek:

```
DUKKAN_DB_USER=dukkan_app
DUKKAN_DB_PASSWORD=<güçlü, YENİ bir parola üret>
```

**Bunlar `:?zorunlu` işaretli** (`docker-compose.prod.yml`): eksikse compose
**hata verip durur**, sessizce dev varsayılanına düşmez.

Bu bilinçli. Dev'de `dev-dukkan-parola-degistir` varsayılanı var; prod'da aynı
varsayılana düşmek, "Dukkan Yönetiyor verisine erişemez" kısıtının parolasını
**herkesin bildiği bir değere** bırakmak olurdu.

> **Caddy TLS dersi (hafızadaki kayıt):** `{$CADDY_TLS}` bozuk değildi;
> değişken sunucuda **boş** geliyordu ve boş genişleme sessizce ACME'ye
> düşürüyordu. `:?` işareti tam olarak o sınıf sessiz düşüşü engelliyor.

---

## 2. Uygulama sırası

```bash
# 1) Kod
git pull

# 2) İmajları kur — KISMİ BUILD YAPMA.
#    `contracts/` canlı mount, `backend/` imaja gömülü; yeni göç dosyası
#    eski kodla karşılaşınca ZİNCİR KOMPLE DÜŞER ve api/admin-web/worker
#    hiç başlamaz (üçü de migrate'e `service_completed_successfully` ile
#    bağlı). P213'te 0107 bunu yaşattı.
docker compose -f docker-compose.prod.yml build migrate api admin-web worker beat

# 3) Göç + rol kurulumu (0113, 0114 + setup_dukkan_role.py)
docker compose -f docker-compose.prod.yml up migrate

# 4) Servisleri yenile.
#    `restart` YETMEZ: ortam değişkenlerini tazelemez (P215'te ölçüldü —
#    konteyner eski MTX_HLSVARIANT ile koşmaya devam etmişti).
docker compose -f docker-compose.prod.yml up -d --force-recreate api worker beat
```

---

## 3. Doğrulama — **kritik olan bu bölüm**

### 3.1 Göç ve rol kurulumu geçti mi

`migrate` çıktısında **şu satır görünmeli**:

```
[setup_dukkan_role] 'dukkan_app' hazır: 'dukkan' şemasında DML, 'public' şemasında SIFIR yetki (doğrulandı)
```

Betik kendi işini **kendi doğruluyor**: `public` şemasında kalan bir tablo
yetkisi bulursa **hata verip çıkıyor** (exit 1). "Kaydedildi" deyip hiçbir şey
yapmamak bu depoda P217'de ölçülmüş bir kusur sınıfı.

### 3.2 SINIR gerçekten duruyor mu — **atlama**

Bu, F1'in bütün anlamı. Prod'da elle doğrula:

```bash
# BEKLENEN: permission denied for table app_user
docker compose -f docker-compose.prod.yml exec db \
  psql "postgresql://dukkan_app:$DUKKAN_DB_PASSWORD@localhost:5432/$POSTGRES_DB" \
  -c "SELECT count(*) FROM public.app_user;"

# BEKLENEN: permission denied for table tenant
docker compose -f docker-compose.prod.yml exec db \
  psql "postgresql://dukkan_app:$DUKKAN_DB_PASSWORD@localhost:5432/$POSTGRES_DB" \
  -c "SELECT count(*) FROM public.tenant;"

# BEKLENEN: 0
docker compose -f docker-compose.prod.yml exec db \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT count(*) FROM information_schema.table_privileges
   WHERE grantee='dukkan_app' AND table_schema='public';"
```

**Üçünden biri beklenenden farklıysa dur ve bildir.** Kısıt delinmiş demektir.

### 3.3 Lokasyon ve kategori verisi

Göç tabloları **oluşturur ama doldurmaz**. Veri yüklemesi ayrı ve **elle**.

> **Lokasyon dosyası DEPODA.** `contracts/veri/tr-lokasyon.json` —
> indirmene gerek yok, `docker cp` de gerekmiyor. `contracts/` hem
> `migrate` hem `api` konteynerine `:ro` mount'lu, dosya konteynerin
> içinde `/contracts/veri/tr-lokasyon.json` yolunda görünüyor.
>
> İlk yazdığım dağıtım notu operatörden dosyayı **indirmesini** istiyordu
> ve bu yanlıştı: ham dosya GitHub'da `master` dalında duruyor, üstteki
> depo onu her an değiştirebilir. "İndir" talimatı, prod'a dev'de
> **doğrulanmamış** bir veri gitmesi demekti — ve fark ancak binlerce SEO
> yolu üretildikten sonra görünürdü. Kaynak, lisans (MIT), indirme tarihi
> ve sha256 `contracts/veri/README.md`'de yazılı.

```bash
docker compose -f docker-compose.prod.yml exec api \
  python -m app.dukkan.lokasyon_yukle /contracts/veri/tr-lokasyon.json
# BEKLENEN: {'il': 81, 'ilce': 973, 'mahalle': 44719, 'atlanan': 29728, 'slug_cakisma': 0}

docker compose -f docker-compose.prod.yml exec api \
  python -m app.dukkan.kategori_yukle
# BEKLENEN: {'ana': 12, 'alt': 51}
```

**Dosyanın doğruluğunu teyit etmek istersen** (gerekmiyor, git zaten
garanti ediyor):

```bash
docker compose -f docker-compose.prod.yml exec api \
  sha256sum /contracts/veri/tr-lokasyon.json
# BEKLENEN: defbf445b2169c16417a27a7b4bf9149da2e97bea82abac9663e5f4f4573c695
```

**Türkçe karakter onarımı için ayrı bir komut YOK.** Onarım
`app/dukkan/lokasyon_yukle.py` içindeki `_onar()` fonksiyonunda ve
yükleme sırasında **otomatik** uygulanıyor. Dosyayı elle onarma: onarılmış
bir dosya yüklenirse `_onar()` ikinci kez çalışır ve adları yeniden bozar.

İkisi de **idempotent**: tekrar koşturmak zarar vermez, `ON CONFLICT` ile
günceller. İkisi de **sıfır kayıtta hata verir** (exit 1), sessizce geçmez.

Yükleme sonrası veri kalitesi kontrolü:

```bash
# BEKLENEN: 0  (birleşen nokta taşıyan bozuk ad kalmamalı)
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -tAc \
  "SELECT count(*) FROM dukkan.mahalle WHERE ad LIKE '%'||chr(775)||'%';"

# BEKLENEN: >5000  (ters yönlü kanıt: 'ı' harfi geri gelmiş olmalı)
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -tAc \
  "SELECT count(*) FROM dukkan.mahalle WHERE ad LIKE '%ı%';"
```

İkinci sorgu **ters yönlü kanıt**: ilki veri boş olsaydı da 0 döndürürdü.

### 3.4 Uçlar ayakta mı

```bash
curl -s https://api.yonetiyor.com/dukkan/lokasyon/il | head -c 200
curl -s https://api.yonetiyor.com/dukkan/kategori | head -c 200
curl -s "https://api.yonetiyor.com/dukkan/lokasyon/il/istanbul/ilce/cekmekoy/mahalle?q=catal"
# Sonuncusu Çatalmeşe döndürmeli — Türkçe harfsiz arama da çalışmalı
```

---

## 4. `dukkan-web` bu turda DAĞITILMIYOR

`apps/dukkan-web` depoya girdi ve derleniyor, ama:

- `docker-compose.prod.yml`'ye **servis eklenmedi**,
- Caddy'ye `dukkan.yonetiyor.com` bloğu **eklenmedi**,
- DNS kaydı **gerekmiyor**.

Sebep: F1'de gösterilecek bir ürün yok (işletmeler F2'de geliyor). Boş bir
siteyi yayına açmak, arama motoruna içeriksiz bir alan adı tanıtmak olurdu —
`05-seo.md` §3'te uzun uzun anlatılan **ince içerik** riskinin ta kendisi.

> **P215 dersi burada bekliyor:** `dukkan-web` servisi eklendiğinde
> `networks: [tesisnet]` **mutlaka** yazılacak. `mediamtx`'i ağa eklemeyi
> unuttuk ve hata prod'a kadar gitti. Servis eklendiğinde bu belgeye
> **ağ doğrulama komutu** da eklenecek.

---

## 5. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade 0112_sikayet_harita_saat
```

`downgrade` `dukkan` şemasını CASCADE düşürür ve `dukkan_app` rolünü siler.
**Yönetiyor verisine dokunmaz** — zaten dokunamaz; ayrı şema ve rol olmasının
bir yan faydası da bu: Dukkan'ı geri almak Yönetiyor için risksiz.

Geri alındıktan sonra `.env.prod`'daki `DUKKAN_*` değişkenleri kalabilir;
`migrate` onları yalnızca `dukkan` şeması varsa kullanır (yoksa hata verir ve
bu doğrudur — sessizce atlamak "kuruldu" yanılgısı üretirdi).

---

## 6. Risk değerlendirmesi

| Risk | Değerlendirme |
|---|---|
| Yönetiyor verisine etki | **Yok.** Yeni şema + yeni rol; mevcut tablolara DDL yok |
| Mevcut uçlara etki | **Yok.** Yalnız 4 yeni `/dukkan/*` ucu eklendi |
| Bağlantı havuzu | **Küçük artış.** Dukkan havuzu `pool_size=3, overflow=2` — bilerek küçük (P187'de idle-in-transaction 90/100 ölçülmüştü). SEO trafiği ölçülene kadar büyütülmeyecek |
| Disk | ~45.000 satır lokasyon — birkaç MB |
| Göç süresi | Tablolar boş oluşturulur, saniyeler. Veri yüklemesi ayrı ve dev'de ~25 saniye sürdü |
