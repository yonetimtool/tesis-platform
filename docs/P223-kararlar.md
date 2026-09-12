# P223 — Kamera görüntüleme, otopark/plaka, rapor görselleştirme

Tarih: 2026-09-11

---

## §1 — Ana sayfada kamera karesi

### Ölçüm (tahmin değil, akış sürüldü)

Dev backend'de `yonetici@acme.com` ile gerçek akış sürüldü:

```
PATCH /cameras/{id} {"ana_ekranda": true}   -> 200, ana_ekranda: true
GET   /cameras?ana_ekranda=true&limit=10    -> meta.total: 1, items: ["Ana Kapı"]
GET   /cameras/{id}/kare                    -> 200 image/jpeg, 12 461 bayt
```

**Backend uçtan uca çalışıyor.** İşaret kaydediliyor, süzgeç süzüyor,
kare geliyor. Panonun attığı isteğin birebir aynısı denendi.

Veritabanı sayımı:

```
toplam kamera: 6 · aktif: 5 · ana_ekranda: 0
```

**Kök neden: işaretli kamera yok ve bu SESSİZ.**

| Yüzey | Kod | Davranış |
|---|---|---|
| Web | `components/KameraSeridi.tsx:81` → `if (gorunen.length === 0) return null;` | bölüm **hiç çizilmez** |
| Mobil | `yonetici_home_screen.dart:227` → `if (kameralar.isNotEmpty)` | bölüm **hiç çizilmez** |

Kullanıcının gördüğü: Kameralar sekmesinde kareler var (o sayfa **tüm**
kameraları çeker), ana sayfada hiçbir şey yok ve **neden olduğunu
söyleyen tek bir satır bile yok**. P217'nin dersi burada tekrarlanmış:
sıfır sonuç sessizce yutulmuş.

### İkinci bulgu — mobilde işaret KONULAMIYOR

`kamera_form_sheet.dart` `aktif` ve `sakinGorebilir` anahtarlarını
taşıyor ama **`anaEkranda` anahtarı yok**; `CameraDraft.toUpdateJson()`
da `ana_ekranda` göndermiyor. Yani mobilden yöneten bir kullanıcı bu
özelliği **hiç açamıyor** — ana ekranında neden kare olmadığını
anlamasının yolu da yok.

P213 §4'te bayrak backend + okuma tarafında yapılmış, **yazma tarafı
yalnız web'e konmuş**. Parite kuralı gereği açıkça yazıyorum: bu
turda kapatılıyor.

### Karar

1. **Boş hal artık sessiz değil.** İşaretli kamera yokken bölüm
   gizlenmiyor; "ana ekranda gösterilecek kamera seçilmedi" deniyor ve
   Kameralar sayfasına bağlantı veriliyor.
2. **Yalnız yönetim rolüne.** Sakine bu mesajı göstermek anlamsız
   olurdu: işareti koyamaz, yapabileceği bir şey yok. Sakinde eski
   davranış (bölüm gizli) sürüyor.
3. **Tesiste hiç kamera yoksa** mesaj farklı: "seçilmedi" demek yanlış
   yönlendirme olurdu.
4. **Mobile `anaEkranda` anahtarı eklendi** — web'deki kutunun karşılığı.

---

## §2 — RTSP canlı yayın

### Ölçüm: dev'de gerçek bir RTSP kaynağı yayımlandı

Dev makinesi dışarıya 554 açamıyor (`dial tcp 3.87.10.134:554: i/o
timeout`), yani seed'deki genel demo RTSP adresi ölçüm için kullanılamaz.
Bu yüzden **ağ içinde gerçek bir RTSP kaynağı kuruldu**: ayrı bir
MediaMTX konteyneri (`testcam`) + ffmpeg ile `rtsp://testcam:8554/cam`.

Backend'in canlı ucu bu kameraya karşı sürüldü:

```
istek 1: 502 (15 132 ms)  server_config   <- YANLIŞ TEŞHİS
istek 2: 502 (15 117 ms)  server_config   <- YANLIŞ TEŞHİS
istek 3: 200 (10 243 ms)  PLAYLIST
```

**Zincir çalışıyordu.** Kopan yer: `sourceOnDemand` gereği MediaMTX RTSP
kaynağına ancak ilk okuyucu gelince bağlanır ve o sırada playlist
isteğini **asılı tutar**. Bizim 15 saniyelik zaman aşımımız önce doluyor,
kod bunu `kamera_gecit_yok` (= "canlı yayın SUNUCU tarafında
yapılandırılmamış") sayıyordu.

Yani: **ilk tıklama her zaman başarısız**, üstüne yöneticiyi hiçbir
sorunu olmayan MediaMTX kurulumunu düzeltmeye gönderen bir mesaj. Üç
turdur "açılmıyor" denmesinin sebebi bu.

### İlk çözümüm yanlıştı — ölçüm gösterdi

Tekrar deneyen bir döngü yazdım. Doğrudan MediaMTX'e ölçünce (katmanlar
ayrılarak) çözüm değil **sebep** olduğu çıktı:

| Yaklaşım | Sonuç |
|---|---|
| Döngü, istek başına 12 sn | 12.0s zaman aşımı ×3, sonra 200 — **41.2 sn** |
| **Tek istek, 60 sn** | **200 — 33.8 sn** |

Her zaman aşımı, MediaMTX'in bekleyen isteğini iptal edip `sourceOnDemand`
döngüsünü sıfırdan başlatıyordu. Kısa zaman aşımı + tekrar denemek,
beklediğimiz şeyi sürekli öldürüyordu.

### Karar

- **Playlist isteği tek ve uzun** (`_CANLI_HAZIRLIK_BUTCESI = 40 sn`).
  Ölçülen soğuk başlangıç 33.8 sn; bütçeyi bunun altına çekmek, ölçülen
  gerçek davranışı "hata" saymak olurdu.
- **Segmentler beklemez** (15 sn): playlist döndüyse kaynak zaten hazır;
  orada uzun bütçe yalnız kopmuş bir yayını bekletirdi.
- **Teşhis tahminle değil SORARAK**: zaman aşımında `_gecit_ayakta()`
  MediaMTX API'sine sorar. Geçit ayaktaysa "henüz hazır değil"; gerçekten
  ulaşılamıyorsa "sunucu yapılandırması". Eskiden ikisi de ikincisiydi.
- **Kullanıcıya "Bağlanıyor…"** — 33 saniye boyunca siyah bir video
  göstermek, sorun yokken sorun var gibi görünmesiydi.

### Düzeltme sonrası uçtan uca

```
SOĞUK BAŞLANGIÇ, İLK TIKLAMA: 200 (36.3 s)
content-type: application/vnd.apple.mpegurl · 191 bayt
alt playlist: 200 · 315 bayt
```

### Ölçemediklerim — açıkça

- **Gerçek bir IP kameranın** (H265, kimlik doğrulamalı, LAN'da)
  hazırlanma süresi ölçülmedi. Dev'de yalnız sentetik H264 kaynak ve
  dışarıya çıkamayan bir ağ var. **33.8 sn bu ortamın sayısıdır**;
  sahada daha kısa olması beklenir ama 40 sn bütçenin yettiği ancak
  prod'da görülür.
- **Tarayıcının H265 desteği** ölçülemedi: dev'de H265 üretebilen bir
  kaynak yok ve tarayıcı testi gerçek bir makine gerektirir. İstemcideki
  kodek ön kontrolü (P216) yerinde duruyor ve değiştirilmedi.
- MediaMTX'te **37 artık yol** birikmiş (her test koşumu bir tane
  bırakıyor). Zarar vermiyor ama sınırsız büyüyor — bu turda
  dokunulmadı, ayrı bir iş.
