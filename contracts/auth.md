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

### 1.1 Login'de tenant nasil belirlenir (PERSONEL — email ile)

> **Iki ayri giris yolu vardir:** PERSONEL (admin/yonetici/security/
> tesis_gorevlisi) **email + parola** ile `POST /auth/login`'den girer (bu
> bolum); SAKIN (resident) **daire no + parola** ile
> `POST /auth/login-resident`'ten girer (§1.2). Personel akisi sakin
> modelinden ETKILENMEZ.

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

### 1.2 Sakin (resident) girisi — daire no + parola

Sakinler email ile DEGIL, **`tenant_slug + unit_no + password`** ile girer
(`POST /auth/login-resident`, bkz. `openapi.yaml`). Kimlik modeli:

- `app_user.email` sakinde **opsiyoneldir** (personelde zorunlu —
  `ck_app_user_staff_email`). Sakin hesabi daireye `unit_resident`
  (aktif = `bitis IS NULL`) ile baglidir.
- **Ayni dairede birden fazla sakin** olabilir (orn. esler): ayni `unit_no`,
  ayri hesaplar. Login'de hesap, girilen parolanin/kodun HANGI sakinin
  hash'iyle eslestigine gore cozulur; belirsizligi onlemek icin her sakinin
  KENDI parolasi + KENDI tek seferlik gecici kodu vardir.

**Ilk giris (gecici kod → zorunlu parola belirleme):**

1. Yonetici sakini `POST /residents` ile acar (daire yoksa ortulu olusur).
   Sunucu **tek seferlik gecici kod** uretir (orn. `K7MR-2QWX`); kod YALNIZ
   bu yanitta duz metin doner, yonetici sakine iletir. DB'de **bcrypt hash'i**
   saklanir (`app_user.temp_code_hash`); `password_set=false`,
   `password_hash=NULL`.
2. Sakin `login-resident`'a daire no + gecici kodla gelir. Kod dogruysa
   **oturum verilmez**; kisa omurlu (~10 dk, `type=pwd_setup`) `setup_token`
   doner (`password_setup_required=true`). Bu token API erisimi SAGLAMAZ;
   yalniz `POST /auth/set-password`'de gecer.
3. `POST /auth/set-password` (setup_token + yeni parola): parola bcrypt ile
   kaydedilir, `password_set=true`, `temp_code_hash=NULL` (**kod tek
   kullanimlik** — bir daha gecmez) ve tam `TokenPair` doner.
4. Sonraki girisler: daire no + sakinin KENDI parolasi → normal oturum.

Akis kurallari:

- Basarisiz her adim → **401** `invalid_credentials`; hangi adimin patladigi
  (daire var mi, kod mu parola mi yanlis) sizdirilmaz — personel akisiyla
  ayni ilke.
- Aktif olmayan (`is_active=false`) veya daireden cikarilmis
  (`unit_resident.bitis` dolu) sakin giremez.
- **Gecici kod omru:** kod, sakin kalici parolasini belirleyene kadar (veya
  yonetici yeni kod uretene kadar) gecerlidir; zaman asimi yoktur ama tek
  kullanimliktir ve `setup_token` ~10 dk ile sinirlidir. Kod ele gecerse
  yalniz o hesabin ILK girisini acar; parola belirlenmisse tamamen olur.
- Token'lar (access/refresh) ve `role=resident` claim'i personelle AYNIDIR
  (§2); refresh rotation aynen gecerlidir.

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
| `POST /auth/login` (personel, email)  |  ✅   | ✅  | ✅  | ✅  | ✅° |
| `POST /auth/login-resident` (daire no)|  ❌   | ❌  | ❌  | ❌  | ✅  |
| `POST /auth/set-password` (ilk giris) |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `POST /residents` (sakin ac + kod)    |  ✅   | ✅  | ❌  | ❌  | ❌  |
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
| `POST /announcements`                 |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PATCH /announcements/{id}`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `DELETE /announcements/{id}`          |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /complaints` (liste/detay)      |  ✅   | ✅  | ✅° | ✅° | ✅° |
| `POST /complaints`                    |  ❌   | ❌  | ✅  | ✅  | ✅  |
| `PATCH /complaints/{id}` (durum/yanit)|  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET /units/by-no/{no}/residents`     |  ✅   | ✅  | ✅  | ❌  | ❌  |
| `POST /visitors` (ziyaretci kaydi)    |  ❌   | ❌  | ✅  | ❌  | ❌  |
| `GET  /visitors` (liste/detay)        |  🔒   | 🔒  | ✅  | ❌  | 🎯  |
| `PATCH /visitors/{id}` (onay/red)     |  ❌   | ❌  | ❌  | ❌  | ✅🎯|
| `POST /kargo` (paket kaydi)           |  ❌   | ❌  | ✅  | ❌  | ❌  |
| `GET  /kargo` (liste/detay)           |  🔒   | 🔒  | ✅  | ❌  | 🔵  |
| `PATCH /kargo/{id}` (teslim aldim)    |  ❌   | ❌  | ❌  | ❌  | ✅* |
| `POST /unit-access-request`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /unit-access-request`           |  ✅   | 👤  | ❌  | ❌  | 🏠  |
| `PATCH /unit-access-request/{id}`     |  ❌   | ❌  | ❌  | ❌  | ✅🏠|
| `GET  /common-areas`                  |  ✅   | ✅  | ✅  | ✅  | ✅° |
| `POST/PATCH /common-areas*`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /reservations` (talep)          |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `GET  /reservations` (liste/detay)    |  ✅   | ✅  | ❌  | ❌  | 🔵  |
| `PATCH /reservations/{id}` (onay/red) |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /events` (liste/detay + sayilar)|  ✅   | ✅  | ✅  | ✅  | ✅  |
| `POST/PATCH/DELETE /events*`          |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `PUT  /events/{id}/rsvp`              |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `GET  /site-rules` (liste/detay + ?q=)|  ✅   | ✅  | ✅  | ✅  | ✅  |
| `POST/PATCH/DELETE /site-rules*`      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /tasks` (liste/detay)           |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `POST /tasks`                         |  ✅   | ✅* | ❌  | ❌  | ❌  |
| `PATCH /tasks/{id}`                   |  ✅   | ✅* | ❌  | ❌  | ❌  |
| `DELETE /tasks/{id}`                  |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET  /tasks/{id}/completions`        |  ✅   | ✅  | ✅  | ✅  | ❌  |
| `GET  /task-completions` (gecmis)     |  ✅   | ✅  | ✅  | ✅  | ❌  |
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
| `*/budget/*` (kategori + defter)      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET /budget/summary` (agregat ozet)  |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `GET /reports/financial-summary`      |  ✅   | ✅  | ✅° | ✅° | ✅° |
| `GET /users` + `GET /users/{id}`      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST/PATCH /users*` (tam)            |  ✅   | ❌  | ❌  | ❌  | ❌  |
| `PATCH /users/{id}/contact`           |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `GET /call-target/{id}`               |  ❌   | ❌  | 📞  | ❌  | 📞  |
| `*/integrations*` (CRUD + tetik)      |  ✅   | ✅  | ❌  | ❌  | ❌  |
| `POST /unit-complaints` (daire sik.)  |  ❌   | ❌  | ❌  | ❌  | ✅  |
| `GET /unit-complaints[/density]`      |  ✅   | ✅  | ✅  | ✅  | ✅  |
| `PATCH /unit-complaints/{id}` (kapat) |  ✅   | ✅  | ❌  | ❌  | ❌  |

> **Giris yollari:** `login`/`login-resident`/`set-password` PUBLIC
> endpoint'lerdir; matris "hangi rol bu yolu kullanir"i gosterir. Sakinin
> BEKLENEN yolu daire girisidir; ° email'i TANIMLI eski sakin hesaplari icin
> email girisi geriye-uyumluluk olarak calismaya devam eder (email'siz sakin
> zaten giremez). `POST /residents` yoneticinin sakin acma/gecici kod uretme
> ucudur (§1.2) — unit CRUD'un admin-only olmasindan ayridir; ayni `unit_no`
> varsa yeni daire acilmaz, mevcuda baglanir.
>
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
  ayni). Tanimlari **okur**, tur kaniti (`POST /scans`) **gonderir**;
  **sikayet/oneri ACAR** ve ° yalniz kendi actiklarini izler (PATCH ❌).
  Yapilandirmayi (CRUD) degistiremez. `tesis_gorevlisi` panele/dashboard'a
  erisemez; saha odakli.
- **resident**: v0 kapsaminda operasyon endpoint'lerine erisimi yoktur.
  Login/refresh + `GET /me/dues` + cihaz kaydi + **duyuru okuma**
  (`GET /announcements`; duyuru OLUSTURAMAZ) + **sikayet/oneri**
  (`POST /complaints` acar, ° `GET /complaints*` YALNIZ kendi actiklarini
  gorur; PATCH ❌) + **acil durum tetikleme** (`POST /emergency` — panik
  butonu sakinin de hakki; GET/PATCH ❌) disinda her kaynak `403`.
  ‡ `POST /uploads/presign`e yalniz sikayet/oneri gorseli yuklemek icin erisir.
- **Gorev-YONETIMI vs "Gorevlerim" (kesin matris — A4 guncel):**
  Gorev-YONETIMI = gorev atama + olusturma/duzenleme ekrani — YALNIZ
  `yonetici` (+`admin`); saha rolleri (`security`/`tesis_gorevlisi`) ve
  `resident` gormez. Saha rolleri yalniz "Gorevlerim" ekranini kullanir.
  **Grup gorunurlugu (A4):** saha rolu "Gorevlerim"de KENDI ROL GRUBUNA
  (`security` + `tesis_gorevlisi`) atanan TUM gorevleri + atanmamislari
  ("Herkes") OKUR; saha-disi kisiye atanmis gorev gorunmez (404 ile varlik
  da sizdirilmaz). **Tamamlama bypass-proof:** saha rolu YALNIZ kendine
  atanan veya atanmamis (havuz) gorevi tamamlar; grubun baska uyesine
  atanmis gorev okunur ama tamamlanamaz — `403 forbidden` (sunucu
  tarafinda zorlanir). Yonetim tum listeyi gorur.
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
- **Daire sikayeti (`/unit-complaints`, D1 — TAM ANONIM, `/complaints`DEN AYRI):**
  sakin YONETIME degil, bir HEDEF DAIREYE sikayet acar (gurultu/ayakkabi/diger);
  daire-basi ANONIM yogunluk + renk uretilir (ileride 2D bina haritasi). Bu,
  var olan yonetim-sikayeti (`/complaints`) modulunden **BAGIMSIZ** bir tablodur.
  - **⚠️ HARD ANONIMLIK KURALI:** `complainant_user_id` YALNIZ ic spam korumasi +
    RLS icin saklanir; **HICBIR uctan/serializer'dan DONMEZ** — `yonetici`/`admin`
    dahil kimse sikayet edeni goremez. `UnitComplaintOut` semasinda complainant
    ALANI YOKTUR (kasitli). Denetlenen tek serializer budur; olusturma/liste/
    detay/kapatma yanitlarinin HEPSI complainant tasimaz (explicit testlerle
    dogrulanir).
  - **ACMA (`POST`) YALNIZ `resident`:** `target_unit_id` (tenant'ta olmali, aksi
    422) + kategori + opsiyonel not. complainant token'dan alinir, echo EDILMEZ.
  - **SPAM KORUMASI (DB-zorlamali, yarissiz):** ayni sakin ayni hedef daireye
    AYNI ANDA yalniz **BIR ACIK** sikayet acabilir (partial-unique
    `WHERE durum='acik'`) -> tekrar **409**. Kapatilinca yeniden acilabilir
    (surekli engel degil; yonetim-kontrollu).
  - **YOGUNLUK/RENK (`GET /density`, tum roller):** her daire icin **ACIK**
    sikayet sayisi + renk — **0-2 yesil, 3-4 sari, 5+ kirmizi**. Kapatma ACIK
    sayimi dusurur (renk feedback). Sikayet eden verisi YOKTUR ("harita"
    tenant-ici herkese acik).
  - **NOT GIZLILIGI:** serbest metin `notlar` YALNIZ yonetim (admin+yonetici)
    yanitinda dolu; `security`/`tesis_gorevlisi`/`resident` icin **null** —
    deanonimlestirme / target-shaming riskini sinirlar. (Sayilar/kategori/tarih/
    renk tum rollere acik.)
  - **KAPATMA (`PATCH`, admin+yonetici):** yalniz durumu degistirir (kapali);
    sikayet edeni GORMEZ.
- **Ortak alan rezervasyonu (`/common-areas` + `/reservations`):** yonetici
  alan tanimlar (havuz/teras/toplanti odasi), sakin slot talep eder, yonetici
  onaylar/reddeder; tam gecmis tutulur.
  - **Alanlar:** OLUSTURMA/DUZENLEME `admin`+`yonetici`; OKUMA TUM roller
    (° yonetim disi roller YALNIZ aktif alanlari gorur — sakin neyin rezerve
    edilebilir oldugunu bilmeli). Silme YOK: kaldirma = `aktif=false`
    (soft-delete; rezervasyon gecmisi korunur, FK RESTRICT).
  - **TALEP (`POST /reservations`) YALNIZ `resident`:** alan + tarih + saat
    araligi (bitis > baslangic, ayni gun) + kisi_sayisi (>0). Daire sakinin
    AKTIF dairesinden turetilir (coklu dairede `unit_id` ile secim — kendi
    dairesi olmali, aksi 422). Yonetim talep ACMAZ (403) — karar veren taraf
    (complaints kanal ilkesi). Talep aninda ONAYLI bir rezervasyonla kesisen
    aralik **409** ile reddedilir (bosuna bekletilmez).
  - **CAKISMA ENGELI (kesin mekanizma):** DB-duzeyi **partial EXCLUDE
    constraint** (`btree_gist`; `alan_id WITH =`, `tsrange(tarih+baslangic,
    tarih+bitis) WITH &&`, `WHERE durum='onaylandi'`). BEKLEYEN talepler ust
    uste binebilir (karar yonetimde); onaya kaldirma **UPDATE'inde** kisit
    devreye girer — es zamanli iki cakisan onaydan YALNIZ BIRI basarir,
    digeri 23P01 → **409** (yaris durumu DB'de cozulur, uygulama kontrolune
    guvenilmez). Yari-acik aralik `[)`: bitisik slot (bitis ==
    diger.baslangic) cakisma SAYILMAZ. Overlap tanimi:
    `baslangic < diger.bitis AND bitis > diger.baslangic`.
  - **KARAR (`PATCH`) yalniz `admin`+`yonetici`:** `onaylayan_user_id` +
    `karar_zamani` otomatik damgalanir; zaten karara baglanmis kayda ikinci
    karar **409** (atomik `durum='bekliyor'` kosullu UPDATE).
  - **OKUMA:** yonetim tenant'in tumu (bekleyenler karar kuyrugu; alan+tarih
    filtresi = gun gorunumu); 🔵 `resident` YALNIZ kendi dairelerinin
    rezervasyonlari (daire bazli — es de gorur); `security`/`tesis_gorevlisi`
    ERISMEZ (403) — sakin↔yonetim akisi.
  - **Push:** talep → yonetim cihazlari (`data: tip=rezervasyon`); karar →
    YALNIZ talebi acan sakin (`tip=rezervasyon_karar`). EK gonderim — hatasi
    kaydi etkilemez.
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
    basina **TEK kayit** (`UNIQUE (tenant_id, etkinlik_id, user_id)`);
    tekrar PUT beyani **DEGISTIRIR** (ON CONFLICT upsert — cift kayit
    imkansiz, es zamanli PUT guvenli). Yanit guncel sayilarla etkinliktir.
    RSVP'de ek push YOK (urun karari).
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
- **Sikayet/Oneri (`/complaints`):** tesiste yasayan/calisandan yonetime
  talep kanali (canli test kesin kurali). ACMA `security` +
  `tesis_gorevlisi` + `resident` (acan token'dan, `durum=acik`, opsiyonel
  `foto_key`); `yonetici` ACAMAZ — kanalin CEVAPLAYAN tarafidir; `admin` de
  acmaz (platform operatoru, tesiste yasamaz/calismaz). OKUMA acan roller
  yalniz KENDI actiklarini (° isareti), `admin`+`yonetici` tenant'taki
  tumunu (yonetim gorunumu); DURUM/YANIT (PATCH) yalniz `admin`+`yonetici`
  (`yanitlayan_user_id` + `yanit_zamani` otomatik) — acan roller
  cevaplayamaz. Talep ACILDIGINDA `admin`+`yonetici` cihazlarina,
  YANITLANDIGINDA yalniz talebi ACANIN cihazlarina push denenir
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
