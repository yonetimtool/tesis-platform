# DUKKAN F8 — DAĞITIM NOTU

> F8 = gelir modeli değişikliği. Üç bölüm:
> **F8a** para akışı yok (göç 0123) · **F8b** reklam (göç 0124) ·
> **F8c** ödeme altyapısı (göç 0125).
>
> **Ödeme sağlayıcısı bağlı değil ve bu sorun değil.** Sistem çalışır;
> reklam satın alma ucu açıkça **503 `odeme_yapilandirilmadi`** döner.

---

## 1. Yeni ortam değişkenleri

| Değişken | Değer | Zorunlu mu |
|---|---|---|
| `ODEME_SAGLAYICI` | **boş bırak** (varsayılan) | Hayır |
| `ODEME_DONUS_ADRESI` | `https://dukkan.yonetiyor.com/panel` | Sağlayıcı bağlanınca |

> **`ODEME_SAGLAYICI` boş = ödeme kapalı.** Bu bilinçli varsayılan:
> yapılandırma unutulursa hiçbir şey tahsil edilmez. Ters yönde hata
> yapmak — "yapılandırılmadı" iken "ödendi" demek — platformun parasını
> almadan hizmet vermesi demekti.
>
> **`sahte` değerini prod'a YAZMA.** Dev/test için; yazılırsa her işlemde
> log uyarır ama gerçek tahsilat yapılmaz.

---

## 2. Göçler — üçü sırayla

| Göç | Ne yapar | Geri alınabilir |
|---|---|---|
| `0123_dukkan_para_akisi_yok` | `is_kaydi.durum`'dan `anlasmazlik` çıkarır; `is_kaydi` ve `teklif.tutar_kurus`'a açıklayıcı `COMMENT` ekler | Evet |
| `0124_dukkan_reklam` | `reklam_paketi`, `reklam_slot_kurali` (+3 başlangıç satırı), `reklam`, `reklam_bekleme`; `btree_gist` eklentisi | Evet |
| `0125_dukkan_odeme` | `odeme_yontemi`, `reklam_satin_alma`, `abonelik` | Evet |

Zincir: `0122` → `0123` → `0124` → `0125`.

> **0123 VERİ VARSA DURUR.** `is_kaydi.durum='anlasmazlik'` satırı varsa
> göç `RuntimeError` ile durur. Sessizce `iptal`e çevirmek, bir
> kullanıcının açık sorununu kayıt dışı bırakırdı. Bugün sıfır satır
> bekleniyor (hiçbir uç yazmıyor) — ama "beklenen" ile "ölçülen" aynı
> şey değil.

> **`btree_gist` gerekli** (0124). PostgreSQL'in standart contrib
> eklentisi, `postgres:16` imajında mevcut. PostGIS gibi ağır bir
> bağımlılık **değil**. Aynı bölge+kategori+çakışan tarihte iki reklamı
> `EXCLUDE` kısıtıyla engellemek için.

---

## 3. Uygulama

```bash
git pull
docker compose -f docker-compose.prod.yml build migrate api worker
docker compose -f docker-compose.prod.yml up migrate
docker compose -f docker-compose.prod.yml up -d --force-recreate api worker beat
```

`dukkan-web` **değişti** (sponsorlu blok + 10 yeni BFF vekili); yayına
alındıysa onu da kur ve **ağ doğrulamasını yap** (§6).

`admin-web` bu fazda değişmedi.

> `restart` **yetmez**: `backend/` imaja gömülü.
> `beat` de yenilenmeli — iki yeni zamanlanmış iş var.

---

## 4. Doğrulama

### 4.1 Göçler uygulandı mı

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c "\dt dukkan.reklam*" -c "\dt dukkan.abonelik" \
  -c "\dt dukkan.odeme_yontemi"
```

**Beklenen:** `reklam`, `reklam_bekleme`, `reklam_paketi`,
`reklam_slot_kurali`, `abonelik`, `odeme_yontemi`.

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT pg_get_constraintdef(oid) FROM pg_constraint
    WHERE conname='is_kaydi_durum_check';"
```

`anlasmazlik` **görünmemeli**.

### 4.2 Slot kuralı yüklendi mi

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT kapsam, azami_slot, azami_oran FROM dukkan.reklam_slot_kurali
    ORDER BY kapsam;"
```

**Beklenen:** il 3 / ilçe 2 / mahalle 1, hepsinde oran 20.00.

> **Bu sayılar TAHMİN** ve ayarlanabilir olsun diye veride. Ayarlamak
> için **yeni satır ekle**, mevcut satırı güncelleme — "o tarihte kural
> neydi" sorusu bir itirazda sorulur:
> ```sql
> INSERT INTO dukkan.reklam_slot_kurali (kapsam, azami_slot, azami_oran)
> VALUES ('ilce', 3, 25.00);
> ```

### 4.3 Ödeme KAPALI olduğunu doğrula — **en önemli adım**

```bash
docker compose -f docker-compose.prod.yml logs --since 5m api | grep -i "ODEME"
```

**Beklenen:** `ODEME saglayici YOK -> hicbir tahsilat yapilmadi`.

**`ODEME_SAGLAYICI='...' TANINMIYOR` görüyorsan dur:** env'e yanlış bir
değer yazılmış; ödeme kapalı ama sebebi yapılandırma hatası.

```bash
# JETON = geçerli bir Dukkan access token
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  -H "authorization: Bearer $JETON" -H 'content-type: application/json' \
  -d '{"takma_ad":"test"}' \
  https://api.yonetiyor.com/dukkan/odeme-yontemi
# BEKLENEN: 503
```

**200 dönerse DUR ve bildir:** ödeme sağlayıcısı bağlı olmadığı hâlde
sistem başarılı yanıt veriyor demektir — bu, platformun parasını almadan
hizmet vermesine yol açan sınıf.

### 4.4 Reklam paketi yok — ve bu normal

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c "SELECT count(*) FROM dukkan.reklam_paketi;"
```

**Beklenen: 0.** Fiyatlar veriden yükleniyor ve **henüz fiyat yok**.
Paket eklenene kadar reklam satılamaz — bu bilinçli: fiyatı koda
gömmemek için.

Fiyat belirlendiğinde:

```sql
INSERT INTO dukkan.reklam_paketi (ad, kapsam, gun, fiyat_kurus, kdv_orani, sira)
VALUES ('Mahalle 30 gün', 'mahalle', 30, 50000, 20.00, 1),
       ('İlçe 30 gün',    'ilce',    30, 150000, 20.00, 2),
       ('İl 30 gün',      'il',      30, 400000, 20.00, 3);
```
*(Tutarlar **kuruş**: 50000 = 500,00 TL. Bunlar örnek, fiyat kararı
senin.)*

### 4.5 Zamanlanmış işler kayıtlı mı

```bash
docker compose -f docker-compose.prod.yml logs beat --since 5m | grep -i dukkan
```

**Beklenen üç iş:** `dukkan-siralama` (02:00),
`dukkan-reklam-bakimi` (02:20), `dukkan-abonelik-cekimi` (02:40).

> Sıra önemli: bakım süresi bitenleri düşürür ve **slot açar**; çekim o
> slota yeni dönemi yazar. Ters sırada yenileme "bölge dolu" alırdı.

### 4.6 Sponsorlu blok ayrı mı

```bash
curl -s "https://api.yonetiyor.com/dukkan/isletme-ara?il=istanbul&ilce=cekmekoy&kategori=elektrikci" \
  | head -c 300
```

Yanıtta **`sponsorlu`** anahtarı olmalı (paket yokken boş dizi).
`items` içinde `sponsorlu: true` taşıyan bir kalem **olmamalı** —
olursa reklam organik listeye karışmış demektir.

---

## 5. Sağlayıcı seçildiğinde ne yapılacak

1. `backend/app/odeme_<saglayici>.py` — tek sınıf, dört metot.
2. `app/odeme.py: odeme_saglayicisi()` içine bir `if` dalı.
3. `.env.prod`: `ODEME_SAGLAYICI=<ad>` + kimlik bilgileri +
   `ODEME_DONUS_ADRESI`.
4. `up -d --force-recreate api worker beat`.

**Başka hiçbir yer değişmeyecek:** reklam, abonelik, fatura ve bildirim
kodu sağlayıcıdan habersiz yazıldı ve testleri sahte bir sağlayıcıyla
koşuyor.

Karşılaştırma ve teklif isterken sorulacaklar:
`08-odeme-saglayici-karsilastirma.md`.

---

## 6. `dukkan-web`

```bash
docker compose -f docker-compose.prod.yml build dukkan-web
docker compose -f docker-compose.prod.yml up -d --force-recreate dukkan-web
docker inspect -f '{{json .NetworkSettings.Networks}}' \
  $(docker compose -f docker-compose.prod.yml ps -q dukkan-web) \
  | tr ',' '\n' | grep -i tesisnet
```

**Çıktı boşsa dur** — servis `tesisnet` üzerinde değil, Caddy ona
ulaşamaz (P215 dersi).

---

## 7. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm --entrypoint sh migrate \
  -lc "alembic -c /contracts/db/alembic.ini downgrade 0122_dukkan_davet_gonderim_izi"
```

Üç göç de geri alınabilir. **Veri kaybı:**

- `0125` → saklanan kart token'ları, satın alma ve fatura kayıtları,
  abonelikler. **Tahsilat yapılmış bir kurulumda bunu YAPMA** — mali
  kayıt kaybolur.
- `0124` → reklamlar, slot kuralı, bekleme listesi.
- `0123` → yalnız `anlasmazlik` değeri CHECK'e geri döner (veri yok).

---

## 8. Bu fazın açık bıraktıkları

| Madde | Neden |
|---|---|
| **Gerçek tahsilat ölçülmedi** | Sağlayıcı yok; akış sahte sağlayıcıyla sürüldü |
| **3DS dalı ölçülmedi** | Kodda var, hiçbir gerçek 3DS sayfası görülmedi |
| **Mobilde reklam SATIN ALMA yok** | Bilerek: fatura (VKN, vergi dairesi, adres) + kart adımı masa başı işler; telefon klavyesinde bitirilemeyen bir form olurdu. Mobilde **durum ve kalan gün** var, satın alma web'de — ekran bunu açıkça söylüyor |
| **Tıklama/görüntülenme ölçümü yok** | Bilerek: ölçüm eklemek "gösterim garantisi" beklentisi yaratır ve sözleşmede taahhüde döner (avukat sorusu S19) |
| **Deneme sayısı (3) ve 1 günlük ara** | Tahmin; ilk ay ölçülmeli |
