"""(P247-bekleyen 1.2) DAIRE NOTLARI SAHA PERSONELINE VARSAYILAN KAPALI.

OLCULEN: daire ekleri (`varlik_eki`, `varlik_tipi='unit'`) daireyi okuyan
her role acikti — guvenlik ve tesis gorevlisi dahil. Yoneticinin daireye
yazdigi not borc, anlasmazlik ya da sakin hakkinda kisisel degerlendirme
olabilir.

KARAR (kullanici): "saha personeli gorebilir" isareti.
  * Varsayilan KAPALI.
  * Goc aninda MEVCUT TUM SATIRLAR KAPALI: hicbir eski not goc aninda
    sahaya acilmaz. `DEFAULT false` + NOT NULL eklemek mevcut satirlari
    false ile doldurur; asagidaki UPDATE, kolon onceden (yarim bir
    denemede) eklenmis olsa bile ayni sonucu garanti eder.
  * Isareti yalniz yonetim koyar/kaldirir (uc tarafi).

Goc `app.*` ithal ETMEZ (dondurulmus kopya kurali).
"""
from alembic import op

revision = "0155_p247_ek_saha"
down_revision = "0154_p247_vardiya_dongu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE varlik_eki ADD COLUMN IF NOT EXISTS saha_gorebilir "
        "boolean NOT NULL DEFAULT false;"
    )
    op.execute("UPDATE varlik_eki SET saha_gorebilir = false WHERE saha_gorebilir;")


def downgrade() -> None:
    op.execute("ALTER TABLE varlik_eki DROP COLUMN IF EXISTS saha_gorebilir;")
