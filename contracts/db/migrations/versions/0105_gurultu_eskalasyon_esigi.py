"""(P213 §1) GURULTU ESKALASYON ESIGI — yonetici ayari.

===========================================================================
NEDEN YENI BIR SUTUN
===========================================================================
P212 §3 eskalasyonu getirdi ama "kacinci esik asimindan sonra guvenlige
haber verilir" KOD SABITIYDI (`asama >= 2`). Bir sitede ikinci uyari,
otekinde ucuncu uyari dogru olabilir: bina yogunlugu, guvenlik ekibinin
buyuklugu ve komsuluk iliskisi tesise gore degisir. Sabit birakmak, her
degisikligi destek talebine cevirirdi (P34/P37'de ayni gerekce).

ANLAM: `gurultu_eskalasyon_esigi = N` -> N. esik asimindan SONRAKI her
asimda guvenlige gider. Varsayilan 1: ikinci 5'te eskalasyon (P212'nin
bugunku davranisi AYNEN korunur).

ARALIK 1..10 (CHECK): 0 "her uyarida guvenligi cagir" demek olurdu ve
birinci esigin anlamini silerdi; 10'un uzeri pratikte "hic cagirma"dir
ve onu ifade etmenin dogru yolu ayri bir kapali/acik anahtaridir, buyuk
bir sayi degil.

GERI ALINABILIR: `downgrade` sutunu ve kisiti dusurur.
"""
from alembic import op
import sqlalchemy as sa

revision = "0105_gurultu_eskalasyon_esigi"
down_revision = "0104_gurultu_eskalasyon"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tenant",
        sa.Column("gurultu_eskalasyon_esigi", sa.Integer(), nullable=False,
                  server_default=sa.text("1")),
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_gurultu_eskalasyon "
        "CHECK (gurultu_eskalasyon_esigi BETWEEN 1 AND 10);"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_gurultu_eskalasyon;"
    )
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS gurultu_eskalasyon_esigi;")
