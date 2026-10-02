"""(P251 §5b) Rezervasyon alanina ISTEGE BAGLI gorsel.

Duyuru, etkinlik ve site kurali gorsel tasiyordu; ortak alan (havuz,
teras, toplanti odasi) tasimiyordu — sakin rezerve edecegi yeri adindan
tahmin etmek zorundaydi. Ayni mekanizma: `/uploads/presign` ile yuklenen
nesnenin anahtari (`<tenant>/...`); okumada kisa omurlu imzali adres.
"""
from alembic import op

revision = "0165_p251_ortak_alan_gorsel"
down_revision = "0164_p250_hatirlatma_eposta"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE ortak_alan ADD COLUMN foto_key text;")


def downgrade() -> None:
    op.execute("ALTER TABLE ortak_alan DROP COLUMN IF EXISTS foto_key;")
