"""(P187) idle_in_transaction_session_timeout — bağlantı sızıntısı savunması

Prod'da 90/100 bağlantı "idle in transaction" durumunda takıldı: bir kod yolu
(kök neden: Celery'nin `asyncio.run`-per-görev deseni; asyncpg bağlantıları
ölü event loop'a bağlı kalıyordu — `app/tasks.py`'de dispose ile düzeltildi)
işlem açıp kapatmadan bağlantıyı bırakabiliyor ve slot geri dönmüyordu.

Bu göç ROL SEVİYESİNDE ikinci bir savunma koyar: `app_rw`/`app_ro` rolüyle açılan
HER bağlantı, bir transaction'ı `idle_in_transaction_session_timeout` (60 sn)
süresince BOŞTA (sorgu çalıştırmadan) tutarsa PostgreSQL oturumu sonlandırır ve
slotu geri verir. Böylece bir sızıntı olsa bile havuz kendini iyileştirir.

60 sn seçildi: normal istek ms sürer; en uzun meşru boşluk davetin senkron
SMTP/SMS çağrısıdır (~18 sn) ve bunun rahatça altındadır. `app/db.py` engine
`connect_args` ile aynı değeri async engine'e ayrıca uygular (kemer + askı);
bu göç sync psycopg bağlantılarını da (scheduler/retention/notify) kapsar.

Revision ID: 0074_idle_in_transaction_timeout
Revises: 0073_vardiya_ozeti_bildirim
Create Date: 2026-08-28
"""
from alembic import op

revision = "0074_idle_in_transaction_timeout"
down_revision = "0073_vardiya_ozeti_bildirim"
branch_labels = None
depends_on = None

# Uygulama/işçi bağlantı rolleri. `owner` (superuser) KASITLI DIŞARIDA: retention
# gibi uzun ama AKTIF (sorgu çalıştıran) işlemleri idle_in_transaction saymaz,
# yine de superuser oturum ayarına dokunmamayı tercih ediyoruz.
#
# ROL VARSA-ALTER: `app_ro` her ortamda oluşturulmuyor (dev'de yok). Var olmayan
# role ALTER 'role does not exist' ile göçü düşürürdü; koşullu DO bloğu göçü
# ortamdan bağımsız kılar.
_ROLLER = ("app_rw", "app_ro")
_TIMEOUT = "60s"


def upgrade() -> None:
    for rol in _ROLLER:
        op.execute(
            f"""
            DO $$
            BEGIN
              IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{rol}') THEN
                ALTER ROLE {rol} SET idle_in_transaction_session_timeout = '{_TIMEOUT}';
              END IF;
            END $$;
            """
        )


def downgrade() -> None:
    for rol in _ROLLER:
        op.execute(
            f"""
            DO $$
            BEGIN
              IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{rol}') THEN
                ALTER ROLE {rol} RESET idle_in_transaction_session_timeout;
              END IF;
            END $$;
            """
        )
