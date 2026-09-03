"""(P207 §3) VARDIYA HATIRLATMA AYARLARI — tenant basina.

===========================================================================
NEDEN AYAR
===========================================================================
"Kac dakika once hatirlat" sorusunun TEK dogru yaniti yok: site
guvenliginde 15 dakika makul, kampus buyuklugunde bir tesiste personel
yola cikmis olmali — 30 dakika gerekir. Urun kurali yapmak, ikisinden
birini yanlis yapmak demekti (`tur_gecikme_toleransi_dk` ile ayni sinif).

`vardiya_hatirlatma_dk`: VIRGULLE AYRILMIS kademe listesi ("30,5" gibi).
Neden metin: kademe SAYISI degisken (bir ya da uc) ve ayri bir tablo
acmak, iki satirlik bir ayari yonetmek icin CRUD ekrani gerektirirdi.
Dogrulama uygulamada (`hatirlatma_kademeleri`); bos ya da gecersiz metin
KAPALI demektir.

`vardiya_baslamadi_dk`: vardiya BASLADIKTAN sonra bu kadar dakika icinde
personelden hicbir okutma gelmezse yoneticiye uyari. GECIKMIS DEVRIYE
ALARMINDAN FARKLI (P34): o, acilmis bir turun gec kalmasidir; bu,
vardiyaya HIC BASLAMAMA durumudur. 0 = kapali.
"""
from alembic import op
import sqlalchemy as sa

revision = "0101_vardiya_hatirlatma"
down_revision = "0100_bildirim_sesi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tenant",
        sa.Column("vardiya_hatirlatma_dk", sa.Text(), nullable=False,
                  server_default=sa.text("'15'")),
    )
    op.add_column(
        "tenant",
        sa.Column("vardiya_baslamadi_dk", sa.Integer(), nullable=False,
                  server_default=sa.text("15")),
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_vardiya_baslamadi "
        "CHECK (vardiya_baslamadi_dk BETWEEN 0 AND 180);"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_vardiya_baslamadi;"
    )
    op.drop_column("tenant", "vardiya_baslamadi_dk")
    op.drop_column("tenant", "vardiya_hatirlatma_dk")
