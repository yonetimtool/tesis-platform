# DUKKAN F6 — DAĞITIM NOTU

> F6 = **Yönetiyor entegrasyonu**: bildirimler (kalıcı satır + push), mobil
> "Yerel İşletmeler" menü girişi, `app.yonetiyor.com` yönetici sayfası.
>
> **Bu fazda Yönetiyor'un kullanıcıya görünen yüzeyi DEĞİŞİYOR** — önceki
> beş fazın aksine. Mobil menüye yeni bir kart, panele yeni bir sayfa
> giriyor.

---

## 1. Yeni ortam değişkeni

**Yok.** Push, Yönetiyor'un mevcut `PUSH_PROVIDER` / FCM yapılandırmasını
**paylaşıyor**.

---

## 2. Göç

**`0120_dukkan_bildirim`** — `dukkan.dukkan_cihaz`, `dukkan.bildirim`.

**Yönetiyor tablolarına DDL yok.**

---

## 3. Uygulama

```bash
git pull
docker compose -f docker-compose.prod.yml build migrate api admin-web worker
docker compose -f docker-compose.prod.yml up migrate
docker compose -f docker-compose.prod.yml up -d --force-recreate api admin-web worker beat
```

> **`admin-web` de yeniden kurulmalı** — bu fazda panele yeni bir sayfa
> (`/yerel-isletmeler`), yeni bir menü girişi ve yeni bir ikon girdi.
> Yenilenmezse sayfa **404** verir ve menü girişi görünmez.

---

## 4. Doğrulama

### 4.1 Panel sayfası açılıyor mu

`app.yonetiyor.com/yerel-isletmeler` — yönetici ya da admin ile giriş yapıp
aç. Menüde **"Yerel işletmeler"** görünmeli (Tesis grubunda, "Dış Hizmetler"
in hemen altında).

**404 alıyorsan** `admin-web` yeniden kurulmamış demektir.

### 4.2 Middleware koruması — **atlama**

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  https://app.yonetiyor.com/yerel-isletmeler
# BEKLENEN: 307/302 (giriş ekranına yönlendirme)
```

**200 dönerse dur ve bildir:** sayfa korumasız kalmış demektir. Bu, bu fazda
`middleware.test.ts`in yakaladığı gerçek bir kusurdu.

### 4.3 Bildirim ucu

```bash
API=https://api.yonetiyor.com
curl -s -o /dev/null -w '%{http_code}\n' "$API/dukkan/bildirim"
# BEKLENEN: 401 (kimlik gerekli)
```

### 4.4 Push gerçekten gidiyor mu — **ölçülmedi, ölçmen gerekiyor**

Dev'de `PUSH_PROVIDER=noop` olduğu için **hiçbir bildirim gerçekten
gönderilmedi**. Prod'da FCM yapılandırılı; ilk gerçek teklif sonrasında:

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -tAc \
  "SELECT tip, gonderildi_at IS NOT NULL AS gitti, count(*)
     FROM dukkan.bildirim GROUP BY 1,2 ORDER BY 1;"
```

`gitti = false` satırları **gönderilememiş** bildirimlerdir. Hepsi `false`
ise cihaz kaydı yok ya da FCM yapılandırması Dukkan tarafında çalışmıyor
demektir.

> `gonderildi_at` **yalnızca sağlayıcı kabul ettiğinde** dolar. Bu bilinçli:
> P191'de `noop` sağlayıcı sessizce "gönderildi" gibi davranıyordu ve
> bildirimler hiç gitmiyordu — kimse fark etmedi.

### 4.5 Denetim ve sınır hâlâ duruyor

```bash
docker compose -f docker-compose.prod.yml run --rm \
  -e OWNER_DSN="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@db:5432/$POSTGRES_DB" \
  api python -m pytest tests/test_dukkan_sinir.py tests/test_dukkan_bildirim.py -q
# BEKLENEN: 27 passed
```

---

## 5. Mobil — **yeni sürüm gerekiyor**

Bu faz mobil menüye **yeni bir kart** ekliyor ("Yerel işletmeler"). Kullanıcı
bunu görmesi için **yeni bir APK/AAB** gerekiyor.

**Sürüm çıkmadan önce bilinmesi gerekenler:**

- `auth_interceptor.dart` F4'te değişti (`dukkanJetonu` muafiyeti). Mevcut
  Yönetiyor akışlarını **etkilemiyor** — muafiyet yalnız `extra` anahtarı
  taşıyan isteklerde devreye giriyor, üç testle kilitli.
- Menü kilidi (`home_menu_test.dart`) güncellendi: yeni kart **4 rolün
  hepsinde** görünüyor (arama uçları kimliksiz).
- **Dukkan bildirim ekranı mobilde YOK** (açık madde). Backend hazır, FCM
  kaydı bağlanmadı — yani mobilde Dukkan push'u **çalışmaz**.

APK üretimi sende; `--dart-define` bayraklarını atlamamaya dikkat (P190'da
bir kez atlanmıştı).

---

## 6. `dukkan-web` — **hâlâ dağıtılmıyor**

Altı fazın tamamı yazıldı; site yayına açma kararı sende. Servis
eklendiğinde:

```yaml
  dukkan-web:
    build: { context: ../apps/dukkan-web }
    environment:
      API_BASE_URL: http://api:8000
      NEXT_PUBLIC_SITE_ADRESI: https://dukkan.yonetiyor.com
      NEXT_PUBLIC_INCE_ICERIK_ESIGI: "3"
    networks: [tesisnet]          # <-- P215: BU SATIR ATLANMAYACAK
    restart: unless-stopped
```

Ağ doğrulama komutu `F3-dagitim.md` §5'te.

---

## 7. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade 0119_dukkan_guven
```

`bildirim` ve `dukkan_cihaz` düşer.

**Panel sayfası ve mobil menü girişi kodda kalır** — geri almak için o
commit'i revert etmek gerekir. Göç geri alınıp kod kalırsa sayfa **500**
verir (tablo yok). İkisini birlikte geri al.

---

## 8. Risk

| Risk | Değerlendirme |
|---|---|
| **Yönetiyor yüzeyi değişiyor** | **Evet** — mobil menüye kart, panele sayfa. Mevcut akışlar değişmiyor; menü kilidi ve 1735 admin-web testi bunu doğruluyor |
| Push maliyeti | FCM ücretsiz; hacim riski **toplulaştırma yok** (açık madde) |
| Bildirim hacmi | Aktif pazar yerinde teklif bildirimleri birikir. Batching **yok** — gerçek trafikte ölçülmeli |
| Veri | `bildirim` tablosu büyür; **retention yok** (açık madde: Yönetiyor'da `push_gonderim` 30 gün tutuluyor, Dukkan'da benzeri kurulmadı) |
