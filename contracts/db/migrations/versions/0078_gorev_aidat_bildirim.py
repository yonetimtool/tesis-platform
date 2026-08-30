"""(P191 §2) notification_tip: 'gorev_atandi' + 'aidat_borc'

ÖLÇÜLEN KUSUR: kullanıcı Play'den güncel sürümü kurdu, bir GÖREV oluşturdu
ve hiçbir bildirim gelmedi. İz sürüldüğünde neden basitti — görev
oluşturma/atama yolunda push ÇAĞRISI HİÇ YOKTU (`dispatch_external`
kullanan 12 yolun arasında `tasks.py` bulunmuyordu). Aynı boşluk aidat
borçlandırmasında da vardı.

Bu göç iki yeni bildirim tipini açar; push metinleri
`app/push_metinleri.py`de, tetikleme `routers/tasks.py` ve
`routers/borclandirma_uc.py` içinde.

Revision ID: 0078_gorev_aidat_bildirim
Revises: 0077_push_gonderim
Create Date: 2026-08-30
"""
from alembic import op

revision = "0078_gorev_aidat_bildirim"
down_revision = "0077_push_gonderim"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 0073 ile aynı desen: ADD VALUE aynı tx'te KULLANILMAZ, IF NOT EXISTS
    # ile idempotent, değerler SONA eklenir (models.py birebir aynası).
    op.execute("ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'gorev_atandi'")
    op.execute("ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'aidat_borc'")


def downgrade() -> None:
    # PG enum değeri düşürülemez; zararsız kalır (0073 kararı).
    pass
