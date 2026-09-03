"""(P207 §3) `notification_tip` ENUM'una VARDIYA HATIRLATMA + BASLAMADI.

===========================================================================
NEDEN ENUM'A EKLENIYOR
===========================================================================
In-app bildirim satiri `notification.tip` ile yazilir ve tip bir ENUM.
Eklemezsek zamanlayici INSERT'te patlar — ve bu, beat gorevinin SESSIZCE
hicbir sey yapmamasi olarak gorunurdu (gorev hatasi loga duser, kullanici
"hatirlatma gelmiyor" der).

IKI AYRI TIP, TEK DEGIL:
  * `vardiya_hatirlatma` PERSONELE gider ("vardiyaniza 15 dakika"),
  * `vardiya_baslamadi` YONETIME gider ("gelmedi").
Tek tipe indirmek, bildirim listesinde ikisini ayirt edilemez yapardi ve
kullanici "benim vardiyam mi baslamadi" diye okurdu.
"""
from alembic import op

revision = "0102_bildirim_tipi_vardiya"
down_revision = "0101_vardiya_hatirlatma"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ADD VALUE IF NOT EXISTS: goc iki kez kosarsa (kismi basarisizlik)
    # patlamasin.
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'vardiya_hatirlatma';"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'vardiya_baslamadi';"
    )


def downgrade() -> None:
    # POSTGRES ENUM DEGERI SILEMEZ (DROP VALUE yok). Geri donus, tipi
    # yeniden yaratip tabloyu donusturmeyi gerektirir; bu, o degerleri
    # TASIYAN satirlarin da silinmesi demektir. Bilincli olarak NO-OP:
    # fazladan bir enum degeri hicbir seyi bozmaz, veri kaybi bozar.
    pass
