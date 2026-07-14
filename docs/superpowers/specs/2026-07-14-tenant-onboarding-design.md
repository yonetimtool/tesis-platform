# Tenant self-signup + saha personeli — Tasarım (Özellik 3/3)

Tarih: 2026-07-14 · Kapsam: migration + backend + contracts + mobil · Branch: main

## Kararlar (onaylandı)

- **(A) Yönetici self-signup** (public), **(ii) IP rate-limit**, **mobilde**.
- **Saha personeli dahil:** yönetici KENDI tenant'ında `security`/`tesis_gorevlisi`
  hesabı açabilir (admin/yönetici/resident AÇAMAZ — yetki yükseltme yok).

## Backend

### Migration (`0001_initial_schema.py` — taze DB)
- Owner-sahipli `SECURITY DEFINER` fonksiyon
  `public.create_tenant_with_yonetici(p_tenant_ad, p_slug, p_timezone,
  p_yonetici_ad, p_telefon, p_password_hash) RETURNS TABLE(tenant_id, user_id)`:
  tenant + ilk `yonetici` (password_set=true) satırını ATOMIK yaratır (owner
  superuser → RLS bypass), `app_rw`'ye EXECUTE (REVOKE PUBLIC). Slug/telefon
  benzersizlik ihlali → fonksiyon raise → API 409.

### `POST /auth/signup` (public, rate-limited)
- Gövde: `SignupRequest { tenant_ad, yonetici_ad, phone, password(≥8) }`.
- Telefon `normalize_phone` (geçersiz → 422). Slug addan türetilir
  (`_slugify`: Türkçe→ascii, küçük harf, [a-z0-9-], + kısa rastgele ek →
  çakışmasız). Fonksiyon çağrılır; başarıda **TokenPair** (auto-login,
  role=yonetici). Telefon zaten kayıtlı → **409** `conflict`.
- **Rate-limit (ii):** IP başına Redis sabit-pencere (`signup:ip:<ip>`,
  varsayılan 5/saat); aşımda **429** `rate_limited`. İstek IP'si
  `request.client.host` (prod'da XFF notu). Attempt sayılır (start'ta incr).

### RBAC genişletme — `POST /users` (users.py)
- Artık `admin` + `yonetici` çağırabilir. `yonetici` YALNIZ
  `role ∈ {security, tesis_gorevlisi}` açabilir; aksi (`admin`/`yonetici`/
  `resident`) → **403** `forbidden` ("Bu rolu olusturamazsiniz"). `admin` her rolü
  açar. Tenant creating user'dan (RLS). Geçici kod / telefon akışı Özellik 2 ile
  aynı. (Resident'lar `POST /residents` ile açılmaya devam eder.)

## Contracts
- `auth.md`: §1'e self-signup; matrise `POST /auth/signup` (public) +
  `POST /users` (admin ✅, yonetici ✅° saha personeli) güncellenir.
- `openapi.yaml`: `/auth/signup` + `SignupRequest`; `/users` POST RBAC notu.

## Mobil (Flutter)
- **Signup:** giriş ekranına **"Tesis oluştur"** bağlantısı → `SignupScreen`
  (Tesis adı, Adınız, Cep telefonu, Parola, Parola tekrar) → `auth.signup(...)`
  → başarıda authenticated → home. auth_api/repository/controller'a `signup`;
  router `/signup` (unauthenticated erişilebilir).
- **Saha Personeli:** yeni `features/staff/` — yönetici/admin için ekran:
  `GET /users?role=security|tesis_gorevlisi` listesi + **ekle** formu (ad,
  telefon, opsiyonel parola) → `POST /users` (rol seçimi security/
  tesis_gorevlisi) → parola boşsa dönen **geçici kod** gösterilir. Home menüsüne
  `personel` girişi (yalnız yönetici + admin görür). Router `/personel`.

## Test
- `backend/tests/test_signup.py`: happy (signup→token, sonra o telefonla
  `login-phone` 200), telefon çakışması 409, geçersiz telefon 422,
  **rate-limit 429** (deterministik: conftest `redis_client` fixture ile
  `signup:*` anahtarları temizlenir).
- `test_users.py`: yönetici → security 201; yönetici → admin/yönetici/resident
  403; admin → her rol 201.
- `flutter analyze` temiz.

## Kabul
Yönetici mobilden tesis+hesap açar, doğrudan girer (rate-limit'li); kendi
tenant'ında saha personeli ekler (temp kod); global-benzersiz telefon; testler +
analyze yeşil.
