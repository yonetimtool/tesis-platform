"""(P192 §2) Ekstre bir BANKA HESABINA aittir — bank_transaction.kasa_id

===========================================================================
NEDEN
===========================================================================
P191'de banka eşleştirmesi defter satırını `kasa_id=NULL` ile yazıyordu.
Sonuç ölçüldü ve `docs/finans-analiz.md`de raporlandı: o para HİÇBİR kasa
bakiyesinde görünmüyor ama özet kartındaki genel toplamda sayılıyordu —
kasa toplamları genel toplamla TUTMUYORDU.

P192 §1 bunu "varsayılan banka hesabı" ile kapattı; bu göç doğru yere
taşıyor: **bir ekstre hangi hesabın ekstresiyse, o hesaba yazılmalı.**
Bir tesisin birden çok banka hesabı olabilir (site hesabı + demirbaş
hesabı) ve ikisinin ekstresini aynı kasaya yazmak, iki hesabın bakiyesini
tek bir sayıya karıştırmak olurdu.

NULLABLE ve öyle kalmalı: alanı göndermeyen mevcut çağrılar (panel, test)
çalışmaya devam eder ve hedef hesap varsayılan banka hesabına düşer.

===========================================================================
KASA SİLİNEMEZ HÂLE GELMEZ
===========================================================================
FK `ON DELETE SET NULL`: bir kasa kapatılırsa geçmiş ekstre satırları
kaybolmamalı. `RESTRICT` olsaydı kullanılmış bir kasa hiç silinemezdi ve
kullanıcı bunu ancak silmeye çalışınca öğrenirdi.

Revision ID: 0084_banka_hesabi_ve_onay
Revises: 0083_tek_defter
Create Date: 2026-08-31
"""
from alembic import op

revision = "0084_banka_hesabi_ve_onay"
down_revision = "0083_tek_defter"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE bank_transaction ADD COLUMN kasa_id uuid;")
    op.execute(
        """
        ALTER TABLE bank_transaction
          ADD CONSTRAINT fk_bank_tx_kasa
          FOREIGN KEY (kasa_id, tenant_id)
          REFERENCES kasa (id, tenant_id) ON DELETE SET NULL;
        """
    )
    # FK'nin BAS SUTUNU indekssiz kalmasin (P191 goc 0081 ile ayni kural):
    # kasa silinirken tam tarama yapmasin.
    op.execute(
        "CREATE INDEX ix_bank_tx_kasa ON bank_transaction (kasa_id, tenant_id) "
        "WHERE kasa_id IS NOT NULL;"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_bank_tx_kasa;")
    op.execute(
        "ALTER TABLE bank_transaction DROP CONSTRAINT IF EXISTS fk_bank_tx_kasa;"
    )
    op.execute("ALTER TABLE bank_transaction DROP COLUMN IF EXISTS kasa_id;")
