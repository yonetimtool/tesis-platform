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
