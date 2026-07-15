# Onboarding yeniden kurgu: admin yönetici açar, yönetici ilk girişte tesisi adlandırır

Tarih: 2026-07-15 · Kapsam: migration + backend + mobil + admin-web · Branch: main

## Yeni model (Model A, onaylandı)

- Mobil girişte HERKES yalnız **telefon + parola** görür — mobil self-signup KALKAR.
- **Admin (web)** tenant (geçici/isimsiz, `kurulum_tamamlandi=false`) + **yönetici**
  hesabını BİRLİKTE oluşturur; tenant ID hemen atanır (admin görür, kimse başka görmez).
- Yönetici ilk girişte, tenant `kurulum_tamamlandi=false` ise **"Tesisinizi
  adlandırın"** ekranına düşer (atlanamaz) → adı yazar → tenant adlandırılır +
  `kurulum_tamamlandi=true` → ana ekran.
- Yönetici sakin/görevli ekler/siler/düzenler *(mevcut)*; sakin/görevli yalnız
  kendi tenant'ını/bloğunu görür *(RLS + own-block, mevcut)*.

## Backend

### Migration (0001)
- `tenant.kurulum_tamamlandi boolean NOT NULL DEFAULT true` (mevcut/seed tenant =
  hazır). `create_tenant_with_yonetici`'ye `p_kurulum boolean` parametresi ekle
  (grant/drop güncellenir). Yeni SECURITY DEFINER `list_all_tenants()` (admin cross-
  tenant listeleme; app_rw'ye EXECUTE).

### Endpoints
- **`POST /tenants`** (admin, cross-tenant): `{ yonetici_ad, phone, password? }` →
  tenant (placeholder ad "(Kurulum bekliyor)", slug rastgele, kurulum=false) +
  yönetici (telefon + parola veya gecici kod). Dönüş `{ tenant_id, temp_code? }`.
  SECURITY DEFINER fonksiyonla (RLS bypass).
- **`GET /tenants`** (admin, cross-tenant): tüm tenant listesi
  `[{ id, ad, kurulum_tamamlandi, created_at }]` (list_all_tenants).
- **`POST /tenant/setup`** (yönetici): `{ ad }` → tenant.ad + kurulum_tamamlandi=true.
  Zaten kurulmuşsa 409. Yalnız kendi tenant'ı (RLS).
- `GET /tenant/settings`: `kurulum_tamamlandi` alanı eklenir (mobil yönlendirme için).
- **`POST /auth/signup` KALDIRILIR** (+ rate-limit + test_signup) — yerini admin akışı alır.

### Şemalar
- `TenantAdminCreate { yonetici_ad, phone, password? }`, `TenantAdminCreatedOut
  { tenant_id, temp_code? }`, `TenantSetupRequest { ad }`, `TenantAdminListItem
  { id, ad, kurulum_tamamlandi, created_at }`. `TenantSettings`+`kurulum_tamamlandi`.
  `SignupRequest`/`SignupResponse` kaldırılır.

## Contracts
- `auth.md` matris + not: `/auth/signup` çıkar; `POST/GET /tenants` (admin),
  `POST /tenant/setup` (yönetici) eklenir; `kurulum_tamamlandi` notu.
- `openapi.yaml`: /auth/signup + SignupRequest çıkar; /tenants + /tenant/setup +
  şemalar; TenantSettings.kurulum_tamamlandi.

## Mobil
- **Self-signup KALDIRILIR:** SignupScreen + login "Tesis oluştur" link/caption +
  auth_api.signup + repo/controller.signup + /signup rotası.
- **Setup ekranı:** `/home` route bir `_HomeGate` olur: role=yönetici ve tenant
  `kurulum_tamamlandi=false` ise **SetupTenantScreen** (tesis adı → POST /tenant/setup
  → invalidate → home); değilse HomeScreen. tenant durumu `tenantSetupProvider`
  (GET /tenant/settings) ile.
- `tenant_api`: `getTenantSettings()` (kurulum_tamamlandi) + `setupTenant(ad)`.

## Admin-web
- **"Tesisler" sayfası** (admin): liste (ID + ad + kurulum durumu) + "Yeni tesis +
  yönetici" formu (yönetici ad + telefon → geçici kod gösterilir). API route'ları
  backend `GET/POST /tenants`'e proxy.

## Test
- `test_tenants.py`: admin `POST /tenants` → tenant(kurulum=false)+yönetici+temp_code;
  `GET /tenants` admin listeler (RBAC: yönetici/saha 403); yönetici `POST /tenant/setup`
  → ad + kurulum=true; ikinci setup 409; setup sonrası GET /tenant/settings kurulum=true.
- `test_signup.py` SİLİNİR. `create_tenant_with_yonetici` çağrıları güncellenir.
- Full `down -v && up --build && seed && pytest` (gündüz penceresi); `flutter analyze`.

## Kabul
Admin web'de tesis+yönetici açar (ID görür); yönetici ilk girişte tesisi adlandırır;
mobil giriş yalnız telefon+parola; sakin/görevli kendi tenant'ında; testler yeşil.
