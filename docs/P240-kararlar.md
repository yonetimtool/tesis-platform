# P240 — PANİK BUTONU + DİYAFON + AKILLI EV + üç düzeltme

Sıra: §5 → §1 → §4 → §2 → §3 (kullanıcının verdiği sıra).

---

## §5 — Üç küçük düzeltme

### (a) "Yeni vardiya" düğmesi görünmüyordu

**Ölçüm:** düğme görünüm seçici + filtreler + tazele ile **aynı
sarılabilir satırdaydı** ve hepsi `ikincil` (gri) olduğu için aralarında
kayboluyordu; dar ekranda alt satıra sarıyor ve hiç görünmüyordu.

**Karar — iki şey birden değişti, ikisi de gerekli:**
- **Yer:** gezinme/görüntüleme araçlarıyla aynı kümede değil. Bu bir
  *görünüm seçimi* değil, *kayıt oluşturma*. Artık başlık satırının
  sağında, tarih gezinme kümesinin sonunda.
- **Renk:** `birincil` (mavi dolgu, `--yz-metal-accent`). Bir ekranda tek
  birincil düğme olur; o da budur. Yanındaki araçlar gri **kaldı** —
  "hepsini mavi yap" değil, birini öne çıkar.

Şablon bölümünün "Yeni şablon" düğmesi de birincil, ama sayfanın
**altında**, kendi bölüm başlığının yanında; ikisi aynı ekran alanında
yan yana görünmüyor. P239 §2'de etiketleri ayırmıştık, artık görsel
ağırlık da ayrı.

### (b) Mobil devriye planında vardiya alanı — **ZATEN VAR**

P239 §3'te (`2775f2e5`) eklenmişti: `devriye-vardiya` seçici,
`patrol_plan_api`de `shiftId` alanı, taklit HTTP adapter üzerinden beş
kilit. Bu turda **tekrar yapılmadı**; doğrulandı.

### (c) Görev tarihi takvimden — ve iki ekran AYNI takvime eşitlendi

**Ölçüm: web'de gün seçimi iki farklı şekilde yapılıyordu.**

| Yer | Nasıl |
|---|---|
| Vardiya ekleme modalı | elde çizilmiş gün şeridi — sarılabilir düğme yığını, **haftaya hizalı değil**, hücre 36px |
| Görev formu | `<input type="datetime-local">` — **tarayıcının kendi takvimi**, her tarayıcıda başka görüntü |

Mobildeki `GunTakvimi` ise bir **ay ızgarası** (7 sütun, haftaya hizalı).
Yani "mobildeki gibi" olan hiçbiri değildi.

**Karar:** ortak `admin-web/components/ui/ay-takvimi.tsx` (`AyTakvimi`).
Her iki yer de onu kullanıyor.
- **Hafta pazartesi başlar (ISO-8601)** — P239 §4'te devriye günleri için
  seçilen numaralandırmayla aynı; "pazartesi" iki ekranda aynı sütuna
  denk gelsin.
- **Gün adları sözlükten değil yerelden** (`Intl.DateTimeFormat`):
  7×7 = 49 yeni anahtar eklemek yerine (mobildeki `gun_takvimi.dart` ile
  aynı karar).
- **Hücre 44px** (2.75rem) — tasarım sisteminin dokunma hedefi. Eski
  şerit 36px'ti; o bir dokunma hedefi değil, yoğun-bağlam ölçüsü.
- **Ay gezinme** görev formunda var (ileri/geri). Düzenlemede takvim
  **görevin ayına atlar**; atlamazsa başka aydaki son tarih için takvim
  boş görünür ve kullanıcı "tarih silinmiş" sanır.
- **Gün + saat ayrı.** Gün tek başına yetmez. **Saat verilmezse gün sonu
  (23:59)** — "tarih verdim ama saat vermedim" = "o günün sonuna kadar";
  00:00 almak işi daha başlamadan gecikmiş yapardı.
- **Aynı güne ikinci tıklama seçimi kaldırır** — son tarihi silmenin
  başka yolu yok.
- **Geçmiş gün seçilebilir** kalır: kapatmak, dün bitmesi gereken bir işi
  sisteme girmeyi imkânsız kılardı (gecikme raporu tam bunun için var).

### KİLİTLER

`admin-web/tests/p240-kucuk-duzeltmeler.dom.test.ts` (5) — düğme birincil
ve komşuları hâlâ ikincil, gezinme kümesinin dışında; görev formunda ay
ızgarası var ve eski `datetime-local` **kalmadı**; vardiya modalı ile
görev formu aynı bileşeni kullanıyor (7 sütunlu ızgara imzası); geçmiş
gün kapalı değil.
`p239-gorev-son-tarih.dom.test.ts` yeni etkileşime göre yeniden
yazıldı (+2 test: gün sonu kuralı, ikinci tıklamayla silme).

**KIRMA:** düğme `ikincil`e çevrildi → 1 kırmızı. Geri alındı.

**Testin kendi hatası düzeltildi:** ilk yazımda ISO dizesinde
`"2026-09-20"` aranıyordu; test ortamının saat dilimi UTC-4 olduğu için
yerel 23:59 **ertesi günün** UTC damgası oluyor ve test kırmızı döndü —
doğru olarak. Ölçüm, değerin **yerel** olarak 20 Eylül 23:59'a denk
gelmesine çevrildi. (P239'daki 17:30 bu tuzağı gizlemişti.)

---

## §1 — PANİK BUTONU

### ÜÇ AYRI TİP — ve kim hangisini tetikler

| Tip | Kim tetikler | Kime gider |
|---|---|---|
| `sakin` | **yalnız `resident`** | güvenlik + amir + yönetim |
| `guvenlik` | security, amir, tesis görevlisi, yönetici, admin | **diğer** güvenlik + amir + yönetim |
| `yonetici_anons` | yönetici, admin | **tesisteki herkes** |

**Yönetici hepsini görebilir mi? HAYIR — ikisini görür.** `sakin` tipi
daire bilgisiyle anlamlıdır ("hangi daireye gidilecek"); yöneticinin
dairesi yoktur ve tetiklediği bir "sakin paniği" alıcılara **gidecek
adres taşımayan** bir alarm olurdu. Sahada saldırı gören yöneticinin
doğru düğmesi `guvenlik` ve o ona açık.

**Tetikleyen kendi alarmının alıcısı değildir:** kendi telefonunda çalan
alarm ona yeni bir bilgi vermez ve "kim gördü" ölçüsünü kirletirdi.

**Denetçi hiçbirini görmez** — salt-okuma mali gözetim rolü, sahada değil.

### İPTAL PENCERESİ: satır önce, bildirim sonra

`POST /panik` alarm satırını **hemen** yazar (`beklemede`) ve bildirimleri
**5 saniye sonraya** planlar (Celery `countdown`).

- Satırı önce yazmak, **iptal edilen alarmın bile denetim kaydında
  kalmasını** sağlar. "Bastım, vazgeçtim" bir olaydır; kaydı silmek
  suistimali görünmez kılardı.
- Bildirimi geciktirmek, iptalin gerçekten **hiçbir şeyin gitmemesi**
  anlamına gelmesini sağlar. Önce gönderip sonra "iptal" demek, alıcının
  telefonunda çalmış bir alarmı geri alamaz.
- **Geri sayım istemcide, yayın sunucuda.** Sayım bitince istemci
  **hiçbir şey yapmaz**. Yayını "sayım bitince ikinci istek at" diye
  kurmak, tam da acil durumda en kırılgan şeye (sekmenin/uygulamanın
  ayakta kalmasına) bağımlı olurdu. İki yüzeyde de test bunu ölçüyor.
- **5 saniye neden:** yanlışlıkla basanın fark edip geri almasına yeter;
  gerçek acilde kaybedilen süre kabul edilebilir sınırı aşmaz. 15 sn
  alarmı geciktirir, 2 sn "basmadan önce düşün" demenin başka yolu olur.
- **Broker yoksa senkron yayın:** iptal penceresi kaybedilir ama **alarm
  gider**. Tersi (broker yoksa alarm hiç gitmesin) bir güvenlik
  özelliğinde kabul edilemez — pencere bir kolaylık, alarm işin kendisi.

`iptal` (pencere içinde, kimse rahatsız edilmedi) ile `yanlis_alarm`
(pencere sonrası, edildi) **ayrı durumlar**: tek duruma indirmek
suistimal ölçümünü kör yapardı. İkincisinde alıcılara **düzeltme
bildirimi** gider — sahaya koşan kişiyi geri çağırmak, alarmın kendisi
kadar zaman-kritiktir (bu yüzden o da **kritik push kanalında**).

**İptal yalnız basana ait.** Başkasının alarmını iptal etmek, gerçek bir
acili susturmanın en kolay yolu olurdu. Yönetim **kapatır** — kapatma
"sonuçlandı" demektir, "hiç olmadı" değil.

### TAKİP — bu olmadan sistem işe yaramaz

`panik_alici` tablosu: kime bildirildi, kim gördü, kim "gidiyorum" dedi.
`notification` bunu taşıyamaz — o bildirimin kendisidir; burada ölçülen
**alarma verilen insan tepkisi**. Müdahale süresi **sunucuda** hesaplanır
(`gonderildi_at` → ilk "gidiyorum"): iki damganın farkını istemcide
hesaplamak, saati kaymış bir cihazda negatif süre üretirdi. Kapanış:
kim kapattı + not. Beş ayrı denetim eylemi (`PANIK_TETIK`, `_IPTAL`,
`_GORULDU`, `_MUDAHALE`, `_KAPAT`) — tek bir "panik" eylemi, kaydı "bir
şey oldu" seviyesine düşürürdü.

**"Gördüm" dedikten sonra tam ekran uyarı geri gelmez** (`/panik/aktif`
görülenleri eler); kapatılamaz bir uyarıyı sonsuz bir engele çevirmek
olurdu. Alarm takip listesinde durmaya devam eder.

### SUİSTİMAL: reddetme YOK, tekrar duyuru VAR

Aynı kişinin aynı tipte **açık** alarmı varken tekrar basması **yeni
alarm üretmez**; var olanı yeniden duyurur (30 sn'den sıksa duyurmaz).

Gerekçe: gerçek acil durumda ikinci kez basan kişi "duyulmadı" diye
düşünüyordur. İsteği **reddetmek** ("çok sık bastınız") tam o anda alarmı
susturmak olurdu. Tekrar duyurmak hem kullanıcının niyetini karşılar hem
de yirmi ayrı alarm satırı üretmez. **Hiçbir koşulda 429 dönmüyoruz.**

İkinci katman **bilgi**: alıcı, tetikleyenin son 24 saatteki iptal/yanlış
alarm sayısını görür (`son_24s_yanlis_alarm`). Engel değil bağlam —
gidenin ne bekleyeceğini bilmesi için. Sayaç yüksek olsa bile müdahale
düğmeleri açık kalır (web testi bunu ölçüyor).

### YETKİ ASKISI: evet, ama süreli ve gerekçeli

`PATCH /users/{id}/panik-aski` (admin + yönetici). `bitis` **zorunlu**,
geçmiş tarih **reddedilir**, **kendini askıya alamazsın**.

- Süresiz askı = unutulan askı; unutulan askı gerçek bir acil durumu
  **sessizce yutar**.
- Askıdayken alarm **satır olarak yazılır**, bildirim gitmez: basmaya
  devam etmesi, askının gerekçesini doğrulayan ya da **çürüten** bir
  ölçümdür.

### KANALLAR

| Kanal | Durum |
|---|---|
| In-app bildirim | ✅ kalıcı kayıt |
| Push (**kritik kanal**, sesli) | ✅ `panik_alarm` + `panik_yanlis_alarm` kritik; `panik_kapandi` değil (koşarak yapılacak bir şey kalmamıştır) |
| SMS | ✅ **kod yazıldı**, Verimor başlık onayı gelince açılır |
| Tam ekran alarm | ✅ iki yüzeyde |
| Kamera işareti | ✅ `camera_id` + `kayit_an` |
| Sesli robot arama | ❌ **yazılmadı** — değerlendirme aşağıda |

**SMS yalnız saha+yönetim rollerine.** `yonetici_anons` tüm siteye push
atar ama **SMS atmaz**: 300 daireye SMS hem maliyet hem sağlayıcı hız
sınırı demektir; anonsun hedefi zaten "uygulaması açık olan herkes".
Başlık onayı gelmeden Verimor sağlayıcısı `basarisiz` döner ve bu
**doğru** davranıştır — gönderilmemiş bir SMS'i "gönderildi" yazmak,
hukuki bir kanıtı uydurmak olurdu.

**Kamera işaretleme = işaret, kopya değil.** Kayıtlar NVR'da durur
(P213); alarma kamera + an yazılır, oynatma mevcut
`/cameras/{id}/kayit/oynat` ucundan yapılır. Saatlerce video indirip
saklamak, bir alarm için depolama ve yasal saklama yükü üretirdi.

### SESLİ ROBOT ARAMA — DEĞERLENDİRME (bu turda yazılmadı)

| Sağlayıcı | Not | Yaklaşık maliyet |
|---|---|---|
| **Netgsm Sesli Arama** | Türkiye'de yerleşik, mevcut SMS sağlayıcımızla aynı çatı; sesli mesaj (IVR) API'si var | dakika/adet bazlı, ~0,20–0,50 ₺ mertebesi |
| **Verimor Sesli** | SMS'te zaten kullandığımız sağlayıcı; sesli ürünü var | benzer mertebede |
| **Twilio Programmable Voice** | Olgun API, TR numarası ve regülasyon (BTK) gereksinimi var | USD bazlı, ~$0,02–0,04/dk + numara ücreti |
| **Vonage / Infobip** | Kurumsal, TR erişimi var | Twilio mertebesinde |

**Öneri:** Netgsm ya da Verimor — sebep maliyet değil, **tek sağlayıcı
çatısı**: SMS başlığı, fatura ve destek zaten oradan yürüyor; ikinci bir
yabancı sağlayıcı BTK/KVKK tarafında ayrı bir sözleşme demek.

**Neden bu turda yazılmadı:** sesli arama, bu turda ölçemeyeceğimiz bir
zincir ekler (numara doğrulama, IVR akışı, meşgul/cevapsız durumları,
tekrar deneme politikası). Daha önemlisi: SMS başlığı **henüz onaylı
değil** ve sesli arama da aynı operatör onay sürecine bağlı. Onay
gelmeden yazılacak kod, çalıştığı doğrulanamayan koddur.

### YASAL SINIR

Metin: **"Bu sistem 112 / 155 / 110 yerine geçmez. Hayati tehlikede önce
resmî acil hatları arayın."**

**Nerede gösteriliyor:** panik düğmelerinin **üstünde**, her açılışta,
tehlike renginde — ikisi de bilinçli. Küçük yazıya almak ya da bir kez
gösterip bir daha göstermemek, hukuken "bildirildi" saymak için yeterli
olsa bile **okunmasını** sağlamazdı. Alarm basıldıktan sonra göstermek
ise en kritik anda okunmamak demekti.

**Ek öneri (yapılmadı, kullanıcı kararı):** aynı metnin tesis sözleşmesi
/ KVKK aydınlatma metnine de girmesi. Bu bir ürün kararı değil, tesisle
yapılan sözleşmenin konusu.

### ÖLÇÜLENLER

**Backend (21 test, `test_p240_panik.py`):** üç tipin doğru alıcılara
gitmesi ve yanlış role gitmemesi; yöneticinin sakin paniğini
tetikleyememesi; tetikleyenin alıcı olmaması; iptal penceresinde iptal →
**sıfır alıcı** (gecikmeli görev sonradan koşsa bile yayın yapmıyor);
gönderildikten sonra iptal → `yanlis_alarm` + alıcılar kayıtlı;
başkasının alarmını iptal edememe; gördüm/müdahale/kapat + süre; alıcı
olmayanın "gördüm" diyememesi; `/panik/aktif`in `beklemede` ve
görülenleri elemesi; sakinin listede yalnız kendi alarmlarını görmesi;
tekrar basmanın **asla reddedilmemesi** ve yeni alarm üretmemesi; yanlış
alarm sayacı; askının bildirimi kesip satırı yazması; askının geçmiş
tarih/kendine reddi; GPS'te tek başına enlemin reddi; konumsuz alarmın
yine de gitmesi.

**KIRMA:** (1) `yayinla_senkron`daki iptal kontrolü kaldırıldı → iptal
testi kırmızı; (2) askı kontrolü kaldırıldı → askı testi kırmızı.

**Web (12 test) ve mobil (12 test):** rol kapısı (dört rol), yasal
uyarının düğmelerden önce gelmesi, geri sayım + iptal isteği, **sayım
bitince ikinci istek atılmaması**, tam ekran alarmın kapatma düğmesi
taşımaması / geri tuşuyla kapanmaması, gidiyorum isteği, telefonun
dokunulabilir olması, yanlış alarm sayacının engel olmaması.

**KIRMA:** rol süzgeci kaldırıldı → web'de 4, mobilde 3 test kırmızı;
`canPop: true` → geri tuşu kilidi kırmızı.

### MOBİLDE NEREDE DURUYOR — ve neden

**Üst barda, her sekmede, tek dokunuş** (`_PanikButonu`, kırmızı dolgu +
"ACİL" yazısı, 48 dp dokunma hedefi).

| Aday | Neden değil |
|---|---|
| Alt çubukta 6. yuva | Çubukta beş yuva var; 320 dp'de altıncı ~53 dp'ye düşürür ve **48 dp dokunma hedefi kilidi (P220) kırılır** |
| Ayrı yüzen düğme | Çubuğun ortasında zaten bir FAB ("+") var; ikincisi onunla yarışır ve içeriği kapatır |
| Ana ekranda sabit kart | Yalnız ana ekranda olurdu; başka sekmedeyken önce ana sekmeye dönmek gerekirdi |

**Simge tek başına değil** — yanında "ACİL" yazıyor (P237 kuralı).

**Tam ekran alarm `MaterialApp.builder` zincirinde** (`SurumKapisi`nin
altında): çizilen her ekranın üstüne geçer. Tek bir ekrana koymak,
kullanıcı başka ekrandayken alarmı kaçırması demekti. Navigator
kullanılmıyor — builder Navigator'un üstündedir ve orada `showDialog`
"No Navigator" hatası verir (P237'de ölçüldü); bu yüzden uyarı bir
diyalog değil, ağaca giren bir **katman**.

**Webde her sayfadan:** düğme `(protected)/layout.tsx` içinde, yani
korumalı alanın tamamında. Rol **sunucuda** çözülmüş halde geçiyor;
istemciden `/api/me` beklemek, düğmeyi bir kare boyunca yanlış role
göstermek ya da hiç göstermemek demekti.

### ÖLÇEMEDİĞİM

- **Gerçek cihazda push'un çaldığı** sürülmedi (emülatör yok, FCM
  gönderimi dev'de `PUSH_PROVIDER` ayarına bağlı). Ölçülen: doğru
  kimliğin doğru kullanıcı kümesine, kritik kanalla gönderilmek üzere
  `dispatch_external`a verildiği.
- **SMS gerçekten gitmiyor** — başlık onayı yok. Ölçülen: sağlayıcı
  seçiminin çağrıldığı ve hatanın alarmı düşürmediği.
- **İptal penceresinin süresi** otomatik ölçülemiyor: testler canlı
  sunucuya gidiyor (monkeypatch yok) ve Celery worker koşmuyor, yani
  `countdown` değeri bir akış testiyle gözlenemiyor. Bunu "ölçülüyor"
  gibi göstermek yerine **kaynak düzeyinde kilit** konuldu (ilk yayın
  `IPTAL_PENCERESI_SN` ile planlanmalı; çıplak sayı yazan bir değişiklik
  pencereyi sessizce yok ederdi).
