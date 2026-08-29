"""(P190) app_user.davet_vazgecti — davet e-postası List-Unsubscribe (RFC 8058)

Davet e-postasına RFC 8058 List-Unsubscribe (+ List-Unsubscribe-Post) başlığı
eklendi (Gmail'de olumlu spam sinyali). Tek-tık iptali onurlandırmak için bir
BASTIRMA bayrağı gerekir: kişi iptal ederse o e-postaya bir daha davet
gönderilmez (yönetici yeniden gönderse bile atlanır ve panelde görünür).

Kişi başına tek boolean yeterli (ayrı bastırma tablosu gereksiz); davet zaten
tek bir app_user'a bağlı.

Revision ID: 0075_davet_vazgecti
Revises: 0074_idle_in_transaction_timeout
Create Date: 2026-08-29
"""
import sqlalchemy as sa
from alembic import op

revision = "0075_davet_vazgecti"
down_revision = "0074_idle_in_transaction_timeout"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "app_user",
        sa.Column(
            "davet_vazgecti",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("app_user", "davet_vazgecti")
