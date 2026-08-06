"""(P146) Talep/sikayet GERI ALMA — iki durum enum'una 'geri_alindi'.

NEDEN YENI BIR DURUM (silme DEGIL): sakin kendi actigi talebi/sikayeti geri
cekebilmeli, ama kayit YOK OLMAMALI. Silmek, yonetimin gordugu bir kaydin
izsiz kaybolmasi demektir; audit ve timeline'in anlami kalmaz. Geri alma
BIR GECISTIR: kayit durur, kimin ne zaman geri aldigi history'de gorunur.

NEDEN YALNIZ `acik`tan: talep is emrine donusmusse sahada is baslamis
olabilir; onu geri almak yetim bir gorev birakir. Gecis tablosu bunu
`ticketing.VALID_TRANSITIONS` icinde de ayni sekilde kisitlar.

`IF NOT EXISTS`: goc iki kez kosulursa (dev/prod tekrarlari) patlamasin.
"""
from alembic import op

revision = "0034_talep_geri_alma"
down_revision = "0033_tanitim_iletisim"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE complaint_durum ADD VALUE IF NOT EXISTS 'geri_alindi';")
    op.execute(
        "ALTER TYPE unit_complaint_durum ADD VALUE IF NOT EXISTS 'geri_alindi';"
    )


def downgrade() -> None:
    # PostgreSQL enum'dan DEGER SILMEYI desteklemez. Geri alis, tipi yeniden
    # yaratip butun kullanan sutunlari tasimayi gerektirir — veri kaybi
    # riski tasir ve bu goc icin GEREKSIZDIR (yeni deger eskiyi bozmaz).
    pass
