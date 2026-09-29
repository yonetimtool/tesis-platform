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
    `interruption-level: critical`) **yalnız izni açık cihazlara** ve
    **yalnız Apple başvurusundaki beyan kapsamında** gönderiyor: gerçek
    deprem, yangın, gaz kaçağı ve tahliye
    (`push_kanal.KRITIK_UYARI_KIMLIKLERI`). **Tatbikatlar kritik değil.**
    Yardım çağrıları (sağlık, güvenlik tehdidi, diğer, yardım talebi) da
    kritik değil; bunlar time-sensitive gider. Kapsam genişletilecekse
    önce başvuru güncellenmeli (`docs/dis-basvurular.md`).
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

---

# §2 — TATBİKAT MODU

## §2a Tatbikat gerçek yolun provasıdır, ayrı bir sistem değildir

Tatbikat başlayınca bir `panik_alarm` satırı açılır ve **gerçek yayın
yolu** çalışır (`panik_yayin.yayinla_senkron`): aynı push, aynı alarm
kanalı, aynı tam ekran, aynı "Güvendeyim". Provada ayrı bir yol
kullanılsaydı, gerçek günde çalışacak yol sınanmamış olurdu.
`panik_tatbikat` tablosu (göç 0158) planı ve raporu tutar. Alarm satırı
ona `tatbikat_id` ile bağlanır.

| Kural | Nasıl |
|---|---|
| Yalnız yönetim başlatır | `POST /tatbikat` → admin, yönetici. Güvenlik raporu okur |
| Kategori | Yalnız toplu uyarılar: deprem, yangın, gaz, tahliye (şema + DB CHECK) |
| Kapsam | Tüm site ya da bir blok. Blokta: o bloktaki **aktif sakinler + tüm personel** (sayımı personel yapar) |
| Zaman | Boş bırakılırsa hemen başlar. İleri tarih en fazla 1 yıl, saat dilimli (dilimsiz zaman reddedilir) |
| Önceden duyuru | İsteğe bağlı, yalnız ileri tarihli tatbikatta. Alarm kanalından **değil**, genel kanaldan gider; metin "Deprem tatbikatı planlandı — 29.09.2026 14:00 · A Blok…" |
| Başlatma | Zamanı gelince beat (dakikada bir, `scheduler.tatbikat_zamani`), ya da elle "Başlat". İptal penceresi yok (planlı eylem) |
| Aynı anda bir tatbikat | İkincisi 409 `tatbikat_zaten_aktif` |
| Denetim kaydı | `tatbikat_plan`, `tatbikat_baslat`, `tatbikat_bitir`, `tatbikat_iptal`, `tatbikat_rapor` (kim, ne zaman, kapsam meta'da) |

## §2b Karıştırılamazlık

* **Başlık:** her dilde başlığın önünde "TATBİKAT — DEPREM ALARMI" (DRILL,
  ÜBUNG, EXERCICE, SIMULACRO, تمرين, УЧЕНИЯ). Bu yazı push'ta, tam
  ekranda ve kayıtta aynıdır.
* **Gövde:** push gövdesi "Bu bir tatbikattır." cümlesiyle başlar.
* **Ekran:** tam ekranın en üstünde sarı zeminli ayrı bir şerit:
  "TATBİKAT — Bu gerçek bir alarm değildir" (mobil ve web).
* **Yanlış alarm sayacı:** tatbikat alarmları sayılmaz
  (`tatbikat_id IS NULL`).
* **SMS, diyafon anonsu, akıllı ev senaryosu çalışmaz.** SMS metninde
  "tatbikat" yok ve maliyeti var. Diyafon anonsu siteye "TATBİKAT"
  demeden seslenirdi. Bir akıllı ev senaryosu provada kapı açabilirdi.

## §2c Gerçek alarm öncelikli

* `GET /panik/aktif` gerçek alarmları **önce** döndürür. İstemci ilk
  öğeyi tam ekran çizdiği için tatbikat sürerken gelen gerçek alarm
  onun arkasında kalmaz.
* **Gerçek bir toplu alarm** (deprem, yangın, gaz, tahliye) yayınlanınca
  aktif tatbikat **durdurulur**. `bitis_nedeni = gercek_alarm`, rapor
  bunu yazar. Aynı anda iki "deprem" ekranı (biri prova) karışıklık
  yaratırdı.
* Yardım çağrısı (sağlık vb.) tatbikatı durdurmaz, ama önce gösterilir.

## §2d Ses: gerçek alarmla AYNI — karar

**Gerekçe:** provanın amacı insanlara gerçek sesi tanıtmaktır. Deprem
gecesi ilk kez duyulan bir ses, ne olduğu anlaşılmadan kapatılır.
Karıştırılmayı önleyen şey ses değil metindir: başlığın ilk kelimesi
"TATBİKAT", ekranda ayrıca şerit var, isteğe bağlı olarak da önceden
duyuru gider. Farklı ses seçilseydi paniği önlerdi ama gerçek günün
provası olmazdı.

## §2e Sakin tatbikat bildirimini kapatamaz — karar

Tatbikatın ölçüsü "alarm kime **ulaştı**". Kapatılabilseydi rapor,
ulaşılamayan kişi yerine alarmı kapatan kişiyi "yanıtsız" gösterirdi.
Tatbikat alarm sınıfındadır, bu yüzden bildirim tercihlerini de aşar
(§1a). Rahatsızlığın çözümü tatbikatı **seyrek** yapmaktır; önerilen
sıklık yılda 1–2'dir. Gerçek alarmları kapatma seçeneği zaten yok.

## §2f Rapor

`GET /tatbikat/{id}` ve `GET /tatbikat/{id}/rapor.pdf`. Rapor, ekrandaki
"daire bazında durum" ile **aynı hesaptan** (`panik_durum.py`) üretilir:

* **Kaç kişiye gitti:** alıcı satırı sayısı. Ayrıca FCM'in kabul ettiği
  push sayısı ("bildirim kabul: 41/43"), teşhis satırlarından.
* **Kaçı açtı:** "gördü" sayısı. Karar vermek de açmayı kapsar.
* **Kaçı "Güvendeyim" dedi**, kaçı yardım istedi.
* **Ortalama yanıt süresi:** alarmın gönderildiği andan yanıta kadar.
* **Yanıt vermeyen daireler:** daire bazında, blok ve daire no ile.
  Sıra: önce yardım isteyen, sonra yanıtsız, en son güvende.

**"Telefona düştü" ölçülemez:** FCM teslim raporu vermiyor. Ölçülebilen,
FCM'in mesajı kabul etmesi ve kişinin açmasıdır.

## §2g Parite

* **Web:** `/panik` sayfasında "Tatbikatlar" bölümü: liste, planla,
  başlat, bitir, iptal, rapor penceresi, PDF.
* **Mobil:** Acil durum çağrıları → "Tatbikatlar": liste, planla,
  başlat, bitir, iptal, rapor ekranı.
* **İstisna — PDF yalnız web'de.** PDF yazdırma ve arşiv için alınır;
  bu bir masaüstü işidir. Mobil aynı raporu aynı veriyle ekranda
  gösterir. Mobilde PDF indirme **yapılmadı**.

## §2 ÖLÇÜLEMEDİ

* Tatbikatın gerçek cihazlarda çalması ve iki cihazdan yanıt verilmesi
  (cihaz yok). Sunucu akışı uçtan uca ölçüldü: planla, duyuru, beat ile
  başlama, Güvendeyim, bitir, rapor, PDF, gerçek alarmın durdurması
  (`test_p249_tatbikat.py`).
* PDF'in görsel düzeni gözle kontrol edilmedi. Yalnız geçerli bir PDF
  olduğu (`%PDF` imzası) ölçüldü.

---

# §3 — GÜVENLİKTEN DAİREYE ULAŞMA

**Saha sorunu:** Daire sahibi evde değil. Biri kapıya gelip "beni
bekliyor" diyor. Güvenlik bunu doğrulayamıyor ve kişi içeri giriyor.

Bu bölümde (a) ziyaretçi onay talebi, (b) sesli mesaj ve (e) telefon
yedeği **yapıldı**; bunlar altyapı istemiyordu. (c) uygulama içi arama ve
(d) diyafon üzerinden arama için **yalnız öneri** yazıldı; kod yok,
onayını bekliyor.

## §3.0 Akış ve ekran tasarımı — "Daireye ulaş"

Tek ekran, tek yön: güvenlik daireyi seçer, basamaklar **yukarıdan aşağı**
denenir. Bir basamak sonuç vermezse bir sonraki **kendiliğinden öne
çıkar**, güvenlik neyi deneyeceğini düşünmek zorunda kalmaz.

```
┌───────────────────────────────────────────┐
│ Daireye ulaş                    [A-12  ▾] │  ← daire seçimi (blok + no, arama)
│ Sakinler: Ayşe Y. · Mehmet Y.             │  ← yalnız ad; telefon YOK
├───────────────────────────────────────────┤
│ 1  ZİYARETÇİ ONAYI                        │
│    Ziyaretçi adı [__________]             │
│    [ Onay iste ]                          │
│    ⏳ Bekleniyor… 2:41                    │  ← geri sayım (3 dk)
│    ✅ Ayşe Y. ONAYLADI 14:02 / ⛔ REDDETTİ │
│    ⚠ 3 dakikada cevap yok  →  2'ye geç    │
├───────────────────────────────────────────┤
│ 2  SESLİ MESAJ           (basılı tut: kayıt)│
│    [ 🎙  Basılı tut, konuş, bırak ]         │  ← en fazla 60 sn
│    Gönderildi 14:04 · Dinlendi: —          │
├───────────────────────────────────────────┤
│ 3  UYGULAMADAN ARA       (öneri — §3c)     │  ← bugün gizli
├───────────────────────────────────────────┤
│ 4  TELEFONLA ARA                           │
│    [ 📞 Ayşe Y.'yi ara ]                    │  ← yalnız izin veren sakin
│    "Her arama kayda geçer."                │
└───────────────────────────────────────────┘
```

* **Sıra:** onay talebi → (cevap yoksa) sesli mesaj ya da arama → (yine
  yoksa) telefon. Sıra zorunlu değil. Güvenlik acil bir durumda 4'e
  doğrudan geçebilir; kısıt yalnız telefonun **izin** ve **kayıt**
  şartıdır.
* **Durum kalıcıdır:** ekran kapansa da onay talebinin sonucu ziyaretçi
  kaydında durur. Güvenlik "Ziyaretçiler" listesinden de görür.
* **Sakin tarafı:** bildirime dokununca "X kişisi sizi bekliyor diyor"
  kartı açılır, üzerinde **Onayla / Reddet** düğmeleri var. Sesli mesaj
  bildirimi "Sesli mesajlar" listesini açar; dinle ya da sil.

## §3a Ziyaretçi onay talebi — YAPILDI (mevcut akışın genişletmesi)

Mevcut ziyaretçi kaydı (`POST /visitors`) yalnız kayıt tutuyordu, onay
istemiyordu. Yeni bir akış yazılmadı; kayda **isteğe bağlı** bir onay
talebi eklendi (`onay_iste: true`).

* **Kime gider:** dairenin **tüm aktif sakinlerine**. Tek hedef
  seçiminin mantığı bilgilendirme içindi; onayda o an evde olmayan
  hedefi beklemek sorunu çözmez. İlk yanıt geçerlidir.
* **Kanal:** kritik kanal, sesli. Alarm kanalı değil: bu bir alarm değil,
  ama beklenen bir yanıttır.
* **Yanıt:** `POST /visitors/{id}/onay` `{karar: onayla|reddet}`. Yalnız
  o dairenin aktif sakini yanıt verebilir. Yanıt güvenliğe **kendi
  bildirimiyle** gider ("Ayşe Y. ONAYLADI").
* **Cevap yok:** süre **3 dakika** (`ZIYARETCI_ONAY_SURE_DK`). Kapıda
  bekleyen biri için makul bir sınır; daha uzunu güvenliği kapıda
  tutar. Süre dolunca beat (dakikada bir) kaydı `cevap_yok` yapar ve
  güvenliğe "cevap yok" bildirimi gider.
* **Denetim:** `visitor_onay_iste`, `visitor_onay_yanit`.

## §3b Sesli mesaj — YAPILDI

* **Kayıt:** basılı tut, konuş, bırak. En fazla **60 saniye**, **AAC
  (m4a)**, mono, 32 kbps. 60 saniye yaklaşık 240 KB tutar; sunucu
  1 MB'ı reddeder.
* **Kim gönderir:** güvenlik, amir, yönetim. **Kime:** dairenin tüm aktif
  sakinlerine. Bildirimde "Güvenlikten sesli mesaj — A-12" yazar.
* **Dinleme:** sakin kendi dairesine gelen mesajı dinler. Sunucu 5
  dakikalık imzalı bir adres verir; dosya herkese açık değildir. İlk
  dinleme zamanı kaydedilir ve gönderen "dinlendi" bilgisini görür.
* **KVKK — saklama 7 gün:** ses kişisel veridir (biyometrik nitelik
  taşıyabilir). Amaç kapıdaki anlık durumu iletmektir. Gece çalışan
  imha görevi 7 günden eski mesajları **hem kayıttan hem depodan**
  siler.
* **Silme:** sakin kendi dairesine gelen mesajı istediği an siler (kayıt
  ve dosya). Gönderen de gönderdiği mesajı geri alabilir.
* **Denetim:** gönderim, dinleme ve silme kayda geçer. Kayıtta sesin
  içeriği değil, yalnız kim/ne zaman/hangi daire tutulur.

## §3c Uygulama içi arama — ÖNERİ (kod yok, onay bekliyor)

**Ne:** güvenlik uygulamadan daireyi arar ve sakinin telefonu gelen
arama gibi çalar (iOS CallKit + VoIP push, Android ConnectionService).

**Mimari:**
* **Sinyal:** mevcut API üzerinden (WebSocket gerekmez). Arama isteği →
  sunucu → VoIP push (iOS) / yüksek öncelikli data push (Android) →
  sakin kabul eder → iki taraf SDP alışverişini sunucu üzerinden yapar.
  Kısa bir süre (≤ 60 sn) için yoklama da yeterli.
* **Medya:** WebRTC (`flutter_webrtc`). Eşler arası bağlantı çoğu
  mobil ağda NAT arkasında kurulamaz; **TURN sunucusu şart**.
* **TURN — iki yol:**

| | Kendimiz (coturn) | Hazır servis (Twilio NTS, Cloudflare Calls TURN, Metered) |
|---|---|---|
| Maliyet | Sunucu + bant genişliği. Sesli arama ≈ 50–100 kbps; aylık birkaç yüz dakika için ihmal edilebilir | Dakika ya da GB başı; düşük hacimde aylık birkaç $ |
| Bakım | TLS sertifikası, 3478/5349 UDP+TCP portları, geniş UDP port aralığı (49152–65535), izleme | Yok |
| Tek sunucumuz | **Kaldırır** (coturn hafif), ama prod sunucusunun UDP port aralığını açmak ve NAT arkasındaysa dış IP'yi bildirmek gerekir. Bugün prod'a yalnız 80/443 açık | Etkilemez |
| Öneri | — | **Başlangıçta hazır servis**; hacim büyürse coturn |

* **iOS VoIP push kuralı:** iOS 13'ten beri **her VoIP push'ta CallKit
  ile arama gösterilmek zorunda**. Gösterilmezse iOS uygulamayı
  sonlandırır ve tekrarında VoIP push'u tamamen keser. Bu yüzden VoIP
  push **yalnız gerçek arama** için gönderilmeli; iptal ya da "cevap
  yok" durumu normal push ile bildirilmeli. Ayrıca APNs'e **ayrı VoIP
  sertifikası / anahtar** gerekir ve FCM VoIP push göndermez; sunucudan
  doğrudan APNs'e gidilmeli (yeni bağımlılık).
* **Birden çok sakin:** **hepsi aynı anda çalsın**, ilk açan konuşur,
  ötekilerin çağrısı "başka cihazda yanıtlandı" ile kapanır. Sırayla
  çaldırmak kapıda bekleme süresini sakin sayısıyla çarpar.
* **İzin:** sakinin profilinde "güvenlik beni uygulamadan arayabilir"
  (varsayılan **açık** önerilir). Uygulama içi arama numara ifşa etmez.
  Telefon yedeğindeki gizlilik sorunu burada yok.
* **Tahmini iş:** 2–3 tur. VoIP/CallKit ve ConnectionService yerel kod
  ister; Mac'te iOS derlemesi ve iki gerçek cihazla deneme gerekir
  (burada ölçülemez).

## §3d Diyafon üzerinden arama — ÖNERİ (kod yok, onay bekliyor)

**Bizim kodda ne var (P240):**
* `diyafon` tablosu **tesis başına** kayıt tutuyor: kapı paneli ya da
  PBX. **Daire başına dahili numara YOK.**
* SIP tarafında yalnız **sinyalleşme** var: `OPTIONS` (sağlık) ve
  `MESSAGE` (ekrana metin anonsu).
* **INVITE + RTP (sesli arama) YAZILMADI**, `sesli_anons` hiçbir
  yöntemde açık değil. Kuru kontak yöntemi ses taşıyamaz.

**Eksik olan:**
1. **Daire → dahili eşlemesi:** `unit.diyafon_dahili` (ya da ayrı tablo).
   Kurulumda yönetici girer ya da PBX'ten içe aktarılır.
2. **Medya:** güvenliğin telefonundaki ses (WebRTC) ile dairenin iç
   ünitesi (SIP/RTP) arasında **köprü**. Sunucuda bir SIP B2BUA ya da
   medya sunucusu gerekir: **Asterisk / FreeSWITCH** ya da **Janus SIP
   eklentisi**. §3c'deki WebRTC altyapısının üzerine kurulur.
3. **Ağ:** sunucumuz sitenin yerel ağındaki PBX'e erişmeli (VPN ya da
   sahada bir ağ geçidi). Bugün P240 bu erişimi sahadaki cihaz üzerinden
   varsayıyor.

**Hangi modellerde çalışır:**
* **Çalışır (SIP destekli IP iç üniteler):** 2N (IP Verso ve iç
  üniteler, doğal SIP), Akuvox (doğal SIP), Hikvision (DS-KH iç
  üniteler SIP sunucusuna kaydedilebilir), Dahua VTH (SIP modu), Fanvil
  ve Grandstream iç üniteler.
* **Çalışmaz:** Türkiye'deki eski sitelerin çoğundaki **analog / 2 telli
  sistemler** (eski Audio, Kocom, Commax analog serileri). SIP konuşmaz;
  ancak üreticinin IP ağ geçidi varsa ve o da genellikle yalnız kapı
  paneli içindir, daire başına değil.
* **Kurulumda sorulacak:** sistemin IP mi analog mu olduğu, bir PBX /
  SIP sunucusu olup olmadığı ve daire iç ünitelerinin SIP'e kayıtlı
  olup olmadığı. Bu üçü yoksa (d) o sitede yapılamaz.

**Öneri:** (d)'yi (c)'den **sonra** yap. Medya köprüsü (c) ile gelir.
Önce bir pilot sitede iç ünite modelini ve PBX erişimini doğrula.
(d)'nin avantajı: sakin evdeyse ama telefonu yanında değilse **iç ünite
çalar**. Dezavantajı: sakin evde değilse hiçbir işe yaramaz. "Ev sahibi
evde değil" senaryosunda (c) ve (e) daha etkilidir.

## §3e Telefon yedeği — YAPILDI

* **Sakin izni:** profilde "Yönetim beni bu numaradan arayabilir"
  (`app_user.yonetim_arayabilir`, varsayılan **kapalı**). Sakin açar ve
  kapatır. Mobil profil ekranında bulunur.
* **Numara görünmez:** liste, arama ve dışa aktarım uçları değişmedi.
  E2E turunda amire kapatılan sakin telefonu kuralı korunuyor. Numara
  yalnız `POST /units/{id}/ulas/telefon` ile, **tek bir sakin** için ve
  yalnız izni açıksa döner. İzin kapalıysa 403 döner ve numara hiç
  gönderilmez.
* **Kim:** güvenlik, amir, yönetim.
* **Her istek denetim kaydına geçer** (`daire_telefon_goster`: kim,
  hangi daire, hangi sakin, ne zaman). "Arama" değil "numara açıldı"
  kaydedilir. Aramanın kendisi telefonun çeviricisinde olur ve uygulama
  onu göremez; kayıt numaranın **açıldığı** anı tutar.
* **Ekranda:** yalnız "Telefonla ara" düğmesi. Numara metin olarak
  yazılmaz; düğme doğrudan çeviriciyi açar.

## §3.5 Uçlar ve kurallar (yapılanlar)

| Uç | Kim | Kural |
|---|---|---|
| `POST /visitors` `onay_iste: true` | güvenlik | Dairenin tüm aktif sakinlerine onay talebi; bilgilendirme push'u yerine gider |
| `POST /visitors/{id}/onay` | dairenin aktif sakini | İlk yanıt geçerli (koşullu güncelleme), sonraki 409; başka daire 404 |
| beat `scheduler.ziyaretci_onay_suresi` | — | 3 dk dolunca `cevap_yok` + güvenliğe bildirim (dakikada bir) |
| `GET /units/{id}/ulas` | güvenlik, amir, yönetim | Aktif sakinler + "telefonla aranabilir mi"; **numara yok** |
| `POST /units/{id}/ulas/telefon` | güvenlik, amir, yönetim | Tek sakin, izin açıksa; denetim `daire_telefon_goster` |
| `POST /units/{id}/sesli-mesaj/yukleme` + `POST /units/{id}/sesli-mesaj` | güvenlik, amir, yönetim | İmzalı adresle depoya; anahtar o tesisin o dairesine ait olmalı; ≤ 60 sn, ≤ 1 MB, AAC |
| `GET /sesli-mesaj`, `GET /sesli-mesaj/{id}/dinle`, `DELETE /sesli-mesaj/{id}` | dairenin sakini ya da gönderen | Yönetim dahil başkası dinleyemez (404) |
| beat `scheduler.sesli_mesaj_imhasi` | — | 7 günden eski mesajların dosyası silinir (04:30) |
| `PATCH /me/bildirim-tercihleri` `yonetim_arayabilir` | sakin | Varsayılan kapalı |

Göç 0159: `visitor.onay_*`, `daire_sesli_mesaj` (RLS), `app_user.yonetim_arayabilir`,
üç yeni bildirim türü.

**IDOR taraması** tüm "hedef" uçlarını ölçüyor: onay yanıtı, dinleme,
silme. **Beat manifesti** iki yeni görevle güncellendi. Prod'da beat
imajı yeniden kurulmazsa görevler çalışmaz; manifest bunu açılışta
gösterir.

## §3.6 Parite

* **Mobil:**
  * güvenlik ve yönetim: Ziyaretçiler → "Daireye ulaş" ekranı (onay,
    basılı tut sesli mesaj, izinli telefon), ziyaretçi formunda "Sakinlerden
    onay iste";
  * sakin: ziyaretçi kartında Onayla / Reddet, "Sesli mesajlar" ekranı
    (dinle, sil), Ayarlar'da "Yönetim beni bu numaradan arayabilir".
* **Web:** Ziyaretçiler sayfasında **onay durumu sütunu**. Yeni üç
  bildirim türünün adı ve yönlendirmesi eklendi.
* **İstisna — "Daireye ulaş" ekranı, ses kaydı ve dinleme web'de YOK.**
  Gerekçe:
  * bu kapıdaki bir iştir ve onu yapan roller (güvenlik, amir) yalnız
    mobildedir;
  * sakin de yalnız mobildedir;
  * yönetici aynı ekranı mobilde kullanabilir (uçlar ona açık);
  * tarayıcı kaydı Chrome'da WebM üretir, sunucu ise AAC bekler; web
    kaydı ayrı bir dönüştürme işi olurdu.

## §3 ÖLÇÜLEMEDİ

* **Gerçek cihazda ses kaydı ve oynatma:**
  * mikrofon izni penceresi;
  * `record` paketinin AAC çıktısının iOS'ta `video_player` ile
    oynatılması;
  * basılı tutma hissi.

  Birim testte kaydedici sahtelendi.
* **İmzalı adrese PUT ÖLÇÜLDÜ** (dev MinIO, konteynerden gerçek
  yükleme). Gönderim ucu dosyanın depoda **olduğunu** ve **1 MB'ı
  aşmadığını** kendisi doğruluyor (`storage.obje_boyutu`). Yüklenmemiş
  anahtar 422 alır. Mobil uygulamanın aynı PUT'u gerçek cihazdan yapması
  ölçülmedi.
* **iki sakinin aynı anda onaylaması:** sunucu koşullu güncellemeyle
  tekini kazandırıyor (kod), eşzamanlı istekle ölçülmedi.
* **(c) ve (d)** kod değil öneri; ölçülecek bir şey yok.
