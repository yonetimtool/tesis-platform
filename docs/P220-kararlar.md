# P220 — Kararlar

> Beş bölüm, her biri ayrı commit. Bu belge her bölüm bittikçe büyüyor.

---

## §1 — Şikâyet sayısı: görünür sayı ile eşik sayacı ayrıldı

### Önce ölçtüm, tahmin etmedim

Kusurun nerede olduğunu bulmak için gerçek akışı sürdüm: şikâyet
oluşturdum, pencereyi 24 saate ayarladım, sonra kaydı 48 saat geriye
alıp (**silmeden**) dört ayrı yanıtı ölçtüm.

| Ölçüm | Taze | 48 saat eski | Değerlendirme |
|---|---|---|---|
| yönetim `complaint_count` | 1 | **0** | ✓ P219'da pencereye bağlanmış |
| yönetim `/density.acik_sayisi` | 1 | **0** | ✓ |
| **sakin `benim_acik_sayisi`** | 1 | **1** | ✗ **KUSUR** |
| **sakin `benim_sikayetim`** | true | **true** | ✗ **KUSUR** |
| `/mine` toplamı | 1 | 1 | ✓ (bilinçli — aşağıda) |
| liste toplamı | 1 | 1 | ✓ (görünürlük filtresi, veri silme değil) |

**Kusur tam olarak buydu:** P219 haritanın penceresini `complaint_count`
için kurmuş, sakinin **kendi** sayımını atlamıştı. Aynı ızgarada,
haritadan düşmüş bir şikâyet sakinin hücresinde görünmeye devam
ediyordu — kullanıcının bildirdiği şeyin birebir kaynağı.

İronik olan: P219'un `building-map` içindeki notu *"iki uç aynı haritayı
besliyor ve birinde filtreleyip ötekinde filtrelememek, aynı ekranda iki
farklı sayı göstermek olurdu"* diyor. Gerekçe doğru yazılmış, **bir sütun
atlanmış**.

### Web'de aynı sorun var mı — kontrol edildi

**Yok.** `admin-web` dashboard'ı hücre durumunu `complaint_count`'tan
türetiyor (`(u.complaint_count ?? 0) > 0`), o da pencereye bağlı.
`benim_acik_sayisi` yalnız `resident` rolüne dönüyor ve web yüzeyi
yöneticiye/admin'e/denetçiye açık — orada resident haritası **yok**.
Yani kusur mobil-özel.

### Karar: iki sayı kodda ve arayüzde **adlandırılarak** ayrıldı

Kullanıcının istediği ayrım artık üç yerde yazılı:

| Sayı | Nerede | Penceresi | Sorusu |
|---|---|---|---|
| **(a) görünür şikâyet sayısı** | `/density.acik_sayisi`, `/building-map.complaint_count`, `/building-map.benim_acik_sayisi` | `tenant.sikayet_harita_saat` (24 saat) | "**şu anda** nerede sorun var" |
| **(b) eşik sayacı** | `gurultu_akisi.acik_gurultu_sayisi()` → `esik_kontrol()` | `tenant.gurultu_pencere_gun` (30 gün) | "uyarı gönderilmeli mi" |

(b) istemciye **hiç gelmez** ve (a) değiştiğinde **değişmez**.

Ayrım `unit_complaints.py` modül başlığında ve mobil
`building_map_models.dart` alan yorumlarında yazılı. İki yönde de
kusur üretir:

- **(b)'yi (a)'ya bağlamak** → 24 saat sonra sayaç sıfırlanır, 5 şikâyete
  hiçbir zaman ulaşılamaz, **sesli uyarı hiç gitmez**. Ve uyarı
  gitmemesi sessizdir — aylar sonra fark edilir.
- **(a)'yı (b)'ye bağlamak** → harita 30 gün kırmızı kalır ve "hiç olmuş
  mu" sorusunu yanıtlamaya döner (P219'da düzeltilen kusur).

### Yöneticinin ayarlarına dokunulmadı

`sikayet_harita_saat`, `gurultu_esigi`, `gurultu_pencere_gun`,
`gurultu_susma_gun` — hiçbiri değişmedi. Testler bu değerleri
**okuyor**, sabit varsaymıyor.

### `/mine` bilerek filtrelenmedi

Sakinin kendi açtığı şikâyet, haritadan düştükten sonra da **onun
kaydıdır**. Gizlemek "şikâyetim kayboldu" demek olurdu ve sakin aynı
şikâyeti tekrar açmaya çalışıp spam korumasına takılırdı. P219 notu da
bunu açıkça kapsam dışı bırakmış.

Ana ekrandaki "Gürültü Şikâyeti" sayacı bu uçtan besleniyor ve o **(a)
değil**: "benim açık şikâyetlerim", haritanın "şu anda nerede sorun var"
sorusundan farklı bir soru.

### Ölçtüklerim

1. **Kusur** — 48 saat eskitilmiş şikâyette sakinin işareti düşmüyordu.
2. **Düzeltme** — aynı akış: işaret `true → false`, sayı `1 → 0`.
3. **Eşik sayacı bozulmadı** — harita penceresi 1 saatken, 3 saat eski
   5 şikâyetle **gerçek uçtan** son şikâyet açıldı ve `unit_uyari`
   satırı doğdu. Yani sesli uyarı hâlâ gidiyor.
4. **Veri silinmedi** — pencere dışı şikâyet tabloda ve `/mine`'da
   duruyor.
5. **Pencere `0` = süresiz** — küçük sitelerde iki sayım da eski
   şikâyeti görüyor.

### Kilitleri kırarak doğruladım

- Düzeltmeyi geri aldım → 3 test kırmızı.
- Eşik sayacını harita penceresine bağladım → `test_ESIK_UYARISI_HALA_URETILIYOR`
  kırmızı. (İlk kırma denemem `pencere_gun=0` idi ve **geçti** — çünkü
  0 "sınırsız" demek; yanlış kırmaydı, düzelttim.)

### Yan bulgu: ölçülen bir test flake'i — ve kaynağı

Hedefli koşumlar sırasında `test_SUSMA_SURESINDE_ikinci_uyari_GITMEZ`
**bir kez** düştü. Tek başına, kendi dosyasında, iki dosyalık ve üç
dosyalık kombinasyonlarda **geçti**; dördüncü denemede yakalandı.

Kaynağı buldum: üç test `tenant.gurultu_susma_gun`'ü `0` yapıp **geri
almıyordu** (`test_gurultu_caydirici.py` bir, `test_p212_gurultu_eskalasyon.py`
sekiz yerde). Veritabanı pytest koşumları arasında **kalıcı** olduğu
için, susmayı kapatan bir koşumdan sonraki koşum onu kapalı buluyor ve
susma testi düşüyor.

Belirtisi sinsi: **kod doğru, test doğru, sıra yanlış.**

**Ayarı yok saymak yerine geri almayı seçtim.** Testin meşru işi
özelliği kapatıp ölçmek; kapalı bırakması başka testlerin işi değil.
`susma_ayari_geri_al` fixture'ı değeri anlık görüntüleyip geri yazıyor.

Doğrulama: `caydirici → p212 → caydirici` sırasıyla koştum (daha önce bu
sıra flake üretiyordu) — **56 passed**.

Bu P220'nin kapsamında değildi ama düzeltmemek, kendi değişikliğimin
yeşilliğini ölçemez hâle getirirdi.

### Ölçemediklerim

- **Sesli anonsun cihazda çalması.** Ölçülen şey `unit_uyari` satırının
  doğması ve push sağlayıcısına gitmesi; dev'de `PUSH_PROVIDER=noop`.
- **Mobil ızgaranın cihazdaki görünümü** — emülatör yok. Ölçülen şey
  sunucunun döndürdüğü sayı.


---

## §2 — Mobilde bildirim toplu işlemleri

### Uçlar zaten vardı — eksik olan yüzeydi

`toplu-okundu`, `tumunu-okundu`, `toplu-sil` üçü de backend'de mevcuttu
(P181 Bölüm 6.5'te web için yazılmış). **Yeni uç yazılmadı**; mobil
onları çağırmıyordu.

### Seçim modu: "Seç" düğmesi **ve** uzun basma

Sorulan karar buydu. **İkisi birden** yapıldı ve ikisinin de işi farklı:

**Neden yalnız uzun basma değil:**
- **Keşfedilemez.** Bu uygulamanın kullanıcıları site yöneticileri ve
  güvenlik görevlileri; "uzun bas" hiçbir yerde yazmıyor. Web'de toplu
  işlem şeridi **görünüyor**; mobilde gizli olsaydı özellik ikinci
  yüzeyde fiilen **yok** sayılırdı.
- **Erişilebilirlik.** Uzun basma, motor güçlük yaşayan kullanıcıda ve
  ekran okuyucuda zayıf çalışır. Görünür düğme ikisinde de çalışır.

**Neden uzun basma da var:** Android'in liste çoklu-seçim geleneği ve
bilenler için tek dokunuşluk kısayol. Varsayılan listeyi kirletmiyor.

Seçim modunda başlık `{n} seçili` olur, sol üstte kapatma, sağ üstte
**tümünü seç / seçimi temizle**, altta eylem şeridi.

### Silme: onay **var**, geri alma **yok**

- **Davranış web'le aynı:** sunucuda yumuşak silme (`silindi_at`),
  arayüzden geri alınamaz. Web'de de geri yükleme ucu yok.
- **Affordans farklı:** dokunmatik ekranda yanlışlıkla basma olasılığı
  fareyle tıklamaya göre çok daha yüksek ve seçili satırların hepsi
  ekranda görünmüyor olabilir. Geri alınamaz bir işlemin önündeki tek
  koruma onay penceresi.

Bu bir davranış ayrışması değil, aynı davranışın iki girdi yöntemine
uyarlanması.

### Sonuç **sayısı** gösteriliyor

"İşlem tamam" demek, hiçbir satır etkilenmediğinde de aynı şeyi
söylerdi — P217'de ölçülen "Kaydedildi yazıp sıfır kayıt üretmek"
sınıfı. Yanıt `etkilenen` döndürüyor, arayüz onu gösteriyor.

### Rozet: P190'ın tekrarı önlendi

P190'da web'de ölçülen kusur: toplu okundu deyince liste güncelleniyor
ama **üst bardaki sayı düşmüyordu** — çünkü rozet ayrı bir sorgudan
besleniyor. Mobilde de `unreadNotificationCountProvider` ayrı. Üç
işlemin **hepsinde** tazeleniyor ve üçü de testle kilitli.

### Ölçüm sırasında bulduğum kendi hatam: sahte yeşil test

Rozet kilidini yazdım, geçti. Sonra **kırdım** — tazelemeyi tamamen
kaldırdım — ve test **yine geçti**. Sebep: rozet sağlayıcısı
`autoDispose` ve testte dinleyicisi yoktu; okuma biter bitmez atılıyor,
ikinci okuma zaten yeniden sorguluyordu. Ölçtüğüm şey ürün değil,
`autoDispose`'un kendisiydi.

Düzeltme: teste rozet sağlayıcısı için de bir dinleyici eklendi. Artık
ikinci sorgu **ancak açık bir `invalidate`** ile oluşuyor; kırma denemesi
üç testi birden kırmızı yakıyor.

> Bu, "test yeşil" ile "test ölçüyor" arasındaki farkın somut örneği ve
> kırmadan fark edilemezdi.

### Yan bulgu: dayanıklılık açığı

`ref.invalidate`, sağlayıcı atılmışsa **fırlatıyor**. `notificationsProvider`
`autoDispose`: kullanıcı toplu işlem sırasında (ağ çağrısı sürerken)
ekrandan çıkarsa dinleyici kalmaz, sağlayıcı atılır ve tazeleme
patlardı. Sonucu: sunucuda **başarıyla tamamlanmış** bir işlem arayüzde
"başarısız" görünür, kullanıcı tekrar dener ve ikinci kez siler.

`ref.mounted` kontrolü eklendi. Ekran zaten kapandığı için tazelemeye de
gerek yok: bir sonraki açılışta liste yeniden çekiliyor.

### Yan bulgu 2: erişilebilirlik kilidi beni yakaladı

Uzun basmayı önce sarmalayıcı bir `GestureDetector` ile yazdım. Mobil
takım kırmızı yandı: *"lib/src içinde çıplak `GestureDetector` yok
(klavyeyle ulaşılamaz)"*.

Kilit haklıydı. `GestureDetector` kendi `Focus`unu kurmaz — harici
klavye, anahtar erişimi (switch access) ve masaüstü hedefleri için öğe
**erişilemez** olur. Uzun basmayı `ActivityRow`un zaten var olan
`InkWell`ine taşıdım; `InkWell` odaklanabilir.

Bu, "erişilebilirlik sonra düşünülür" tuzağının tam olarak nasıl
kapatıldığının örneği: kural kaynak taramasıyla zorlanıyor ve yazarken
yakalıyor.

### Ölçemediklerim

- **Cihazda uzun basma ve onay penceresi** — emülatör yok. Ölçülen şey,
  doğru uca doğru gövdeyle gidildiği ve rozetin tazelendiği.
- **Çok sayıda seçimde davranış** — `ids` en çok 500 (sunucu sınırı);
  501 seçimde ne olacağı sürülmedi.


---

## §3 — Okundu / okunmadı sekmeleri + arama

### İki sekme, varsayılan **okunmamış** — "Tümü" kaldırıldı

Web'de üç filtre düğmesi vardı (Tümü / Okunmamış / Okunmuş) ve
varsayılan **Tümü**ydü. Mobilde hiç filtre yoktu.

**"Tümü" neden kaldırıldı:** bildirim listesinin yanıtlaması gereken
soru *"neyi kaçırdım"*. Okunmuşlarla karışık bir liste o soruyu
yanıtlamıyor ve kullanıcıyı her açılışta süzmeye zorluyordu. Arama
geldiği için de gereksiz: bir bildirimi metniyle arıyorsan hangi sekmede
olduğunu bilmen gerekmez — **iki sekmede de arama var**.

Okundu işaretlenen bildirim okunmuş sekmesine geçiyor (liste
tazeleniyor), rozet yalnız okunmamışları sayıyor (zaten öyleydi:
`okundu=false&limit=1`).

### Arama neyi kapsıyor: **başlık + gövde + tip**

Kararın gerekçesi bir **ölçümden** çıktı: bildirim metni **kayıtta
durmuyor**. Satır `mesaj_kimlik` + `mesaj_veri` taşıyor; cümle **okuma
anında, isteğin dilinde** kuruluyor (tur 16 kararı — aynı kayıt her
kullanıcıya kendi dilinde görünsün diye).

Sonucu: `WHERE mesaj ILIKE '%kargo%'` yalnız **tur 16 öncesi** satırları
bulurdu — yani kullanıcının gördüğü metinlerin neredeyse hiçbirini.
`test_KAYITTAKI_MESAJ_BOS_ama_ARAMA_BULUYOR` bu kısıtı kanıtlıyor.

Bu yüzden arama **üretilmiş metin** üzerinde:

| Kapsam | Neden |
|---|---|
| **başlık** (`push_basligi`) | Kullanıcının listede gördüğü etiket |
| **gövde** (`push_govdesi`) | Aradığı cümlenin kendisi |
| **tip** (ham kimlik) | Ekranda görünmüyor ama destek yazışmasında geçiyor; dışarıda bırakmak "tipe göre bulayım" diyen yöneticiyi boş döndürürdü |

### İstemcide filtrelemek neden yanlış olurdu

Yalnız **açık sayfayı** süzer. "kargo" arayan kullanıcı 3. sayfadaki
kaydı bulamaz ve "yok" sanar.
`test_ARAMA_SAYFA_DISINDAKINI_de_BULUR` bunu ölçüyor: aranan kayıt
`limit=1` ile ilk sayfada görünmüyor, arama onu buluyor.

### Tarama tavanı **görünür**

SQL'de arayamadığımız için uç, kapsamdaki en yeni **1000** satırı
üretip filtreliyor. Tavan aşılırsa yanıt bunu söylüyor
(`meta.arama_tavani_asildi`) ve iki yüzey de gösteriyor.

Sessizce eksik sonuç döndürmek, kullanıcıyı *"aradım, bulamadım, demek
ki yok"* sonucuna götürür — oysa kayıt taranmamış olabilir.

**En az 2 karakter:** tek harf, taranan satırların neredeyse tamamıyla
eşleşir ve arama bir işe yaramaz. Kısa sorgu aramasız yola düşüyor
(sayfalama SQL'de kalıyor, büyük listede tek satır bile fazladan
üretilmiyor).

### Arama yetkiyi genişletmiyor

`_kapsam(user)` aynen uygulanıyor: yönetici yalnız `user_id IS NULL`
satırlarını, diğerleri kendi satırlarını arıyor.
`test_ARAMA_KAPSAMI_ASMAZ` başka tesisin kaydının gelmediğini ölçüyor.

### Web'de dört kilit yakaladı

1. **Tasarım tokenı** — `--yz-line` / `--yz-surface` tanımsızdı
   (`--yz-border` / `--yz-surface-1` doğrusu).
2. **Çok satırlı JSX'te Türkçe** ×2 — tarayıcı çok satırlı `{/* */}`
   bloklarını JSX metni sayıyor. Gerekçeler TS yorumlarına taşındı.
3. **`aria-pressed` testi** — "Tümü" düğmesini bekliyordu. Test
   güncellendi ve iki sekmenin birbirini dışladığı da ölçülüyor.

### Ölçemediklerim

- **Gerçek dilde arama.** Testler Türkçe metinlerle koşuyor; Arapça ya
  da Rusça arayüzde üretilen metinde arama sürülmedi. Mekanizma dilden
  bağımsız (`Accept-Language` ile üretiliyor) ama ölçülmedi.
- **1000 satırlık tavanın performansı.** Tavan üstünde bir kapsamla
  koşulmadı; ölçülen şey tavanın **bildirildiği**.
- **Gecikmenin (300 ms) doğru süre olduğu.** İki yüzeyde de aynı ve
  tutarlılık kriterini karşılıyor, ama sürenin kendisi bir tahmin;
  gerçek kullanımda ölçülmedi.


---

## §4 — Blok bazlı sakin düzeni

### Önce ölçtüm: mevcut durum

| Ölçüm | Bulgu |
|---|---|
| `POST /residents` gövdesi | `blok` **zaten vardı** — ama yalnız **yeni açılan** daireye işleniyor |
| Mobil ekleme formu | `telefon` + `unit_no` gönderiyordu, **blok yok** |
| `GET /residents` yanıtı | `ad` + `unit_no` + `is_active` — **blok yok** |
| Web'de sakin listesi | **Yok** — `admin-web` `/users` sayfasını kullanıyor; `GET /residents` mobil-özel |

Yani "sakinler bloklara göre gruplansın" ve "blokta arayabilsin"
istemcide **karşılanamıyordu**: liste blok taşımıyordu.

### Blok, daire numarasından türetilemez

`A-12` numaralı bir daire `B` bloğunda olabilir. Blok `unit.blok`
sütunudur, numaranın bir parçası değil — **P193'te ikisi bilerek
ayrıldı**. Numaradan tahmin etmek yanlış blokta daire açardı ve o sakin
gruplanmış listede **yanlış yerde** görünürdü.

### `q` ve `blok` **ayrı** parametreler

| Parametre | Ne yapar |
|---|---|
| `q` | Ad + daire no + blok üzerinde **metin** araması (en az 2 karakter) |
| `blok` | **Tam eşleşme** daraltması |

Tek parametreye sığdırmak, `A` bloğunu daraltmak isteyen yöneticiye
`A-12` dairesindeki herkesi getirirdi.

Arama üç alanı birden kapsıyor çünkü yöneticinin elinde bunlardan **biri**
olur: adını bilir, dairesini bilir ya da yalnızca hangi blokta oturduğunu
bilir.

### Bloksuz sakin **gizlenmiyor**

Aktif daire bağı olmayan sakin "Blok atanmamış" grubunda, **en sonda**
görünüyor. Gizlemek, siteden ayrılmış ama hesabı duran bir sakini
**bulunamaz** yapardı — ve isteğin gerekçesi tam olarak onu bulup silmek.

### `ExpansionTile` kullanılmadı

Kapalı bir grup, *"sakinim listede yok"* sorusunun ikinci sebebi olurdu.
Gruplar düz listede, başlık + satırlar olarak açık duruyor. Blok
daraltması açıksa **görünür bir çip** olarak duruyor ve tek dokunuşla
kalkıyor — gizli süzgeç aynı sorunun en sık sebebi.

### Ayrılan sakin akışı: uçtan uca sürüldü

İsteğin gerekçe cümlesi üç ölçüme çevrildi ve **gerçek uçlardan**
sürüldü:

1. **Blokta bulunuyor** (`blok=` süzgeci).
2. **Siliniyor** — P189 akıllı silme: geçmişsiz sakin `deleted=true`
   (tamamen), geçmişli `deleted=false` (anonimleştirme).
3. **Daire boşalıyor** — `unit_resident.bitis` doluyor. **Her iki
   modda da**: anonimleştirmede de boşalıyor. İkisini karıştırmak,
   "silinemedi" yanıtını "daire hâlâ dolu" diye okumak olurdu.
4. **Yerine yeni sakin eklenebiliyor** — aynı daireye.

Ters yön de ölçüldü: daire **gerçekten** doluyken ikinci malik 409
alıyor. Bu olmasaydı "daire boşaldı" ölçümü bir şey kanıtlamazdı — her
durumda eklenebiliyor olurdu.

### Ölçüm sırasında öğrendiğim iki şey

**`audit_log` "geçmiş" saymıyor.** Anonimleştirme dalını kurmak için
önce `audit_log` satırı yazdım; sakin **yine tamamen silindi**.
`app_user`'a `ON DELETE RESTRICT` ile bağlı tabloları ölçtüm
(`scan_event`, `task_completion`, `dues_payment`, `complaint`, …) ve
`complaint` kullandım.

Bu, `hesap_silme.py`'nin kendi yaklaşımıyla aynı: o da tahmin etmiyor,
`DELETE`i bir savepoint içinde **deniyor**. Testin de denenen şeyi
gerçekten kurması gerekiyordu.

**Hata kimliği `message`da, `code`da değil.** `/residents` ucu
`APIError(409, "conflict", <kimlik>)` kalıbını kullanıyor ve zarf metni
isteğin dilinde üretiyor. `daire_zaten_dolu` kodunu beklemek, çevirinin
varlığını kusur saymak olurdu.

*(Not: Dukkan tarafında bu kalıp F8'de yola göre değiştirilmişti; burada
Yönetiyor'un kayıtlı `code` değerleri korunuyor.)*

### İki kilit daha yakaladı (mobil)

1. **Yerleşim kilidi** — gruplu görünüm ekranın düzenini değiştiriyor.
   Değişiklik bilinçli olduğu için kilit yenilendi. Ayrıca test
   fixture'ına **blok verildi**: bloksuz bırakılsaydı kilit yalnız
   "Blok atanmamış" dalını kaydeder, asıl davranışı (blok başlığı +
   sayaç + daraltma düğmesi) hiç görmezdi.
2. **Dokunma hedefi** — blok daraltma düğmesine
   `visualDensity: compact` vermiştim; hedef 40×40'a düşüyordu ve
   erişilebilirlik kilidi *"Tappable objects should be at least
   48×48"* diye yakaladı. Sıkışık görünüm uğruna dokunma hedefini
   küçültmek, motor güçlük yaşayan kullanıcıda düğmeyi isabet
   ettirilemez yapar.

### Kendi hatam: bozuk imajla koşan suite

Kırma denemesinden sonra host dosyasını geri aldım ama **api imajını
yeniden kurmadım**. `backend/` imaja gömülü olduğu için konteyner bozuk
kodla koştu ve tam suite tam olarak o iki testte kırmızı yandı.

Bu turda **ikinci kez** aynı sınıf hata: daha önce koşan bir suite'in
altından konteyneri yeniden kurup suite'i öldürmüştüm (`EXIT=137`).
Kural tek cümle: **`backend/` imaja gömülü — host dosyasını değiştirmek
konteyneri değiştirmez, ve koşan bir suite'in altından konteyneri
değiştirmek suite'i öldürür.**

### Ölçemediklerim

- **Cihazda gruplu görünüm ve blok çipi** — emülatör yok.
- **Çok bloklu büyük sitede performans.** Liste sayfalanmıyor (site
  sakini sayısı binlerce değil varsayımı); 500+ sakinli bir sitede
  gruplama maliyeti ölçülmedi.
- **Web'de blok gruplaması** — `admin-web`'de ayrı bir sakin listesi
  sayfası yok; `/users` sayfası farklı bir uçtan besleniyor. Bu turda
  dokunulmadı.


---

## §5 — Bina düzenlemede sakin bilgisi

### Backend'in çoğu zaten vardı — biri hariç

| İhtiyaç | Durum |
|---|---|
| Dairede kim oturuyor (ad + rol) | `GET /units/{id}/residents` **vardı** (`user_ad` dâhil) |
| Sakin ekle | `POST /units/{id}/residents` **vardı** |
| Sakin çıkar | `DELETE /units/{id}/residents/{user}` **vardı** |
| **Rol değiştir** | **Yoktu** — aşağıda |

### Yeni uç: `PATCH /units/{id}/residents/{user_id}`

Rol değiştirmek için elimizde yalnız `PATCH /residents/{user_id}` vardı
ve o uç kullanıcının **aktif tüm bağlarına** uyguluyor (kendi
dokümanında yazılı).

Somut sonucu: iki dairesi olan bir sakinde — birinde **malik**, ötekinde
**kiracı** — daire penceresinden yapılan bir rol değişikliği **iki
daireyi de** değiştirirdi. Daire penceresi **tek bir daire** hakkında
konuşuyor.

Bu farkı testle **kanıtladım**: `test_ESKI_UC_TUM_BAGLARA_UYGULUYOR` eski
ucun iki bağı birden değiştirdiğini,
`test_ROL_DEGISIMI_DIGER_DAIREYI_ETKILEMEZ` yeni ucun yalnız hedefe
dokunduğunu ölçüyor. İkincisi tek başına yeterli olmazdı — farkın
gerçekten var olduğunu göstermek gerekiyordu.

### Kendi satırı çatışma sayılmıyor

Rol değişiminde "bu dairede aynı rolden başkası var mı" kontrolü,
**güncellenecek bağın kendisini hariç tutuyor**. Tutmasaydı "malik →
malik" bile 409 verirdi ve `oturuyor` alanını değiştirmek **imkânsız**
olurdu.

### Rol değişince `oturuyor` yeniden çözülüyor

Kiracı tanımı gereği oturur (P218). İstemci açıkça `oturuyor`
gönderirse o kazanıyor. Bu, "malik-oturan"ın **üçüncü bir rol
olmadığı** — malikin oturuyor olması — ayrımını koruyor; ikisini tek
etikete sıkıştırmak aidat hedeflemesindeki ayrımı gizlerdi.

### Boş gövde 422

"Hiçbir şey değişmedi" ile "istemci hata yaptı" aynı yanıt olsaydı,
istemci hatasını kimse görmezdi.

### Mobil pencere

`bina_duzenleme_screen.dart`'ın daire formuna sakin bölümü eklendi:
ad + rol + oturma durumu, birden çok sakin, **boş daire** durumu ve
ekleme yolu, rol değiştir / oturma durumu değiştir / çıkar.

**Yalnız mevcut dairede gösteriliyor.** Yeni daire formunda daire henüz
**yok**; boş bir bölüm göstermek kullanıcıyı çalışmayan bir düğmeye
tıklatırdı.

**Çıkarma onayı ne olmadığını da söylüyor:** "yalnızca bu daireyle bağı
kapanır; hesabı silinmez". Kişi siteden ayrılmadıysa başka bir daireye
taşınmış olabilir.

**Ad yoksa UUID gösterilmiyor** — kullanıcı silinmiş olabilir ve bir
kimlik dizisi hiçbir şey anlatmaz.

**Sakin ekleme yeni hesap açmıyor**, site sakinleri arasından seçtiriyor.
Hesap açma "Sakinler" ekranının işi; burada tekrarlamak aynı akışı iki
yerde bakım gerektirir hâle getirirdi. Buradaki iş **bağ kurmak**.

**Site geneli liste de tazeleniyor:** aynı gerçek iki ekranda
gösteriliyor; birinde değişip ötekinde eski kalması, yöneticinin
hangisine inanacağını bilememesi olurdu.

### Yetki sunucuda

`admin` + `yonetici`. Sakin ve güvenlik için **403** ölçüldü. Arayüzde
gizlemek yetmez: ikinci istemci o gizlemeyi taşımayabilir. Rol matrisi
yenilendi (`IZIN IZIN RED RED RED RED RED`).

### Ölçüm sırasında öğrendiğim

`POST /units` **blok zorunlu** istiyor (P193: blok ve daire ayrıldı).
`blok` vermeyince 422 "Field required", `null` verince 422 "should be a
valid string". Testlerin bunu varsayması gerekti.

### Ölçemediklerim

- **Cihazda daire penceresi** — emülatör yok. Ölçülen şey, doğru uca
  doğru gövdeyle gidildiği ve sunucunun doğru davrandığı.
- **Web'de daire penceresinde sakin bilgisi.** `admin-web`'in bina
  düzenleme yüzeyi bu turda **yapılmadı**; §5 mobilde tam, web'de
  **eksik**. Kabul kriteri 9'un yarısı karşılanmadı ve bunu açıkça
  söylüyorum.
- **Aynı anda iki yöneticinin aynı daireyi düzenlemesi** — yarış koşulu
  üretilmedi; sunucu tarafında `daire_zaten_dolu` kontrolü var ama
  eşzamanlı iki `PATCH` sürülmedi.
