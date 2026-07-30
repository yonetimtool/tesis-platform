# Ölçülmeyen durumlar — üçüncü envanter (tur 62)

**Tarih:** 2026-07-30 · **Kapsam:** mobil (Flutter) + panel (admin-web) + veri + backend

Tur 36'nın envanteri (A–F) tur 37–48'de, tur 49'un envanteri (A–F) tur 50–61'de
**kapatıldı**. Bu belge o kapanıştan sonra kalanları listeler. Yine tahmin yok:
her madde kapsam verisinden, canlı sayfadan, veritabanı sayımından ya da
araçların kendi kodundan geliyor.

**Sayılar (ölçüldü, 2026-07-30):**

| Ölçü | Değer | Not |
|---|---|---|
| Mobil `presentation` satır kapsamı | **9 411 / 13 373 = %70,4** | tur 49'da %67,7 |
| Mobil `lib/src` tümü | 16 782 / 27 317 = %61,4 | |
| Mobil test | 1 216 | tur 49'da ~1 100 |
| Backend test | 762 | |
| Panel birim test | 105 | |
| Panel sayfası sürüş listesinde | **26 / 26** | `/tenants/[id]` tur 61'de eklendi |
| Sürülmemiş mobil ekran | **0 / 47** | her ekran en az bir testte anılıyor |

---

## A. Denetleyiciler (controller) — kapsam açığının yeni merkezi ✔ **KAPANDI (tur 63 + 65)**

Ekranlar sürülüyor, ama **denetleyicilerin dalları** sürülmüyor. Sürüşler API'yi
sahteliyor ve sahte **başarı** dönüyor; hata/yeniden dene/iptal/eşzamanlılık
dalları karanlıkta kalıyor. En düşük kapsamlı `presentation` dosyaları (≥25
satır) neredeyse tamamı denetleyici:

| Dosya | Kapsam | Ne ölçülmüyor |
|---|---|---|
| `nfc/presentation/nfc_controller.dart` | **7 / 27 = %26** | NFC durum makinesi (tarama başlat/iptal/hata) |
| `patrol/presentation/patrol_tracking_screen.dart` | 52 / 189 = %28 | canlı tur takibi, konum akışı |
| `assets/presentation/assets_controller.dart` | 39 / 139 = %28 | zimmet ver/al, NFC okut, hata dalları |
| `nfc/presentation/nfc_screen.dart` | 63 / 189 = %33 | okuma ekranı halleri |
| `complaints/presentation/complaints_controller.dart` | 48 / 136 = %35 | talep oluştur/çöz/reddet akışı |
| `settings/presentation/settings_screen.dart` | 46 / 129 = %36 | ayar yazma yolları |
| `tasks/presentation/task_complete_controller.dart` | 64 / 134 = %48 | görev tamamlama + foto yükleme dalları |
| `tasks/presentation/task_categories_screen.dart` | 52 / 106 = %49 | kategori CRUD |
| `tasks/presentation/tasks_controller.dart` | 37 / 75 = %49 | |
| `patrol/presentation/patrol_plans_screen.dart` | 129 / 247 = %52 | |

**Neden şimdiye kadar görülmedi:** bütün sürüş yardımcıları (`tumEksenlerSurusu`,
`fotografliSurus`, `eksenKombinasyonSurusu`…) *çizim* odaklı — ekranı boyar,
taşma/kontrast/etiket/sıra ölçer. Bir düğmeye basıp **sonucun** doğru olduğunu
ölçen tek yer tur 50'nin eylem zincirleri ve o da hata dallarına girmiyor.

## B. Seed'de HİÇ VERİ OLMAYAN modüller — sayfa boş ölçülüyor ✔ **KAPANDI (tur 62)**

Dev veritabanında **dört tablo tamamen boş** (49 tablodan):

| Tablo | Etkilenen sayfa/ekran | Kanıt |
|---|---|---|
| `asset` | panel `/assets`, mobil demirbaş | canlı sayfa: "Demirbaş yok · **Toplam 0**" |
| `asset_checkout` | zimmet geçmişi | 0 kayıt |
| `dis_hizmet` | mobil dış hizmet ekranı | 0 kayıt |
| `integration` | panel `/integrations` | canlı sayfa boş liste |

`/assets` **yedi** sürüş listesinde var ve yedisi de **boş sayfayı** ölçüyor:
satır/rozet/eylem kodlarına hiç uğranmıyor. Bu tam olarak tur 34/35'in ürün
hatası çıkardığı kör nokta sınıfı (fotoğrafsız veri) — bu kez "kayıtsız liste".

Seed `scripts/seed.py` içinde `asset`/`dis_hizmet`/`integration` için **tek bir
INSERT yok** (arandı, 0 sonuç).

## C. Panel sürüşlerinin dördü kendi kendini sınamıyor ✔ **KAPANDI (tur 62)**

`DENEY=1` kipi (kasıtlı kusur enjekte et → görülüyor mu?) on araçtan **altısında**
var, dördünde yok:

| Araç | `DENEY` | Risk |
|---|---|---|
| `okuyucu-surusu.mjs` | **yok** | 350 koşumluk en büyük sürüş; ölçmediğini kanıtlayan hiçbir şey yok |
| `hata-surusu.mjs` | **yok** | 4 kip × hata enjeksiyonu — kip gerçekten uygulanıyor mu? |
| `rapor-surusu.mjs` | **yok** | rapor formu gönderiliyor mu? |
| `durum-envanteri.mjs` | **yok** | sayaçlar doğru mu (kart selector'ı `/announcements`te 0 sayıyor) |

Tur 59'un dersi tam buydu: dedektörü sınamayınca "temiz" raporu hiçbir şey
söylemiyor. `dar-ekran`, `tr-sizinti`, `okuma-sirasi`, `foto`, `mutasyon`,
`klavye` sınanıyor; bu dördü sınanmıyor.

> **Kuşku çözüldü (aynı tur).** `/announcements` gerçekten **iki** duyuru kartı
> taşıyor; selector doğru çalışıyordu. Kusur **eşikteydi**: "verisiz" kararı
> `satır === 0 && kart <= 2` idi ve kart kullanan sayfaları yanlış
> sınıflandırıyordu. Yeni `oge` ölçüsü (`tbody tr` + `li` + `article`) eklendi;
> "verisiz" artık `oge === 0`. Liste 6 → **7** sayfaya çıktı ve içeriği
> değişti — ama üçü (`/building-editor`, `/schematic`, `/transparency`) kendi
> yerleşimini çiziyor, üçü `/reports/*` form gönderimi istiyor, biri
> (`/settings`) form sayfası: yani hiçbiri veri boşluğu değil. Araç bu uyarıyı
> artık **çıktısında** basıyor: liste bir *aday* listesidir.

## D. Backend'de ölçülmeyen: saklanan metnin dili ✔ **KAPANDI (tur 62)**

Tur 62'de **bir ürün hatası** bulundu ve düzeltildi: `/dashboard/live`, alarm
metnini `notification.mesaj` (tur 16'da **deprecated** edilmiş Türkçe özet)
kolonundan dönüyordu; `/notifications` ise doğru şekilde
`mesaj_kimlik` + `mesaj_veri`den okuma anında üretiyordu. Sonuç: panonun alarm
listesi **altı dilde Türkçe** görünüyordu.

**Bunu tur 61'de yanlış sınıflandırmıştım:** TR sızıntı sürüşü metni gördü, ben
"backend verisi, ayrı tasarım kararı" diye kaydettim. Oysa tasarım zaten
doğruydu — kusur tek bir uçtaydı. Ders: "veri" etiketi bir bulguyu kapatmanın en
kolay yolu ve bu yüzden en tehlikeli olanı.

**Kalan soru (ölçülmedi):** `mesaj` kolonunu okuyan başka tüketici var mı? Kod
taraması `activity.py`nin bilinçli olarak kullanmadığını gösteriyor
(yorumla yazılmış), `complaints.py`teki `mesaj` farklı bir alan. Mobil
`/notifications` üzerinden gidiyor. Yani bilinen tüketici kalmadı — ama bu
**kod okuma**, ölçüm değil.

## E. Hâlâ kurulmamış kalite eksenleri ✔ **İKİSİ KAPANDI (tur 64)**

* ~~**Eşzamanlılık / yarış.**~~ **KAPANDI (tur 64)** — rezervasyonda 409 yarışı
  ölçüldü ve bir tutarsızlık bulundu (aşağıda). Demirbaş 409'u tur 63'te
  ölçülmüştü.
* ~~**Çevrimdışı kuyruk davranışı.**~~ **KAPANDI (tur 66)** — uzun kesinti,
  yeniden bağlanma, çakışma ve geri çekilme ölçüldü (aşağıda).
* ~~**Bellek/kare bütçesi gerçek cihazda.**~~ **BELLEK KAPANDI (tur 67)** —
  ve "gerçek cihaz gerekir" iddiam **yanlıştı**: çözme süreç içinde ölçülebiliyor
  (aşağıda). Kare bütçesi (jank) ölçümü hâlâ cihaz gerektiriyor.
* ~~**Erişilebilirlik: odak GÖRÜNÜRLÜĞÜ.**~~ **KAPANDI (tur 64)** — yeni araç
  `tools/odak-gorunurlugu-surusu.mjs`; 102 ihlal bulundu, 0'a indirildi.

## F. Veri durumu — kalan boşluklar

| Durum | Şu an | Not |
|---|---|---|
| `asset` / `asset_checkout` | ~~0~~ → **4 / 2** | tur 62'de seed'e eklendi (üç durum + açık/kapalı zimmet) |
| `dis_hizmet` | ~~0~~ → **3** | tur 62 |
| `integration` | ~~0~~ → **3** (2 aktif + 1 pasif) | tur 62; veriyle ilk sürüşte 2 kontrast ihlali çıktı |
| `user_device` | 0 kayıt | push hedefi yok; push testleri sahte kanal kullanıyor (bilinçli) |
| `payment_webhook_event` | 0 kayıt | webhook akışı yalnız pytest'te (bilinçli) |
| tesis sayısı | 11 | tur 61'de 101'den indi; artık büyümüyor |

## Kör nokta OLMAYANLAR (bilerek dışarıda)

* Para biçimi (TL + Türkçe gruplama) dile duyarsız — politika.
* `data/*_api.dart` düşük kapsam — sürüşler API'yi bilerek sahteliyor.
* CSV kolon **başlıkları** ASCII/Türkçe (`Tahakkuk_TL`, `Baslangic`) — makine
  okunur kolon kimliği kabul edildi; değerler tur 61'de çevrildi.
* Piksel golden regresyonu — yerine yerleşim kilidi kuruldu (tur 60).

## Öneri sırası (etkiye göre)

1. ~~**Seed'e demirbaş + dış hizmet + entegrasyon verisi**~~ **YAPILDI (tur 62)**.
2. ~~**Sınanmayan dört sürüşe `DENEY` kipi**~~ **YAPILDI (tur 62)** — özellikle 350 koşumluk
   `okuyucu-surusu`; ve `durum-envanteri`nin kart sayacındaki kuşkuyu çöz.
3. **Denetleyici dalları** (A) — hata/iptal/yeniden dene yolları; kapsam
   açığının merkezi.
4. Eşzamanlılık ve odak görünürlüğü (E).

---

## Tur 62'de kapatılanlar (aynı turda)

Envanter yazıldıktan sonra 1. ve 2. öneri uygulandı; ikisi de ürün hatası
çıkardı.

**B — seed'e demirbaş / dış hizmet / entegrasyon verisi.** `asset` (4 kayıt, üç
durum), `asset_checkout` (biri açık biri kapalı zimmet), `dis_hizmet` (3),
`integration` (2 aktif + 1 pasif) eklendi. Seed idempotent (ikinci koşumda
sayılar sabit) ve `tazelik:` denetimine beş satır daha girdi.

`/integrations` **veriyle ilk kez** sürülünce **iki kontrast ihlali** çıktı ve
ikisinin de kökü aynıydı: pasif satır durumunu **`opacity-60`** ile
belirtiyordu. Açık temada satır hücreleri (`text-slate-600`, 6×), koyu temada
sil düğmesi WCAG AA'nın altına düşüyordu. Aynı kalıp **dört sayfada** vardı
(`/tasks`, `/assets`, `/users`, `/integrations`); hepsinde `opacity-60` yerine
hafif zemin tonu (`bg-slate-50`) kullanıldı — durum zaten "Aktif" kolonunda
metinle de veriliyor, yani bilgi kaybı yok.

**C — sınanmayan dört sürüşe `DENEY` kipi.** `okuyucu-surusu` (alt'sız görsel →
axe `image-alt`; Türkçe `aria-label` → TR sızıntı), `hata-surusu` (uyarı
düğümleri silinir → "SESSİZ HATA" kuralı), `rapor-surusu` (sonuç satırları
silinir → "SONUÇ YOK" kuralı), `durum-envanteri` (veri öğeleri silinir → hepsi
verisiz görünmeli). Dördü de OK.

Bu sınamalar iki şey daha buldu: (1) `okuyucu-surusu`nun TR kuralı ilk denemede
**KÖR** çıktı — çünkü kural yalnız `tr` dışı dillerde koşuyor, ben `DENEY`
dilini `tr` seçmiştim; deney dili `en` yapıldı. (2) `durum-envanteri`nin eşik
kusuru (yukarıda).

**Ek: statik taramanın üçlü kuralında kusur.** `/integrations` satırındaki
`{it.aktif ? "Evet" : "—"}` sızıntısı görünmüyordu. Sebep: nesne-anahtarı
sezgim (`ad: "x"` atla) **her iki operatöre** uygulanıyordu ve üçlünün **ilk**
dalı (`koşul ? "TR"`) daima bir tanımlayıcıdan sonra geldiği için her zaman
atlanıyordu. `?` öncesinde anahtar olamaz; kontrol yalnız `:` için anlamlı.
Düzeltilince **5 sızıntı** daha çıktı (`evet` ×2, `Evet` ×2, `(birincil)`).

**Ek: `/tenants/[id]` kimlik seçimi kırılgandı.** İlk sürüm "kurulumu
tamamlanmış ilk tesis"i seçiyordu; tur 61'de 100 test artığı silinince aday
kümesi değişti ve sürüş **yöneticisi olmayan** bir tesise düştü —
`okuma-sirasi-surusu` haklı olarak "yalnız 2 metin ögesi — ölçüm boş" dedi.
Artık adayların detayı okunup **yöneticisi olan** tesis seçiliyor.

**D — pano alarm metni.** `/dashboard/live` deprecated `mesaj` kolonunu
dönüyordu; `mesaj_kimlik` + `mesaj_veri`den okuma anında üretmeye çevrildi ve
`test_dashboard.py` içinde üç dilde kilitlendi (aynı kayıt → üç ayrı metin, ve
İngilizce yanıtta Türkçe kalmadığı ayrıca doğrulanıyor).

**Ölçümler (tur 62):** TR sızıntı 144/0 · dar-ekran 425/0 (dar+büyük yazı +
360dp bandı) · okuma sırası 50/0 · klavye 50/0 · **okuyucu tam koşum 350/0**
(düzeltme öncesi 13 kontrast ihlali) · backend **763** test · panel birim
105/105 · mobil 1216 test.

**Sırada (A ve E):** denetleyici dalları (kapsam açığının merkezi) ve
eşzamanlılık + odak görünürlüğü.

---

## Tur 63'te kapatılanlar (A maddesi — dört denetleyici)

Denetleyiciler **widget çizmeden** sürüldü: `ProviderContainer` + sahte API/servis
ile doğrudan durum geçişleri ölçülüyor. Bu, sürüş yardımcılarının yapamadığı şey
— onlar ekranı boyar, karar dallarına girmez.

| Dosya | Önce | Sonra | Test |
|---|---|---|---|
| `nfc_controller` | %26 | **%96,3** | 7 |
| `assets_controller` | %28 | **%98,6** | 22 |
| `complaints_controller` | %35 | **%93,4** | 21 |
| `task_complete_controller` | %48 | **%99,3** | 22 |

Ölçülen dal sınıfları: ağ / ağ-dışı hata ayrımı (mesaj kanalı vs kimlik
kanalı), beklenmeyen hata, **409 yarışı** (başkası aldı → kart taze durumla
yeniden çizilir; tazeleme de patlarsa kart eski kalır, çökme yok), 403 →
`forbidden`, çevrimdışı, yeniden-girme kilitleri (eşzamanlı iki çağrı → tek
istek), iptal/vazgeçme, yeniden dene, 3-yuva sınırı, foto **zorunlu** kapısı ve
"foto henüz yüklenmedi" kapısı (ikisi de **sunucuya gitmeden** durdurur — istek
sayacıyla doğrulandı), `onDispose`ta NFC oturumunun bırakılması (tur 37'nin ürün
hatasının nöbetçisi).

**Test yazarken öğrenilen üç şey — hepsi ölçümü sessizce bozabilirdi:**

1. **Dinleyicisiz `ProviderContainer` ölçmüyor.** `build()` içindeki
   `Future.microtask` dinleyicisi olmayan sağlayıcıda `ref.mounted == false`
   görüp **durumu yazmadan** dönüyor; ayrıca sağlayıcı okumalar arasında yeniden
   kurulup durumu sıfırlıyor (bir foto yuvası "kayboldu" sanıldı). Kap artık her
   sağlayıcıyı dinliyor.
2. **`retry` fotoğrafı YOLDAN yeniden okuyor.** Uydurma yol verilirse tekrar
   deneme daima genel hataya düşer. Testte gerçek geçici dosya kullanılıyor — ve
   bu arada bir **ürün davranışı** kayda geçti: geçici dosya silinmişse kullanıcı
   "dosya artık yok" değil "yüklenemedi" görüyor.
3. **`submit` başarı dalı liste rozetini güncelliyor** (`markCompleted`); gerçek
   liste denetleyicisi kendi bağımlılıklarını istediği için test patlıyordu.
   Sahte denetleyici hem patlamayı önlüyor hem rozet güncellemesini doğruluyor.

**Sayılar:** mobil test **1 216 → 1 288**; `presentation` kapsamı
**%70,4 → %72,4**; `lib/src` %61,4 → %62,4; `flutter analyze` temiz.

**Kalan (A):** `patrol_tracking_screen` (%28), `settings_screen` (%36),
`task_categories_screen` (%49), `patrol_plans_screen` (%52) — bunlar ekran, yani
denetleyici deseni doğrudan uygulanmıyor; canlı tur takibi konum akışı
gerektiriyor.

---

## Tur 64'te kapatılanlar (E maddesi — odak görünürlüğü + eşzamanlılık)

### Odak görünürlüğü: 102 → 0

`globals.css` bütün etkileşimli ögelere teal bir `outline` veriyordu, yani
"odak halkası var" sanılıyordu. Yeni sürüş (`tools/odak-gorunurlugu-surusu.mjs`)
**klavyeyle** TAB gezinip her aktif ögede üç şeyi ölçüyor: halka var mı, halka
rengi arkasındaki zeminle **3:1** (WCAG 1.4.11) tutuyor mu, ve halka
`overflow` kapsayıcısında **kırpılıyor** mu. Sonuç 25 sayfa × 2 tema:
**102 ihlal**, üç kök neden:

| Kök neden | Adet | Düzeltme |
|---|---|---|
| Halka kırpılıyor (kenar çubuğu, tablo kapsayıcıları, rapor sekmeleri) | 88 | `.odak-ic` → halka **içe** çizilir (`outline-offset: -2px`) |
| Teal zeminde teal halka (`/login` gönder, şematik daire kartları) | 5+ | `.odak-ters` → beyaz halka |
| Koyu temada ton yetersiz (2.83:1) | 14 | koyu temada açık teal `#2cc4b7` |

Düzeltirken **CSS özgüllük tuzağı** çıktı: `.dark button:focus-visible` (0,2,1)
`.odak-ters:focus-visible`i (0,2,0) yeniyordu, yani koyu temada beyaz halka
teale dönüyordu — sürüş bunu 2.38/2.53 kontrastla gösterdi. `.dark
.odak-ters:focus-visible` eklendi.

**Ve dedektörün kendi sınaması ölçümün geçersiz olduğunu gösterdi.** İlk sürümde
odağı `el.focus()` ile veriyordum; `DENEY=1` "KOR" dedi. Sebep: Chromium
`:focus-visible`i **programatik** odakta (metin alanları dışında) uygulamıyor —
yani `globals.css`teki halka hiç devreye girmiyordu ve ölçtüğüm şey tarayıcının
varsayılan çizgisiydi. Odak artık `Tab` tuşuyla veriliyor (tur 33'ün klavye
sürüşüyle aynı yol). Bu, "detektörü sınamasan ölçüm yaptığını sanırsın"
dersinin en net örneği: araç çalışıyor **görünüyordu** ve iki gerçek bulgu bile
üretmişti.

### Eşzamanlılık: rezervasyonda bir tutarsızlık

Ölçüm (`test/rezervasyon_yaris_dallari_test.dart`, 11 test): iki kullanıcı aynı
slotu isteyince ikincisi 409 alıyor. İstemci hatayı doğru şekilde yukarı
fırlatıyordu **ama listeyi tazelemiyordu** — yani yarışı kaybeden kullanıcı
slotun artık dolu olduğunu görmüyor, ızgara eski hâliyle kalıyordu. `cancel`
aynı sınıf durumu `finally` ile çözüyordu; `request` çözmüyordu. Düzeltildi:
`request` artık başarısızlıkta da tazeliyor (hata yine çağırana fırlıyor).

Ayrıca ölçülen dallar: saha rolü `/reservations` isteğini **hiç atmıyor** (403
savunması), yeniden-girme kilidi, alan CRUD'unun her birinin ardından tazeleme.

---

## Tur 65'te kapatılanlar (A maddesinin ekran kısmı)

Tur 63 denetleyicileri kapatmıştı; kalan dört dosya **ekran**dı ve hepsi zaten
"sürülüyordu" — ama yalnız **açıldığı hâlde**. Ölçüm gösterdi ki asıl kod
sekmelerde, alt sayfalarda ve diyaloglarda:

| Dosya | Önce | Sonra | Ne eksikti |
|---|---|---|---|
| `patrol_tracking_screen` | %28 | **%88,9** | üç sekmeden ikisi hiç açılmıyordu; `_WindowCard`ın beş durum dalından dördü karanlıktı |
| `settings_screen` | %36 | **%98,5** | dil alt sayfası açılmıyor, tema segmenti değişmiyor, tesis adı kaydetme (3 dal) koşmuyor, rol kapıları tek rolle ölçülüyordu |
| `task_categories_screen` | %49 | **%88,7** | ekle/sil diyalogları, iptal dalı, boş ad dalı, API hatası |
| `patrol_plans_screen` | %52 | **%89,5** | plan formu (yeni + düzenle), periyot doğrulaması, nokta ataması ve **sırası**, silme onayı + hata |
| `patrol_history_view` | — | %80,6 | ikinci sekme açılınca birlikte kapsandı |

**Ölçülen davranışlar (çizim değil, sonuç):** hangi API hangi argümanla
çağrıldı, liste tazelendi mi, hangi mesaj çizildi, ve **istek atılmaması
gereken yerlerde atılmadı mı**. Üç kapı bu şekilde kilitlendi: boş tesis adı,
boş kategori adı, ve pozitif olmayan devriye periyodu — üçü de sunucuya
gitmeden duruyor ve testler istek sayacına bakıyor.

Nokta atamasında **sıra** ayrıca doğrulanıyor: `setCheckpoints` listedeki sırayı
değil **seçim sırasını** gönderiyor (kullanıcı turun gezinme sırasını böyle
belirliyor).

**Sayılar:** mobil test **1 288 → 1 329**; `presentation` kapsamı
**%72,4 → %75,0** (tur 62'de %70,4); `lib/src` %63,5.

**İki test yazım tuzağı:** (1) `settings_screen`in tema kartı listenin altında
kalıyor ve varsayılan 800×600 görüntüde `ListView` onu **hiç kurmuyor** — tembel
liste; görüntü büyütülmeden ölçüm boş koşuyordu. (2) `TabBarView`in bir çocuğu
yalnız **sekmeye dokununca** kuruluyor; sekmeyi programatik seçmek yetmiyor.

---

## Tur 66'da kapatılanlar (E — çevrimdışı kuyruk)

Mevcut `scan_outbox` testleri tek kayıt / tek hata üzerineydi. Yeni dosya
(`test/cevrimdisi_kuyruk_senaryo_test.dart`, 12 test) senaryoyu ölçüyor:

* **Pil/veri koruması:** tek pump turunda ilk ağ hatasından sonra sıradakiler
  denenmiyor (istek sayacıyla).
* **Yeniden bağlanma:** kuyruk FIFO sırayla tamamen boşalıyor; yeni oturum
  diskteki kuyruğu devralıyor.
* **Çakışma:** kesinti sırasında sunucu kaydı zaten almışsa (200 duplicate)
  kayıt `gönderildi` + `duplicate` oluyor — kullanıcıya hata değil "gönderildi".
* **Karışık kuyruk:** kalıcı hata (404) turu **kesmiyor**, geçici hata
  **kesiyor**.
* **401 kalıcı değil:** oturum dönünce gönderiliyor.
* **Yeniden girme:** pump sürerken gelen ikinci pump kaybolmuyor.

**İki şeyi burada öğrendim, ikisi de ölçümü yanlış yapmama neden olmuştu:**

1. **Her `enqueue` kendi pump'ını tetikliyor.** İlk sürümde "üç kayıt = bir
   deneme" bekliyordum ve test üç deneme gördü. Doğru okuma: yeni bir okutma
   denemeye **değer**; ölçülecek değişmez "tek tur içinde tek deneme". Test
   buna göre yazıldı.
2. **`await syncNow()` turun koştuğunu garanti etmiyor.** Önceki tur hâlâ
   `_pumping` ise çağrı erken dönüyor ve tur sonradan koşuyor (`_pumpAgain`).
   Beklemeyi duruma göre yapmak gerekiyor.

**Ölçülemeyen bir şeyi de kayda geçirdim:** üstel geri çekilmenin
**zamanlayıcısını** sahte saatle ilerletmeyi denedim — test **askıda kaldı**.
Sebep: kuyruk her durum geçişinde **gerçek disk yazması** yapıyor ve
`testWidgets`in sahte zamanı bununla kilitleniyor. Bu ortamda "zamanlayıcı 15
saniye sonra ateşliyor mu" ölçülemez. Bu yüzden hesap saf bir fonksiyona
çıkarıldı (`geriCekilmeSuresi`, davranış değişmedi) ve invariant orada
kilitlendi: 15s → 30s → 60s → 120s, **10 dakikada tavan**, monoton, ve
0/negatif sayaçta tabana düşüyor (çökme yok).

---

## Tur 67'de kapatılanlar (E — görsel belleğinin gerçek ölçümü)

**Envantere yazdığım "gerçek cihaz gerekir" notu yanlıştı.** Flutter'ın görsel
önbelleği (`imageCache.currentSizeBytes`) çözülen görüntünün kaç bayt tuttuğunu
bildiriyor; yani çözme maliyeti **süreç içinde** ölçülebiliyor.

**Ölçülen gerçek** (1200×800 tek renk PNG, **4,5 KB dosya**):

| | Bayt |
|---|---|
| ham çözüm | **3 840 000** (1200 × 800 × 4) |
| 96×64 sınırlı | **24 576** |

**156 kat** fark. Dosya 5 KB'ın altında ama bellekte ~3,8 MB — sıkıştırılmış
boyut aldatıcı, bunu kod okumakla değil ölçümle görüyorsun. Tur 61 yalnızca
"`ResizeImage` kuruldu mu" diye doğruluyordu; artık **tasarrufun kendisi**
ölçülüyor (5 test), üretim yardımcısı `sinirliGorsel` dahil (56 dp avatar,
dpr 2 → 112×112×4 bayt).

**İki engel ve çözümleri** — ikisi de "ölçüm mümkün değil" demeden önce
denenmesi gereken şeylerdi:

1. `Picture.toImage` ile büyük PNG üretmek **başsız testte kilitleniyor**
   (rasterizer yok; test 400 saniyede bitmedi). Çözüm: PNG'yi **elle** kodlamak
   — IHDR + zlib IDAT + IEND. Rasterizer gerekmez, gerçek **çözücü** çalışır.
2. Çözme `runAsync` içinde yapılmalı; sahte zamanda görsel akışı hiç
   tamamlanmıyor.

**Bir de kendi araç hatam:** `pkill -f "flutter_tools.snapshot test"` deseni
**kendi kabuk komutumu** da eşleştirip öldürüyordu — bu yüzden üç ardışık dosya
yazma denemem hiç gerçekleşmedi ve eski dosya koşmaya devam etti. Belirti
"aynı hata tekrar ediyor" gibi görünüyordu; sebep dosyanın hiç değişmemesiydi.

**Hâlâ açık:** kare bütçesi / jank ölçümü. Bu gerçekten cihaz (ya da
`flutter drive` + emülatör) gerektiriyor; süreç içinde eşdeğeri yok.
