# P243 — kararlar

Altı bölüm: vardiya modalı sadeleştirme (§1), "Atanmamış" tanımı (§2),
içe aktarım tablosu (§3), web görünüm modu (§4), SOS düzenlemesi (§5),
onboarding (§6). Her bölüm ayrı commit.

---

# §1 — VARDİYA EKLEME MODALI

## §1.0 ÖLÇÜM: modal sunucuya ne gönderiyordu

Alanları kaldırmadan önce modalın **çalıştığını** varsaymıştım. Ölçtüm,
çalışmıyordu:

> Modal, "serbest saat + tek kişi" durumunda `/vardiya-plani/toplu`
> ucuna `baslangic` / `bitis` gönderiyor; şema `baslangic_tarih` /
> `bitis_tarih` istiyor.

Sunucuya birebir o gövdeyi göndererek ölçüldü:
`422 baslangic_tarih: Field required`.

Yani **web'de en sık yapılan işlem — tek kişiye serbest saatle vardiya
yazmak — P235'ten beri hiç çalışmıyormuş.**

**DOM testi bunu neden görmedi:** taklit `fetch` her gövdeye 200
dönüyordu. Sözleşme uyumu ancak sunucuya karşı ölçülür; bu yüzden yeni
kilit backend'de (`test_p243_vardiya_modali.py`) ve DOM testi "hangi
uca gidildiği" kuralını ölçüyor.

**Düzeltme alan adını yamalamak değil, ikinci yolu kaldırmak oldu.**
`/kalip-uygula` serbest saati zaten tek dilimli bir grup olarak işliyor
ve çakışma akışı, önizleme, parti kimliği ve rotasyon hep orada. İki yol
demek bu kuralların iki kopyası demekti — ve biri sessizce eskimişti.

## §1.1 Kaldırılanlar

| Alan | Gerekçe |
|---|---|
| **Bu vardiyadaki rol** | Kişi sisteme eklenirken rolü zaten belirleniyor. Vardiya başına tekrar sormak aynı bilgiyi ikinci kez istemek — ve iki kaynak birbirinden sapabilir. |
| **Lokasyon** | Referanstaki "şube"nin karşılığıydı; bizde şube yok. Doldurulmayan bir alan formu uzatmaktan başka bir şey yapmıyordu. |
| **Başlangıç / bitiş tarihi** | Üstte zaten takvim var. İki yol birden açıkken hangisinin geçerli olduğu belirsizdi — **ve bu belirsizlik önizlemeyi öldürüyordu** (§1.4). |

**Sütunlar silinmedi** (göç 0145): P241'de yazılmış kayıtlar duruyor ve
ızgara onları hâlâ gösteriyor. Sütunu düşürmek var olan veriyi silmek
olurdu; yapılan şey **yeni kayıtta sormamak**.

## §1.2 Rol süzgeci (§1d)

Kişi seçiminin **üstünde**, `ortakTumu` varsayılanıyla. **Kaydedilen bir
alan değil**, gövdede gitmiyor (test bunu ayrıca ölçüyor). Rol
değiştiğinde seçili kişi süzgecin dışında kalıyorsa **düşürülüyor**:
görünmeyen bir kişiyle vardiya oluşturmak, kullanıcının görmediği bir
sonuç üretirdi. Roller **personel listesinden türer**, elle yazılmaz.

## §1.3 Aylık rotasyon (§1e) — takvim ayı, 4 haftalık döngü değil

İstek sordu. **Takvim ayı seçildi.** Dört haftalık döngü ayın ortasında
kayar ("15 Mart'tan sonra A ekibi geceye geçti") ve yöneticinin
takviminde bir karşılığı yoktur. Takvim ayı **söylenebilir** bir şeydir:
"mart gündüz, nisan gece" — personel de vardiyasını ay adıyla hatırlar.

**Kilit ayırt edici seçildi:** ilk yazımda 2 Mart ↔ 30 Mart kullanmıştım;
dört hafta = çift kaydırma olduğu için haftalık ile aylık **aynı** sonucu
veriyordu ve test iki kuralı ayırt edemiyordu. Kilidi kırarak ölçtüm,
geçti. 9 Mart (tam bir hafta sonra) ile değiştirildi.

## §1.4 Çoklu kalıp (§1f) — yeni kavram üretilmedi

Ölçüldü: **`VardiyaGunGrubu` zaten `kalip_id` taşıyor** (P232). Yani
"birden çok kalıp" için yeni bir yapı gerekmiyordu; eksik olan, modalın
kalıbı **gruba** değil formun tamamına bağlamasıydı. Artık her "Gruba
ekle" kendi kalıbını taşıyor: pazartesi 2-vardiyalı kalıp, cumartesi
3-vardiyalı kalıp — tek istek, tek parti, tek geri alma.

## §1.5 Önizleme (§1g) — kök neden

Önizleme grup üzerinden gidiyor, grup ise **seçili günlerden**
kuruluyordu. Tarih alanlarını doldurup takvimden gün seçmeyen
kullanıcının "Önizle" düğmesi **sessizce hiçbir şey yapmıyordu**
(`hepsi.length === 0` → erken dönüş).

Yani §1c ile §1g **aynı kusurun iki yüzü**. Tarih alanları kalkınca tek
yol kaldı; gün seçilmeden gönder/önizle düğmeleri **kapalı** ve neden
kapalı olduğu yazılı.

---

# §2 — "ATANMAMIŞ" BÖLÜMÜ

## §2.0 ÖLÇÜM: bugün neye göre hesaplanıyor

`/vardiya-plani/cizelge` **her aktif personeli** (güvenlik, tesis
görevlisi, amir, yönetici) boş blok listesiyle döndürüyor — P205'te
bilinçli bir karar ("kim boşta" sorusu da bir plan sorusudur). Web
ızgarası da "bloğu olmayan" herkesi "Atanmamış"a koyuyordu.

Sonuç: bölüm **bir personel rehberine** dönüşmüştü ve asıl soruyu —
*"bu hafta kimi atamayı unuttum"* — görünmez kılıyordu.

## §2.1 Yeni tanım

> **Atanmamış = vardiya düzenine dahil olduğu hâlde bu dönemde vardiyası
> olmayan kişi.**

"Vardiya düzenine dahil" ölçütü (sunucuda, `vardiya_duzeninde`):
1. **Varsayılan kadro** üyesi (`shift_assignment`), **veya**
2. **Herhangi bir tarihte** vardiya satırı var.

**Dönem dışındaki satırlar da sayılır** ve bu şart: bu hafta vardiyası
olmayan ama geçen hafta çalışmış biri *tam da* atanmamış olandır. Yalnız
dönem içine bakmak, ölçütü tanımın kendisiyle çelişirdi.

**Kadro üyeliği neden yeter:** "Haftayı doldur" tam da onları yazacak;
kadroya konmuş ama bu hafta planlanmamış kişi yöneticinin yapılacak
işidir.

**Hiç vardiya girilmemiş sitede bölüm boş** — isteğin şartı, tanımdan
doğal olarak çıkıyor (ölçüldü).

## §2.2 ÖLÇEMEDİĞİM (§1–§2)

* Gerçek tarayıcıda modal açılıp tıklanmadı; DOM testi jsdom üzerinde.
* Aylık rotasyon **bir yıllık** gerçek planla denenmedi; ölçüm üç günlük
  ayırt edici bir kurulumla yapıldı.

---

# §5 — SOS DÜZENLEMESİ

## §5a Web'den tetikleme kaldırıldı

**Gerekçe (isteğin kendi cümlesi):** acil durumda kimse bilgisayar
başına koşmaz, telefon elde olur. P240'ta düğme her sayfaya konmuştu
("alarm geç kalmasın") — ama **yanlış yüzeyde hızlı olmak, hızlı olmak
değildir**.

**Kalan:** alarm **takibi** (`/panik` sayfası: gördüm / müdahale /
kapat) **ve gelen alarm katmanı** (`PanikAlarmi`). Bilgisayar başındaki
yöneticiye alarmın **ulaşması**, onun alarmı **başlatmasından** bağımsız
bir ihtiyaç.

`components/panik/panik-dugmesi.tsx` **silindi**. Kilit, dosyanın geri
gelmediğini ve düzenin onu çizmediğini ölçüyor.

## §5b Mobilde konum

**Ölçüm — şu an neredeydi:** üst app bar'da, ızgara/zil/arama
simgelerinin solunda (P240 §1'de oraya konmuştu, gerekçesi "tek
dokunuş"tu).

**Yeni yer:** sol menünün (drawer) **üst sağı**, marka logosunun
yanında, 48 dp dokunma hedefi ve **görünür "SOS" etiketiyle** (P237:
başka ekrana götüren eylem adını görünür taşır).

**BEDELİ AÇIKÇA:** içerik ekranından SOS'a ulaşmak artık **iki hareket**
(menüyü aç + dokun). Bunu kabul edilebilir kılan şey §5c: alarm artık
tek dokunuşla **gitmiyor** — önce kategori seçiliyor. Yani "tek dokunuşta
ateş" zaten tasarım gereği yok; menüde **ilk ekranda, kaydırmadan, tek
dokunuşla** açılıyor.

**İki giriş bırakılmadı:** aynı eylemin iki kapısı "hangisi gerçek"
sorusunu doğurur (P232'de ölçülen desen).

## §5c Kategoriler

Yedi kategori: deprem, yangın, gaz, tahliye, sağlık, güvenlik tehdidi,
diğer. Göç 0146 (`panik_kategori` enum + `panik_alarm.kategori`).

**`tip` kaldırılmadı, kategori onun yerine geçmez:** `tip` *kimin*
tetiklediğini ve kapsamı, kategori *ne olduğunu* söyler. "Sakin,
dairesinde yangın" ile "yönetici, site geneli tahliye" aynı kategoriyi
taşıyabilir ama aynı alarm değildir.

**Kategori NULL kalabilir:** P240'ta yazılmış alarmların kategorisi yok;
uydurmak, olmayan bir bilgiyi kayda geçirmek olurdu. Kategorisiz alarm
eski metni kullanır.

**Zorunlu da değil:** acil durumda kategori seçmeye zorlamak alarmı
geciktirirdi.

### Metinler — uydurulmadı

| Kategori | Talimat (tr) | Dayanak |
|---|---|---|
| Deprem | "Çök, kapan, tutun. Sarsıntı bitince merdivenle çıkın; asansör kullanmayın." | AFAD'ın temel hareketi "Çök–Kapan–Tutun" ve deprem sonrası asansör yasağı |
| Yangın | "Binayı merdivenden terk edin. Asansör kullanmayın, kapıları kapatın." | İtfaiye tahliye yönergesi (asansör yasağı, kapıları kapatarak yayılımı yavaşlatma) |
| Gaz | "Ateş yakmayın, elektrik düğmelerine dokunmayın. Binayı terk edin." | Doğal gaz dağıtım şirketlerinin kaçak talimatı (kıvılcım kaynağı yasağı) |
| Tahliye | "Binayı derhal terk edin. Asansör kullanmayın, toplanma alanına gidin." | Tahliye yönergesi |
| Sağlık | "112 arandı mı kontrol edin, ekibi kapıda karşılayın." | Ambulansın siteye girişini hızlandıran pratik adım |
| Güvenlik tehdidi | "Bulunduğunuz yerde kalın, kapıyı kilitleyin, 155'i arayın." | Yerinde sığınma (shelter-in-place) yaklaşımı |

**Talimatlar birbirini dışlıyor** ve kilit bunu ölçüyor: depremde
"asansör", gazda "elektrik", tahliyede "terk"; güvenlik tehdidinde
**"terk edin" geçmiyor** (dışarı çıkmak riski artırır).

**Kısa tutuldu** (≤110 karakter, her dilde ölçülü): bildirim ekranında
tam okunmalı; uzun metin "..." ile kesilir ve kesilen yer tam da
talimatın olduğu yerdir.

### Kategoriye göre farklı davranış — değerlendirildi, EVET

| Kategori | Kime |
|---|---|
| Deprem, yangın, gaz, tahliye | **Tüm site** (sakinler dahil) |
| Sağlık, güvenlik tehdidi, diğer | Yönetim + güvenlik |

* **Bina geneli tehlikede herkesin yapacağı bir şey var** — bilgiyi
  yalnız görevlilere vermek, bilmesi gerekenleri dışarıda bırakmaktı.
* **Sağlık kişisel veridir**; "3. katta sağlık acili" duyurusu gereksiz
  bir ifşadır.
* **Güvenlik tehdidinde** sakinleri koridora çıkaracak bir duyuru riski
  artırır; metin zaten "yerinde kal" diyor. Yönetici gerekirse
  `yonetici_anons` ile siteye ayrıca seslenir — **o karar insanın**.

**Kategori kümeyi yalnız GENİŞLETİR, daraltmaz.** Daraltabilseydi
"sakin paniği + sağlık" gibi bir bileşke, alarmı güvenlikten de
gizleyebilir — yani çağrıyı sessizleştirebilirdi.

**Kapsam seçim anında yazılı:** kullanıcı "deprem" derken tüm siteye
seslendiğini **göndermeden önce** görür.

## §5 ÖLÇEMEDİĞİM

* **Gerçek cihazda push düşmedi** (dev'de kayıtlı cihaz yok); ölçülen
  bildirim satırı, alıcı kümesi ve metin kimliği.
* Metinlerin **resmî kurum onayı** alınmadı: yönergelerin özeti
  yazıldı, kurumlara doğrulatılmadı. Sitenin kendi acil durum planı
  farklıysa metinler gözden geçirilmeli.
* Drawer'daki SOS **gerçek telefonda** denenmedi (emülatör yok).

---

# §4 — WEB'DE GÖRÜNÜM MODU

## §4.1 Neden token ölçekleme (zoom değil)

`zoom` ya da köke büyük bir `font-size` vermek, piksel cinsinden yazılmış
her ölçüyü (kenarlık, gölge, ikon) olduğu gibi bırakır: **metin büyür,
kutu büyümez, taşma olur.**

Ölçeklenen şey **tipografi token'ları** (`--yz-fs-*`) ve satır yüksekliği.
Menü, tablolar, form etiketleri ve düğmeler zaten bu token'lardan
çizildiği için **birlikte** büyüyor — tek tek büyütmek, yeni bir bileşende
unutulacak bir adım bırakırdı. Dokunma/tıklama hedefleri de büyük modda
52 px'e çıkıyor.

## §4.2 Oran 1.25 — mobildeki 1.3 değil

Mobilde 1.3 seçilmişti çünkü orada ızgara karo sayısı da azalıyor
(`izgaraKaroSiniri`). Web'de tablo sütunları sabit; 1.3 ile 24 px'lik
`h1` 31 px'e çıkıyor ve dar bir ekranda sayfa başlığı **iki satıra
sarıyor**. 1.25 aynı okunabilirlik kazancını veriyor, sarmayı önlüyor.

Bu mod tarayıcı yakınlaştırmasının **yerine geçmez, onunla birlikte
çalışır**; WCAG 1.4.4 zaten %200'e kadar bozulmamayı istiyor ve bu mod
onun altında bir adım.

## §4.3 Kontrast (WCAG AA)

**Renk token'larına dokunulmadı.** Büyük mod yalnız ölçü değiştiriyor;
kontrast oranları P160'ta ölçülmüş hâliyle duruyor ve ikisi birbirinden
bağımsız kalıyor. Kilit bunu ayrıca ölçüyor: `:root.yz-buyuk` bloğunda
hiçbir renk değişkeni tanımlanamaz.

## §4.4 Üç katman, her birinin nedeni

| Katman | Neden |
|---|---|
| **Hesap** (`app_user.ui_gorunum`, göç 0147) | Başka tarayıcıda da aynı görünüm. `ui_tema` ile aynı gerekçe (göç 0076). |
| **Çerez** | SSR ilk karede sınıfı basabilsin. Çerez olmasaydı sayfa önce **küçük** çizilir, sonra büyürdü — tam da bu ayara ihtiyaç duyan kullanıcıyı bir kare boyunca okuyamaz bırakırdı. |
| `localStorage` **yok** | Tema'da geriye dönük uyum için duruyor; burada böyle bir miras yok ve üçüncü bir kaynak "hangisi doğru" sorusunu üçüncü kez sordururdu. |

## §4.5 Mobildeki ayarla aynı mantık

Aynı ad ("Görünüm modu"), aynı iki seçenek ("Standart / Büyük"), aynı
davranış. Ayar **profil sayfasının hesap bölümünün en üstünde**: bu ayarı
arayan kişi tam da arayüzü okuyamayan kişidir; onu sayfanın altına
koymak, bulması için önce okumasını istemek olurdu.

**Fark (bilinçli):** mobilde değer cihazda duruyor, web'de hesapta. Mobil
uygulamada hesap tek cihaza bağlı kullanılıyor; web'de aynı hesap birden
çok tarayıcıda açılıyor.

## §4.6 ÖLÇEMEDİĞİM

* **Gerçek tarayıcıda görsel doğrulama yapılmadı** — jsdom CSS
  değişkenlerini hesaplamaz. Bu yüzden kilit, CSS dosyasını **kaynak
  olarak** okuyup token'ların gerçekten büyüdüğünü ve renk token'larına
  dokunulmadığını ölçüyor; **piksel düzeyinde taşma olmadığı gözle
  doğrulanmalı.**
* **Kontrast oranı yeniden ölçülmedi**: renk token'larına dokunulmadığı
  için P160'taki ölçüm geçerli sayıldı.

---

# §3 — İÇE AKTARIM: TABLO DOLDURMA

## §3.0 ÖLÇÜM: bugün kaç tür var

**Dört:** `daire`, `kisi`, `acilis_bakiye`, `arac`.

Yönetici aynı insan için **iki dosya** hazırlıyordu (kişiler + plakalar) ve
ikincisinde daire numarasını **tekrar** yazıyordu. Aynı şekilde daire ve
sakin ayrı dosyalardaydı.

## §3.1 Üçe indirildi — birleştirerek, silerek değil

| Yeni tür | Ne katlandı |
|---|---|
| **Kişiler** (`kisi`) | `arac` türü buraya: `plaka`, `arac_marka`, `arac_model` sütunları. |
| **Daireler ve sakinler** (`daire`) | Sakin sütunları: `sakin_ad`, `sakin_eposta`, `sakin_telefon`, `rol_tipi`. |
| **Açılış bakiyeleri** | Değişmedi. |

**`arac` kodu silinmedi:** `ice_aktarim` geçmişinde `tur='arac'` satırlar
var ve göç CHECK'i onları tutuyor. Kodu düşürmek **geçmiş kayıtları
okunamaz** kılar ve geri alınamaz hâle getirirdi. Yalnızca yeni
aktarımlarda seçilemiyor.

Bu yüzden `test_turler_GOCLE_AYNI` kilidi **eşitlikten alt kümeye**
çevrildi: kusuru üreten yön tektir — routerda olup CHECK'te olmayan tür
500 verir. Ters yön (CHECK'te kalan eski değer) zararsızdır ve
**gereklidir**.

**Sakin sütunları boş bırakılabilir:** boş daire de bir gerçektir. Hata
yalnız **yarım** doldurulmuş satırda üretilir (ad var e-posta yok gibi) —
sessizce yarım kişi yaratmak, sahiplenilemeyen bir hesap bırakırdı.

**Kod tekrarı yok:** daire satırındaki sakin, `_uygula_kisi`'nin
**kendisini** çağırır. Ad/e-posta doğrulama, davet gönderimi, rol eşleme
ve daire bağı orada yazılı; ikinci bir kopya, birinde düzeltilen kuralın
ötekinde eskimesi demekti.

**Kendi kusurumu ölçtüm:** kuru koşumda daire henüz yazılmadığı için
sakin satırı "daire bulunamadı" hatası veriyordu ve P193 kuralı gereği
**tüm aktarım iptal oluyordu** — özellik kendi kendini engelliyordu.
`daire_hazir` bayrağıyla düzeltildi.

## §3.2 Tablo — sütunları hazır, yapıştırılabilir

Ölçülen sürtünme: yönetici kendi Excel'ini **bizim şablonumuza
uyduruyor**, yüklüyor, sonra **kolon eşlemesi** yapıyordu. Yani önce
dosyasını değiştiriyor, sonra da hangi sütunun ne olduğunu bize
anlatıyordu.

Yeni ekranda sütunlar zaten bizim: **eşleme adımı yok**.

* **Yapıştırma en kritik özellik.** Excel bloğu TSV'dir; yapıştırma
  **odaklanan hücreden** başlar ve sağa/aşağı yayılır (Excel'in kendi
  davranışı). Satır yetmezse **tablo büyür** — "önce 50 satır ekleyin"
  demek, işi kullanıcıya geri vermekti.
* Satır ekleme/silme, tabloyu temizleme.
* Zorunlu sütunlar **başlıkta** işaretli (altta bir açıklama satırı,
  kaydırınca ekrandan çıkardı).
* Hatalı hücre **anında belirgin** (kenarlık) **ve** satır numarası
  kırmızı **ve** altta cümlesi yazılı — renk tek başına anlam taşımıyor.
* Boş satırlar gönderilmeden atılır: tablo beş boş satırla açılıyor.

**Dosya kipi kaldırılmadı.** Elinde zaten uygun bir dosya olan
kullanıcının yolunu kapatmak, bir sorunu çözerken bir başkasını
üretmekti. Örnek şablon indirme de duruyor (P234).

**Kilit gerçek bir kusur yakaladı:** "Önizle"/"Aktar" düğmeleri eşleme
kartının **içindeydi**; tablo kipinde eşleme kartı çizilmediği için
düğmeler de çizilmiyordu — yani yeni kip tek başına **kullanılamazdı**.
Düğmeler kendi kartına taşındı.

## §3.3 Mobil — bilinçli ayrım (P204)

Tablo mobilde **yok**. 200 satırlık bir önizlemeyi telefonda doğrulamak
mümkün değil. Ama **sessiz de bırakılmadı**: sakinler ekranının boş
durumunda "toplu aktarım bilgisayardan yapılır" satırı görünüyor —
yoksa yönetici tek tek eklemeye başlardı.

## §3.4 YAN BULGU: `/arama` ucu kırıkmış

Plakalı bir satır yazınca ortaya çıktı: `routers/arama.py` plaka vuruşunu
`kaynak="arac"` diye üretiyor ama `AramaVurusu.kaynak` Literal'i onu
tanımıyordu → **araç kaydı olan her tesiste plakayla arama 500
veriyormuş.** P243'ten eski bir kusur; düzeltildi.

## §3.5 ÖLÇEMEDİĞİM

* **Gerçek bir Excel'den gerçek tarayıcıya yapıştırma** denenmedi; jsdom
  pano olayı taklit ediliyor. Ölçülen: TSV çözümleme, hücre doldurma,
  tablo büyütme.
* Davet e-postalarının **gerçekten gittiği** ölçülmedi (dev'de gönderim
  kapalı); ölçülen, davet sayacının arttığı.
