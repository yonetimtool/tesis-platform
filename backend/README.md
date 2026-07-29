# /backend — FastAPI Servisi (DEV-A)

Multi-tenant tesis guvenlik & operasyon SaaS'in backend iskeleti.
DB semasi ve API sozlesmesi **`/contracts`** altinda (salt-okunur kaynak); bu
servis onu uygular, **degistirmez**.

## Mimari ozet

- **FastAPI** (async) + **async SQLAlchemy** (asyncpg).
- Uygulama DB'ye **dusuk yetkili `app_rw`** rolu ile baglanir → **RLS'e tabi**.
- Migration'lar **`/contracts/db`** canonical migration'indan, **owner** ile
  uygulanir. Bu serviste **ikinci bir migration yoktur**, autogenerate yapilmaz.
- **Tenant izolasyonu** DB seviyesinde RLS ile zorlanir: her transaction'da
  `app.current_tenant_id` set edilir (`app/db.py`). Set edilmezse hicbir
  tenant-kapsamli satir gorunmez (guvenli varsayilan).
- **Redis** + **Celery** worker iskeleti (ornek `ping` task'i).

```
app/
  config.py       # pydantic-settings (DB/Redis/JWT env)
  db.py           # async engine, session, tenant baglami (SET LOCAL esdegeri)
  models.py       # /contracts semasinin SQLAlchemy aynasi (sadece sorgu icin)
  main.py         # FastAPI app + GET /health
  celery_app.py   # Celery uygulamasi
  tasks.py        # ornek task (ping)
tests/
  conftest.py            # owner + app_rw DB baglantilari
  test_rls_isolation.py  # RLS izolasyon testi (KABUL KRITERI)
  test_health.py         # /health smoke (opsiyonel)
```

## Calistirma (Docker — onerilen)

```bash
cd infra
cp .env.example .env          # degerleri degistirin
docker compose up --build     # db, redis, migrate, api, worker

curl localhost:8000/health    # -> {"status":"ok","checks":{"database":true,"redis":true}}
```

Sira: `db` saglikli → `migrate` (canonical migration + app_rw kurulumu) →
`api`/`worker`.

## Testler

RLS izolasyon testi DB'ye dogrudan baglanir (owner + app_rw). En kolay yol,
compose ayaktayken api container'i icinde calistirmaktir (DSN env'leri orada
hazir):

```bash
docker compose exec api pytest -v
```

Beklenen: `test_rls_isolation.py` → 4 test PASS
(A sadece A'yi gorur, B sadece B'yi, capraz sizinti yok, tenant set degilse 0 satir).

> **KOD DEGISIKLIGINDEN SONRA IMAGE'I YENILE.** Kod image'a GOMULUDUR (mount
> yok): `docker compose build api && docker compose up -d api`. Aksi halde
> pytest ESKI kodu/testleri kosar ve anlasilmaz hatalar gorursun.


### Fixture artiklari ve rasgele sira (tur 46)

Suit **pytest-randomly** ile RASGELE SIRADA kosar. Iki yapisal kirilganlik
vardi ve ikisi de "tek bir artik satir tum suiti kirmiziya dondurur" sinifina
giriyordu:

1. **SABIT TELEFON NUMARALARI.** `world` fixture'i kullanicilari
   `+90500000000x` gibi sabit numaralarla aciyordu. `app_user.telefon`
   **GLOBAL benzersizdir** (tenant'lar arasi). Kosum ortadan kesilirse
   (timeout, Ctrl-C, konteyner restart) fixture temizligi hic calismaz;
   kalan TEK kullanici sonraki kosumun HER testini `UniqueViolation` ile
   dusururdu. Numaralar artik tenant uuid'sinden turetilir
   (`_telefonlar`, `+9054<7 hane><indeks>`) — catisma imkansiz.
   Testlerin kendi olusturdugu numaralar da (`world["bos_telefonlar"]`)
   ayni kaynaktan gelir.

2. **YARIDA KALAN KURULUM TEMIZLENMIYORDU.** Fixture `yield`den sonra
   siliyordu; kurulum ortasinda hata olursa (ornegin yukaridaki kisit
   ihlali) tenant satiri kaliyordu. Temizlik artik `request.addfinalizer`
   ile INSERT'ten ONCE kaydedilir.

Ayrica session basinda **artik temizligi** calisir: onceki kosumdan kalan
fixture tenant'lari (`ca-`, `cb-`, `rls-a-`, `rls-b-`, `ta-`, `tb-`, `cam-`,
`sched-` onekli) silinir. Seed tenant'i (`acme-plaza`) ve gercek veriler
ETKILENMEZ. Yeni bir fixture tenant oneki eklenirse `FIXTURE_SLUG_ONEKLERI`
listesine de yazilmalidir.

> Dogrulama: kesilmis kosumun biraktigi artik ELLE olusturulup suit yeniden
> kosuldu — eskiden komple duserdi, simdi geciyor ve artik temizleniyor.

### Seed'in BAYATLAMASI ve tazelik denetimi (tur 55)

Goreli tarihli seed verisi zamanla bayatlar ve bayatlama **SESSIZDIR**: panel
o durumu bos olcer, kimse fark etmez. Tur 49 envanterinde tam bu gorulmustu —
tur 41'de eklenen "bugun aktif devriye penceresi" `kacirildi`ya donmustu, yani
`/dashboard`in AKTIF TUR hali artik hic surulemiyordu.

Iki ayri sorun vardi:

1. **DEVRIYE PENCERELERI IDEMPOTENT DEGILDI.** Var-mi kontrolunun anahtari
   `pencere_baslangic` idi ve deger `now()`dan turiyordu; **her kosum ucer yeni
   pencere ekliyordu** (22 pencere birikmisti). Artik zaman **saat basina
   hizalanir** — ayni saat icinde tekrar kosum ayni satiri bulur — ve planin
   onceki seed pencereleri silinir. Iki kosum ust uste: 3 pencere, sabit.

2. **YAKLASAN ETKINLIKLER TAZELENMIYORDU.** `WHERE NOT EXISTS (baslik)`
   idempotentti ama tarihi ILK kosumdan kaliyordu; 4 etkinlikten yalniz 1'i
   "yaklasan" kalmisti. Tarih artik her kosumda `UPDATE` ile tazelenir.

**TAZELIK DENETIMI.** Seed sonunda kendi ciktisini denetler ve basar:

```
[seed] tazelik: aktif devriye penceresi = 1 (OK)
[seed] tazelik: yaklasan etkinlik = 2 (OK)
[seed] tazelik: okunmamis bildirim = 10 (OK)
[seed] tazelik: fotografli talep = 2 (OK)
```

Sifir cikan satir `BAYAT/BOS` isaretlenir — surus o durumu bos olcecek demektir.

> Denetim blogu `with psycopg.connect(...)` GOVDESININ ICINDE olmalidir; disarida
> `conn` kapali ve execute "connection is closed" verir (tur 41'de ayni tuzaga
> dusuldu, tur 55'te ilk denemede tekrarlandi).

### Zaman bagimli testler (saat flake'i)

Testler CANLI sunucuya gider ve sunucu GERCEK saati kullanir; zamanlama kurallari
tenant-yerel saatte olculur. `test_rezervasyon.py` bu yuzden eskiden aksam
saatlerinde kiriliyordu (slotlar gece yarisini sariyor, alan kapanisi "24:00"
oluyordu). **Cozuldu:** dosya tenant'in saat dilimini yerel saat ~09:xx olacak
sabit-ofset bir bolgeye (`Etc/GMT±N`, DST yok) alir; secim `test_saat_dilimi_
secimi_24_saatin_hepsinde_guvenli` ile 24 UTC saati icin dogrulanir. Bu dosyada
saat kaynakli bir kirik gorursen artik gercek bir kusur ara.

Kesilen bir kosum `world`/`rworld` tenant'larini geride birakabilir (teardown
kacar). Sonraki kosumda benzersizlik hatalari gorursen temizle:

```bash
docker compose exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "DELETE FROM tenant WHERE slug !~ 'acme';"
```

Ayrica **iki pytest kosumunu ayni anda calistirmayin** — ayni DB'yi paylastiklari
icin yuzlerce sahte `psycopg` hatasi uretirler.

### Hata metni testleri (tur 14)

```bash
docker compose exec api pytest -q tests/test_hata_i18n.py   # 23 test
```

Ilk 18'i saf birim testidir (katalog butunlugu, dil cozumleme, kaynak
taramasi); son 5'i CALISAN API'ye gider ve ayni istegin `Accept-Language`
degistikce farkli metin, **ayni kodu** dondurdugunu dogrular.

`test_kaynakta_ham_cumle_kalmadi` yeni bir hata cumlesi eklendiginde kirilir;
cozum metni `app/hata_metinleri.py` katalogunda 7 dille tanimlamaktir.

### Host'tan calistirma (opsiyonel)

`docker compose up` ile portlar acik (5432/8000). Host'ta sanal ortamda:

```bash
cd backend
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
export OWNER_DSN="postgresql://tesis_owner:owner_secret_change_me@localhost:5432/tesis"
export APP_DSN="postgresql://app_rw:app_rw_secret_change_me@localhost:5432/tesis"
export API_URL="http://localhost:8000"
pytest -v
```
> DSN sifrelerini `.env` ile ayni tutun.

## Ortam degiskenleri

| Degisken | Aciklama | Ornek |
|----------|----------|-------|
| `DATABASE_URL` | Uygulama async DB URL (app_rw) | `postgresql+asyncpg://app_rw:***@db:5432/tesis` |
| `REDIS_URL` | Redis (cache + Celery) | `redis://redis:6379/0` |
| `JWT_SECRET` | JWT imza anahtari (Prompt 2) | `...32+ char...` |
| `JWT_ALGORITHM` | varsayilan `HS256` | `HS256` |
| `SQL_ECHO` | SQLAlchemy echo (debug) | `false` |
| `OWNER_DSN` *(test/migrate)* | owner libpq DSN | `postgresql://tesis_owner:***@db:5432/tesis` |
| `APP_DSN` *(test)* | app_rw libpq DSN | `postgresql://app_rw:***@db:5432/tesis` |

## Auth (Prompt 2)

JWT `access` (15 dk) + `refresh` (30 gun), `/contracts/auth.md`'ye gore.

- **Parola:** bcrypt (`app/security.py`).
- **Login tenant'i `tenant_slug` ile belirler** (email tenant-ici benzersiz).
  slug→tenant_id cozumu RLS bootstrap'i icin owner-sahipli `SECURITY DEFINER`
  fonksiyon `tenant_id_by_slug` ile (bkz. `/contracts/auth.md §1.1`).
- **Refresh rotation/iptal** Redis'te tutulur (sema'da refresh tablosu yok):
  her refresh tek kullanimlik; eski jti tekrar gelirse aile iptal edilir.
- **Dependency'ler** (`app/deps.py`): `get_access_claims` → `get_tenant_db`
  (token'daki tenant_id ile `SET LOCAL`) → `get_current_user` → `require_role(...)`.

Endpoint'ler:
| Method/Path | Auth | Not |
|-------------|------|-----|
| `POST /auth/login` | public | `{tenant_slug,email,password}` → TokenPair |
| `POST /auth/refresh` | public | `{refresh_token}` → TokenPair (rotation) |
| `GET /me` | access | token'daki kullanici |
| `GET /me/checkpoints` | access | Faz-0 izolasyon dogrulama (diagnostic) |
| `GET /admin/overview` | access + `admin` | RBAC demo (403 ornegi) |

Hizli deneme:
```bash
TOKEN=$(curl -s localhost:8000/auth/login -H 'content-type: application/json' \
  -d '{"tenant_slug":"acme-plaza","email":"admin@acme.com","password":"..."}' \
  | python -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
curl -s localhost:8000/me -H "Authorization: Bearer $TOKEN"
```

> **Sema degisikligi (onayli):** Bu prompt'ta `/contracts`'a `tenant.slug` kolonu
> + `tenant_id_by_slug` fonksiyonu eklendi. Mevcut bir DB varsa migration'i yeniden
> uygulamak icin volume sifirlanmali: `docker compose down -v && docker compose up --build`.

## Aidat (konut/daire + tahakkuk + odeme)

Borc **daireye** (`unit`) tahakkuk eder; `resident` daireye `unit_resident` ile baglanir
(aktif = `bitis NULL`). **Tutarlar KURUS (integer); para icin float yok.**
- **Unit CRUD** (`/units`, admin): no tenant-ici benzersiz → 409. Sakin: `POST/GET
  /units/{id}/residents`, `DELETE /units/{id}/residents/{user_id}` (bitis=now).
- **Tahakkuk** (`POST /dues/assessments`, admin): tek daire (`unit_id`) veya **toplu**
  (`unit_ids` ya da tum aktif daireler). `UNIQUE(tenant_id,unit_id,donem)` → tek dairede
  ikinci kez 409; toplu modda mevcutlar `atlanan` sayilir.
- **Odeme** (`POST /dues/payments`, admin): **gercek tahsilat YOK** (soyut
  `PaymentProvider`, `app/payments.py`). `Idempotency-Key` zorunlu (cift kayit; 200/409/400).
  `kaydeden` token'dan; denetlenebilir. **`donem`** ('YYYY-MM', nullable): acikca verilir
  ya da `assessment_id`'nin doneminden turer; ikisi de yoksa NULL (serbest odeme).
  Liste `GET /dues/payments?donem=` ile donem bazli suzulur (rapor atfi).
- **Bakiye:** `bakiye_kurus = toplam_tahakkuk - toplam_odenen(durum='basarili')` (pozitif=borc).
  `GET /units/{id}/dues` (admin) ve `GET /me/dues` (resident — yalniz kendi daireleri).

### Odeme saglayici + webhook (iyzico / paytr iskeleti)
`app/payments.py` — tek arayuz `PaymentProvider` (`init_payment` + `verify` +
`parse_and_verify_webhook`). `get_payment_provider()` env **`PAYMENT_PROVIDER`** (manual|iyzico|paytr,
vars. manual) ile secer.
- **manual** (elden/havale): anlik `basarili`, para hareketi yok (mevcut akis korunur).
- **iyzico / paytr** (kart): `init_payment` gercek API yapisina gore istek kurar (endpoint,
  imza/hash — iyzico `IYZWS` sha1, paytr HMAC-SHA256), HTTP `_http_post_json/_http_post_form`
  arkasinda (test'te mock'lanir). Sonuc: `dues_payment.bekliyor` + `provider`/`provider_ref`
  + yanitta `odeme_url`. **Anahtar yoksa 503 `payment_unconfigured`** (sessiz cokme yok).

**Webhook** (`POST /webhooks/payments/{provider}`, `app/routers/webhooks.py`) — odeme onayinin
GUVENLI yolu:
1. **Imza dogrulama** (DB'den once): provider secret ile HMAC; gecersiz → **401**, islem yok.
2. **Tenant cozumu**: token yok → `payment_tenant_by_ref(provider, provider_ref)` SECURITY DEFINER
   (RLS bootstrap) → `set_config`.
3. **Idempotency**: `payment_webhook_event` UNIQUE(tenant,provider,event_id) — tekrar → no-op 200.
4. **Tutar kontrolu**: webhook tutari (kurus) `dues_payment.tutar_kurus` ile eslesmeli → degilse
   **400** (rollback, durum degismez).
5. Gecerli → `durum=basarili/iptal`, bakiyeye yansir.

**GERCEK ANAHTAR YOK** — sandbox denemesi anahtarlar gelince. Yerel/test secret'lari compose
`:-` varsayilanlarindan gelir (`PAYTR_MERCHANT_KEY` vb.).
seed: `acme-plaza` icin `A-12` dairesi + `resident@acme.com` baglantisi + `2026-06` tahakkuk (750 TL).

## Duyuru (announcement)

Yonetimden tum tesise duyuru (`app/routers/announcements.py`).
- **RBAC (auth.md §4):** gonderme/duzenleme/silme **admin + yonetici**; okuma
  **TUM roller** (resident dahil — sakinin ilk operasyon-disi kaynagi).
- **Uclar:** `GET /announcements` (liste, `created_at DESC`, sayfali; her item
  `olusturan_ad` tasir) / `GET /announcements/{id}` / `POST` / `PATCH` / `DELETE`.
- **Push:** olusturmada tenant'in TUM aktif cihazlarina push denenir
  (`dispatch_external` — EK gonderim; hatasi duyuru kaydini KIRMAZ).
  `data: {tip: "duyuru", announcement_id}`.
- **Model:** `announcement` (baslik ≤200, govde ≤5000, olusturan composite FK
  `ON DELETE RESTRICT`); RLS tenant-izole. seed 'Hos geldiniz' ornegi ekler
  (baslik uzerinden idempotent).

## Demirbas envanteri + zimmet (Asset / checkout / checkin)

Demirbas (`asset`) + zimmet (`asset_checkout`) — "kim aldi/birakti" (NFC) (`app/routers/assets.py`).
- **Asset CRUD** (`/assets`): GET liste (`kategori`/`durum`/`aktif`/`nfc_tag_uid`(tam eslesme)/
  `checked_out_by`(`me` | uuid — uuid yalniz admin) filtreleri, sayfali) / detay / POST / PATCH /
  DELETE. **RBAC:** GET admin/yonetici/security/tesis_gorevlisi; yazma yalniz admin. Liste/detay item'lari
  `acik_zimmet` ozeti tasir (`null` | `{alan_user_id, alan_user_ad, alinma_zamani}`).
  `nfc_tag_uid` tenant icinde benzersiz (NULL haric) → cakisma **409**. `durum`:
  musait/zimmetli/bakimda.
- **checkout** (`POST /assets/{id}/checkout`, admin/security/tesis_gorevlisi): demirbasi al.
  `Idempotency-Key` zorunlu (400). `nfc_tag_uid` verilirse asset nfc'siyle eslesmeli (422).
  `alan_user_id` token'dan. **Tek aktif zimmet**: zaten zimmetliyse **409** (DB'de partial
  unique `(tenant_id, asset_id) WHERE birakma_zamani IS NULL` ile garanti). Idempotency:
  ayni key+gövde → 200, farkli → 409 (scan SAVEPOINT deseni). Basarili → asset.durum='zimmetli'.
- **checkin** (`POST /assets/{id}/checkin`): acik zimmeti kapatir (birakma_zamani=now,
  durum='musait'). **SAHIPLIK (mobil §13 #6):** yalniz zimmetin sahibi veya admin; baskasi
  **403** `forbidden`. Kapatan **`birakan_user_id`** olarak kaydedilir. `Idempotency-Key`
  zorunlu; ayni key ile tekrar → 200 ayni kayit (`birakma_idempotency_key` partial unique).
  Acik zimmet yoksa **409**.
- **history** (`GET /assets/{id}/history`): zimmet gecmisi, `?order=asc|desc`
  (varsayilan **desc** — en yeni ustte), item'larda `alan_user_ad` + `birakan_user_id`/
  `birakan_user_ad`, sayfali, tenant-izole.

## Peyzaj bakim takvimi + hatirlatma

Ayri tablo **YOK** — mevcut task sistemi genisletildi:
- `task.tip='peyzaj'` + takvim alani **`task.sonraki_planlanan`** (UTC) + tekrar araligi
  olarak mevcut **`periyot_dakika`**. Yonetim mevcut **Task CRUD** ile (admin).
- **Takvim:** `GET /landscape/schedule` → aktif peyzaj task'lari `sonraki_planlanan` ARTAN,
  sayfali, tenant-izole (admin/yonetici/security/tesis_gorevlisi).
- **Tamamlama ilerletir:** periyodik task tamamlaninca (`task_completion`)
  `sonraki_planlanan += periyot_dakika` (`create_completion`, yalnizca yeni kayitta).
- **Hatirlatma** (`scheduler.landscape_reminders`, beat, varsayilan saat basi):
  - `peyzaj_yaklasan`: `sonraki_planlanan ∈ [now, now+lead]` (`SCHEDULER_LANDSCAPE_LEAD_HOURS`, vars. 24).
  - `peyzaj_kacirilan`: `sonraki_planlanan < now` ve o tarihten sonra tamamlama yok.
  - **Idempotent:** `notification.dedup_key = "<tip>:<task_id>:<planlanan_iso>"` +
    `UNIQUE(tenant_id, dedup_key)` + `ON CONFLICT DO NOTHING`. Mevcut notify deseni
    (app_rw + tenant context, RLS) yeniden kullanilir; gercek push hala yok (kanca var).
- Peyzaj bildirimleri `/notifications` altinda gorulur; **dashboard `son_alarmlar`'a
  DUSMEZ** (alarm tipi degil) — dashboard yalniz `kacirilan_tur/eksik_checkpoint/gecikmis_okutma`.

## Gorev sistemi + foto kanit (Task / Completion / MinIO)

Esnek **tek `task` modeli** (`tip`: temizlik/kontrol/ilaclama/bakim/diger). Cop topla,
kamelya kontrol, havuz, bahce vb. hepsi `tip + ad` ile ayrisir (`app/routers/tasks.py`).

- **Task CRUD** (`/tasks`): GET liste (`tip`/`aktif`/`atanan_user_id`(`me`|uuid — mobil
  "Gorevlerim") filtreleri, sayfali) / detay / POST / PATCH / DELETE. **RBAC:** GET
  admin/yonetici/security/tesis_gorevlisi; yazma admin/yonetici (yonetici yalniz
  security/tesis_gorevlisi'ne atayabilir). `atanan_user_id` ve `checkpoint_id` aynı
  tenant'ta olmali (capraz → 422). **`foto_zorunlu`** (bool, vars. false): true ise
  completion `foto_key`'siz kabul edilmez.
- **Tamamlama** (`POST /tasks/{id}/completions`): admin/security/tesis_gorevlisi. **Idempotency-Key
  zorunlu** (scan deseni: aynı key+gövde → 200, farklı → 409, key yok → 400). `tamamlayan_user_id`
  token'dan. Task'ın `checkpoint_id`'si varsa ve `nfc_tag_uid` gönderilirse o checkpoint'in
  nfc'siyle eşleşmeli (yoksa 422; karsilastirma **normalize**: strip+upper, `crud_helpers.norm_nfc`
  — scan/asset uclariyla ayni). `foto_zorunlu=true` + `foto_key` yok → 422 (anlamli mesaj).
  Gecmis: `GET /tasks/{id}/completions`.

### Foto kanit akisi (MinIO, presigned)
1. İstemci `POST /uploads/presign` `{content_type}` → backend **`foto_key`** (tenant ile
   namespace'li) + **presigned PUT `upload_url`** döner (`app/storage.py`, boto3; URL **yerel
   imzalanır**, MinIO ayakta olmasa da üretilir).
2. İstemci dosyayı **doğrudan** `upload_url`'e `PUT` eder (backend'den geçmez).
3. İstemci completion'da `foto_key`'i gönderir → kalıcı saklanır.

`upload_url` host'u **PUBLIC** endpoint (`MINIO_PUBLIC_ENDPOINT`, dev: `http://localhost:9000`)
olmalı ki istemci erişebilsin.

### MinIO erisim (dev)
- S3 API: `http://localhost:9000` · Web console: `http://localhost:9001`
- Giris: `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` (`.env`).
- Bucket (`MINIO_BUCKET`, dev `tesis-foto`) compose'taki **`minio-init`** one-shot servisiyle olusur.
- Env: `MINIO_ENDPOINT` (=PUBLIC), `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET`.

Hizli foto denemesi:
```bash
P=$(curl -s -X POST localhost:8000/uploads/presign -H "Authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' -d '{"content_type":"image/jpeg"}')
URL=$(echo "$P" | python -c 'import sys,json;print(json.load(sys.stdin)["upload_url"])')
KEY=$(echo "$P" | python -c 'import sys,json;print(json.load(sys.stdin)["foto_key"])')
curl -s -X PUT "$URL" -H 'content-type: image/jpeg' --data-binary @foto.jpg   # MinIO'ya yukle
# sonra completion'da foto_key=$KEY gonderilir
```

## Panel — GET /dashboard/live

Yoneticinin canli ozeti (`app/routers/dashboard.py`).
- **RBAC:** admin/yonetici/security (tesis_gorevlisi/resident → 403).
- **aktif_turlar:** tenant-yerel **bugune** ait `patrol_window`'lar + durum +
  `beklenen_checkpoint_sayisi` (atanmis aktif checkpoint) + `okutulan_checkpoint_sayisi`
  (pencere araliginda okutulmus, beklenen). Tek set-tabanli sorgu (N+1 yok).
- **son_alarmlar:** son `kacirildi` pencerelerden **turetilir** (`tip=kacirilan_tur`),
  `alarm_limit` (1–100, varsayilan 20) ile.
- tenant token'dan, RLS izole. `generated_at` = sunucu UTC.

### Notification (kalici bildirim) — eklendi
Sozlesmeye `notification` tablosu + `GET /notifications` + `PATCH /notifications/{id}`
eklendi (onayli contract degisikligi). Davranis:
- `notify_missed_tour(...)` kacirilan turu **kalici** `notification` kaydina yazar
  (`tip=kacirilan_tur`), **idempotent**: `UNIQUE (tenant_id, tip, patrol_window_id)` +
  `ON CONFLICT DO NOTHING` → ayni pencere icin cift kayit olmaz. Yazma, scheduler'in
  app_rw + tenant-context (`SET LOCAL`) baglantisi icinde → RLS uyumlu.
- **Gercek push/SMS hala YOK** — `_dispatch_external(...)` soyut kancasi (no-op/log).
- **`GET /notifications`** (admin+security): sayfali (`limit/offset`+meta), `okundu`
  filtresi, tenant-izole. **`PATCH /notifications/{id}`**: `okundu` isaretleme.
- **Dashboard `son_alarmlar`** artik `notification` tablosundan okunur (response semasi
  AYNI — `Alarm`).

## Mobil — GET /me/patrol-window

Mobil ekibin bulgusu uzerine eklendi: "aktif turumda hangi noktalari okuttum" listesi
artik sunucudan alinir — cihaz yerel kaydina gerek yok (`app/routers/me_patrol.py`).
- **RBAC:** admin + security (yonetici/tesis_gorevlisi/resident → 403) — saha gorevlisinin kendi turu.
- **Aktif pencere:** su an icinde olunan pencere (`pencere_baslangic <= now < pencere_bitis`).
  Birden cok plan ayni anda aktifse **tum** pencereler `windows[]`'ta (her biri kendi
  `sira` sirali checkpoint listesiyle, `pencere_bitis` ASC); `window` + `checkpoints` =
  bitisi en yakin olani. Aktif pencere yoksa `window: null` + bos listeler (**200**).
- **okutuldu pencere-geneli:** herhangi bir elemanin pencere araligindaki okutmasi sayilir —
  scheduler'in `tamamlandi` hesabiyla ayni eslesme. `okutma_zamani`/`okutan_user_id`
  penceredeki **ilk** scan'den (LATERAL, tek set-tabanli sorgu).
- **Tablo degisikligi YOK** — mevcut tablolar uzerinde salt okuma. tenant token'dan, RLS izole.

## Tur kaniti — POST /scans

Mobil/saha istemcisinin checkpoint okutma kanitini gonderdigi uc (`app/routers/scans.py`).
- **RBAC:** admin/security/tesis_gorevlisi gonderebilir; yonetici/resident → 403.
- **tenant + guard_id token'dan** turetilir (istekten alinmaz).
- **nfc_tag_uid → checkpoint** RLS ile tenant icinde cozulur; bulunamazsa **404**
  (capraz-tenant tag da burada 404). `checkpoint_id` verilirse nfc ile tutarliligi dogrulanir.
- **Idempotency (zorunlu `Idempotency-Key`):** header yoksa **400**. `UNIQUE(tenant_id,
  idempotency_key)` ile race-safe (SAVEPOINT/`begin_nested`): ayni key + ayni govde →
  mevcut kayit **200**; ayni key + farkli govde → **409**.
- **imza_dogrulandi (NTAG424 SDM/SUN):** deger **yalniz sunucuda** hesaplanir
  (`app/nfc_sdm.py`, AN12196: AES-CBC PICC cozumu + SV2/KSes CMAC + sabit-zaman
  karsilastirma); govdedeki `imza_dogrulandi` **deprecated + yok sayilir**. Mobil
  `sdm_picc_data`(32 hex) + `sdm_cmac`(16 hex) gonderir. Karar tablosu:

  | checkpoint anahtari | SDM alanlari | sonuc |
  |---|---|---|
  | yok | yok/var | kayit `false` (gecis donemi) |
  | var | yok | kayit `false` (zorlama yok) |
  | var | gecersiz | **422 `invalid_signature`** — kayit olusmaz |
  | var | sayac ilerlememis | **422 `replay_detected`** — kayit olusmaz |
  | var | gecerli | kayit `true`; sayac gunceller |

  Replay korumasi `checkpoint.sdm_son_sayac` monotonlugu: kosullu UPDATE
  (`WHERE sdm_son_sayac < :ctr`) scan insert ile **ayni transaction'da** —
  0 satirda 422 + tam rollback. **Idempotent tekrar SDM dogrulamasini ATLAR**
  (once idempotency SELECT) — offline outbox tekrari replay sanilmaz.
- **SDM anahtar kaydi:** `PUT /checkpoints/{id}/sdm-key` (yalniz admin) —
  `{key:"<32 hex>"}` yazar + sayaci 0'lar; `{key:null}` kapatir. Anahtar **hicbir
  response'ta donmez** (`sdm_aktif` bool'u gorunur). Anahtarlar env **`SDM_KEK`**
  (32+ karakter; `infra/.env.example`) ile **AES-GCM sifreli** saklanir; KEK
  yapilandirilmamissa kayit **500 `config_error`**. **Fiziksel dogrulama
  bekliyor:** gercek NTAG424 etiketiyle uctan uca deneme cihaz testinde; kripto
  dogrulugu AN12196 **yayinli vektorleriyle** kanitli (`tests/test_nfc_sdm.py`).
  Provisioning varsayimi (v0): UID+CTR aynali, ENCPICCData'li, SDMMAC girdisi bos
  (AN12196 ornek konfigurasyonu).
- **Pencere durum gecisi BURADA YAPILMAZ** (tek sorumluluk): scan yalnizca kaydedilir;
  `patrol_window`'un `tamamlandi`/`kacirildi` gecisi **scheduler'in detect task'inin** isidir
  (zaman-tabanli eslestirme). `patrol_window_id` verilirse yalnizca varligi dogrulanir.

> Sozlesmede `GET /scans` tanimli degil → eklenmedi.

## Scheduler (patrol_window uretimi + kacirilan tur tespiti)

Celery beat ile iki periyodik task (`app/scheduler/`):

1. **Pencere uretimi** (`scheduler.generate_patrol_windows`, varsayilan saat basi):
   Her aktif `patrol_plan` icin, `tenant.timezone`'a gore plan saatlerini
   (`baslangic_saat`→`bitis_saat`, `periyot_dakika`) **somut UTC** `patrol_window`'lara
   cevirir, `bekliyor` olarak yazar. **Materialize-ahead** (anlik hesap yok), varsayilan
   ufuk **bugun+yarin** (`SCHEDULER_HORIZON_DAYS`). DST-guvenli (zoneinfo). `baslangic > bitis`
   → ertesi gune sarkar. **Idempotent:** `ON CONFLICT (patrol_plan_id, pencere_baslangic)
   DO NOTHING` — sozlesmedeki `uq_patrol_window_plan_baslangic` dogal anahtari.

2. **Kacirilan tur tespiti** (`scheduler.detect_missed_tours`, varsayilan 5 dk):
   `pencere_bitis <= now` ve hala `bekliyor` her pencere icin durum belirlenir.
   - **"tamamlandi" tanimi (v0):** Plana atanmis **TUM AKTIF** checkpoint'ler icin,
     `okutma_zamani` pencere araliginda `[baslangic, bitis)` en az bir `scan_event`
     varsa → `tamamlandi`. En az biri eksikse → `kacirildi` + `notify_missed_tour(...)`
     (bu turda yalnizca yapilandirilmis **log**; gercek push/SMS + Notification tablosu
     sonraki prompt). Atanmis aktif checkpoint yoksa (bos plan) → vacuously `tamamlandi`.
   - **Idempotent:** yalnizca `bekliyor` pencereler islenir; `tamamlandi`/`kacirildi`
     olanlara dokunulmaz (tekrar notify yok).

**RLS uyumu (token yok):** Task'lar HTTP istegi degil. Tenant **listesi** app_rw ile
okunamaz (`tenant` RLS; baglam yokken satir gorunmez) — bu yuzden tenant enumerasyonu
**OWNER** (`OWNER_DSN`) ile salt-okuma yapilir (gerekce: RLS bootstrap). Asil is (plan/
checkpoint/scan okuma, `patrol_window` yazma) her tenant icin **app_rw + `SET LOCAL
app.current_tenant_id`** ile RLS altinda yurutulur; bir tenant'in verisi digerine sizmaz.

Manuel tetikleme (beat'i beklemeden):
```bash
docker compose exec api python -m scripts.run_scheduler --once
docker compose exec api python -m scripts.run_scheduler --generate --horizon 1
docker compose exec api python -m scripts.run_scheduler --detect --now 2026-06-27T07:00:00Z
```

Servisler: `worker` (Celery worker) + `beat` (Celery beat) — `infra/docker-compose.yml`.
Env: `OWNER_DSN`, `APP_DSN`, `SCHEDULER_HORIZON_DAYS`,
`SCHEDULER_GENERATE_INTERVAL_SECONDS`, `SCHEDULER_DETECT_INTERVAL_SECONDS`.

## Hata metinleri 7 dilde (tur 14)

Hata zarfindaki `message` kullaniciya **aynen** gosterilir (mobil
`ApiException.message`). Tur 13'e kadar bu metin sabit Turkce cumleydi: Arapca
arayuzdeki bir sakin 409'u Turkce goruyordu. Artik `APIError` **cumle degil
kimlik** tasir, metin istegin `Accept-Language` basligina gore hata
isleyicisinde uretilir.

| Parca | Yer |
|---|---|
| Katalog (kimlik → 7 dil) | `app/hata_metinleri.py` — `METINLER` (**127 kimlik × 7 dil**) |
| Cozumleyici | `hata_metni(kimlik, dil, params)` + `istek_dili(header)` |
| Uretim noktasi | `app/errors.py` — `install_error_handlers` (TEK yer) |
| Dil zinciri | `ceviri.accept_language_coz` — **icerik cevirisiyle AYNI** |
| Kilit | `tests/test_hata_i18n.py` (22 test; 5'i calisan API'ye) |

```python
# cumle DEGIL kimlik; parametreler kwargs ile
raise APIError(409, "conflict", "blok_etiketi_zaten_kayitli")
raise APIError(422, "invalid_reference", "daire_listesi_bulunamadi", eksik=", ".join(missing))
```

**Kurallar**

* `code` **dilden bagimsizdir** ve istemci mantigi onunla kurulur; `message`
  yalnizca gosterilir (bkz. `/contracts/README.md` → Hata formati).
* Yeni hata eklerken katalogda **7 dilin hepsi** yazilir. Eksik dil calisma
  aninda Turkce'ye duser (kullaniciya bos metin gitmez) ve
  `test_katalog_tam` ile yakalanir.
* `APIError`e **cumle gecirilmez**: `test_kaynakta_ham_cumle_kalmadi` tum
  `app/` agacini tarar ve katalogsuz metni reddeder.
* **Cevrilmeyenler** (bilincli): `storage_unconfigured`, `config_error`,
  `payment_unconfigured`, `payment_provider_error`, `webhook_unsupported` —
  operatore/loga hitap eder, kullaniciya degil.
* Parametreli metinlerde alan adlari **tum dillerde ayni** olmali
  (`test_parametreli_kimliklerde_alanlar_tum_dillerde_ayni`) — bir dilde
  dusen `{plaka}` sessizce eksik bilgi gosterir.

### Kalan sunucu i18n borcu (tur 14 KAPSAMI DISI)

Bu tur **hata metinlerini** kapsadi. Sunucunun urettigi diger kullanici-gorunur
metinler hala Turkce:

| Ne | Yer | Not |
|---|---|---|
| ~~`/activity` satirlari~~ | ~~`app/routers/activity.py`~~ | **TUR 15'TE KAPANDI** — asagi bak. |
| ~~Push bildirim metinleri~~ | ~~`app/push.py` cagrilari~~ | **TUR 16'DA KAPANDI** — asagi bak. |
| ~~`notification.mesaj`~~ | ~~`app/scheduler/notify.py`~~ | **TUR 16'DA KAPANDI** — kayit kimlik tasir, metin okuma aninda uretilir. |
| Seed/demo icerigi | `scripts/seed.py` | Ornek veridir, cevrilmez. |

**Sunucunun urettigi kullanici-gorunur metinlerin hepsi artik 7 dilde.**

## Push + in-app bildirim metinleri (tur 16)

Bildirimlerin sorunu hata metinlerinden FARKLIYDI: **push asenkrondur** —
gonderim aninda istek yoktur, dolayisiyla `Accept-Language` de yoktur. Tur
14'un cozumu (istek aninda cevirme) burada calismaz. Iki parca gerekti:

| Parca | Yer |
|---|---|
| Katalog (kimlik -> baslik + govde, 7 dil) | `app/push_metinleri.py` — **14 kimlik** |
| Cihazin dili | `user_device.dil` (migration **0008**); `POST /devices` govdesindeki `dil` |
| Gonderim | `scheduler/notify.dispatch_external(kimlik, params=...)` — dile gore GRUPLAR |
| Kalici kayit | `notification.mesaj_kimlik` + `mesaj_veri` (0008) |
| Okuma | `routers/notifications` — metin `Accept-Language`e gore uretilir |
| Kilit | `tests/test_push_i18n.py` (17 test) |

```python
# cumle DEGIL kimlik + parametre
dispatch_external(
    "kargo",
    tenant_id=user.tenant_id,
    target_user_ids=sakinler,
    params={"firma": body.firma, "daire": unit.no},
    data={"tip": "kargo", "kargo_id": str(obj.id)},
)
```

**Kurallar**

* Kimlik = `data.tip` = `notification.tip` (mumkun oldugunca): istemci
  yonlendirmesi ile metin AYNI anahtari kullanir.
* **Durum bir SOZCUK ise kimlige girer**, parametreye degil:
  `talep_cozuldu` / `talep_reddedildi` ayri kimliklerdir. `{durum}` diye
  parametre gecmek, cevrilecek metni gizlemenin baska bir yolu olurdu.
* Dil **cihaz** bazlidir, kullanici bazli degil: ayni kisinin iki cihazi
  farkli dilde olabilir; gonderim dile gore gruplanir.
* Kullanici uygulama dilini degistirince istemci cihazi YENIDEN kaydeder
  (idempotent upsert). Yapilmazsa bildirimler eski dilde gelmeye devam eder.
* Kalici kayda **cumle yazilmaz**: yazan kisinin dili sonsuza kadar
  sabitlenirdi. `mesaj` kolonu (NOT NULL) deprecated olarak ayni yapisal
  veriden uretilir; eski satirlarda kimlik NULL'dur ve metin aynen doner.

## `/activity` satirlari: METIN degil KIMLIK (tur 15)

13 SQL kaynagi `baslik`/`alt_metin` alanlarini TURKCE uretiyordu
("Kargo Teslim Edildi", `'Daire ' || u.no || ' — ₺' || to_char(...)`). Istemci
onlari aynen gosterdigi icin Arapca arayuzde de Turkce goruntuleniyordu.

Artik her satir sunlari tasir:

| Alan | Anlam |
|---|---|
| `tur` | olay turu (ikon/renk secimi) |
| `baslik_kimlik` | basligin YERELLESTIRILEBILIR kimligi — `tur`den ayridir: `talep` -> `talep_acik`/`talep_is_emri`/`talep_cozuldu`/`talep_reddedildi`, `alarm` -> tipine gore 3 kimlik |
| `veri` (jsonb) | satirin DEGISKEN kismi: `daire`, `firma`, `plaka`, `tutar_kurus`, `kategori` (kimlik), `plan`+`baslangic`+`bitis`, `ad`, `baslik`, `konum`, `tanim` |

**Kurallar**

* SQL cumle KURMAZ; `jsonb_build_object` ile alanlari ayri ayri gonderir.
* `jsonb_strip_nulls`: opsiyonel alan **null olarak degil, hic** gonderilmez —
  bicimi alanin varligi belirler (eski `COALESCE(' — Daire ' || u.no, '')`
  mantiginin istemci karsiligi).
* **Para** `tutar_kurus` TAM SAYIDIR; sunucu `to_char` ile bicimlemez.
  **Zaman** ISO-8601 UTC gider. Ikisi de dile/saat dilimine baglidir.
* `kategori` gorunen ad degil **sozlesme kimligidir**; adi istemci cozer.
* Alarm satirinin alt metni artik `notification.mesaj` (scheduler'in Turkce
  cumlesi) DEGIL, plan adi + pencere sinirlaridir.

`baslik`/`alt_metin` alanlari **DEPRECATED** olarak duruyor: guncellenmemis
istemciler bozulmasin diye ayni metin `app/akis_metinleri.py` icinde YAPISAL
VERIDEN uretilir (SQL'e cumle geri sizmaz). O modul **tek dillidir** ve
bilincli olarak boyledir — 7 dile cevirmek mobil ARB'nin ikinci bir kopyasini
ve kayma riskini yaratirdi. Tum istemciler gecince modul de alanlar da
silinecek.

Kilit: `tests/test_activity.py` (kimlik/veri sozlesmesi + eski alanlarin ayni
metni uretmesi) ve mobil `test/akis_kimlik_i18n_test.dart`.

**Istemciler:** mobil her istege `Accept-Language` ekler
(`core/network/dil_interceptor.dart`; deger **cihaz** dili degil, uygulamanin
o an cizdigi dil). Admin panel tek dillidir ve `tr` gonderir. Baslik
gonderilmezse Turkce doner — eski istemciler etkilenmez.

## Seed (ornek veri)

Gelistirme/test icin **idempotent** seed (`scripts/seed.py`). Olusturur:

| Kayit | Deger |
|-------|-------|
| tenant | `slug=acme-plaza`, `ad=Acme Plaza`, `tz=Europe/Istanbul` |
| admin | `admin@acme.com` / `Admin123!` (rol: admin — platform admini, panel) |
| yonetici | `yonetici@acme.com` / `Yonetici123!` (rol: yonetici — site yoneticisi, mobil) |
| security | `guard@acme.com` / `Guard123!` (rol: security) |
| tesis_gorevlisi | `cleaner@acme.com` / `Clean123!` (rol: tesis_gorevlisi) |
| resident | `resident@acme.com` / `Resident123!` (rol: resident) |

**Mobil giris telefonladir** (`POST /auth/login-phone`; e-posta + `tenant_slug`
YALNIZ panelde). Telefonlar global benzersizdir:

| Rol | Telefon | Parola |
|---|---|---|
| admin | `+905321112200` | `Admin123!` |
| yonetici (birincil) | `+905321112201` | `Yonetici123!` |
| security | `+905321112202` | `Guard123!` |
| resident | `+905321112203` | `Resident123!` |
| tesis_gorevlisi | `+905321112204` | `Clean123!` |
| resident-3 | `+905321112205` | `Resident123!` |
| resident-es | `+905321112206` | *(gecici kod — parola belirlemeden)* |
| yonetici-2 | `+905321112207` | `Yonetici123!` |

**RLS:** Yeni tenant olusturmak app_rw ile mumkun olmadigindan (RLS WITH CHECK),
seed **OWNER** baglantisi (`OWNER_DSN`) ile calisir — migrate servisiyle ayni
yetki. UPSERT (`ON CONFLICT DO UPDATE`) ile tekrar tekrar guvenle calisir;
ikinci kosumda hata vermez, hesaplari bilinen dev durumuna (parola dahil) ceker.
Parolalar `SEED_ADMIN_PASSWORD` / `SEED_YONETICI_PASSWORD` / `SEED_GUARD_PASSWORD` /
`SEED_CLEANER_PASSWORD` / `SEED_RESIDENT_PASSWORD`
env'leri ile override edilebilir.

**Seed gorselleri (MinIO).** Gorselli kayitlar (yaklasan etkinlikler + bir site
kurali) icin seed kucuk birer PNG uretir ve MinIO'ya **EN-IYI-CABA** yukler;
foto_key her zaman yazilir, yukleme basarisiz olursa seed durmaz (`[seed] UYARI
gorsel yuklenemedi ...` basar, yalnizca gorsel gorunmez). api/seed
konteynerindeki `MINIO_ENDPOINT` presign icin PUBLIC adrestir; seed IC agdan
yazdigi icin ayri degisken kullanir: `MINIO_SEED_ENDPOINT`
(varsayilan `http://minio:9000`).

**Kamera seed'i gercek PUBLIC test yayinlaridir** (oynatma gercekten denenebilir):
5 kayit — 3 `hls` + 1 `mp4` + 1 `rtsp`; `sakin_gorebilir=true` yalniz "Ana Kapı"
ve "Otopark"ta, "Servis Girişi" ise `aktif=false` (bayrak acik olsa da sakin
GORMEZ). Yani `GET /cameras` -> admin/yonetici/security 5, resident/
tesis_gorevlisi 2 kayit dondurur; `rtsp` kaydinda `oynatilabilir=false`.

Calistirma (api ayaktayken — tek komut):
```bash
docker compose exec api python -m scripts.seed
# alternatif (api kapaliyken, profilli servis):
docker compose --profile seed run --rm seed
```

Seed sonrasi login + /me:
```bash
TOKEN=$(curl -s localhost:8000/auth/login -H 'content-type: application/json' \
  -d '{"tenant_slug":"acme-plaza","email":"admin@acme.com","password":"Admin123!"}' \
  | python -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
curl -s localhost:8000/me -H "Authorization: Bearer $TOKEN"

# RBAC: security rolu admin-only ucta 403 almali
GTOKEN=$(curl -s localhost:8000/auth/login -H 'content-type: application/json' \
  -d '{"tenant_slug":"acme-plaza","email":"guard@acme.com","password":"Guard123!"}' \
  | python -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/admin/overview \
  -H "Authorization: Bearer $GTOKEN"   # -> 403
```

## Tenant baglami kullanimi

```python
from app.db import tenant_session

async with tenant_session(tenant_id) as session:
    # bu blokta yalnizca tenant_id'ye ait satirlar gorunur (RLS)
    ...
```

`app/db.py`:
- `get_session` — tenant'siz, transaction'li session (orn. /health, auth).
- `get_tenant_session_dep(tenant_id)` — tenant-kapsamli FastAPI dependency
  uretici (Prompt 2'de token'dan gelecek).
- `tenant_session(tenant_id)` — worker/servis icin context manager.

## Push (FCM) — gercek kimligi acma

`FcmProvider` (`app/push.py`) gercek FCM HTTP v1 + OAuth2 kosar; **varsayilan
`PUSH_PROVIDER=noop`** oldugundan test/CI hicbir zaman gercek push atmaz.

1. Kimlik dosyasi: `infra/secrets/fcm-service-account.json` (**.gitignore'da;
   icerigi asla loglanmaz/yazdirilmaz — yalniz dosya YOLU kullanilir**).
2. `.env`'e `PUSH_PROVIDER=fcm` yaz.
3. Kimlik mount'lu kaldir (opsiyonel override — ana compose secrets'siz de calisir):
   `docker compose -f docker-compose.yml -f docker-compose.push.yml up -d`
4. **Duman testi** (Google'dan GERCEK OAuth2 token alir; push ATMAZ, token'i
   YAZDIRMAZ): `... exec api python -m scripts.push_smoke`
   → `token alindi, project=tesis-platform, expiry=...`

Teknik: OAuth2 icin **google-auth kullanilmadi** — service account JWT'si PyJWT
(RS256, cryptography backend) ile imzalanip `token_uri`'ye httpx ile POST edilir;
ucu de zaten bagimlilikta, HTTP katmani mock'lanabilir kaliyor (`_http_post_form`
/ `_fetch_token_response`). Token, expiry'ye 60 sn kala yenilenen module-ici
onbellekte tutulur. Dosya yok/bozuk → `push_unconfigured` (no-op + log, COKME
YOK). **Gercek uctan uca push cihaz testinde** (fiziksel cihaz + mobil build).

## Sinirlar (DEV-A)

- Sadece `/backend` ve `/infra`. `/mobile`, `/admin-web`'e dokunulmaz.
- `/contracts` salt-okunur. Sema degisikligi gerekiyorsa kod yazmadan once
  contract sahibine danisilir.
