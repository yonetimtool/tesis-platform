# /contracts — Tek Dogruluk Kaynagi

Multi-tenant tesis guvenlik & operasyon SaaS. Bu klasor, **backend (FastAPI)**,
**mobil (Flutter)** ve **panel (Next.js)** gelistiricilerinin paralel
calismasinin dayanagidir. Kod degil, **sozlesme** burada yasar. Bir davranis
degisecekse once burasi degisir, sonra kod.

## Icindekiler

| Dosya | Ne |
|-------|----|
| [`db/`](./db) | Alembic migration — PostgreSQL semasi + Row-Level Security (RLS) |
| [`openapi.yaml`](./openapi.yaml) | REST API sozlesmesi (OpenAPI 3.0.3) |
| [`auth.md`](./auth.md) | JWT + RBAC modeli, token sureleri, refresh akisi |
| `README.md` | Bu dosya — kararlar ve konvansiyonlar |

## Konvansiyonlar (tum stack icin baglayici)

### Zaman
- **Tum zaman damgalari ISO8601 UTC** (`2026-06-27T03:00:00Z`). DB'de `timestamptz`.
- Yorumlama **tenant.timezone** ile yapilir (orn. `Europe/Istanbul`).
- **Gece 00:00 mantigi kritik:** Vardiya/plan saatleri gun-ici **lokal saat**
  olarak (`time`) tutulur. Scheduler, plani tenant timezone'una gore somut UTC
  pencerelerine (`patrol_window.pencere_baslangic/bitis`) cevirir. Ornek: gece
  `00:00–06:00`, `periyot_dakika=60` → o gece icin 6 adet saatlik pencere, hepsi
  UTC olarak saklanir (DST gecisleri timezone kutuphanesi ile cozumlenir).
- `baslangic_saat > bitis_saat` ise vardiya/pencere **ertesi gune sarkar**.

### Tenant izolasyonu
- **Her sorgu tenant_id ile izole.** Bu, uygulama kodu unutsa bile **DB
  seviyesinde RLS** ile zorlanir.
- Backend her istekte: token'dan `tenant_id` → `SET app.current_tenant_id = '<uuid>'`.
- Istemci **hicbir zaman** `tenant_id` gondermez; her zaman token'dan turetilir.
- Cross-tenant FK referanslari composite FK `(id, tenant_id)` ile DB'de imkansiz.
- **Composite FK + `ON DELETE SET NULL` kurali:** Paylasilan `NOT NULL tenant_id`
  iceren composite FK'lerde duz `ON DELETE SET NULL` *tum* referans kolonlarini
  (tenant_id dahil) NULL'lamaya calisir ve `NOT NULL` ihlali verir. Bu durumda
  **kolon-ozel** sozdizimi kullanilir: `ON DELETE SET NULL (<fk_kolonu>)` (PG15+),
  boylece yalnizca ilgili kolon NULL'lanir, `tenant_id` korunur. (Orn.
  `fk_patrol_plan_shift` → `(shift_id)`, `fk_scan_window` → `(patrol_window_id)`.)

### Hata formati (tutarli zarf)
```json
{ "error": { "code": "validation_error", "message": "Aciklama" } }
```
- `code`: makine-okunabilir; `message`: insan-okunabilir. Alan hatalari icin
  opsiyonel `error.details[] = { field, message }`.
- HTTP durum kodlari: `400` (kotu istek), `401` (kimlik), `403` (yetki),
  `404` (bulunamadi), `409` (cakisma), `422` (dogrulama), `429` (limit).

### Sayfalama
- Liste endpoint'leri: `limit` (varsayilan **50**, max **200**) + `offset`.
- Yanit `meta: { limit, offset, total }` icerir.

### Idempotency (offline guvenlik)
- `POST /scans` icin **`Idempotency-Key` header'i zorunlu** (istemci uretir,
  UUID onerilir). Offline kuyruktan cift gonderim engellenir.
- Ayni key + ayni govde → `200` ve ilk kayit (yeni kayit yok).
- Ayni key + farkli govde → `409`.
- DB'de `scan_event UNIQUE (tenant_id, idempotency_key)` ile garanti.

### Auth
- JWT `access` (15 dk) + `refresh` (30 gun), refresh rotation. Detay: `auth.md`.
- Access claim'leri: `sub` (user_id), `tenant_id`, `role`, `exp` (+ `iat`, `jti`, `type`).
- **Login tenant'i `tenant_slug` ile belirler** (email tenant-ici benzersiz).
  `tenant.slug` benzersiz; slug→id cozumu RLS bootstrap'i icin owner-sahipli
  `SECURITY DEFINER` fonksiyon `tenant_id_by_slug` ile yapilir. Detay: `auth.md` §1.1.

## Veri modeli — ozet kararlar

- **Birincil anahtarlar UUID** (`gen_random_uuid()`), coklu-tenant ve dagitik
  uretim icin guvenli.
- **Enum'lar** native PostgreSQL tipi: `user_role`, `gun_tipi`, `patrol_window_durum`.
- `app_user.email` tenant icinde benzersiz (case-insensitive).
- `notification`: kacirilan tur vb. kalici bildirim. Idempotent dogal anahtar
  `UNIQUE (tenant_id, tip, patrol_window_id)` (ayni kacirilan pencere icin tek kayit).
  FK'ler composite + kolon-ozel `ON DELETE SET NULL`. Erisim: admin + security
  (`GET /notifications`, `PATCH /notifications/{id}` okundu). Gercek push/SMS ayri is.
- `task` / `task_completion`: esnek gorev sistemi (tip: temizlik/kontrol/ilaclama/
  bakim/diger). Task CRUD admin; tamamlama (`POST /tasks/{id}/completions`) cleaning+
  security+admin. Completion `UNIQUE (tenant_id, idempotency_key)` (offline cift
  gonderim korumasi, scan deseni). Foto kanit: **MinIO** (S3-uyumlu); `POST /uploads/presign`
  presigned PUT URL + `foto_key` doner, istemci dogrudan MinIO'ya yukler, sonra
  `foto_key` completion'da saklanir. FK'ler composite + kolon-ozel `ON DELETE SET NULL`.
  ('not' SQL anahtar kelimesi oldugu icin DB kolonu `notlar').
- **Peyzaj**: ayri tablo YOK — `task.tip='peyzaj'` + takvim alani `task.sonraki_planlanan`
  (UTC) + tekrar araligi olarak mevcut `periyot_dakika`. Tamamlanma (`task_completion`)
  periyodik peyzaji bir periyot ilerletir. Takvim: `GET /landscape/schedule` (sonraki_planlanan
  artan). Hatirlatma: `notification_tip` 'peyzaj_yaklasan' (planlanan yaklasinca) /
  'peyzaj_kacirilan' (planlanan gecmis + tamamlanmamis); idempotency `notification.dedup_key`
  (`UNIQUE (tenant_id, dedup_key)`), deger `<tip>:<task_id>:<planlanan_iso>`. Erisim: peyzaj
  yonetimi admin (Task CRUD), tamamlama+takvim okuma cleaning/security/admin.
- `asset` / `asset_checkout`: demirbas envanteri + zimmet (al/birak, NFC). `asset.nfc_tag_uid`
  tenant icinde benzersiz (partial unique, NULL haric). `asset.durum` (musait/zimmetli/bakimda).
  **Tek aktif zimmet**: bir asset icin en fazla bir acik checkout → partial unique
  `(tenant_id, asset_id) WHERE birakma_zamani IS NULL`. Idempotency: alma `UNIQUE(tenant_id,
  idempotency_key)`, birakma `UNIQUE(tenant_id, birakma_idempotency_key)` (partial). FK'ler
  composite. Asset CRUD admin; checkout/checkin/history cleaning/security/admin. checkout →
  durum 'zimmetli', checkin → 'musait'.
- `emergency_alert`: acil durum butonu (saha → yonetim anlik alarm). `durum` (acik|cozuldu).
  `POST /emergency` (saha+admin) → alarm + yuksek oncelikli `notification_tip='acil_durum'`
  (dashboard `son_alarmlar`'da en ustte). Idempotency `UNIQUE(tenant_id, idempotency_key)`
  (panik mukerrer basim). Liste/coz admin. FK composite (cozen kolon-ozel SET NULL).
- **Yonetim numarasi:** ayri tablo YOK — `tenant.acil_durum_telefon` (tek alan). `GET
  /tenant/settings` (admin/security/cleaning) ile okunur; mobil acil durumda `tel:` ile arar
  (backend aramaz). `PATCH /tenant/settings` (admin) ile ayarlanir.
- `checkpoint.nfc_tag_uid` tenant icinde benzersiz (NFC eslemesi).
- `patrol_plan` gun-ici sablon; `patrol_window` scheduler'in urettigi somut
  UTC pencere. `scan_event` mobilin gonderdigi tur kaniti.
- `scan_event.patrol_window_id` **nullable** — ad-hoc okutmalar plan disi olabilir.
- Index'ler: her tabloda `tenant_id`, tum FK kolonlari, `scan_event(okutma_zamani)`,
  `patrol_window(durum, pencere_baslangic)` (dashboard/scheduler sorgulari icin).

## Rol modeli — ozet

`admin` (yonetim/CRUD + panel), `security` & `cleaning` (saha: tanim okur, scan
gonderir), `resident` (v0'da operasyon erisimi yok). Tam matris: `auth.md` §4.

## Migration'i calistirma

```bash
cd contracts/db
export DATABASE_URL="postgresql+psycopg://owner:***@localhost:5432/tesis"
alembic upgrade head
```
Migration **owner/superuser** ile calistirilir (RLS'i bypass eder). Uygulama
dusuk-yetkili `app_rw` rolu ile baglanir ve RLS'e tabidir. Detay: `db/README.md`.

## Aidat (konut/daire bazinda)

- **Borc daireye (`unit`) tahakkuk eder** — kiraci/malik degisse de borc dairededir.
  `resident` kullanici daireye `unit_resident` ile baglanir (aktif sakin = `bitis IS NULL`).
- **Tutarlar KURUS (integer minor units).** Para icin **float ASLA** kullanilmaz.
  Tahakkuk/odeme `tutar_kurus > 0` (CHECK); negatif/sifir reddedilir (422).
- **Tahakkuk** (`dues_assessment`): `UNIQUE(tenant_id, unit_id, donem)` — ayni daire+donem
  iki kez tahakkuk olmaz. Tek daire veya toplu donem.
- **Odeme** (`dues_payment`): manuel kayit (admin); gercek tahsilat **YOK** (soyut
  `PaymentProvider`). `UNIQUE(tenant_id, idempotency_key)` (cift kayit korumasi).
- **Bakiye hesabi:** `bakiye_kurus = SUM(tahakkuk.tutar_kurus) - SUM(odeme.tutar_kurus WHERE
  durum='basarili')`. Pozitif bakiye = borc. Kismi odeme bakiyeyi azaltir.
- **Erisim:** Unit/tahakkuk/odeme yonetimi yalniz **admin**; `security/cleaning` aidat gormez;
  `resident` yalniz `GET /me/dues` ile kendi dairelerinin borcunu gorur. Denetlenebilirlik:
  her odeme `kaydeden_user_id` + `odeme_zamani` + `donem` ile izlenir.
- **Saglayici + webhook (kart):** `PAYMENT_PROVIDER = manual|iyzico|paytr` (env). Kart akisi
  `init_payment` → `dues_payment.bekliyor` + `provider`/`provider_ref` + yanitta `odeme_url`.
  Odeme durumunun tek guvenli kaynagi **webhook** (`POST /webhooks/payments/{provider}`, PUBLIC
  + HMAC imza): imza gecersiz → 401; tenant `payment_tenant_by_ref` (SECURITY DEFINER) ile;
  idempotent (`payment_webhook_event`); tutar (kurus) eslesmeli. Durum istemciden DEGISMEZ.
  Gercek anahtar yok (sandbox sonra). `manual` hala anlik `basarili`.

## Kullanici yonetimi (users)

- `GET/POST/PATCH /users` (yalniz **admin**): personel + sakin (resident dahil) olusturma/listeleme/
  guncelleme. **Yeni tablo YOK** — mevcut `app_user` uzerinde calisir. `email` tenant icinde
  benzersiz (`UNIQUE(tenant_id,email)`) → cakisma **409**. parola **bcrypt** (`app/security.py`);
  **`password_hash` yanitta ASLA donmez** (`User` semasinda yok). Kullanici **silinmez**;
  pasiflestirme `is_active=false` (PATCH). tenant token'dan, RLS izole.

## Push bildirim (FCM) + cihaz token kaydi

- **GERCEK FIREBASE KIMLIGI YOK.** `FcmProvider` (backend/app/push.py) gercek FCM HTTP v1
  yapisina gore yazildi (service-account -> OAuth2 access token -> `POST
  /v1/projects/{project_id}/messages:send`, `message.token/notification/data`) ama HTTP + OAuth
  cagrisi mock'lanabilir (`_http_post_json` / `_fetch_access_token`). Kimlik (`FCM_PROJECT_ID` +
  `FCM_SERVICE_ACCOUNT_JSON`) bossa **`push_unconfigured`** (no-op + log; sessiz cokme yok).
- Saglayici secimi `PUSH_PROVIDER = noop | fcm` (varsayilan **noop**) — odeme (`PAYMENT_PROVIDER`)
  deseninin AYNISI. `get_push_provider()`.
- **Cihaz token kaydi:** `POST /devices` (her rol, kendi cihazi; idempotent upsert,
  `UNIQUE(tenant_id, fcm_token)`), `DELETE /devices/{fcm_token}` (pasiflestir), `GET /devices`
  (admin, debug). Yeni tablo **`user_device`** (RLS + tenant-izole).
- **Kanca:** `scheduler/notify.py::dispatch_external` in-app notification'in YANINA push tetikler
  (kacirilan tur / peyzaj / acil durum -> admin+security cihazlari). Push in-app bildirimi
  **ETKILEMEZ**; push hatasi bildirim akisini **KIRMAZ** (try/except + log).

## Gorev tamamlama gecmisi (task-completions)

- `GET /task-completions` (admin + security): TUM gorevlerin tamamlanma **gecmisi** —
  tarih araligi (`baslangic`/`bitis`, yari-acik: `tamamlanma_zamani >= baslangic AND < bitis`),
  `tip` (task.tip uzerinden join), `task_id`, `tamamlayan_user_id` filtreleri; `tamamlanma_zamani`
  **DESC**; sayfali. `/tasks/{id}/completions` tek gorev icindir, bu uc **capraz-gorev** sorgudur.
  **Yeni tablo YOK** — mevcut `task_completion` uzerinde okuma. Ozet (`toplam` + ana tip dagilimi
  temizlik/kontrol/ilaclama/peyzaj) **filtrelenmis tum kume** uzerinden `response.ozet`'te doner.
  Kanit varligi `foto_var`/`nfc_dogrulandi` bool olarak verilir (foto_url/gps donmez). tenant-izole (RLS).

## Tur gecmisi (patrol-windows)

- `GET /patrol-windows` (admin + security): materialize edilmis `patrol_window`'larin
  **gecmisi** — tarih araligi (`baslangic`/`bitis`, yari-acik: `pencere_baslangic >= baslangic AND
  < bitis`), `durum` (bekliyor|tamamlandi|kacirildi) ve `patrol_plan_id` filtreleri; `pencere_baslangic`
  **DESC** sirali; sayfali (limit/offset+meta). `/dashboard/live` anlik bugunku durumu verir, bu uc
  **gecmise donuk** sorgu icindir. **Yeni tablo YOK** — mevcut `patrol_window` uzerinde okuma.
  Ozet sayilar (`toplam/tamamlandi/kacirildi/bekliyor`) **filtrelenmis tum kume** uzerinden
  `response.ozet`'te doner. tenant-izole (RLS).

## Aktif devriye durumu (me/patrol-window)

- `GET /me/patrol-window` (admin + security): mobil icin "aktif turumda hangi noktalar
  okutuldu" listesi — cihaz yerel kaydina gerek kalmadan sunucudan. Aktif pencere =
  **su an icinde olunan** pencere (`pencere_baslangic <= now < pencere_bitis`). Birden cok
  plan ayni anda aktif olabileceginden **tum** aktif pencereler `windows[]` icinde doner
  (her biri kendi `sira` ile sirali checkpoint listesiyle, `pencere_bitis` ASC); `window` +
  `checkpoints` bunlardan **bitisi en yakin** olanin sade gorunumudur. Aktif pencere yoksa
  `window: null` + bos listeler (**200**, hata degil). `okutuldu` **pencere-geneli**
  (herhangi bir elemanin okutmasi sayilir) ve scheduler'in `tamamlandi` hesabiyla ayni
  eslesme: checkpoint + `okutma_zamani` pencere araliginda `[baslangic, bitis)`;
  `okutma_zamani`/`okutan_user_id` penceredeki **ilk** scan'den. **Yeni tablo YOK** —
  mevcut `patrol_window`/`scan_event`/`patrol_plan_checkpoint` uzerinde okuma. tenant-izole (RLS).

## Mobil §13 bulgulari kapatildi (demirbas/zimmet)

Mobil ekibin zimmet modulu bulgularina backend cevabi — hepsi uc/sorgu isi,
**yeni tablo YOK**:

| # | Bulgu | Nasil kapandi |
|---|-------|---------------|
| 1 | UID -> asset cozumu cok istekli | `GET /assets?nfc_tag_uid=...` tam-eslesme filtresi (tenant icinde unique -> 0/1 sonuc) |
| 2 | Acik zimmet icin history taranmasi | Asset liste/detayinda `acik_zimmet` alani: `null` \| `{alan_user_id, alan_user_ad, alinma_zamani}` |
| 3 | "Uzerimdekiler" listesi yok | `GET /assets?checked_out_by=me` (acik zimmeti bende olanlar); `<uuid>` degeri yalniz admin, gecersiz deger 422 |
| 4 | History en eski ustte | Varsayilan **`desc`** yapildi (en yeni ustte); eski davranis `?order=asc` ile duruyor. Mevcut tuketiciler siraya bagimli degildi (admin-web acik kaydi `birakma_zamani==null` ile buluyor) |
| 5 | Yalniz user id, ad yok | `acik_zimmet.alan_user_ad` + history/checkout/checkin item'larinda `alan_user_ad` (id + ad birlikte) |
| 6 | **KRITIK: checkin sahiplik acigi** | `POST /assets/{id}/checkin` artik SAHIPLIK kontrollu: yalniz zimmet sahibi veya admin; baskasi **403** `forbidden` ("Zimmet baskasinin uzerinde..."). Detay: `openapi.yaml` + `auth.md` |

~~Not: zimmeti **kapatan** kullanici ayrica kaydedilmiyor.~~ **KAPANDI** —
`birakan_user_id` kolonu eklendi (asagidaki "birikmis flag temizligi" bolumu).

## Birikmis flag temizligi: mobil §11 + panel aidat raporu + demirbas bulgulari kapatildi

Uc kaynaktan birikmis bulgulara backend cevabi. Bu turda **3 yeni kolon** eklendi
(canonical migration `0001_initial_schema.py` YERINDE guncellendi — ikinci migration
uretilmedi; `down -v` ile yeniden uygulanir):

| Kaynak | Bulgu | Nasil kapandi |
|--------|-------|---------------|
| mobil §11 #1 | "Bana atananlar" filtresi yok | `GET /tasks?atanan_user_id=me` (token kullanicisi) veya duz UUID (panel; gecersiz deger 422) |
| mobil §11 #2 | Foto zorunlulugu alani yok | `task.foto_zorunlu boolean NOT NULL DEFAULT false` (YENI KOLON). `foto_zorunlu=true` iken `foto_key`'siz completion **422** (anlamli mesaj); CRUD semalarinda alan |
| mobil §11 #3 | NFC eslesmesi harfe duyarli | Tek yardimci `norm_nfc` (strip+upper) — task completion, `POST /scans` checkpoint lookup ve asset checkout/checkin NFC karsilastirmalari artik AYNI normalize davranista |
| panel aidat raporu | Serbest odeme doneme atfedilemiyor | `dues_payment.donem text NULL` (YENI KOLON) + `ix_payment_donem`. POST: acik `donem` > assessment'tan tureyen > NULL. `GET /dues/payments?donem=` filtresi |
| demirbas turu | Zimmeti kapatan kaydedilmiyor | `asset_checkout.birakan_user_id uuid NULL` (YENI KOLON; app_user composite FK, kolon-ozel SET NULL). checkin'de dolu yazilir; cevap + history'de `birakan_user_id` + `birakan_user_ad` |

Geriye uyumluluk: uc kolon da nullable/default'lu; yeni response alanlari additive —
eski istemciler etkilenmez. NFC normalizasyonu eslesme kumesini yalniz GENISLETIR
(birebir eslesenler eslesmeye devam eder).

## NTAG424 DNA SDM/SUN kripto dogrulamasi (POST /scans)

`imza_dogrulandi` artik istemci beyani DEGIL — degeri yalniz SUNUCU, etiketin
SDM/SUN ciktisini (AN12196: AES-CBC PICC cozumu, SV2/KSes CMAC, sabit-zaman
karsilastirma) dogrulayarak belirler. Govdedeki `imza_dogrulandi` deprecated +
yok sayilir (eski mobil kirilmaz). Mobil, etiketin NDEF ciktisindan
`sdm_picc_data` (32 hex) + `sdm_cmac` (16 hex) gonderir.

| checkpoint anahtari | SDM alanlari | sonuc |
|---|---|---|
| yok | yok/var | kayit `imza_dogrulandi=false` (gecis donemi) |
| var | yok | kayit `false` (zorlama yok) |
| var | gecersiz | **422 `invalid_signature`** — kayit olusmaz |
| var | sayac ilerlememis | **422 `replay_detected`** — kayit olusmaz |
| var | gecerli | kayit `true`; replay sayaci gunceller |

- **Anahtar kaydi:** `PUT /checkpoints/{id}/sdm-key` (yalniz admin) —
  `{key: "<32 hex>"}` yazar (sayac 0'lanir), `{key: null}` kapatir. Anahtar
  hicbir response'ta donmez; `Checkpoint.sdm_aktif` bool'u gorunur.
- **KEK:** anahtarlar env `SDM_KEK` (32+ karakter) ile AES-GCM sifreli saklanir
  (`checkpoint.sdm_key_sifreli`); KEK yapilandirilmamissa anahtar kaydi **500
  `config_error`**. Rotasyon v0 kapsam disi.
- **Replay:** `checkpoint.sdm_son_sayac` (BIGINT) monotonlugu; guncelleme scan
  insert ile ayni transaction'da kosullu UPDATE (yaris-guvenli). Idempotent
  tekrar (ayni Idempotency-Key) dogrulamayi ATLAR — replay sanilmaz.
- **Tablo degisikligi:** yalniz `checkpoint` +2 kolon (`sdm_key_sifreli`,
  `sdm_son_sayac`) — canonical migration yerinde guncellendi.
- **Fiziksel dogrulama bekliyor:** gercek NTAG424 etiketiyle uctan uca deneme
  cihaz testinde yapilacak (kripto dogrulugu AN12196 yayinli vektorleriyle
  test edildi: `backend/tests/test_nfc_sdm.py`).

## API base path

- **Base path YOK** (`/v0` kaldirildi). Tum endpoint'ler host:port kokunden sunulur:
  `/auth/login`, `/scans`, `/tasks`, `/assets`, `/emergency`, `/dashboard/live`,
  `/notifications`, `/tenant/settings`, `/landscape/schedule` ... Yerel: `http://localhost:8000`.
  (Onceki `openapi.yaml` `servers` girdileri yanlislikla `/v0` iceriyordu; gercek backend
  ile hizalamak icin kaldirildi.)

## Degisiklik politikasi

- Sozlesme degisikligi **once burada** yapilir, PR ile gozden gecirilir, sonra
  backend/mobil/panel uyarlanir.
- Kirici degisiklikler (breaking) yeni surumle (`/v1`) ele alinir; `openapi.yaml`
  `info.version` ve `servers` guncellenir.
