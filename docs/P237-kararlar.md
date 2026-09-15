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

---

## §2 — Görev süreç takibi (alt adımlar)

### §2.0 ÖNCE ÖLÇÜM — alt adım kavramı var mıydı?

**YOKTU.** Ölçülen:

| Yapı | Durum |
|---|---|
| `task` tablosu | işi TEK PARÇA taşıyor: ad, açıklama, atanan, foto_zorunlu, son_tarih, başlama |
| `task_completion` | görev başına TEK kapanış kaydı (foto + not + NFC + GPS) |
| Alt adım tablosu / kolonu | **hiç yok** |
| İlerleme göstergesi | yok — yalnızca "tamamlandı / tamamlanmadı" |

Yani "A bitti, B'ye geçildi" bilgisi hiçbir yerde tutulamıyordu. Göç
**0136** bunu açıyor.

### §2 TASARIM KARARLARI

| Soru | Karar | Gerekçe |
|---|---|---|
| Adımlar ne zaman tanımlanır? | **İkisi de**: görev oluştururken (`TaskCreate.adimlar`) VE sonradan (`POST /tasks/{id}/adimlar`) | Sahada iş verilirken bloklar bellidir, ama "D bloğu da yapıver" sonradan çıkar. Yalnız oluşturma anında izin vermek, o isteği **yeni bir görev açmaya** zorlardı ve ilerleme iki yere bölünürdü |
| Personel kendi adımını ekleyebilir mi? | **HAYIR** | Adım, işin TANIMIDIR. Personel adım ekleyebilseydi "3/3 tamamlandı" ifadesi anlamını yitirirdi: **paydayı da işi yapan belirlerdi** ve yönetici ekranındaki ilerleme ölçüsü denetlenemez olurdu. Personelin söyleyeceği şey **not** alanına yazılır — bilgi kaybolmaz, ölçü bozulmaz |
| Fotoğraf zorunlu mu? Türe göre değişir mi? | Görevden **MİRAS**; adım **sıkılaştırabilir, gevşetemez**. Türe göre otomatik kural **KONMADI** | Görev "fotoğrafsız kapanmasın" diyorsa bir adımın muaf olması kuralı delerdi (422 `gorev_adim_foto_gevsetilemez`). Tür bazında kural konmadı çünkü kategoriler **yönetici-tanımlı** (sabit tür enum'u P?/A6'da kaldırılmıştı); "temizlikte foto zorunlu" gibi bir eşleme uydurma olurdu |
| Adımlar sıralı mı? | Varsayılan **SERBEST**, görev düzeyinde `adim_sirali` bayrağı | Sahada sıra çoğu zaman sabit değildir: B bloğunun kapısı kilitliyse sırayı zorlamak işi **tamamen durdururdu**. Gerçekten sıralı işler de var ("önce boşalt, sonra yıka") |
| Her adımda bildirim yorgunluk yaratır mı? | **EVET** — eşik + toplama uygulandı | Yirmi adımlık görevde yirmi bildirim, kullanıcının bildirimleri okumayı bırakması demektir; özellik kendi kendini bozar |

### §2 BİLDİRİM YORGUNLUĞU ÇÖZÜMÜ

Kural (`ADIM_BILDIRIM_ARALIK_DK = 30`):

- **İlk** tamamlanan adım → bildirim (iş başladı, haber değeri yüksek)
- **Son** adım → görev zaten tamamlanır, mevcut `gorev_tamamlandi` gider
- **Aradakiler** → yalnızca son adım bildiriminden 30 dk geçtiyse; ve o
  bildirim arada biriken ilerlemeyi **toplu** taşır:
  `"Temizlik: 3/5 adım tamamlandı — son: B blok (Ali)"`

Yani **bildirim sayısı adım sayısıyla değil, geçen zamanla artar.**

Yeni bildirim tipi `gorev_adim_ilerleme` açıldı; `gorev_tamamlandi`ya
bindirilmedi çünkü biri işin SONUNU, öteki ORTASINI bildirir — tek tipe
indirmek, bildirim tercihinde "ilerlemeyi kapat, bitişi al" demeyi
imkânsız kılardı (0131'in aynı gerekçesi).

### §2 VERİ MODELİ (göç 0136)

`task_step`: `task_id`, `sira`, `ad`, `foto_zorunlu`, `tamamlayan_user_id`,
`tamamlanma_zamani`, `foto_key`, `foto_url`, `notlar`. RLS ENABLE+FORCE +
tenant politikası (platform tablosu DEĞİL). `task`'a iki kolon:
`adim_sirali`, `son_adim_bildirim_at`.

**JSON değil ayrı tablo:** her adım kendi tamamlayanını, zamanını ve
fotoğrafını taşıyor; bunlar sorgulanacak, yetkilendirilecek (RLS) ve
raporlanacak alanlar. JSON'da "kim bitirdi" bir FK ile değil bir metinle
yanıtlanırdı.

**Bedeli açıkça:** periyodik görevde periyot ilerleyince adım-düzeyi iz
tabloda kalmaz; kalıcı iz `audit_log`'da (foto anahtarı dahil) ve
görev-düzeyi `task_completion` kaydında. Periyodik görev + adım
birlikteliği nadir; bu bedel bilinçli.

### §2 UÇLAR

`GET|POST /tasks/{id}/adimlar`, `PATCH|DELETE /tasks/{id}/adimlar/{step_id}`,
`POST .../tamamla`, `POST .../geri-al`. Tamamlama `_COMPLETER`
(admin+yönetici+saha), tanımlama `_WRITER` (admin+yönetici+güvenlik amiri).

İkinci tamamlama **409, idempotent değil**: ikinci çağrı farklı bir
fotoğraf taşıyor olabilir ve sessizce yutmak yüklenen kanıtı kaybetmek
olurdu. Geri alma **yalnız yönetim**: işi yapanın kendi izini
temizleyebilmesi denetimi boşa çıkarırdı.

### §2 İKİ YÜZEY (parite)

| | Web | Mobil |
|---|---|---|
| Görev oluştururken adım tanımı | `CokSatir`, satır başına bir adım | `TextFormField`, satır başına bir adım |
| `adim_sirali` seçimi | onay kutusu | `SwitchListTile` |
| Listede ilerleme | yeni "Alt adımlar" sütunu (`2/3`) | görev kartında satır (`2/3`) |
| Ayrıntıda adım listesi | `GorevAdimlari` kartı | `_AdimlarKarti` |
| Adım ekleme/silme | ✔ (yönetim) | ✔ (yönetim) |
| Fotoğrafla tamamlama | presign → PUT → `foto_key` | kamera → presign → PUT → `foto_key` |
| Geri alma | ✔ (yönetim) | ✔ (yönetim) |
| Fotoğrafı büyütüp görme | yeni sekmede | `InteractiveViewer` + `sinirliGorsel` |

**Düzenlemede adımlar GÖNDERİLMEZ** (iki yüzeyde de): gönderilseydi
mevcut adımlar — tamamlanmışlar dahil — ezilirdi. Düzenleme, ayrıntı
ekranındaki tek tek ekleme/silme akışından geçer ve orada her işlem
denetim kaydına yazılır.

**Adımı olmayan görevde "0/0" yazılmaz**, tire/hiç çizilmez: bölünmemiş
bir işi hiç ilerlememiş gibi göstermek yanlış olurdu.

### §2 DOĞRULAMA — brief'in istediği akış BİREBİR sürüldü

`backend/tests/test_p237_gorev_adimlari.py` — **9 test, hepsi yeşil**,
gerçek API konteynerine karşı (bu depoda testler canlı sunucuya gider).

| Ölçüm | Sonuç |
|---|---|
| Görevi ÜÇ adıma böl | `adim_toplam=3, adim_tamam=0` ✔ |
| İKİSİNİ fotoğrafla tamamla | iki `tamamla` çağrısı 200 ✔ |
| Yöneticide ilerlemeyi gör | `2/3`; A ve B tamam, C değil ✔ |
| Kim bitirdi | `tamamlayan_user_id` = guard, `tamamlayan_ad` dolu ✔ |
| Ne zaman | `tamamlanma_zamani` dolu ✔ |
| Fotoğrafıyla | `foto_url` (presigned) dolu ✔ |
| Listede de görünür | liste satırında `2/3`, `adimlar` null ✔ |
| Sonradan adım ekleme | 201 ✔ |
| Personel adım ekleyemez | **403** ✔ |
| Foto mirası | adım `foto_zorunlu=true` devraldı ✔ |
| Fotosuz tamamlama | **422** ✔ |
| Foto gevşetme | **422** ✔ |
| Serbest sırada atlama | 200 ✔ |
| Sıralı görevde atlama | **409**, sırayla 200+200 ✔ |
| İkinci tamamlama | **409** ✔ |
| Personel geri alamaz | **403** ✔, yönetim 200 ✔ |
| Kendine atanmayan görev | **404** ✔ |
| **Bildirim eşiği**: 5 adım peş peşe | bildirim defterinde artış **≤ 1** ✔ |

Mobil: `test/p237_gorev_adimlari_test.dart` — 10 test. Dikiş yeri **taklit
HTTP adapter'ında** (P198/P200/P229 dersi): `TaskApi`yi taklit etmek
gövdeyi kuran/çözen katmanı ölçmezdi. Yol, metot ve gövde gerçekten
üretiliyor ve doğrulanıyor.

Web: `tests/p237-gorev-adimlari.dom.test.ts` — 5 test; ilerleme metni,
fotoğraf zorunlu adımda **dosya seçici** (düz "Tamamla" düğmesi değil —
o 422 üretirdi), doğru URL'e POST, boş adda istek atılmaması, adımsız
görevde açıklama.

**ÖLÇEMEDİĞİM:** gerçek bir cihazdan kamera ile fotoğraf çekip adım
kapatma akışını süremedim (emülatör yok); fotoğraf yükleme zinciri
presign→PUT olarak birim düzeyinde ölçüldü, cihazda değil.

### §2 MEVCUT KİLİTLERİN YAKALADIĞI BEŞ GERÇEK KUSUR

Hiçbiri tahminle bulunmadı; hepsini var olan kilitler ölçtü:

1. **`enum-bag`** — `gorev_adim_ilerleme` / `anket_acildi` web enum
   aynasına yazılmamıştı (P212'de birebir aynı sınıf yaşanmıştı).
2. **`modal-tasima`** — `GorevAdimlari`'nda `window.confirm` kullanmıştım;
   P161 kuralı yıkıcı onayı tarayıcı diyaloğuyla sormayı yasaklıyor
   (tema ve dil tanımıyor). `useOnay`a çevrildi.
3. **`yz-tasima-gorevler.dom`** — forma "Alt adımlar" alanı eklenince
   testin gevşek `getByLabelText(/Başlık|Ad/)` bulucusu iki alan birden
   buldu. Bulucu daraltıldı (testin ölçtüğü şey değişmedi).
4. **`gorsel_cozme_denetimi`** — fotoğraf büyütme diyaloğundaki
   `sinirliGorsel(...)` sarmalayıcısını çok satıra yaydığım için kilidin
   60 karakterlik penceresine girmedi ve "sarılmamış" raporladı. Tek
   satıra alındı (kilidin bilinen bir biçim kısıtı; yorumda yazılı).
5. **`saha_akisi_surus` yerleşim kilidi** — iki ayrı gerçek kusur:
   - Adım sağlayıcısına taklit konmamıştı, bölüm **"Adımlar yüklenemedi"**
     hata halini çiziyordu ve altın görüntü o hatayı kilitleyecekti.
     P229 §3'te birebir aynı şey yaşanmış ve o turda yorumla not
     edilmişti; bu turda tekrarı önlendi.
   - Başlık + ilerleme **yan yana** (`Row`) konunca uzun çevirilerde
     başlık **47 piksele sıkışıp dört satıra** kırılıyordu (ölçüm:
     `gorev_detay.txt` "47x80"). Alt alta alındı.
   - Adım ekleme satırı 320dp'de **Almanca'da 68 piksel taştı**; alan ve
     düğme alt alta alındı. Etiketi kısaltmak yerine yerleşimi
     değiştirmek, uzun çeviri gelen her dilde çalışır.

---

## §3 — Anket sistemi

### §3.0 ÖNCE ÖLÇÜM — web'de anket ne yapabiliyordu?

Kullanıcı "mobilde hiç yok, web'de var ama işlevsel değil" dedi.
**Mobilde vardı** (`features/anket/` — görüntüleme + oy verme, P38'de
bilinçli olarak salt-okuma). Web'de ise arka ucun taşıdığı alanların bir
kısmı formda bile yoktu.

| İstenen | Arka uç | Web formu | Mobil |
|---|---|---|---|
| Başlık | ✔ | ✔ | okur |
| Açıklama | ✔ | **YOK** | okur |
| Görsel | **YOK** | YOK | YOK |
| Başlangıç tarihi | **YOK** | YOK | YOK |
| Bitiş tarihi | ✔ (`kapanis_at`) | **YOK** | okur |
| Maddeler, en az 2 | ✔ | ✔ | okur |
| Hedef kitle | **YOK** | YOK | YOK |
| Bir kişi bir oy | ✔ | — | ✔ |
| Bitişte kapanma | ✔ | — | ✔ |
| Anlık sonuç (yönetim) | ✔ | ✔ (düz liste) | — |
| Kim neye oy verdi | **YOK** | YOK | YOK |
| Grafik | **YOK** | YOK | YOK |
| Katılım oranı | **YOK** (payda yok) | YOK | YOK |
| Anonim anket | **YOK** | YOK | YOK |
| Bildirim | **YOK** | — | — |

Yani eksiklerin çoğu arka uçtaydı; göç **0137** onları açıyor.

### §3 KARARLAR

| Soru | Karar | Gerekçe |
|---|---|---|
| Malik/kiracı ayrımı seçilebilmeli mi? | **EVET** — `hedef_sakin_tipi` | `unit_resident.rol_tipi` bu ayrımı zaten taşıyor (P218: `oturuyor` mülkiyetten ayrı). KMK'da malik ve kullanan farklı şeylerden sorumlu; "çatı yenilensin mi" anketi maliklere, "spor salonu saatleri" oturanlara gider. Yalnız `resident` hedeflendiğinde anlamlı; personel `rol_tipi` taşımadığı için filtreden **elenmez** |
| Oy değiştirilebilir mi? | **HAYIR** (mevcut karar korundu) | P38 gerekçesi geçerli: değiştirilebilir oy, kapanışa kadar sonucun anlamsız olması demek. **İkinci gerekçe P237'de eklendi:** anonim ankette oy satırında kimlik yok — "benim oyumu bul ve değiştir" fiziksel olarak yapılamaz. Bir tür için açıp öteki için kapatmak, aynı düğmenin iki ankette farklı davranması olurdu |
| Hedef dışındaki kişi ne görür? | Anketi **görür**, oy **veremez** (403) | Görünürlük kapısı değil OY kapısı. Site genelinde ne konuşulduğu bilgi değeridir; ama oyu sayılmaz |
| "Herkes" ayrı bir kutu mu? | **HAYIR** — boş bırakmak "herkes" demek | İşaretlenince diğerleriyle çelişen bir kutu olurdu ("Herkes + yalnız güvenlik" ne demek?) |
| Sonuç ne zaman görünür? | Değişmedi: kapanana kadar **yönetime**, kapanınca herkese | P38'in sürüsel etki gerekçesi |

### §3 ANONİMLİK — VERİTABANI DÜZEYİNDE GARANTİ

Brief: "yönetici veya platform admini bile göremesin", "sonradan
değiştirilemesin, kilitle".

Uygulama katmanında "bu uçta `user_id` döndürme" demek **yetmez**: veri
orada durduğu sürece bir sonraki sorgu, rapor veya yedek onu açar. Bu
yüzden:

```
anket_oy.anonim  (anket.anonim'in denormalize kopyası)
FK  anket_oy (anket_id, anonim) -> anket (id, anonim)
CHECK (NOT anonim OR user_id IS NULL)
```

Bu iki satır birlikte şunu garanti eder: **anonim bir ankette kimlik
taşıyan bir oy satırı yazılamaz.** Uygulama hatası, elle SQL, bakım
betiği — hiçbiri geçemez.

**Tek oy kuralı anonimde nasıl korunuyor?** Ayrı defter:
`anket_katilim` yalnızca **kimin** oy verdiğini tutar, **neye** oy
verdiğini tutmaz. İki tablo arasında bağlantı yok; zaman damgası **güne
yuvarlanır** ki sıralama üzerinden eşleştirme yapılamasın.

**Değiştirilemezlik — iki katman:**
1. Bileşik FK: ankette oy varken `anonim` değiştirilmek istenirse
   referans veren satırlar yüzünden PostgreSQL reddeder.
2. Tetikleyici `trg_anket_anonim_kilit`: henüz oy yokken bile reddeder.
   Çünkü 1. katman yalnız oy varsa korur; anket açıldıktan sonra ilk oy
   gelmeden yapılan bir değişiklik de listede "anonim" yazısını görmüş
   kullanıcıya verilen vaadi bozardı.

Uç katmanında ayrıca `AnketUpdate` bu alanı **taşımıyor**
(`extra="forbid"` → 422). İki katman: biri **anlaşılır hata**, öteki
**mutlak garanti**.

### §3 KATILIM ORANI

Payda = hedef kitledeki **aktif** kişi sayısı (`hedef_kisi`), SQL'de
hesaplanır. Yalnız yönetime döner: "kaç kişiye gitti" bilgisi oy verenin
kararı için bir girdi değil. **Payda yoksa oran hiç çizilmez** — uydurma
bir yüzde katılımı olduğundan iyi ya da kötü gösterirdi. Kapatılmış
hesaplar paydaya girmez; girseydi oran kalıcı olarak düşük görünürdü.

### §3 BİLDİRİM

Anket açılınca hedef kitleye `anket_acildi` push + kalıcı in-app satır.
`duyuru` tipine bindirilmedi: bildirim tercihinde "duyuruları al, anket
bildirimini alma" demek mümkün kalmalı (0131/0136 ile aynı gerekçe).
İleri tarihli başlangıçta da **şimdi** gider — "12 Ekim'de oylama var"
haberinin değeri o tarihte değil, öncesinde.

### §3 KVKK

Oy verme davranışı kişisel veri. Anonim **olmayan** ankette kullanıcı,
kimliğinin yönetime görüneceğini **oy vermeden önce** görür
(`anket-kvkk`, iki yüzeyde de). Anonim ankette de karşılığı gösterilir
("kimin ne oy verdiği kaydedilmez"). Sonradan söylemek bilgilendirme
sayılmaz.

### §3 İKİ YÜZEY (parite)

| | Web | Mobil |
|---|---|---|
| Anket oluşturma | ✔ modal | ✔ `merkezSayfaAc` formu (**P38'de yoktu**) |
| Başlık / açıklama / görsel | ✔ | ✔ |
| Başlangıç / bitiş | ✔ `datetime-local` | ⚠ **YAPILMADI** — aşağıda |
| Maddeler (satır başına) | ✔ | ✔ |
| Hedef kitle çoklu | ✔ onay kutuları | ✔ `FilterChip` |
| Malik/kiracı ayrımı | ✔ | ⚠ **YAPILMADI** — aşağıda |
| Anonim + uyarı | ✔ | ✔ |
| Anketi kapatma | ✔ | ✔ |
| Sonuç grafiği | ✔ `Grafik` (P223 kuralı: ≤6 dilim pasta, fazlası çubuk) | ⚠ **YAPILMADI** — aşağıda |
| Kim neye oy verdi | ✔ tablo | API hazır (`oyDokumu`), ekran yok |
| Katılım oranı | ✔ | ✔ |
| Anonimde döküm isteği | atılmaz | atılmaz |
| KVKK uyarısı | modal içinde | oy kartında |

**AÇIKÇA YAPILMADI (mobil):** tarih aralığı seçimi, malik/kiracı ayrımı,
sonuç grafiği ve oy dökümü ekranı. Model ve API katmanı üçünü de
taşıyor; eksik olan yalnızca form/ekran alanları. Parite kuralı gereği
bunu "yapıldı" saymıyorum — bir sonraki turda kapatılacak iş.

### §3 DOĞRULAMA — ne ölçtüm

`backend/tests/test_p237_anket.py` — **12 test yeşil**.

| Ölçüm | Sonuç |
|---|---|
| Hedef kitle çoklu seçilir, geri döner | ✔ |
| Hedef dışındaki rol oy veremez | **403** ✔ |
| Hedef boşsa herkes oy verir | 201 ✔ |
| Bilinmeyen rol | **422** ✔ |
| Başlangıç gelmeden oy | **409**, `acik=false` ✔ |
| Bitiş < başlangıç | **422** ✔ |
| Adlı ankette döküm: kim, neye, adıyla | ✔ |
| **Anonim ankette `anket_oy.user_id`** | **veritabanında NULL** ✔ |
| Anonimde döküm ucu | **409** (403 değil: veri yok) ✔ |
| `anket_katilim`da `secenek_id` kolonu | **yok** ✔ |
| **KIRMA: elle SQL ile anonim+kimlikli oy** | `CheckViolation` ✔ |
| **KIRMA: elle SQL ile `anonim` değiştir** | tetikleyici reddetti ✔ |
| Karşı kontrol: adlı ankette kimlik yazılır | ✔ |
| Anonimde de tek oy | ikinci oy **409** ✔ |

Web: `tests/p237-anket.dom.test.ts` — 7 test (katılım oranı, paydasız
durumda oranın çizilmemesi, anonimde döküm isteğinin **hiç atılmaması**,
adlıda dökümün çizilmesi, iki maddeden az olunca POST'un atılmaması,
hedef+anonimin gövdeye girmesi, anonim uyarısının kaydetmeden önce
görünmesi).

Mobil: `test/p237_anket_test.dart` — 10 test; dikiş yeri taklit HTTP
adapter'ında (`anonim` bayrağının gövdeye gerçekten konması dahil).

**ÖLÇEMEDİĞİM:** anket bildiriminin gerçek bir cihaza düşmesini
süremedim (emülatör yok, `PUSH_PROVIDER=noop`); ölçülen şey
`dispatch_external`ın doğru hedef kümesiyle çağrılması.

### §3 KİLİDİN YAKALADIĞI GERÇEK KUSUR

**`bff-yol-eslesmesi`** — oy dökümü için
`app/api/panel/anketler/[id]/oylar/route.ts` açmıştım. Kilit bunu
çürüttü: **statik `anketler` klasörü açmak,
`/api/panel/anketler` isteğinin genel `[kaynak]` vekiline düşmesini
engelliyor** (Next statik segmenti önce çözer ve geri dönmez) — yani
anket listesi ve oluşturma 404 olurdu. Çözüm: `[kaynak]/[id]/[eylem]`
vekiline beyaz listeli bir `GET` eklendi.

Ayrıca `tests/kurulum.ts`'e **`ResizeObserver` kuklası** kondu: jsdom onu
tanımlamıyor ve grafik çizen her sayfa testi bu duvara çarpardı (hata
dinamik parça yüklendikten sonra atıldığı için test "beklenmedik boş DOM"
diye düşüyordu).


---

## TURUN SONU — ne bitti, ne bitmedi

### Commit dökümü

| Commit | İçerik | Not |
|---|---|---|
| §1 | başlık çubuğu simgeleri | temiz |
| §2 | görev alt adımları | **§3'ün yarım backend dosyalarını da kapsıyor** (`git add -A` süpürdü): göç 0137, `models.py`/`schemas.py`/`routers/anketler.py` ilk hâli. Tarih yeniden yazılmadı; bu not o yüzden burada |
| §3 | anket sistemi | kalan her şey |

### Kabul kriterleri

| # | Kriter | Durum |
|---|---|---|
| 1 | Bina düzenlemede tekrar eden simge kaldırıldı | ✔ |
| 2 | Devriye takibi menü girişleri sadeleşti | ✔ (enum'dan silindi) |
| 3 | Simgeler açıklamalı; erişilebilirlik etiketleri var | ✔ (ekran okuyucuyla **dinlenmedi** — emülatör yok) |
| 4 | Tüm başlık çubukları tarandı | ✔ (mobil 29 eylem / web 86 sayfa; kaynak kilidi) |
| 5 | Görev alt adımlara bölünebiliyor | ✔ |
| 6 | Her adım ayrı tamamlanıyor, fotoğraf + not | ✔ |
| 7 | Yönetici ilerlemeyi adım adım görüyor | ✔ (listede + ayrıntıda, iki yüzey) |
| 8 | Her güncellemede bildirim (yorgunluk çözümüyle) | ✔ eşik + toplama |
| 9 | Anket oluşturuluyor: başlık, görsel, tarih, ≥2 madde | ✔ web; **mobilde tarih alanı YOK** |
| 10 | Hedef kitle çoklu seçilebiliyor | ✔ (mobilde malik/kiracı ayrımı YOK) |
| 11 | Oylar anlık takip, grafikle gösterim | ✔ web; **mobilde grafik YOK** |
| 12 | Anonim anket çalışıyor, kimlik görünmüyor | ✔ veritabanı kısıtıyla kanıtlandı |
| 13 | Anonimlik sonradan değiştirilemiyor | ✔ iki katman, kırma denemesiyle kanıtlandı |
| 14 | 7 dil parity | ✔ (web 19 + mobil 16 yeni anahtar) |
| 15 | Tam test paketi yeşil | ✔ **backend 3284 / web 1859 / mobil 2257** |

### AÇIKÇA BİTMEDİ

Mobil anket yüzeyinde dört alan: **tarih aralığı seçimi, malik/kiracı
ayrımı, sonuç grafiği, oy dökümü ekranı.** Model ve API katmanı dördünü
de taşıyor; eksik olan yalnızca form/ekran. Parite kuralı gereği bunu
"yapıldı" saymıyorum.

### ÖLÇEMEDİKLERİM (tekrar, tek yerde)

- Gerçek cihazda hiçbir akış sürülmedi (emülatör yok): kamerayla adım
  kapatma, push bildirimi düşmesi, ekran okuyucu telaffuzu.
- Push zinciri `dispatch_external` çağrısına kadar ölçüldü;
  `PUSH_PROVIDER=noop` olduğu için gerçek gönderim ölçülmedi.
