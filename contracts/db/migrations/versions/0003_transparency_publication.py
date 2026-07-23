"""transparency_publication — Seffaflik Panosu aylik yayin durumu (0003).

Yonetici, ay-bazli ANONIM finansal ozeti sakinlere YAYINLAR. Bu tablo YALNIZ
yayin durumunu (tenant + ay + yayin bool) tutar; finansal ozet server-side
hesaplanir ve KISISEL VERI (ad/daire/bireysel tutar) TUTMAZ.

URETIM: additive + geriye-uyumlu; 0001/0002 uzerine ILERI-YONLU (yeni tablo;
mevcut veriye dokunmaz). Dev `down -v` ile geri alinabilir.
"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "0003_transparency_publication"
down_revision = "0002_audit_log"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE transparency_publication (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ay         text NOT NULL,                 -- 'YYYY-MM'
            yayin      boolean NOT NULL DEFAULT false,
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_transparency_tenant_ay UNIQUE (tenant_id, ay)
        );
        """
    )
    # RLS: tenant-kapsamli (diger tablolarla ayni desen).
    op.execute("ALTER TABLE transparency_publication ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE transparency_publication FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY transparency_publication_isolation ON transparency_publication
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    # app_rw tam DML (append-only DEGIL; yonetici ac/kapa yapabilir).
    op.execute(
        "GRANT SELECT, INSERT, UPDATE, DELETE ON transparency_publication "
        f"TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS transparency_publication;")
