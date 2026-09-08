# DUKKAN F7 — DAĞITIM NOTU

> F7 = **kota düzeltmesi** (göç 0122) + **mobil telefon-OTP**.
>
> Backend tek başına dağıtılabilir ve **hemen faydalı**: kota düzeltmesi
> mobil sürümden bağımsız çalışır. OTP akışı yeni mobil sürüm gerektirir.

---

## 1. Yeni ortam değişkeni

**Yok.**

> **`SMS_BASLIK` hâlâ boş.** Bu faz onu gerektirmiyor; kod başlıksız
> çalışıyor ve durumu **açıkça söylüyor** (503 `sms_baslik_yok`, arayüzde
> "onay sürecimiz sürüyor"). Başlık onaylandığında yapılacak tek şey:
> `.env.prod`'a `SMS_BASLIK=<onaylı başlık>` eklemek ve `api` + `worker`
> servislerini `up -d --force-recreate` ile yenilemek. **Kod değişmez.**

---

## 2. Göç

**`0122_dukkan_davet_gonderim_izi`** — `dukkan.yorum_daveti`'ye
`gonderim_durumu` (`NOT NULL DEFAULT 'saglayici_yok'`, CHECK'li),
`gonderim_hatasi`, `saglayici` + kısmi indeks
`ix_yorum_daveti_gonderilen`.

**Yönetiyor tablolarına DDL yok.** Geri alınabilir.

Zincir: `0121_dukkan_bildirim_tercihi` → **`0122_dukkan_davet_gonderim_izi`**.

> **Geçmiş satırlar `saglayici_yok` sayılıyor** — yani mevcut davetler
> kotayı **boşaltıyor**. Bu bilinçli: gerçekte gönderilip
> gönderilmedikleri bilinmiyor ve `gonderildi` varsaymak, gitmemiş
> davetleri gitmiş saymak olurdu (gerekçe: `F7-kararlar.md` §1).

---

## 3. Uygulama

> Kanonik komut **`docs/DAGITIM-SABLONU.md`**'den gelir ve `beat` HER
> ZAMAN listededir. Üç kez atlandı (P187/P192/F8b) ve zamanlayıcı
> sessizce eski kodla çalıştı — dördüncüsü olmasın diye artık şablondan
> türüyor ve `GET /health` → `beat` ile **ölçülüyor**.


```bash
git pull
docker compose -f docker-compose.prod.yml build migrate api worker beat
docker compose -f docker-compose.prod.yml up migrate
docker compose -f docker-compose.prod.yml up -d --force-recreate api worker beat
```

`admin-web` ve `dukkan-web` **bu fazda değişmedi**.

---

## 4. Doğrulama

### 4.1 Göç uygulandı mı

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT column_name FROM information_schema.columns
    WHERE table_schema='dukkan' AND table_name='yorum_daveti'
      AND column_name IN ('gonderim_durumu','gonderim_hatasi','saglayici');"
```

**Beklenen: 3 satır.** Sıfırsa **dur** — davet ucu 500 verir.

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT indexname FROM pg_indexes
    WHERE schemaname='dukkan' AND indexname='ix_yorum_daveti_gonderilen';"
```

### 4.2 Kota gerçekten boşaldı mı

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT gonderim_durumu, count(*) FROM dukkan.yorum_daveti GROUP BY 1;"
```

Göçten hemen sonra **hepsi `saglayici_yok`** olmalı — yani hiçbir işletme
kota tüketmemiş durumda. Başlık geldikten sonra bu tabloda `gonderildi`
satırları birikmeye başlar; **başlamıyorsa** gönderim hâlâ çalışmıyor
demektir.

### 4.3 Başlık geldiğinde — asıl ölçüm

`SMS_BASLIK` doldurulup servisler yenilendikten sonra:

```bash
# JETON = onaylı bir işletmenin sahibine ait Dukkan access token
curl -s -X POST -H "authorization: Bearer $JETON" \
  -H 'content-type: application/json' \
  -d '{"telefon":"+90XXXXXXXXXX"}' \
  https://api.yonetiyor.com/dukkan/isletme/$ISLETME_ID/yorum-daveti
```

**Beklenen:** `201` ve `"gonderildi": true`.
**`503 sms_baslik_yok` alıyorsan** başlık env'e girmemiş ya da servis
yenilenmemiş (`restart` yetmez, `--force-recreate` gerekir).

`"gonderildi": false` ile `201` **asla** dönmemeli — çelişkili yanıt
sınıfı SMS turunda kapatıldı.

### 4.4 Mobil OTP akışı

Yeni mobil sürüm dağıldıktan sonra, **telefonu olmayan** bir Yönetiyor
hesabıyla: Yerel İşletmeler → Taleplerim → "Telefonumu doğrula".

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT gonderim_durumu, count(*) FROM dukkan.telefon_dogrulama
    WHERE amac='giris' AND created_at > now() - interval '1 day'
    GROUP BY 1;"
```

`gonderildi` satırı **hiç yoksa** SMS zinciri kopuktur — kullanıcı kod
bekleyip alamaz.

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT count(*) FILTER (WHERE b.dukkan_kullanici_id IS NULL) AS otp_ile,
          count(*) FILTER (WHERE b.dukkan_kullanici_id IS NOT NULL) AS sso_ile
     FROM dukkan.dukkan_kullanici k
     LEFT JOIN dukkan.dukkan_yonetiyor_bag b ON b.dukkan_kullanici_id = k.id;"
```

`otp_ile` sütunu, **köprünün ulaşamadığı** kullanıcıları gösterir — yani
bu fazın kazandırdığı kitle. Sıfır kalıyorsa ya sürüm dağılmamış ya akış
bir yerde kopuyor.

---

## 5. Mobil sürüm

- yeni ekran: telefon doğrulama (OTP), ortak hata gövdesi
- Dukkan jetonu artık **cihazda saklanıyor** (Keystore/Keychain
  destekli), Yönetiyor kullanıcısına bağlı
- 23 yeni sözlük anahtarı × 7 dil

> **Sürüm yükseltmesi kullanıcıyı çıkarmaz.** Yeni depo anahtarları
> (`dukkan.jeton`, `dukkan.jeton.sahip`) boş başlar; jeton yoksa akış
> eskisi gibi köprüden devam eder.

---

## 6. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm migrate \
  alembic downgrade 0121_dukkan_bildirim_tercihi
git checkout <önceki-sha> && docker compose ... build api worker beat && up -d --force-recreate api worker beat
```

`downgrade` üç sütunu ve indeksi düşürür. **Veri kaybı: gönderim izi** —
yani hangi davetin gerçekten gittiği bilgisi. Davet satırlarının kendisi
etkilenmez, ama geri alındığında kota yeniden **tüm satırları** saymaya
başlar (eski kusurlu davranış).

---

## 7. Bu fazın açık bıraktıkları

| Madde | Neden |
|---|---|
| **Gerçek SMS teslimi ölçülmedi** | Onaylı başlık yok; §4.3 bekliyor |
| **OTP hesabında `dukkan_yonetiyor_bag` yok** | Köprü salt okunur; Yönetiyor'a telefon yazmak sınır ihlali olurdu (F7-kararlar §2) |
| **Cihazda OTP ekranı sürülmedi** | Emülatör yok |
