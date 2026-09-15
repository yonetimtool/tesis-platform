# P237 — kararlar

Tur üç bölümden oluşuyor: simge netliği (§1), görev süreç takibi (§2),
anket sistemi (§3). Her bölüm ayrı commit.

---

## §1 — Simge tekrarları ve netlik

### §1.0 ÖNCE ÖLÇÜM

Ölçüm aracı: kaynak taraması (`actions: [...]` blokları, `<button>` /
`<Link>` gövdeleri) + ekran testleri.

**Mobil (`mobile/lib`, 79 ekran):**

| Ölçüm | Sonuç |
|---|---|
| App bar eylem widget'ı | 29 |
| Tooltip'i olmayan | **0** |
| BAŞKA EKRANA götüren | 6 |
| Bunlardan görünür etiketi olmayan | **4** |

Yani sorun "tooltip yok" değil. Sorun şu: tooltip mobilde **uzun basmayı**
gerektirir; kullanıcı simgenin varlığını öğrenmeden önce ne işe yaradığını
merak etmek zorunda. P154'te bu tam olarak ölçülmüş ve çözüm olarak
ekranlar menüye eklenmişti — yani simge açıklanmadı, **ikinci bir kopya**
üretildi. Kullanıcının bu turdaki üç şikâyeti de o kopyalardan doğuyor.

**Web (`admin-web`, 86 sayfa):**

| Ölçüm | Sonuç |
|---|---|
| İkonlu `<button>` | 5 |
| Bunlardan etiketsiz (metin/`aria-label`/`title` yok) | **0** |
| İkonlu `<Link>` | 0 |

**Web'de düzeltilecek bir şey çıkmadı** — web başlıkları ikon değil
etiketli düğme kullanıyor (`Dugme boy="kucuk"`). Bu bir atlama değil,
ölçüm sonucu; ayrıntı aşağıda madde madde.

### §1 GENEL KURAL (koda ve kilide bağlandı)

> App bar'daki bir eylem **başka bir ekrana** götürüyorsa adını **görünür**
> taşır. Yerinde iş yapan eylem (yenile, ekle) tooltip'le yetinir.

Gerekçe: yerinde iş yapan simgenin sonucu **anında görünür** — yanlış
basan kullanıcı ne olduğunu hemen anlar ve geri alabilir. Gezinme
simgesinde ise yanlış basmanın bedeli bir ekran değişimi, doğru basmanın
ön koşulu ise simgeyi önceden tanımak.

Kilit: `mobile/test/p237_baslik_ikonlari_test.dart` — kaynak tarar.
Davranış testi bu kuralı yakalayamaz: etiketsiz bir ikon da kusursuz
çalışır, kusur **anlaşılırlıkta**. Kilit dört dedektör vakasıyla ve
gerçek bir kırma denemesiyle doğrulandı (aşağıda).

Yer darlığında sıra:
1. Tek gezinme eylemi varsa → app bar'da `TextButton.icon` (ikon + metin).
2. Birden çok eylem varsa ve gövdenin üstü boşsa → **gövde şeridi**
   (bina düzenlemede çalıştığı kanıtlanan desen).
3. Gövdenin üstü de doluysa → **etiketli maddeleri olan taşma menüsü**
   (`more_vert`); giriş simgesi evrensel, hedefler açıldığında adıyla
   görünür.

### §1a Bina düzenleme — tekrar eden simge kaldırıldı

`mobile/.../bina_duzenleme_screen.dart`: app bar'daki
`PopupMenuButton(construction_outlined)` **kaldırıldı**. Gövdedeki
etiketli `TextButton.icon` ("Yapısal araçlar") kaldı; artık
`Key('yapisal-araclar')` taşıyor.

Ölçüm: iki kontrol de `_yapisalArac`a gidiyordu — hiçbir fark yok.
P166 §10'da ikon app bar'da bırakılmış, etiketli giriş gövdeye
**eklenmişti**; yani tekrar o turda üretildi.

App bar'a metin konamadığı P166 §10'da ölçülmüştü (320dp'de 43 piksel
taşma). Bu yüzden çözüm "app bar'a etiket koymak" değil, "app bar'daki
etiketsiz kopyayı kaldırmak" oldu.

**Web'de bu tekrar YOK:** `building-editor` başlığında üç **etiketli**
düğme var (`Toplu daire oluştur`, `Katı sil`, `Toplu tip`) ve hiç ikon
kısayolu yok. Parite kuralı gereği baktım, düzeltilecek bir şey çıkmadı.

### §1b Devriye takibi — menü sadeleşti, simgeler etiketlendi

- `HomeMenuEntry.patrolPlans` ve `.checkpoints` **enum'dan tamamen
  silindi** (liste, etiket switch'i, grup switch'i, `module_card_spec`).
  Ölü kod bırakılmadı.
- App bar'daki iki etiketsiz ikon **gövdenin üstüne** taşındı ve
  etiketlendi: `devriye-planlari-giris`, `kontrol-noktalari-giris`.
- Şerit **yatay kaydırılabilir**: 320dp'de iki etiket yan yana sığmayabilir;
  taşma yerine kaydırma.

Kullanıcı "üstteki simgeler kalsın" dedi; simgeler bu ekranda kaldı ama
**app bar'dan gövdenin en üstüne** indi — tek değişiklik bu, çünkü app
bar'da başlık + yenile + üç sekmeli `TabBar` zaten dar ve etiket sığmıyor.
Erişim menüye geri konmadı; ekranlar silinmedi.

**Web'de bu ekran YOK.** Ölçüm: `admin-web`'de devriye takibi ayrı sayfa
değil — `dashboard`'daki `DevriyeGorunumu` bileşeni + `/reports/patrols`.
`/checkpoints` ve `/patrol-plans` ise **sol menüde metin girişleri**
olarak duruyor: ne ikon belirsizliği ne de kopya var, ve onları menüden
kaldırmak web'de erişimi tamamen koparırdı (barındıracak bir üst çubuk
yok). Bu yüzden **web menüsü değiştirilmedi** — parite kuralına göre
gerekçelendirilmiş istisna, atlama değil.

### §1c Görev yönetimi — kategori girişi etiketlendi

`tasks_screen.dart`: `IconButton(label_outline)` →
`TextButton.icon` + `Key('gorev-kategorileri-giris')`, etiket
`gorevKategorilerTooltip` ("Kategoriler"). App bar'da başka eylem yok,
etiket sığdı.

Yeni l10n anahtarı **açılmadı**: mevcut anahtarın değeri zaten kısa bir
etiket; yedi dilde ikinci bir anahtar açmak aynı metni tekrar çevirtmek
olurdu. (Anahtar adında `Tooltip` kalması bilinçli — yedi arb dosyasında
yeniden adlandırma, hiçbir davranış değiştirmeden çeviri dosyalarını
kirletirdi.)

**Web'de zaten etiketli:** `/tasks` sayfasında `gorevKategoriYonet`
düğmesi metin taşıyor. Değişiklik gerekmedi.

### §1d Taramanın bulduğu DİĞER iki yer (brief'te yoktu)

| Ekran | Önce | Sonra | Neden bu çözüm |
|---|---|---|---|
| `vehicle_pass_screen` | `IconButton(document_scanner)` → Plaka okumaları | gövde şeridinde etiketli giriş | App bar'da etiketli denendi, **320dp'de Rusça 36 piksel taştı** (beş eksen sürüşü ölçtü) → kuralın 2. basamağı |
| `dukkan_arama_screen` | üç etiketsiz `IconButton` | tek `PopupMenuButton(more_vert)`, üç madde **adıyla** | Üç etiket 320dp'ye sığmaz; gövdenin üstü **arama alanı** (pazar yerinin asıl işi), şerit oraya konamaz |

### §1 DOĞRULAMA — ne ölçtüm

| Ölçüm | Sonuç |
|---|---|
| Kaynak kilidi tüm `lib`i tarıyor | 300+ dosya, ihlal **0** |
| Kilit dedektörü: etiketsiz `IconButton` + `context.push` | yakalıyor ✔ |
| Kilit dedektörü: `TextButton.icon` (label) | temiz ✔ |
| Kilit dedektörü: yerinde `refresh` ikonu | temiz ✔ |
| Kilit dedektörü: etiketli taşma menüsü | temiz ✔ |
| **GERÇEK KIRMA**: `vehicle_pass` etiketi geri alındı | kilit kırmızı: `...vehicle_pass_screen.dart:44 IconButton` ✔ sonra geri kondu |
| Devriye takibi 430dp: iki etiket adıyla çiziliyor | ✔ |
| Devriye takibi **320dp**: taşma yok, etiket erişilebilir | ✔ |
| Web ikon taraması | etiketsiz **0** (düzeltilecek yok) |

**İKİNCİ ÖLÇÜM (ilk denemeyi çürüttü):** `vehicle_pass` etiketini app
bar'a koymak 320dp'de Rusça'da **36 piksel taşma** üretti ve mevcut beş
eksen sürüşü (`arac_ihlal_otopark_test.dart`) bunu yakaladı. Yani "tek
gezinme eylemi varsa app bar'a etiket sığar" varsayımım yanlıştı; etiket
uzunluğu dile göre değişiyor. Giriş gövde şeridine indirildi. Aynı test
şimdi yeşil. (`tasks_screen`'de "Kategoriler" kısa olduğu için sığdı —
o da tam takımda beş eksende sürülüyor.)

**Beklenmedik bulgu:** etiketli şeridi eklemek
`devriye_takibi_sekmeler_test.dart`'ın "SEKME 3: HATA hali" testini
kırdı — test `find.byType(TextButton).first`'ü kullanıyordu ve yeni
etiketli girişler ağaçta **önce** geliyor; tıklama "tekrar dene" yerine
Devriye Planları ekranını açıyordu. Test `TabBarView` içine kapsandı.
Bu, kapsamsız `.first` bulucularının kırılganlığının somut kanıtı.

**ERİŞİLEBİLİRLİK:** `TextButton.icon`'un metni Flutter'da doğrudan
semantik etikettir — ekran okuyucu "düğme" değil "Devriye Planları,
düğme" der. Kalan ikonlu eylemlerde (`refresh` vb.) `tooltip`, Flutter'da
`Tooltip` widget'ı üzerinden `Semantics(label:)` kurar. **Ölçemediğim:**
gerçek bir ekran okuyucuyla (TalkBack/VoiceOver) cihazda dinlemedim —
bu makinede emülatör yok.
