# Ana Ekran Görsel Zenginleştirme — Tasarım

**Tarih:** 2026-07-24
**Durum:** Kullanıcı onaylı (sohbet içinde); yazılı spec incelemesi bekleniyor
**Referanslar:** `docs/design-refs/{yonetici,site-sakini,gorevli}.jpeg`

## Amaç

Tamamlanan mobil home redesign'ın üzerine, referans görsellerdeki şu
zenginleştirmeleri eklemek:

1. **WP-B** — Ana ekran Duyurular kartında duyuru resmi (thumbnail)
2. **WP-A** — Izgaraların 2 sütundan 4 sütunlu kompakt dizilime geçmesi
3. **WP-C** — Başlıkta hava durumu (sıcaklık + ikon + şehir)
4. **WP-D** — Personel profil fotoğrafı (yönetici + görevli)
5. **WP-E** — Vardiya↔personel ataması + vardiya kartında personel fotoğrafı
6. **WP-F** — Kamera MVP: yönetici sitedeki mevcut kamera sisteminin yayın
   URL'lerini tanımlar; security ana ekranında "Canlı Kamera" şeridi oynatır

**Kapsam dışı (kullanıcı kararı):** Sakinlere avatar yükleme YOK (yalnız
personel rolleri). Kamerada ONVIF keşfi / kayıt / geri izleme YOK — yalnız
elle URL tanımı + canlı oynatma (yalnız RTSP veren eski NVR'lerde site
tarafında HLS/MJPEG dönüştürücü gerekir; platform işi değil).

## Kullanıcı kararları (sohbet, 2026-07-24)

- Kamera: önce ertelendi, sonra **WP-F olarak kapsama alındı** — mevcut
  Entegrasyonlar bölümü (giden webhook) kameraya uygun değil; ayrı
  "Kameralar" tanımı yapılır.
- Hava: backend proxy + Open-Meteo (anahtarsız); tenant konum ayarı,
  varsayılan İstanbul.
- 4'lü dizilim: referanstaki gibi TÜM bölümler (öne çıkan ızgara, Hızlı
  Özet, Yakında); ≤360dp'de 4→2 düşüş.
- Avatar: yalnız yönetici + görevli (admin/yonetici/security/tesis_gorevlisi)
  yükler; sakinler yükleyemez. Amaç: sakinler personeli tanısın.
- Vardiya fotoğrafı: yönetici atama yaptıktan sonra görünür; atama yoksa
  kart bugünkü gibi (fotoğrafsız) kalır.

## Şema değişiklikleri — tek migration `0005_home_gorsel`

Tüm WP'lerin şema ihtiyacı tek migration'da toplanır (0004 support deseni):

1. `tenant.konum_ad TEXT NOT NULL DEFAULT 'İstanbul'` — başlıkta görünen ad.
2. `tenant.konum_lat NUMERIC(9,6) NOT NULL DEFAULT 41.0082`,
   `tenant.konum_lon NUMERIC(9,6) NOT NULL DEFAULT 28.9784` — Open-Meteo
   sorgu koordinatı (İstanbul varsayılanı).
3. `app_user.avatar_key TEXT NULL` — MinIO obje anahtarı
   (announcement.foto_key deseni; tenant-önekli).
4. `shift_assignment` tablosu:
   - `id UUID PK`, `tenant_id UUID FK→tenant CASCADE`
   - `shift_id UUID` + composite FK `(shift_id, tenant_id) → shift(id, tenant_id)
     ON DELETE CASCADE`
   - `user_id UUID` + composite FK `(user_id, tenant_id) → app_user(id, tenant_id)
     ON DELETE CASCADE`
   - `UNIQUE (tenant_id, shift_id, user_id)` — aynı vardiyaya çift atama yok
   - `created_at` — ev stili `_created_at()`
   - RLS: mevcut tenant-izolasyon deseni (diğer tenant tablolarıyla aynı
     policy şablonu); `models.py` mirror'ı güncellenir.
5. `camera` tablosu (WP-F):
   - `id UUID PK`, `tenant_id UUID FK→tenant CASCADE`
   - `ad TEXT NOT NULL`, `stream_url TEXT NOT NULL`
   - `UNIQUE (tenant_id, ad)`
   - `created_at`, `updated_at`; RLS aynı tenant-izolasyon deseni.

## WP-B — Duyurular kartında resim (salt mobil)

`DuyurularKarti` satırına, duyuruda `fotoUrl` varsa sola ~72dp yuvarlatılmış
thumbnail (referans site-sakini.jpeg dizilimi: resim | başlık + gövde tek
satır + tarih + "Yeni" çipi). `Image.network` hata durumunda thumbnail
gizlenir (kart metin-only'ye döner; ekran asla düşmez). Resimsiz duyuruda
bugünkü görünüm aynen korunur. Veri zaten `sonDuyurularProvider`'da
(`foto_url` alanı modelde mevcut) — backend işi yok.

## WP-A — 4'lü kompakt dizilim (salt mobil)

- `ModuleCard`'a `compact` varyantı: küçük pastel ikon çipi (üstte), başlık
  (en çok 2 satır, `Flexible`), altında sayaç satırı; `childAspectRatio`
  kare-yakını. Mevcut geniş varyant "Tüm Modüller" listesinde kalır.
- `RoleHomeBody` öne çıkan ızgara: `crossAxisCount 2 → 4`.
- `YoneticiQuickStats` (`StatTile`): `2 → 4`; StatTile içeriği dar hücreye
  sığacak şekilde sıkılaştırılır (`FittedBox` mevcut deseni).
- `YakindaSection`: `2 → 4`.
- Duyarlılık: `LayoutBuilder` ile kullanılabilir genişlik ≤ 360dp ise
  `crossAxisCount 2`'ye düşer. `small_screen_overflow_test` (320×480) bu
  düşüşü doğrular; 4 sütunlu yol için yeni widget testleri eklenir.
- Sayaç metinleri ("104 Daire", "Borç Yok") kompakt kartta tek satır +
  `ellipsis`.

## WP-C — Hava durumu (backend + mobil)

**Backend:**
- `GET/PATCH /tenant/settings`'e `konum_ad`, `konum_lat`, `konum_lon`
  eklenir (PATCH mevcut RBAC'ıyla — yönetici/admin).
- Yeni `GET /weather` (routers/weather.py): tüm kimlikli roller okur.
  Open-Meteo `current=temperature_2m,weather_code` çağrısı; yanıt
  `{sicaklik_c: float, durum: str, konum_ad: str}`. `durum` = weather_code'un
  basitleştirilmiş eşlemesi (`acik|parcali|kapali|yagmur|kar|sis|firtina`).
- Cache: süreç-içi `{(lat,lon): (veri, zaman)}`, TTL 30 dk — istemciler dış
  servise hiç çıkmaz, tenant başına ≥30 dk'da 1 dış istek.
- Hata işleme: Open-Meteo erişilemezse **süresi geçmiş cache varsa onu
  döndür** (bayat-veri toleransı), hiç veri yoksa `503 weather_unavailable`.
  Timeout kısa (3 sn) — ana ekran isteğini bekletmez (mobil zaten paralel
  provider ile çeker).
- Test notu: testler canlı api container'a gider (monkeypatch yok) — test,
  dış ağa bağımlı olmamak için `WEATHER_BASE_URL` config'i (varsayılan
  Open-Meteo) + testte sahte HTTP sunucusuna yönlendirme kullanır.

**Mobil:**
- `weatherProvider` (`FutureProvider`); `HomeHeader` sağ üstüne referanstaki
  gibi ikon + `24°C` + konum adı. Yükleme/hata → bölüm çizilmez (mevcut
  "sessizce gizle" deseni). Tüm rollerin başlığında görünür.

## WP-D — Profil fotoğrafı (backend + mobil)

**Backend:**
- Upload: mevcut `/uploads/presign` akışı aynen (yeni endpoint yok).
- `PATCH /me/avatar` `{avatar_key: str | null}`: yalnız
  admin/yonetici/security/tesis_gorevlisi (resident → 403). `avatar_key`
  tenant-önek doğrulaması (announcements `_validate_foto_key` deseni —
  IDOR koruması). `null` → fotoğrafı kaldır. Audit: mevcut `audit_user`
  helper'ıyla PROFILE_UPDATE benzeri kayıt.
- Görünürlük (yanıtlara `avatar_url` presign eklenir):
  - `GET /me` — kendi fotoğrafı (başlık + hesap menüsü).
  - Yönetici iletişim kartı (`yonetici_iletisim.py`) — sakinler yönetici
    fotoğrafını görür.
  - `GET /users` / `GET /users/{id}` — admin/yönetici listelerinde.
  - `GET /shifts` — atanan personelin fotoğrafı (WP-E).
- KVKK: değiştirme/kaldırma anında eski MinIO objesi silinir (PATCH içinde
  `delete_objects`). Resident anonimleştirme etkilenmez (sakinler avatar
  yükleyemez); personel için silme ucu bugün yok — eklenirse avatar objesi
  de silinmeli (auth.md notu). Fotoğraf self-servis yüklenir (rıza), amaç
  sınırlı: site içi tanıma.

**Mobil:**
- Profil ekranına "Profil Fotoğrafı" bölümü (yalnız personel rollerinde):
  announcements'daki `imagePicker → presign → PUT → PATCH` deseni; kaldır
  butonu.
- Başlık avatarı + hesap menüsü: `avatar_url` varsa `Image.network`
  (dairesel), yoksa bugünkü baş harf/ikon fallback.
- Yönetici iletişim kartında (sakin görünümü) fotoğraf.

## WP-E — Vardiya ataması + kartta fotoğraf

**Backend (`shifts.py`):**
- `PUT /shifts/{shift_id}/assignments` `{user_ids: [UUID]}` — tam-liste
  değiştirme (declarative replace; tekil ekle/çıkar endpoint'i YOK — basit).
  RBAC: **admin + yonetici**. Atanabilir roller yalnız
  `security|tesis_gorevlisi`; başka rol id'si → 422. Vardiya CRUD admin-only
  kalır. `/contracts/auth.md` §4 güncellenir.
- `GET /shifts` yanıtına `personel: [{user_id, ad, avatar_url}]` eklenir
  (mevcut okuyucular: admin/yonetici/security/tesis_gorevlisi — değişmez).
- Audit: atama değişikliği `audit_user` ile kaydedilir.

**Mobil:**
- `Shift` modeline `personel` listesi (savunmacı parse; yoksa boş).
- `ShiftStatusCard`: atanmış personel varsa ilk kişinin avatarı (dairesel,
  referanstaki konum) + mevcut "N Görevli" satırı gerçek sayıyı gösterir;
  avatar yoksa bugünkü görünüm.
- Atama UI: `VardiyaSection` başlığındaki "Tümünü Gör" → yeni
  `VardiyalarScreen` (vardiya listesi). Yönetici/admin'de her vardiya
  satırında "Personel Ata" → `GET /users?role=security` +
  `?role=tesis_gorevlisi` birleşimi çoklu-seçim sheet'i → PUT. Security /
  tesis_gorevlisi ekranında salt-okunur liste.

## WP-F — Kamera MVP (backend + mobil)

**Backend (yeni `routers/cameras.py`):**
- `GET /cameras` — admin + yonetici + **security** (KVKK: tesis_gorevlisi ve
  resident 403; mevcut rol-görünürlük kararıyla tutarlı).
- `POST /cameras`, `PATCH /cameras/{id}`, `DELETE /cameras/{id}` — admin +
  yonetici. `stream_url` doğrulaması: yalnız `http(s)://` şeması (aksi 422).
  Backend yayını HİÇ çekmez (SSRF yüzeyi yok — istemci oynatır); sır alanı
  yok, URL kimlik bilgisi içerecekse sitenin kendi sorumluluğu (dokümante).
- Audit: create/update/delete `audit_user` ile.

**Mobil:**
- `features/cameras/{domain,data,presentation}`: Camera modeli, camerasProvider.
- Security ana ekranı: liste boş değilse referanstaki gibi yatay **"Canlı
  Kamera" şeridi** (koyu kart + oynat ikonu + ad + "Canlı" noktası); karta
  dokunma → tam ekran `CameraPlayerScreen` (`video_player` paketi, HLS).
  Liste boşsa şerit çizilmez; "Yakında" ızgarasındaki Canlı Kamera kartı
  KALDIRILIR (özellik artık gerçek).
- Yönetici/admin: `/cameras` rotasında yönetim ekranı (liste + ekle/düzenle/
  sil formu — ad + URL). Yönetici ana ekranındaki "Tüm Modüller"e girmez;
  Entegrasyonlar gibi ayarlar-altı erişim yeterli (Ayarlar/Tesis bölümünden
  bağlantı).
- Yeni bağımlılık: `video_player` (pubspec).

## WP-G — Destek taleplerine resim (backend + mobil + admin-web)

Kullanıcı isteği (2026-07-24, yürütme sırasında): yönetici destek talebi
açarken resim ekleyebilsin; admin web panelinden yanıtlarken yine resim
ekleyebilsin. Taraf başına TEK opsiyonel görsel (announcement deseni; çoklu
galeri YAGNI).

**Backend:**
- Migration `0006_support_foto`: `platform_support_ticket`'a `foto_key` +
  `admin_cevap_foto_key` (text NULL). `support_ticket_list` ve
  `support_ticket_answer` SECURITY DEFINER fonksiyonları DROP + yeni imzayla
  yeniden CREATE (answer'a `p_cevap_foto_key` parametresi; app_rw'da UPDATE
  grant'i YOK kararı korunur). REVOKE/GRANT hijyeni tekrarlanır.
- `SupportTicketCreate.foto_key` (yönetici, tenant-önek doğrulaması — IDOR),
  `SupportTicketUpdate.admin_cevap_foto_key` (admin, kendi tenant-önek
  doğrulaması). Çıktılarda presigned `foto_url` + `admin_cevap_foto_url`.
- Upload mevcut `/uploads/presign` ile (yonetici + admin zaten _UPLOADER'da).

**Mobil:** DestekScreen talep formuna opsiyonel görsel (announcements picker
deseni); talep listesinde talep görseli + admin yanıt görseli
(`Image.network` + errorBuilder, kart düşmez).

**Admin-web:** Dosya girişi tarayıcıdan MinIO'ya DEĞİL — BFF üzerinden:
`app/api/uploads/route.ts` FormData dosyayı alır, admin token'ıyla backend
presign'ı çağırır, sunucu tarafında presigned URL'e PUT eder, `foto_key`
döner (dev MinIO CORS sorunu yok). Yanıt formuna dosya seçici; listede her
iki görsel `foto_url`'lerden gösterilir.

## Uygulama sırası ve test

Sıra: **B → A → C → D → E → F** (bağımsızlar önce; E, D'nin avatar_url
altyapısını kullanır; F en sonda — yeni bağımlılık + yeni tablo, diğerlerini
bloklamaz). Her WP kendi commit'i; TDD (önce kırmızı test).
Backend testleri canlı api container'a gider → migration + imaj rebuild
her backend WP'sinde zorunlu (`backend-docker-images-bake-code-no-mount`).
Mobil suite bugün 558+; her WP yeşil suite ile kapanır. Görsel doğrulama:
mevcut Playwright + flutter web release akışı.

## Riskler / kararlar

- 4 sütun dar hücre taşmaları: en riskli WP-A; `small_screen_overflow_test`
  + 320dp golden koşusu şart.
- Open-Meteo dış bağımlılık: prod'da backend'in dış ağa çıkışı var
  (push/harici bildirimlerle aynı yol); bayat-cache toleransı kesinti
  etkisini sınırlar.
- `shift_assignment` kullanıcı silmede `CASCADE` — personel siteden
  çıkarılınca atama otomatik düşer; ayrı temizlik işi yok.
- Vardiya kartında yalnız İLK personel avatarı gösterilir (referansla
  uyumlu); çoklu avatar istifi YAGNI.
