"""(P250 §7) Otomatik aidat hatirlatmasina E-POSTA kanali.

P192'nin borc hatirlatmasi yalniz push + uygulama ici bildirim gonderiyordu.
`hatirlatma_ayari.eposta`: e-posta da gitsin mi.

VARSAYILAN ACIK — ama yalniz hatirlatmanin KENDISI aciksa calisir
(`aktif`, varsayilan KAPALI). Yani bu goc hicbir tesiste kendiliginden
e-posta gondermeye baslatmaz: hatirlatmayi bugun acmis bir tesis, ertesi
gece borclulara e-posta da gonderir. Bu bilinclidir — P250'nin istedigi
tam olarak budur — ve dagitim notunda yoneticilere duyurulur.
"""
from alembic import op

revision = "0164_p250_hatirlatma_eposta"
down_revision = "0163_p250_egitim_videolari"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE hatirlatma_ayari ADD COLUMN eposta boolean NOT NULL DEFAULT true;"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE hatirlatma_ayari DROP COLUMN IF EXISTS eposta;")
