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
| Site kuralı | **yalnız okuma** | ekle · düzenle · sil | ⛔ **açık fark** — aşağıya bakın |
| Etkinlik | **yalnız okuma** | ekle · düzenle · sil · RSVP | ⛔ **açık fark** — aşağıya bakın |
| Finans / gelir-gider | ekle | — | ✅ web daha zengin |
| İcra dosyası | ekle · düzenle | — | ✅ web daha zengin |
| Tanımlar (firma, personel, araç, sayaç, kasa) | ekle · düzenle · sil | kısmi | ✅ web daha zengin |
| Entegrasyon | ekle · düzenle · sil | ekle · düzenle · sil | ✅ eşit |
| Dış hizmet | ekle | ekle · düzenle · sil | ⚠️ mobilde düzenleme/silme var |

## Kapatılmayan farklar ve nedeni

### Site kuralı ve etkinlik — web'de yönetim ekranı YOK

Ölçüm: `/kurallar` ve `/etkinlikler` sayfalarının ikisinde de **hiç
`apiSend` çağrısı yok**; uçlar (`POST/PATCH/DELETE /site-rules`,
`/events`) ve mobil istemci ise tam CRUD yapıyor.

Bu turda kapatmaya çalıştım ve **yanlış yaptım**: yazma düğmelerini
`/kurallar` sayfasına ekledim. `tests/sakin-okuma.dom.test.ts` bunu
düşürdü ve haklıydı — o sayfa **sakin görünümüdür** (P126.3), yönetim
ekranı değil. Sakine, basınca 403 alacağı bir düğme göstermek "yetkim var
sandım" demektir. Değişiklik geri alındı.

Doğru kapanış, duyurularda olduğu gibi **ayrı bir yönetim sayfası**
açmaktır (`/duyurular` sakin ↔ `/announcements` yönetim). Bu iki yeni
ekran demek ve bu turda yapılmadı.

### Ziyaretçi / kargo / dış hizmet güncellemeleri

Mobilde var, webde yok. Küçük farklar; kapatılmadı.

## P162'de kapatılanlar

1. **Kullanıcı silme** (`e8b00e29`) — uç ve vekil vardı, düğme yoktu.
2. **Sakin oluştururken daire ataması** (`5a76ae49`) — webde iki adım
   gerekiyordu; artık tek adımda, `POST /users` ardından
   `POST /units/{id}/residents`. Sözleşme değişmedi.
