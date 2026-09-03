"""(P207 §2) `app_user.bildirim_sesi` — SESLI UYARI TERCIHI.

===========================================================================
NEDEN AYRI BIR TERCIH
===========================================================================
`bildirim_mobil` (goc 0055) "push GELSIN mi" sorusunu yanitlar. Ses ise
BASKA bir soru: bildirim gelsin ama SESSIZ gelsin. Ikisini tek bayrakla
yonetmek, "gece caliyor" diyen kullaniciya bildirimin TAMAMINI
kapattirirdi — ve o kullanici ertesi gun vardiyasini da kacirirdi.

===========================================================================
NEDEN SUNUCUDA (CIHAZDA DEGIL)
===========================================================================
Android'de bildirimin sesi KANALIN ozelligidir ve kanal olusturulduktan
sonra uygulama onu degistiremez. Yani "sesi kapat" istemcide
uygulanamaz; sunucunun BASKA BIR KANALA gondermesi gerekir. Tercih bu
yuzden sunucuda durur ve gonderim aninda okunur.

VARSAYILAN TRUE: bugune kadar sesli olmasi beklenen bildirimler sessiz
geliyordu; varsayilani false yapmak, kusuru "ayar" diye kalici hale
getirmek olurdu.
"""
from alembic import op
import sqlalchemy as sa

revision = "0100_bildirim_sesi"
down_revision = "0099_vardiya_kalibi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "app_user",
        sa.Column("bildirim_sesi", sa.Boolean(), nullable=False,
                  server_default=sa.text("true")),
    )


def downgrade() -> None:
    op.drop_column("app_user", "bildirim_sesi")
