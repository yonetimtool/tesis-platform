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

## Degisiklik politikasi

- Sozlesme degisikligi **once burada** yapilir, PR ile gozden gecirilir, sonra
  backend/mobil/panel uyarlanir.
- Kirici degisiklikler (breaking) yeni surumle (`/v1`) ele alinir; `openapi.yaml`
  `info.version` ve `servers` guncellenir.
