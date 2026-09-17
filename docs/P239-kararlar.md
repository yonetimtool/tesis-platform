# P239 — kararlar

Yedi bölüm. Her bölüm ayrı commit.

---

## §1 — Izgara kart adı kelime ortasından bölünüyordu

### P229 kilidi bunu neden yakalamadı

Kullanıcı haklı olarak sordu. Ölçtüm — `dugme_metni_tasmasi_test`
(P229 §1) iki sebeple göremezdi:

1. **DÜĞME etiketlerini** tarıyor; ızgara **kart adları** kapsamında değil.
2. **SATIR SAYISI** ölçüyor. Kart adı zaten iki satıra sarabilir (tasarım
   böyle) — "Görüntülem / e İzni" de iki satırdır. Yani sayım doğru,
   **bölünme yeri** yanlıştı; ölçülmeyen şey tam olarak oydu.

### Kök neden — `AutoSizeText`in seçim ölçütü yanlış

`AutoSizeText`, metnin **tamamının** `maxLines` içine sığdığı en büyük
puntoyu seçer. Bir kelime satıra sığmıyorsa Flutter onu **içinden böler**
ve metin yine iki satıra "sığmış" olur — yani `AutoSizeText`e göre sorun
yoktur. Ölçüt metne bakıyordu; **en uzun kelimeye** bakmalıydı. Kelime
satıra sığıyorsa Flutter onu asla bölmez.

### Çözüm — kullanıcının verdiği sırayla

| Madde | Uygulama |
|---|---|
| (a) kelime bütünlüğü korunsun | `kartBaslikPuntosu` en uzun **bölünmez parçanın** sığdığı puntoyu bulur |
| (b) sığmıyorsa küçült | aynı döngü, yarım punto adımlarıyla **8pt**'ye kadar |
| (c) yine sığmıyorsa sondan kes | `null` döner → kart `maxLines: 1` + ellipsis çizer; **iki satıra bölmez** |
| (d) tam metin erişilebilirlikte | `semanticsLabel` + `Tooltip` (uzun basma) |

**`AutoSizeText` ve grup KORUNDU.** Yalnızca punto **tavanı** bastırılıyor;
`AutoSizeText` bundan daha küçüğe inebilir ve küçükte de kelime bölünmez.
Grubu (`baslikGrubu`) kaldırmak kartların ortak puntosunu ve
`home_kart_titremesi_test`in koruduğu titremesizliği bozardı.

### Tire meşru bölünme yeridir

İlk dedektörüm `Site- | Budget`, `Rundgang- | Verfolgung` gibi **altı
Almanca bileşik adı** ihlal saydı. Bu yanlış: tireden sonraki bölünme bir
**hece** bölünmesi değil, Unicode'un zaten tanıdığı bir satır sonu
fırsatı ve tipografik olarak doğru. Hem dedektör hem punto seçimi
`- / ‐ – —` karakterlerini kelime sınırı sayıyor.

### Doğrulama

`mobile/test/p239_kelime_bolunmesi_test.dart` — 7 test.

**Düzeltmeden ÖNCE ölçülen ihlaller** (sabit 14pt, 320dp kart genişliği):
tr'de 9, en'de 4, de'de 8+ … bildirilen kart dahil:
`tr/modulGoruntulemeIzni: Görüntüle | me İzni`.

Kilit **üretim algoritmasının seçtiği puntoda** ölçüyor. İlk yazımım sabit
14pt'de ölçüyordu ve **düzeltmeden sonra da kırmızı kalırdı** — çünkü kart
14pt'de çizmiyor. Kilit böylece "metin kısa mı" değil "kart doğru mu
çiziyor" sorusunu soruyor.

| Ölçüm | Sonuç |
|---|---|
| 7 dil × `modul*` adları, 320dp | ihlal **0** |
| Büyük yazı tipi (**x1.6**) | ihlal **0** |
| En küçük puntoda da sığmayan ad | `null` → tek satır ✔ |
| Bölünmez parçalar (tire/boşluk) | ✔ |
| **KIRMA**: punto seçimi tabana sabitlendi | **üç test birden kırmızı** ✔ |

**Altın görüntü değişti** (`yonetici_ana_ekran`, `sakin_ana_ekran`):
"Vardiyalar" artık `69x20` (iki satır, ortadan bölünmüş) yerine `69x10`
(tek satır + üç nokta). Test fontu her glifi kare em çizdiği için
gerçekten olduğundan çok daha dar; cihazda bu ad rahat sığar.

### ÖLÇEMEDİĞİM

Gerçek cihazda ekran okuyucunun tam metni okuduğu ve uzun basma
ipucunun göründüğü sürülmedi (emülatör yok); ikisi de widget
seviyesinde bağlandı.

---

## §6 — Devriye planlarında ÇİFT "Plan ekle" düğmesi

**Kullanıcı bildirimi:** "Ortadaki düğmeyi KALDIR. Sağ alttaki her zaman
kalsın. Boş durumda açıklama metni kalsın… ama düğme olmasın. Aynı kalıbı
başka ekranlarda da tara."

### ÖLÇÜM: kusur devriyeden fazlasındaydı

`floatingActionButton` **ve** `BosDurum(... onEylem ...)` birlikte olan
ekranları taradım. Kullanıcı birini bildirdi; **dört** tane çıktı:

| Ekran | Satır |
|---|---|
| `residents_screen.dart` | 140 |
| `patrol_plans_screen.dart` | 50 |
| `staff_screen.dart` | 51 |
| `checkpoints_screen.dart` | 51 |

Dördünde de FAB `FloatingActionButton.extended` — yani **etiketli**.

### KARAR: ortadaki gider, FAB kalır, açıklama kalır

Gerekçe: liste dolunca ortadaki kayboluyor, sağ alttaki kalıyor.
Kullanıcı aynı eylemi önce iki yerde görüyor, sonra "düğme nereye gitti"
diye arıyor. Açıklama metni **kalır** — boş liste karşısındaki kullanıcı
çoğu zaman özelliğin ne olduğunu da bilmiyor; kaldırılan yalnız düğme.

### P166 §10 GERİ ALINDI — ve neden bu bir çelişki değil

P166 §10 tam tersini yazmıştı: "boş durumda çağrı düğmesi — liste yokken
göz ekranın ortasındadır, dibindeki FAB'de değil". O kararın **asıl**
derdi şuydu: *"bir eylemin TEK girişi etiketsiz bir ikon olmamalı."*
Ölçüm: bu dört ekranda FAB zaten `extended` ve **adını yazıyor**, yani
P166'nın derdi FAB tarafından karşılanıyor. Ortadaki düğme o yüzden
fazlalıktı. Kilidin başlığı ve gerekçesi bu ölçümle birlikte
`gizli_aksiyon_test.dart` içinde yeniden yazıldı — silinmedi: yeni sürüm
artık "ortadaki YOK **ve** FAB etiketli VAR" ikilisini birlikte ölçüyor,
böylece geri alma FAB'in etiketini düşürmeye bahane olamaz.

### WEB TARAMASI (parite)

Web'de **FAB yok** — ekleme düğmesi sayfa başlığında ve liste dolunca da
orada duruyor, yani üst üste binen bir ikilik yok. Aynı *sınıf*tan tek
bulgu `units/page.tsx`: boş durumdaki "Daireleri bina düzenlemeden
ekleyin" bağlantısı, başlıktaki "Bina düzenleme" düğmesiyle **aynı yere**
gidiyordu ve liste dolunca kayboluyordu. Kaldırıldı; açıklama metni
(`daireYokAlt`) kaldı. Artık kullanılmayan `daireBosDurumEylem` anahtarı
7 sözlükten de silindi.

### KİLİT

`mobile/test/p239_cift_dugme_test.dart` — kaynak taraması: FAB taşıyan
hiçbir ekranda `BosDurum(... onEylem ...)` olmasın. Dedektörün kendisi de
üç örnekle sınanıyor (yakalar / FAB yokken serbest bırakır / düğmesiz boş
durumu temiz sayar), yoksa "hiç ihlal yok" sonucu taramanın **çalıştığını**
değil yalnızca bir şey bulmadığını gösterirdi.

**Kilidin yakaladıkları (koşumda kırmızıya dönen ÜÇ eski test):**
`gizli_aksiyon_test` (yukarıda), `aidat_nokta_kuyruk_i18n_test` (boş
liste metni testi düğmeyi de ölçüyordu) ve `p206_mobil_sayac_personel_test`
(formu **boş durum düğmesine basarak** açıyordu → FAB'e çevrildi).
Üçü de gerçek bağımlılıktı; sessizce geçselerdi değişiklik eksik kalırdı.

---

## §7 — Anket seçenekleri: ayrı kutular, "+" ile ekle, tek tek sil

### ÖLÇÜM: iki yüzeyde de tek çok-satırlı metin alanı

Web `anketler/page.tsx` `maddeler: string` + `CokSatir`, mobil
`anket_form.dart` tek `TextEditingController` — ikisi de satırları
bölerek seçeneğe çeviriyordu. P237'de bunun gerekçesi yazılıydı: "ayrı
alan açmak aynı işi üç dokunuşa çıkarırdı."

**O gerekçe tutmadı.** Ölçülen üç kusur: kullanıcı kaç seçenek yazdığını
göremiyor; boş satır/boşluk sessizce yutuluyor; bir seçeneği silmek
satırı işaretleyip silmeyi gerektiriyor. Mobil klavyede satır sonu koymak
da zaten fazladan bir dokunuş — "üç dokunuş" tasarrufu gerçek değildi.

### KARAR

- **İki kutu açık başlar** (en az iki şartı zaten var; boş form o şartı
  göstererek başlasın).
- **"+"** bir kutu ekler, sınırsız.
- **Silme iki kutuda KAPALI — gizli değil.** Gizlenen düğme "neden yok"
  sorusunu doğurur; kapalı düğme ipucu metniyle (`En az iki seçenek
  gerekir`) kuralı söyler.
- **Sunucuya giden gövde DEĞİŞMEDİ** (`{metin, sira}` listesi / mobilde
  metin listesi) ve boş kutular atılıp `sira` yeniden verilir. Bu yüzden
  **mevcut anketler ve arka uç etkilenmez** — değişiklik yalnız form
  durumunda.
- 7 dile üç yeni anahtar: `anketSecenekEkle`, `anketSecenekSil`,
  `anketSecenekNo` (mobilde `{n}` yer tutuculu).

### KİLİT (iki yüzey)

`admin-web/tests/p239-anket-secenek.dom.test.ts` ve
`mobile/test/p239_anket_secenek_test.dart` — beşer test: iki kutuyla
başlar / "+" ekler / ikide silme kapalı / üçte açılır ve **ortadakini**
siler (kalanlar A, C) / gövde `{metin, sira}` kalır ve boş kutu atılır.

**KIRMA:** silme kuralı `disabled={false}` yapıldı → web'de iki test
birden kırmızı; kural geri alındı.

**Kilidin yakaladığı:** `p237_anket_ekranlari_test`'te "yalnız güvenlik
hedeflenince ayrım çizilmez" testi kırmızıya döndü — form uzayınca hedef
çipi katlamanın altında kaldı ve `tap` **dokunmadan** uyarı verdi (P237'de
de yaşanan sahte-yeşil tuzağı). `ensureVisible` eklendi.

### ÖLÇEMEDİĞİM

Seçenekleri **yeniden sıralama** (sürükle) yapılmadı — brief'te
"opsiyonel" olarak geçiyordu; sıra `sira` alanıyla zaten kutuların
görsel sırasından türüyor.

---

## §5 — Vardiya durum kartı: yalnız şu an görevde olanlar

**İstek:** "Kartta yalnız o an görevde olan kişiler olsun; giriş yapanın
kendi kartı görünmesin; karta dokununca kişi ekranı açılsın, telefonu
dokunulabilir olsun."

### ÖLÇÜM: kart KİŞİ değil ŞABLON gösteriyordu

Ana ekrandaki "Vardiya Durumu" şeridi `GET /shifts`ten besleniyordu —
yani vardiya **tanımlarını** (Sabah Vardiyası 06:00–14:00). Kimsenin
atanmadığı bir günde de aynı görüntüyü veriyordu. AKTİF/PLANLANDI ayrımı
da **istemcide** saatten hesaplanıyordu; geceyi aşan vardiya ve tesis
saat dilimi orada yanlış çıkabiliyordu.

Doğru kaynak zaten vardı: **`GET /vardiya-plani/simdi`** (P203 §4.2) —
sunucu, tesisin saatinde, gerçekten atanmış kişileri döner
(`gorevdekiler[{user_id, ad, rol}]`). Web'de bu uç zaten çağrılıyordu
ama sonuç `ad.join(", ")` ile **düz metin** olarak yazılıyordu.

### KARAR

- Şerit artık `/vardiya-plani/simdi` → **kişi kartları**. `vardiyaKartlari`
  eşleştiricisi (ve onu besleyen `/shifts` yolu) **silindi** — iki kaynağı
  yan yana bırakmak, hangisinin doğru olduğunu belirsiz kılardı.
- **Kendi kartım çizilmez** (her iki yüzeyde). Kendi görevde olduğumu
  zaten biliyorum; dar şeritte en değerli yer başkasına ulaşma yeridir.
  Liste kendi kaydım düşünce boşalıyorsa bölüm hiç çizilmez.
- **Sıradakiler kart olmaz** — şerit "şu an"ı anlatır.
- Serinin sonundaki **"Yönetici" kartı kaldırıldı**: görevde olmayan bir
  kişiyi "şu an görevde" şeridine koymak bölümün anlamını bozuyordu.
  Erişim kaybolmadı — menüde etiketli "Yönetim iletişimi" girişi duruyor.

### TELEFON: iki yüzeyde İKİ FARKLI YOL — ve nedeni

| | Mobil | Web |
|---|---|---|
| Kaynak | `GET /call-target/{id}` | `GET /users/{id}` |
| Numara ekranda | **yazmaz** (yalnız çeviriciye gider) | yazar, `tel:` bağı |

**`/call-target` yalnız `security` + `resident` rollerine açık**
(`CALL_DIRECTIONS`: security→{yönetici, sakin}, sakin→{security}).
Yönetici/admin oradan **403** alır. Bu bilinçli bir KVKK tasarımı ve bu
tur onu **genişletmedi** — rıza (`aranabilir`) ve yön matrisi olduğu gibi
duruyor. Web'de yöneticinin numarayı görme yolu **zaten vardı**:
`GET /users/{id}` tek-kayıt yönetim görünümü telefonu döner (liste ucu
dönmez — toplu numara yok) ve kullanıcılar sayfası da aynısını çizer.
Yani panel **yeni bir ifşa açmıyor**, var olanı kişinin yanına getiriyor.
İstek yalnız panel AÇILINCA atılır (şerit açılır açılmaz N numara
çözmek, amaç-sınırlılığa aykırı olurdu).

### AÇIK MADDE — kullanıcı kararı gerekiyor

Saha personeli (`security`) **meslektaşını arayamaz**: yön matrisinde
`security→security` yok. Yani mobilde bir görevli, yanındaki görevlinin
kartına dokunduğunda düğme "aranamıyor" der. Bu bir kusur değil, mevcut
KVKK kararının sonucu. Genişletmek (personelin personeli araması,
yöneticinin personeli araması) **gizlilik politikası değişikliğidir** ve
kendi başıma yapmadım. İstenirse `CALL_DIRECTIONS`'a personel-içi yönler
eklenebilir; sakin numaralarına erişim yine değişmez.

### KİLİTLER

- `mobile/test/vardiya_section_test.dart` — **yeniden yazıldı** (eski hali
  silinen eşleştiriciyi ölçüyordu): görevdekiler kart olur / kendi kartım
  çizilmez / yalnız ben görevdeysem liste boşalır / sıradakiler kart olmaz
  / slot yoksa alt başlık rol olur + şeritte dokunma ve **kişisiz kart
  tıklanmaz**.
- `mobile/test/p239_kisi_sayfasi_test.dart` — ad/rol/vardiya satırı
  rotadan çizilir, ham `security` ekranda yazmaz, numara ekranda yazmaz
  ama çeviriciye gider, **403'te ekran çökmez**, ikinci istek atılmaz.
- `admin-web/tests/p239-vardiya-kisi.dom.test.ts` — tıklanabilir isimler,
  kendi kaydım çizilmez, `tel:` bağı, numara yoksa "kayıtlı değil",
  **panel açılmadan `/users/{id}` isteği atılmaz**.

**KIRMA:** kendi-kaydı düşüren süzgeç iki yüzeyde de kaldırıldı → mobilde
iki, web'de bir test kırmızı. Geri alındı.

### ÖLÇEMEDİĞİM

Gerçek cihazda çeviricinin açıldığı sürülmedi (emülatör yok);
`CallLauncher` sahtesiyle `tel:` URI'sinin doğru üretildiği ölçüldü.

---

## §4 — Takvimden gün seçimi: GÖREVLER

### ÖLÇÜM: kolon ve uç HAZIRDI, form GÖNDERMİYORDU

`task.son_tarih` P230 §4'te (göç 0133) eklendi; `TaskCreate`/`TaskUpdate`
ikisi de kabul ediyor; liste "gecikti" rozetini ve `gecikme_gun`u ondan
hesaplıyor; mobil görev detayı onu **okuyup yazıyor**. Ama:

| Yüzey | Son tarih alanı |
|---|---|
| Web `tasks/page.tsx` | **yok** (`sonraki_planlanan` var, o başka şey) |
| Mobil `task_form_sheet.dart` | **yok** |

Yani "gecikti" durumu arayüzden **kurulamıyordu**, yalnızca okunuyordu.

### KARAR

- İki yüzeye de **opsiyonel son tarih** alanı. Web'de `datetime-local`
  (tarayıcının kendi takvimi — sayfanın geri kalanıyla aynı desen),
  mobilde gün→saat seçici.
- **Varsayılan YOK.** Bugünü doldurmak, kullanıcının vermediği bir sözü
  kaydetmek ve her görevi bir süre sonra "gecikti" yapmak olurdu.
- **Gün tek başına yetmez:** "12 Ekim'de bitsin" diyen kullanıcı gün
  içinde bir an kastediyor; 00:00 almak o anı bir gün öne çeker ve iş
  başlamadan gecikmiş sayılır. Bu yüzden saat de sorulur.
- `sonraki_planlanan` ile **karıştırılmaz**: o yalnız periyodik
  görevlerde dolu ve anlamı "bir sonraki tekrar". İkisi ayrı alan olarak
  gider (web testinin son iddiası tam olarak bunu ölçer).
- Mobilde `son_tarih` **tam-gövdede** (null da gider): PATCH ile son
  tarihi **kaldırmak** başka türlü mümkün olmazdı.

### TARİH SEÇİCİ ORTAK BİLEŞENE TAŞINDI

Satır P237'de anket formunun **içinde** özel bir widget'tı. İkinci
tüketici çıkınca kopyalamak yerine taşındı:
`mobile/lib/src/core/ui/tarih_satiri.dart` (`TarihSatiri` +
`tarihSaatSec`). Kopya, iki seçicinin zamanla ayrışması demekti —
birinde "temizle" olur, ötekinde olmaz. `anketTarihSec` /
`anketTarihTemizle` anahtarları `ortakTarihSec` / `ortakTarihTemizle`
oldu (7 dil).

### KİLİTLER

- `admin-web/tests/p239-gorev-son-tarih.dom.test.ts` — alan var ve değer
  ISO olarak gövdeye girer (`sonraki_planlanan` **null kalır**), boşsa
  null gider, düzenlemede mevcut değer alana yüklenir (yüklenmeseydi
  kaydet var olan son tarihi sessizce silerdi).
- `mobile/test/p239_gorev_son_tarih_test.dart` — UTC ISO, boşta null,
  anahtar her zaman var (PATCH ile kaldırılabilir), düzenleme taslağı
  mevcut tarihi taşır.

**KIRMA:** web'de `son_tarih: toIso(...)` satırı gövdeden çıkarıldı → iki
test kırmızı. Geri alındı.

### YAPILMADI — devriye planında gün seçimi (§4'ün ikinci yarısı)

`patrol_plan` tablosunda **ne gün listesi ne de atanan kişi var**:
plan `ad + shift_id + baslangic_saat + bitis_saat + periyot_dakika`dan
ibaret ve hangi gün kimin yürüyeceği `shift` kadrosundan türüyor. Yani
bu, arayüz işi değil **şema değişikliği** (göç + uç + iki yüzey + rol
matrisi/indeks kilitleri). Bu tura sığmadı; §3'ün devriye ayağıyla
birlikte ayrı bir turda yapılmalı — bkz. aşağıdaki §3 notu.

---

## §3 — Kişi ataması: nerede var, nerede yok (ÖLÇÜM)

| | Web | Mobil |
|---|---|---|
| **Vardiya** | var (P235 birleşik modal: takvim + kişi) | var (hızlı ekle) |
| **Görev** | var (`atanan_user_id` seçici) | var (atama seçici) |
| **Devriye planı** | **YOK** | **YOK** |

Devriye planında kişi ataması **arayüzde eksik olduğu için değil,
veritabanında olmadığı için** yok: `patrol_plan`ın atanan kişi kolonu
hiç açılmamış; plan bir `shift`e bağlanır ve kimin yürüyeceği o vardiya
kadrosundan gelir. Bunu "kişiye ata"ya çevirmek bir tasarım kararıdır
(kadro mu kişi mi öncelikli, ikisi birden olursa hangisi kazanır) ve
göç gerektirir. **Bu turda yapılmadı** — kendi turunu hak ediyor.

---

## §2 — Web'de vardiya oluşturma: kök neden AYNI ETİKETTİ

**İstek:** "Web'de vardiya ekleme penceresi mobildeki gibi olsun —
oluştururken takvimden gün ve kişi seçilsin; atamadan sonra çizelge
tazelensin."

### ÖLÇÜM: istenen özellik ZATEN VARDI

`admin-web/components/vardiya/vardiya-ekle-modali.tsx` (P235 §1) tam da
bu: **takvim → kişi/saat → gruba ekle → önizleme**, mobildeki akışın
aynısı. Atama sonrası çizelge de tazeleniyor (`onBitti → mutate()`).

Kusur başka yerdeydi ve ölçünce net çıktı: **sayfadaki iki ayrı düğme
aynı sözlük anahtarını kullanıyordu** — `t("vardiyaYeni")` = "Yeni
vardiya".

| Düğme | Açtığı şey |
|---|---|
| Üst araç çubuğu (`vardiya-yeni`) | birleşik modal: takvim + kişi |
| Şablonlar bölümü | **şablon** formu: ad + saat + gün tipi |

Şablon modalının başlığı da `vardiyaYeni`ydi. Yani ekranda iki yerde
**birebir aynı yazı** vardı ve farklı şeyler açıyorlardı; ekran
görüntüsündeki pencere ikincisiydi. Kullanıcının "takvim nerede,
kişi nerede" sorması bu yüzden doğruydu — yanlış pencereye bakıyordu,
çünkü pencerenin adı diğeriyle aynıydı.

### KARAR

- Şablon bölümünün düğmesi ve modal başlığı ayrıldı:
  `vardiyaSablonYeni` / `vardiyaSablonDuzenle` (7 dil).
- Bölüme **açıklama satırı**: "Şablon bir vardiya tanımıdır (ad + saat +
  gün tipi). Çizelgeye kişi eklemek için yukarıdaki '…' düğmesini
  kullanın." Düğme adını değiştirmek tek başına "peki bu ne zaman
  kullanılır" sorusunu yanıtlamazdı.
- Açıklamadaki düğme adı **sözlükte sabitlenmedi**, `{dugme}`
  parametresiyle üstteki düğmenin kendi etiketinden geliyor — etiket
  değişirse açıklama onunla değişsin diye.
- `gun_tipi` alanı **silinmedi**: sunucu onu doğruluyor
  (`vardiya_plani.py:128`, `scheduler/service.py` `_gun_uyar`), yani
  şablonun gerçek bir işlevi var.

### KİLİT

`admin-web/tests/p239-vardiya-sablon-ayrimi.dom.test.ts` — iki düğme
aynı yazıyı taşımaz (hem sözlük hem DOM düzeyinde), şablon bölümü ne
olduğunu ve nereden vardiya ekleneceğini söyler, üstteki düğme
**takvim + kişi taşıyan** modalı açar, atamadan sonra çizelge yeniden
çekilir.

**Testin kendi zayıflığı düzeltildi:** ilk yazımda personel listesi boştu
→ gönderim düğmesi kapalı kalıyor ve test "tazeleme" iddiasını **hiç
ölçmeden** yeşil görünüyordu. Sahte listeye gerçek bir personel konuldu;
artık önce POST'un atıldığı, sonra çizelgenin yeniden çekildiği ölçülüyor.

**KIRMA:** (1) `onBitti`'deki `mutate()` kaldırıldı, (2) şablon düğmesi
yeniden `vardiyaYeni` yapıldı → iki test kırmızı. Geri alındı.

**Kilidin yakaladığı:** `yz-tasima-bildirim-vardiya.dom` iki testi
şablon formunu "Yeni vardiya" düğmesiyle açıyordu → kırmızıya döndü.
Gerçek bağımlılıktı; yeni etikete çevrildi.

### MOBİLDE AYNI KUSUR YOK

Mobilde şablon ekranı (`vardiyalar_screen`) salt-okuma + personel atama;
kendi metinleri ayrı (`vardiyaBaslik`, `vardiyaTanimYok`,
`vardiyaPersonelAta`) ve şablon **oluşturma** mobilde hiç yok. Etiket
çakışması web'e özgüydü; parite açısından eklenecek bir şey çıkmadı.

---

## §3 (kısmi) — Devriye planına VARDİYA seçimi: mobil paritesi

Yukarıdaki §3 ölçümünde "devriye planında kişi ataması yok" yazmıştım.
Daha derin ölçüm bir parite kusuru daha çıkardı:

| | Web | Mobil |
|---|---|---|
| Devriye planı formunda `shift_id` (vardiya) | **var** | **YOKTU** |

`patrol_plan`da atanan **kişi** kolonu yok; "kim yürüyecek" sorusunun
bugünkü yanıtı planı bir **vardiyaya** bağlamak ve o vardiyanın
kadrosunun yürümesi. Mobilde bu seçici hiç olmadığı için **mobilden
açılan her plan kadrosuz kalıyordu** ve kimin yürüyeceği hiçbir yerde
yazmıyordu.

### KARAR

- Mobil forma vardiya seçici eklendi (`devriye-vardiya`), web'deki
  alanın karşılığı. **Opsiyonel**: boş bırakmak geçerli bir hal —
  zorunlu kılmak, vardiyası henüz tanımlanmamış bir sitede plan açmayı
  imkânsız kılardı.
- Vardiya listesi çekilemezse seçici **çizilmez** ve mevcut seçim
  korunur; hatayı "vardiya yok" diye göstermek yanlış olurdu.
- `shift_id` PATCH'te **null da gönderilir**: vardiya bağını
  **kaldırmak** başka türlü mümkün olmazdı.

### KİLİT

`mobile/test/p239_devriye_vardiya_test.dart` — dikiş yeri **taklit HTTP
adapter** (repo/API düzeyinde taklit gövdeyi kuran katmanı ölçmezdi):
oluşturmada `shift_id` gider, seçilmezse null gider, PATCH'te null
gönderilir, yanıttan geri okunur, alan yoksa model null taşır.

**KIRMA:** gövdeden `shift_id` çıkarıldı → iki test kırmızı.

### HÂLÂ YAPILMADI

Devriye planına **doğrudan kişi** ataması ve **gün seçimi** — ikisi de
göç gerektiriyor ve tasarım kararı içeriyor:
1. Kişi mi kadro mu önceliklidir, ikisi birden varsa hangisi kazanır?
2. "Gün seçimi" **haftanın günleri** mi (Pzt/Çar/Cum — plan tekrarlı
   kalır) yoksa **somut tarihler** mi (plan tekrarsızlaşır)? Mobildeki
   `GunTakvimi` somut tarih seçiyor; devriye planı ise doğası gereği
   tekrarlı. Bu iki cevap farklı şema demek.

Bu iki soru yanıtlanmadan göç yazmak, yanlış tabloyu kalıcılaştırırdı.
