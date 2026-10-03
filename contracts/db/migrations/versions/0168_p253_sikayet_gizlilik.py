"""(P253 §D) Sikayet gizliligi — kaynak daire + "asilsiz" isareti.

* `unit_complaint.kaynak_unit_id`: sikayetin GELDIGI daire. Esik artik
  KISI degil FARKLI KAYNAK DAIRE sayar (bir kisinin 5 sikayeti esigi
  dolduramaz). Kimlik degildir: yonetime yine DONMEZ, yalniz sayilir.
  Eski satirlar sikayet edenin aktif dairesinden doldurulur (hedefin
  blogundaki ilk daire; yoksa herhangi biri; hic yoksa NULL — sayimda
  kisinin kendisi kaynak sayilir).
* `asilsiz_at` / `asilsiz_gerekce` / `asilsiz_isaretleyen`: yonetimin
  "asilsiz" karari. Sikayet edenle GIZLICE iliskilenir (satir zaten
  `complainant_user_id` tasir); yonetim KIMIN oldugunu ogrenmez.
* Sinirlama sorgulari icin (tenant, sikayet eden, zaman) indeksi.
* `notification_tip`: `sikayet_asilsiz`, `sikayet_sinirlama`.
"""
from alembic import op

revision = "0168_p253_sikayet_gizlilik"
down_revision = "0167_p252_personel_maas"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE unit_complaint "
        "ADD COLUMN kaynak_unit_id uuid, "
        "ADD COLUMN asilsiz_at timestamptz, "
        "ADD COLUMN asilsiz_gerekce text, "
        "ADD COLUMN asilsiz_isaretleyen uuid, "
        "ADD CONSTRAINT ck_unit_complaint_asilsiz CHECK ("
        "(asilsiz_at IS NULL AND asilsiz_gerekce IS NULL) OR "
        "(asilsiz_at IS NOT NULL AND length(btrim(asilsiz_gerekce)) > 0));"
    )
    op.execute(
        """
        UPDATE unit_complaint uc SET kaynak_unit_id = (
            SELECT ur.unit_id
            FROM unit_resident ur
            JOIN unit u ON u.id = ur.unit_id
            JOIN unit hedef ON hedef.id = uc.target_unit_id
            WHERE ur.user_id = uc.complainant_user_id
              AND ur.tenant_id = uc.tenant_id
            ORDER BY (ur.bitis IS NOT NULL),
                     (u.blok IS DISTINCT FROM hedef.blok),
                     ur.unit_id
            LIMIT 1
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_unit_complaint_kaynak_zaman ON unit_complaint "
        "(tenant_id, complainant_user_id, created_at);"
    )
    for tip in ("sikayet_asilsiz", "sikayet_sinirlama"):
        op.execute(f"ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS '{tip}';")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_unit_complaint_kaynak_zaman;")
    op.execute(
        "ALTER TABLE unit_complaint "
        "DROP CONSTRAINT IF EXISTS ck_unit_complaint_asilsiz, "
        "DROP COLUMN IF EXISTS asilsiz_isaretleyen, "
        "DROP COLUMN IF EXISTS asilsiz_gerekce, "
        "DROP COLUMN IF EXISTS asilsiz_at, "
        "DROP COLUMN IF EXISTS kaynak_unit_id;"
    )
    # notification_tip degerleri GERI ALINMAZ (goc 0131/0140/0144 emsali).
