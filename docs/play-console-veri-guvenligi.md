# Play Console — Veri Güvenliği Formu Envanteri

**Kaynak:** koddan ölçülmüştür, beyan değildir. Her satırın karşılığı
belirtilen dosyadadır. Form doldurulurken **bu belge tek kaynaktır**;
`/hesap-silme` sayfası ve gizlilik politikası da bununla tutarlıdır.

Son ölçüm: 6 Ağustos 2026 · P141.6

---

## 1. Toplanan veri tipleri

| Veri | Nerede | Sunucuya | Zorunlu mu | Amaç |
|---|---|---|---|---|
| Telefon numarası | Kayıt, giriş, profil | ✓ `app_user.telefon` | Evet (kimlik) | Hesap yönetimi, kimlik doğrulama |
| Ad | Kayıt, profil | ✓ `app_user.ad` | Evet | Uygulama işlevi |
| E-posta | Yönetici/personel hesapları | ✓ `app_user.email` | Hayır (sakinde boş) | Hesap yönetimi |
| Profil fotoğrafı | `PATCH /me/avatar` | ✓ MinIO + `avatar_key` | Hayır | Uygulama işlevi |
| Yaklaşık + kesin konum | Devriye okutma, demirbaş zimmeti | ✓ `scan_event.gps_*`, `asset_checkout.alma_gps_*` | Hayır | Uygulama işlevi (saha kanıtı) |
| Fotoğraf | Talep, duyuru, site kuralı, kargo, görev kanıtı | ✓ MinIO | Hayır | Uygulama işlevi |
| Push jetonu | Uygulama açılışı | ✓ `user_device.fcm_token` | Evet | Bildirim |
| Uygulama içi mesaj/metin | Talep başlığı+mesajı, daire şikayeti notu | ✓ | Hayır | Uygulama işlevi |

### Toplanmayanlar (formda "hayır" işaretlenecek)

* **Cihaz veya reklam kimliği** — `device_info`/reklam kimliği kütüphanesi yok.
* **Çökme kayıtları / tanılama** — Crashlytics, Sentry, analitik SDK'sı yok.
* **Firebase Analytics** — `pubspec.yaml`'da yalnız `firebase_core` +
  `firebase_messaging` var; `firebase_analytics` **yok**.
* Konum **arka planda** toplanmıyor: `ACCESS_BACKGROUND_LOCATION` manifest'te
  yok, `geolocator` yalnız okutma anında çağrılıyor.

## 2. Üçüncü taraf aktarımı

| Servis | Üçüncü taraf mı | Giden veri |
|---|---|---|
| **Firebase Cloud Messaging (Google)** | **Evet** | Push jetonu + bildirim başlığı/gövdesi |
| Apple APNs | Evet (iOS teslimi FCM üzerinden) | Aynı |
| LibreTranslate | **Hayır** — kendi sunucumuz, iç ağ | — |
| MinIO | **Hayır** — kendi sunucumuz, dışarı kapalı | — |
| SMS sağlayıcı (Netgsm) | **Evet, yapılandırılırsa** | Telefon numarası + doğrulama kodu metni |

> Bildirim gövdesi kişisel veri **taşıyabiliyor** (örn. "Kargonuz geldi —
> {firma} (A-1)" daire numarası içerir). Formda beyan edilmelidir.

## 3. Şifreleme

* **Aktarımda:** ✓ TLS (Caddy + Let's Encrypt), HTTP→HTTPS yönlendirme.
* **Beklemede:** ✗ Veritabanı ve obje deposu şifresiz. Parolalar ve
  doğrulama kodları bcrypt'li; telefon/ad/e-posta/GPS düz metin sütunlarda.

## 4. Silme

**Kullanıcı silebilir:** ✓ Uygulama içi (Ayarlar → Hesabımı sil) ve
girişsiz web sayfası `https://yönetiyor.com/hesap-silme`.

Silinen: ad, e-posta, telefon, avatar kaydı, cihaz kayıtları (push
jetonları), oturum, daire bağlantısı. Referans veren kayıt yoksa hesap
tamamen silinir; varsa **anonimleştirilir** (`hesap_silme.py`).

**Silinmeyen ve nedeni:** devriye GPS kayıtları, yüklenen fotoğraflar,
talep metinleri — tesisin operasyonel ve denetim kaydı. Silme sonrası
kullanıcıyla ilişkilendirilemez hale gelir.

### Gecelik saklama işi (`retention.py`, beat)

| Tablo | Süre | İşlem |
|---|---|---|
| `visitor` | 24 ay | Silinir |
| `kargo` + fotoğrafları | süreli | Silinir (**MinIO objeleri dahil**) |
| `rezervasyon` | süreli | Silinir |
| `complaint` (çözüldü/reddedildi) | 36 ay | Metin arşivlenir, satır kalır |
| `audit_log` | süreli | Purge |

Sonuç `audit_log`'a `erasure_run` olarak yazılır.

---

## 5. AÇIK BULGULAR — forma "silinebilir" yazmadan önce kapatılmalı

**(a) Hesap silinince avatar objesi MinIO'da kalıyordu — KAPATILDI (P141.6).**
`hesap_silme.py` yalnız `avatar_key = None` yapıyordu; obje depoda yetim
kalıyordu. Artık `storage.delete_objects` çağrılıyor. MinIO erişilemezse
hata kaydı kırmıyor — depo arızasında kullanıcının hesabını silememesi
daha kötü olurdu.

**(b) Talep fotoğrafları hiçbir zaman silinmiyor.**
Retention talep metnini arşivliyor ama `complaint_photo` objelerine
dokunmuyor (`retention.py` içinde sıfır referans). Fotoğraflar süresiz
kalıyor.

Kalan madde (b), sayfada ve bu belgede yazdığımız "fotoğraflar operasyonel
kayıt olarak saklanır" ifadesiyle **çelişmiyor** — ama süresiz saklama
bilinçli bir karar değil, sadece retention'da atlanmış bir tablo. Süre
belirlenip retention'a eklenmeli.

**(c) Firebase'in kendi topladıkları ölçülmedi.** `firebase_messaging` SDK'sı
Google tarafında hangi tanılama verisini topluyor, Firebase konsolundaki
ayarlara bakılmadı. Analytics SDK'sı kurulu değil, ama konsol tarafı
doğrulanmalı.
