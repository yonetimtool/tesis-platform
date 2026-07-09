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
| `POST /auth/login`                    |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `POST /auth/refresh`                  |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `GET  /shifts` (liste/detay)          |  ✅   | ❌  | ✅  | ✅  | ❌  |
| `POST /shifts`                        |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PATCH /shifts/{id}`                  |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `DELETE /shifts/{id}`                 |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /checkpoints` (liste/detay)     |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /checkpoints`                   |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PATCH /checkpoints/{id}`             |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `DELETE /checkpoints/{id}`            |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PUT  /checkpoints/{id}/sdm-key`      |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /patrol-plans` (liste/detay)    |  ✅   | ❌  | ✅  | ✅  | ❌  |
| `POST /patrol-plans`                  |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PATCH /patrol-plans/{id}`            |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `DELETE /patrol-plans/{id}`           |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /patrol-plans/{id}/checkpoints` |  ✅   | ❌  | ✅  | ✅  | ❌  |
| `PUT  /patrol-plans/{id}/checkpoints` |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `POST /scans`                         |  ✅   | ❌  | ✅  | ✅  | ❌  |
| `GET  /dashboard/live`                |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `GET  /patrol-windows`                |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `GET  /me/patrol-window`              |  ✅   | ❌  | ✅  | ❌  | ❌  |
| `GET  /notifications`                 |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `PATCH /notifications/{id}`           |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `GET  /announcements` (liste/detay)   |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `POST /announcements`                 |  ❌   | ✅  | ❌  | ❌  | ❌  |
| `PATCH /announcements/{id}`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `DELETE /announcements/{id}`          |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /complaints` (liste/detay)      |  ✅   | ✅  | ❌  | ❌  | ✅° |
| `POST /complaints`                    |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `PATCH /complaints/{id}` (durum/yanit)|  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /tasks` (liste/detay)           |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /tasks`                         |  ✅   | ✅* | ❌  | ❌  | ❌  |
| `PATCH /tasks/{id}`                   |  ✅   | ✅* | ❌  | ❌  | ❌  |
| `DELETE /tasks/{id}`                  |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /tasks/{id}/completions`        |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `GET  /task-completions` (gecmis)     |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `POST /tasks/{id}/completions`        |  ✅   | ❌  | ✅  | ✅  | ❌  |
| `GET  /landscape/schedule`            |  ✅   | ✅  | ✅  | ✅  | ❌  |
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
| `POST /emergency`                     |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `GET  /emergency`                     |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PATCH /emergency/{id}`               |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /tenant/settings`               |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `PATCH /tenant/settings`              |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `*/units*` (CRUD + sakin)             |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET /units/{id}/dues`                |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /dues/assessments`              |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /dues/assessments`              |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /dues/payments`                 |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `GET  /dues/payments`                 |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET /me/dues`                        |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `GET /users` + `GET /users/{id}`      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST/PATCH /users*`                  |  ✅   | ❌  | ❌  | ❌  | ❌  |

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
  acil durumu tetikler/yonetir; demirbasi goruntuler; kullanici listesini okur.
  Yapilandirma (shift/checkpoint/patrol-plan/asset/unit/tenant/kullanici CRUD)
  ve aidat yazma **admin-only** kalir. Saha kaniti uretmez (`POST /scans`,
  completion, zimmet ❌). † `POST /uploads/presign`e yalniz duyuru gorseli
  yuklemek icin erisir (saha kanit akisi degil).
- **security / tesis_gorevlisi**: operasyonel saha rolleri (tesis_gorevlisi =
  temizlik + bahcivan + teknik, eski `cleaning`in devami — yetkileri birebir
  ayni). Tanimlari **okur**, tur kaniti (`POST /scans`) **gonderir**.
  Yapilandirmayi (CRUD) degistiremez. `tesis_gorevlisi` panele/dashboard'a
  erisemez; saha odakli.
- **resident**: v0 kapsaminda operasyon endpoint'lerine erisimi yoktur.
  Login/refresh + `GET /me/dues` + cihaz kaydi + **duyuru okuma**
  (`GET /announcements`; duyuru OLUSTURAMAZ) + **sikayet/oneri**
  (`POST /complaints` acar, ° `GET /complaints*` YALNIZ kendi actiklarini
  gorur; PATCH ❌) + **acil durum tetikleme** (`POST /emergency` — panik
  butonu sakinin de hakki; GET/PATCH ❌) disinda her kaynak `403`.
  ‡ `POST /uploads/presign`e yalniz sikayet/oneri gorseli yuklemek icin erisir.
- **Duyuru:** OLUSTURMA **yalniz `yonetici`** — duyuru site yonetiminin
  agzidir; `admin` platform operatorudur, tesise duyuru YAYINLAMAZ (canli
  test karari). Duzenleme/silme `admin` + `yonetici` (moderasyon); OKUMA tum
  roller.
  Olusturmada tenant'in tum aktif cihazlarina push denenir (EK gonderim; push
  hatasi duyuru kaydini etkilemez). Duyuruya OPSIYONEL gorsel eklenebilir
  (`/uploads/presign` → PUT → `foto_key`); okumada `foto_url` (kisa omurlu
  presigned GET) tum okuyan rollere doner.
- **Sikayet/Oneri (`/complaints`):** sakin↔yonetim kanali. ACMA yalniz
  `resident` (acan token'dan, `durum=acik`, opsiyonel `foto_key`); OKUMA
  `resident` yalniz KENDI actiklarini (° isareti), `admin`+`yonetici` tenant'taki
  tumunu; DURUM/YANIT (PATCH) yalniz `admin`+`yonetici` (`yanitlayan_user_id`
  + `yanit_zamani` otomatik). `security`/`tesis_gorevlisi` ERISMEZ — kanal
  onlara kapali. Talep ACILDIGINDA `admin`+`yonetici` cihazlarina,
  YANITLANDIGINDA yalniz talebi ACAN sakinin cihazlarina push denenir
  (kisi hedefli; EK gonderim — hatasi talep kaydini etkilemez).

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
