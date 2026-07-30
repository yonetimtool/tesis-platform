# Ölçülmeyen durumlar — ikinci envanter (tur 49)

**Tarih:** 2026-07-29 · **Kapsam:** mobil (Flutter) + panel (admin-web) + veri

Tur 36'nın envanteri (A–F) tur 37–48 arasında **kapatıldı**. Bu belge, o
kapanıştan **sonra** kalan kör noktaları listeler. Yine tahmin yok: her madde
kapsam (coverage) verisinden, canlı sayfadan, veritabanı sayımından ya da
sürüş araçlarının kendi kodundan geliyor.

**Mobil presentation kapsamı: 9 001 / 13 302 = %67,7.**
Panelde 26 sayfanın 25'i en az bir sürüş listesinde.

---

> **GÜNCELLEME (tur 53).** A **tamamen kapandı**: okutulmuş demirbaş kartları
> (4 zimmet kararı + işlem sürüyor) ve fotoğraf vazgeçme dalı sürüldü.
> `assets_screen` %37 → %84. Bulgu çıkmadı.
>
> **GÜNCELLEME (tur 50).** A'nın büyük kısmı kapatıldı: 7 eylem zinciri beş
> eksende sürülüyor (personel/sakin menü eylemleri + vardiya atama). Bir
> **layout assertion** bulundu (`ListTile.trailing` 320 dp'de tile'ı yiyor).
> Açık kalan: `assets` `_ScannedCard`/`_HistoryCard` (NFC ile okutulmuş
> demirbaş durumu) ve fotoğraf seçiminden **vazgeçme** dalı.

## A. Kullanıcı EYLEMİ sonrası durumlar (en büyük küme)

Sürüşler ekranı çiziyor (tur 23–37), formu açıyor (tur 38), fotoğraf
yüklüyor (tur 39), onay diyaloğunu açıyor (tur 40). Ama **satır menüsü →
eylem → sonuç** zinciri hiç yürütülmüyor. Kapsam açıkları tam bu bloklarda
toplanıyor:

| Blok | Açık satır | Ne kaçırılıyor |
|---|---|---|
| `staff_screen` satır menüsü + parola sıfırlama | 132‑155, 159‑187 | personeli pasifleştirme, geçici kod diyalogu |
| `residents_screen` sil / parola sıfırla / düzenle sayfası | 112‑152, 213‑239 | sakin düzenleme alt sayfası hiç çizilmiyor |
| `assets_screen` `_ScannedCard`, `_HistoryCard` | 137‑192, 264‑302 | NFC ile okutulan demirbaş kartı ve zimmet geçmişi |
| `vardiyalar_screen` `_AtamaSheet` | 116‑193 | vardiya atama alt sayfası |
| foto seçiminden VAZGEÇME dalı (`file == null`) | 4 ekranda | kullanıcı kamerayı kapatınca ne oluyor |

> **GÜNCELLEME (tur 51).** `set_password_screen` kapatıldı: dört hâl beş
> eksende sürülüyor, kapsam %1 → **%88**. Açık kalan tek dosya
> `task_ticket_widgets` (1/60).

## B. Hiç çizilmemiş kalan iki dosya

| Dosya | Kapsam | Not |
|---|---|---|
| `auth/presentation/set_password_screen.dart` | **1 / 83** | tur 36'da listelenmişti, hâlâ açık: geçici parola → kalıcı parola akışı (ilk giriş!) |
| `tasks/presentation/task_ticket_widgets.dart` | **1 / 60** | talepten gelen iş emri rozetleri |

> **GÜNCELLEME (tur 54).** C'nin mutasyon kısmı kapatıldı: 4 kip × 3 dil ×
> 6 form = 72 gönderim, üründe **0 bulgu**. Üç yanlış alarm/kör nokta
> dedektörde düzeltildi. Açık kalan: `/tenants/[id]` hâlâ hiçbir sürüş
> listesinde yok.

## C. Panelde mutasyon akışları

Bütün panel sürüşleri **yalnız okuma** yapıyor: `rapor-surusu` ve
`foto-surusu` birer düğmeye basıyor, gerisi GET. Dolayısıyla ölçülmeyenler:

* **oluşturma/güncelleme/silme sonrası** durumlar (başarı toast'ı, listenin
  tazelenmesi, satırın kaybolması),
* **doğrulama hataları** (422 alan hataları formda nasıl görünüyor),
* **çakışma** (409 — aynı kaydı iki sekmede düzenleme),
* **oturum düşmesi** (401 mid-session → `/login`e yönlendirme).
* ~~`/tenants/[id]` **hiçbir sürüş listesinde yok**~~ **KAPANDI (tur 61).**

## D. Eksen değerleri sabit — ölçülmeyen kombinasyonlar

| Eksen | Ölçülen | Ölçülmeyen |
|---|---|---|
| Hareket | `reducedMotion: reduce` (panel), `pumpAndSettle` (mobil) | **animasyon sürerken** hiçbir şey ölçülmüyor — tur 30'da tam bu yanlış alarm vermişti, şimdi kör nokta |
| Yön | dikey (mobil), yatay yok | tablet/yatay yerleşim; kamera ekranı yatayı zorluyor ama ölçülmüyor |
| Yazı ölçeği | 1.0 ve 2.0 | 0.85 (küçültme), 1.3 (yaygın ara değer) |
| Genişlik | 320/430 (mobil), 360/1280 (panel) | tablet (768), ultra-geniş (1920+) |
| Yoğunluk | `devicePixelRatio = 1.0` | 2.0/3.0 (gerçek cihazlar) — piksel kırpma/kenar yuvarlama |
| Sistem ayarı | tema (açık/koyu) | **kalın yazı** (bold text), yüksek kontrast, renk körlüğü filtreleri |

> **GÜNCELLEME (tur 57).** Tint zemin kalıbı kapatıldı — ve içinden
> beklenmedik bir bulgu çıktı: **açık tema da başarısızdı** (`Colors.orange`
> 1,92; `green` 2,42; `blue` 2,66). `okunurVurgu` iki yönlü yapıldı ve
> `test/tint_kontrast_denetimi_test.dart` ile hesap tabanlı olarak kilitlendi
> (12 renk × 4 opaklık × 2 tema).
>
> **GÜNCELLEME (tur 52).** B kapandı (`task_ticket_widgets` %2 → %96).
> **YENİ KÖR NOKTA (E'ye eklendi):** `textContrastGuideline` küçük/ince
> metinde yetersiz — sabit renk + tint zemin kalıbı koyu temada 2.06:1
> verirken kılavuz geçiyor. Bu kalıp `lib/src` içinde **29 yerde daha** var
> (`withValues(alpha: 0.1x)` ile tint zemin): complaints (3), transparency
> (2), reports (2), patrol_tracking (2), etkinlik (2), … Elle hesap ya da
> daha sıkı bir ölçüm gerekiyor.

> **GÜNCELLEME (tur 59).** D **kapandı** — ve en verimli tur bu oldu.
> Eksen değerleri genişletildi: mobilde 7 kombinasyon × 3 dil
> (`eksenKombinasyonSurusu`: 0,85×/1,3× ölçek, tablet dikey/**yatay**,
> telefon yatay, **kalın yazı**, dpr 2,0/3,0) + `animasyonSurusu` (kare kare,
> sonsuz animasyonlu ekranlarda da). Panelde 5 yeni ölçü + **`ANIMASYON
> sururken`** kipi (`networkidle` yerine `domcontentloaded`).
>
> **Mobilde bulgu çıkmadı, panelde 63 bulgu çıktı.** Hepsi tek eksende
> yoğunlaştı: `320 px + 22 px kök yazı` (kalın yazı/büyük font kullanan
> erişilebilirlik ayarı). Düzeltilenler: sayfa başlığı uzun Almanca bileşik
> kelimede taşıyordu (`min-w-0` + `break-words`), sabit genişlikli filtre
> kutuları (`w-52/48/64` → `w-full sm:w-*`), bildirim satırı, duyuru eylem
> çifti, talep iş-emri şeridi, şeffaflık kartı, alarm satırı, giriş başlığı ve
> pano KPI ızgarası (2 kolonda 70 px içerik kalıyordu).
>
> **YAN BULGU — asıl değerli olan:** kalın yazı sürüşü Almanca `/notifications`
> sayfasında **"Okundu"** butonunu gösterdi. Bu bir TR sızıntısıydı ve tur
> 47'nin taraması onu görmemişti: `METIN` kalıbı `\n` hariç tutuyordu, yani
> Prettier'in kendi satırına sardığı metin düğümleri **hiç taranmıyordu**.
> Tarama düzeltilince **17 sızıntı** çıktı; ardından iki kalıp daha eklendi
> (süslü parantezli prop `detail={...}` ve karışık metin düğümü
> `>Toplam {n} · …<`) ve **11 sızıntı daha** çıktı. Toplam **28**.
>
> En çarpıcısı: panonun dört KPI açıklaması (`{n} plan penceresi`,
> `{n} turdan`, `tur yok`, `ilgilenilmeli`) ile `haritaKat` — **sözlük
> anahtarları zaten vardı ve yedi dile çevrilmişti**, sayfa hiçbirini
> kullanmıyordu. Panelin amiral sayfası altı dilde Türkçe gösteriyordu.
>
> **YENİ ARAÇ: `tools/tr-sizinti-surusu.mjs`** — mobilde her sürüşte çalışan
> `trSizintisiYok`ın panel karşılığı yoktu (bu yüzden yukarıdaki hata yıllarca
> hayatta kaldı). Karaktere ("ğışç") değil **sözlüğe** bakar: sayfa `de`
> boyanırken TR sözlüğünün bir değeri birebir geçiyorsa sızıntıdır. 23 sayfa ×
> 6 dil = 138 koşum, `DENEY=1` kendi kendini sınar, VERİ izin listesi
> (`(Kurulum bekliyor)` yer tutucu adı, vardiya adları, kategori adları)
> gerekçeleriyle yazılıdır. Şu an **138/0**.
>
> **BİR OLAY: ölçüm GEÇERSİZ olabilir ve fark edilmez.** Sürüş koşarken
> `next build` çalıştırdım; çalışan sunucunun altından `.next` değişti, CSS
> **400** döndü ve sayfa **stilsiz** boyandı. O hâlde "taşma" ölçümü tamamen
> anlamsızdır (`overflow-hidden` bile uygulanmıyordu) ama araç yine de düzgün
> görünen bir rapor üretti — 63 yerine sahte bir tablo taşması. Artık sürüş her
> bağlamda ölçümden **önce** stilin uygulandığını doğruluyor; doğrulanamazsa
> `CSS UYGULANMADI — olcum GECERSIZ` basıp o bağlamı atlıyor.
>
> **DEDEKTÖRÜN KENDİ TESTİ** (`test/eksen_kombinasyon_dedektor_test.dart`, 5
> test): yedi kombinasyonun agaca **ayrı ayrı** ulaştığı (yedi farklı eksen
> imzası — `MaterialApp` kendi `MediaQuery`sini eklerse hepsi aynılaşırdı),
> yalnız 320 dp'de ve yalnız kalın yazıda taşan kusurların yakalandığı, ve
> `animasyonSurusu`nun **hiç durmayan** ekranda ölçüm yapabildiği kanıtlanıyor.
> Bu son test kendi helper'ımdaki gerçek kusuru buldu: sondaki `pumpAndSettle`,
> sürüşün kapsamak için var olduğu ekran sınıfında sürüşün kendisini
> düşürüyordu (`bekleyen` bayrağı eklendi).
>
> **Ayrıca:** tam suite `00:24`'te koşarken `rezervasyon_screen_test` düştü —
> kurgu "00:00–00:30 geçmiş, 23:00–23:59 aktif" varsayımına dayanıyordu ve gece
> yarısından sonra tersine dönüyor. Tur 53'ün backend'de çözdüğü sınıfın aynısı.
> `_gecti`nin saati artık dışarıdan verilebiliyor (`rezSimdi`,
> `@visibleForTesting`) ve test bugünün 12:00'sini sabitliyor.
>
> **Sayılar:** panel dar-ekran sürüşü **1104/0** (önce 63), TR sızıntı sürüşü
> **138/0** (önce 54 satır / 9 ayrı kusur), panel birim testleri 105/105,
> mobil dedektör 5/5.

> **GÜNCELLEME (tur 60).** E'nin iki maddesi kapandı: **okuma sırası** ve
> **görsel regresyon**.
>
> **Okuma sırası.** Mobilde sıra artık gerçek API'den okunuyor
> (`debugListChildrenInOrder(traversalOrder)`) ve *geriye atlama* aranıyor;
> 19 ekran × 2 dil (tr + ar), **0 ihlal**. Panelde karşılığı yeni bir araç:
> `tools/okuma-sirasi-surusu.mjs` — DOM sırası ile görsel sıra karşılaştırılıyor
> (CSS `order-*`, `flex-*-reverse`, absolute yerleşim sırayı bozabilir; axe
> buna bakmaz), 24 sayfa × 2 dil = **48/0**.
>
> Kural iki kez düzeltildi, ikisi de dedektörün kendi sınaması sayesinde:
> (1) ilk sürüm "arada boşluk olsun" istiyordu, bu yüzden **bitişik** satırların
> ters okunmasını yakalamıyordu; (2) çok kolonlu kart ızgarasında yanlış alarm
> veriyordu — okuyucu bir kartı bitirip sonraki kartın başına dönmesi
> **doğru** davranıştır, bu yüzden dikey geri atlama artık yalnız **aynı
> kolonda** ihlal sayılıyor. Panelde bu düzeltme panonun dört KPI kartındaki
> dört yanlış alarmı kaldırdı.
>
> RTL'de bir ayrım öğrendim: Flutter gezinme sırasını semantik ağaçtaki
> `textDirection`a göre kuruyor; **çıplak `Directionality` yetmiyor**,
> `Localizations`/`MaterialApp` zinciri gerekiyor. Sentetik kurguyla yapılan
> RTL ölçümü ürünü değil kurguyu ölçer — dedektör testi bu yüzden gerçek
> `l10nApp(locale: ar)` yolunu kullanıyor.
>
> **Görsel regresyon.** Piksel golden'ı bilinçli olarak regresyon testi
> yapılmamıştı (font/Skia'ya duyarlı, diff'i okunamaz). Yerine **yerleşim
> kilidi**: her görünür yazının konumu + ölçüsü + içeriği sıralanıp
> `test/yerlesim/<ad>.txt` dosyasına yazılıyor; diff okunabilir ("şu yazı 12 px
> aşağı kaydı"). **19 ekran kilitlendi** (önce 1 golden vardı, o da regresyon
> değildi). Bilinçli güncelleme:
> `flutter test --dart-define=KILIT_GUNCELLE=true`.
>
> Kilit ilk kuruluşunda üç şey buldu: (1) `allRenderObjects` aynı
> `RenderParagraph`ı altı kez veriyor — tekilleştirmeden diff okunmaz;
> (2) fikstür verisi bilinçli olarak "şimdi"ye göreli olduğu için ekrandaki
> saat/tarih **her dakika** sapma raporluyordu (konum/ölçü aynen korunup yalnız
> saat/tarih parçası maskelendi); (3) üç ekran (`destek`, `vardiyalar`,
> `yonetici_iletisim`) **boş hâl** çiziyordu — `enAz` eşiği yakaladı, dolu veri
> verildi. Kilidin kendi testi kararlılığı ve **8 px'lik bir dolgu farkına
> duyarlılığı** kanıtlıyor.
>
> **Panel dedektöründe bir tuzak daha:** `DENEY=1` enjeksiyonu
> `DOMContentLoaded`da yapılınca React hidrasyonu düğümü **siliyor** ve dedektör
> kendi kusurunu göremiyor. Enjeksiyon ölçümün hemen öncesine alındı (tur
> 54'teki dersin aynısı). Ayrıca ihlal listesindeki **6'lık tavan** artık
> "(+N ihlal daha — tavan)" satırıyla bildiriliyor: sessiz tavan, ölçülmemiş
> alan demektir — ilk sürümde enjekte edilen kusur tam bu yüzden görünmedi.
>
> **Bir de kendi hatam:** `dart format test/*.dart` çalıştırdım ve 112 dosya
> yeniden biçimlendi (tur 40'ta aynı hatayı yapmıştım). Depodaki dosyalar eski
> formatter stilinde; yeni SDK stili her dosyayı baştan sona değiştiriyor.
> İlgisiz 107 dosya geri alındı. Bu sırada ikinci bir hata ortaya çıktı: yeni
> test bloklarını "son `});`den sonra" ekleyen betiğim blokları bir `for`
> döngüsünün/grubun içine koymuş, bu yüzden bazı testler iki-üç kez
> kaydolmuştu; ayrıca `main`den sonra üst düzey sınıf tanımı olan dosyalarda
> (`bina_complaints`'te `_PatlayanMapApi`) blok sınıfın içine düşüyordu.
> Ekleme artık `void main(` satırından sonraki ilk sıfır-girintili `}` önüne
> yapılıyor ve her test bir kez koşuyor.
>
> **Sayılar:** okuma sırası mobil 19 ekran × 2 dil → **0 ihlal**; panel
> **48/0**; yerleşim kilidi **19 ekran** (kilit dosyaları git'te); dedektör
> testleri mobil **4 + 3**, panel `DENEY=1` **OK**.

## E. Kalite eksenleri (hiç kurulmamış)

* ~~**Anlamsal okuma SIRASI.**~~ **KAPANDI (tur 60).** Etiketlerin *varlığı*
  tur 29/30'da ölçülmüştü, sırası ölçülmüyordu.
* ~~**Canlı bölge duyurusu.**~~ **KAPANDI (tur 56).** Panelde `ErrorBox`,
  `/login` ve `/dashboard` hata kutularına `role="alert"`; mobilde statik hata
  bantlarına `Semantics(liveRegion: true)`. **Bu maddedeki iddiam kısmen
  yanlıştı:** Flutter'ın `SnackBar`'ı zaten `liveRegion: true` kullanıyor, yani
  tur 45'in push bildirimi sessiz değildi; eksik olan statik bantlardı.
* ~~**Görsel regresyon.**~~ **KAPANDI (tur 60)** — piksel yerine yerleşim
  kilidiyle: `test/yerlesim/*.txt`, 19 ekran.
* ~~**Performans.**~~ **KAPANDI (tur 61)** — uzun listede kaydırma ve büyük
  fotoğrafın bellek etkisi ölçüldü; ikisinde de gerçek bulgu çıktı.

> **GÜNCELLEME (tur 58).** F **kapandı**: complaint `reddedildi`, kargo
> `teslim_alindi` ve `unit_access_permission` (3 durum) seed'e eklendi.
> Tazelik denetimi artık **durum kapsamasını** da ölçüyor (4/4, 2/2, 3/3,
> 3/3). Mobilde talep-reddedildi ve erişim izninin üç durumu beş eksende
> sürüldü; panel sürüşü 336/0.

## F. Veri durumu — hâlâ boş ya da BAYATLAYAN

| Durum | Şu an | Not |
|---|---|---|
| `unit_access_permission` | **0 kayıt** | daire erişim izni listesi hâlâ boş (tur 36'da da açıktı) |
| complaint `reddedildi` | yok | dört durumdan biri hiç görülmedi |
| kargo `teslim_alindi` | yok | |
| `patrol_window` `bekliyor` | **artık yok** | seed "bugün" penceresi açtı, zamanla `kacirildi`ya döndü |

> **GÜNCELLEME (tur 55).** Bayatlama **kapatıldı**: devriye pencereleri saat
> başına hizalandı (idempotent — 22 → 3 pencere) ve yaklaşan etkinliklerin
> tarihi her koşumda tazeleniyor. Seed artık kendi çıktısını denetleyip
> `tazelik:` satırları basıyor; sıfır çıkan `BAYAT/BOS` işaretlenir.
> Kalan boş veri durumları (F tablosu) tur 58'de.
>
> **SEED ZAMAN İÇİNDE BAYATLIYOR** — bu ayrı bir kör nokta sınıfı. Tur 41'de
> eklenen "bugün aktif tur" penceresi artık kaçırılmış görünüyor; yani
> `/dashboard`ın **aktif tur** hâli bugün sürülse yine boş çıkar. Sabit
> tarihli seed verisi, ölçümün sonucunu **takvime bağımlı** yapıyor.


> **GÜNCELLEME (tur 61).** Envanterde açık kalan son iki kalem kapandı ve
> ikisinden de gerçek bulgu çıktı.
>
> **`/tenants/[id]` (C).** Dinamik rota olduğu için hiçbir sürüş listesinde
> yoktu. Listeye `/tenants/:id` yer tutucusu yazılıyor,
> `tools/tesis-id.mjs` oturum açıldıktan sonra **kurulumu tamamlanmış** bir
> tesisin kimliğiyle değiştiriyor (yer tutucu tesisin detayı yönetici formunu
> çizmez, ölçüm zayıf kalır). Kimlik çözülemezse yol **atılır** — uydurma bir
> id ile 404 sayfasını ölçüp "temiz" demek, ölçmemekten kötüdür. Beş sürüşe
> eklendi: dar-ekran, okuyucu, klavye, TR-sızıntı, okuma-sırası. Bulgu yok.
>
> **YAN BULGU — ölçümü kirleten test artığı.** `/tenants` sayfasını açınca
> **101 tesis** göründü; 100'ü `(Kurulum bekliyor)` yer tutucusu. Kök neden:
> `test_tenants.py` `POST /tenants` ucunu onlarca kez çağırıyor ama yalnız
> silme testi kendi kaydını siliyor; her koşum kalıcı satır bırakıyor (yalnız
> `test_tenants.py` bile **10 tesis** bırakıyor — ölçtüm). Yani panelin
> `/tenants` sayfası aylardır bu hâlde ölçülüyordu ve TR-sızıntı sürüşü
> "Kurulum"/"bekliyor" kelimelerini VERİ diye izin listesine almak zorunda
> kaldı. `kurulum-bekliyor-` öneki `FIXTURE_SLUG_ONEKLERI`ne eklendi (tur
> 46'nın artık temizliği); 100 satır silindi.
>
> **Büyük fotoğrafın belleği (E).** `lib/src` içindeki **17** ağ görseli
> çağrısının **hiçbiri** çözme sınırı vermiyordu: 40×40 dp'lik avatar da 96
> dp'lik liste minyatürü de fotoğrafı **tam çözünürlükte** belleğe açıyordu
> (4000×3000 JPEG ≈ 48 MB RGBA). Hiçbir sürüş bunu göremezdi — görsel taklidi
> (tur 34) minik bir PNG servis ediyor, yani çözme boyutu hiç zorlanmıyor.
> Kusur ölçümle değil **kod okumayla** bulundu. `cozmeSiniri(context, dp)` ve
> `sinirliGorsel(...)` eklendi, 17 çağrı sınırlandı; tam ekran görüntüleyiciler
> (`InteractiveViewer`) ekran genişliğinin iki katıyla sınırlı. Kural
> `test/gorsel_cozme_denetimi_test.dart` ile kilitli: statik tarama + `cacheWidth`ın
> gerçekten `ResizeImage` ürettiğinin çalışma-anı kanıtı + taramanın kasıtlı
> kusuru gördüğü sınama.
>
> **Uzun liste (E) — ve düzelttiğim bir iddia.** Tarama tek eager veri listesi
> buldu (`unit_access_records_screen`). İlk iddiam "500 satır yerleşime
> giriyordu" idi; **yanlış.** Dedektör testi gösterdi ki `ListView(children:)`
> eleman düzeyinde zaten tembeldir (`SliverChildListDelegate`). Gerçek fark:
> `children:` kalıbı ekran her yeniden inşa edildiğinde **500 widget nesnesi**
> kuruyordu (liste literali `build` içinde materyalleşir); `builder` yalnız
> görünenleri kuruyor — ölçülen 500 → ~10. Kazanç yerleşimde değil, her
> karedeki O(N) nesne inşasında. Ekran `ListView.builder`a çevrildi ve üç test
> bu ayrımı kayda geçiriyor. Not: iki API de (`visitor_api`, `kargo_api`)
> 200'lük sayfalarla **tüm** veriyi çekiyor, üst sınır yok — bu ayrı bir konu,
> dokunulmadı.
>
> **`/tenants/[id]` sürülünce çıkanlar.** Sayfa ilk kez ölçüldü ve iki şey
> buldu: (1) 320 px + 22 px kök yazıda **+14px taşma** — üç dilde de aynı, yani
> metin uzunluğu değil yerleşim: 36 karakterlik UUID sarılamıyordu
> (`break-all` + `min-w-0`), `justify-between` satırları sarmıyordu, iki
> kolonlu `dl` bölünmeyen telefon/kimlik değerlerinde kolonu aşıyordu.
> (2) **dört TR sızıntısı** ("kurulum bekliyor", "aktif", "pasif", "parola
> belirlendi") — hepsi `{koşul ? t(...) : "TR metin"}` kalıbında.
>
> **Tarayıcıya üçüncü kalıp (tur 61).** Tur 59 bu kalıbı yalnız
> **özniteliklerde** yakalıyordu, JSX **çocuğu** olarak değil. Üçlü ifade
> kuralı eklendi ve **16 sızıntı** daha çıktı: `Zimmet`, `Tümü`,
> `Blok silindi.`, `· Bloksuz`, `pasif` (dört sayfada), `Test`,
> `Detay / Aidat`, `Parola (opsiyonel)`, `En az 8 karakter`, `Tahsil et`,
> `Tahakkuk ekle` ve **CSV çıktısındaki** `var/yok`, `evet/hayir`. Yanlış
> alarmlar için iki süzgeç yazıldı: Tailwind sınıf dizgeleri (üçlülerin çoğu
> `className` seçimidir) ve teknik değer listesi (`emerald`, `security`,
> `application/json`…).
>
> **Bir denemeyi geri aldım.** TR sızıntı sürüşünü harf duyarsız yaptım —
> mantık şuydu: sözlükte "Aktif", sayfada "aktif" olduğu için sürüş o dördü
> kaçırmıştı. Sonuç **76 bulgu** ve hepsi VERİ: backend'in ürettiği Türkçe
> alarm metni ("Gece devriyesi turu kaçırıldı (3 eksik kontrol noktası)") ve
> seed'deki Türkçe talep/destek içeriği sözlük değerlerini alt-dize olarak
> içermeye başladı. Kelime sınırı eklemek (Unicode harf sınıfıyla; `\b`
> Türkçe harflerde yanlış çalışıyor) 76'yı 13'e indirdi ama 13'ü de izin
> listesine almak gerekecekti — yani dedektör körleşecekti. Karar:
> karşılaştırma **harf duyarlı** kaldı, kelime sınırı korundu, ve varyant
> sınıfı **kaynakta** yakalanıyor (statik tarama o dördünü zaten buldu).
>
> **Açık kalan (yeni):** panonun alarm metinleri **backend'de Türkçe üretilip
> saklanıyor**; hangi dilde okunursa okunsun Türkçe görünüyor. Bildirim
> gövdeleri için `push_metinleri.py`/`akis_metinleri.py` var ama `alarm`
> tablosuna yazılan metin çeviriden geçmiyor. Bu ayrı bir tasarım kararı
> (saklanan metni mi çevirmeli, yoksa yapı taşıyıp okuma anında mı üretmeli) —
> bu turda dokunulmadı.
>
> **Sayılar:** dar-ekran **1150** sayfa-dil-ölçü (`/tenants/[id]` dahil) → 3
> bulgu → düzeltme sonrası 0; TR sızıntı **144/0**; okuyucu **350/0**; klavye
> **50/0**; okuma sırası **50/0**; mobil **1216** test; panel birim 105/105.
> Tesis sayısı 101 → 11 ve artık büyümüyor.

## Kör nokta OLMAYANLAR (bilerek dışarıda)

* Backend uçlarının kendisi — 762 pytest testi kapsıyor.
* `data/*_api.dart` düşük kapsam — sürüşler API'yi bilerek sahteliyor.
* Para biçimi (TL + Türkçe gruplama) dile duyarsız — politika.

## Öneri sırası (etkiye göre)

1. **Eylem zincirleri** (A) — kapsam açığının en büyük kümesi, hepsi gerçek
   kullanıcı yolları.
2. **`set_password_screen`** (B) — ilk girişin tek yolu, hâlâ 1/83.
3. **Panelde mutasyon + 401/409** (C).
4. **Seed'in bayatlaması** (F notu) — "bugün" verisi koşum anına göre
   üretilmeli; aksi hâlde ölçüm takvime bağlı.
5. **Canlı bölge duyurusu** (E) — küçük değişiklik, ekran okuyucu için büyük
   fark.
6. Kalan eksen kombinasyonları (D).
