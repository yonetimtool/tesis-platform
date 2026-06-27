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
