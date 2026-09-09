# P221 — DAĞITIM NOTU

> Dükkan yüzeyi sunucudan yönetilen bir bayrağın arkasına alındı; mobil
> 1.2.2+9 paketleri üretildi.

## 1. Yeni ortam değişkenleri

`DUKKAN_MOBIL_ACIK` — **varsayılan `false`, prod'da eklenmesine gerek
yok.** Eklenmezse Dükkan yüzeyi hem mobilde hem web'de "yakında" ekranı
gösterir; bu istenen davranıştır.

İleride açmak için `.env.prod`a `DUKKAN_MOBIL_ACIK=true` yazıp `api`yi
**yeniden oluşturmak** yeterlidir; mobil sürüm çıkmaz.

## 2. Göç

Yok. Yeni tablo, sütun ya da veri değişikliği yok.

## 3. Uygulama

```
cd infra
docker compose -f docker-compose.prod.yml build migrate api admin-web worker beat
docker compose -f docker-compose.prod.yml up migrate
docker compose -f docker-compose.prod.yml up -d --force-recreate api admin-web worker beat
```

`beat` listede — üç kez düşmüştü. `restart` **yetmez**: ortam değişkeni
yeniden okunmaz, kod yenilenmez.

## 4. Doğrulama

```
curl -s https://api.yonetio.site/ozellikler
```
→ `{"dukkan":false}` beklenir. **Başka bir şey çıkarsa dur:** 404
gelirse `api` yeni kodla ayağa kalkmamıştır; `{"dukkan":true}` gelirse
`.env.prod`a yanlışlıkla bayrak konmuştur ve boş pazar yeri yayına
çıkmış demektir.

Web'de `/yerel-isletmeler` → "Yerel işletmeler hazırlanıyor" yer tutucusu
görünmeli, il/ilçe süzgeçleri **görünmemeli**. Menü girişi durmalı.
**Süzgeçler görünüyorsa dur:** BFF vekili (`/api/ozellikler`) 404
veriyordur.

Mobil: Dükkan sekmesi görünür, dokununca "Yerel işletmeler hazırlanıyor"
ekranı açılır. Push bildiriminden gelen derin bağlantı da aynı ekrana
düşmeli.

## 5. Geri alma

Bir önceki `api` + `admin-web` imajına dönmek yeterli; veri kaybı yok.
Mobil paket geri alınamaz (mağaza sürümü geri çekilir), ama bayrak
kapalı olduğu için 1.2.2 kullanıcıya Dükkan açmaz.

## 6. Bu fazın açık bıraktıkları

- **iOS paketi üretilmedi.** Bu makinede macOS/Xcode yok; `.ipa` ve
  App Store yüklemesi kullanıcıda. `pubspec.yaml: 1.2.2+9` iOS için de
  geçerlidir (`CFBundleVersion` oradan türer).
- **AAB'nin `versionCode`u doğrudan okunmadı**: AAB manifesti protobuf
  ve elde `bundletool` yok. Aynı koşumda aynı girdilerle üretilen APK
  `versionCode=9 / versionName=1.2.2 / targetSdk=36` diyor; AAB için
  bunu **dolaylı** kabul ettim.
- **İkonun piksel içeriği doğrulanmadı** — yayın yapımı PNG'leri yeniden
  sıkıştırdığı için bayt karşılaştırması imkânsız. Betik yalnız
  "kaynak paketten yeni değil" ve "`ic_launcher` kaynak tablosunda var"
  ölçüyor. Görsel doğrulama cihazda gözle yapılmalı.
- **Cihazda çalıştırma yapılmadı** — bağlı cihaz/emülatör yok.
  `dagitim/yonetio-1.2.2+9.apk` bu iş için üretildi.
