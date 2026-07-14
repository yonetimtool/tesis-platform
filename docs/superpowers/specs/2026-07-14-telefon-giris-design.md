# Telefon-ile-giriş + geçici parola — Tasarım (Özellik 2/3)

Tarih: 2026-07-14 · Kapsam: migration + backend + contracts + seed + mobil + admin-web · Branch: main

## Kararlar (onaylandı)

- **(A)** Telefon **global benzersiz** → giriş telefon+parola, tenant otomatik çözülür.
- **Q1→(1):** Mobil roller (yönetici/güvenlik/tesis görevlisi/sakin) telefonla girer;
  **admin paneli (`/auth/login`, e-posta+tenant_slug) DEĞİŞMEZ.**
- **Q2→(a):** İlk girişte geçici parola → **zorunlu** kalıcı parola belirleme
  (mevcut `/auth/set-password` akışı yeniden kullanılır).
- E-posta **opsiyonel** olur (girişte kullanılmaz). `/auth/login-resident` **kalkar**.

## Migration (`0001_initial_schema.py` — taze DB, ALTER yok)

- `app_user.telefon` → global kısmi UNIQUE: `CREATE UNIQUE INDEX uq_app_user_telefon
  ON app_user (telefon) WHERE telefon IS NOT NULL` (tenant'lar arası benzersiz).
- Yeni `public.tenant_id_by_phone(p_phone text)` SECURITY DEFINER (search_path='',
  STABLE): `SELECT tenant_id FROM public.app_user WHERE telefon = p_phone` — yalnız
  telefon→tenant_id; REVOKE PUBLIC + GRANT app_rw. downgrade'de DROP.
- `ck_app_user_staff_email` **kaldırılır** (email herkes için opsiyonel).

## Backend

- **`normalize_phone(raw) -> str`** (security.py): boşluk/tire/parantez temizle;
  baştaki `0`→`+90`; `+90...`/`+...` korunur; sonuç `^\+\d{8,15}$` değilse `ValueError`.
- **`POST /auth/login-phone`** `{ phone, password }` → `PhoneLoginResponse`
  (= ResidentLoginResponse şekli: `password_setup_required` + opsiyonel token'lar +
  `setup_token`). Akış: normalize → `tenant_id_by_phone` → set_tenant → kullaniciyi
  telefonla yükle → kalıcı parola eşleşir: TokenPair; geçici kod eşleşir
  (`password_set=false`): setup_token; aksi/hata → **401 invalid_credentials**.
- **`/auth/set-password`** aynen (setup_token user+tenant taşır).
- **`/auth/login-resident` + helper KALDIRILIR** (+ testleri).
- **Oluşturma (geçici parola + telefon):**
  - `POST /residents`: `telefon` zorunlu + normalize + benzersiz (çakışma 409);
    geçici kod üretimi + düz metin yanıt korunur.
  - `POST /users`: `telefon` zorunlu + normalize + benzersiz; `password` opsiyonel —
    verilirse `password_set=true`, verilmezse geçici kod üretilir; yanıt
    `temp_code` (yalnız kod üretildiyse) döner.

## Seed

- Tüm `USERS` + resident2'ye benzersiz normalize telefon (`+90...`). Personel
  parolalı (password_set=true) + telefon; resident2 geçici kod + telefon.

## Mobil (Flutter)

- `login_screen.dart`: tek **Telefon** + **Parola** (tenant/e-posta/daire-no/
  Personel-Sakin geçişi kalkar). `auth_api.loginPhone` + `auth_controller.loginPhone`
  (ResidentLoginResult yeniden kullanılır — setup akışı zaten var). İlk giriş →
  mevcut set-password ekranı.

## Admin-web

- Giriş değişmez. Kullanıcı oluşturma formuna **telefon** alanı eklenir; parola
  boşsa yanıttaki **geçici kod** gösterilir.

## Contracts

- `auth.md` §1: telefon-giriş olarak yeniden yazılır; matris `POST /auth/login-phone`
  (mobil roller ✅); `login-resident` çıkarılır; §1.1 (email/panel) kalır.
- `openapi.yaml`: `/auth/login-phone` + `PhoneLoginRequest`/`PhoneLoginResponse`;
  residents/users create'e `telefon` + temp_code yanıtı; `login-resident` çıkarılır.

## Test

- `/auth/login` (email) STAYS → world'ün email-login yardımcıları çalışmaya devam eder.
- `test_auth_phone.py` (yeni): telefonla giriş happy-path, ilk giriş→setup→set-password,
  yanlış parola 401, bilinmeyen telefon 401, global benzersizlik (2 tenant aynı numara
  → 409 create).
- `conftest.world`: kullanıcılara benzersiz `telefon` eklenir (+`_phone_headers`).
- residents/users create testleri: `telefon` eklenir; `test_auth_resident.py` kaldırılır.
- Hedef: full `down -v && up --build && seed && pytest` yeşil; `flutter analyze` temiz.

## Kabul

Telefonla giriş (tenant otomatik); ilk giriş zorunlu parola belirleme; global
benzersiz telefon; admin paneli e-posta ile çalışır; testler + analyze yeşil.
