# Panel Görsel Düzeltmeleri + Saha Personeli Fotoğraf Yönetimi — Tasarım

**Tarih:** 2026-07-24
**Durum:** Kullanıcı onaylı (sohbet içinde)
**Referanslar:** `docs/design-refs/{yonetici,gorevli}.jpeg`
**Önceki spec:** `docs/superpowers/specs/2026-07-24-home-gorsel-zenginlestirme-design.md` (WP-A…WP-G)

## Amaç

Uygulanan ana ekran zenginleştirmesinin (WP-A…WP-G) kullanıcı geri bildirimiyle
düzeltilmesi:

1. **P1 — Taşma:** 4'lü ızgaradaki modül kartı yazıları ve "Hızlı Özet"
   bloklarındaki değerler (`₺248.750`, `%86`, `78/120`) dar hücrelere sığmıyor.
2. **P2 — Saha personeli fotoğrafı:** Referans yönetici panelindeki gibi vardiya
   kartlarında saha personelinin fotoğrafını göstermek. Sorun: personelin
   fotoğrafı yok ve yükleme yolu yok.
3. **P3 — Yetki:** Saha personeli (güvenlik + tesis görevlisi) profil
   fotoğrafını **yalnızca yönetici** yükler. **Yönetici + site sakini** kendi
   fotoğrafını yükleyebilir; admin'e gerek yok.

## Kapsam dışı (kullanıcı kararı / YAGNI)

- admin-web tarafında avatar yönetimi.
- Referanstaki sahte "Yönetici" vardiya kartı (yalnız gerçek vardiyalar çizilir).
- admin, güvenlik, tesis görevlisi için self-servis avatar.

---

## P1 — Görsel taşma düzeltmeleri (mobil, backend yok)

Kök neden: 4 sütunlu ızgarada telefon genişliğinde hücre ~85–95dp; `headlineSmall`
değer metni ve uzun başlıklar bu darlıkta `RenderFlex`/ellipsis taşmasına düşüyor.
Referans daha geniş ekranda ve otomatik-küçülen metinle sığıyor.

**Çözüm:**

- **`StatTile` (`widgets/stat_tile.dart`):** `value` metni `FittedBox(fit:
  BoxFit.scaleDown, alignment: centerLeft)` içine alınır — büyük değerler dar
  hücreye küçülerek sığar, taşma imkânsız. `dense` tipografi korunur. Chip pastel
  arka planı (alpha 0.12) referanstaki "soluk/yumuşak" görünümle aynı — değişmez.
- **`ModuleCard` dense (`widgets/module_card.dart`):** başlık ve sayaç
  `FittedBox(scaleDown)` ile sarılır; iki satırlık başlık korunur ama kesilme
  yerine küçülür. Gerekirse `homeGridAspect`/`YoneticiQuickStats` `childAspectRatio`
  bir tık artırılır (kart biraz uzar) — test yeşilken bırakılır.
- **Doğrulama:** mevcut `small_screen_overflow_test`, `home_grid_test`,
  `stat_tile_test`, `module_card_test` yeşil kalır; 320/360/412dp'de
  `tester.takeException()` null (RenderFlex overflow yok). Değer/başlık metni
  hâlâ ekranda bulunur.

**Arayüz değişmez:** `StatTile`/`ModuleCard` imzaları aynı; yalnız iç düzen.

---

## P2/P3 — Saha personeli fotoğraf yönetimi (backend RBAC + mobil)

### Yetki modeli (auth.md §4 güncellenir)

| Uç | admin | yönetici | güvenlik | tesis_gör. | resident |
|----|:---:|:---:|:---:|:---:|:---:|
| `PATCH /me/avatar` (kendi) | ❌ | ✅ | ❌ | ❌ | ✅ |
| `PATCH /users/{id}/avatar` (saha personeli) | ❌ | ✅ | ❌ | ❌ | ❌ |

- `PATCH /me/avatar` RBAC **yönetici + resident** olur (eski: personel rolleri).
  Diğerleri 403. Mevcut `test_avatar` güncellenir (yönetici hâlâ yükler; resident
  artık 403 yerine 200; security/tesis_gorevlisi artık 403).
- Yeni `PATCH /users/{id}/avatar` — **yalnız yönetici**. Hedef kullanıcı aynı
  tenant'ta (RLS) ve rolü ∈ {security, tesis_gorevlisi} olmalı; değilse 422.
  `avatar_key` yöneticinin kendi tenant namespace'inde (IDOR — `_validate_prefix`).
  `null` fotoğrafı kaldırır; eski MinIO objesi silinir. Audit: `AVATAR_UPDATE`
  (meta'da hedef `user_id`).

### Backend değişiklikleri

- **`routers/me.py`:** `_AVATAR_ROLLER` → `require_role("yonetici", "resident")`.
  `_user_out` zaten `avatar_url` doldurur.
- **`routers/users.py`:** yeni `PATCH /users/{id}/avatar` (yönetici). Yardımcı:
  hedefi `get_or_404(AppUser)` ile al, rol ∈ saha kontrolü, prefix doğrulaması,
  eski obje silme, `UserAdminOut` döner (avatar_url dolu).
- **`schemas.py`:** `UserAdminListItem`'a `avatar_url: str | None = None`
  (staff ekranı + vardiya kartları için); `UserAdminOut`'a da `avatar_url` (zaten
  UserOut'ta var deseni — kart görünümü). `AvatarUpdate` yeniden kullanılır.
  `GET /users` (`list_users`) ve `GET /users/{id}` avatar_url'ü presign ile
  doldurur (yalnız saha personeli listelendiği için maliyet düşük).
- **Vardiya kartları:** `shifts.py._personel_map` zaten `AppUser.avatar_key`'den
  presign üretiyor — yönetici foto atayınca otomatik görünür. **Değişiklik yok.**
- **auth.md §4** iki satır güncellenir.
- **Testler:** `test_avatar.py` güncellenir + `PATCH /users/{id}/avatar` için
  yeni testler (yönetici saha personeline foto atar; resident/güvenlik 403;
  yönetici hedefi non-saha ise 422; yabancı önek 422; tenant izolasyonu 404).

### Mobil değişiklikleri

- **`staff/data/staff_api.dart`:** `StaffMember`'a `avatarUrl`; liste parse'ında
  `avatar_url`. Yeni `setStaffAvatar(id, fotoKey?)` (`PATCH /users/{id}/avatar`)
  + presign/upload yardımcıları (announcements deseni, avatar_api ile aynı).
- **`staff/presentation/staff_screen.dart`:** ekle/düzenle formuna galeri/kamera
  foto seçici + önizleme + kaldır. Akış: (oluşturma) `POST /users` → dönen id →
  foto seçiliyse presign+upload+`setStaffAvatar`; (düzenleme) mevcut id ile aynı.
  Listede satır başına `CircleAvatar` (avatarUrl varsa NetworkImage, yoksa ikon).
- **`profile/presentation/profile_screen.dart`:** `_AvatarCard` görünürlüğü
  `role == yonetici || role == resident` (eski: `role != resident`).
- **Testler:** `staff_screen`/`staff_api` testlerinde avatar override; profil
  ekranı avatar görünürlük testi (yönetici+resident var, güvenlik yok);
  savunmacı parse (`avatarUrlFromUsers`).

### Veri akışı

1. Yönetici StaffScreen'de personel oluşturur/düzenler + foto seçer.
2. Mobil: presign → MinIO PUT → `PATCH /users/{id}/avatar {avatar_key}`.
3. Yönetici personeli vardiyaya atar (mevcut `/vardiyalar`).
4. `GET /shifts` → `_personel_map` presign avatar_url → VardiyaSection kartında
   referanstaki gibi fotoğraf.

### Hata durumu

- Foto yükleme hatası create'i BOZMAZ: kullanıcı yine de oluşur, foto atlanır,
  SnackBar uyarısı (announcements deseni).
- Ağ/parse hatası ana ekranı/personel ekranını düşürmez (sessiz null → ikon).

---

## Test stratejisi

- **Backend:** canlı api container (mevcut fixture); avatar RBAC + rol kısıtı +
  IDOR + tenant izolasyonu. `test_avatar.py` güncel + yeni users-avatar testleri.
- **Mobil:** `flutter analyze` temiz + tüm suite yeşil; taşma testleri
  (`takeException()` null), profil avatar görünürlük, staff avatar parse.
- **Doğrulama:** admin-web dokunulmaz (build gerekmez).
