"""(P243 §4) WEB GORUNUM MODU — standart / buyuk.

===========================================================================
NEDEN HESAPTA, CIHAZDA DEGIL
===========================================================================
`ui_tema` ile AYNI gerekce (goc 0076): gozu iyi gormeyen bir yonetici
ofisteki bilgisayarda da evdeki dizustunde de BUYUK gormek ister.
Cihazda saklamak, her yeni tarayicida ayari yeniden bulmasi demekti.

MOBILDEKI AYARLA AYNI KAVRAM (P230): "Standart / Buyuk". Kullanici iki
yuzeyde iki farkli sey ogrenmesin — mobil tarafta deger cihazda duruyor
cunku orada hesap TEK cihaza bagli kullaniliyor; kavram ve etiketler
ayni.
"""
from alembic import op

revision = "0147_web_gorunum_modu"
down_revision = "0146_panik_kategori"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE app_user ADD COLUMN IF NOT EXISTS ui_gorunum text "
        "NOT NULL DEFAULT 'standart';"
    )
    # CHECK — `ui_tema` ile ayni desen: gecersiz bir deger arayuzde
    # SESSIZCE standarda duserdi ve kullanici ayarinin uygulanmadigini
    # sanirdi.
    op.execute(
        "ALTER TABLE app_user ADD CONSTRAINT ck_app_user_ui_gorunum "
        "CHECK (ui_gorunum IN ('standart', 'buyuk'));"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE app_user DROP CONSTRAINT IF EXISTS ck_app_user_ui_gorunum;"
    )
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS ui_gorunum;")
