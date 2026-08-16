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
