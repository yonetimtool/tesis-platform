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

## Sinirlar (DEV-A)

- Sadece `/backend` ve `/infra`. `/mobile`, `/admin-web`'e dokunulmaz.
- `/contracts` salt-okunur. Sema degisikligi gerekiyorsa kod yazmadan once
  contract sahibine danisilir.
