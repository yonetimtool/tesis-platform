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
| `cameras` | Kameralar (izleme + yönetim) | **P121 canlı karo deseni web'de de geçerli**; oynatıcı `<video>` + HLS |
| `dis_hizmet` | Dış hizmet/firma kayıtları | telefon alanı P123 maskesi |
| `yonetici_iletisim` | Yönetime ulaş / iletişim kartı | |

### tesis görevlisi (1)

| Modül | Sayfa | Not |
|---|---|---|
| `unit_access` | Daire erişim/anahtar kayıtları | KVKK kısıtları korunur |

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
| P126.5 | yönetici'nin 3 eksik sayfası (`cameras` dâhil) | orta |
| P126.6 | tesis görevlisi `unit_access` | küçük |
| P126.7 | 7 dil ARB + rol yalıtımı testleri + kapılar | orta |

Her alt-adım kendi commit'idir (kural 2/10). **Hiçbiri yarım bırakılmaz**:
bir rolün sayfası eklendiğinde o rol o gün işini web'den yapabilir olmalıdır.
