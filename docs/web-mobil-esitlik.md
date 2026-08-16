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
| Ziyaretçi | ekle | ekle · düzenle | ⚠️ mobilde çıkış güncellemesi var |
| Kargo | ekle | ekle · düzenle | ⚠️ mobilde teslim güncellemesi var |
| Talep / şikayet | aç · çöz/reddet | aç · çöz | ✅ eşit |
| Duyuru | düzenle · sil (**ekleme yok**) | ekle · düzenle · sil | ⛔ **bilinçli** — `auth.md §4`: `POST /announcements` admin'e 403; duyuru site yöneticisine ait (mobil) |
| Site kuralı | ekle · düzenle · sil (`/site-kurallari`) | ekle · düzenle · sil | ✅ **P162'de kapandı** |
| Etkinlik | ekle · düzenle · sil (`/etkinlik-yonetimi`) | ekle · düzenle · sil · RSVP | ✅ **P162'de kapandı** (RSVP sakin işi) |
| Finans / gelir-gider | ekle | — | ✅ web daha zengin |
| İcra dosyası | ekle · düzenle | — | ✅ web daha zengin |
| Tanımlar (firma, personel, araç, sayaç, kasa) | ekle · düzenle · sil | kısmi | ✅ web daha zengin |
| Entegrasyon | ekle · düzenle · sil | ekle · düzenle · sil | ✅ eşit |
| Dış hizmet | ekle | ekle · düzenle · sil | ⚠️ mobilde düzenleme/silme var |

## Kapatılmayan farklar ve nedeni

### Ziyaretçi / kargo / dış hizmet güncellemeleri

Mobilde var, webde yok. Küçük farklar; kapatılmadı.

## P162'de kapatılanlar

1. **Kullanıcı silme** (`e8b00e29`) — uç ve vekil vardı, düğme yoktu.
2. **Sakin oluştururken daire ataması** (`5a76ae49`) — webde iki adım
   gerekiyordu; artık tek adımda, `POST /users` ardından
   `POST /units/{id}/residents`. Sözleşme değişmedi.
3. **Site kuralı ve etkinlik yönetimi** — iki yeni sayfa:
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
