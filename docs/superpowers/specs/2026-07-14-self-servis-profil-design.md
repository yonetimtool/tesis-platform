# Self-servis Profil — Tasarım (Özellik 1/3)

Tarih: 2026-07-14 · Kapsam: mobil + backend + contracts · Branch: main

## Amaç

Giriş yapmış her kullanıcı, sağ üstteki **profil ikonundan** açılan bir ekranda
**kendi parolasını** ve **kendi telefon numarasını** (+ aranmaya rıza) güncelleyebilsin.
Bu, daha büyük "telefon-ile-giriş + tenant onboarding" işinin bağımsız, düşük
riskli ilk parçasıdır (o parçaların A/B/C tenant kararından etkilenmez).

## Kapsam dışı (sonraki parçalar)

- Telefon-ile-giriş / tenant adı yazmama (Özellik 2).
- Yönetici tarafından tenant oluşturma (Özellik 3).
- SMS/OTP ile numara doğrulama (altyapı yok; numara doğrudan kaydedilir).

## Kararlar (onaylandı)

1. Parola değiştirmede **mevcut parola zorunlu** (standart güvenlik).
2. Kullanıcı **kendi `aranabilir` (aranmaya rıza)** ayarını da yönetir.
3. Numara **OTP'siz doğrudan** kaydedilir.

## Backend

Router: mevcut `app/routers/me.py` (prefix'siz; `/me/...` yolları). Yeni uçlar:

- `GET /me/profile` → `MeProfileOut` — TÜM roller (kendi). Kimlik + iletişim
  alanlarını döner: `id, ad, email, role, telefon, aranabilir, is_active`.
- `PATCH /me/password` → **204** — TÜM roller (kendi). Gövde:
  `PasswordChangeRequest { current_password: str, new_password: str (min 8) }`.
  Akış: `verify_password(current, user.password_hash)` başarısızsa **400**
  `invalid_credentials` ("Mevcut parola hatalı."). Başarıda `password_hash`
  yeni bcrypt hash olur, `updated_at=now()`. (Refresh token'lar iptal EDİLMEZ —
  basit tutulur; oturum devam eder.)
- `PATCH /me/contact` → `MeProfileOut` — TÜM roller (kendi). Gövde mevcut
  `UserContactUpdate { telefon?, aranabilir? }` (en az bir alan). Kendi
  `telefon`/`aranabilir` alanını günceller, `updated_at=now()`.

Not: `get_current_user` zaten `get_tenant_db` oturumunu paylaşır (RLS + commit),
tıpkı `PATCH /users/{id}/contact`'taki gibi mutasyon + `session.begin()` commit.
Parolasız (temp-kod bekleyen) sakinin geçerli access token'ı olamaz → uçlar
implicit olarak yalnız gerçek oturumlara açık.

Şemalar (`app/schemas.py`): `MeProfileOut` (from_attributes), `PasswordChangeRequest`.
`UserContactUpdate` yeniden kullanılır.

## Contracts

- `contracts/auth.md` §4 matrisine 3 satır (tüm roller ✅ kendi) + kısa not.
- `contracts/openapi.yaml`'a 3 uç + 2 şema.

## Mobil (Flutter)

- `AppRoutes.profile = '/profile'` + `GoRoute` → `ProfileScreen`.
- `home_screen.dart` AppBar: ayarlar ikonundan önce **profil ikonu**
  (`Icons.person_outline`) → `context.push(AppRoutes.profile)`.
- Yeni `features/profile/`:
  - `data/profile_api.dart` — `ProfileApi(dio)`: `getProfile()`,
    `changePassword(current,new)`, `updateContact(telefon, aranabilir)`;
    kimlikli `dioProvider` kullanır; `provider`.
  - `domain/profile.dart` — `Profile { ad, email, role, telefon, aranabilir }`.
  - `presentation/profile_screen.dart` — `profileProvider` (FutureProvider) ile
    yüklenir; üstte ad+rol+telefon; iki `Card`: **Parola değiştir** (mevcut/yeni/
    yeni tekrar; client-side eşleşme + min 8) ve **İletişim** (telefon alanı +
    "Aranabilir" switch). Başarı/hata `SnackBar`; iletişim kaydında provider
    invalidate → güncel telefon yenilenir.

## Test

- `backend/tests/test_profile.py` (canlı sunucu, httpx fixture):
  - `GET /me/profile` alanları döner.
  - `PATCH /me/password` doğru mevcut parola → 204; yeni parolayla login olur,
    eski parola **401**.
  - Yanlış mevcut parola → **400**; kısa yeni parola → **422**.
  - `PATCH /me/contact` telefon+aranabilir → `GET /me/profile`'da yansır.
  - Sakin (resident) de kendi parolasını değiştirebilir.
- `flutter analyze` temiz.

## Kabul

Profil ikonu → ekran; parola + telefon/rıza self-servis güncellenir; yalnız
kendi kaydı; auth.md + openapi güncel; pytest + analyze yeşil.
