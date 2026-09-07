# DUKKAN F4 — DAĞITIM NOTU

> F4 = **talep tarafı**: talep oluşturma + KVKK paylaşım tercihleri, teklif
> akışı, iş kabulü ve **adresin açılması**. Web + mobil.
>
> Bu fazla birlikte ürün **uçtan uca çalışır** hâle geliyor: kullanıcı talep
> açıyor, işletme teklif veriyor, iş veriliyor. `dukkan.yonetiyor.com` yine
> de açılmıyor — F5 (yorum/güven) olmadan pazar yerinin güven katmanı eksik.

---

## 1. Yeni ortam değişkeni

**Yok.**

---

## 2. Göç

**`0118_dukkan_talep_teklif_is`**

- `dukkan.talep` — `paylas_ad` / `paylas_telefon` / `paylas_adres`
  **`DEFAULT false`**
- `dukkan.teklif` — `UNIQUE (talep_id, isletme_id)`
- `dukkan.is_kaydi` — `talep_id` **UNIQUE**
- `dukkan.yorum.is_id` → `is_kaydi(id)` FK'si **artık kuruluyor** (0117'de
  hedef tablo yoktu; o göçte açıkça yazılıydı)

> **Tablo adı `is_kaydi`, `is` değil.** `IS` SQL'de ayrılmış anahtar kelime;
> `is` adı tüm sorguları 500'e düşürüyordu. Ölçülerek bulundu.

**Yönetiyor tablolarına DDL yok.**

---

## 3. Uygulama

```bash
git pull
docker compose -f docker-compose.prod.yml build migrate api admin-web worker
docker compose -f docker-compose.prod.yml up migrate
docker compose -f docker-compose.prod.yml up -d --force-recreate api worker beat
```

---

## 4. Doğrulama

### 4.1 KVKK görünürlüğü — **atlama, en kritik kontrol**

Bu, tasarımın en kritik tek kuralı: **sakinin açık adresi ve telefonu,
iş kabul edilmeden hiçbir işletmeye gitmez.**

Prod'da elle sürmek yerine **testlerin prod imajında geçtiğini** doğrula:

```bash
docker compose -f docker-compose.prod.yml run --rm \
  -e OWNER_DSN="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$POSTGRES_DB" \
  api python -m pytest tests/test_dukkan_kvkk.py -q
# BEKLENEN: 10 passed
```

> **Bu test prod imajında koşturulmalı, dev'de geçmesi yetmez.** Ölçülen
> şey imajın içindeki kod; dev ile prod imajı ayrışmışsa fark burada
> görünür.

Kırmızı çıkarsa **dur ve bildir** — adres sızıntısı KVKK ihlalidir.

### 4.2 Şema varsayılanları

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -tAc \
  "SELECT column_name, column_default FROM information_schema.columns
    WHERE table_schema='dukkan' AND table_name='talep'
      AND column_name LIKE 'paylas%' ORDER BY column_name;"
```

Üçü de **`false`** olmalı. `true` görürsen **dur ve bildir**: formda bir
kutu unutulduğunda kullanıcının verisi paylaşılır.

### 4.3 Tablo adı

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -tAc \
  "SELECT to_regclass('dukkan.is_kaydi');"
# BEKLENEN: dukkan.is_kaydi   (NULL ise göç eksik)
```

### 4.4 Uçlar ayakta

```bash
API=https://api.yonetiyor.com
# Kimliksiz -> 401 (kamu ucu DEĞİL)
curl -s -o /dev/null -w '%{http_code}\n' "$API/dukkan/talep"
# BEKLENEN: 401
```

### 4.5 IDOR ve sınır kilitleri hâlâ duruyor

```bash
docker compose -f docker-compose.prod.yml run --rm \
  -e OWNER_DSN="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$POSTGRES_DB" \
  api python -m pytest tests/test_dukkan_isletme_idor.py tests/test_dukkan_sinir.py -q
# BEKLENEN: 39 passed
```

---

## 5. Mobil — **APK/AAB gerekiyor mu?**

**Bu fazda kullanıcıya dağıtılmıyor.** Rotalar (`/dukkan/talep-olustur`,
`/dukkan/taleplerim`) tanımlı ama **menüde görünmüyor** — giriş noktası
F6'da eklenecek.

Yine de mobil tarafta **davranış değişikliği var** ve bunu bilmek önemli:

> `AuthInterceptor`'a `dukkanJetonu` muafiyeti eklendi. Bu, **mevcut
> Yönetiyor akışlarını etkilemez** (muafiyet yalnız `extra` anahtarı
> taşıyan isteklerde devreye giriyor) — ama bir sonraki mobil sürümde
> `auth_interceptor.dart` değişmiş olacak.

Önlenen kusur: Dukkan uçlarının 401'i Yönetiyor refresh'ini tetikleyip
**kullanıcıyı tesis uygulamasından atabilirdi**. Üç testle kilitli
(`test/dukkan_jeton_ayrimi_test.dart`).

---

## 6. `dukkan-web` — hâlâ dağıtılmıyor

Servis eklendiğinde `networks: [tesisnet]` **mutlaka** yazılacak (P215) ve
ağ doğrulama komutu `F3-dagitim.md` §5'te hazır.

---

## 7. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade 0117_dukkan_yorum_ve_siralama
```

`talep`, `teklif`, `is_kaydi` düşer ve `yorum.is_id` FK'si kalkar.
Veri kaybı: bu üç tablo (F4'te boş).

---

## 8. Risk

| Risk | Değerlendirme |
|---|---|
| Yönetiyor'a etki | **Yok** (backend). Mobilde `auth_interceptor` değişti ama muafiyet yalnız `extra` anahtarıyla devreye giriyor — mevcut akışlar aynı yolu izliyor, testle kilitli |
| KVKK | **Bu fazın merkezi.** 10 test, beşi sözleşmede isimle sayılan kilitler; hepsi kırılarak doğrulandı |
| Mevcut uçlara etki | **Yok.** 8 yeni uç |
| Veri hacmi | Talep/teklif küçük; indeksler kısmi (`durum IN ('acik','teklif_var')`) |
