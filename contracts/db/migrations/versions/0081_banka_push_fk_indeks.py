"""(P191) FK ÖNCÜ-KOLON İNDEKSLERİ — 0077 ve 0079'un eksiği

`test_indeks_kapsam` şu kuralı zorluyor: her yabancı anahtarın ÖNCÜ kolonunu
kapsayan bir indeks olmalı. Gerekçe indeksin okuma hızı değil, SİLMEDİR: üst
satır (örn. bir `app_user`) silindiğinde referans bütünlüğü tetiği bu
tabloları tarar; indeks yoksa seq scan yapar ve kullanıcı silme işlemi
tablolar büyüdükçe yavaşlar.

0077/0079'da (tenant_id, user_id, ...) bileşik indeksleri var ama ÖNCÜ kolon
`tenant_id`; `user_id` FK'si için bu yetmez. Bu göç eksik beşini ekler.

Revision ID: 0081_banka_push_fk_indeks
Revises: 0080_aidat_odendi_bildirim
Create Date: 2026-08-30
"""
from alembic import op

revision = "0081_banka_push_fk_indeks"
down_revision = "0080_aidat_odendi_bildirim"
branch_labels = None
depends_on = None

_INDEKSLER = (
    ("ix_bank_tx_karar_veren", "bank_transaction", "karar_veren_user_id"),
    ("ix_payment_match_karar_veren", "payment_match", "karar_veren_user_id"),
    ("ix_payment_match_user_fk", "payment_match", "user_id"),
    ("ix_push_gonderim_user_fk", "push_gonderim", "user_id"),
    ("ix_receipt_user_fk", "receipt", "user_id"),
)


def upgrade() -> None:
    for ad, tablo, kolon in _INDEKSLER:
        op.execute(f"CREATE INDEX IF NOT EXISTS {ad} ON {tablo} ({kolon});")


def downgrade() -> None:
    for ad, _, _ in _INDEKSLER:
        op.execute(f"DROP INDEX IF EXISTS {ad};")
