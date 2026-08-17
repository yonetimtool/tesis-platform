# Web / mobil yetenek eşitliği — ölçüm (P162 §5)

> Brief: "İki yüzeyde ekleme/silme/düzenleme yetenekleri AYNI olacak. Fark
> tespit et ve kapat." Bu belge **ölçümün kendisidir**: hangi varlıkta hangi
> yüzeyin ne yapabildiği, ve farkın kapatılıp kapatılmadığı.

## Nasıl ölçüldü

Tahmin yok, iki taraf da kaynaktan sayıldı:

* **Web** — `admin-web/app/(protected)/**/page.tsx` içindeki `apiSend(url, FIIL)`
  çağrıları (GET dışındaki fiiller).
* **Mobil** — `mobile/lib/src/features/**` altındaki istemci çağrıları
  (`.post/.patch/.put/.delete`).

Yöntemin sınırı açık: dizin başına fiil saymak **kaba** bir ölçüdür. Bir
`PUT`, kaynağın kendisini değil bir alt-kaynağı güncelliyor olabilir (örn.
mobildeki `shifts` `PUT`u vardiya *atamasıdır*, vardiya CRUD'u değil). Bu
yüzden aşağıdaki tabloda **her satır tek tek doğrulandı** — sayım yalnızca
nereye bakılacağını söyledi.

## Tablo

| Varlık | Web | Mobil | Durum |
|---|---|---|---|
| Kullanıcı / sakin | ekle · düzenle · **sil** | ekle · düzenle · sil | ✅ **P162'de kapandı** — web'de silme yoktu (`DELETE /users/{id}` ve BFF vardı, düğme yoktu) |
| Sakin → daire ataması | **oluştururken atanabilir** | oluştururken atanabilir | ✅ **P162'de kapandı** — web'de iki adım gerekiyordu |
| Daire | ekle · düzenle · sil · toplu | ekle · düzenle · sil | ✅ eşit |
| Blok | ekle · düzenle · sil | ekle · düzenle · sil | ✅ eşit |
| Görev | ekle · düzenle · sil | ekle · düzenle · sil | ✅ eşit |
| Demirbaş | ekle · düzenle | ekle | ✅ web daha zengin |
| Kamera | ekle · düzenle · sil | ekle · düzenle · sil | ✅ eşit |
| NFC noktası | ekle · düzenle · sil | sil | ✅ web daha zengin |
| Devriye planı | ekle · düzenle · sil | ekle · düzenle · sil | ✅ eşit |
| Vardiya | ekle · düzenle · sil | atama (`PUT`) | ✅ eşit (mobildeki `PUT` atamadır, CRUD değil) |
| Ziyaretçi | ekle · **düzenle** · çıkış | ekle · düzenle | ✅ **P162'de kapandı** |
| Kargo | kapıda kaydet (güvenlik) · **teslim aldım** (sakin) | aynı | ✅ **P162'de kapandı** |
| Talep / şikayet | aç · çöz/reddet | aç · çöz | ✅ eşit |
| Duyuru | düzenle · sil (**ekleme yok**) | ekle · düzenle · sil | ⛔ **bilinçli** — `auth.md §4`: `POST /announcements` admin'e 403; duyuru site yöneticisine ait (mobil) |
| Site kuralı | ekle · düzenle · sil (`/site-kurallari`) | ekle · düzenle · sil | ✅ **P162'de kapandı** |
| Etkinlik | ekle · düzenle · sil (`/etkinlik-yonetimi`) | ekle · düzenle · sil · RSVP | ✅ **P162'de kapandı** (RSVP sakin işi) |
| Finans / gelir-gider | ekle | — | ✅ web daha zengin |
| İcra dosyası | ekle · düzenle | — | ✅ web daha zengin |
| Tanımlar (firma, personel, araç, sayaç, kasa) | ekle · düzenle · sil | kısmi | ✅ web daha zengin |
| Entegrasyon | ekle · düzenle · sil | ekle · düzenle · sil | ✅ eşit |
| Dış hizmet | ekle · **düzenle** · **sil** | ekle · düzenle · sil | ✅ **P162'de kapandı** |

## Bina Düzenleme ekranı (P163 §5)

Ayrı ölçüldü, çünkü P163'te web tarafına üç yapısal araç taşındı.

**Yöntem:** mobil `features/building_map/` altındaki API çağrıları
(`bina_duzenleme_api.dart`, `bina_duzenleme_controller.dart`) tek tek
okundu; web tarafı `app/(protected)/building-editor/page.tsx`.

| Yetenek | Web | Mobil | Durum |
|---|---|---|---|
| Blok ekle / düzenle / sil (cascade) | ✅ | ✅ | eşit |
| Daire ekle / düzenle / sil | ✅ | ✅ | eşit |
| Kat ekle | ✅ | ✅ | eşit |
| Toplu daire oluştur (`/units/bulk`) | ✅ **P163'te taşındı** | ✅ | eşit |
| Kat sil (`/units/kat-sil`) | ✅ | ✅ **P164'te eklendi** | eşit |
| Daire tipi toplu değiştir (`/units/toplu`) | ✅ | ✅ **P164'te eklendi** | eşit |
| Numara ile seç (3,5,7-12) | ✅ | ✅ **P164'te eklendi** | eşit |
| Sürükleyerek sıralama (`/units/siralama`) | ✅ | ✅ **P164'te eklendi** | eşit |
| Toplu oluşturmada başlangıç katı (bodrum/zemin) | ✅ | ✅ **P164'te eklendi** | eşit |

**P164 notu — ölçüm beşinci bir farkı ortaya çıkardı.** Dördü kapatılırken
görüldü ki mobilin toplu oluşturması `baslangic_kat` alanını *hiç
göndermiyordu*; sunucu 1 varsayıyor ve bodrumlu bir binada kat numaraları
bir kaydırmayla yazılıyordu. Alan eklendi.

### Aralık ayrıştırıcısı iki yüzeyde AYNI

"3,5,7-12" ifadesi mobilde `domain/daire_araligi.dart` ile çözülüyor ve
webdeki `lib/aralik.ts`in **birebir** karşılığı. Bu bir tercih değil
zorunluluk: kullanıcı webde "7-12" yazıp altı daire seçiyorsa mobilde de
altı seçmeli, yoksa toplu işlem **yanlış dairelere** gider.

`mobile/test/daire_araligi_test.dart` webdeki `aralik.test.ts` ile aynı
senaryoları koşar — ters aralık, eşleşmeyen parça, kopya üretmeme, aynı
kuyruğun birden çok satıra denk gelmesi ve tek değerin **önce sayı**
olarak denenmesi dahil (sırayı ters çevirmek iki yüzeyi ayırırdı).

## Kapatılmayan fark kalmadı

Tablodaki tek ⛔ satırı (duyuru oluşturma) bir eksik değil, **bilinçli bir
ürün kararıdır**: `POST /announcements` admin'e 403 döner; duyuru site
yöneticisine aittir (`auth.md §4`).

### Ölçüm bir kez tabloyu düzeltti

"Kargo — mobilde teslim güncellemesi var" satırı kaba fiil sayımından
gelmişti ve **güvenlik ekranının eksiği sanılmıştı**. Sunucuya bakınca
`PATCH /kargo/{id}` kapısının `_RESIDENT` olduğu görüldü — o bir **sakin**
eylemi. Doğru kapanış güvenlik ekranına düğme koymak değil, sakinin aynı
listede kendi kargosunu işaretleyebilmesiydi.

Ayrı bir sakin sayfası da açılmadı: `GET /kargo` zaten rol kapsamlı
(`resident` yalnızca kendi dairelerininkini görür), yani sakin o sayfayı
açtığında zaten kendi listesini görüyordu. İkinci bir sayfa, aynı listeyi
iki yerde tutmak olurdu.

## P162'de kapatılanlar

1. **Kullanıcı silme** (`e8b00e29`) — uç ve vekil vardı, düğme yoktu.
2. **Sakin oluştururken daire ataması** (`5a76ae49`) — webde iki adım
   gerekiyordu; artık tek adımda, `POST /users` ardından
   `POST /units/{id}/residents`. Sözleşme değişmedi.
3. **Ziyaretçi kaydı düzenleme** — uç (`PATCH /visitors/{id}`, `_REGISTRAR`)
   vardı, vekil ve düğme yoktu. Düzenleme **çıkıştan bağımsız**: kapıda
   yanlış yazılan bir ad, ziyaretçi çıktıktan sonra da düzeltilebilmeli.
4. **Dış hizmet düzenleme + silme** — uçlar (`_WRITER`) vardı; rehberdeki
   bir numara değiştiğinde kaydı silip yeniden yazmak, kaydın kimliğini
   gereksizce değiştirmekti.
5. **Kargo teslim alma (sakin)** — yukarıdaki ölçüm notuna bakın.
6. **Site kuralı ve etkinlik yönetimi** — iki yeni sayfa:
   `/site-kurallari` ve `/etkinlik-yonetimi`, rol kapısı
   `["admin", "yonetici"]` (sunucudaki `_MANAGER` ile aynı küme).

   **Bir kez yanlış yaptım ve test yakaladı:** yazma düğmelerini önce
   sakin sayfasına (`/kurallar`) eklemiştim; `sakin-okuma` kilidi haklı
   olarak düşürdü. Doğru desen depoda zaten vardı —
   `/duyurular` (sakin) ↔ `/announcements` (yönetim) — ve bu iki sayfa
   onun aynısı.

   Menüde `tesis` değil **`iletişim`** grubuna kondular: hem anlamca
   (üçü de yönetimin sakine yayınladığı içerik, duyuru yönetimi zaten
   orada) hem de ölçümle — `tesis` grubuna eklemek açılıştaki görünür
   satırı 13'e çıkarıyordu ve `menu-gruplari` bütçesi (en çok 12)
   düşüyordu.

## P165 — iki fark daha kapandı (ikisi de MOBİL tarafta)

P165 web tarafında iki yeni davranış getirdi; ölçüm, ikisinin de mobilde
karşılığı olmadığını gösterdi. Brief'in kısıtı açıktı: *"web ve mobil
davranışı aynı olacak"*.

| Yetenek | Web | Mobil | Durum |
|---|---|---|---|
| Kat silme **etki özeti** (`/units/kat-onizleme`) | ✅ | ✅ **P165'te eklendi** | eşit |
| Mali kayıtta **ikinci kapı** (kat no yazma) | ✅ | ✅ **P165'te eklendi** | eşit |
| Rezervasyon **Aktif / Geçmiş** ayrımı (`?gecmis=`) | ✅ | ✅ **P165'te eklendi** | eşit |
| Geçmiş kayıtta "İptal et" görünmez | ✅ | ✅ **P165'te eklendi** | eşit |

**Metinler tek kaynaktan.** Mobil arb'lere eklenen altı anahtarın yedi
dildeki karşılığı web sözlüğünden (`admin-web/lib/i18n/sozluk/*.ts`)
kopyalandı. Aynı cümlenin iki yüzeyde farklı çevirisi olması, "davranış
aynı" kısıtını metin düzeyinde bozardı — kullanıcı için ekranda gördüğü
cümle davranışın kendisidir.

### Ölçüm burada da beklenmedik bir kusur buldu

Mobilde "Katı sil", **bir bloğa girilmeden** (üst seviyeden) açıldığında
`blok` alanını **boş** gönderiyordu. Uç `blok`u zorunlu tutuyor
(`min_length=1`), yani işlem her seferinde 422 ile düşüyordu — kullanıcı
sebebini anlamadığı bir hata alıyordu. Webde modalın ilk alanı zaten blok
seçimi; mobil ona hizalandı (blok seçilene kadar "Sil" kapalı, kat listesi
de çizilmez).

## P167 Aşama 1 — menü mimarisi + profil (ölçüm)

Bu aşama **kabuk** ve **kendi hesabı** ekranlarına dokundu; ikisi de
"varlık CRUD'u" değil, o yüzden yukarıdaki tabloya satır eklemiyor.
Değerlendirme madde madde:

| Madde | Mobilde gerekli mi | Gerekçe |
|---|---|---|
| §1.1–§1.6 menü ağacı (ikon kuralı, kapalı başlıklar, Özet, İcra taşıma, iletişim birleştirme, Tanımlar) | **hayır** | Mobilde sol menü **yok**; gezinme alt sekme + "Tüm Modüller" (P160). Web menü ağacının mobilde bir karşılığı olmadığı için "fark" da oluşmuyor. |
| §1.7 avatar yükle/kaldır | **zaten eşit** | `PATCH /me/avatar` P3'ten beri mobilde kullanılıyor; web bu turda ona yetişti. |
| §1.7 hesabımı sil | **zaten eşit oldu** | Uç P112'de **mobil için** açılmıştı; eksik olan **web** tarafıydı (BFF vekili yoktu) ve bu turda kapandı. |
| §1.7 ad soyad self-servis | **açık fark — mobil** | Yeni `MeContactUpdate.ad` yalnız web'de kullanılıyor. Mobil profil ekranı adı hâlâ salt okur gösteriyor. Uç hazır, tek eksik ekran alanı. |
| §1.7 güvenilen cihazlar + hesap etkinliği | **açık fark — mobil** | Uçlar rol bağımsız ve hazır (`/me/cihazlar`, `/me/etkinlik`). "Bu telefonu kaybettim" senaryosunun doğal yeri telefonun kendisidir. |
| §1.7 bildirim ayarları | **açık fark — mobil, öncelikli** | **Mobil bildirim** anahtarını web'den açıp kapatmak dolaylı bir yol; kullanıcı bildirimi aldığı cihazda kapatmak ister. `GET/PATCH /me/bildirim-tercihleri` hazır. |
| §1.8 alt bar | **hayır** | Kabuk farkı. |

**Sonuç:** bu aşama mobilde kod değişikliği **gerektirmedi** ama **üç
açık fark bıraktı** ve üçü de aynı ekrana düşüyor — mobil profil sayfası:
ad düzenleme, cihaz listesi, bildirim ayarları. Uçların hepsi açık ve rol
bağımsız; iş yalnız ekran işi. Kapatılması Aşama 6'dan sonraya yazıldı.

## P167 Aşama 2 — Özet sayfası (ölçüm)

| Madde | Mobilde gerekli mi | Gerekçe |
|---|---|---|
| §2.1 widget şeridi | **hayır** | Mobil ana ekran P160'ta zaten kısayol ızgarası + "Tüm Modüller" olarak yeniden tasarlandı; ikinci bir şerit aynı işi iki kez yapardı. |
| §2.2 finansal kartlar | **kısmi fark** | Mobilde özet kartlar var; `/finans/ozet`in üç yeni alanını (`borc_kurus`, `onay_bekleyen_adet`, `odenmis_fatura_ay_kurus`) henüz çizmiyor. Uç hazır — küçük ekran işi. |
| §2.3 takvim + hatırlatma | **açık fark, öncelikli** | Yaklaşan olay ve kişisel hatırlatma telefonda en çok bakılan şey. `GET /takvim` ve `/hatirlatmalar` rol bağımsız ve hazır. |
| §2.4 3D maket | **hayır** | Mobilde WebGL sahnesi taşımanın pil ve paket boyutu maliyeti var; mobilin karşılığı şematik plan. |
| §2.5 panel düzenleme | **hayır** | Mobil ana ekran düzeni zaten sabit ve tek kolon; sıralama orada bir soruna çözüm değil. |

**Sonuç:** bu aşama da mobilde kod değişikliği gerektirmedi. Açık kalan
iki fark — takvim ekranı ve üç finansal kart alanı — Aşama 1'in bıraktığı
üç farkla birlikte listede.

## P167 Aşama 4 — Finansal İşlemler (ölçüm)

| Madde | Mobilde gerekli mi | Gerekçe |
|---|---|---|
| Merkezi belge numaralandırma | **otomatik eşit** | Kural sunucuda (`app/belge_no.py`); mobilin yazdığı her hareket de aynı seriden numara alıyor. Mobil tarafta kod değişikliği gerekmedi. |
| 4.1–4.7 finans ekranları | **hayır** | Masa başı muhasebe işi: çok satırlı giriş, Excel/PDF çıktısı, dönem seçimi. Telefonda satır tablosu doldurmak aracı yanlış işe koşmaktır; mobilin mali ihtiyacı (aidatım, borç görüntüleme) zaten karşılanıyor. |
| 4.8 icra dosyaları | **hayır** | Hukuki dosya takibi de masa başı işi. |
| `finansal_hareket.durum` alanı | **kısmi fark** | Mobil hareket listelerinde çizilmiyor. Uç hazır — küçük ekran işi. |

---

## P167 Aşama 5 — Rapor motoru

| Madde | Web | Mobil | Karar ve gerekçe |
|---|---|---|---|
| Kategorili kart ızgarası (Listeler / Ekstreler / Dökümler) | var | yok | **Bilinçli fark.** On beş raporluk bir yapılandırma ızgarası masa başı işi; telefonda on beş kartı tarayıp on alanlı bir modal doldurmak aracı yanlış işe koşmaktır. Mobilin rapor ihtiyacı (aidatım, borcum, makbuzum) kendi ekranlarında karşılanıyor. |
| Ortak `RaporModalı` | var | yok | Yukarıdakinin parçası. |
| Kuyruk (`/raporlar/{kod}/kuyruk`, `/raporlar/isler`) | var | **uç hazır, ekran yok** | Uçlar rol kapısıyla açık ve istemciden bağımsız. Mobil bir gün rapor üretimi isterse aynı kuyruğu kullanır; bugün mobilde rapor üretim ekranı olmadığı için ekran **yazılmadı** — kullanılmayan bir ekran yazmak, bakımı olan ölü kod olurdu. |
| Üç yeni rapor (Notlar, Firma Ekstresi, Hesap Ekstresi) | var | **otomatik eşit** | Sunucuda üretiliyor; herhangi bir istemci aynı çıktıyı alır. |
| Alan tanımının sunucudan gelmesi | var | **otomatik eşit** | Katalog `alanlar` döndürüyor. Mobil bir gün modal çizerse aynı listeden besleneceği için iki istemci ayrışamaz. |

---

## P167 Aşama 6 — Yönetim başlığı

| Madde | Web | Mobil | Karar ve gerekçe |
|---|---|---|---|
| Karar Defteri | var | yok | **Bilinçli fark.** Karar yazmak uzun metin girişidir ve masa başı işidir. Sakinin kararları *okuma* ihtiyacı ayrı bir istektir; brief'te yok ve uç bugün admin+yönetici'ye kapalı. |
| Doküman Yönetimi (yükleme) | var | yok | Sürükle-bırak, 25 MB'lik dosya, çoklu seçim — masa başı işi. |
| Doküman **okuma** | var | **var (P167 ek)** | Karar verildi ve açıldı — ama arşivin tamamı değil: `sakine_acik` bayrağı (varsayılan **kapalı**) ve ayrı `/me/dokumanlar` ucu. Ayrıntı aşağıda. |
| KVKK metni yayınlama | var | yok | Hukuki metin; sürüm mantığı ve geri alınamazlık masaüstünde kalmalı. |
| Gürültü uyarıları | var | **uç hazır, ekran yok** | Anons "yapıldı" işaretlemesi saha işi olabilir; mobil isterse aynı uç kullanılır. |
| Merkezî karar numarası (`KRR-…`) | — | **otomatik eşit** | Sunucuda; hangi istemci yazarsa yazsın aynı seriden numara alır. |
| Doküman yumuşak silme + gecelik süpürme | — | **otomatik eşit** | Sunucuda; mobil bir gün silme yaparsa aynı kurala tabi olur. |
| Doküman indirme ucu | var | **uç hazır** | `GET /dokumanlar/{id}/indir` istemciden bağımsız. |

---

## P167 ek — Sakin doküman erişimi

Kullanıcı kararı: *"mobilde sakinler dokümanları okuyabilsin."*

| Madde | Web | Mobil | Karar ve gerekçe |
|---|---|---|---|
| Sakin doküman listesi | — | **var** | Ana ekranda "Site Dokümanları" karosu (site kurallarının yanında: ikisi de *başvuru içeriğidir*, duyuru gibi anlık değil). |
| Görünürlük bayrağı (`sakine_acik`) | **var** (yönetici işaretler) | — | Bayrağı sakin göremez ve değiştiremez. Web'de rozet + "Sakine aç / kapat". |
| Süzgeç nerede | — | **sunucuda** | Mobil model `sakineAcik` alanı **taşımaz**: taşısaydı istemcide ikinci bir süzgeç yazma ihtimali doğar ve o süzgeç bir gün yanlış yazılırsa kapalı bir belge sakinin ekranında görünürdü. |
| Yönetim ucu (`/dokumanlar`) | var | **yok ve olmamalı** | O uç TÜM arşivi döner. Mobil sakin uygulamasının ona hiç dokunmaması, "yanlışlıkla yönetim ucunu çağırdım" sınıfını kapatır; mobil testi bunu ölçüyor. |
| Dosyayı açma | tarayıcı | **sistem uygulaması** | PDF/Word görüntüleyici gömülmedi: her biçim için okuyucu taşımak uygulamayı büyütür ve çoğu biçimde yine eksik kalırdı. |
| Saha personeli (güvenlik/görevli) | — | **hayır** | Uç *sakin* için açıldı; onlar tesisin sakini değil çalışanıdır. Menüde de yok — göstermek, tıklanınca 403 veren bir karo olurdu. |

