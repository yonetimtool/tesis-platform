"""(P181 Bölüm 6.5) notification.silindi_at — bildirim YUMUŞAK silme

Toplu bildirim işlemleri için yumuşak silme. Sert silme yerine `silindi_at`
zaman damgası: satır kalır (denetim + "yanlışlıkla sildim" kurtarma mümkün),
listede gizlenir. Denetim kaydı ayrıca `audit_log`'a (NOTIFICATION_DELETE) yazılır.

Revision ID: 0072_notification_silindi_at
Revises: 0071_kod_amaci_sifre_sifirla
Create Date: 2026-08-26
"""
import sqlalchemy as sa
from alembic import op

revision = "0072_notification_silindi_at"
down_revision = "0071_kod_amaci_sifre_sifirla"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "notification",
        sa.Column("silindi_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("notification", "silindi_at")
