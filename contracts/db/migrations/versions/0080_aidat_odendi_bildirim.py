"""(P191 §4) notification_tip: 'aidat_odendi'

Banka eşleştirmesi bir ödemeyi işlediğinde sakine "ödemeniz alındı,
makbuzunuz hazır" bildirimi gider. Bu bildirimin tipi.

AYRI DEĞER: `aidat_borc` borcun DOĞDUĞUNU, bu ise KAPANDIĞINI söyler;
ikisini tek tiple yazmak, sakinin bildirim listesinde borç ile ödemeyi
ayırt edememesi demekti.

Revision ID: 0080_aidat_odendi_bildirim
Revises: 0079_banka_entegrasyonu
Create Date: 2026-08-30
"""
from alembic import op

revision = "0080_aidat_odendi_bildirim"
down_revision = "0079_banka_entegrasyonu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'aidat_odendi'")


def downgrade() -> None:
    # PG enum degeri dusurulemez; zararsiz kalir (0073/0078 karari).
    pass
