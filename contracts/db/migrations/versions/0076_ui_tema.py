"""(P190 §5) app_user.ui_tema — tema tercihi HESAPTA saklanır

Web tema tercihi yalnız localStorage'daydı: cihaz/tarayıcı değişince
kayboluyordu. Tercih artık kullanıcı hesabında durur (system|light|dark);
web açılışta hesaptakiyle senkronlar, başka tarayıcıda da aynı tema gelir.

CHECK kısıtı: serbest metin bırakmak, yazım hatalı bir değerin sessizce
"system"e düşmesi (ya da istemciyi şaşırtması) demekti.

Revision ID: 0076_ui_tema
Revises: 0075_davet_vazgecti
Create Date: 2026-08-29
"""
import sqlalchemy as sa
from alembic import op

revision = "0076_ui_tema"
down_revision = "0075_davet_vazgecti"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "app_user",
        sa.Column(
            "ui_tema",
            sa.Text(),
            nullable=False,
            server_default=sa.text("'system'"),
        ),
    )
    op.create_check_constraint(
        "ck_app_user_ui_tema",
        "app_user",
        "ui_tema IN ('system','light','dark')",
    )


def downgrade() -> None:
    op.drop_constraint("ck_app_user_ui_tema", "app_user", type_="check")
    op.drop_column("app_user", "ui_tema")
