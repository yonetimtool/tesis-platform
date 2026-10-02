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

