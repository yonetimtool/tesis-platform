"""(P181 Bölüm 10.2) notification_tip enum'una 'vardiya_ozeti'

Devriye okutmaları tek tek push üretmez; vardiya BİTTİĞİNDE tek özet
("X/Y nokta okutuldu") yönetime gider (batching). Bu özet bildiriminin tipi.
Diğer değerlerden AYRI: gerçek-zamanlı alarm değil, vardiya sonu RAPORU.

Revision ID: 0073_vardiya_ozeti_bildirim
Revises: 0072_notification_silindi_at
Create Date: 2026-08-27
"""
from alembic import op

revision = "0073_vardiya_ozeti_bildirim"
down_revision = "0072_notification_silindi_at"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # PG16: ADD VALUE bu tx'te KULLANILMIYOR (yalnız ekleniyor) -> güvenli.
    # IF NOT EXISTS -> idempotent. Değer SONA eklenir (models.py aynası).
    op.execute("ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'vardiya_ozeti'")


def downgrade() -> None:
    # PG enum değeri düşürülemez; zararsız kalır.
    pass
