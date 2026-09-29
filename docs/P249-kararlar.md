# P249 — SOS alarm deneyimi, tatbikat modu, güvenlikten daireye ulaşma

Bu belge P249'un kararlarını, ölçümlerini ve **ölçülemeyenlerini** tutar.
Bu turun kuralı: bir maddeye "geçti" demek için gerçek akış sürülmüş
olmalı. Sürülemeyen her halka ayrıca **ÖLÇÜLEMEDİ** diye yazılır.

---

# §1 — ÖLÇÜM: SOS ZİNCİRİ NEREDE KOPUYOR

Kod değiştirilmeden, zincir halka halka izlendi (dev ortamı, 2026-09-29).

## Halka 1 — Seçilen kategori sunucuya ulaşıyor mu? **EVET**

* Mobil `panik_sayfasi.dart` kategoriyi `POST /panik` gövdesinde
  `kategori` olarak gönderiyor (`p243_panik_kategori_test.dart` bunu
  ölçüyor).
* Sunucu `PanikOlustur.kategori` alanını 7 değerli bir kümeyle
  doğruluyor ve `panik_alarm.kategori` sütununa yazıyor (göç 0146).
* **Ama kategori ZORUNLU DEĞİL** (P243 kararı: "acil durumda seçime
  zorlamak alarmı geciktirir"). Kategorisiz basılan alarm eski genel
  metinle gidiyor. Cihazda görülen "ACİL DURUM ÇAĞRISI" ekranı iki
  durumda da aynı çıkıyor (halka 4), bu yüzden cihazdaki ekrandan
  kategorinin seçilip seçilmediği anlaşılamaz.

## Halka 2 — Push içeriğinde kategori ve talimat var mı? **KISMEN — ve bir kusur**

* Metin kimliği kategoriden türüyor: `panik_kategori_<k>`. Başlık
  kategori adı ("DEPREM"), gövde talimat ("Çök, kapan, tutun…").
  `data` içinde `panik_kategori` gidiyor.
* **KUSUR — yardım çağrısında KİM ve NEREDE kayboldu.** P240'ın
  `panik_alarm` metni "{ad} yardım istedi — {yer}" idi. P243 kategori
  metinlerini yazarken şablonu **parametresiz** yaptı: `saglik`
  bildirimi "Sağlık acili. 112 arandı mı kontrol edin…" diyor ama
  **hangi dairede olduğunu söylemiyor**. Güvenlik görevlisi
  bildirimden nereye koşacağını öğrenemiyor. Aynı kusur
  `guvenlik_tehdidi` ve `diger` için de geçerli.
* Başlıkta "ALARMI" yok ("DEPREM"); istenen biçim "DEPREM ALARMI".

## Halka 3 — Push gerçekten gönderiliyor mu? **DEV'DE HAYIR (yapılandırma), PROD ÖLÇÜLEMEDİ**

`push_gonderim` teşhis tablosu (dev) — `panik*` satırları:

| kimlik | sonuç | adet |
|---|---|---|
| `panik_kategori_yangin` | `yapilandirilmadi / kimlik_yok` | 8 |
| `panik_kategori_guvenlik_tehdidi` | `yapilandirilmadi / kimlik_yok` | 3 |
| diğer tüm `panik_*` | `hedef_yok / cihaz_yok` | 18 |

* Dev'de `PUSH_PROVIDER=fcm` ama servis hesabı dosyası yok, yani dev
  **hiçbir koşulda gerçek push gönderemez**. P243'teki bütün SOS
  ölçümleri bu ortamda yapıldı.
* **Prod'daki gerçek sonuç bu makineden ÖLÇÜLEMEDİ** (prod'a SSH yok).
  Ölçmek için prod veritabanında salt okunur sorgu:
  `docs/P249-sos-teshis.sql`. Sorgu son SOS'un her alıcısı için
  şunları gösterir: cihaz kaydı var mı, `bildirim_mobil` ve
  `bildirim_sesi` tercihi, push sonucu ve FCM hata kodu.

**Koddan okunan iki gerçek kopukluk (prod'da da geçerli):**

1. **Mobil bildirimi kapatmış kullanıcıya SOS push'u HİÇ gitmiyor.**
   `_push_to_devices` her bildirimde `u.bildirim_mobil = true`
   koşulunu uyguluyor, SOS dahil. "Duyuru bildirimlerini kapattım"
   diyen biri deprem alarmını da kapatmış oluyordu.
2. **Sesli uyarıyı kapatmış kullanıcıya SOS SESSİZ kanaldan gidiyor.**
   `kanal_sec(sesli=False)` kritik tipleri de `yonetio_sessiz_v2`
   kanalına (IMPORTANCE_LOW) yolluyordu. Bu kanal ekranın üstünde
   belirmez ve ses çıkarmaz; bildirim yalnız bildirim çekmecesine
   düşer. Kullanıcının gözünde bu "bildirim gelmedi" demektir.

**Kanal ve ses:** SOS, sıradan şikâyet ve vardiya hatırlatmalarıyla
**aynı** `yonetio_kritik_v2` kanalından ve aynı sesle gidiyordu.
Kanalın ses türü `USAGE_NOTIFICATION`: telefon sessizde veya titreşimde
**çalmaz**, Rahatsız Etmeyin açıkken **susturulur**. Ayrı bir alarm
sesi yoktu.

**iOS:** `interruption-level: time-sensitive` gönderiliyor ama
`Runner.entitlements` içinde Time Sensitive yetkisi **yok**. Yetki
olmadan iOS bu alanı yok sayar ve bildirim Odak modunda gizlenir.
Critical Alerts yok (Apple onayı gerekiyor).

## Halka 4 — Alıcı ekranı hangi şablonu çiziyor? **SABİT ŞABLON, KATEGORİYİ OKUMUYOR**

* Mobil `PanikAlarm` modelinde **`kategori` alanı hiç yok**
  (`panik_models.dart`). Sunucu `kategori` döndürüyor ama istemci
  JSON'dan okumuyor.
* `PanikAlarmKatmani` (tam ekran) sabit başlık `panikGelenAlarm`
  ("ACİL DURUM ÇAĞRISI"), ad, yer, yanlış alarm sayacı, telefon ve
  Gidiyorum/Gördüm çiziyor. Kategori ve talimat yok; deprem ile
  sağlık acili aynı ekranı alıyor.
* Web'deki gelen alarm katmanı (`components/panik/panik-alarmi.tsx`)
  ve `/panik` takip sayfası da kategoriyi göstermiyor.
* **Yanlış alarm sayacı herkese gidiyor.** `_govde()` sayacı izleyenin
  rolüne bakmadan dolduruyor. Deprem alarmında sakin de "son 24 saatte
  2 yanlış alarm" görüyor.
* Bildirime dokununca `panik-takip` listesi açılıyor. Sakin bu
  listede yalnız **kendi açtığı** alarmları görür; deprem alarmına
  dokunan sakin boş bir liste görüyordu.

## Halka 5 — Uygulama kapalı / arka planda / kilit ekranında **ÖLÇÜLEMEDİ**

Bu makinede bağlı telefon ve emülatör yok. Kodun söylediği:

* Push `notification` gövdesiyle gidiyor. Android bunu uygulama
  kapalıyken de sistem tepsisine düşürür (uygulama "zorla
  durdurulmadıysa"). Kilit ekranında `visibility=PUBLIC`.
* Sistemin çizdiği bildirim **tam ekran açamaz, sesi döngüye alamaz,
  "Gördüm" deyince susmaz**. Bunlar ancak bildirimi uygulamanın kendisi
  kurarsa mümkün (§1c kararı).
* Bazı üreticiler (Xiaomi, Huawei, Oppo) uygulamayı son kullanılanlar
  listesinden kaydırmayı "zorla durdurma" sayar. Bu durumda FCM mesajı
  uygulama yeniden açılana kadar **hiç teslim edilmez**. Sunucu
  tarafında buna çare yok; cihazda "pil optimizasyonu dışında tut"
  ayarı gerekir.

## P243 kriter 15 neden "geçti" raporlandı — neyi ölçmüştüm, neyi ölçmemiştim

**Ölçtüklerim:**

* `test_p243_panik_kategori.py` (sunucu): her kategorinin kendi metin
  kimliği var, 7 dilde metin var, ≤110 karakter, deprem tüm siteye
  gidiyor, sağlık sakine gitmiyor, kategorisiz alarm eski metni
  kullanıyor. Hepsi **`notification` tablosuna yazılan satırı**
  ölçüyor.
* `p243_panik_kategori_test.dart` (mobil): kategori seçimi tetiklemeden
  önce çiziliyor ve **gönderilen istek gövdesinde** kategori var.

**Ölçmediklerim:**

1. **Alıcı tarafı.** Hiçbir test "alarmı ALAN kişinin ekranında kategori
   görünüyor mu" diye sormadı. Sorsaydı mobil modelde alanın olmadığı
   ilk koşumda görülürdü. Test **gönderen** ucu ve **veritabanını**
   ölçtü; aradaki ekranı ölçmedi.
2. **Push teslimi.** Dev'de FCM kimliği yok; bütün satırlar
   `yapilandirilmadi`. P243 kararlar belgesinin "ÖLÇEMEDİĞİM" başlığında
   "gerçek cihazda push düşmedi" diye yazdım. **Hata şuydu:** ölçülmemiş
   bir halkayı raporda "geçti" sayılan bir kriterin içinde bıraktım.
   "Metin doğru yazıldı" ile "alıcı metni gördü" aynı şey değildir.
3. **Bildirim tercihinin SOS'u susturması.** Tercih süzgeci P181'de
   eklenmişti ve P240/P243'te SOS'un bu süzgeçten muaf olup olmadığı
   hiç sorulmadı.

**Bu turda değişen yöntem:** her SOS kabul maddesi için test
**alıcının gördüğünü** ölçer: istemci modelinin JSON'dan okuduğu
alan, ekrana çizilen metin, push gövdesinin kendisi. Gerçek cihazda
sürülemeyen halkalar "ÖLÇÜLEMEDİ" başlığında ayrıca listelenir.

---

# §1 — DÜZELTMELER

## §1a Kapatılan kopukluklar

| # | Kopukluk (§1 ölçümü) | Düzeltme |
|---|---|---|
| 1 | Mobil bildirimi kapatan kişiye SOS push'u hiç gitmiyordu | Alarm sınıfı (`push_kanal.alarm_mi`) `bildirim_mobil` süzgecinden **muaf** |
| 2 | Sesli uyarıyı kapatan kişiye SOS sessiz kanaldan gidiyordu | Alarm sınıfı her zaman **alarm kanalından**, sesli |
| 3 | SOS, şikâyetle aynı kanal ve sesle; sessizde çalmıyordu | Yeni kanal `yonetio_alarm_v1`: `USAGE_ALARM` + `CATEGORY_ALARM` |
| 4 | Yardım çağrısı bildirimi kimin/nerede olduğunu söylemiyordu | Gövde `"{ad} · {yer} — <kısa talimat>"` |
| 5 | Alıcı modeli `kategori` alanını okumuyordu, ekran sabitti | Model + iki ayrı ekran (mobil ve web) |
| 6 | Yanlış alarm sayacı deprem uyarısında sakine de görünüyordu | Yalnız güvenlik/yönetim, yalnız yardım çağrısında |
| 7 | Toplu uyarıda sakin, sitedeki bütün alıcıların adını görüyordu | Alıcı listesi yalnız takip eden rollere ve alarmı basana |
| 8 | Push'a dokunan sakin boş bir takip listesi görüyordu | Dokunuş `/panik-alarm/<id>` ekranını açıyor |
| 9 | iOS'ta `time-sensitive` yetkisiz gönderiliyordu (yok sayılıyordu) | `Runner.entitlements` içine Time Sensitive yetkisi |

## §1b İki deneyim

**Toplu uyarı** (deprem, yangın, gaz, tahliye) tüm siteye gider. Tam
ekranın en üstünde büyük harfle kategori başlığı ("DEPREM ALARMI") yer
alır. Altında yer (tetikleyenin dairesi, yoksa tesis adı) ve saat, onun
altında **adım adım talimat** (5 adım) bulunur. Düğmeler "GÜVENDEYİM" ve
"YARDIMA İHTİYACIM VAR". "Gidiyorum" düğmesi yok.

**Yardım çağrısı** (sağlık, güvenlik tehdidi, diğer) güvenliğe ve yönetime
gider. Ekranda kategori başlığı, kim, nerede, telefon, tek cümlelik
talimat, yanlış alarm sayacı ve Gidiyorum / Gördüm yer alır.

**"Yardıma ihtiyacım var" eklendi.** Bu turun metni yalnız "Güvendeyim"
istiyordu. Önceki yapıştırılan metin ise "Güvendeyim / Yardıma ihtiyacım
var" diyordu. Depremde enkaz altında kalan ya da yaralanan kişinin
"güvendeyim" diyemeyeceği ama bir şey söylemesi gerektiği açık. Bu yüzden
ikisi de var. "Yardım" seçilince güvenliğe ve yönetime **kendi
bildirimiyle** (`panik_yardim_talebi`, alarm kanalından) gider. Bildirimde
yer, isteyenin dairesidir.

**Yanıt değişebilir.** "Güvendeyim" dedikten sonra yaralandığını fark eden
kişi "yardım"a geçebilir, yardım gelince de geri dönebilir.

**Daire bazında durum** (`GET /panik/{id}/durum`). Yalnız güvenlik, amir
ve yönetim görür. Sakin göremez, çünkü yanıt vermeyen daire boş olabilir
ve bu hem kişisel hem güvenlik bilgisidir. Sıralama: önce yardım isteyen
daireler, sonra yanıtsızlar, en son güvende olanlar. Mobilde
`/panik-alarm/<id>` ekranının altında, web'de `/panik` satırındaki "Daire
durumu" penceresinde gösterilir.

**Talimatlar tek kaynakta** (`backend/app/panik_talimat.py`). Mobil tam
ekran, web katmanı ve push başlığı aynı metni isteğin dilinde okur. Üç
sözlükte tutulsaydı bir yüzeydeki düzeltme ötekinde eski kalırdı.

### Talimat kaynakları

| Kategori | Dayanak (özetlendi, uydurulmadı) |
|---|---|
| Deprem | AFAD "Deprem Anında Yapılması Gerekenler": Çök-Kapan-Tutun; pencere ve camdan uzak durma; sarsıntı sürerken merdivene, balkona ya da asansöre yönelmeme. AFAD "Deprem Sonrası": gaz ve elektriği kapatma, hasarlı binaya girmeme, artçılar |
| Yangın | İtfaiye yangın güvenliği yönergeleri: 112, asansör yasağı, dumanda eğilerek ve ağız ıslak bezle kapalı ilerleme, kapıyı elin tersiyle yoklama, kapıları kapatma, eşya için geri dönmeme |
| Gaz | Doğal gaz dağıtım şirketlerinin kaçak talimatı ve 187 Doğal Gaz Acil: kıvılcım kaynaklarına dokunmama, havalandırma, güvenliyse vanayı kapatma, binayı terk etme, ihbarı bina dışından yapma |
| Tahliye | AFAD tahliye ve toplanma alanı yönergesi: asansör yasağı, yardıma ihtiyacı olanlara destek, toplanma alanı, izinsiz geri dönmeme |
| Sağlık / güvenlik tehdidi / diğer | Alıcı güvenlik ve yönetim: 112'yi kontrol et / 155 ve yerinde kalma yönlendirmesi / olay yerine git |

**Kurumlara doğrulatılmadı.** Metinler yönergelerin özetidir. Sitenin
kendi acil durum planı farklıysa gözden geçirilmelidir.

**Güvenlik tehdidi metni değişti.** P243'te "Bulunduğunuz yerde kalın,
kapıyı kilitleyin" yazıyordu. Bu cümle sakine hitap ediyor ama bu alarm
sakine **gitmiyor**. Alıcı güvenlik ve yönetim olduğu için metin artık
"Kendinizi riske atmayın, 155'i arayın, sakinleri yerinde kalmaya
yönlendirin" diyor. P243 testi buna göre güncellendi: "terk" kelimesi
yok, "155" var.

## §1c Alarm sesi — ne mümkün, ne değil

### Android

* **Kanal:** `yonetio_alarm_v1`, `IMPORTANCE_HIGH`, ses türü
  `USAGE_ALARM`, ses olarak sistem alarm sesi. Alarm ses akışı **zil
  modundan bağımsızdır**: telefon sessizde veya titreşimdeyken de çalar.
* **Rahatsız Etmeyin:** varsayılan Rahatsız Etmeyin ayarı "alarmlara
  izin ver" açıktır. `CATEGORY_ALARM` taşıyan bildirim bu ayarla geçer.
  Kullanıcı Rahatsız Etmeyin'de alarmları da kapattıysa kanal ancak
  **"Rahatsız Etmeyin erişimi"** verilirse deler (`setBypassDnd`). Bu
  izni uygulama isteyemez, kullanıcı sistem ayarından verir.
  Ayarlar → "SOS alarm ayarları" kartı durumu gösterir ve ilgili sistem
  ekranını açar.
* **Tam ekran:** `USE_FULL_SCREEN_INTENT`. Android 13 ve öncesinde
  kendiliğinden verilir. Android 14 ve sonrasında Google bu izni yalnız
  arama ve çalar saat uygulamalarına **otomatik** verir. Yönetio ikisi
  de değil, bu yüzden izin büyük olasılıkla kapalı gelecek. Kullanıcı
  "SOS alarm ayarları" kartından açar. **İzin kapalıyken de bildirim
  gelir**, yalnız tam ekran yerine ekranın üstünde belirir.
* **Döngülü ses, "Gördüm" deyince susar:** yerel bildirim
  `FLAG_INSISTENT` taşır. Ses kullanıcı bildirime dokunana, onu
  kaldırana ya da uygulamada karar verene kadar çalar. Karar
  verildiğinde `AlarmKanali.sustur` bildirimi kaldırır.
* **Yerel alarm yolu:** sistemin çizdiği bildirim tam ekran açamaz,
  sesi döngüye alamaz ve susturulamaz. Bu yüzden sunucu **1.8.0 ve
  sonrası** Android cihazlara SOS'u `notification` gövdesi olmadan,
  yüksek öncelikli veri mesajı olarak gönderir. Bildirimi uygulamanın
  kendi servisi (`SosMesajServisi.kt`) kurar ve Flutter motorunu
  beklemez. Daha eski sürümler eski yoldan (sistem bildirimi, alarm
  kanalı) almaya devam eder. Eşik sunucuda:
  `push_gorunum.YEREL_ALARM_SURUMU`. Mesaj ömrü 1 saattir
  (`YEREL_ALARM_OMRU`): bir saat kapalı kalmış telefona geç kalmış bir
  "deprem" alarmı düşmez; uygulama açılınca aktif alarm zaten görünür.
* **Mümkün olmayan:**
  * **Zorla durdurulmuş uygulama:** bazı üreticiler (Xiaomi, Huawei,
    Oppo) son kullanılanlardan kaydırmayı "zorla durdurma" sayar. Bu
    durumda **hiçbir FCM mesajı teslim edilmez**, eski yolda da.
    Çözüm cihazda "pil optimizasyonu dışında tut" ayarıdır.
  * **Alarm ses seviyesi sıfırsa** çalmaz.

**Play Console "Tam ekran amacı" beyanı.** Politika → Uygulama içeriği
bölümünde, Android 14'ü hedefleyen ve bu izni bildiren uygulamalardan
isteniyor. Formun seçeneklerini bu makineden göremedim. Beklenen yapı
şöyle: uygulamanın temel işlevi (arama / çalar saat / diğer) seçilir ve
bir gerekçe yazılır. **Doğru yanıt "arama" ya da "çalar saat" DEĞİLDİR.**
Yönetio bir site yönetim uygulamasıdır ve öyle beyan edilmelidir. Yanlış
beyan uygulamanın kaldırılmasına yol açabilir. Gerekçe metni (form
İngilizce istediği için İngilizce):

> Yönetio is a residential site (apartment complex) management app. It
> uses full-screen intents only for life-safety emergency alerts —
> earthquake, fire, gas leak, evacuation and personal SOS calls raised by
> residents or security staff of the same site. When such an alert is
> raised, residents and security staff must see the instructions
> immediately, including when the phone is locked. Full-screen intents
> are never used for marketing, reminders or any other notification
> type. If the permission is not granted, the alert is still delivered as
> a high-priority notification, and the user can enable the permission
> from the app's "SOS alarm settings" screen.

Türkçesi (kayıt için): Yönetio bir site yönetim uygulamasıdır. Tam ekran
bildirimi yalnız can güvenliği uyarıları için kullanır: aynı sitenin
sakinlerinin ya da güvenlik görevlilerinin başlattığı deprem, yangın,
gaz kaçağı, tahliye ve kişisel SOS çağrıları. Pazarlama, hatırlatma ya da
başka bir bildirim türünde kullanılmaz. İzin verilmezse uyarı yine
yüksek öncelikli bildirim olarak gelir.

### iOS

* **Time Sensitive:** yetki `Runner.entitlements` dosyasına **eklendi**.
  Apple onayı gerekmez. Mac'te Xcode → Signing & Capabilities → "+ Time
  Sensitive Notifications" ile App ID'ye de eklenmeli. Otomatik imzada
  profil kendiliğinden güncellenir. Etkisi: SOS **Odak modunu deler**,
  ama telefon **sessizdeyken ÇALMAZ**.
* **Critical Alerts:** sessizde ve Odak modunda çalar, **Apple onayı
  ister**. Kod hazır:
  * uygulama izni `criticalAlert: true` ile istiyor,
  * cihazın izin durumunu kayıtta gönderiyor (`kritik_uyari`,
    göç 0157),
  * sunucu kritik ses yükünü (`critical: 1`,
    `interruption-level: critical`) **yalnız izni açık cihazlara**
    gönderiyor.
* **ONAY GELİNCE DEĞİŞECEK TEK YER:** `mobile/ios/Runner/Runner.entitlements`.
  Şu iki satır eklenecek:
  ```xml
  <key>com.apple.developer.usernotifications.critical-alerts</key>
  <true/>
  ```
  Onay gelmeden eklenirse imza başarısız olur. Onay geldikten sonra
  provisioning profile'ın yenilenmesi gerekir. Sunucuda ve Dart'ta
  değişiklik yok.
* **Critical Alerts başvurusu için gerekenler** (başvuru:
  developer.apple.com/contact/request/notifications-critical-alerts-entitlement):
  * **Takım ve uygulama:** Team ID, Bundle ID (`site.yonetio.app`),
    App Store adı ve bağlantısı.
  * **Kullanım senaryosu:** "Can güvenliği: site sakinlerine ve
    güvenlik personeline deprem, yangın, gaz kaçağı, tahliye
    uyarıları ve kişisel acil durum (SOS) çağrıları." Apple bu yetkiyi
    sağlık, halk güvenliği ve ev güvenliği gibi senaryolar için veriyor.
    Başvuruda uygulamanın bir **güvenlik ürünü** olduğu, sıradan
    bildirimlerde kullanılmayacağı açıkça yazılmalı.
  * **Kim tetikler, ne sıklıkla:** yalnız yönetim (site geneli) ve
    kayıtlı kişiler (kendi acil durumu). 5 saniyelik iptal penceresi
    ve yanlış alarm askısı var, yani kötüye kullanım sınırlı.
  * **Kullanıcı kontrolü:** iOS izni sorar, kullanıcı reddedebilir.
    Tatbikat bildirimleri de aynı yoldan gider, sıklığı yönetim belirler.
* **30 saniye sınırı:** iOS bildirim sesi en fazla 30 saniyedir ve
  **döngüye alınamaz**. Uzun dosya verilirse sistem sesi çalar.
* **Mümkün olmayan:** iOS'ta tam ekran alarm (yalnız CallKit ile, o da
  arama içindir) ve "Gördüm" deyince çalan sesi kesmek (ses bir kez
  çalar ve biter). "Gördüm" denince o alarmın bildirimleri bildirim
  merkezinden kaldırılır.

### Ses dosyası (sen sağlayacaksın)

Dosya gelene kadar **sistem alarm sesi** çalar.

| | Android | iOS |
|---|---|---|
| Ad | `yonetio_alarm.ogg` → `android/app/src/main/res/raw/` | `yonetio_alarm.caf` → `ios/Runner/` (Xcode'da hedefe eklenmeli) |
| Biçim | OGG Vorbis, 44.1 kHz, mono | CAF, IMA4 ya da Linear PCM, 44.1 kHz, mono |
| Süre | 3–8 sn, **döngüye uygun** (baş ve son kesintisiz birleşmeli; `FLAG_INSISTENT` dosyayı tekrar tekrar çalar) | **≤ 30 sn** (döngü yok; ≈20 sn önerilir) |
| Ses düzeyi | Tepe −1 dBFS, sıkıştırılmış (telefon hoparlöründe keskin) | aynı |
| Nitelik | Mevcut üç sesten (bildirim, gürültü, vardiya) **açıkça ayrılan**, sirene yakın, 1–3 kHz ağırlıklı (hoparlörde en duyulan aralık) | aynı kaynak |

Dosya gelince yapılacaklar:
1. Dosyaları koy.
2. `push_kanal.ALARM_SES_HAZIR = True` yap.
3. Android kanalını `yonetio_alarm_v2` olarak aç ve `_v1`'i sil.
   Android'de var olan bir kanalın sesi programla değiştirilemez.
4. `AlarmBildirimi.kt` içinde `R.raw.yonetio_alarm` statik referansını
   kullan. P210 dersi: `getIdentifier` kullanılırsa küçültücü dosyayı
   atar.

## §1d Rol geçişi (P247) — değişmedi

SOS kişiye (`app_user`) gider, aktif moda değil. Yönetici + sakin olan
kişi sakin modundayken de alır. Bildirim sakin kimlikli değildir; bu
yüzden dokunuşta uygulama yönetici modunda açılır ve alarm ekranı iki
modda da erişilebilirdir. Kanıt: `test_p249_sos_alici.py` alıcı kümesi
testleri ve mobilde `pushHedefi` testi.

## §1 ÖLÇÜLEMEDİ

Bu makinede telefon ve emülatör yok. Dev'de FCM kimliği de yok, bu
yüzden gerçek push da gönderilemez. Aşağıdakiler **ölçülmedi**, kodla ve
birim testleriyle desteklendi:

* Uygulama kapalıyken SOS'un **gerçek cihaza** düşmesi (Android ve iOS).
* Kilit ekranında tam ekran açılması (Android 14+ izni kapalı gelir).
* Alarm sesinin sessiz modda ve Rahatsız Etmeyin'de gerçekten çalması.
* "Gördüm" / "Güvendeyim" deyince sesin gerçekten susması.
* iOS Time Sensitive'in Odak modunu gerçekten delmesi. Yetki Mac'te
  imzalanmadı.
* Xiaomi, Huawei gibi üreticilerde kaydırılıp kapatılmış uygulamaya
  teslim.
* **Swift kodu derlenmedi** (`AppDelegate.swift` içindeki
  `kurAlarmKanali`). Olası hata noktaları:
  * `criticalAlertSetting` / `timeSensitiveSetting` kullanılabilirlik
    koşulları,
  * `getDeliveredNotifications` kapanışında `sonuc`'un ana iş parçacığında
    çağrılması.
* **Kotlin derlendi** (`flutter build apk --debug` geçti). Birleştirilmiş
  manifestte eklentinin servisinin kalktığı ve `SosMesajServisi`'nin
  kayıtlı olduğu **ölçüldü**.

**Cihaz test listesi (senin için):**
1. Alıcı telefonda uygulamayı tamamen kapat, telefonu sessize al,
   ekranı kilitle.
2. Diğer telefondan yönetici hesabıyla DEPREM SOS'u tetikle.
3. Beklenen: kilit ekranında "DEPREM ALARMI · <site>" başlığı ve talimat
   gövdesi, **alarm sesi döngüde** (Android). Android 14+'da tam ekran
   ancak "SOS alarm ayarları"ndan izin verildiyse açılır.
4. Bildirime dokun. Beklenen: `/panik-alarm/<id>` ekranı, adım adım
   talimat, GÜVENDEYİM düğmesi. Dokununca ses susmalı.
5. Aynı adımları SAĞLIK için tekrarla. Beklenen: "SAĞLIK ACİLİ",
   kim/nerede, Gidiyorum/Gördüm; sakin telefonuna **gelmemeli**.
6. Sorun olursa prod'da `docs/P249-sos-teshis.sql` sorgusunu çalıştır.
