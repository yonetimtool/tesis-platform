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
