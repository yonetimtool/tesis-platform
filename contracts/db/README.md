# /contracts/db — DB Semasi & RLS

PostgreSQL semasinin tek dogruluk kaynagi. Alembic migration olarak yonetilir.

## Yapi

```
db/
├── alembic.ini
├── README.md
└── migrations/
    ├── env.py
    ├── script.py.mako
    └── versions/
        └── 0001_initial_schema.py
```

## Calistirma

```bash
cd contracts/db
export DATABASE_URL="postgresql+psycopg://owner:***@localhost:5432/tesis"
alembic upgrade head      # uygula
alembic downgrade base    # geri al
```

> `psycopg` (v3) surucusu varsayilir. Backend `psycopg2` kullaniyorsa URL'i
> `postgresql+psycopg2://...` yapin; sema ayni.

## Roller ve RLS — onemli

- Migration'i **owner/superuser** ile calistirin. Bu rol RLS'i **bypass eder**;
  bu yuzden migration ve bakim islemleri politikalardan etkilenmez.
- Migration, dusuk-yetkili **`app_rw`** rolunu olusturur (NOLOGIN). Backend bu
  role login yetkisi ekleyip onunla baglanmali:
  ```sql
  ALTER ROLE app_rw WITH LOGIN PASSWORD '***';
  ```
  `app_rw` RLS'e **tabidir** (BYPASSRLS yok), boylece tenant izolasyonu garanti.

## Her istekte tenant baglami

Backend, baglanti/islem basinda tenant'i oturuma yazar:
```sql
SET app.current_tenant_id = '7b3f...uuid';   -- veya SET LOCAL (tx kapsaminda)
```
RLS politikalari `current_setting('app.current_tenant_id', true)::uuid` ile
karsilastirir. Degisken **set edilmezse** politika hicbir satir dondurmez
(guvenli varsayilan — kazara tum-tenant erisimi olmaz).

> Connection pool kullaniliyorsa `SET LOCAL` (transaction kapsamli) tercih edin
> ki baglanti havuzda baska tenant'a sizmasin.

## Tablolar (ozet)

| Tablo | Amac |
|-------|------|
| `tenant` | Kiraci. Izolasyon `id` uzerinden (tenant_id yok). |
| `app_user` | Kullanicilar; `role` enum, `email` tenant-ici benzersiz. |
| `shift` | Gun-ici vardiya sablonu (`time`). |
| `checkpoint` | NFC noktasi; `nfc_tag_uid` tenant-ici benzersiz. |
| `patrol_plan` | Devriye sablonu (gun-ici saat + `periyot_dakika`). |
| `patrol_plan_checkpoint` | Plan ↔ checkpoint, sirali. |
| `patrol_window` | Scheduler'in urettigi somut UTC pencere + `durum`. |
| `scan_event` | Mobilin tur kaniti; `(tenant_id, idempotency_key)` benzersiz. |

Tum tenant-kapsamli tablolarda RLS `ENABLE` + `FORCE`. Cross-tenant FK'ler
composite `(id, tenant_id)` ile engellenir. Detayli kararlar: `../README.md`.
