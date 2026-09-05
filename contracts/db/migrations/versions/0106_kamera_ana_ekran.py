"""(P213 §4) KAMERA ANA EKRANDA GORUNSUN MU.

===========================================================================
NEDEN AYRI BIR BAYRAK
===========================================================================
Kareler artik kameralar sayfasinda degil ANA EKRANDA (web: Ozet, mobil:
ana ekran alti) gosteriliyor. "Hangi kameralar?" sorusunun yaniti
`sakin_gorebilir` OLAMAZ: o gorunurluk (YETKI) sorusudur — "sakin bu
kamerayi gorebilir mi". Ana ekran ise YERLESIM sorusudur — "bu kamera
ozetin ust bandinda dursun mu". Ikisini tek bayrakla yonetmek, otopark
kamerasini sakinlere acan yoneticinin ozetini de otomatik doldururdu.

===========================================================================
VARSAYILAN `false` — VE NEDEN
===========================================================================
Varsayilan `true` olsaydi, 20 kamerali bir sitede ozet acilir acilmaz 20
ffmpeg sureci baslardi (her kare AYRI bir cekim). Sunucu yukunu
kullanicinin HIC ISTEMEDIGI bir varsayilana baglamak dogru degil.
Yonetici hangi kameralari one cikaracagini SECER; hicbiri secilmemisse
ana ekranda kamera bandi CIZILMEZ (bos bir kutu degil, hic yok).

Ust sinir UYGULAMADA (`KAMERA_ANA_EKRAN_SINIR`, varsayilan 4): sema
kisiti yapmak, siniri degistirmek icin goc gerektirirdi.

GERI ALINABILIR: `downgrade` sutunu dusurur.
"""
from alembic import op
import sqlalchemy as sa

revision = "0106_kamera_ana_ekran"
down_revision = "0105_gurultu_eskalasyon_esigi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "camera",
        sa.Column("ana_ekranda", sa.Boolean(), nullable=False,
                  server_default=sa.text("false")),
    )


def downgrade() -> None:
    op.execute("ALTER TABLE camera DROP COLUMN IF EXISTS ana_ekranda;")
