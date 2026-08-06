"""(P147) Sakine ozel bildirim satiri: `notification.user_id` + yeni tipler.

NEDEN: `notification` tablosu YONETIM ALARMLARI icin tasarlanmisti — satirda
alici YOK, tablo tenant kapsamli ve `GET /notifications` sakine kapaliydi.
Sakinin gordugu olaylar (kargo geldi, talebiniz cozuldu) yalnizca ANLIK push
olarak gidiyordu: bildirimi o an kaciran kullanici icin geriye HICBIR kayit
kalmiyordu.

`user_id` NULL BIRAKILABILIR ve bu bilinclidir: NULL = "tesise ait yonetim
alarmi" (bugunku butun satirlar boyle), dolu = "su kisiye ait olay". Boylece
mevcut satirlarin anlami DEGISMEZ ve okuma yolu ikisini ayirabilir.

Yeni tipler: sakinin kendi olaylarinin geri donusu. Metinleri `push_metinleri`
icinde ZATEN 7 dilde var (kargo/ziyaretci/rezervasyon); `sikayet_cozuldu`
bu turda eklendi.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "0035_sakin_bildirimleri"
down_revision = "0034_talep_geri_alma"
branch_labels = None
depends_on = None

_YENI_TIPLER = ("kargo", "ziyaretci", "rezervasyon", "sikayet_cozuldu")


def upgrade() -> None:
    for tip in _YENI_TIPLER:
        op.execute(f"ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS '{tip}';")
    op.add_column(
        "notification",
        sa.Column("user_id", UUID(as_uuid=True), nullable=True),
    )
    # Kismi indeks: sakinin listesi HER ZAMAN user_id + created_at uzerinden
    # okunur. NULL satirlar (yonetim alarmlari) indekste yer kaplamasin.
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_notification_user_created
            ON notification (tenant_id, user_id, created_at DESC)
            WHERE user_id IS NOT NULL;
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_notification_user_created;")
    op.drop_column("notification", "user_id")
    # Enum degerleri BIRAKILIR: PostgreSQL enum'dan deger silmeyi
    # desteklemez ve yeni deger eski satirlari bozmaz.
