"""(P219 §2) SIKAYET HARITASINDA GORUNME SURESI.

===========================================================================
NEDEN
===========================================================================
Sikayetler haritada SURESIZ kaliyordu: alti ay once cozulmus bir gurultu
sikayeti, dun gece gelenle ayni kirmizi noktayi uretiyordu. Harita
"su anda nerede sorun var" sorusunu yanitlamasi gerekirken "hic olmus
mu" sorusunu yanitliyordu ve zamanla her daire kirmiziya donuyordu.

===========================================================================
BU BIR GORUNURLUK FILTRESI, VERI SILME DEGIL
===========================================================================
Sikayet SILINMEZ. Kayit yerinde durur; yalnizca HARITADA gosterilmez:
  * esik sayaclari (P208/P209/P212) BU FILTREDEN ETKILENMEZ — onlarin
    kendi penceresi var (`gurultu_pencere_gun`, varsayilan 30 gun),
  * raporlar, denetim kaydi ve sikayet listeleri DEGISMEZ,
  * sakinin kendi sikayetleri DEGISMEZ.

Iki sure KARISTIRILMAMALI ve arayuzde ayri ayri anlatiliyor:
  `gurultu_pencere_gun`   -> kac gun geriye SAYILIR   (eşik mantigi)
  `sikayet_harita_saat`   -> kac saat HARITADA DURUR  (gorunurluk)

===========================================================================
`0` = SURESIZ GOSTER
===========================================================================
Kapatilabilir olmali: haftada bir sikayet gelen kucuk bir sitede 24
saatlik pencere haritayi surekli bos gosterir ve harita islevini
yitirir. `0` degeri urunun baska yerlerinde de "sinirsiz" anlaminda
kullaniliyor (`gurultu_pencere_gun`, `rezervasyon_gecmis_ay`) — ayni
kavrama ayni degeri vermek, yoneticinin ogrenmesi gereken kural
sayisini artirmiyor.

VARSAYILAN 24 SAAT: brief'in istegi.

GERI ALINABILIR: `downgrade` sutunu dusurur, harita eski (suresiz)
davranisina doner.
"""
from alembic import op
import sqlalchemy as sa

revision = "0112_sikayet_harita_saat"
down_revision = "0111_eskalasyon_esigi_anlami"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tenant",
        sa.Column("sikayet_harita_saat", sa.Integer(), nullable=False,
                  server_default=sa.text("24")),
    )


def downgrade() -> None:
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS sikayet_harita_saat;")
