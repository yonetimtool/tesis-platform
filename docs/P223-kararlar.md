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

---

## §3 — Otopark sayacı

### Ölçüm: altyapının çoğu zaten vardı

| Parça | Ölçülen durum |
|---|---|
| `vehicle_pass` + açık geçiş = içeride | vardı |
| `GET /parking/occupancy` (kapasite/dolu/oran) | vardı |
| `tenant.otopark_kapasite` | **veritabanında vardı, hiçbir ekranda GİRİLEMİYORDU** |
| Giriş/çıkış işaretleme | vardı ama `_OPERATOR = admin + security` — **yönetici 403 alıyordu** |
| Sakinin boş yeri görmesi | **hiçbir yerde yoktu** |

Yani "kamera bağımsız sayaç" isteği, üç küçük boşluk yüzünden
karşılanmıyordu — modül eksik değildi.

### Karar

1. **Yönetici de işaretleyebilir** (`_OPERATOR`'e eklendi). Küçük
   sitelerde 7/24 güvenlik yok; yönetici sayacı düzeltemiyordu.
   **`resident` EKLENMEDİ**: kendi aracını "girdi" işaretleyen sakin
   başkasının yerini de doldurabilirdi ve sayaç doğrulanamaz hale
   gelirdi.
2. **Kapasite tesis ayarlarına eklendi** (yeni "Otopark" grubu).
   Sınırlar sunucuyla aynı (0–100 000); panelde dar bir aralık yazmak,
   sunucunun kabul ettiği değeri reddetmek olurdu.
3. **Sakin "N boş yer" görüyor** — aynı uçtan türetilmiş, ikinci uç yok.
   **Kapasite tanımsızsa boş yer UYDURULMAZ**: yalnız içerideki araç
   sayısı yazılır.
4. **Kapasite aşılırsa sunucu gerçek sayıyı döner** (oran %100 üstü
   olabilir); istemci "boş yer"i 0'da tabanlar — negatif boş yer
   kullanıcıya anlamsız gelir. Sayıyı sunucuda kırpmak veriyi yalan
   söylemek olurdu.

### Sıfırlama ve bildirim — analiz belgesinde, kod yazılmadı

`docs/P223-plaka-okuma-analiz.md` §4'te gerekçeleriyle:
- **Gece yarısı/vardiya sıfırlaması: HAYIR.** Doluluk bir *durum*dur,
  sayaç değil; sıfırlamak sabah 08:00'de dolu otoparkı "0" göstermek
  olur. Doğru araç **bayat geçiş süpürme**dir (24 saat, tesis ayarı).
- **Kritik doluluk bildirimi: EVET ama yalnız YÖNETİME**, eşik tesis
  ayarı, tekrarsız. Sakine göndermek istenmeyen bildirimdir.

Bu ikisi **onay bekliyor**, kod yazılmadı.

### Uçtan uca sürüldü (dev)

```
kapasite 50 yazıldı        -> 200
doluluk                    -> {'kapasite': 50, 'dolu': 3, 'oran': 6}
yönetici GİRİŞ işaretledi  -> 201
doluluk                    -> dolu 4, oran 8
yönetici ÇIKIŞ işaretledi  -> 200
doluluk                    -> dolu 3, oran 6
```

---

## §4 — Rapor ve veri görselleştirme

### Ölçüm önce: neyimiz var

| Katman | Ölçülen durum |
|---|---|
| Web grafik kütüphanesi | **recharts ^2.15.4** — tek kütüphane, her ekranda aynısı |
| `components/ui/grafik.tsx` | vardı: tema paleti, **her zaman sayısal tablo**, boş veri durumu, tembel yükleme — ama **yalnız PASTA** |
| `components/rapor/rapor-grafik.tsx` (P181) | sütun/çizgi/pasta + boş durum + büyük veri örnekleme |
| PDF çıktısı (P181) | logo, site adı, rapor adı, dönem, zaman damgası, **"Sayfa n / m" iki geçişli**, gömülü pasta/çubuk |
| Excel çıktısı (P181) | `PieChart` / `BarChart` / `LineChart` |
| **Mobil** | **hiç grafik yok** — kütüphane de yok, `CustomPaint` de |

Çıktılar gerçekten üretiliyor (dev'de çalıştırıldı):

```
PDF:  3 683 bayt  b'%PDF-'
XLSX: 6 741 bayt  b'PK'
BOŞ VERİ PDF: 1 938 bayt   (grafik sayfası eklenmiyor)
```

Yani §4'ün "**İNDİRİLEN DOSYALAR**" maddesi P181'de zaten karşılanmıştı;
yeniden yazmadım, **çalıştığını doğruladım**.

### Bu turda yapılan

**Web — grafik türleri.** `Grafik` bileşenine `tur` eklendi:
`pasta · cubuk · cizgi · yatay · otomatik`.

- **Tür seçimi TEK YERDE** (`grafikTuruSec`): her çağıranın ayrı karar
  vermesi, aynı veriyi iki ekranda iki farklı biçimde göstermek olurdu.
- **`otomatik` kuralı kullanıcının kuralıdır**: 6 dilime kadar pasta,
  fazlasında çubuk. Sınır `PASTA_DILIM_SINIRI` sabitinde.
- **Açıkça istenen tür ezilmez**: 3 noktaya düşen bir zaman serisi
  çizgi kalır — "az veri" diye pastaya çevirmek zaman eksenini yok
  etmekti.
- **Yatay çubuk** yaşlandırma kovaları için: "90+" gibi etiketler dikey
  eksende kırpılır; yatayda kova sırası yukarıdan aşağıya doğal okunur.
  Borçlular sayfasına eklendi (kovalar o güne kadar yalnız düğme
  olarak diziliyordu).
- Renk kuralı değişmedi ve değişmemeli: bileşen **her zaman** sayısal
  tabloyu da çizer, grafik `aria-hidden`dır.

**Mobil — grafik kartı.** `core/grafik/grafik_karti.dart`.

- **Kütüphane EKLENMEDİ.** Çizilen şey oransal çubuklar; `LayoutBuilder`
  + `Container` yetiyor, `CustomPainter` bile gerekmiyor. Üç ekran için
  kalıcı bir bağımlılık, sürüm yükseltme yükü ve APK boyutu demekti.
  İhtiyaç çizgi/pasta grafiğe dönerse karar yeniden verilir.
- Web'le **aynı üç kural**: sayı her çubuğun yanında (renk tek başına
  anlam taşımaz), veri yoksa grafik çizilmez, renkler `colorScheme`den
  (karanlık temada okunur).
- Bütçe ekranındaki kategori kırılımına bağlandı; **alttaki liste
  kaldırılmadı** — kategori tipi/ikonu orada.

### Bu turda YAPILMADI — açıkça

Kabul kriteri 6 ("raporlarda grafikler var, veri türüne uygun") **web'de
karşılandı, mobilde kısmen**:

- **Mobilde yalnız bütçe kategori kırılımı** görselleşti. Devriye/vardiya
  raporları, şikayet dağılımı ve şeffaflık ekranı mobilde hâlâ düz
  liste.
- **Mobilde çizgi ve pasta yok** — bileşen yalnız çubuk çiziyor. Zaman
  serisi (tahsilat oranı, doluluk) mobilde görselleşmedi.
- **Web'de şikayet dağılımı ve devriye/vardiya raporları** için yeni bir
  grafik eklenmedi; mevcut rapor grafiği (P181) katalogdaki `grafik`
  tanımına bağlı ve o tanımlar gözden geçirilmedi.

Bunlar bu turun dışında kaldı; uydurup "yapıldı" demiyorum.

---

## Tam takım koşumundan çıkan iki ders

**1. Üç takımı aynı anda koşturmak sekiz sahte hata üretti.** Web
suite'inde `Test timed out in 5000ms` diyen sekiz test, tek başına
koşunca 38/38 geçti. Sebep koddaki bir gerileme değil, aynı makinede
backend + mobil + web'in yarışmasıydı. Bundan sonra takımlar **en fazla
ikişer** koşturulacak; "kırmızı" bir sonucu koda yormadan önce yalıtımda
tekrarlanmalı.

**2. Ölçüm için kurduğum konteyner, başka bir testin kaynağını çaldı.**
§2'yi ölçmek için `testcam` ağ adıyla bir MediaMTX konteyneri açtım —
oysa dev'de P216'dan kalan **gerçek bir `testcam`** ve ona H265 yayını
yapan `testpub265` zaten vardı. Benim konteynerim adı gölgeledi; ayrıca
api konteynerini defalarca yeniden yaratmam H264 yayıncısı `testpub`'ı
düşürdü. Sonuç: `test_p216_kodek.py` "H264 kaynak `None` göründü"
dedi — **koda bağlı olmayan bir hata**.

Düzeltme: kendi konteynerimi sildim, `testpub`'ı geri başlattım, kodek
testleri 9/9 yeşile döndü. Ders: ölçüm için ortam kurarken **var olan
adları** önce sorgula; `docker ps -a` bir dakikada söylüyordu.
