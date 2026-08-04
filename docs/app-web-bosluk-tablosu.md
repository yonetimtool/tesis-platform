# app.yönetiyor.com — BOŞLUK TABLOSU (P126)

Görev açıkça istedi: *"First produce a gap table (mobile feature → web page
exists / to build) and commit it; then implement in sub-commits per
role/module."* Bu belge o tablodur.

**Yöntem:** mobil modül listesi (`mobile/lib/src/features`, **43** klasör) ile
panel sayfa listesi (`admin-web/app/(protected)`, **32** sayfa) yan yana
konuldu. Eşleme **ada bakarak değil okuyarak** yapıldı — `residents` mobilde
tek modül, panelde `units` + `users` diye ikiye ayrılmış; `budget` mobilde
ayrı, panelde `finans`ın içinde.

**Sonuç:** 25 modülün web karşılığı **var**, 13'ü **yok**, 5'i **mobil-özel**.

---

## 1) WEB'DE KARŞILIĞI VAR (25) — taşınacak, yeniden yazılmayacak

Bunlar `panel.*`ta bugün çalışıyor; P126'da `app.*` altına, rol kapılı
biçimde taşınırlar. Yeniden yazım **yok**: çalışan bir ekranı yeniden
yazmak, düzeltilmiş her hatayı geri getirme riskidir.

| Mobil modül | Web karşılığı |
|---|---|
| announcements | `announcements` |
| anket | `yonetisim` (anketler) |
| anpr | `integrations` (ANPR) — **platform**, app'e gelmez |
| assets | `assets` |
| auth | `login` |
| budget | `finans` |
| building_map | `schematic` + `building-editor` |
| checkpoints | `checkpoints` |
| complaints, unit_complaints | `complaints` |
| dues | `dues` |
| home | `dashboard` |
| integrations | `integrations` — **platform** |
| notifications | `notifications` |
| patrol | `patrol-plans` |
| reports | `raporlar`, `reports/dues`, `reports/patrols`, `reports/tasks` |
| residents | `units` + `users` |
| settings | `settings` (bölünecek — bkz. P125) |
| shifts | `shifts` |
| staff | `users` |
| support | `support` — **platform** |
| tasks | `tasks` |
| tenant | `tenants` — **platform** |
| transparency | `transparency` |
| unit_tanimlari | `tanimlar` |

## 2) WEB'DE YOK — YAPILACAK (13)

Rol başına gruplandı; P126 alt-commit'lerinin sırası budur.

### sakin (5) — en yüksek öncelik
Sakinin web'de hiçbir şeyi yok; `app.*`ın varlık sebebi büyük ölçüde bu.

| Modül | Sayfa | Not |
|---|---|---|
| `rezervasyon` | Rezervasyonlarım + yeni rezervasyon | 24 sa / günde bir / 10 dk kuralları sunucuda (P?) |
| `site_kurali` | Site kuralları (okuma) | |
| `etkinlik` | Etkinlikler + katılım | |
| `kvkk` | KVKK tercihleri + veri talebi | hesap silme akışı **mobilde var** (P112); web'de de gerekir |
| `profile` | Profil + telefon/parola | telefon alanı **P123 maskesini** kullanır |

### güvenlik (4)

| Modül | Sayfa | Not |
|---|---|---|
| `visitors` | Ziyaretçi kaydı/çıkışı | |
| `kargo` | Kargo teslim/alım | |
| `violations` | İhlal/olay bildirimi | |
| `vehicle_pass` | Araç geçiş kayıtları | ANPR ile beslenir |

### yönetici (3)

| Modül | Sayfa | Not |
|---|---|---|
| `cameras` | **Kameralar ✅** | P121 canlı karo deseni; **oynatıcı YOK** — `hls.js` bağımlılık kararı alınmadı, gerekçe dosyada. Ekle/düzenle **mobilde kalır** (kaynak kuralı `CameraDraft`te) |
| `dis_hizmet` | **Dış hizmetler ✅** | telefon alanı P123 maskesi; `soyad` sunucuda **zorunlu** |
| `yonetici_iletisim` | **Yönetim iletişim ✅** | salt okuma; numara `aranabilir`e bakmaz — C1a istisnası sunucuda (yönetici = hizmet rolü) |

### tesis görevlisi (1)

| Modül | Sayfa | Not |
|---|---|---|
| `tasks` (kendi görünümü) | **Görevlerim** ✅ | `/tasks` sunucuda saha rolü için zaten kendi-kapsamlı |

> **⚠️ DÜZELTME — `unit_access` bu role AİT DEĞİL.** Ölçüldü
> (`routers/unit_access.py`): `_REQUESTER = admin/yonetici`,
> `_DECIDER = resident`, `_READER = admin/yonetici/resident`.
> `tesis_gorevlisi` o akışta **hiç yok**. Modül, bir yöneticinin daireye
> erişim **talep etmesi** ve sakinin **onaylaması** akışıdır — KVKK
> tadında bir rıza akışı. Doğru yeri: **yönetici** (talep) + **sakin**
> (karar) tarafı; ilk tablodaki atama yanlıştı.

## 2b) SONRADAN ÇIKAN BULGU — 25 "var" sayfa YÖNETİCİ görünümüdür

P126.3'e başlarken ölçüldü: sakinin kendi verisi backend'de **`/me/*`**
altında (`/me/dues`, `/me/profile`, `/me/contact`, `/me/checkpoints`).
Paneldeki `dues`, `complaints`, `announcements` sayfaları ise **yönetim**
görünümleridir — tahakkuk oluşturur, başkasının talebini yönetir.

Yani tablonun 1. bölümündeki "karşılığı var" ifadesi **yönetici için**
doğru; sakin için o sayfaların **kendi görünümü** gerekiyor:

| Sakinin ihtiyacı | Bugünkü panel sayfası | Gereken |
|---|---|---|
| Aidatım + ödeme | `dues` (tahakkuk **oluşturma**) | `/me/dues` üzerinden **kendi** borcu |
| Talebim | `complaints` (hepsini yönetme) | kendi talepleri + yeni talep |
| Duyurular | `announcements` (yazma) | salt-okuma listesi |

**Sonuç:** sakin çalışma alanı 5 değil ~8 sayfadır. Bu, tablonun ilk
tahminini düzeltir ve P126.3'ün neden "büyük" olduğunu açıklar.

## 3) MOBİL-ÖZEL — WEB'E GELMEZ (5)

| Modül | Neden |
|---|---|
| `nfc`, `scan` | NFC okutma **donanıma bağlıdır**; tarayıcıda karşılığı yok. Arayüzde **açıkça yazılacak**: "NFC okutma yalnız mobil uygulamada." Web tarafı tur kayıtlarını **görüntüler**, okutma yapmaz. |
| `push` | Web push ayrı bir iştir (VAPID); P12 Firebase kimliği gelmeden anlamsız |
| `call` | `tel:` bağlantısı — web'de tarayıcıya bırakılır |
| `weather` | Ana ekran süsü; web panosunda karşılığı `dashboard` içinde |

---

## 4) SIRA VE BÜYÜKLÜK — dürüst tahmin

P126 **tek oturumluk bir iş değil**. Ölçülebilir parçalara bölünüşü:

| Alt-adım | İçerik | Büyüklük |
|---|---|---|
| P126.1 | `app.*` iskeleti: rol×yüzey kapısı, kabuk/menü, Caddy proxy | ✅ **BİTTİ** |
| P126.2 | Yüzey kapısı (middleware) — 25 sayfa `app.*`ta erişilir, panelde kesilir | ✅ **BİTTİ** |
| P126.3 | **sakin çalışma alanı ✅ BİTTİ** — Profil, Aidatım, Taleplerim, Duyurular, Kurallar, Etkinlikler, Rezervasyonlarım, KVKK; `resident` `app.*`a **alındı** | ✅ **BİTTİ** |
| P126.4 | **güvenlik çalışma alanı ✅ BİTTİ** — Ziyaretçiler, Kargolar, Olaylar, Araç geçişleri; `security` `app.*`a **alındı** | ✅ **BİTTİ** |
| P126.5 | **yönetici'nin 3 eksik sayfası ✅ BİTTİ** — Kameralar (canlı karo, oynatıcı yok), Dış hizmetler, Yönetim iletişim | ✅ **BİTTİ** |
| P126.6 | **tesis görevlisi ✅ BİTTİ** — Görevlerim; `tesis_gorevlisi` `app.*`a **alındı** | ✅ **BİTTİ** |
| P126.7 | **rol yalıtımı ✅ BİTTİ** — menü artık role göre süzülüyor (rol×rota haritası backend matrisiyle kilitli); 7 dil sözlüğüne "TR kopyası" taraması eklendi | ✅ **BİTTİ** |

Her alt-adım kendi commit'idir (kural 2/10). **Hiçbiri yarım bırakılmaz**:
bir rolün sayfası eklendiğinde o rol o gün işini web'den yapabilir olmalıdır.

---

## 5) P126.7'DE ÇIKAN ASIL BULGU — menü YALNIZ yüzeye göre süzülüyordu

P126.1–.6 boyunca `app.*` menüsü rolden habersizdi: `app.*`a giren bir
**sakin 39 bağlantının hepsini** görüyordu — vardiya çizelgesi, tahakkuk,
kullanıcılar, finans. Hiçbirini açamıyordu (sunucu 403 veriyor) ama
"görüyorum, tıklayınca çalışmıyor" tam olarak `yuzey.ts`in önlemeye
çalıştığı **"sistem bozuk"** izlenimidir.

Çözüm iki katmanlı ve **ölçüme dayanır**:

| Katman | Nerede | Ne garanti eder |
|---|---|---|
| **Erişim** (ölçülür) | `backend/tests/yetki/rol-matrisi.txt` | rol o sayfanın birincil ucundan 403 alıyorsa sayfa menüde **olamaz** |
| **Niyet** (ürün kararı) | `admin-web/lib/yuzey.ts` → `ROTA_ROLLERI` | erişim yeter şart değil: `GET /cameras` herkese açık ama Kameralar bir yönetim ekranıdır |

`admin-web/tests/rol-menusu.test.ts` bildirilen kümenin erişim kümesinin
**alt kümesi** olduğunu her koşuda doğrular; bir uç daraltılırsa test düşer.
`backend/tests/test_yuzey_yalitimi.py` ise ters yönü yazar: 15 platform ucu
**hiçbir tesis rolüne** açık değildir (ve `admin`e **açıktır** — yoksa ucu
herkese kapatmak da testi geçirirdi).

Üçüncü katman **middleware**tir: menü süzgeci adresi yazanı durdurmaz.
`app.*`ta `/finans` yazan bir sakin sayfayı açar ve 403 alırdı; artık istek
sayfa çizilmeden kesilir ve rolün kendi başlangıcına yönlendirilir. Access
çerezi düşmüşse kapı uygulanmaz (yenileme şansı kalsın).

**Ölçümün yakaladığı somut örnek:** `GET /vehicle-passes` **yöneticiye 403**
döner (yalnız admin + security). "Araç geçişleri" yöneticiye gösterilseydi
tıklayınca boş ekran gelirdi — menüye elle bakan biri bunu fark etmezdi.
