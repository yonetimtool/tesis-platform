"""(P253 A2) Toplu tahakkuk partisi + "rapor hazir" bildirimi.

* `dues_assessment.parti_id`: bir toplu tahakkuk cagrisinin yazdigi
  satirlar AYNI parti kimligini tasir. §C-4 "geri al": parti tek istekte
  ters kayitla geri alinir (`POST /borclandirma/parti/{parti_id}/geri-al`,
  sebep zorunlu). Eski satirlarda NULL — onlar tek tek ters kayitlanir.
* `notification_tip`: `rapor_hazir` — kuyruktaki rapor bitince isteyene.
"""
from alembic import op

revision = "0169_p253_parti_rapor_hazir"
down_revision = "0168_p253_sikayet_gizlilik"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE dues_assessment ADD COLUMN parti_id uuid;")
    op.execute(
        "CREATE INDEX ix_dues_assessment_parti ON dues_assessment (tenant_id, parti_id) "
        "WHERE parti_id IS NOT NULL;"
    )
    op.execute("ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'rapor_hazir';")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_dues_assessment_parti;")
    op.execute("ALTER TABLE dues_assessment DROP COLUMN IF EXISTS parti_id;")
    # notification_tip degeri GERI ALINMAZ (goc 0131/0140/0144 emsali).
