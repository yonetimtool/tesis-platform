# Auth & RBAC Modeli — v0

Tek dogruluk kaynagi. Backend (FastAPI) ve istemciler (Flutter / Next.js) bu
sozlesmeye gore gelistirir.

## 1. Genel Yaklasim

- **JWT** tabanli, `access` + `refresh` token cifti.
- Token'lar **imzali** (HS256 veya RS256 — bkz. §6). Istemci token icerigine
  guvenmez; backend her istekte imzayi dogrular.
- **Tenant her zaman token'dan cikarilir.** Istemci hicbir endpoint'te
  `tenant_id` gondermez/secemez. Backend, access token'daki `tenant_id`'yi alir
  ve her istek basinda DB oturum degiskenine yazar:
  `SET app.current_tenant_id = '<tenant_id>'` → RLS bu degeri kullanir.
- Yetkilendirme iki katman:
  1. **RBAC** (uygulama katmani): rol → endpoint erisimi (bu dosya, §4).
  2. **RLS** (DB katmani): tenant izolasyonu (bkz. `/contracts/db`).

### 1.1 Mobil giris — telefon ile (tenant OTOMATIK, `POST /auth/login-phone`)

> **Iki ayri giris yolu vardir:** MOBIL roller (yonetici/security/
> tesis_gorevlisi/resident) **cep telefonu + parola** ile
> `POST /auth/login-phone`'dan girer (bu bolum); tenant **numaradan otomatik**
> cozulur — istemci `tenant_slug`/e-posta/daire no GIRMEZ. ADMIN paneli
> (admin-web) ayri kalir: `POST /auth/login` ile **e-posta + tenant_slug**
> (§1.2).

`app_user.telefon` **GLOBAL benzersizdir** (tenant'lar arasi; kismi indeks
`uq_app_user_telefon`, NULL serbest) ve login anahtaridir. Numara **E.164**
normalize edilir (`normalize_phone`: bosluk/tire silinir, `0`→`+90`).
`POST /auth/login-phone` istegi `phone` + `password` alir (bkz. `openapi.yaml`
`PhoneLoginRequest`).

Akis:
1. `phone` → `tenant_id` cozumu: `app_user` **RLS** altinda oldugu ve henuz
   tenant baglami olmadigi icin, uygulama rolu tabloyu dogrudan okuyamaz.
   Cozum, owner-sahipli **`SECURITY DEFINER`** fonksiyon
   `public.tenant_id_by_phone(phone)`'dur; yalnizca telefon → tenant_id
   eslemesini doner (baska veri sizmaz; global benzersiz indeks tek satiri
   garanti eder), `app_rw`'ye `EXECUTE` verilir.
2. `tenant_id` bulununca `set_config('app.current_tenant_id', <id>, true)` ile
   baglam kurulur; kullanici **RLS altinda** telefonla yuklenir.
3. Kalici parola (`password_set=true`) eslesirse → tam `TokenPair`. Gecici kod
   (`password_set=false`) eslesirse → oturum YOK, `setup_token`
   (`password_setup_required=true`; §1.3). Basarisiz her adim (numara/parola/
   kod) → **401** `invalid_credentials` (hangi adimin patladigi sizdirilmaz).

- **Ayni dairede birden fazla sakin** (orn. esler): her birinin KENDI telefonu +
  KENDI parolasi vardir; telefon global benzersiz oldugundan hesap dogrudan
  cozulur (daire no login KALDIRILDI).
- Aktif olmayan (`is_active=false`) kullanici giremez.

### 1.2 Panel girisi — e-posta + tenant_slug (`POST /auth/login`, admin)

Admin paneli (admin-web) `tenant_slug` + `email` + `password` ile girer
(`LoginRequest`). `tenant.slug` → `tenant_id` cozumu owner-sahipli
`public.tenant_id_by_slug(slug)` SECURITY DEFINER ile yapilir; kullanici RLS
altinda `email` ile yuklenir, parola + `is_active` dogrulanir (basarisiz → 401).
`app_user.email` **opsiyoneldir** ve **tenant-ici** benzersizdir
(`UNIQUE (tenant_id, email)`); girise girmez, bildirim/yedek amaclidir. `tenant.
slug`: kucuk harf/rakam/tire, benzersiz.

> **PAROLA POLITIKASI (tum parola olusturma/belirleme/degistirme uclari):** en az
> **8 karakter + ≥1 buyuk harf + ≥1 rakam + ≥1 sembol** (Turkce harfler dahil).
> Backend `validate_password_strength` ile zorlar (`SetPasswordRequest`,
> `SignupRequest`, `PasswordChangeRequest`, `UserCreate/UserUpdate.password`,
> `ResidentCreate.password`); ihlal → **422**. Login parolayi yeniden dogrulamaz.

### 1.3 Ilk giris — gecici parola → zorunlu parola belirleme

Kullanici olusturulurken **tek seferlik gecici kod** uretilir (temp password
first); kullanici telefonla girip kalici parolasini belirler.

1. Yonetici sakini `POST /residents` (telefon zorunlu), admin personeli
   `POST /users` (telefon zorunlu; `password` verilmezse) ile acar. Sunucu
   **tek seferlik gecici kod** uretir (orn. `K7MR-2QWX`); kod YALNIZ olusturma
   yanitinda duz metin doner (`temp_code`), yonetim kullaniciya iletir. DB'de
   **bcrypt hash** saklanir (`temp_code_hash`); `password_set=false`.
2. Kullanici `login-phone`'a telefon + gecici kodla gelir. Kod dogruysa
   **oturum verilmez**; kisa omurlu (~10 dk, `type=pwd_setup`) `setup_token`
   doner (`password_setup_required=true`). Token API erisimi SAGLAMAZ; yalniz
   `POST /auth/set-password`'de gecer.
3. `POST /auth/set-password` (setup_token + yeni parola): parola bcrypt ile
   kaydedilir, `password_set=true`, `temp_code_hash=NULL` (**tek kullanimlik**)
   ve tam `TokenPair` doner.
4. Sonraki girisler: telefon + kalici parola → normal oturum.

- Token'lar (access/refresh) ve rol claim'i tum rollerde AYNIDIR (§2); refresh
  rotation aynen gecerlidir. `setup_token` ~10 dk; gecici kod tek kullanimlik.

### 1.4 Onboarding (Model A) — admin tesis acar, yonetici ilk giriste adlandirir

Mobil self-signup KALDIRILDI (mobil giris yalniz telefon+parola). Yeni akis:

1. **`POST /tenants` (ADMIN, cross-tenant):** admin bir tenant (isimsiz — yer
   tutucu ad "(Kurulum bekliyor)", `kurulum_tamamlandi=false`, slug rastgele) +
   ilk `yonetici` hesabini BIRLIKTE acar. Govde `{ yonetici_ad, phone, password? }`
   — parola verilirse dogrudan belirlenir, verilmezse **gecici kod** (bir kez
   `temp_code` doner, admin yoneticiye iletir). `tenant` RLS FORCE oldugundan
   owner-sahipli **`SECURITY DEFINER`** `create_tenant_with_yonetici(...)` ile
   atomik. Telefon global benzersiz → **409**. Donus `{ tenant_id, yonetici_user_id,
   temp_code? }`; **`tenant_id` GIZLI kimliktir** (yalniz admin gorur).
2. **`GET /tenants` (ADMIN):** tum tesisleri listeler `{ id, ad, kurulum_tamamlandi,
   created_at }` (owner-sahipli `list_all_tenants()`; baska tenant verisi donmez).
3. Yonetici telefonla girer (gecici kodla ise §1.3 set-password). Ardindan tenant
   `kurulum_tamamlandi=false` oldugundan mobil **"Tesisinizi adlandirin"** ekranini
   gosterir (`GET /tenant/settings.kurulum_tamamlandi`).
4. **`POST /tenant/setup` (YONETICI):** `{ ad }` → tenant.ad + `kurulum_tamamlandi
   =true`. Zaten kuruluysa **409**. Sonrasi normal ana ekran.

**Tesis detay & yonetici konfigurasyonu (ADMIN, cross-tenant — admin-web):** admin
bir tesise girip yoneticisini yonetir + tenant'i siler. Hepsi owner-sahipli
SECURITY DEFINER (`tenant_detail` / `update_tenant_yonetici` /
`reset_tenant_yonetici_credential` / `delete_tenant`), yalniz admin:
- **`GET /tenants/{id}`** → tenant + yoneticisi (ad, telefon, is_active, password_set).
- **`PATCH /tenants/{id}`** `{ ad }` → tesis ADINI degistirir (rename/duzeltme);
  `kurulum_tamamlandi=true` olur. Bilinmeyen tesis **404**; `ad` < 2 karakter **422**.
- **`PATCH /tenants/{id}/yonetici`** `{ ad?, phone?, is_active? }` (kismi). Telefon
  global benzersiz → **409**; yonetici yoksa **404**.
- **`POST /tenants/{id}/yonetici/reset-credential`** → parola silinir + yeni tek
  seferlik gecici kod (**bir kez** doner); yonetici tekrar ilk-giris akisina duser.
- **`DELETE /tenants/{id}`** → tenant + TUM verisi (yonetici + duyuru + daire +
  sakin...) `ON DELETE CASCADE` ile silinir (GERI ALINAMAZ). Bilinmeyen tesis **404**.

> **`POST /users` — yonetici saha personeli acar (Ozellik 3):** yonetici (tenant'i
> admin acti — §1.4) KENDI tenant'inda `security`/`tesis_gorevlisi` hesabi
> olusturur (telefon + gecici kod / parola — §1.3 ile ayni). `yonetici`,
> `admin`/`yonetici`/`resident` rolu ACAMAZ → **403** (yetki yukseltme yok;
> resident'lar `POST /residents` ile acilir). `admin` her rolu acar. Tenant
> olusturan kullanicidan alinir (RLS).
>
> **Saha personeli DUZENLEME/pasiflestirme/parola-sifirlama (Parca C):** yonetici
> (+admin) `PATCH /users/{id}` ile saha personelini duzenler (ad/telefon/rol —
> yon rolu YALNIZ `security`↔`tesis_gorevlisi` yapabilir, saha disina cekemez →
> **403**; admin herkesi duzenler), `is_active=false` ile **pasiflestirir**
> ("cikar" = giris engellenir, gecmis korunur), `POST /users/{id}/reset-password`
> ile yeni gecici kod uretir (bir kez). yonetici saha-disi (admin/yonetici/
> resident) kullaniciya bu uclarda dokunamaz → **403**.
>
> **Site sakini yonetimi (yonetici):** sakin KENDI kayit OLAMAZ; yonetici (+admin)
> ekler/listeler/duzenler/siler/parola-sifirlar. `POST /residents` (ad + telefon
> + daire no -> gecici kod). `GET /residents` sakin listesi (ad + aktif daire no
> + durum; **telefon KVKK geregi donmez**). `PATCH /residents/{id}` ad ve/veya
> telefon (global benzersiz; cakisma 409). `POST /residents/{id}/reset-password`
> yeni gecici kod uretir (bir kez doner; kilitlenme/parola unutma).
> **`DELETE /residents/{id}` AKILLI sil — telefon HER DURUMDA serbest kalir:**
> gecmissiz sakin (yeni/hatali kayit) TAMAMEN silinir (`deleted=true`); gecmisi
> olan sakin (FK RESTRICT: sikayet/rezervasyon vb.) silinemez -> pasiflestirilir
> + `telefon=NULL` (`deleted=false`). Boylece ayni numarayla yeniden kayit her
> zaman mumkun. role=resident degilse 404. Saha/sakin roller erisemez (403).
> (Daire-bazli `/units/{id}/residents` atama/cikarma admin-only kalir.)

## 2. Token Yapisi

### Access token claim'leri

| Claim   | Tip     | Aciklama                                            |
|---------|---------|-----------------------------------------------------|
| `sub`   | string  | user_id (app_user.id, UUID)                         |
| `tenant_id` | string | Kullanicinin tenant'i (UUID)                    |
| `role`  | string  | `admin` \| `yonetici` \| `security` \| `tesis_gorevlisi` \| `resident` |
| `type`  | string  | `access`                                            |
| `iat`   | number  | Verilis zamani (Unix epoch, UTC)                    |
| `exp`   | number  | Bitis zamani (Unix epoch, UTC)                      |
| `jti`   | string  | Token kimligi (iptal/izleme icin)                   |

### Refresh token claim'leri

| Claim   | Tip     | Aciklama                                            |
|---------|---------|-----------------------------------------------------|
| `sub`   | string  | user_id                                             |
| `tenant_id` | string | Tenant (UUID)                                   |
| `type`  | string  | `refresh`                                           |
| `iat`   | number  | Verilis zamani                                      |
| `exp`   | number  | Bitis zamani                                        |
| `jti`   | string  | Rotation/iptal icin benzersiz kimlik                |

> Refresh token sadece `POST /auth/refresh` icin kullanilir; kaynak
> endpoint'lerinde **kabul edilmez** (`type` kontrol edilir).

## 3. Token Sureleri ve Refresh Akisi

| Token   | Varsayilan sure | Not                                         |
|---------|-----------------|---------------------------------------------|
| access  | **15 dakika**   | Kisa omurlu; her istekte `Authorization` header'inda |
| refresh | **30 gun**      | Uzun omurlu; guvenli saklama (mobilde secure storage) |

### Refresh akisi (rotation ile)

1. Istemci `POST /auth/login` → `{ access_token, refresh_token }`.
2. Access token suresi dolunca istemci `POST /auth/refresh` (govdede
   `refresh_token`) cagirir.
3. Backend refresh token'i dogrular, **eskisini iptal eder (rotation)** ve yeni
   bir `access + refresh` cifti doner.
4. Iptal edilmis / suresi dolmus / yeniden kullanilmis refresh token → `401`.
   (Reuse tespiti: ayni `jti` ikinci kez gelirse o kullanicinin tum refresh
   token'lari iptal edilir — token sizintisi savunmasi.)

> Logout = istemci token'lari siler + (opsiyonel) backend refresh `jti`'yi
> iptal listesine ekler. v0'da server-side iptal listesi onerilir.

## 4. RBAC Matrisi

Roller: **admin** (platform admini — biz/gelistirici; TUM tesisler, panel),
**yonetici** (site yoneticisi — musteri; KENDI tenant'i, mobil),
**security** (guvenlik gorevlisi), **tesis_gorevlisi** (temizlik + bahcivan +
teknik — birlesik saha rolu), **resident** (site sakini).

> **PANEL (admin-web) YALNIZ `admin` icindir.** `yonetici` panele GIRMEZ;
> tum islerini mobil uygulamadan yapar. `yonetici` kendi tenant'iyla
> SINIRLIDIR (RLS tenant izolasyonu + token'daki `tenant_id`); cross-tenant
> hicbir kaynaga erisemez. `admin` platform genelinde calisir.

Lejant: ✅ izinli · ❌ yasak · 🔵 sadece kendi kayitlari/okuma

Kisaltmalar: yon = yonetici · sec = security · tg = tesis_gorevlisi · res = resident

| Endpoint                              | admin | yon | sec | tg  | res |
|---------------------------------------|:-----:|:---:|:---:|:---:|:---:|
| `POST /auth/login` (panel, email)     |  ✅   | ✅° | ✅° | ✅° | ✅° |
| `POST /auth/login-phone` (mobil, tel) |  ❌   | ✅  | ✅  | ✅  | ✅  |
| `POST /auth/set-password` (ilk giris) |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `POST /residents` (sakin ac + kod)    |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /residents` (site sakin listesi)|  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PATCH /residents/{id}` (ad/telefon)  |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /residents/{id}/reset-password` |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `DELETE /residents/{id}` (akilli sil) |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /auth/refresh`                  |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `GET  /me/profile` (kendi)            |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `PATCH /me/password` (kendi)          |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `PATCH /me/contact` (kendi tel/riza)  |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `PATCH /me/avatar` (profil fotografi) |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `GET  /shifts` (liste/detay)          |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /shifts`                        |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PATCH /shifts/{id}`                  |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `DELETE /shifts/{id}`                 |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PUT  /shifts/{id}/assignments` (personel)| ✅ | ✅  | ❌  | ❌  | ❌  |
| `GET  /checkpoints` (liste/detay)     |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /checkpoints` (tanim)           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PATCH /checkpoints/{id}`             |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `DELETE /checkpoints/{id}`            |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PUT  /checkpoints/{id}/sdm-key` (kripto)| ✅ | ❌  | ❌  | ❌  | ❌  |
| `GET  /patrol-plans` (liste/detay)    |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /patrol-plans` (yonetici tanimlar)| ✅  | ✅  | ❌  | ❌  | ❌  |
| `PATCH /patrol-plans/{id}`            |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `DELETE /patrol-plans/{id}`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /patrol-plans/{id}/checkpoints` |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `PUT  /patrol-plans/{id}/checkpoints` |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /scans` (okutma)                |  ✅   | ❌  | ✅  | ✅  | ❌  |
| `GET  /scans` (gun-gun tarama raporu) |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /dashboard/live`                |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `GET  /patrol-windows`                |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `GET  /me/patrol-window`              |  ✅   | ❌  | ✅  | ❌  | ❌  |
| `GET  /notifications`                 |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `PATCH /notifications/{id}`           |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `GET  /announcements` (liste/detay)   |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `POST /announcements`                 |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PATCH /announcements/{id}`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `DELETE /announcements/{id}`          |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /complaints` (liste/detay, talep)|  ✅   | ✅  | ✅° | ✅° | ✅° |
| `POST /complaints` (talep ac)         |  ❌   | ❌  | ✅  | ✅  | ✅  |
| `POST /complaints/{id}/convert` (is emrine donustur)| ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /complaints/{id}/resolve` (dogrudan coz)| ✅ | ✅ | ❌ | ❌ | ❌ |
| `POST /complaints/{id}/decline` (reddet)| ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET /units/by-no/{no}/residents`     |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `POST /visitors` (ziyaretci kaydi)    |  ❌   | ❌  | ✅  | ❌  | ❌  |
| `GET  /visitors` (liste/detay)        |  🔒   | 🔒  | ✅  | ❌  | 🎯  |
| `PATCH /visitors/{id}` (guvenlik duzenler: ad/daire/hedef/not)| ❌ | ❌ | ✅ | ❌ | ❌ |
| `POST /kargo` (paket kaydi)           |  ❌   | ❌  | ✅  | ❌  | ❌  |
| `GET  /kargo` (liste/detay)           |  🔒   | 🔒  | ✅  | ❌  | 🔵  |
| `PATCH /kargo/{id}` (teslim aldim)    |  ❌   | ❌  | ❌  | ❌  | ✅* |
| `POST /unit-access-request`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /unit-access-request`           |  ✅   | 👤  | ❌  | ❌  | 🏠  |
| `PATCH /unit-access-request/{id}`     |  ❌   | ❌  | ❌  | ❌  | ✅🏠|
| `GET  /common-areas`                  |  ✅   | ✅  | ✅  | ✅  | ✅° |
| `GET  /common-areas/{id}/slots`       |  ✅   | ✅  | ✅  | ✅  | ✅° |
| `POST/PATCH /common-areas*`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /reservations` (talep)          |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `GET  /reservations` (liste/detay)    |  ✅   | ✅  | ❌  | ❌  | 🔵  |
| `PATCH /reservations/{id}` (onay/red) |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /events` (liste/detay + sayilar)|  ✅   | ✅  | ✅  | ✅  | ✅  |
| `POST/PATCH/DELETE /events*`          |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PUT  /events/{id}/rsvp`              |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `GET  /site-rules` (liste/detay + ?q=)|  ✅   | ✅  | ✅  | ✅  | ✅  |
| `POST/PATCH/DELETE /site-rules*`      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /external-services` (dis hizmetler + not)| ✅ | ✅ | ✅ | ✅ | ✅ |
| `POST/PATCH/DELETE /external-services*` + `PUT /note`| ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET  /tasks` (liste/detay)           |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /tasks`                         |  ✅   | ✅* | ❌  | ❌  | ❌  |
| `PATCH /tasks/{id}`                   |  ✅   | ✅* | ❌  | ❌  | ❌  |
| `DELETE /tasks/{id}`                  |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /tasks/{id}/completions`        |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `GET  /task-completions` (gecmis)     |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /tasks/{id}/completions`        |  ✅   | ❌  | ✅  | ✅  | ❌  |
| `POST /uploads/presign`               |  ✅   | ✅† | ✅  | ✅  | ✅‡ |
| `POST /devices` (kendi cihazi)        |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `DELETE /devices/{fcm_token}`         |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `GET  /devices` (liste, debug)        |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /assets` (liste/detay)          |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /assets`                        |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PATCH /assets/{id}`                  |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `DELETE /assets/{id}`                 |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `POST /assets/{id}/checkout`          |  ✅   | ❌  | ✅  | ✅  | ❌  |
| `POST /assets/{id}/checkin` (sahiplik*)|  ✅   | ❌  | ✅* | ✅* | ❌  |
| `GET  /assets/{id}/history`           |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `GET  /yonetici-iletisim` (yonetici dizini)| ✅ | ✅ | ✅  | ✅  | ✅  |
| `GET  /tenant/settings` (site adi dahil)|  ✅  | ✅  | ✅  | ✅  | ✅  |
| `PATCH /tenant/settings` (admin: hepsi / yonetici: `ad` + `konum_ad/konum_lat/konum_lon`)| ✅ | ✅ | ❌ | ❌ | ❌ |
| `GET  /weather` (tenant konumu hava durumu)| ✅  | ✅  | ✅  | ✅  | ✅  |
| `POST /tenants` (admin tesis+yonetici)|  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /tenants` (admin tum tesisler)  |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `POST /tenant/setup` (ilk-giris adlandir — YALNIZ **BIRINCIL** yonetici)| ❌ | ✅ | ❌ | ❌ | ❌ |
| `GET  /tenants/{id}` (tesis detay)     |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PATCH /tenants/{id}` (tesis adi)      |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PATCH /tenants/{id}/yonetici`         |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `POST /tenants/{id}/yonetici/reset-credential`| ✅ | ❌ | ❌ | ❌ | ❌ |
| `DELETE /tenants/{id}` (tesisi sil)    |  ✅   | ❌  | ❌  | ❌  | ❌  |
| daire CRUD + yerlesim + TOPLU (`/units*`,layout,bulk)| ✅ | ✅ | ❌ | ❌ | ❌ |
| daire sakin atama (`/units/{id}/residents`)| ✅ | ❌  | ❌  | ❌  | ❌  |
| bina blok CRUD (`/blocks*`)           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET /units/{id}/dues`                |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /dues/assessments`              |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /dues/assessments`              |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /dues/payments`                 |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /dues/payments`                 |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET /me/dues`                        |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `*/budget/*` (kategori + defter)      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET /budget/summary` (agregat ozet)  |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `GET /reports/financial-summary`      |  ✅   | ✅  | ✅° | ✅° | ✅° |
| `GET /users` + `GET /users/{id}`      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /users` (admin: her rol; yon: saha)| ✅ | ✅* | ❌ | ❌  | ❌  |
| `PATCH /users/{id}` (admin: her; yon: saha)| ✅ | ✅* | ❌ | ❌ | ❌ |
| `POST /users/{id}/reset-password` (admin: her; yon: saha)| ✅ | ✅* | ❌ | ❌ | ❌ |
| `PATCH /users/{id}/contact`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET /call-target/{id}`               |  ❌   | ❌  | 📞  | ❌  | 📞  |
| `*/integrations*` (CRUD + tetik)      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /unit-complaints` (kendi bloğu) |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `GET /unit-complaints/mine` (kendi)   |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `GET /unit-complaints/building-map`   |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `GET /unit-complaints[/density]` (liste)|  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PATCH /unit-complaints/{id}` (kapat) |  ✅   | ✅  | ❌  | ❌  | ❌  |

> **Giris yollari:** `login`/`login-resident`/`set-password` PUBLIC
> endpoint'lerdir; matris "hangi rol bu yolu kullanir"i gosterir. Sakinin
> BEKLENEN yolu daire girisidir; ° email'i TANIMLI eski sakin hesaplari icin
> email girisi geriye-uyumluluk olarak calismaya devam eder (email'siz sakin
> zaten giremez). `POST /residents` yoneticinin sakin acma/gecici kod uretme
> ucudur (§1.2) — unit CRUD'un admin-only olmasindan ayridir; ayni `unit_no`
> varsa yeni daire acilmaz, mevcuda baglanir.
>
> **Tesis adi + kurulum:** `PATCH /tenant/settings` govdesinde **admin** TUM
> alanlari (`ad` + `timezone` + `yonetim_email` + `konum_ad`/`konum_lat`/
> `konum_lon`) gonderebilir; **yonetici** `ad` + konum alanlarini gonderebilir
> (hava durumu icin tesis konumunu belirler) — baska alan gonderirse **403**.
> `POST /tenant/setup`
> (ilk-giris adlandirma) YALNIZ **BIRINCIL** yoneticiye acilir; birincil olmayan
> yonetici **403**, zaten kurulmus tesis **409**. `slug` ve tenant `id` bu
> uclarin HICBIRINDE degismez.
>
> **`GET /yonetici-iletisim`:** rol kapisi YOKTUR — tenant'in HERHANGI bir
> kimlikli uyesi (bes rolun besi de) gorur; izolasyon RLS ile. Numara aciklamasi
> bilincli bir gizlilik istisnasidir — bkz. §C1a.

> **Gorev atama (yonetici ✅\*):** `yonetici` gorev olusturur/gunceller ama
> `atanan_user_id` YALNIZ `security` veya `tesis_gorevlisi` rolunde bir
> kullanici olabilir (aksi 422 `invalid_reference`). `admin` icin bu kisit yok.
> `yonetici`'nin kullanici secebilmesi icin `GET /users` okumasi acik;
> kullanici olusturma/guncelleme (CRUD) admin-only kalir.

> **Zimmet sahipligi (checkin\*):** rol yetkisi yetmez — acik zimmeti YALNIZ
> **sahibi** (`alan_user_id == token user`) veya **admin** (yonetim mudahalesi)
> kapatabilir; baska security/tesis_gorevlisi **403** `forbidden` ("Zimmet baskasinin
> uzerinde..."). Ayrica `GET /assets?checked_out_by=<uuid>` yalniz **admin**
> (herkes `checked_out_by=me` kullanabilir).
>
> **Aidat:** Unit/tahakkuk/odeme YAZMA yalniz **admin**. **yonetici** aidat
> raporlarini OKUR (`GET /dues/assessments`, `GET /dues/payments`,
> `GET /units/{id}/dues`) ama tahakkuk/odeme kaydedemez. **security/tesis_gorevlisi
> aidat GORMEZ** (403). **resident** yalniz `GET /me/dues` ile **kendi** dairelerinin
> borcunu gorur; tahakkuk/odeme yapamaz, baska daireyi goremez.
>
> **Butce (Wave 2A) + seffaflik (Wave 2B):** dinamik gelir/gider kategorileri
> + defter + kasa ozeti. YONETIM (`yonetici` + `admin`) tam yetkili: kategori
> CRUD, manuel kayit, defter satirlari. **Seffaflik:** `GET /budget/summary`
> AGREGAT oldugu icin TUM rollere aciktir (sakin sitenin toplam gelir/gider/
> kasasini ve kategori toplamlarini gorur); defter SATIRLARI, kategori
> yonetimi ve kisi/daire bazli veri sakin/saha icin 403 kalir. Sakin kendi
> aidat detayini yalniz `GET /me/dues`tan okur (`/units/{id}/dues` yonetim
> raporudur — sakin unit_id vererek ERISEMEZ). Basarili aidat odemesi
> OTOMATIK "Aidat" gelir kaydi uretir (kaynak=aidat_odeme, idempotent); bu
> kayitlar defterden elle duzenlenemez/silinemez. Para integer KURUS.
>
> **Finansal ozet raporu** (`GET /reports/financial-summary?donem=`): cepten
> hizli ozet — rol-duyarli TEK uc. Tum roller agregat kismi alir (gelir/
> gider/kasa + en yuksek gider kategorileri); ° `tahsilat` blogu (tahakkuk,
> tahsilat, oran, geciken daire sayisi) YALNIZ yonetimde dolar, sakin/saha
> icin `null` (daire/kisi duzeyi sizmaz). Salt okuma.
>
> **Daire sikayeti + bina semasi (D-viz Rev-1) — KADEMELI GORUNURLUK:**
> Sakin YONETIME degil, bir HEDEF DAIREYE anonim sikayet acar (kategori:
> `gurultu` / `kapi_onu_ayakkabi` / `zarar_verme` / `diger` + opsiyonel not).
> - **`GET /unit-complaints/building-map`** ROL-FARKINDADIR (`shows_density`
>   bayragi): **yonetici/admin** her daire icin ACIK sikayet **sayisi + renk**
>   (0-2 yeşil / 3-4 sarı / 5+ kırmızı) görür; **resident** YALNIZ **kendi
>   bloğunun** yapısını görür (genel sayı/renk `null` — hangi dairenin kaç
>   şikayeti olduğunu **bilemez**; haritayı yalnız şikayet edilecek daireyi
>   SEÇMEK için kullanır) + **KENDI sikayet ettigi daireler isaretli**
>   (`benim_sikayetim` + `benim_acik_sayisi`, yalnız kendi kayıtlarından;
>   Rev-1.1 — ayrı "Şikayetlerim" ekranı yerine harita üzerinde); **security/
>   tesis_gorevlisi** TÜM bina yapısını görür ama sayı/renk `null`.
> - **Own-block:** resident yalnız kendi bloğundaki daireyi şikayet edebilir
>   (`POST /unit-complaints` blok dışı hedef → **403**). Blok-suz sitede blok
>   `null`'dur (tek örtük blok). Aktif dairesi olmayan sakin hiçbir yere açamaz.
> - **complainant (şikayet eden) kimliği (Rev-2 — GİZLİ):** ARTIK **hiçbir**
>   role dönmez — **yönetim dahil**. `GET /unit-complaints` (+ kapatma) yalnız
>   yönetime açık (diğerleri 403) ve yönetim "şikayet edildiğini" + kategori +
>   not + durum + daire-başı **sayı/renk** görür, ancak **KİMİN** ettiğini
>   göremez (`complainant_user_id`/`complainant_ad` her zaman `null`; alanlar
>   geriye-uyum için şemada durur). `building-map` de hiçbir role complainant
>   döndürmez. Kimlik yalnız sunucuda spam-koruması için tutulur.
> - **Bina blok CRUD (`/blocks*`)** ve daire CRUD/yerleşim (`/units*`,
>   `/units/{id}/layout`, **`POST /units/bulk` toplu ekleme**) **YAZMA** admin
>   **+ yonetici**'dir (Rev-2 görsel editörü bu uçları kullanır; blok-suz +
>   blok-tabanlı siteler birlikte desteklenir). Toplu ekleme: blok + kat sayısı
>   + kat başına daire + başlangıç no → ardışık üretir; var olan no atlanır.
>   **OKUMA** (`GET /blocks`, `GET /units`) admin+yonetici **+
>   security/tesis_gorevlisi**: saha rolleri "Bina Düzenleme" ekranını
>   **SALT-OKUMA** görür (blok/kat/daire yapısını referans olarak; tüm düzenleme
>   eylemleri istemcide gizli, backend yazmayı yine 403'ler). `resident` erişmez.
>
> **Odeme webhook'u** (`POST /webhooks/payments/{provider}`): **PUBLIC** (JWT YOK) — saha
> disindan saglayici cagirir. Guvenlik **imza/hash** ile saglanir (provider secret; HMAC).
> Imza gecersizse **401** ve hicbir islem yapilmaz. Tenant, `provider_ref`'ten owner-sahipli
> `SECURITY DEFINER` `payment_tenant_by_ref` ile RLS-safe cozulur. Odeme durumu **yalnizca**
> webhook/saglayicidan degisir; istemci "odedim" diyemez. Webhook tutari (kurus) odeme ile
> karsilastirilir (manipulasyon engeli); olay (provider+event_id) bir kez islenir (idempotent).

Notlar:
- **admin**: PLATFORM admini (biz/gelistirici). Tum yonetim islemleri (CRUD) +
  **panel (admin-web)** — panel yalniz bu role aciktir. Tenant kapsami token'la
  belirlenir; operasyonel olarak tum tesislere hesap acilabilir.
- **yonetici**: SITE yoneticisi (musteri). MOBIL kullanicidir, panele girmez.
  Kendi tenant'inda: gorev olusturur/atar (yalniz security/tesis_gorevlisi'ne)
  ve takip eder; devriye/NFC takibini okur (patrol-windows, dashboard/live,
  checkpoints); aylik raporlari okur (task-completions, patrol-windows, aidat);
  demirbasi goruntuler; kullanici listesini okur.
  Yapilandirma (shift/checkpoint/patrol-plan/asset/unit/tenant/kullanici CRUD)
  ve aidat yazma **admin-only** kalir. Saha kaniti uretmez (`POST /scans`,
  completion, zimmet ❌). † `POST /uploads/presign`e yalniz duyuru gorseli
  yuklemek icin erisir (saha kanit akisi degil).
  - **BIRINCIL yonetici (`app_user.birincil`):** tenant olusturulurken girilen
    ILK yonetici birincildir (`uq_app_user_birincil` kismi unique index: tenant
    basina EN FAZLA bir). Tesisi ILK GIRISTE adlandirma kapisi (`POST
    /tenant/setup`) YALNIZ ona acilir (digeri 403); mobil kapi da yalniz ona
    gosterilir. Birincil olmayan yonetici, tesis adsizken ana ekrani gorur
    (engelleyici ekran YOK — bilincli).
  - **Tesis adini degistirme:** TUM yoneticiler `PATCH /tenant/settings {ad}`
    ile yeniden adlandirabilir (admin de). Yonetici ayrica `konum_ad`/
    `konum_lat`/`konum_lon` (hava durumu konumu) gonderebilir. `timezone`/
    `yonetim_email` admin'de kalir — yonetici gonderirse 403. **`slug` ve
    tenant `id` ASLA degismez.**
  - **Bireysel kullanici silme ucu YOKTUR** (yalniz `DELETE /tenants/{id}` tum
    tenant'i siler; kullanici pasiflestirilir). Bu yuzden "birincil silinince
    terfi" senaryosu olusmaz; pasiflestirme birincil bayragini DEGISTIRMEZ.
    (Pasif yonetici `GET /yonetici-iletisim` dizininde listelenmez.)
- **security / tesis_gorevlisi**: operasyonel saha rolleri (tesis_gorevlisi =
  temizlik + bahcivan + teknik, eski `cleaning`in devami — yetkileri birebir
  ayni). Tanimlari **okur**, tur kaniti (`POST /scans`) **gonderir**;
  **talep/ariza ACAR** (`POST /complaints`) ve ° yalniz kendi actiklarini
  izler; convert/resolve/decline ❌ (yonetim isi). Kendine atanan is emrini
  (`POST /tasks/{id}/completions`) tamamlayarak talebi dolayli olarak
  cozer (bkz. "Talep durum makinesi"). Yapilandirmayi (CRUD) degistiremez.
  `tesis_gorevlisi` panele/dashboard'a erisemez; saha odakli.
- **resident**: v0 kapsaminda operasyon endpoint'lerine erisimi yoktur.
  Login/refresh + `GET /me/dues` + cihaz kaydi + **duyuru okuma**
  (`GET /announcements`; duyuru OLUSTURAMAZ) + **talep/ariza**
  (`POST /complaints` acar, ° `GET /complaints*` YALNIZ kendi actiklarini
  gorur; convert/resolve/decline ❌) disinda her kaynak `403`.
  ‡ `POST /uploads/presign`e yalniz talep/ariza gorseli yuklemek icin erisir.
- **Gorev-YONETIMI vs "Gorevlerim" (kesin matris — A4 guncel):**
  Gorev-YONETIMI = gorev atama + olusturma/duzenleme ekrani — YALNIZ
  `yonetici` (+`admin`); saha rolleri (`security`/`tesis_gorevlisi`) ve
  `resident` gormez. Saha rolleri yalniz "Gorevlerim" ekranini kullanir.
  **KATI bireysel gorunurluk (F4, Rev-2):** saha rolu "Gorevlerim"de YALNIZ
  KENDINE atanan gorevleri OKUR. Havuz (atanmamis) ve grup (baska saha
  uyesine atanmis) gorevler saha'ya GORUNMEZ (404 ile varlik da sizdirilmaz);
  yalniz yonetim gorur ve atar. **Tamamlama bypass-proof:** saha rolu YALNIZ
  kendine atanan gorevi tamamlar; digerini goremedigi icin tamamlayamaz
  (`404`). Yonetim tum listeyi gorur (havuz dahil, atamak icin).
- **Gorev kategorisi (`/task-categories`, A6):** yonetici-tanimli,
  tenant'a ozel kategori seti. YAZMA (POST/DELETE) `admin` + `yonetici`;
  OKUMA gorev goren roller (`admin`/`yonetici`/`security`/
  `tesis_gorevlisi`); `resident` ❌. DELETE SOFT-DELETE'tir (aktif=false);
  pasif kategoriye yeni gorev yazilamaz (422). Gorev olustururken
  opsiyonel `kategori_id` ile secilir.
- **Duyuru:** OLUSTURMA `yonetici` (site yonetiminin agzi, mobil) +
  `admin` (platform tarafi, panel) — canli test kesin kurali. Saha rolleri
  ve `resident` olusturamaz. Duzenleme/silme `admin` + `yonetici`; OKUMA
  tum roller. Mobil UX: "yeni duyuru" butonu YALNIZ yonetici ekraninda
  (admin panelden yayinlar).
  Olusturmada tenant'in tum aktif cihazlarina push denenir (EK gonderim; push
  hatasi duyuru kaydini etkilemez). Duyuruya OPSIYONEL gorsel eklenebilir
  (`/uploads/presign` → PUT → `foto_key`); okumada `foto_url` (kisa omurlu
  presigned GET) tum okuyan rollere doner.
> **GIZLILIK (ziyaretci + kargo, kesin kural — KVKK):** ziyaretci ve kargo
> kayitlari **OZEL**dir — VARSAYILAN olarak yalniz (1) o kaydin **hedef/dairesi
> olan sakini** ve (2) **kaydeden guvenlik** (kapi ops, vardiya devri) gorebilir.
> **`yonetici` VE `admin` ikisi de VARSAYILAN KAPALI** (🔒): platform operatoru
> (`admin`) dahil hicbir yonetim rolu sakinin ozel ziyaretci/paket verisini
> varsayilan olarak goremez. Gormek icin `unit-access-request` ile **sakin
> onayli tek-seferlik izin** alinir (bir okumada tuketilir). Bu, gizliligi
> uniform kilar: yalniz guvenlik (ops) + hedef sakin varsayilan gorur.

- **Ziyaretci (`/visitors`):** kapi onay akisi — guvenlik kaydeder, **secilen
  TEK hedef sakin** onaylar/reddeder, sonuc guvenlige doner; tam gecmis tutulur.
  - **KAYIT (`POST`) YALNIZ `security`:** ziyaretci kapida karsilanir; kayit
    kapi operasyonudur. `yonetici`/`admin` kayit ACMAZ (403). Daire `unit_id`
    VEYA `unit_no` ile verilir (bulunamazsa 422). **TEK HEDEF MODELI:** guvenlik
    `target_resident_user_id` ile dairenin **AKTIF bir sakinini** secer (baska
    dairenin/rolun id'si 422). Guvenlik hedef listesini
    **`GET /units/by-no/{unit_no}/residents`** ile ceker (security+admin+yonetici
    okur; resident 403 — komsularini listeleyemez). Push YALNIZ **o hedef
    sakine** gider (esler dahil degil; kisi hedefli; EK gonderim — hatasi kaydi
    etkilemez; `data: tip=ziyaretci, visitor_id`).
  - **YANIT (`PATCH`, ✅🎯) YALNIZ HEDEF sakin:** rol yetmez — `target_resident
    _user_id == user` VE `unit_resident` (bitis IS NULL) sunucuda dogrulanir;
    hedef DISI (ayni dairedeki es dahil) veya baska daire **404** (varlik
    sizdirilmaz). Pasiflesen hedef de yanitlayamaz (404). **ILK yanit gecerli:**
    zaten yanitlanmis kayda ikinci yanit **409** (atomik `durum='bekliyor'`
    kosullu UPDATE). `yanitlayan_user_id` + `yanit_zamani` damgalanir; sonuc
    push'u YALNIZ kaydi acan guvenlige (`data: tip=ziyaretci_sonuc`).
  - **OKUMA:** YALNIZ `security` tenant'in TUM gecmisi (guvenlik canli sonuc +
    gecmis; durum/daire/tarih filtresi); 🎯 `resident` YALNIZ **kendine
    hedeflenen** kayitlari gorur (ayni dairedeki es'in kaydini GORMEZ); 🔒
    `yonetici` VE `admin` VARSAYILAN 403 — yalniz izinli daireyi `?unit_id=`
    ile bir kez gorur (izin tuketilir; KVKK — platform operatoru dahil).
    `tesis_gorevlisi` ERISMEZ (403).
  - **GSM'e hazir (ILERIDE, simdi yok):** yanit alanlari kanaldan
    bagimsizdir; sakin telefonu `app_user.telefon`'da. Gercek arama
    (Twilio/Netgsm) `visitor_durum`'a deger (orn. `araniyor`) + arama
    meta'si (ayri kolon/tablo; `uq_visitor_id_tenant` composite-FK hedefi
    hazir) eklenerek gelir — modelde yeniden tasarim gerekmez.
- **Kargo (`/kargo`):** paket takibi — guvenlik gelen paketi kaydeder
  (daire + firma + opsiyonel foto/not), dairenin sakini "teslim aldim"
  isaretler; tam gecmis tutulur. Ziyaretci modulunun RBAC/izolasyon
  deseninin AYNISI; akis onay/red degil TESLIM (bekliyor → teslim_alindi).
  - **KAYIT (`POST`) YALNIZ `security`** (kapi operasyonu; `yonetici`/`admin`
    403 — gecmisi GET ile okur). Daire `unit_id` VEYA `unit_no` (sunucuda
    cozulur; yoksa 422). **Foto MEVCUT presign akisiyla** (`/uploads/presign`
    → PUT → `foto_key`; gorev/talep/duyuru ile ayni desen, yeni upload yolu
    YOK); `foto_key` tenant-namespace dogrulanir (IDOR korumasi), okumada
    kisa omurlu `foto_url` doner. Kayitta dairenin **TUM aktif sakinlerine**
    push denenir ("Kargonuz geldi — <firma>"; EK gonderim — hatasi kaydi
    etkilemez; `data: tip=kargo, kargo_id`).
  - **TESLIM (`PATCH`, ✅\*) YALNIZ o dairenin AKTIF sakini:** rol yetmez —
    `unit_resident` (bitis IS NULL) sunucuda dogrulanir; BASKA dairenin
    sakini **404** (varlik sizdirilmaz). Atomik `durum='bekliyor'` kosullu
    UPDATE: zaten teslim alinmis kayda ikinci isaret **409** — kimin teslim
    aldigi DEGISMEZ (ayni dairede coklu sakin guvenli).
    `teslim_alan_user_id` + `teslim_zamani` otomatik damgalanir.
    **Teslimde geri-push YOK** (urun karari — kayit-push'u yeterli;
    guvenlik/yonetim guncel durumu listeden gorur). Kargo `TUM aktif
    sakinler` modelini korur (ziyaretci gibi tek-hedefe gecmedi — teslimi
    dairenin herhangi bir sakini alabilir; coklu sakin guvenli).
  - **OKUMA:** YALNIZ `security` tenant'in TUM gecmisi (durum/daire/tarih
    filtresi); 🔵 `resident` YALNIZ kendi **dairelerinin** paketleri (es de
    gorur — kargo unit-bazli); 🔒 `yonetici` VE `admin` VARSAYILAN 403 —
    yalniz izinli daireyi `?unit_id=` ile bir kez gorur (ziyaretci ile ayni
    izin mekanizmasi). `tesis_gorevlisi` ERISMEZ (403).
- **Tek-seferlik erisim izni (`/unit-access-request`):** ziyaretci/kargo hem
  yonetici'ye hem admin'e varsayilan kapali oldugundan, talep eden bir dairenin
  kayitlarini gormek icin izin TALEBI acar; dairenin sakini onaylar/reddeder.
  - **TALEP (`POST`) `admin` VEYA `yonetici`:** `unit_id`/`unit_no` (yoksa 422)
    -> `durum=bekliyor`. Dairenin **AKTIF sakinlerine** push (`data:
    tip=erisim_talebi, request_id`). Diger roller 403. (`granted_to_yonetici
    _user_id` kolonu talebi acan yonetici VEYA admin id'sini tutar.)
  - **KARAR (`PATCH`, ✅🏠) YALNIZ o dairenin AKTIF sakini:** baska daire
    **404**; ILK karar gecerli (ikinci **409**). `onaylandi` -> TEK-KULLANIMLIK
    izin (`used=false`). Sonuc push'u talebi acan yonetici'ye (`data:
    tip=erisim_sonuc`).
  - **TUKETIM (one-shot, SURESIZ):** onayli izin, talep eden (yonetici/admin)
    o dairenin ziyaretci/kargo kaydini **ILK okudugunda** tuketilir (`used=true`,
    atomik) — sonraki okuma **403**; tekrar gormek yeni talep ister. Tek izin
    hem ziyaretci hem kargo icin gecerlidir ve ilk okumada (hangisi olursa)
    tuketilir. Sureye bagli DEGIL (deterministik; TTL gelecekte eklenebilir).
  - **OKUMA (`GET`):** 👤 `yonetici` kendi talepleri; 🏠 `resident` kendi
    dairelerine gelen talepler; `admin` tenant tumu.

> Matris isaretleri: 🔒 varsayilan kapali (tek-seferlik izinle acilir) · 🎯
> yalniz hedef sakin · 🔵 kendi dairesi (es dahil) · 👤 kendi talepleri · 🏠
> kendi dairesine gelen talepler · 📞 yon+riza kapisiyla (bkz. rol-bazli arama).

- **Rol-bazli arama (`/call-target`, C1a — telefon numarasi GIZLILIGI):**
  sahadaki roller birbirine cihaz ceviricisiyle (tel:, ucretsiz — Twilio yok)
  ulasir. Numara **PII**dir; asagidaki UC kapi hepsi saglanmadan ASLA aciklanmaz:
  1. **YON (rol-bazli, tam dizin DEGIL):** `security` → `yonetici`/`resident`;
     `resident` → `security`. Diger arayan roller (admin/yonetici/tesis_gorevlisi)
     bu turda arama BASLATMAZ (403). Yon disi cift (orn. resident→resident) 403.
  2. **RIZA:** callee `aranabilir=true` olmali (yonetim girer). Riza yoksa 404 —
     numara donmez.
  3. **NUMARA VARLIGI:** callee `telefon` dolu olmali; yoksa 404.
  - **AMAÇ-SINIRLI + DATA-MINIMIZATION:** numara YALNIZ `GET /call-target/{id}`
    yanitinda (yalniz arama amaci), yalniz yetkili+rizali cift icin doner.
    **Listede (`GET /users`) numara YOK** (`UserListItem` telefon tasimaz);
    tek-kayit yonetim gorunumu (`GET /users/{id}`) yonetime numarayi gosterir.
  - **ILETISIM AYARI (`PATCH /users/{id}/contact`):** telefon + riza YALNIZ
    `admin`+`yonetici` tarafindan girilir — rol/parola/is_active gibi hassas
    alanlara DOKUNMADAN (tam PATCH `admin`-only kalir; yetki yukseltme yok).
  - **YONETICI ILETISIM KARTI (`GET /yonetici-iletisim`) — BILINCLI C1a
    ISTISNASI:** bu uc, yukaridaki UC KAPIYI (YON + RIZA + NUMARA VARLIGI) ve
    "listede numara YOK" kuralini YALNIZ yonetici kartlari icin deler: tenant'in
    HERHANGI bir kimlikli uyesi tum aktif yoneticilerin `ad_soyad` + `telefon`
    bilgisini ve tenant'in `yonetim_email`ini gorur.
    - **GEREKCE:** `yonetici` bir HIZMET rolüdür (kisisel iletisim degil);
      numarayi admin, tesis olusturulurken BILEREK girer; sahadaki personelin ve
      sakinin yonetime ulasabilmesi urun geregidir.
    - **KAPSAM (dar):** YALNIZ bu uc, YALNIZ `role='yonetici'` kullanicilar,
      YALNIZ `ad_soyad`+`telefon`. `aranabilir` rizasi bu ucta YOKSAYILIR —
      yonetici rizayi kaldirsa bile kartta listelenir. Pasif (`is_active=false`)
      yonetici listelenmez. Numara girilmemisse `telefon` null doner.
    - **DEGISMEYENLER:** C1a modeli baska HER SEY icin aynen gecerlidir —
      `/call-target` uc kapili kalir; `GET /users` numara tasimaz; `PATCH
      /me/contact` rizasi diger roller icin baglayicidir. Yoneticilere kayitta
      `aranabilir=true` verilir ki `/call-target` de tutarli calissin.
    - **UX:** mobil kartta numara METIN olarak gorunur ve `tel:` ile aranir
      (`CallButton` DEGIL — o numarayi kasten gizler; paylasilan parca
      `CallLauncher`dir).
- **Self-servis profil (`/me/profile`, `/me/password`, `/me/contact`) — TUM
  roller, YALNIZ kendi kaydi:** giris yapmis kullanici kendi profilini gorur ve
  gunceller (mobil sag-ust profil ikonu).
  - **`GET /me/profile`:** kimlik + iletisim alanlari (`ad`/`email`/`telefon`/
    `aranabilir`/`role`/`is_active`/`birincil`); `password_hash` ASLA donmez.
    (`birincil` = tenant'in birincil yoneticisi mi — mobil ilk-giris adlandirma
    kapisi yalniz buna acilir; yonetici disi rollerde daima `false`.)
  - **`PATCH /me/password`:** `current_password` + `new_password` (min 8).
    Mevcut parola dogrulanir; hatali → **400** `invalid_credentials` ("Mevcut
    parola hatali."). Basarida yeni bcrypt hash; **204**. Oturum (refresh)
    devam eder (token iptali yok). Parolasiz sakin (temp-kod bekleyen) zaten
    access token tasimaz → uc implicit kapali.
  - **`PATCH /me/contact`:** kullanici KENDI `telefon` + `aranabilir` rizasini
    yonetir (en az bir alan). Numara **OTP'siz dogrudan** kaydedilir (SMS
    altyapisi ileride). Yonetim ucu (`PATCH /users/{id}/contact`, baskasi icin)
    ayri kalir; bu onun kendi-kaydi karsiligidir.
  - **`PATCH /me/avatar` (profil fotografi, WP-D):** YALNIZ personel rolleri
    (admin/yonetici/security/tesis_gorevlisi); **resident 403** (sakinler
    personeli tanisin diye tek yonlu). `avatar_key` kendi tenant namespace'inde
    olmali (yabanci onek 422 — IDOR). `null` gonderimi fotografi kaldirir; eski
    obje MinIO'dan silinir. **Not:** ileride personel SILME ucu eklenirse
    kullanicinin `avatar_key` objesi de silinmelidir (su an personel silme ucu
    yok — yalniz create/update/reset).
  - **Kanal soyutlamasi (C1b'ye hazir):** yanit `channel` alani tasir; C1a yalniz
    `phone` (tel:). C1b (megafon/akilli-ev HTTP adaptorleri) yeni kanal + resolver
    ekler — sema/kapi yeniden yazilmaz. (Teknik data-minimization; hukuki tavsiye
    degil.)
- **Dis sistem entegrasyonlari (`/integrations`, C1b — SSRF-KORUMALI TETIK):**
  admin/yonetici bir dis ucu (megafon/akilli-ev/generic webhook) API detaylariyla
  tanimlar; tetiklenince sistem gercek HTTP istegi gonderir. C1a kanal
  soyutlamasini genisletir (`channel_type`: webhook/megaphone/smarthome — phone'un
  yaninda; kod yeniden yazilmaz).
  - **RBAC:** CRUD + tetik YALNIZ `admin`+`yonetici`; digerleri **403**.
  - **PRESET'ler (`GET /integrations/presets`):** generic webhook uzerinde makul
    varsayilanlar (marka-bagimsiz sablonlar — gercek cihaz surucusu DEGIL);
    form on-doldurur, kullanici duzenler.
  - **SIR (`auth_secret`) — WRITE-ONLY:** KEK ile AES-GCM sifreli saklanir
    (NTAG SDM deseni), GET'te **ASLA donmez** (`auth_secret_set` bool doner).
  - **⚠️ SSRF KAPISI (non-negotiable, `POST /integrations/{id}/trigger`):**
    numara/ic-hedef gizliligi degil, **ic ag erisimi** riski. Kapi: (1) yalniz
    `http(s)`; (2) host **DNS ile cozulur ve DONEN HER IP denetlenir** —
    hostname'e guvenilmez (DNS-rebinding: public gorunup private'a cozulen adres
    de reddedilir); (3) engellenenler: `127.0.0.0/8`, `10/8`, `172.16/12`,
    `192.168/16`, `169.254/16` (bulut metadata), `::1`, `fc00::/7`, `fe80::/10`,
    reserved/multicast/unspecified; (4) **redirect TAKIP EDILMEZ**; (5) timeout +
    yanit-boyutu siniri; (6) **IP-PIN (TOCTOU/rebind kapatma):** cozulen IP'ler
    baglantida sabitlenir — dogrula-sonra-baglan araligindaki DNS-rebinding
    (public dogrulanip private'a baglanma) engellenir; URL host degismez, TLS
    SNI/sertifika orijinal hostname'e gore dogrulanir. Engellenen tetik
    `{ok:false, error}` doner (istek ic aga CIKMAZ).
- **Daire sikayeti + bina semasi (`/unit-complaints` + `/building-map`, D1 →
  D-viz Rev-1 — KADEMELI GORUNURLUK, `/complaints`DEN AYRI):** sakin YONETIME
  degil, bir HEDEF DAIREYE sikayet acar (kategori: `gurultu` /
  `kapi_onu_ayakkabi` / `zarar_verme` / `diger` + opsiyonel not). Bu, var olan
  talep/ariza (`/complaints`) modulunden **BAGIMSIZ** bir tablodur —
  anonimlik YALNIZ bu modulde vardir; `/complaints` HER ZAMAN kimliklidir.
  - **KATEGORI GECISI (Rev-1):** `ayakkabi` → `kapi_onu_ayakkabi` (yeniden
    adlandirma); `gurultu`/`diger` aynen; **yeni** `zarar_verme`. (down -v ile
    taze DB uygulandigindan canli ALTER yoktur; eski `ayakkabi`/`goruntu` → 422.)
  - **ACMA (`POST`) YALNIZ `resident` + OWN-BLOCK:** `target_unit_id` tenant'ta
    olmali (aksi 422) VE sakinin KENDI blogunda olmali (blok disi → **403**).
    Blok-suz sitede blok `null` (tek ortuk blok). complainant token'dan alinir,
    resident'a echo EDILMEZ (kendi kaydinda da `null` gorur).
  - **KENDI SIKAYETLERIM (`GET /unit-complaints/mine`, YALNIZ `resident`):**
    sakin YALNIZ kendi actigi sikayetleri gorur (gitti mi geri bildirimi) —
    hedef `unit_no` + `kategori` + `tarih` + `durum` (+ kendi notu). Baska
    sakinlerin kayitlari, yogunluk/renk ve complainant (kendisi) YOKTUR.
    **Rev-1.1 fix — AYRI EKRAN YOK (mobil):** sakin kendi sikayetlerini artik
    **Şikayet Haritası uzerinde** gorur (kendi ilettigi daireler harita
    hucresinde isaretli; dokununca `/mine`'dan o daireye ait kendi kayitlari).
    Mobilde ayri "Şikayetlerim" menu girisi KALDIRILDI; `/mine` ucu (harita
    detayini besler) ve kural aynen gecerli.
  - **SPAM KORUMASI (Rev-1.1 — HAFTALIK + KATEGORI-BAZLI, YARISSIZ):** ayni sakin
    ayni hedef daireye **ayni KATEGORIDE 7 günde en fazla 1** sikayet acabilir
    (**farklı kategori serbest**; kural durumdan **bağımsız** — kapalı kayıt da
    sayılır) → tekrar **409** ("Bu daire için bu konuda haftada en fazla 1
    şikayet açabilirsiniz."). Sliding 7-gün penceresi, `(complainant,unit,
    kategori)` için `pg_advisory_xact_lock` + pencere sorgusuyla **race-safe**
    zorlanır (eski `WHERE durum='acik'` partial-unique kaldırıldı).
  - **HARITA (`GET /building-map`, TUM roller) — ROL-FARKINDA (`shows_density`):**
    **yonetici/admin** daire-basi ACIK sayi + renk (**0-2 yeşil / 3-4 sarı / 5+
    kırmızı**) gorur; **resident** YALNIZ **kendi bloğunun** yapisini gorur
    (genel sayi/renk `null` — hangi dairenin kaç şikayeti olduğunu **bilemez**;
    haritayı sikayet edilecek daireyi SEÇMEK için kullanır); **security/
    tesis_gorevlisi** TÜM yapıyı gorur ama sayi/renk `null`. Harita hiçbir role
    complainant döndürmez.
    **Rev-1.1 — resident KENDI sikayet isareti:** resident yanitinda her daire
    icin `benim_sikayetim` (bool) + `benim_acik_sayisi` (KENDI acik sikayet
    sayim) doner; **YALNIZ kendi kayitlarindan** (`complainant == kendisi`)
    turer. Boylece sakin haritada KENDI sikayet ettigi daireleri isaretli gorur
    ("iletildi"). Genel yogunluk, baskalarinin sayisi/kaydi/kimligi **ASLA**
    sizmaz; sikayet etmedigi daire `benim_sikayetim=false`. Yonetim yanitinda bu
    alanlar `false`/`null` (yonetim sayim/renk kullanir).
  - **DENETIM GORUNUMU (`GET /density` + liste `GET /unit-complaints`) — YALNIZ
    YONETIM:** sayilar + kategori + tarih + **not** + **complainant kimliği**
    (`complainant_user_id` + `complainant_ad`) admin/yonetici'ye doner (denetim/
    oversight). `security`/`tesis_gorevlisi`/`resident` bu liste/density'ye
    **erişemez (403)**; kimlik onlara **asla** sızmaz. `building-map` bu
    daraltmadan bağımsızdır (yapı herkese açık).
  - **KAPATMA (`PATCH`, admin+yonetici):** durumu degistirir (kapali); ACIK
    sayimi dusurur (renk feedback). Yanit complainant + not tasir (denetim).
  - **Bina blok CRUD (`/blocks*`) + daire CRUD/yerlesim (`/units*`, layout)
    admin + YONETICI** (Rev-2 gorsel editoru bu uclari kullanacak). Sakin atama
    (`/units/{id}/residents`) ve aidat admin-only kalir.
- **Ortak alan rezervasyonu (`/common-areas` + `/reservations`):** yonetici
  alan tanimlar (havuz/teras/toplanti odasi), sakin bos slotu ANINDA rezerve
  eder (**ONAY AKISI YOK**); tam gecmis tutulur. `durum` yalniz
  `onaylandi`|`iptal`.
  - **Alanlar:** OLUSTURMA/DUZENLEME `admin`+`yonetici`; OKUMA TUM roller
    (° yonetim disi roller YALNIZ aktif alanlari gorur — sakin neyin rezerve
    edilebilir oldugunu bilmeli). Silme YOK: kaldirma = `aktif=false`
    (soft-delete; rezervasyon gecmisi korunur, FK RESTRICT).
  - **MUSAITLIK (basit, gunler-arasi tekbicim):** alan `acilis`/`kapanis` +
    `slot_dakika` tasir; her gun `[acilis, kapanis)` araliginda `slot_dakika`
    uzunlugunda slotlarla rezerve edilebilir (saat girilmezse tum-gun
    varsayilan). Talep dogrulamasi araligin bu pencerede olmasini arar (slot
    izgara hizasi UX/istemci isi; cakismasizligi EXCLUDE saglar).
  - **ZAMANLAMA KURALLARI (backend zorlar; slot baslangicina gore, tenant tz
    `tenant.timezone` — varsayilan Europe/Istanbul; sunucu UTC "now"a cevirir):**
    - **24 SAAT PENCERESI:** slota **<24s kala** rezerve edilir; 24s'ten erken
      → **422** ("Rezervasyon en erken 24 saat kala yapilabilir."); baslangici
      gecmis slot → **422**.
    - **GUNDE BIR:** sakin, rezerve edilen slotun takvim gunune denk **en fazla
      1 aktif** (`onaylandi`) rezervasyon tutar; ikincisi → **409** ("Bu gun
      icin zaten bir rezervasyonunuz var.").
    - **SON DAKIKA ISTISNASI:** slota **<10 dk kala** BOS slot gunluk kotayi
      **baypas eder** (bos slot bosa gitmesin); yalniz gunluk kurali gecersiz
      kilar, 24s ust siniri zaten saglanmistir.
  - **SLOTLAR (`GET /common-areas/{id}/slots?date=`) TUM roller — ROL-FARKINDA:**
    o gunun TAM slot izgarasini + her slot icin `dolu` + `rezerve_edilebilir` +
    `sebep` (`dolu`|`gecti`|`cok_erken`|`gunluk`|null) doner. **dolu** = o slotla
    kesisen ONAYLI rezervasyon var; iptal DOLDURMAZ. **rezerve_edilebilir**
    yalniz SAKIN icin hesaplanir (24s + gunluk kota + son-dakika); yonetimde
    daima false. **GUNLUK KOTA SLOT-GUNUNE gore** olculur (`Rezervasyon.tarih ==
    goruntulenen/talep gunu`; rezervasyon/bugun gunu DEGIL) → farkli gun serbest.
    **GORUNURLUK KADEMESI:** 🔵 `resident` dolu slotta: KENDI rezervasyonu ise
    `benim=true` (istemci baslangic/bitis+simdi ile aktif=YESIL / gecmis=KIRMIZI
    secer); BASKASININ ise anonim "dolu" (`benim=false`, `unit_no`/`kisi_sayisi`
    = null — kimlik/kac kisi SIZMAZ). ✅ `admin`/`yonetici` dolu slotta rezerve
    eden **daire (`unit_no`) + `kisi_sayisi`** gorur (denetim; `benim` yok).
    Pasif alan sakine/sahaya **404**; yonetim pasif alan slotlarini gorur. Tum
    roller "alanlar-once" akisla: alani sec → gunun slot izgarasini gor.
  - **REZERVE ET (`POST /reservations`) YALNIZ `resident`:** alan + tarih +
    saat araligi (bitis > baslangic, ayni gun) + kisi_sayisi (>0). Daire
    sakinin AKTIF dairesinden turetilir (coklu dairede `unit_id` ile secim —
    kendi dairesi olmali, aksi 422). ONAY YOK: kayit dogrudan
    `durum='onaylandi'`. Yonetim rezerve ETMEZ (403).
  - **CAKISMA ENGELI (kesin mekanizma):** DB-duzeyi **partial EXCLUDE
    constraint** (`btree_gist`; `alan_id WITH =`, `tsrange(tarih+baslangic,
    tarih+bitis) WITH &&`, `WHERE durum='onaylandi'`). Kisit **INSERT aninda**
    devreye girer — es zamanli iki cakisan talepten YALNIZ BIRI basarir,
    digeri 23P01 → **409** (yaris durumu DB'de cozulur). Yari-acik aralik `[)`:
    bitisik slot (bitis == diger.baslangic) cakisma SAYILMAZ. Overlap tanimi:
    `baslangic < diger.bitis AND bitis > diger.baslangic`.
  - **IPTAL (`POST /reservations/{id}/cancel`) YALNIZ rezerve eden `resident`:**
    KENDI rezervasyonu (baskasininki 404). Yonetim iptal ETMEZ (403) — onay
    akisi yok, yalniz izler. **10 DK KURALI:** slot baslangicina <10 dk kala
    (veya baslamis) iptal EDILEMEZ → **422** ("Rezervasyon baslangicina 10
    dakikadan az kaldi, iptal edilemez."). `durum='iptal'` +
    `iptal_eden_user_id`/`iptal_zamani` damgalanir; slot bosalir. Zaten iptal
    → **409**. `security`/`tesis_gorevlisi` ERISMEZ (403).
  - **OKUMA:** yonetim tenant'in tumu (alan+tarih filtresi = gun gorunumu);
    🔵 `resident` YALNIZ kendi dairelerinin rezervasyonlari (daire bazli — es
    de gorur); `security`/`tesis_gorevlisi` ERISMEZ (403) — sakin↔yonetim akisi.
  - **Push:** rezerve sonrasi → rezerve eden sakinin cihazlari (`data:
    tip=rezervasyon`). EK gonderim — hatasi kaydi etkilemez.
- **Etkinlik + RSVP (`/events`):** yonetici etkinlik duyurur (cenaze, mac
  izleme vb.), sakinler katilim beyan eder; sayilar herkese seffaf.
  - **OLUSTUR/DUZENLE/SIL `admin`+`yonetici`** (duyuru deseni). Olusturmada
    **TUM SAKINLERIN** cihazlarina push denenir (hedef kitle sakinler —
    personel etkinligi OKUR ama push almaz; karar). `data: tip=etkinlik,
    etkinlik_id`. Silmede RSVP'ler CASCADE.
  - **OKUMA TUM roller** — liste/detay **SEFFAF SAYILARLA** doner:
    `katiliyorum_sayisi` + `katilmiyorum_sayisi` herkese acik.
    **Kim-katiliyor listesi URUN GEREGI YOK** — kimlik degil yalniz sayi
    paylasilir; `benim_durumum` yalniz istekteki kullanicinin KENDI beyani.
  - **RSVP (`PUT /events/{id}/rsvp`) YALNIZ `resident`:** etkinligin
    muhatabi site sakinleri — personel beyan vermez (karar). Kullanici
    basina **TEK kayit** (`UNIQUE (tenant_id, etkinlik_id, user_id)`) ve
    **KILITLI**: ilk beyandan sonra **DEGISTIRILEMEZ** (secim kesin —
    urun karari). Mevcut beyan varsa tekrar PUT **409 `already_answered`**
    doner; ilk beyanda ON CONFLICT DO NOTHING ile es zamanli iki PUT'ta da
    cift kayit imkansiz (ilki kazanir). Ilk beyanin yaniti guncel sayilarla
    etkinliktir. RSVP'de ek push YOK (urun karari).
- **Site kurallari (`/site-rules`):** blog-tarzi kural icerigi — yonetici
  liste tutar (ekle/duzenle/sil), TUM roller okur.
  - **CRUD `admin`+`yonetici`** (duyuru deseni); **OKUMA TUM roller** —
    liste `sira` ASC (esitlikte eski once) siralanir.
  - **ARAMA:** `?q=` basligi **SUNUCU tarafinda ILIKE** ile suzer (karar) —
    buyuk/kucuk harf duyarsiz; `%`/`_` joker karakterleri kacislanir (arama
    literal metin); RLS ile tenant-kapsamli — baska tenant'in kurali
    aramaya SIZMAZ.
  - **Silme HARD DELETE** (karar): salt icerik — operasyonel gecmis/FK
    tasimaz; soft-delete karmasasi gereksiz.
  - **Foto MEVCUT presign akisiyla** (`/uploads/presign` → PUT → `foto_key`;
    yeni upload yolu YOK); `foto_key` tenant-namespace dogrulanir (IDOR),
    okumada kisa omurlu `foto_url`. PATCH'te acik `foto_key=null` gorseli
    kaldirir. **Push YOK** — kurallar duyuru degil basvuru icerigi (karar).
- **Talep/Ariza → Is Emri (`/complaints`):** tesiste yasayan/calisandan
  yonetime uctan uca talep kanali (eski "sikayet/oneri" modulunun
  yeniden amaçlandırılmış hali — ayni path, yeni sema). ACMA `security` +
  `tesis_gorevlisi` + `resident` (acan token'dan, `durum=acik` baslar, ilk
  timeline satiri yazilir); `yonetici` ACAMAZ — kanalin CEVAPLAYAN
  tarafidir; `admin` de acmaz (platform operatoru, tesiste yasamaz/
  calismaz). OKUMA bes rol de erisir; acan roller (`security`/
  `tesis_gorevlisi`/`resident`, ° isareti) YALNIZ KENDI actiklarini gorur
  (baskasinin talebi 404 — varligi da sizdirilmaz); `admin`+`yonetici`
  tenant'taki tumunu gorur (yonetim gorunumu).
  - **ANONIMLIK YOK:** talepler HER ZAMAN kimlikli acilir (`acan_user_id`
    her yanitta doner); `/complaints` anonim DEGILDIR. Anonim/hedef-daire
    kanali AYRI bir modul olan `/unit-complaints`'tir (bkz. asagidaki
    "Daire sikayeti + bina semasi" bolumu) — ikisi karistirilmamalidir.
  - **Talep durum makinesi:** gecisler backend'de tek yerde
    (`ticketing.assert_transition`) zorlanir; gecersiz gecis **422**
    `invalid_transition` doner. `cozuldu` ve `reddedildi` TERMINALDIR (geri
    donus yok).
    ```
    acik ──convert──> is_emri ──(is emri tamamlanir | resolve)──> cozuldu
      │                                                              ▲
      ├──resolve────────────────────────────────────────────────────┘
      └──decline──> reddedildi
    ```
    - `acik` → `is_emri` (**`POST /complaints/{id}/convert`**, admin+yonetici):
      talebi bir is emrine (Task, `ticket_id`=talep) donusturur; atanan
      YALNIZ `security`/`tesis_gorevlisi` olabilir (aksi 422
      `invalid_assignee`).
    - `acik` → `cozuldu` (**`POST /complaints/{id}/resolve`**, admin+yonetici):
      is emri acmadan dogrudan kapatma (orn. telefonla cozuldu).
    - `acik` → `reddedildi` (**`POST /complaints/{id}/decline`**,
      admin+yonetici, `sebep` ZORUNLU).
    - `is_emri` → `cozuldu`: ILE IKI YOLDAN biri: (1) yine
      `POST /complaints/{id}/resolve` (manuel/erken kapanis) VEYA (2) bagli
      is emri (Task) saha personeli tarafindan
      `POST /tasks/{id}/completions` ile tamamlandiginda **OTOMATIK**
      (backend tetikler; ayri bir talep-kapatma cagrisi GEREKMEZ). `is_emri`
      durumundan `reddedildi`'ye gecis YOKTUR (donusturulmus is artik geri
      reddedilemez).
    - Her gecis `gecmis[]` (timeline) satirina yazilir: `durum` +
      `actor_role` (YALNIZ rol — `user_id` ASLA tutulmaz) + opsiyonel
      `sebep` (`convert.not` / `resolve.cozum_notu` / `decline.sebep`) +
      `created_at`.
  - **Talep fotografları:** acilista en fazla **3** gorsel eklenebilir
    (`foto_keys`, `ComplaintCreate`) — MEVCUT presign akisiyla
    (`/uploads/presign` → PUT → `foto_key`; duyuru/gorev/site-kurali ile
    ayni desen, yeni upload yolu YOK); `content_type` **YALNIZ gorsel**
    olmali (jpeg/png/webp/heic, aksi 422) ve imzali URL bu tipe baglanir.
    Her `foto_key` **tenant-namespace dogrulanir** (`<tenant_id>/...`
    onekiyle baslamali, aksi 422 `invalid_foto_key` — IDOR korumasi).
    Okumada `fotograflar[]` icinde her fotograf icin kisa omurlu
    `foto_url` (presigned GET) doner; depo yapilandirilmamissa `foto_url`
    sessizce `null` kalir (okuma kirilmaz).
  - **Push:** talep ACILDIGINDA `admin`+`yonetici` cihazlarina
    (`data: tip=talep`); `is_emri`'ye DONUSTURULDUGUNDE talebi acana
    (`tip=talep_is_emri`) VE atanan saha personeline
    (`tip=is_emri_atandi`) EK push denenir; `cozuldu`/`reddedildi`
    olduğunda YALNIZ talebi ACANIN cihazlarina (`tip=talep_cozuldu` /
    `talep_reddedildi`) push denenir. Tumu EK gonderim — push hatasi talep
    kaydini etkilemez.
  - **Kategori:** sabit `ComplaintKategori` enum'u KALDIRILDI; talep
    kategorisi artik dinamik `task_category`'e FK'lidir (`kategori_id`,
    opsiyonel; `kategori_ad` join ile doldurulur) — Gorev kategorisiyle
    (`/task-categories`) AYNI havuzu paylasir, boylece `convert` sirasinda
    kategori is emrine dogrudan tasınır.

## 5. Hata Davranisi

- Eksik/gecersiz/suresi dolmus access token → **401** + standart hata zarfi.
- Gecerli token ama rol yetersiz → **403**.
- Hata zarfi (tum API ile tutarli):
  ```json
  { "error": { "code": "forbidden", "message": "Bu islem icin yetkiniz yok" } }
  ```
- Onerilen kodlar: `unauthorized`, `forbidden`, `token_expired`,
  `invalid_token`, `invalid_credentials`.

## 6. Imzalama Anahtari (uygulama notu)

- v0: **HS256** + ortam degiskeninde tutulan gizli anahtar (`JWT_SECRET`) ile
  baslanabilir. Tek backend icin yeterli.
- Olcek/coklu servis durumunda **RS256**'ya gecis onerilir (public key ile
  dogrulama, private key sadece auth servisinde). Claim seti degismez.
- `is_active = false` kullanici: login reddedilir; mevcut access token suresi
  dolana dek gecerli kabul edilir (kisa omurlu oldugu icin kabul edilebilir
  risk). Aninda iptal gerekiyorsa access token icin de `jti` denylist eklenir.

---

## 7. KVKK — Denetim Kaydı, Saklama & İmha (WP1 + WP2)

Gerçek sakin verisi birikmeden önce KVKK duruşumuzun gerektirdiği iki paket:
değiştirilemez denetim izi + saklama/imha motoru.

### 7.1 Denetim kaydı (`audit_log`) — değiştirilemez (append-only)

Migration **0002** `audit_log` tablosunu ekler (`id, ts, tenant_id [nullable],
actor_user_id [FK'siz], actor_rol, action, resource_type, resource_id, meta jsonb`).

- **Append-only:** `app_rw` YALNIZ `INSERT + SELECT` alır; `UPDATE/DELETE`
  `setup_app_role.py`'de REVOKE edilir (blanket GRANT her migrate sonrası
  koştuğundan REVOKE orada). Ham `app_rw` bağlantısı UPDATE/DELETE denerse
  `permission denied` alır (test ile kanıtlı). 24 aylık purge YALNIZ owner ile.
- **`actor_user_id` FK'siz (bilinçli):** kullanıcı anonimleştirilse/silinse de iz kalır.
- **`meta` KVKK kuralı:** yalnız id'ler ve alan ADLARI; ASLA kişisel veri DEĞERİ
  (telefon/e-posta/ad/parola değerleri denetime GİRMEZ).
- **Yazım:** aynı-transaction ucuz INSERT (işlem COMMIT olursa yazılır; ROLLBACK
  olursa yazılmaz → yanıltıcı iz yok). Tenant bağlamı set olduğundan RLS `WITH
  CHECK` geçer. Sistem/tenant-siz olaylar (retention) owner ile yazılır.
- **Görüntüleme:** `GET /audit` — YALNIZ platform admini (yönetici DEĞİL). RLS
  FORCE olduğundan owner-sahipli `audit_log_list` SECURITY DEFINER fonksiyonu tüm
  tenant'ları (opsiyonel filtreyle) döner. Panel: `/audit` (salt-okuma).
- **Kapsam:** kimlik olayları (login ok/fail, parola set/değiştir); kişisel-veri
  kaynaklarındaki YAZMA (sakin/kullanıcı, ziyaretçi, kargo, erişim izni, talep/
  şikayet, aidat, blok/daire); **telefon ifşası (`phone_reveal`) + arama başlatma
  (`call_initiate`)** (C1a — en kritik iz); kargo fotoğrafı presign-GET
  (`kargo_photo_view`, yalnız tekil detay). Hassas-olmayan LİSTELEME loglanmaz.

### 7.2 Saklama süreleri (retention) — KVKK saklama sınırlama ilkesi (m.4/2-d)

Kişisel veri, işleme amacı geçtikten sonra tutulmaz. Varsayılanlar
`app/config.py`'de, **ENV ile daraltılabilir** (uzatılması önerilmez):

| Sınıf | Süre | İşlem | Gerekçe |
|---|---|---|---|
| Ziyaretçi (`visitor`) | 24 ay | SİL | Güvenlik log'u; amaç kısa vadeli kayıt/denetim |
| Kargo (`kargo`) + fotoğraf | 24 ay | SİL (+MinIO foto) | Teslimat kaydı; foto kişisel |
| Rezervasyon (geçmiş) | 24 ay | SİL | Tamamlanmış/iptal; operasyon amacı geçti |
| Talep/şikayet (çözülmüş/reddedilmiş) | 36 ay | ANONİMLEŞTİR | İş-emri/defter bütünlüğü için satır kalır; serbest metin arşivlenir |
| Denetim (`audit_log`) | 24 ay | PURGE (owner) | Hesap verebilirlik ↔ saklama dengesi |

Gecelik Celery beat: **04:00 Europe/Istanbul** (`crontab(hour=1)` UTC; TR yıl boyu
UTC+3). İdempotent, partili; sonuç `audit_log`'a `erasure_run` (yalnız sayılar)
olarak yazılır. Kargo fotoğrafı önce MinIO'dan silinir, sonra DB satırı (MinIO
erişilemezse o gece satır silinmez → foto asla DB'siz ortada kalmaz).

### 7.3 Sakin imha (KVKK silme hakkı) — `DELETE /residents/{id}`

Akıllı silme (yönetici/admin):
- **Geçmişsiz sakin** (yalnız CASCADE referans): TAMAMEN silinir → `deleted=true`
  (audit: `resident_delete`).
- **Geçmişli sakin** (FK RESTRICT: aidat/talep/rezervasyon vb.): silinemez →
  **ANONİMLEŞTİRİLİR** → `deleted=false` (audit: `resident_erasure`):
  `ad → 'Silinmiş Kullanıcı'`, `email/telefon → NULL`, parola/geçici-kod hash'leri
  temizlenir (kimlik doğrulama geçersizleşir), **FCM/cihaz token'ları silinir**,
  `aranabilir=false`, aktif daire bağlantıları kapatılır, `is_active=false`.
- **Korunan:** FİNANSAL (`dues_*`) ve talep/şikayet satırları defter bütünlüğü
  için KALIR — yazarları anonim kullanıcıya işaret eder. **Yüklenen şikayet
  fotoğrafları KALIR** (kişiyi değil, tesis sorununu belgeler — bilinçli karar).
