# P251 — Test bulguları: alarm durumu, bildirim, tablolar, görseller, menü, mesaj günlüğü, mobil ızgara

Her bölüm ayrı commit. Ölçüm önce, düzeltme sonra.

# §1 — ACİL DURUM ÇAĞRILARI

## Ölçüm (dev, gerçek akış + gerçek Chromium)

Akış API üzerinden sürüldü: güvenlik alarm başlattı → yönetici kapattı;
ikinci alarm yayından sonra iptal edildi (yanlış alarm). Ardından
`/panik` sayfası gerçek tarayıcıda görüntülendi.

* **Sunucu doğru:** kapatılan alarm `kapandi`, iptal edilen
  `yanlis_alarm` döndü; yayın görevi iptal penceresinden sonra kapanmış
  alarmı ezmiyor (`panik_yayin.py` korumalı). BFF önbelleklemiyor
  (`force-dynamic`, `no-store`).
* **(a) + (b) kök neden web'de, iki kusur:**
  1. "Açık çağrı" istemcide `kapandi_at == null` ile sayılıyordu. İptal
     ve yanlış alarm `kapandi_at` **yazmaz** (yalnız `iptal_at`), yani
     sonsuza kadar "açık" sayılıyordu. Ekranda "Açık çağrı: 1" ve tek
     kayıt "Yanlış alarm" olarak ölçüldü.
  2. Sayılar ayrı bir istekten (200 kayıt) geliyordu ve o istek **hiç
     yenilenmiyordu**: liste 15 sn'de bir tazelenirken şerit eski
     kalıyordu; web'de "Kapat" da yalnız listeyi tazeliyordu. "Kapattım
     ama hâlâ açık" görüntüsü buydu.
* **(c)** Süzgeç elle yazılmış bir listeden çiziliyordu ve
  `yanlis_alarm` eksikti. Ayrıca bilinmeyen bir `?durum=` değeri
  veritabanında tür hatasına (500) dönüşüyordu.
* **(d)** "/ gördü" başlığı, satır metninin (`{goren}/{toplam} gördü`)
  yer tutucuları boş verilerek yapılmıştı. Eylem sütununun başlığı
  `aria-label` ile verilmişti ama paylaşılan `Th` bileşeni bu özelliği
  **tanımlamıyordu**: tireli özellik TypeScript'te hata vermediği için
  9 tabloda sessizce yutuluyordu — başlık hem görünmez hem ekran
  okuyucuya boştu. `Tr` ve `Td` de `data-test`i aynı şekilde yutuyordu.
* **Mobil:** takip ekranı satırda **durumu hiç yazmıyordu** (yalnız
  ikon rengi; yanlış alarm ile kapandı aynı görünüyordu), sayı ve
  süzgeç yoktu, tatbikatlar karışıktı.

## Kararlar

* **Sayılar sunucuda, durumdan:** `GET /panik` yanıtı `ozet` taşır.
  Tek tanım: **açık = beklemede | açık | müdahale**.
* **"Kapanan" = sonuçlanan her alarm** (kapandı + iptal + yanlış alarm).
  Gerekçe: üç kart toplamı tüm alarmları karşılamalı; yanlış alarm ve
  iptal de "artık müdahale beklemeyen" kayıttır. Ayrıntı kartın altında:
  "1 yanlış alarm · 0 iptal".
* Sayılar **durum ve tatbikat süzgecinden bağımsız** (P244 §8c) ve
  listeyle aynı yanıtta geldiği için 15 sn'de bir birlikte yenilenir.
  "Bugün" tesisin saat diliminde.
* **Durumlar enum'dan:** yanıt `durumlar` = `PANIK_DURUM.enums`. Süzgeç
  (web + mobil) bundan çizilir; yeni bir durum eklenince eksik kalmaz.
  Bilinmeyen durum 422 (`gecersiz_durum`, 7 dil).
* **Tatbikat:** ayrı süzgeç — Gerçek alarmlar / Tatbikatlar / Gerçek ve
  tatbikat. **Varsayılan gerçek alarmlar**: tatbikatın kendi bölümü ve
  raporu aynı sayfada (web) / ayrı ekranda (mobil); acil durum
  listesine karışmaları görünürlüğü bulandırıyordu. Tatbikat satırı
  "Tatbikat" rozeti taşır. Özet tatbikatları açık sayısına katmaz
  (`ozet.tatbikat` ayrı).
* **Başlıklar:** "Gören" ve görünür "İşlem" başlığı. Paylaşılan `Th`
  artık `aria-label`'ı görünmez metin olarak çizer (diğer 8 tablonun
  eylem sütunu da ekran okuyucuda adlandı); `Tr`/`Td` `data-test`
  geçirir.

## Testler

* Sunucu `test_p251_panik_ozet.py` (3): iptal + yanlış alarm açık
  sayılmaz, kapatma açık sayısından düşer, özet durum süzgecinden
  bağımsız; `durumlar` = enum, `yanlis_alarm` süzer, bilinmeyen 422;
  tatbikat süzgeci + özet tatbikatı saymaz.
* Web `p251-panik-takip.dom.test.ts` (4), mobil
  `p251_panik_takip_test.dart` (3, büyük yazı 2x taşma dahil).
* Gerçek tarayıcı (sonra): Açık 0, Kapanan 2 ("1 yanlış alarm · 0
  iptal"), başlıklar dolu.

## Testte bulunan kusur

* Mobilde süzgeç değişince yeni istek yüklenirken durum listesi
  boşalıyor, seçili durum açılır listede kalmadığı için ekran çöküyordu
  (Flutter assert). Son bilinen liste korunur, ilk yüklemede yedek
  liste kullanılır.

# §9 — SOS İKİ KEZ GÖRÜNÜYOR (mobil)

* **Kök neden:** yan menü başlığındaki düğme `Icons.sos_outlined`
  simgesini ve "SOS" yazısını birlikte çiziyordu; simgenin kendisi "SOS"
  harflerinden oluşuyor. Ekranda "SOS SOS" okunuyordu.
* **Karar:** simge kaldırıldı; **kırmızı rozetli tek "SOS" yazısı**
  kaldı (P237 kuralı: başka ekrana götüren eylemin adı görünür olmalı).
  Ekran okuyucu kısaltmayı değil adı söyler: **"Acil durum"**
  (`Semantics` etiketi, alt anlamlar dışlandı). Dokunma hedefi en az
  48×48 (P220 kilidi korunuyor).
* Başka ekranda aynı ikili yok (taranadı; panik alarm ekranındaki tek
  `Icons.sos` "yardım" durumunun simgesi).
* **Test:** `p251_tek_sos_test.dart` — tek "SOS" metni, simge yok,
  ekran okuyucuda "Acil durum" (SOS değil), boyut ≥ 48×48, dokununca
  `/panik`.

# §5 — GÖRSELLER: ETKİNLİK, DUYURU, REZERVASYON ALANI

## (a) Ölçüm: mobilden eklenen etkinlik görseli web'de neden yok

Mobilin akışı betikle sürüldü (`/uploads/presign` → depoya PUT →
`POST /events` `foto_key` ile), ardından web gerçek Chromium'da açıldı.
Adaylar tek tek elendi:

* **Sunucu yanıtı:** `GET /events` ve tekil uç `foto_url` döndürüyor;
  imzalı adres geçerli (dev'de 200, `image/png`). → aday değil.
* **İmzalı adresin süresi:** liste her açılışta taze adres üretiyor. →
  aday değil.
* **CSP `img-src`:** P250 politikası `img-src`'i bilerek kısıtlamıyor;
  tarayıcı konsolunda CSP ihlali yok. → aday değil.
* **Web yanıtı okumuyor — KÖK NEDEN.** Yönetici etkinlikleri web'de
  yalnız **Etkinlik yönetimi** sayfasında görüyor ve o sayfanın türü
  `foto_url` alanını **hiç tanımlamıyordu**; görsel çizilmiyordu, form
  da görsel kabul etmiyordu. Görselli kart yalnız sakin görünümündeki
  sayfadaydı. Ölçüm: sayfada kayıt görünüyor, `<img>` sayısı 0, depoya
  hiç istek yok. Düzeltmeden sonra: aynı kayıt küçük resimle görünüyor,
  depodan 200.

## Kararlar

* **Ortak bileşen (web + mobil):** `IcerikGorseli` iki boy:
  * **küçük** (listede, 64 px web / 48–56 dp mobil),
  * **büyük** (ayrıntıda, 16:9; mobilde dokununca tam ekran +
    yakınlaştırma).
* **(d) Görsel yoksa:** küçükte içerik türünü söyleyen sakin bir **ikon
  kutusu** (duyuru / takvim / bina) — liste hizası bozulmaz; büyükte
  **hiçbir şey** çizilmez. Görsel yüklenemezse de aynı. Eski davranış
  (web'de kesik kenarlı "Görsel görüntülenemedi" kutusu, mobilde
  "Görsel yüklenemedi" satırı) kaldırıldı: istege bağlı görseli
  olmayan her kayıt "kırık" gibi görünüyordu.
* **Ortak seçici (web + mobil):** `GorselSecici` — seç/çek → presign →
  depoya PUT → `foto_key`; kaldır → `null`; dokunulmadıysa alan hiç
  gönderilmez (sunucu mevcudu korur); yükleme sürerken/düşmüşken kayıt
  engellenir. Duyuru ve site kuralında kopyalanmış mantığın ortak hali;
  etkinlik yönetimi (web) ve rezervasyon alanı (web + mobil) bunu
  kullanıyor. Mevcut duyuru/etkinlik formlarının çalışan seçicilerine
  dokunulmadı.
* **(b) Rezervasyon alanı görseli:** göç **0165** (`ortak_alan.foto_key`),
  oluştur/düzenle'de `foto_key`, okumada imzalı `foto_url`. Anahtar kendi
  tesisinin alanında olmalı (duyuru/etkinlik/site kuralıyla aynı IDOR
  koruması, 422).
* **(c) Nerede görünüyor:**

| İçerik | Web listesi | Web ayrıntısı | Mobil listesi | Mobil ayrıntısı |
|---|---|---|---|---|
| Duyuru | küçük (tıklayınca ayrıntı) | büyük (ayrıntı penceresi) | büyük* | — |
| Etkinlik | küçük (yönetim) / büyük kart (sakin görünümü) | büyük (düzenleme formu) | küçük | büyük (ayrıntı sayfası) |
| Rezervasyon alanı | küçük (yönetim) | büyük (rezervasyon formunda seçilen alan) | küçük | büyük (alan ve slotlar) |

  \* Mobil duyuru kartı metnin tamamını gösterir ve ayrı bir ayrıntı
  ekranı yoktur; kart ayrıntı görevinde olduğu için büyük boy kullanıldı.

## Testler

* Sunucu `test_p251_alan_gorsel.py` (2): anahtarla oluştur → listede
  `foto_url` (sakin de görür), PATCH null kaldırır; başka tesisin
  anahtarı 422; görselsiz alan `foto_url=null`. Rezervasyon testleri
  (44) yeşil.
* Web `p251-gorseller.dom.test.ts` (4): gösterim (yoksa/hata → ikon,
  büyük hiç), etkinlik yönetiminde mobilden gelen görsel, web'den görsel
  yükle → `foto_key` POST, alan görselini kaldır → `foto_key: null`.
* Mobil `p251_gorseller_test.dart` (4): gösterim, yüklenemeyen görsel,
  seçici → anahtar, model/taslak (yeni/kaldır/dokunulmadı).
* **Davranış değişikliğiyle güncellenen 2 mobil test:** kırık görselde
  "Görsel yüklenemedi" satırı bekliyorlardı; artık görselin hiç
  çizilmediğini ölçüyorlar (320 dp taşma ölçümü korunuyor).
* Gerçek tarayıcı: etkinlik yönetiminde görsel küçük resim olarak
  göründü, görselsiz kayıtlarda ikon kutusu.

# §6 — İÇE AKTARIM TABLOSU

## Ölçüm

* Tablo kipinde satırlar `i + 2` ile numaralanıyordu (Excel'in başlık
  satırı sayılmıştı); tabloda başlık satırı yok, ilk satır "2" görünüyordu.
  Sunucuya da `satir_no = i + 2` gidiyordu; hata listesi "Satır 2"
  diyordu.
* Dosya kipinde numara başlık işaretine göre 1 ya da 2'den başlıyordu.
* Başlıklar, eşleme seçenekleri, hata satırları ve şablon açıklaması ham
  alan kodunu gösteriyordu (`sakin_ad`, `rol_tipi`).
* `rol_tipi` serbest metin kutusuydu; örnek metin ("malik | kiraci |
  malik_oturan") kesiliyordu; "Kiracı" yazan kullanıcı sunucuda
  `gecersiz_rol_tipi` alıyordu (Türkçe `ı` ve "KİRACI" tanınmıyordu).
* Ad/soyad P250'de ayrılmıştı (şablon, tablo, sunucu biçimleme) —
  doğrulandı, değişiklik gerekmedi. Telefon sütunu P248'in ortak telefon
  bileşeniyle — doğrulandı (gerçek tarayıcıda ülke kodu + numara).

## Kararlar

* **Satır numarası her yerde 1'den, başlık sayılmadan** (tablo ve dosya
  kipi). Ekranda görünen, sunucuya giden ve hata listesinde yazan sayı
  aynı (`satirNo`).
* **Okunur başlık:** alan kodları sözlükten okunur ada çevrilir (7 dil):
  Ad, Soyad, E-posta, Telefon, Blok, Daire no, **Malik / Kiracı**, Plaka,
  Araç markası, Araç modeli, Arsa payı, Metrekare, Tutar, Açıklama.
  Daire türündeki `sakin_*` sütunları aynı adla ("sakin_ad" → "Ad").
  Sözlükte karşılığı olmayan yeni bir kod olduğu gibi görünür (eksik
  çeviri fark edilsin). Kod sunucu sözleşmesidir, değişmedi; başlığın
  `title`'ında durur. İndirilen şablonun başlık satırı ve açıklaması da
  okunur adlarla; dosya kipinde eşleme el ile yapıldığı için eski
  (kodlu) dosyalar da çalışmaya devam eder.
* **Rol açılır liste:** Malik / Kiracı / Malik (oturuyor). Excel'den
  yapıştırılan "Kiracı", "malik-oturan", "Malik ve oturan" koda çevrilir;
  tanınmayan değer kaybolmaz, seçili kalır ve sunucu satırı işaretler
  (sessizce düzeltilmez). Sunucu da dosya kipi için Türkçe yazımı tanır
  (`tr_kucuk` + `ı→i`).
* **Mobil:** içe aktarım yalnız web'de (P204 kararı; mobil ekran
  "toplu aktarım bilgisayardan yapılır" der). Bu bölümde mobil
  değişiklik yok.

## Testler

* Sunucu `test_p251_ice_aktarim.py` (2): hata satır numarası gönderilenle
  aynı; "Kiracı", "KİRACI", "Malik oturan" kabul, "komşu" satır hatası;
  ad/soyad Türkçe biçim ("ışıl ilhan" → "Işıl İLHAN").
* Web `p251-ice-aktarim.dom.test.ts` (2): rol `<select>` ve seçenekleri,
  telefon ortak bileşen, yapıştırılan "Kiracı" → `kiraci`, istek
  gövdesinde `satir_no` [1, 2]; normalleştirme yardımcısı.
* `p243-aktarim-tablosu.dom.test.ts` yeni davranışa güncellendi: başlıkta
  "Blok (zorunlu)", "E-posta" (ham kod yok), ilk satır "1", hata "Satır
  1 · Daire no".
* Gerçek tarayıcı: başlıklar okunur, satır 1'den, rol listesi kesilmeden.
  **Not:** tablo sayfayı yatayda taşırıyor — §4'te (içerik genişliği)
  ele alındı.

# §10 — MESAJ VE PUSH GÜNLÜKLERİ PLATFORM PANELİNE

## Ölçüm

* Tesis yöneticisi ham sağlayıcı ayrıntısını üç yerde görüyordu:
  * **Mesajlar → Gönderim geçmişi** tablosu: satır başına sağlayıcının
    hata kodu (`535 5.7.8 …`, `bounce`).
  * **Bildirimler** sayfasının üstündeki push teşhis paneli: bildirim
    kimlikleri (`gecikmis_okutma`, `kacirilan_tur`), cihaz jetonu
    parçaları, sağlayıcı/servis hesabı durumu.
  * **Davetler** ekranı (web + mobil): ulaşmayan davette ham kod
    ("bounce").
* Ödeme kodu ve otomatik hatırlatma ekranları ham hata göstermiyordu
  (sunucu `teslim_durumu` ile sade durum veriyordu) ama etiketler teknik
  kalıyordu ("Geri döndü", "Başarısız", "E-posta ayarı yok") ve yöneticiye
  ne yapması gerektiğini söylemiyordu.

## Kararlar

* **Platform paneli "Gönderim günlüğü"** (`/gonderim-gunlugu`, yalnız
  admin): e-posta + SMS (`mesaj_gonderim`) ve push (`push_gonderim`) tek
  listede, **tüm tesisler**: tarih, kanal, tesis, alıcı (ad + adres /
  telefon / "platform …jetonun son 6 hanesi"), amaç (Türkçe: Ödeme kodu,
  Hoş geldiniz, Aidat hatırlatması, bildirim türü…), durum, **ham hata
  ayrıntısı** (yalnız burada).
  * Arama kutusu: alıcı adı, adres/telefon, tesis adı, hata metni.
  * Süzgeçler: kanal, durum, **yalnız başarısız olanlar**, tarih aralığı.
  * Tesisler arası okuma `audit_log_list` deseninde sahip yetkili
    `gonderim_gunlugu_list` fonksiyonuyla (göç **0166**, zaman indeksleri
    dahil); secdef envanterine kayıtlı.
  * P191'in push sağlayıcı paneli (sağlayıcı, servis hesabı, cihaz sayısı,
    "kendime test gönder", geçersiz jetonları temizle) bu sayfanın altına
    taşındı; olay sütunu artık okunur ad gösteriyor.
* **Yöneticide ne kaldı (karar ve gerekçe):** yalnız **bağlam içindeki
  sade durum** — çünkü yönetici yanlış e-posta adresini ancak ilgili
  kişinin satırında görürse düzeltebilir; teknik ayrıntı (sağlayıcı kodu,
  jeton) onun düzeltebileceği bir şey değil.
  * Ödeme kodu satırı, otomatik hatırlatma e-postaları, davetler (web +
    mobil): **İletildi / Ulaşmadı / Gönderilemedi / E-posta gönderimi
    hazır değil** ve ulaşmadıysa tek cümle ne yapılacağı:
    * geri döndü → "E-posta adresi geçersiz olabilir."
    * gönderilemedi → "Bir süre sonra yeniden deneyin."
    * hazır değil → "destek@yonetiyor.com ile iletişime geçin."
  * Toplu mesaj gönderiminin sonucu sayılarla (gönderildi / rıza yok /
    adres yok / başarısız) ekranda kalır.
* **Kaldırılan / kapatılan (DAVRANIŞ DEĞİŞİKLİĞİ):**
  * Mesajlar sayfasındaki gönderim geçmişi tablosu kalktı;
    `GET /mesajlar/gecmis` artık **yalnız admin** (yöneticiye 403).
  * `GET /push/teshis`, `POST /push/test`, `POST /push/cihaz-temizle`
    **yalnız admin** (yöneticiye 403).
* **Mobil:** mobilde teknik günlük hiç yoktu; davetler, ödeme kodu ve
  hatırlatma ekranlarındaki etiket + açıklama web ile aynı. Platform
  paneli yalnız web (`panel.*`; mobilde platform yüzeyi yok).

## Testler

* Sunucu `test_p251_gonderim_gunlugu.py` (2): yönetici 403 (günlük,
  `/mesajlar/gecmis`, `/push/teshis`); iki tesisin kayıtları tek listede
  tesis adıyla, arama (adres + hata metni), tesis / kanal / yalnız
  başarısız süzgeçleri, push satırı (jeton son 6), geçersiz kanal 422.
  Push teşhis testleri yönetici 403'e güncellendi; rol matrisi ve uç
  güvenlik kilitleri yeniden üretildi.
* Web `p251-gonderim-gunlugu.dom.test.ts` (3); mobil
  `p250_odeme_kodlari_test` ve `e2e_davetler_gurultu_test` yeni sade
  etiketlere güncellendi ("bounce" artık görünmüyor, açıklama görünüyor).
* Gerçek tarayıcı: platform yöneticisi olarak 8.634 kayıt, tesis adlarıyla;
  ham hata yalnız bu sayfada.

# §2 — BİLDİRİMLER: TEK PANEL

* Bildirimler sayfasının üstündeki push teşhis paneli kaldırıldı (§10 ile
  platforma taşındı). Sayfada yalnız asıl bildirim ekranı kalır:
  okunmamış/okunmuş, arama, toplu işlem.
* **Tür adları:** 14 tür ham/kısa ve küçük harfliydi ("kaçırılan tur",
  "eksik nokta", "talep → iş emri"). 7 dilde açık adlarla değiştirildi:
  "Kaçırılan devriye turu", "Devriyede okutulmayan nokta", "Devriye
  noktası geç okutuldu", "Konum dışından okutma", "Talep iş emrine
  dönüştü", "Kargo geldi", "Ziyaretçi geldi" vb. Push kimlikleri
  (`panik_kategori_*` dahil) aynı adlarla gösterilir.
* Mobil bildirim ekranı türü adla değil ikonla gösteriyor; değişiklik
  gerekmedi.
* **Test:** `p251-gonderim-gunlugu.dom.test.ts` — bildirimler sayfası push
  teşhis ucunu hiç çağırmıyor, tür "Kaçırılan devriye turu" yazıyor.

# §3 — ŞİKAYET HARİTASI: AÇILIR PENCERE

* **Ölçüm:** daire ayrıntısı sayfanın sağ sütununda bir paneldi
  (`grid lg:grid-cols-[1fr_360px]`); aşağı kaydırılmış bir blokta daireye
  tıklayan yönetici paneli göremiyordu.
* **Karar:** ayrıntı ortak `Modal` içinde açılır: Esc ve dışarı tıklama
  kapatır, odak pencerede kalır, kapanınca tıklanan hücreye döner
  (ortak bileşenin mevcut erişilebilirlik davranışı). Sayfa tek sütun.
* **İçerik:** başlıkta daire; altında blok, kat, sıra; **açık
  şikayetler** (tür, tarih, açıklama) ve ayrı başlık altında **süresi
  dolmuş** olanlar.
* **"Süresi dolmuş" tanımı:** harita penceresinden (`sikayet_harita_saat`,
  P219) eski, hâlâ açık şikayet — haritada sayılmıyor. Önceden ayrıntı
  listesi bunları açık olanlarla karışık gösteriyor, başlıktaki sayı ile
  liste çelişiyordu. Sunucu yönetim listesine `suresi_doldu` işareti
  ekledi (haritayla aynı ayar, tek tanım; pencere 0 = süresiz → hiçbiri).
* **Şikayet edenin kimliği — ÖLÇÜLDÜ, DEĞİŞTİRİLMEDİ:** istek "yalnız
  yönetime görünsün (mevcut kural)" diyor; ölçülen mevcut kural daha
  sıkı: **Rev-2 gizlilik kararıyla kimlik hiçbir uçtan dönmüyor, yönetim
  dahil** (sunucu `include_complainant=False`; mobil testi bunu kilitliyor).
  Bir gizlilik kuralını bu turda sessizce gevşetmedim; yönetime açılması
  isteniyorsa ayrı karar gerekir. Web, alan dolu gelirse yine yalnız
  yönetim ekranında gösterir.
* **Mobil:** ayrıntı zaten açılır sayfadaydı (bottom sheet); "süresi
  dolmuş" ayrımı aynı başlıkla eklendi.
* **Testler:** sunucu `test_p251_sikayet_suresi.py` (işaret, süresiz
  pencere, kimlik hâlâ dönmüyor); web `p251-sikayet-haritasi.dom.test.ts`
  (pencere açılır, açık/dolmuş ayrı, Esc kapatır); mobil
  `building_schematic_test` (ayrı başlık, sıra). Mevcut harita testleri
  (134) yeşil; çift başlık testi pencere başlığına göre güncellendi.

# §4 — TABLOLAR: OKUNABİLİRLİK

## Ölçüm

* Başlık stili üç yerde elle yazılmıştı: ilkel `Th` (`TabloBasligi`
  12 px, ikincil renk, normal kalınlık, harf aralıklı), `VeriTablosu`
  başlık hücresi (aynısı) ve finans satır tablosu (12 px, üçüncül renk).
  Gerçek tarayıcıda: 12 px, `font-weight: 500`, gri.
* İçerik `max-w-7xl` (1280 px) ile sınırlı: 1920 px ekranda kenar
  çubuğundan sonra iki yanda ~190 px boşluk; çok sütunlu tablolar
  (içe aktarım, kullanıcılar, finans) yatayda kaydırılıyordu.
* İçe aktarım sayfası 1440 px'te sayfayı yatayda 290 px taşırıyordu.
  **Kök neden:** §1'de `Th`'ye eklediğim görünmez ekran okuyucu etiketi
  (`sr-only`, mutlak konumlu) konumlanmış bir atası olmadığı için tablonun
  kaydırma kabından kaçıp gövdeye göre yerleşiyordu. Bu benim §1
  gerilemem; `Th` artık `relative` (etiket hücreye bağlı). Düzeltmeden
  sonra 4 sayfada `scrollWidth == innerWidth`.

## Kararlar

* **Tek kaynak:** `tasarim-sistemi.css` → `.yz-tablo-baslik`: **kalın
  (600)**, `--yz-fs-sm` (Standart 13 px, **Büyük modda 16 px** — mod ile
  birlikte büyür), **ana metin rengi** (P160'ta ölçülmüş AA token; yeni
  renk icat edilmedi), harf aralığı yok, başlık satır kırmaz. `Th`,
  `VeriTablosu` başlığı ve finans satır tablosu bu sınıfı taşır;
  `TabloBasligi` artık yazı stili dayatmıyor (yalnız zemin).
* **Genişlik:** tablo ağırlıklı sayfalar (`lib/genis-sayfa.ts` listesi:
  daireler, kullanıcılar, sakinler, görevler, finans/*, aidat, raporlar,
  tanımlar, içe aktarım, acil durum, gönderim günlüğü, denetim, tesisler,
  demirbaş, araç geçişleri, davetler, talepler, bakım, vardiya) **1680
  px**'e kadar genişler. Özet, formlar ve okuma sayfaları P244/P245
  düzeninde (1280 px) kalır: uzun metin satırları geniş ekranda
  okunmaz olurdu. Ana alan `min-w-0`: geniş tablo ana alanı itmez,
  kendi kaydırma kabında kalır.
* **Gözden geçirilen, değiştirilmeyen:** satır yüksekliği (P244
  yoğunluk ayarı), sayısal sütunlar zaten sağa hizalı ve
  `tabular-nums`, satır üzerine gelince vurgu zaten var (yalnız
  `hover: hover` cihazlarda). Uzun metin: tablo kendi kabında yatay
  kayar; kelime ortasından bölmek (`overflow-wrap: anywhere`) dar
  sütunlardaki kısa kelimeleri de böleceği için eklenmedi.
* **Mobil:** tablolar yalnız web'de (mobil kart listeleri kullanıyor);
  bu bölümde mobil değişiklik yok.
* Vardiya döngüsü penceresindeki önizleme ızgarası gerekçeli istisna
  (pencere içinde sıkışık matris; büyük punto pencereyi taşırırdı).

## Kilit ve ölçüm

* `tests/p251-tablo-baslik.test.ts` (kaynak taraması): CSS sınıfı
  değerleri; `Th` ve `VeriTablosu` sınıfı taşıyor; `TabloBasligi` yazı
  stili dayatmıyor; `components/ui` dışında ham `<th>` yazan her dosya
  sınıfı taşıyor ya da gerekçeli istisnada.
* Gerçek Chromium (1920 px): geniş sayfalarda ana alan 1664 px, özette
  1280 px; başlık 13 px / 600 / ana metin rengi.

# §7 — Tanımlar menüsü tek giriş

## Karar

* Kenar çubuğunun Tanımlar bölümü 14 satırdan **3 satıra** indi:
  **Bloklar · İçe aktarım · Tanımlar**. Bloklar ve İçe aktarım ayrı
  sayfalar olduğu için kaldı. `/tanimlar` sayfasının 12 sekmesi (kasalar …
  ayarlar) artık yalnız sayfanın içindeki sekme şeridinde.
* **Derin bağlantı** değişmedi: `/tanimlar?defter=kasalar` doğrudan
  Kasalar sekmesini açar. Bağımlılık uyarıları, kurulum sihirbazı ve
  görevlerdeki "kategorileri düzenle" bağlantısı zaten sekmeyi veriyordu.
* **Arama:** sekmeler `TANIM_SEKMELERI` listesinde (sıra sayfanın
  `DEFTERLER` dizisiyle aynı). Sayfa araması bu listeyi menüye ek olarak
  tarar: "kasalar" yazan kullanıcı `/tanimlar?defter=kasalar` sonucunu
  alır. Görünürlük `/tanimlar` rotasının rol kapısından gelir; ikinci bir
  yetki kararı yazılmadı.
* Kayıt aramasında **firma** sonucu artık `/tanimlar?defter=firmalar`
  açıyor. Önceden sorgusuz `/tanimlar`'a gidiyor ve ilk sekmeye (Kasalar)
  düşüyordu.
* **Yardım:** ekran yardımı sayfa düzeyinde (`/tanimlar` → tek metin).
  Sekmeye özel yardım metni yok, bu yüzden bağlantının doğru sekmeyi
  açması diye bir durum doğmuyor.
* Herhangi bir sekmedeyken menüdeki "Tanımlar" satırı **aktif** görünür.
* Bölüm başlığı ile satırın adı aynı ("Tanımlar"): istekte geçen ad
  kullanıldı. P167 §1.6'daki "kendine işaret eden satır" itirazı, satırın
  12 sekmenin yanında durduğu düzen içindi. Bölüm adlandırması §8
  önerisiyle birlikte (onay bekliyor) yeniden ele alınacak.

## Mobil

Mobilde muhasebe defterleri yok (§8 tablosu: yalnız web). Mobil Tanımlar
grubundaki öğelerin her biri ayrı bir ekran, tek bir sayfanın sekmesi
değil. Bu yüzden aynı tekrar mobilde yok ve **mobilde değişiklik
yapılmadı**.

## Kilit

`tests/menu-gruplari.test.ts`:
* Tanımlar bölümü tam olarak 3 bağlantı içerir.
* `TANIM_SEKMELERI` sayfanın sekme sırasını izler.
* Sekmedeyken satır aktif kalır.

`tests/sayfa-aramasi.test.ts`: "kasalar" araması derin bağlantıyı
döndürür.

# §11 — Mobil ızgara: basılı tut, sürükle, bırak

## Davranış

* **Basılı tut**, karoyu kaldırır. Kart hafifçe büyüyüp gölgeyle yükselir, titreşim olur ve yerinde soluk bir iz kalır.
* **Sürükle**: başka bir karonun üstüne gelince diğer karolar yer açar. Bu canlı bir önizlemedir ve henüz kaydedilmez.
* **Bırak**: yeni sıra hesaba kaydedilir. Karo bir hedefin dışında bırakılırsa sıra geri alınır.
* **Kaydırmayla çakışmaz.** Kısa dokunuş karoyu açar. Sürükleme yalnız uzun basışta (`kLongPressTimeout`) başlar, yani sayfayı kaydıran parmak karoyu oynatmaz.
* **Büyük mod** (2 sütun, ilk 4 karo) ve **Standart** modda aynı şekilde çalışır. Görünen karolar listenin başı olduğu için taşıma tüm listede de aynı yeri gösterir.
* **Erişilebilirlik:** ekran okuyucu sürükleyemez. Her karoda "Yukarı taşı" ve "Aşağı taşı" özel eylemleri var (7 dil). İlk karoda "Yukarı", sonuncuda "Aşağı" eylemi yok.

## Kayıt: tek tercih, artık hesapta

* P139.3'te ızgara tercihi **cihazdaydı** (secure storage). İstek "yeni sıra hesaba kaydedilir" diyor. Kayıt sunucuya taşındı: `pano_tercihi.ana_ekran_izgarasi`, uçlar `GET`/`PUT /me/ana-ekran-izgarasi`.
* "Ana ekranı düzenle" ekranı ve sürükle-bırak **aynı kaydı** yazıyor; ikinci bir düzen kaydı yok. Aynı kullanıcı her telefonda aynı ızgarayı görür.
* Web Özet düzeni kaydedilirken (`PUT /me/pano-tercihi`) bu anahtar **korunur**, tıpkı P250'nin Hızlı İşlemler seçimi gibi. Mobil yazım da web düzenine ve Hızlı İşlemler'e dokunmaz.
* **Geçiş:** hesapta kayıt yoksa ve cihazda eski (P139) kayıt varsa, kayıt hesaba taşınır ve cihazdan silinir. Kimse düzenini kaybetmez. Uygulama açıldığında cihazda eski kayıt duruyorsa hesaptakinin yerine o geçer (bekleyen yazım sayılır). Bu yalnız bir kez olur.
* **Çevrimdışı:** yazma başarısız olursa seçim cihaza yazılır ve bir sonraki açılışta hesaba taşınır. Sıfırlama çevrimdışıyken yapılırsa yalnız cihazda geçerli olur ve hesaptaki kayıt yeniden gelir. Bu sınır kabul edildi.

## Ölçülen engel: menüde karşılığı olmayan kartlar

Kayıt menü girişi adlarını tutuyordu. Varsayılan ızgarada **5 rolde** menüde karşılığı olmayan kart var:

| Rol | Kart |
|---|---|
| Sakin | Şikayetlerim |
| Güvenlik | Araç plaka |
| Güvenlik amiri | Demirbaş |
| Admin | Görevler, Aidat durumu, Raporlar |

Yalnız giriş adlarıyla kaydetmek, bu kullanıcıların ilk sürüklemede o kartları **sessizce kaybetmesi** demekti. Çözüm: kayıt bu kartları `kart:<kimlik>` olarak tutar (sunucu deseni `^(kart:)?[A-Za-z][A-Za-z0-9]*$`, en çok 8 öğe). Gidiş-dönüş (kart → kayıt → kart) her rolde, düz ve ters sırada kayıpsız; test bunu kilitliyor.

"Ana ekranı düzenle" ekranı yalnız menü girişlerini listeler. O ekrandan kaydetmek `kart:` öğelerini düşürür; bu, P139'dan beri süren davranıştır.

## Web Özet karoları aynı tercih mi? Hayır, ayrı anahtar (aynı satır)

Web Özet kısayolları (`widgetlar`) **web sayfalarıdır** ve en çok 6 tanedir. Mobil ızgara ise **mobil menü girişleridir** ve en çok 8 tanedir. İki küme farklı rotalardan oluşuyor; birinin sırası ötekine anlamlı bir şekilde aktarılamaz. Biri ötekini ezmesin diye ikisi aynı `pano_tercihi` satırında ama ayrı anahtarlarda duruyor.

## Kilitler

* `backend/tests/test_p251_ana_ekran_izgarasi.py`:
  * sıralı kayıt, null ile varsayılana dönüş;
  * web ve mobil kayıtları birbirini ezmiyor;
  * geçersiz ad, `kart:` boş ya da 9 öğe → 422;
  * kayıt kişiye özel.
* `mobile/test/p251_izgara_surukle_test.dart` (18 test):
  * tüm rollerde gidiş-dönüş;
  * uzun bas ve sürükle; kısa dokunuş açar; dışarıda bırakınca geri alınır;
  * Büyük mod;
  * ekran okuyucu eylemleri;
  * hesaptan okuma; cihaz kaydının taşınması; çevrimdışı bekleme;
  * düzenleme ekranının aynı kayda yazması.
* Kilit kayıtları: openapi, `uc-guvenlik.tsv` (kendi), `rol-matrisi.txt`, IDOR istisnaları, denetçi salt-okuma istisnası (kişinin kendi görünümü).


# §8 — Menü yapısı (ONAYLANDI, düzeltmelerle)

Onaylanan: (1) Kişiler tek giriş + sekmeler, (2) maaş kartları Finans'a,
(3) Devriye tek sayfa, (4) yalnız-web listesi. Kullanıcının düzeltmeleri
aşağıdaki tabloya işlendi; tablo **uygulamadan önce** yazıldı.

## Yan yana tablo — yönetici (web tesis yüzeyi ↔ mobil yönetici)

Kaynak: `contracts/menu-paritesi.tsv` (tek kaynak; iki kilit de onu okur).
Grup sırası iki yüzeyde aynı: **Güvenlik · Tesis · Finans · İletişim ·
Kişiler · Tanımlar · Yönetim** (web'de en üstte Özet).

| Grup | Web adı | Mobil adı | Aynı mı | Gerekçe (farklıysa) |
|---|---|---|---|---|
| Özet | Özet (`/dashboard`) | — | menü dışı (yapısal) | Mobilde Özet ayrı bir menü öğesi değil, uygulamanın ana ekranının kendisi. |
| Güvenlik | Acil durum çağrıları (`/panik`) | Acil durum çağrıları (`panikTakip`) | ✓ aynı |  |
| Güvenlik | Kameralar (`/kameralar`) | Kameralar (`kameralar`) | ✓ aynı |  |
| Güvenlik | Kamera Kayıtları (`/kamera-kayitlari`) | Kamera Kayıtları (`kameraKayitlari`) | ✓ aynı |  |
| Güvenlik | Devriye (`/devriye`) | Devriye (`patrolTracking`) | ✓ aynı |  |
| Güvenlik | Vardiya planı (`/vardiya-plani`) | Vardiya planı (`vardiyalar`) | ✓ aynı |  |
| Güvenlik | Otopark ve araç geçişleri (`/arac-gecisleri`) | Otopark ve araç geçişleri (`otopark`) | ✓ aynı |  |
| Güvenlik | Olaylar ve ihlaller (`/olaylar`) | Olaylar ve ihlaller (`ihlaller`) | ✓ aynı |  |
| Güvenlik | Görüntüleme izni (`/goruntuleme-izni`) | Görüntüleme izni (`unitAccess`) | ✓ aynı |  |
| Güvenlik | Bildirimler (`/notifications`) | — | menü dışı (yapısal) | Mobilde bildirimler her ekranın üst çubuğundaki zil simgesinden açılır; menüye ikinci giriş koymak aynı ekrana iki yol olurdu. |
| Tesis | Daireler (`/units`) | — | menü dışı (yapısal) | Mobilde daire listesi Bina yapısı ekranının içindedir (blok → daire); ayrı liste ekranı yok. |
| Tesis | Görevler (`/tasks`) | Görevler (`taskTracking`) | ✓ aynı |  |
| Tesis | Bakım takibi (`/bakim`) | Bakım takibi (`bakim`) | ✓ aynı |  |
| Tesis | Demirbaş (`/assets`) | Demirbaş (`assets`) | ✓ aynı |  |
| Tesis | Şikayet Haritası (`/schematic`) | Şikayet Haritası (`sikayetHaritasi`) | ✓ aynı |  |
| Tesis | Rezervasyon (`/rezervasyon-yonetimi`) | Rezervasyon (`rezervasyon`) | ✓ aynı |  |
| Tesis | Dış hizmetler (`/dis-hizmetler`) | Dış hizmetler (`disHizmet`) | ✓ aynı |  |
| Tesis | Yerel işletmeler (`/yerel-isletmeler`) | Yerel işletmeler (`yerelIsletmeler`) | ✓ aynı |  |
| Tesis | Akıllı ev (`/akilli-ev`) | Akıllı ev (`akilliEv`) | ✓ aynı |  |
| Finans | Finansal özet (`/finans`) | Finansal özet (`financialSummary`) | ✓ aynı |  |
| Finans | Tahsilatlar (`/finans/tahsilatlar`) | Tahsilatlar (`tahsilat`) | ✓ aynı |  |
| Finans | Giderler (`/finans/giderler`) | Giderler (`gider`) | ✓ aynı |  |
| Finans | Borçlular (`/finans/borclular`) | Borçlular (`borclular`) | ✓ aynı |  |
| Finans | Otomasyon (`/finans/otomasyon`) | Otomasyon (`otomasyon`) | ✓ aynı |  |
| Finans | Bütçe (`/finans/butce`) | Bütçe (`budget`) | ✓ aynı |  |
| Finans | Sayaç okuma (`/sayac-okuma`) | Sayaç okuma (`sayacOkuma`) | ✓ aynı |  |
| Finans | Raporlar (`/raporlar`) | Raporlar (`reports`) | ✓ aynı |  |
| Finans | Şeffaflık (`/transparency`) | Şeffaflık (`transparency`) | ✓ aynı |  |
| Finans | Aidat (`/dues`) | — | yalnız web | Toplu aidat tahakkuku daire başına önizleme ve dağıtım seçimi ister; geniş tablo telefonda doğrulanamaz. Mobilde aidat planı Otomasyon'dan kurulur. |
| Finans | Borçlandırmalar (`/finans/borclandirmalar`) | — | yalnız web | Tek ve toplu borçlandırma aynı geniş önizleme tablosunu kullanır (Aidat ile aynı gerekçe). |
| Finans | Gelirler (`/finans/gelirler`) | — | yalnız web | Aidat dışı gelir kaydı kasa, kalem ve belge seçimi ister ve seyrek yapılır; mobilde günlük iş tahsilat ve gider kaydıdır. |
| Finans | Hesaplar arası virman (`/finans/virman`) | — | yalnız web | İki kasa arasında para taşır; yanlış girişin düzeltmesi ters kayıt ister. Muhasebe defteri işidir. |
| Finans | Ödeme iadesi (`/finans/iade`) | — | yalnız web | İade bir tahsilatın ters kaydıdır; özgün kaydı defterde bulup eşleştirmek geniş ekran ister. |
| Finans | Açılış fişleri (`/finans/acilis`) | — | yalnız web | Kurulumda bir kez girilen devir bakiyeleri; çok satırlı fiş. |
| Finans | Banka Entegrasyonu (`/finans/banka`) | — | yalnız web | Ekstre dosyası yükleme ve satır satır eşleştirme (P191). |
| Finans | Fazla mesai (`/finans/mesai`) | — | yalnız web | Haftalık hesap tablosu ve gider olarak işleme; kişi × hafta matrisi telefonda okunmaz. |
| Finans | Maaş kartları (`/finans/maas-kartlari`) | — | yalnız web | Ücret, giriş/çıkış tarihi ve kimlik bilgisi içeren kayıt; personel hesabı mobilde Kişiler'de açılır, maaş kartı ona bilgisayardan bağlanır. |
| Finans | İcra dosyaları (`/icra`) | — | yalnız web | Hukuki dosya: belge, safha ve tutar geçmişi. |
| İletişim | Duyurular (`/announcements`) | Duyurular (`announcements`) | ✓ aynı |  |
| İletişim | Site kuralları (`/site-kurallari`) | Site kuralları (`siteKurallari`) | ✓ aynı |  |
| İletişim | Etkinlikler (`/etkinlik-yonetimi`) | Etkinlikler (`etkinlik`) | ✓ aynı |  |
| İletişim | Anketler (`/anketler`) | Anketler (`anketler`) | ✓ aynı |  |
| İletişim | Talep / Arıza (`/complaints`) | Talep / Arıza (`complaints`) | ✓ aynı |  |
| İletişim | Gürültü uyarıları (`/gurultu-uyarilari`) | Gürültü uyarıları (`gurultuUyarilari`) | ✓ aynı |  |
| İletişim | SMS/E-Posta Yönetimi (`/mesajlar`) | — | yalnız web | Toplu SMS ve e-posta ücretlidir ve geri alınamaz; alıcı süzgeci ve gönderim önizlemesi geniş ekranda doğrulanır. |
| Kişiler | Kişiler (`/kisiler`) | Kişiler (`kisiler`) | ✓ aynı |  |
| Tanımlar | Bina yapısı (`/building-editor`) | Bina yapısı (`binaDuzenleme`) | ✓ aynı |  |
| Tanımlar | Tanımlar (`/tanimlar`) | Tanımlar (`tanimlar`) | ✓ aynı |  |
| Tanımlar | İçe aktarım (`/ice-aktarim`) | — | yalnız web | Excel ile yüzlerce satırın önizlemesi ve hata düzeltmesi telefonda yapılamaz (P204). |
| Yönetim | Tesis ayarları (`/tesis-ayarlari`) | Tesis ayarları (`tesisAyarlari`) | ✓ aynı |  |
| Yönetim | Entegrasyonlar (`/integrations`) | Entegrasyonlar (`integrations`) | ✓ aynı |  |
| Yönetim | Kurulum sihirbazı (`/kurulum`) | Kurulum sihirbazı (`kurulum`) | ✓ aynı |  |
| Yönetim | Dokümanlar (`/dokumanlar`) | Dokümanlar (`dokumanlar`) | ✓ aynı |  |
| Yönetim | Karar Defteri (`/karar-defteri`) | — | yalnız web | Resmî karar kaydı: madde metni, oy dağılımı ve ek belge düzenlemesi; yayımlanan karar sakine Dokümanlar'dan ulaşır. |
| Yönetim | KVKK tercihlerim (`/kvkk`) | — | menü dışı (yapısal) | Kişisel izin tercihi; mobilde Profil › Ayarlar'da durur (hesaba ait, siteye ait değil). |
| Yönetim | — | Bilgisayardan yapılanlar (`bilgisayardan`) | yalnız mobil | Yalnız web'de kalan işlemlerin listesi ve app.yonetiyor.com bağlantısı; web'de karşılığı o sayfaların kendisi. |

## Yan yana tablo — sakin (web sakin modu ↔ mobil sakin)

Web sakin modu (P247) başlıksız tek bölümdür; grup mobilde ölçülür.

| Grup | Web adı | Mobil adı | Aynı mı | Gerekçe (farklıysa) |
|---|---|---|---|---|
| Finans | Aidatım (`/aidatim`) | Aidatım (`myDues`) | ✓ aynı |  |
| İletişim | Duyurular (`/duyurular`) | Duyurular (`announcements`) | ✓ aynı |  |
| İletişim | Talep / Arıza (`/taleplerim`) | Talep / Arıza (`complaints`) | ✓ aynı |  |
| Tesis | Rezervasyon (`/rezervasyonlarim`) | Rezervasyon (`rezervasyon`) | ✓ aynı |  |
| İletişim | Etkinlikler (`/etkinlikler`) | Etkinlikler (`etkinlik`) | ✓ aynı |  |
| İletişim | Site kuralları (`/kurallar`) | Site kuralları (`siteKurallari`) | ✓ aynı |  |
| İletişim | Yönetimle iletişim (`/yonetim-iletisim`) | Yönetimle iletişim (`yoneticiIletisim`) | ✓ aynı |  |
| Güvenlik | Bildirimler (`/notifications`) | — | menü dışı (yapısal) | Mobilde üst çubuktaki zil simgesi (yönetici satırıyla aynı gerekçe). |
| Güvenlik | — | Ziyaretçiler (`visitors`) | yalnız mobil | Ziyaretçi kaydı kapıda anlık onay bildirimiyle çalışır; web sakin modu (P247) yöneticinin kendi dairesi için kısa yoldur, kapı akışı telefondadır. |
| Güvenlik | — | Kargo (`kargo`) | yalnız mobil | Kargo teslim bildirimi ve teslim alma onayı telefonda (ziyaretçi ile aynı gerekçe). |
| Güvenlik | — | Görüntüleme izni (`unitAccess`) | yalnız mobil | Sakinin onay/ret kararı anlık bildirimden açılır; yöneticinin isteği web'de de var (yönetici satırı). |
| Tesis | — | Şikayet Haritası (`sikayetHaritasi`) | yalnız mobil | Sakin kendi dairesinin şikayet durumunu görür; web sakin modu yöneticidir ve haritanın tamamını yönetici menüsünde zaten görür. |
| Tesis | — | Dış hizmetler (`disHizmet`) | yalnız mobil | Yönetici web'de aynı rehberi yönetici menüsünde (Tesis) yönetir; sakin modunda ikinci kopya gerekmez. |
| Tesis | — | Yerel işletmeler (`yerelIsletmeler`) | yalnız mobil | Dış hizmetler ile aynı gerekçe. |
| Tesis | — | Akıllı ev (`akilliEv`) | yalnız mobil | Cihaz komutu (kapı, ışık) telefondan verilir; yönetici web'de tüm cihazları yönetici menüsünde görür. |
| Finans | — | Site Bütçesi (`siteBudget`) | yalnız mobil | Yönetici web'de bütçenin kendisini (Finans › Bütçe) yönetir; sakine gösterilen özet onun salt okunur hâlidir. |
| Finans | — | Şeffaflık (`transparency`) | yalnız mobil | Yönetici web'de Şeffaflık'ı Finans grubunda yayımlar; sakin modunda ikinci kopya gerekmez. |
| İletişim | — | Anketler (`anketler`) | yalnız mobil | Yönetici web'de anketi açar ve sonuçları görür; oy verme sakinin telefonundan. |
| Yönetim | — | Dokümanlar (`dokumanlar`) | yalnız mobil | Yönetici web'de Dokümanlar'ı yönetir; sakin modunda ikinci kopya gerekmez. |

Güvenlik amiri, güvenlik görevlisi ve tesis görevlisinin web yüzeyi yok
(P129, P248: saha rolleri mobil-yalnız); karşılaştırma bu yüzden iki çift
üzerinden yapılır.

## Kullanıcının düzelttiği ilke ihlalleri — karar

| Konu | Önce | Karar |
|---|---|---|
| Akıllı ev | web Güvenlik / mobil Tesis | **Tesis** (iki yüzey). Binanın ve dairelerin cihazları; sakin de kullanır. Güvenlik grubu güvenlik operasyonudur. |
| Şeffaflık | web Yönetim / mobil Finans | **Finans** (iki yüzey). Anonim aylık finans özetidir. |
| Araç geçişleri / Otopark | iki ad, iki ekran | **Tek modül, tek ad: "Otopark ve araç geçişleri".** Aynı veri: geçiş kayıtları (ANPR) ve onlardan sayılan doluluk. Web sayfasının üstüne doluluk özeti eklendi; mobil ekran doluluğu gösterir ve yetkili role geçiş listesini açar. Güvenlik amirinin "Araç plaka" girişi de aynı adı alır. |
| Talepler / Talep / Arıza | iki ad | **"Talep / Arıza"** (web yönetici + sakin modu, mobil). |
| Rezervasyon yönetimi / Rezervasyon | iki ad | **"Rezervasyon"**. Sakinin sayfası da aynı adı taşır (web "Rezervasyonlarım" → "Rezervasyon"). |
| Mobil Güvenlik'te Kameralar | yok (yalnız Ayarlar'da) | **Eklendi.** Mobil canlı izleme ekranı vardı ama yalnız Ayarlar'dan açılıyordu; Güvenlik grubuna taşındı, Ayarlar'daki kopya kalktı. |
| Web'de İhlaller | `/olaylar` vardı, yalnız admin'e açıktı | **Web'de var, yöneticiye açıldı.** Aynı modül (`/violations`): ad iki yüzeyde **"Olaylar ve ihlaller"**. Sunucu kuralı değişmedi: yönetici okur ve izler, kaydı güvenlik/admin açar. |
| Web'de Görüntüleme izni | yok | **Web'e eklendi** (`/goruntuleme-izni`): yönetici tek daire / toplu izin ister, durumu izler, onaylanan dairenin kayıtlarını bir kez görür. Sakinin onay/ret kararı mobilde kalır (anlık bildirim). |
| Kişiler | — | Sekmeler role göre: güvenlik amiri yalnız **Personel** sekmesini ve yalnız güvenlik personelini görür (P231); sakin modunda Kişiler görünmez. |
| Devriye | — | Sekmeler role göre: güvenlik görevlisi yalnız **takibi** (kendi turları) görür; NFC noktaları ve planlar yönetim ve amir içindir. |

Diğer ad birleştirmeleri (ilke gereği): "Bloklar" → **Bina yapısı**;
"Rapor motoru" → **Raporlar** (eski tek raporluk `/reports/dues` menüden
çıktı, adresi çalışır); "Finans" → **Finansal özet**; "Görev yönetimi" →
**Görevler**; "Tahsilat" → **Tahsilatlar**; "Gider kaydı" → **Giderler**;
"Aylık raporlar" → **Raporlar**; "Devriye takibi" → **Devriye**;
"Yönetici iletişim" / "Yönetim iletişim" → **Yönetimle iletişim**;
"Doküman yönetimi" / "Site dokümanları" → **Dokümanlar**.

## Maaş kartı ↔ personel hesabı ↔ fazla mesai (değerlendirme)

Ölçüm:
* Sunucuda bağ **zaten var**: `personel_kayit.app_user_id` (isteğe bağlı;
  hesap silinirse kart durur — bordro geçmişi kimliğe bağlı olmamalı).
* Fazla mesai (P203/P214) **saatleri hesaptan** (vardiya/mola kayıtları
  `app_user`a bağlı) alır, **ücreti maaş kartından** alır: `app/routers/
  mesai.py` kişiyi `PersonelKayit.app_user_id` üzerinden bulur. Bağ yoksa
  kişi "ücret tanımsız" görünür ve mesai tutarı hesaplanmaz.
* **Kusur:** web formunda bağ alanı **yoktu**. Yani yönetici kartı hesaba
  bağlayamıyor, mesai ekranı ücret bulamıyordu; aynı kişiyi iki kez
  (hesap + kart) yazmak zorundaydı.

Karar: **ikisi ayrı kayıt kalır, isteğe bağlı bağlanır.**
* Ayrı kalma gerekçesi: her personelin hesabı yoktur (temizlik, bahçıvan)
  ve her hesap personel değildir; kartta TC, ücret, giriş/çıkış tarihi
  gibi hesapta olmaması gereken bilgiler durur.
* Maaş kartı formuna **"Uygulama hesabı"** seçimi eklendi (saha personeli
  hesapları). Seçilince ad, telefon ve e-posta hesaptan **doldurulur**, tekrar
  yazılmaz.
* Kişiler › Personel'de her satırda maaş kartı durumu ve **"Maaş kartı
  oluştur"** eylemi (bağlı ve dolu açılır). Fazla mesai ekranında "ücret
  tanımsız" satırından da aynı yere gidilir.
* Kurulum sihirbazının "personel" adımı artık **hesabı** (saha personeli)
  sayar; maaş kartı isteğe bağlı finans adımıdır.

## Eski adresler ve derin bağlantılar

| Eski (web) | Yeni |
|---|---|
| `/users` | `/kisiler?sekme=personel` (`?rol=resident` → `sekme=sakinler`) |
| `/residents` | `/kisiler?sekme=sakinler` |
| `/davetler` | `/kisiler?sekme=davetler` |
| `/checkpoints` | `/devriye?sekme=noktalar` |
| `/patrol-plans` | `/devriye?sekme=planlar` |
| `/reports/patrols` | `/devriye?sekme=takip` |
| `/tanimlar?defter=personel-kayitlari` | `/finans/maas-kartlari` |

Mobil: `/personel`, `/sakinler`, `/davetler` → Kişiler ekranının ilgili
sekmesi; `/patrol-plans`, `/checkpoints` adresleri aynen çalışır.
Bildirim yönlendirmeleri (web `lib/bildirim-rotasi.ts`, mobil push
yönlendirmesi) yeni adreslere güncellendi; eski adresler de yönlendirmeyle
açılmaya devam eder.

## Kilit

`contracts/menu-paritesi.tsv` + iki test:
* `admin-web/tests/p251-menu-paritesi.test.ts`: web yönetici menüsü ve
  sakin modu tablodaki satırlarla **birebir** (grup + Türkçe ad); tabloda
  olmayan web öğesi, ya da tabloda web'i olan ama menüde olmayan satır
  düşer.
* `mobile/test/p251_menu_paritesi_test.dart`: aynısı mobil yönetici ve
  sakin menüsü için; ayrıca "Bilgisayardan yapılanlar" listesi tablodaki
  `yalniz_web` satırlarının tamamını içerir.
* Gerekçesiz farklı satır tablonun kendisinde reddedilir (`ayni` dışındaki
  her satırda gerekçe zorunlu).
