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
