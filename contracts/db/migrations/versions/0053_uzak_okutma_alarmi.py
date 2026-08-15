"""(P160) Uzak okutma alarmi — `notification_tip`e yeni deger.

===========================================================================
NEDEN YENI BIR TIP
===========================================================================
`0052` okutma mesafe esigini bir tesis ayari yapti ama esik yalnizca
PANEL HARITASINI etkiliyordu: yonetici "esigi koydum, artik uyari alirim"
bekliyordu ve YANILIYORDU. Bu goc o boslugu kapatir.

Mevcut alarmlarin hicbiri bu olayi anlatamaz:
  * `kacirilan_tur`      — pencere bitti, tur yapilmadi,
  * `eksik_checkpoint`   — nokta hic okutulmadi,
  * `gecikmis_okutma`    — pencere acik, okutma gecikti.
Uzak okutma bunlarin hicbiri DEGIL: okutma YAPILDI, zamaninda YAPILDI,
ama noktadan uzakta yapildi. Var olan bir tipe bindirmek, iki farkli
olayi ayni satirda toplamak ve panelin gruplamasini bozmak olurdu.

===========================================================================
DOWNGRADE NEDEN BOS
===========================================================================
PostgreSQL enum'dan DEGER SILMEYI desteklemez; geri alis tipi yeniden
yaratip butun kullanan sutunlari tasimayi gerektirir ve veri kaybi riski
tasir. Yeni deger eskiyi BOZMAZ (0034'teki ayni karar).

`IF NOT EXISTS`: goc iki kez kosulursa (dev/prod tekrarlari) patlamasin.
"""
from alembic import op

revision = "0053_uzak_okutma_alarmi"
down_revision = "0052_okutma_mesafe_esigi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'uzak_okutma';"
    )


def downgrade() -> None:
    # PostgreSQL enum'dan deger silmeyi desteklemez — bkz. dosya basi.
    pass
