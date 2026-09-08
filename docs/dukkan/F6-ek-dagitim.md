# DUKKAN F6-ek — DAĞITIM NOTU

> F6-ek = **mobil bildirim ekranı + FCM kaydı**, Dukkan'ın kendi push
> kanalı, ayrı bildirim tercihi, web bildirim sayfası.
>
> **Bu faz mobil uygulamanın yeni sürümünü gerektirir.** Backend
> tek başına dağıtılabilir ve zararsızdır (yeni kanal kimliğiyle push
> gönderir, eski sürümdeki cihaz o kanalı **tanımaz**) — ayrıntı §7'de.

---

## 1. Yeni ortam değişkeni

**Yok.**

---

## 2. Göç

**`0121_dukkan_bildirim_tercihi`** —
`dukkan.dukkan_kullanici`'ya `bildirim_acik` + `bildirim_sesli`
(ikisi de `NOT NULL DEFAULT true`).

**Yönetiyor tablolarına DDL yok.** Geri alınabilir (`downgrade` iki
sütunu düşürür).

Zincir: `0120_dukkan_bildirim` → **`0121_dukkan_bildirim_tercihi`**.

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

> `admin-web` **bu fazda değişmedi** — yeniden kurmaya gerek yok.
> `dukkan-web` **değişti** (yeni `/bildirimler` sayfası + BFF vekili);
> servis yayına alındıysa onu da kur (§6).

> `restart` **yetmez**: `backend/` imaja gömülü, kod ancak yeniden kurulup
> `--force-recreate` ile ayağa kalkan konteynerde yenilenir.

---

## 4. Doğrulama

### 4.1 Göç uygulandı mı

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT column_name, column_default FROM information_schema.columns
    WHERE table_schema='dukkan' AND table_name='dukkan_kullanici'
      AND column_name LIKE 'bildirim%';"
```

**Beklenen:** iki satır, ikisinin de varsayılanı `true`.
**Sıfır satır dönerse dur** — göç uygulanmamış, tercih ucu 500 verir.

### 4.2 Tercih ucu çalışıyor mu

```bash
# JETON = geçerli bir Dukkan access token
curl -s -H "authorization: Bearer $JETON" \
  https://api.yonetiyor.com/dukkan/bildirim-tercihi
```

**Beklenen:** `{"bildirim_acik":true,"bildirim_sesli":true}`

```bash
curl -s -X PATCH -H "authorization: Bearer $JETON" \
  -H 'content-type: application/json' \
  -d '{"bildirim_acik":false}' \
  https://api.yonetiyor.com/dukkan/bildirim-tercihi
```

**Beklenen:** `{"bildirim_acik":false,"bildirim_sesli":true}` —
yani **sunucudaki güncel hâl**. `{"ok":true}` gibi bir şey dönerse
yanlış sürüm çalışıyordur.

Boş gövde **400** dönmeli:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X PATCH \
  -H "authorization: Bearer $JETON" -H 'content-type: application/json' \
  -d '{}' https://api.yonetiyor.com/dukkan/bildirim-tercihi
# BEKLENEN: 400
```

### 4.3 Kanal gerçekten gönderiliyor mu — **push günlüğü**

Bu fazın asıl ölçümü. Dev'de `PUSH_PROVIDER=noop` olduğu için **gerçek
teslim hiç ölçülemedi**; prod'da ölçülebilir.

```bash
docker compose -f docker-compose.prod.yml logs --since 10m api \
  | grep -i "PUSH"
```

**`PUSH_PROVIDER=noop: HICBIR BILDIRIM GONDERILMEZ` satırı görüyorsan
dur:** push yapılandırılmamış demektir ve pazar yeri bildirimsiz çalışır
(P191'de bu tam olarak yaşandı ve haftalarca fark edilmedi).

### 4.4 Bildirim gerçekten gitti mi — **veritabanı**

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT tip, count(*) AS toplam,
          count(*) FILTER (WHERE gonderildi_at IS NOT NULL) AS gonderilen
     FROM dukkan.bildirim
    WHERE created_at > now() - interval '1 day'
    GROUP BY tip ORDER BY 1;"
```

`gonderilen` sütunu **sürekli 0 ise** push zinciri kopuktur (cihaz kaydı
yok ya da sağlayıcı reddediyor). Tiplerin hepsi `dukkan_` önekli olmalı;
öneksiz bir tip görürsen **eski sürüm** yazıyor demektir.

### 4.5 Cihaz kaydı geliyor mu

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -c \
  "SELECT platform, count(*) FROM dukkan.dukkan_cihaz GROUP BY 1;"
```

Yeni mobil sürüm dağıldıktan sonra, **Dukkan ekranını açan** kullanıcı
başına satır oluşmalı. Sıfır kalıyorsa ya sürüm dağılmamış ya
`initialize()` `false` dönüyor (Firebase yapılandırması eksik).

> **Kayıt girişte değil, Dukkan jetonu alındığında yapılır** (gerekçe:
> `F6-ek-kararlar.md` §5). Yani "giriş yapan herkes" değil, "pazar yerini
> açan herkes" için satır beklenir. Bu sayının kullanıcı sayısından düşük
> olması **normal**, kusur değil.

---

## 5. Mobil sürüm

Mobil değişiklikler **yeni sürüm yayını** gerektirir:

- yeni bildirim kanalı `yonetio_dukkan_v1` (`MainActivity.kt`)
- iki yeni string (`kanal_dukkan_ad`, `kanal_dukkan_aciklama`), tr + en
- yeni ekranlar: talep detayı, işletme paneli, bildirim listesi
- 33 yeni sözlük anahtarı × 7 dil

Kanal **uygulama açılışında** oluşturulur; kullanıcı sistem ayarlarında
"Yerel işletmeler" satırını sürüm yüklendikten sonra görür.

> **Eski kanal silinmiyor.** `ESKI_KANALLAR` listesine dokunulmadı;
> `yonetio_dukkan_v1` ilk kez açılıyor, silinecek bir öncülü yok.

---

## 6. `dukkan-web`

Yayına alındıysa:

```bash
docker compose -f docker-compose.prod.yml build dukkan-web beat
docker compose -f docker-compose.prod.yml up -d --force-recreate dukkan-web beat
```

Ağ doğrulaması (**P215 dersi** — `mediamtx` `networks:` satırı unutulmuş
ve kusur prod'a ulaşmıştı):

```bash
docker inspect -f '{{json .NetworkSettings.Networks}}' \
  $(docker compose -f docker-compose.prod.yml ps -q dukkan-web) | tr ',' '\n' | grep -i tesisnet
```

**Çıktı boşsa dur:** servis `tesisnet` üzerinde değil, Caddy ona
ulaşamaz.

Sayfa doğrulaması:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://dukkan.yonetiyor.com/bildirimler
# BEKLENEN: 200 (istemci tarafı jeton yoksa /giris'e yönlendirir)
```

---

## 7. Karışık sürüm dönemi (backend yeni, mobil eski)

Backend'i mobil sürümden önce dağıtmak **güvenli değil, sessizce
zararlı**:

- Backend `channel_id: yonetio_dukkan_v1` gönderir.
- Eski mobil sürümde o kanal **oluşturulmamıştır**.
- Android **kayıtsız kanala gelen bildirimi gösterMEZ** — sessizce düşer.

Yani eski sürümdeki kullanıcılar bu dönemde **Dukkan push'u almaz** (uygulama
içi liste etkilenmez, satır yazılmaya devam eder).

**Öneri:** ya mobil sürümü önce yayınla ve yaygınlaşmasını bekle, ya da
`dukkan.yonetiyor.com` henüz yayında olmadığı için bu fazı **mobil sürümle
birlikte** dağıt. Şu an Dukkan'da gerçek kullanıcı olmadığı için pratikte
etkisi yok — ama site açıldıktan sonra bu sıra **önemli**.

---

## 8. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm migrate \
  alembic downgrade 0120_dukkan_bildirim
git checkout <önceki-sha> && docker compose ... build api worker beat && up -d --force-recreate api worker beat
```

`downgrade` iki sütunu düşürür; **veri kaybı yalnızca kullanıcıların
kapatma tercihidir** (geri alındığında herkes yeniden "açık" olur).
Bildirim satırları ve cihaz kayıtları etkilenmez.

Mobil geri alma yok — mağaza sürümü geri çekilmez; yeni sürüm yayınlanır.

---

## 9. Bu fazın açık bıraktıkları

| Madde | Neden şimdi kapatılmadı |
|---|---|
| **Web push yok** | Service worker altyapısı kurulmadı; web kullanıcısı bildirimi sayfayı açtığında görür |
| **`dukkan_cihaz` retention yok** | F6-dagitim §8'deki açık madde duruyor; ölü jeton temizliği yazılmadı |
| **Gerçek teslim ölçülmedi** | Dev'de `PUSH_PROVIDER=noop`; ölçüm §4.3–4.4 ile **prod'da** yapılacak |
| **Cihazda görünüm doğrulanmadı** | Emülatör yok; kanal satırı ve tepsiden dokunma sürülmedi |
