# Play Console — Veri Güvenliği Formu

**TEK KAYNAK.** Form buradan doldurulur. Önceki turda envanter ile Play
kategori tablosu iki ayrı yerde durup çelişmişti (Finansal bilgi ve
Uygulama etkinliği tabloda vardı, envanterde yoktu) — birleştirildi.

Kaynak: koddan ölçüm, beyan değil. Son ölçüm: 7 Ağustos 2026 · P141.6

---

## 1. Form satırları (Play'in kendi kategorileri)

| Play kategorisi | Toplanıyor | Paylaşılıyor | Zorunlu/İsteğe bağlı | Amaç | Aktarımda şifreli | Silme istenebilir |
|---|---|---|---|---|---|---|
| Konum — yaklaşık | Evet | Hayır | İsteğe bağlı | Uygulama işlevi | Evet | **Hayır** |
| Konum — kesin | Evet | Hayır | İsteğe bağlı | Uygulama işlevi | Evet | **Hayır** |
| Kişisel bilgiler — ad | Evet | Hayır | Zorunlu | Uygulama işlevi, Hesap yönetimi | Evet | Evet |
| Kişisel bilgiler — e-posta | Evet | Hayır | İsteğe bağlı | Hesap yönetimi | Evet | Evet |
| Kişisel bilgiler — telefon | Evet | **Evet** | Zorunlu | Hesap yönetimi, Dolandırıcılık önleme | Evet | Evet |
| Kişisel bilgiler — kullanıcı kimliği | Evet | Hayır | Zorunlu | Uygulama işlevi, Hesap yönetimi | Evet | Evet |
| Kişisel bilgiler — adres | Evet | **Evet** | Zorunlu | Uygulama işlevi | Evet | Evet |
| Finansal bilgi — diğer finansal bilgiler | Evet | Hayır | Zorunlu | Uygulama işlevi, Hesap yönetimi | Evet | **Hayır** |
| Mesajlar — diğer uygulama içi mesajlar | Evet | Hayır | İsteğe bağlı | Uygulama işlevi | Evet | **Hayır** |
| Fotoğraflar ve videolar — fotoğraflar | Evet | Hayır | İsteğe bağlı | Uygulama işlevi | Evet | **Hayır** |
| Uygulama etkinliği — diğer eylemler | Evet | Hayır | Zorunlu | Uygulama işlevi | Evet | **Hayır** |
| Cihaz veya diğer kimlikler | Evet | **Evet** | Zorunlu | Uygulama işlevi | Evet | Evet |

**Toplanmayan kategoriler:** Sağlık ve fitness · Ses dosyaları · Dosyalar ve
belgeler · Takvim · Kişiler · Web tarama · Uygulama bilgileri ve performansı.

### İki sınır kararı ve gerekçesi

**Finansal bilgi — EVET, beyan edilir.** Play bu kategoriyi "ödeme
bilgileri, satın alma geçmişi, kredi notu, **diğer finansal bilgiler**"
diye tanımlıyor. Aidat borcu, ödeme geçmişi ve tahsilat kayıtları
kullanıcıya ait bir mali yükümlülük kaydıdır ve son madde bunu kapsar.
**Kart/ödeme aracı verisi YOK** — ödeme tesis tarafından kaydedilir,
uygulamada kart bilgisi girilmez. Az beyan Play ihlalidir, fazla beyan
değildir; sınırdaki kategori beyan edilir.

> App Store gizlilik anketiyle tutarlılık: orada "ödeme verisi
> toplanmıyor" denmişti. O beyan ödeme **aracına** dairse çelişki yok.
> "Hiç finansal veri yok" biçiminde verildiyse App Store tarafı
> düzeltilmeli — iki mağaza formu birbiriyle çelişmemeli.

**Uygulama etkinliği — EVET, beyan edilir.** Play "diğer eylemler" alt
başlığını "kullanıcının gerçekleştirdiği diğer eylemler" diye tanımlıyor.
`audit_log` ve olay kayıtları (devriye okutma, ziyaretçi onayı, talep
açma) doğrudan uygulama kullanımından üretiliyor. Sunucu tarafında
üretilmiş olması kategoriyi değiştirmez.

## 2. Veri tipleri — koddaki karşılıkları

| Play kategorisi | Kod karşılığı |
|---|---|
| Konum | `scan_event.gps_lat/lng/dogruluk_m`, `asset_checkout.alma_gps_*` |
| Ad / e-posta / telefon / kimlik | `app_user.ad / email / telefon / id` |
| Adres | `unit.blok` + `unit.no`, `unit_resident` bağlantısı |
| Finansal bilgi | aidat / borç / tahsilat tabloları |
| Mesajlar | `complaint.baslik`+`mesaj`, `unit_complaint.notlar` |
| Fotoğraflar | MinIO: `avatar_key`, `complaint_photo`, kargo/görev/duyuru |
| Uygulama etkinliği | `audit_log`, olay kayıtları |
| Cihaz kimliği | `user_device.fcm_token` |

### Toplanmadığının kanıtı

* Cihaz/reklam kimliği: `device_info`/reklam kimliği kütüphanesi yok.
* Çökme ve tanılama: Crashlytics/Sentry yok.
* **Firebase Analytics yok** — `pubspec.yaml`'da yalnız `firebase_core` +
  `firebase_messaging`. Analytics SDK'sı kurulu olmadığı için Google
  konsol tarafında da toplama olmaz.
* Arka plan konumu: `ACCESS_BACKGROUND_LOCATION` manifest'te yok.
* **WebView yok** — yalnız `url_launcher` (harici tarayıcı).

## 3. Üçüncü taraf aktarımı

| Servis | Üçüncü taraf | Giden veri |
|---|---|---|
| Firebase Cloud Messaging (Google) | **Evet** | Push jetonu + bildirim başlığı/gövdesi |
| Apple APNs | Evet (iOS teslimi FCM üzerinden) | Aynı |
| SMS sağlayıcı (Netgsm) | **Evet, yapılandırılırsa** | Telefon + doğrulama kodu metni |
| LibreTranslate | Hayır — kendi sunucumuz, iç ağ | — |
| MinIO | Hayır — kendi sunucumuz, dışa kapalı | — |

Bildirim gövdesi kişisel veri taşıyabiliyor ("Kargonuz geldi — {firma}
(A-1)"): tablodaki **adres** ve **cihaz kimliği** satırlarındaki
"paylaşılıyor" işareti buradan geliyor.

## 4. Silme

**Uygulama içi:** Ayarlar → Hesabımı sil (parola **veya** telefon kodu).
**Web (girişsiz):** `/hesap-silme` — adres için §6.

**Tam silinir → "kullanıcılar silinmesini isteyebilir" işaretlenebilir:**
Kişisel bilgiler (ad, e-posta, telefon, kullanıcı kimliği, adres
bağlantısı) · Cihaz veya diğer kimlikler.

**Kısmen saklanır → işaretlenirse YANLIŞ BEYAN:**

| Kategori | Neden |
|---|---|
| Konum (yaklaşık + kesin) | Devriye GPS'i operasyonel/denetim kaydı |
| Fotoğraflar | Avatar silinir, **talep fotoğrafı yalnız 36 ayda** |
| Mesajlar | Talep metni 36 ayda arşivlenir, talep üzerine değil |
| Finansal bilgi | Yasal saklama süresi |
| Uygulama etkinliği | Denetim kaydı |

Bu kategorilerde doğru cevap silme değil **anonimleştirme**; `/hesap-silme`
sayfası ve gizlilik politikası da aynı şeyi yazar.

### Gecelik saklama işi (`retention.py`, beat)

| Tablo | Süre | İşlem |
|---|---|---|
| `visitor` | 24 ay | Silinir |
| `kargo` + fotoğrafları | süreli | Silinir (MinIO objeleri dahil) |
| `rezervasyon` | süreli | Silinir |
| `complaint` | 36 ay | Metin arşivlenir, satır kalır |
| `complaint_photo` | 36 ay | Silinir (MinIO objeleri dahil) |
| `audit_log` | süreli | Purge |

## 5. Şifreleme

**Aktarımda:** ✓ TLS (Caddy + Let's Encrypt), HTTP→HTTPS.

**Beklemede: ✗ BİLİNEN EKSİK.** Veritabanı ve obje deposu şifresiz;
telefon, ad, e-posta ve GPS düz metin sütunlarda. Parolalar ve doğrulama
kodları bcrypt'li, ama bu alan şifrelemesi değildir. Play formu at-rest
sormuyor — **form engeli değil**; KVKK tarafında ele alınacak bir eksik
olarak kayıtlıdır. Seçenekler: sütun bazlı şifreleme (pgcrypto), disk
şifreleme, ya da yönetilen veritabanı şifrelemesi.

## 6. Hesap silme URL'i — DAĞITIM BEKLİYOR

**Ölçüm (7 Ağustos 2026, prod):**

| Adres | `/` | `/gizlilik` | `/hesap-silme` |
|---|---|---|---|
| `yonetio.site` | 200 | 200 | **404** |
| `xn--ynetiyor-n4a.com` | 200 | 200 | **404** |

İki alan adı da **canlı ve TLS'li**; 404 yönlendirme sorunu değil
**dağıtım** sorunu: sayfa depoda var, prod'a yeniden dağıtım yapılmadı.

**Forma girmeden önce admin-web prod'a dağıtılmalı**, sonra adres yeniden
ölçülmeli. Play botu URL'i açıp kontrol eder; 404 red sebebidir.

**Öneri: `https://yonetio.site/hesap-silme`.** Gerekçe: tamamen ASCII, IDN
belirsizliği yok, bugün canlı ve uygulamanın mevcut bağlantıları da bu
alan adına gidiyor. Marka alan adı tercih edilecekse **punycode biçimi**
(`xn--ynetiyor-n4a.com`) girilmeli — `ö` harfli biçim forma yazılmamalı,
normalleştirme davranışı garanti değil.

---

## 7. Açık kalan

Önceki turların (a) avatar objesi, (b) talep fotoğrafı saklama süresi ve
(c) Firebase Analytics maddeleri **kapandı**. Tek bekleyen iş §6'daki prod
dağıtımı; §5'teki at-rest şifreleme ise form dışı, ayrı bir tur.
