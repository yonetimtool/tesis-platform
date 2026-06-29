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
