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

