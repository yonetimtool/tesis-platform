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

### 1.1 Login'de tenant nasil belirlenir

`app_user.email` **tenant-ici** benzersizdir (`UNIQUE (tenant_id, email)`), yani
ayni email birden cok tenant'ta bulunabilir. Bu yuzden `POST /auth/login`
istegi `tenant_slug` + `email` + `password` alir (bkz. `openapi.yaml`
`LoginRequest`).

Akis:
1. `tenant_slug` → `tenant_id` cozumu: `tenant` tablosunda **RLS** etkin oldugu
   ve henuz tenant baglami olmadigi icin, uygulama rolu (`app_rw`) tabloyu
   dogrudan okuyamaz. Cozum, owner-sahipli **`SECURITY DEFINER`** fonksiyon
   `public.tenant_id_by_slug(slug)`'tur; yalnizca slug → id eslemesini doner
   (baska tenant verisi sizmaz), `app_rw`'ye `EXECUTE` verilir.
2. `tenant_id` bulununca `set_config('app.current_tenant_id', <id>, true)` ile
   baglam kurulur; kullanici **RLS altinda** `email` ile yuklenir.
3. Parola ve `is_active` dogrulanir. Basarisiz herhangi bir adim → **401**
   `invalid_credentials` (hangi adimin patladigi sizdirilmaz).

> `tenant.slug`: kucuk harf/rakam/tire, tenant genelinde benzersiz.

## 2. Token Yapisi

### Access token claim'leri

| Claim   | Tip     | Aciklama                                            |
|---------|---------|-----------------------------------------------------|
| `sub`   | string  | user_id (app_user.id, UUID)                         |
| `tenant_id` | string | Kullanicinin tenant'i (UUID)                    |
| `role`  | string  | `admin` \| `security` \| `cleaning` \| `resident`   |
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

Roller: **admin**, **security** (guvenlik gorevlisi), **cleaning** (temizlik
gorevlisi), **resident** (sakin).

Lejant: ✅ izinli · ❌ yasak · 🔵 sadece kendi kayitlari/okuma

| Endpoint                              | admin | security | cleaning | resident |
|---------------------------------------|:-----:|:--------:|:--------:|:--------:|
| `POST /auth/login`                    |  ✅   |    ✅    |    ✅    |    ✅    |
| `POST /auth/refresh`                  |  ✅   |    ✅    |    ✅    |    ✅    |
| `GET  /shifts` (liste/detay)          |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /shifts`                        |  ✅   |    ❌    |    ❌    |    ❌    |
| `PATCH /shifts/{id}`                  |  ✅   |    ❌    |    ❌    |    ❌    |
| `DELETE /shifts/{id}`                 |  ✅   |    ❌    |    ❌    |    ❌    |
| `GET  /checkpoints` (liste/detay)     |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /checkpoints`                   |  ✅   |    ❌    |    ❌    |    ❌    |
| `PATCH /checkpoints/{id}`             |  ✅   |    ❌    |    ❌    |    ❌    |
| `DELETE /checkpoints/{id}`            |  ✅   |    ❌    |    ❌    |    ❌    |
| `GET  /patrol-plans` (liste/detay)    |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /patrol-plans`                  |  ✅   |    ❌    |    ❌    |    ❌    |
| `PATCH /patrol-plans/{id}`            |  ✅   |    ❌    |    ❌    |    ❌    |
| `DELETE /patrol-plans/{id}`           |  ✅   |    ❌    |    ❌    |    ❌    |
| `GET  /patrol-plans/{id}/checkpoints` |  ✅   |    ✅    |    ✅    |    ❌    |
| `PUT  /patrol-plans/{id}/checkpoints` |  ✅   |    ❌    |    ❌    |    ❌    |
| `POST /scans`                         |  ✅   |    ✅    |    ✅    |    ❌    |
| `GET  /dashboard/live`                |  ✅   |    ✅    |    ❌    |    ❌    |
| `GET  /notifications`                 |  ✅   |    ✅    |    ❌    |    ❌    |
| `PATCH /notifications/{id}`           |  ✅   |    ✅    |    ❌    |    ❌    |
| `GET  /tasks` (liste/detay)           |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /tasks`                         |  ✅   |    ❌    |    ❌    |    ❌    |
| `PATCH /tasks/{id}`                   |  ✅   |    ❌    |    ❌    |    ❌    |
| `DELETE /tasks/{id}`                  |  ✅   |    ❌    |    ❌    |    ❌    |
| `GET  /tasks/{id}/completions`        |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /tasks/{id}/completions`        |  ✅   |    ✅    |    ✅    |    ❌    |
| `GET  /landscape/schedule`            |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /uploads/presign`               |  ✅   |    ✅    |    ✅    |    ❌    |
| `GET  /assets` (liste/detay)          |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /assets`                        |  ✅   |    ❌    |    ❌    |    ❌    |
| `PATCH /assets/{id}`                  |  ✅   |    ❌    |    ❌    |    ❌    |
| `DELETE /assets/{id}`                 |  ✅   |    ❌    |    ❌    |    ❌    |
| `POST /assets/{id}/checkout`          |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /assets/{id}/checkin`           |  ✅   |    ✅    |    ✅    |    ❌    |
| `GET  /assets/{id}/history`           |  ✅   |    ✅    |    ✅    |    ❌    |
| `POST /emergency`                     |  ✅   |    ✅    |    ✅    |    ❌    |
| `GET  /emergency`                     |  ✅   |    ❌    |    ❌    |    ❌    |
| `PATCH /emergency/{id}`               |  ✅   |    ❌    |    ❌    |    ❌    |
| `GET  /tenant/settings`               |  ✅   |    ✅    |    ✅    |    ❌    |
| `PATCH /tenant/settings`              |  ✅   |    ❌    |    ❌    |    ❌    |

Notlar:
- **admin**: tenant icindeki tum yonetim islemleri (CRUD) + panel.
- **security / cleaning**: operasyonel saha rolleri. Tanimlari **okur**, tur
  kaniti (`POST /scans`) **gonderir**. Yapilandirmayi (CRUD) degistiremez.
  `cleaning` panele (dashboard/live) erisemez; saha odakli.
- **resident**: v0 kapsaminda operasyon endpoint'lerine erisimi yoktur. Sakin
  ozellikleri (bildirim, talep vb.) sonraki surumde tanimlanacak. Login/refresh
  yapabilir ama yetkili oldugu kaynak yoktur (her kaynak `403`).

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
