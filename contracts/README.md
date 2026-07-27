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

**`message` YERELLESTIRILMISTIR (7 dil), `code` DEGILDIR.** Istemci mantigi
**daima `code`** (ve HTTP durumu) ile kurulur; `message` yalniz gosterilir.
Metin `Accept-Language` basligina gore uretilir — icerik cevirisiyle **ayni**
zincir (RFC 9110, bolge eki duser, ilk desteklenen dil kazanir, yoksa `tr`).

```http
GET /units/<id>
Accept-Language: ar, tr;q=0.8
→ 401 { "error": { "code": "unauthorized", "message": "المصادقة مطلوبة." } }
```

- Baslik gonderilmezse **Turkce** doner (mevcut istemciler etkilenmez).
- `error.details[].message` alan duzeyinde **teknik** metindir (dogrulama
  kutuphanesinin kendi ciktisi, Ingilizce) — kullaniciya ham gosterilmez.
- Sunucu yapilandirma hatalari (`storage_unconfigured`, `config_error`,
  `payment_unconfigured`, `payment_provider_error`, `webhook_unsupported`)
  **cevrilmez**: operatore hitap eder. Katalog ve gerekce:
  `backend/app/hata_metinleri.py`.

### Uretilen metin — KIMLIK kurali

Sunucu kullaniciya gosterilecek **cumle uretmez**; kimlik + veri gonderir ve
metni istemci kendi dilinde kurar. Bugunku uygulamalari:

| Alan | Kimlik kanali | Veri kanali |
|---|---|---|
| Hata zarfi | `error.code` (+ sunucu `message`'i **cevrilmis** doner, tur 14) | — |
| `/activity` satiri | `baslik_kimlik` (tur 15) | `veri` (daire, firma, plaka, `tutar_kurus`, kategori kimligi...) |
| Durum/kategori alanlari | enum degeri (`durum`, `kategori`, `tip`) | — |

Bicimleme de istemcidedir: **para** `*_kurus` TAM SAYI olarak gider (sunucu
"₺1.250,00" yazmaz), **zaman** ISO-8601 UTC gider (yerel saat/12-24 saat
karari istemcinin). Sunucu bicimlerse dil ve saat dilimi sessizce yanlis olur.

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
- `announcement`: duyuru (yonetimden tum tesise). Gonderme/duzenleme/silme
  **admin + yonetici**; okuma **tum roller** (resident dahil). Olusturan composite FK
  (`app_user`, ON DELETE RESTRICT); liste `created_at DESC`. Olusturmada tenant'in tum
  aktif cihazlarina push denenir (EK gonderim — hatasi kaydi etkilemez).
- `task` / `task_completion`: esnek gorev sistemi (tip: temizlik/kontrol/ilaclama/
  bakim/diger). Task CRUD admin/yonetici; tamamlama (`POST /tasks/{id}/completions`) tesis_gorevlisi+
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
  yonetimi admin/yonetici (Task CRUD), tamamlama gonderme tesis_gorevlisi/security/admin,
  takvim okuma + yonetici.
- `asset` / `asset_checkout`: demirbas envanteri + zimmet (al/birak, NFC). `asset.nfc_tag_uid`
  tenant icinde benzersiz (partial unique, NULL haric). `asset.durum` (musait/zimmetli/bakimda).
  **Tek aktif zimmet**: bir asset icin en fazla bir acik checkout → partial unique
  `(tenant_id, asset_id) WHERE birakma_zamani IS NULL`. Idempotency: alma `UNIQUE(tenant_id,
  idempotency_key)`, birakma `UNIQUE(tenant_id, birakma_idempotency_key)` (partial). FK'ler
  composite. Asset CRUD admin; checkout/checkin tesis_gorevlisi/security/admin; goruntuleme/history + yonetici. checkout →
  durum 'zimmetli', checkin → 'musait'.
- **Yonetim maili:** ayri tablo YOK — `tenant.yonetim_email` (tek alan, nullable;
  kisisel veya ortak olabilir — anlamsal kisit yok). Admin tesis acarken girer
  (`POST /tenants`), `PATCH /tenant/settings` (admin) ile degistirir. `GET
  /tenant/settings` (TUM roller) ve `GET /yonetici-iletisim` (tenant'in her
  uyesi) ile okunur.
- **Birincil yonetici:** `app_user.birincil boolean NOT NULL DEFAULT false`.
  Tenant olusturulurken verilen ILK yonetici `true` alir. `uq_app_user_birincil`
  **kismi unique index** (`ON app_user (tenant_id) WHERE birincil`) tenant basina
  EN FAZLA BIR birincil'i YAPISAL olarak garanti eder (`birincil=false` satirlar
  kisitlanmaz). Tesisi ilk giriste adlandirma kapisi (`POST /tenant/setup`)
  YALNIZ birincil'e acilir; `tenant_detail` fonksiyonu da tekil yonetici olarak
  birincil'i doner. Bireysel kullanici silme ucu olmadigindan "birincil silinince
  terfi" senaryosu yoktur; pasiflestirme bayragi degistirmez.
- `checkpoint.nfc_tag_uid` tenant icinde benzersiz (NFC eslemesi).
- `patrol_plan` gun-ici sablon; `patrol_window` scheduler'in urettigi somut
  UTC pencere. `scan_event` mobilin gonderdigi tur kaniti.
- `scan_event.patrol_window_id` **nullable** — ad-hoc okutmalar plan disi olabilir.
- Index'ler: her tabloda `tenant_id`, tum FK kolonlari, `scan_event(okutma_zamani)`,
  `patrol_window(durum, pencere_baslangic)` (dashboard/scheduler sorgulari icin).

## Rol modeli — ozet

`admin` (PLATFORM admini: tum CRUD + panel — panel YALNIZ admin), `yonetici`
(site yoneticisi — musteri: mobil; gorev atama/takip, devriye/rapor okuma,
demirbas goruntuleme, tesisi yeniden adlandirma; kendi tenant'iyla sinirli),
`security` &
`tesis_gorevlisi` (saha: tanim okur, scan gonderir; tesis_gorevlisi = eski
`cleaning`, temizlik+bahcivan+teknik birlesik), `resident` (v0'da operasyon
erisimi yok). Tam matris: `auth.md` §4.

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
- **Erisim:** Unit/tahakkuk/odeme YAZMA yalniz **admin**; `yonetici` aidat raporlarini okur;
  `security/tesis_gorevlisi` aidat gormez;
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

- **GERCEK KIMLIK BAGLANDI.** `FcmProvider` (backend/app/push.py) gercek FCM HTTP v1
  akisini kosar: service account (dosyadan, read-only mount) -> OAuth2 access token
  (RS256 JWT + jwt-bearer grant; PyJWT+cryptography+httpx — google-auth YOK, uc
  bagimlilik da zaten mevcut) -> `POST /v1/projects/{project_id}/messages:send`.
  Token expiry'ye 60 sn kala onbellekten yenilenir. HTTP + OAuth katmani hala
  mock'lanabilir (`_http_post_json` / `_http_post_form` / `_fetch_token_response`)
  — testler GERCEK kimliksiz, mock'la kosar.
- **Kimlik dosyasi:** `infra/secrets/fcm-service-account.json` (**.gitignore'da —
  ASLA repoya girmez; icerigi loglanmaz**). Container'a baglama OPSIYONEL override
  ile: `docker compose -f docker-compose.yml -f docker-compose.push.yml up -d`
  (api+worker'a `/run/secrets/fcm-sa.json:ro`). Ana compose secrets'siz her
  ortamda ayakta kalir. Dosya yok/bozuk -> **`push_unconfigured`** (no-op + log;
  cokme yok). `project_id` dosyadan okunur (`FCM_PROJECT_ID` istege bagli override).
- Saglayici secimi `PUSH_PROVIDER = noop | fcm` (varsayilan **noop**; `.env` ile
  acilir) — odeme (`PAYMENT_PROVIDER`) deseninin AYNISI. `get_push_provider()`.
- **Duman testi** (push atmaz, yalniz kimligi dogrular; token yazdirilmaz):
  `... exec api python -m scripts.push_smoke` -> "token alindi, project=..., expiry=...".
  **Gercek uctan uca push cihaz testinde** (fiziksel cihaz + mobil build gerekir).
- **Cihaz token kaydi:** `POST /devices` (her rol, kendi cihazi; idempotent upsert,
  `UNIQUE(tenant_id, fcm_token)`), `DELETE /devices/{fcm_token}` (pasiflestir), `GET /devices`
  (admin, debug). Yeni tablo **`user_device`** (RLS + tenant-izole).
- **Kanca:** `scheduler/notify.py::dispatch_external` in-app notification'in YANINA push tetikler
  (kacirilan tur -> admin+security cihazlari). Push in-app bildirimi
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

## Mobil ana ekran sozlesme bosluklari kapatildi (G1–G7)

Mobil ekibin 3-rol ana ekran raporundaki 7 bosluk. Bu turda **2 yeni tablo**
(`vehicle_pass`, `violation`) + **2 yeni kolon** (`tenant.otopark_kapasite`,
`visitor.cikis_zamani`) eklendi — canonical migration `0001_initial_schema.py`
YERINDE guncellendi (yeni migration dosyasi uretilmedi; `down -v` ile yeniden
uygulanir). Yeni tablolar tenant-kapsamli + RLS `ENABLE`+`FORCE`.

| # | Bosluk | Nasil kapandi |
|---|--------|---------------|
| G1 | Arac plaka/gecis kaydi yok | `vehicle_pass` + `POST /vehicle-passes` (giris), `POST /vehicle-passes/{id}/checkout`, `GET /vehicle-passes?acik=&plaka=`. Plaka NORMALIZE (bosluksuz+BUYUK, `norm_plaka`); ayni plakadan tek ACIK gecis (kismi unique indeks → 409). RBAC admin+security |
| G2 | Ihlal kaydi yok (site_kurali yalniz metin) | `violation` + `POST /violations` (admin+security), `GET /violations?durum=`, `PATCH /violations/{id}`. `yeni → inceleniyor → kapatildi`; **kapatma yalniz admin**, `kapatildi` TERMINAL (409) |
| G3 | Ziyaretci "icerde" turetilemiyor | `visitor.cikis_zamani` (nullable) + `POST /visitors/{id}/checkout` (409 cift damga) + `GET /visitors?icerde=true` |
| G4 | Otopark kapasite/doluluk yok | `tenant.otopark_kapasite` (`PATCH /tenant/settings`; admin **veya** yonetici) + `GET /parking/occupancy` → `{kapasite, dolu, oran}`. `dolu` = ACIK gecis sayimi (ayri sayac YOK); kapasite tanimsiz/0 → `kapasite`+`oran` **null** |
| G5 | Akis istemcide 3–4 istekten birlestiriliyor | `GET /activity?limit=&cursor=` — 13 kaynagi SUNUCUDA birlestirir/siralar/rol'e gore suzer. Bilesik imlec (`zaman`,`id`) — `offset` ve `meta.total` YOK. **Satirlar METIN degil KIMLIK tasir** (`baslik_kimlik` + `veri`); cumleyi istemci kendi dilinde kurar (tur 15) |
| G6 | `/unit-complaints/mine`'da kategori suzgeci yok | `?kategori=` eklendi (`/unit-complaints` genel listesine de) |
| G7 | `/weather` + `/cameras` canlida var, sozlesmede yok | `openapi.yaml`'a **davranis degistirilmeden** geri-dolduruldu (uygulama denetlenip gercek istek/yanit sekilleri yazildi) |

Geriye uyumluluk: iki kolon da nullable; yeni alanlar/filtreler/uclar **additive**
— mevcut istemciler etkilenmez. Mobil ekibin taslagindan bilincli sapmalar:

- **G1 tek-satir gecis modeli** (`giris_zamani` + nullable `cikis_zamani`),
  taslaktaki `yon: giris|cikis` iki-satir modeli DEGIL. Iki-satirda doluluk
  "eslesmemis girisleri bul" sorgusuna doner (plaka basina son-olay penceresi;
  yaris-acik, indekslemesi pahali); tek-satirda doluluk kismi indeksli tek
  `COUNT` ve "ayni plakadan tek acik gecis" DB kisitiyla garanti.
- **G1 RBAC'te `resident` yok.** Taslak "sakin kendi dairesinin araci" diyordu;
  plaka PII'ye baglandigi ve gecisi kaydeden/okuyanin kapi operasyonu oldugu
  icin liste admin+security'de birakildi. Sakinin ekraninda zaten arac karti yok.
- **G4 alan adi `oran`** (taslakta `doluluk_yuzde`) ve `guncellenme` alani yok —
  deger her istekte canli sayimdir, ayri damga yaniltici olurdu.
- **G5'te `admin`/`yonetici` ziyaretci+kargo olaylarini GORMEZ.** Bu uclar
  yonetime VARSAYILAN KAPALI'dir ve tek-seferlik izinle acilir; birlesik akis
  o kapiyi bypass eden bir yan kanal olmamalidir (KVKK). `duyuru` turu de
  akisa alinmadi (duyuru bir olay degil, kalici icerik — `/announcements`).
- **G5 sayfalama offset degil imlec.** Taslak `offset`+`total` istiyordu; araya
  yeni kayit girince offset sayfayi kaydirip olay TEKRARLATIR, ve 13 kaynagin
  birlesik `total`'i her istekte tam tarama demektir.

## Kamera yonetimi + gorunurluk, etkinlik gorseli, sakin ana ekran icerigi (WP-H)

Bu turda kamera "basit yayin listesi"nden **yonetilen varlik**a yukseltildi,
etkinliklere **gorsel + bitis zamani** eklendi ve sakin ana ekraninin uc icerik
listesi (duyuru / kural / yaklasan etkinlik) uctan uca dogrulandi.

**Sema** (canonical migration YERINDE guncellendi; yeni dosya uretilmedi —
`down -v` ile yeniden uygulanir):

| Tablo | Degisiklik | Migration |
|---|---|---|
| `camera` | `+konum`, `+tur camera_tur('hls','mp4','rtsp')`, `+aktif`, `+sakin_gorebilir`, `+ix_camera_tenant_gorunur` | `0005_home_gorsel.py` (tablonun canonical tanimi orada) |
| `etkinlik` | `+bitis_zamani` (nullable, `ck_etkinlik_bitis` CHECK), `+foto_key`, `+ix_etkinlik_tenant_bitis` | `0001_initial_schema.py` |

**Kamera gorunurlugu (KVKK) — suzgec SUNUCUDA:**

| rol | gordugu kameralar |
|---|---|
| admin, yonetici, security | TUMU (pasif + sakine kapali dahil); `?aktif=` ile suzebilir |
| resident, tesis_gorevlisi | YALNIZ `aktif=true` **VE** `sakin_gorebilir=true` |

`sakin_gorebilir` varsayilani **false**'tur; `?aktif=` parametresi sakin/gorevli
icin YOK SAYILIR (istemci suzgeci genisletemez). Gizli kameranin `stream_url`'i
ve hatta `meta.total` sayimi bu rollerin yanitina HIC girmez.

**Oynatilabilirlik:** yanittaki `oynatilabilir` alani turden TURER (saklanmaz) —
`hls`/`mp4` → true, `rtsp` → **false**. RTSP kaydi kabul edilir ve saklanir
(envanter/ileride medya gecidi) ama istemci natively oynatamaz; UI oynat
dugmesini bu alanla pasifler.

**Etkinlik "yaklasan" suzgeci:** `GET /events?aktif=true` →
`COALESCE(bitis_zamani, tarih) >= now()`, siralama en YAKIN once. `aktif=false`
bitmisleri (en yeni once), suzgecsiz liste eskisi gibi tumu (en yeni once).
`bitis_zamani` NULL ise etkinlik ANLIKTIR (bitis = baslangic).

**Gorsel mekanizmasi TEK:** etkinlik gorseli `POST /uploads/presign` →
`foto_key` → okumada kisa omurlu presigned GET `foto_url`; duyuru, site kurali,
talep ve gorev tamamlama ile AYNI depo, ayni tur/boyut limitleri, ayni
tenant-namespace IDOR kontrolu (yabanci onek → 422 `invalid_foto_key`).

Bilincli sapmalar (istek metnine gore):

- **`stream_url` alani `url` olarak YENIDEN ADLANDIRILMADI.** Istek "url"
  diyordu; alan adini degistirmek yayindaki mobil istemciyi (Camera modeli
  `stream_url` okur) kirar ve karsiliginda hicbir sey kazandirmaz. Yanit sekli
  bu yuzden **geriye uyumlu**: yalniz alan EKLENDI (`konum`, `tur`, `aktif`,
  `sakin_gorebilir`, `oynatilabilir`), hicbir alan kaldirilmadi/adlandirilmadi.
- **URL semasi `tur` ile TUTARLI olmak zorunda** (`hls`/`mp4` → `http(s)://`,
  `rtsp` → `rtsp://`; aksi 422 `invalid_stream_url`). Istek "url http(s) olmali
  ama rtsp turu kabul edilir" diyordu; `tur=rtsp` kaydina http(s) URL yazmak
  calismayan bir kayit uretirdi (RTSP yayinlari `rtsp://`dir). PATCH'te
  tutarlilik MEVCUT kayitla birlestirilerek dogrulanir (yalniz `tur`
  gonderilse bile). SSRF yuzeyi degismedi — backend yayini HIC cekmez.
- **resident + tesis_gorevlisi artik `GET /cameras`'ta 403 DEGIL 200 alir.**
  Onceki kural "kamera listesi bile kapali"ydi; gorunurluk artik kayit bazinda
  ve varsayilan KAPALI oldugu icin mevcut kayitlarin gorunurlugu DEGISMEZ.
- **Etkinlige `bitis_zamani` EKLENDI** (istek "bitis yoksa baslangica gore
  suz" diyordu). Bitis olmadan 20:00–23:00 arasi SUREN etkinlik 20:01'de
  listeden duserdi; nullable kolon + `COALESCE` hem dogru davranisi verir hem
  eski kayitlari (bitis NULL) aynen korur.
- **Site kurali gorseli YENIDEN YAZILMADI:** `site_kurali.foto_key` +
  `foto_url` zaten vardi (uygulama + sozlesme + test). Bu turda yalniz
  dogrulandi ve seed'e gorselli bir kural eklendi.

Geriye uyumluluk: tum kolonlar nullable ya da `DEFAULT`'lu; yeni alanlar,
filtreler ve `oynatilabilir` **additive** — mevcut istemciler etkilenmez.

## Icerik cevirisi — yayin icerigi 7 dilde (Accept-Language)

Yonetimin yazdigi **yayin icerigi** (duyuru / site kurali / etkinlik) sakinin
kendi dilinde okunur. Mimari kararlar (baglayici):

| Karar | Deger |
|---|---|
| Ne zaman cevrilir | **YAZMA** aninda (kayit sonrasi kuyruk); okuma cevirmez |
| Kac dil | 7: `tr` (kaynak/varsayilan) + `en`, `ar`, `ru`, `de`, `fr`, `es` |
| Saklama | Entity basina yan tablo: `announcement_ceviri`, `site_kurali_ceviri`, `etkinlik_ceviri` (migration 0007; RLS ENABLE+FORCE, composite FK + CASCADE) |
| Cevrilen alanlar | duyuru `baslik`+`govde`, kural `baslik`+`icerik`, etkinlik `baslik`+`aciklama` |
| CEVRILMEYEN | `konum` (yer adi), `foto_key`/`foto_url`, tarih/sira/sayilar |
| Motor | **Kendi barindirdigimiz LibreTranslate** (compose ic agi; icerik dis servise GITMEZ) |
| Orijinal | **Her zaman korunur** ve her yanitta `orijinal` alaninda doner |

### Okuma sozlesmesi

`Accept-Language` (RFC 9110; `tr-TR,tr;q=0.9,en;q=0.8`) ile dil secilir. Bolge
eki duser, q'ya gore ilk **desteklenen** dil kazanir. **Geri-dusme zinciri:**
`?dil=` → Accept-Language → icerigin orijinal dili. Desteklenmeyen dil **400
URETMEZ** — orijinale duser (icerik her zaman okunabilir). `?dil=orijinal`
kaynak dili zorlar.

Yanit alanlari (`CeviriAlanlari`, openapi.yaml): `orijinal_dil`,
`gosterilen_dil`, `ceviri_durumu` (`hazir`|`bekliyor`|`hata`), `cevirildi_mi`,
`orijinal`.

**Ceviri hazir degilse ORIJINAL metin servis edilir** ve `ceviri_durumu`
gercegi soyler; istemci "çeviri hazırlanıyor" gosterebilir ama metin alanlari
**asla bos kalmaz**.

### Elle duzeltme kurali (tek cumle)

Yonetici bir dildeki ceviriyi duzeltirse (`elle_duzeltildi=true`), bu duzeltme
**yalnizca kaynak metin degismedikce korunur**. Ilgisiz bir alan (gorsel,
tarih, sira) duzenlenirse duzeltme kalir; kaynak **metin** degisirse duzeltme
artik yanlis metnin duzeltmesi oldugu icin gecersizdir ve yeniden cevrilir.
Anahtar: her ceviri satirinda kaynak metnin ozeti (`kaynak_hash`) tutulur.

### Basarisizlik ilkesi

Ceviri **EK** bir islemdir: saglayici ya da kuyruk erisilemez olsa bile icerik
kaydi **BASARILI** olur (POST/PATCH 2xx). Basarisiz diller `durum='hata'`
isaretlenir ve orijinal metin servis edilmeye devam eder.

### Yapilandirma

`TRANSLATE_PROVIDER` = `libretranslate` (kod varsayilani) | `echo`
(deterministik sahte — **dev/test varsayilani**, model indirmesi/CPU gerekmez) |
`noop`. `TRANSLATE_URL` ic ag adresidir (operator ayari; kullanici girdisi
olmadigi icin SSRF kapisindan gecmez).

## API base path

- **Base path YOK** (`/v0` kaldirildi). Tum endpoint'ler host:port kokunden sunulur:
  `/auth/login`, `/scans`, `/tasks`, `/assets`, `/dashboard/live`,
  `/notifications`, `/tenant/settings`, `/yonetici-iletisim` ... Yerel: `http://localhost:8000`.
  (Onceki `openapi.yaml` `servers` girdileri yanlislikla `/v0` iceriyordu; gercek backend
  ile hizalamak icin kaldirildi.)

## Degisiklik politikasi

- Sozlesme degisikligi **once burada** yapilir, PR ile gozden gecirilir, sonra
  backend/mobil/panel uyarlanir.
- Kirici degisiklikler (breaking) yeni surumle (`/v1`) ele alinir; `openapi.yaml`
  `info.version` ve `servers` guncellenir.
