# P221 — Dukkan "yakında" kapısı + mobil sürüm paketi

Tarih: 2026-09-09

## 1. Neden bir bayrak, neden sunucuda

İstek: "Dukkan sekmesi görünsün, ama içinde 'yakında' ekranı olsun."

Üç seçenek vardı:

| Seçenek | Sonuç |
|---|---|
| Sekmeyi kaldır | Hazır olunca **yeni mağaza turu** gerekir — tam kaçınılmak istenen şey |
| Sekmeyi bırak, boş pazar yeri göster | "Ürün çalışmıyor" izlenimi |
| **Sekme dursun, içerik yer tutucu olsun** | Seçilen |

**Bayrak UYGULAMADA DEĞİL SUNUCUDA.** Uygulamada olsaydı açmak için yeni
sürüm + inceleme + yayılma gerekirdi (Play'de gün, App Store'da daha
fazla). Sunucuda tek ortam değişkeni yeter:

```
DUKKAN_MOBIL_ACIK=true
```

Yeni bir uç açıldı — `GET /ozellikler`, **kimliksiz**, gövde:

```json
{"dukkan": false}
```

Kimliksiz olması bilinçli: bayrak giriş ekranından önce de okunabilmeli
ve içinde kişisel/tesise özel hiçbir şey yok.

`POST /surum/kontrol` ile **birleştirilmedi**: o uç sürüm politikası
tablosundan okur (tesis/istemci sürümüne bağlı, veritabanı), bu ise
dağıtım yapılandırmasından (ortam değişkeni). Aynı uca koymak, iki farklı
kaynağı tek yanıtın arkasına saklamak olurdu.

## 2. Varsayılan KAPALI — her yolda

"Bayrak eksik gelirse Dukkan sessizce açılmasın." Ölçülen ve kilitlenen
yollar (mobil 8 test, web 7 test):

- sunucu `false` diyor → kapalı
- alan **hiç yok** (eski sunucu) → kapalı
- uç 500 dönüyor → kapalı
- ağ hatası → kapalı
- yanıt **henüz gelmedi** (yükleniyor) → kapalı
- tip beklenmedik (`"evet"`) → kapalı
- sunucu `true` diyor → **açılır** (ters yön; bu olmadan "yüzeyi tümden
  sil" de testi geçerdi)

Aynı fail-closed deseni `sms_aktif`, `dukkan_sms_saglayici` ve
`odeme_saglayici` ile aynı: bilinmiyorsa çalışıyor sayma.

## 3. Kapı nerede duruyor

**Mobil:** `DukkanKapisi` sarmalayıcısı, `app_router.dart`'taki
**8 Dukkan rotasının tamamında**. Tek tek sarmak yerine tek bir yerde
sarmak yeterli değildi: derin bağlantı (push bildirimi) doğrudan alt
ekrana götürüyor. Kaynak taraması yapan bir kilit, sarmasız bir rota
eklenirse düşüyor — kırarak doğrulandı.

**Web:** `/yerel-isletmeler` sayfası, `useDukkanAcik()` ile aynı bayrağa
bağlı. **Menü girişi kaldırılmadı**: girişi gizlemek yöneticiye özelliğin
var olduğunu hiç anlatmazdı; boş pazar yeri göstermek kötü izlenim
bırakırdı — üçüncü yol yer tutucu.

## 4. Metin — tarih taahhüdü YOK

7 dilde iki anahtar (`dukkanYakindaBaslik`, `dukkanYakindaMetin`).
Türkçe:

> **Yerel işletmeler hazırlanıyor**
> Mahallendeki ustaları ve hizmet firmalarını buradan bulabileceksin.
> Hazır olduğunda bu ekran açılacak — uygulamayı güncellemene gerek
> kalmayacak.

Hiçbir dilde tarih, ay ya da "çok yakında" yok: kaçırılan bir tarih,
hiç tarih vermemekten daha çok güven kaybettirir. Son cümle bayrağın
sunucuda olmasının kullanıcıya bakan karşılığı.

Web metni kısa tutuldu (yönetici yüzeyi, "sen" değil "siz").

## 5. Yan bulgu: BFF tarama boşluğu kapatıldı

`/api/ozellikler` vekilini **silip tüm web suite'ini koşunca hiçbir test
düşmedi.** P163'te kilitlenen 405/404 sınıfı hâlâ kaçabiliyormuş: eski
tarama yalnız `apiSend("...")` çağrılarını ve yalnız `app/` + `components/`
altını görüyordu. `useSWR("/api/...")` ve düz `fetch("/api/...")`
çağrıları — özellikle `lib/` altındakiler — kapsam dışıydı.

`tests/bff-yol-eslesmesi.test.ts`'e ikinci tarama eklendi (136 çağrı).
Yol çözücü **geri izlemeli**: `app/api/panel/ice-aktarim/` yalnız `[id]`
taşıyor, kendi `route.ts`i yok — Next o isteği kardeş `[kaynak]` vekiline
verir. İlk yazımda düz dalı koşulsuz seçen çözücü, çalışan bir yolu
"eksik" diye raporladı; düzeltildi.

**Ölçmediğim şey:** `/api/x/${id}/...` biçimindeki açık uçlu çağrılarda
değişkenden sonrası kaynaktan bilinemiyor; orada yalnız dinamik bir
çocuğun varlığı doğrulanıyor, fazlası iddia edilmiyor.

## 6. Bayrağı açmak (ileride)

`.env.prod` içine `DUKKAN_MOBIL_ACIK=true`, sonra:

```
docker compose -f infra/docker-compose.prod.yml up -d --force-recreate api
```

`restart` **yetmez** — ortam değişkeni yeniden okunmaz. Doğrulama:

```
curl -s https://api.yonetio.site/ozellikler
```

`{"dukkan":true}` görülmeden istemci tarafında bir şey değişmez.
Mobil uygulamada sürüm çıkmasına gerek yoktur; kullanıcı uygulamayı
yeniden açtığında yüzey açılır.
