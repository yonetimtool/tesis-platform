"""odeme_kodu (0020) — MASTER-PLAN P30: havale aciklama kodu.

Sakin banka havalesiyle oderken aciklamaya BENZERSIZ bir kod yazar; yonetim
ekstreyi yukleyince (P29) bu kod ESLESTIRMEYI KESINLESTIRIR.

NEDEN AYRI SUTUN, TURETME DEGIL: kod `unit_no + kisa id` gibi turetilseydi
daire numarasi degisince (P23'te oluyor) kod da degisir ve sakinin bankada
kayitli duzenli talimati SESSIZCE eslesmez olurdu. Kod bir kez uretilir ve
SABIT KALIR.

BICIM `TS-XXXXXX` (6 karakter, karistirilabilir harfler CIKARILMIS):
kullanici kodu ELLE yazacak ve `0/O`, `1/I/l` ayrimi telefonda okunmaz.

TENANT ICINDE BENZERSIZ (global degil): iki sitede ayni kod olabilir cunku
eslestirme zaten tenant kapsaminda calisir; global benzersizlik alfabeyi
gereksizce tuketirdi.

Revision ID: 0020_odeme_kodu
Revises: 0019_finansal_hareket
"""
from __future__ import annotations

from alembic import op

revision = "0020_odeme_kodu"
down_revision = "0019_finansal_hareket"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE app_user ADD COLUMN odeme_kodu text NULL;")
    op.execute(
        "ALTER TABLE app_user ADD CONSTRAINT uq_app_user_tenant_odeme_kodu "
        "UNIQUE (tenant_id, odeme_kodu);"
    )
    op.execute(
        "ALTER TABLE app_user ADD CONSTRAINT ck_app_user_odeme_kodu "
        "CHECK (odeme_kodu IS NULL OR odeme_kodu ~ '^TS-[A-Z2-9]{6}$');"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE app_user DROP CONSTRAINT IF EXISTS ck_app_user_odeme_kodu;"
    )
    op.execute(
        "ALTER TABLE app_user DROP CONSTRAINT IF EXISTS uq_app_user_tenant_odeme_kodu;"
    )
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS odeme_kodu;")
