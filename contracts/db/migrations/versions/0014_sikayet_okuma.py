"""sikayet_okuma (0014) — YONETICI BASINA sikayet okuma durumu.

MASTER-PLAN P24: sikayet yonetim gorunumu "Yeni / Okunmamis" sekmesi kazanir
ve okuma durumu KISI BASINADIR — iki yonetici ayni siteye bakarken birinin
okumasi digerinin kuyrugunu bosaltmamalidir.

TASARIM — WATERMARK DEGIL SATIR BASINA KAYIT:
"Son okuma zamani" (watermark) tek satirla cozulurdu ama sekmeyi acmak
HEPSINI okundu yapardi; triyajda kullanici bes sikayetten ikisini ele alip
gerisini kuyrukta BIRAKMAK ister. Bu yuzden (sikayet, kullanici) ciftine
satir yazilir. Buyume kaygisi yok: yonetici sayisi site basina birkac kisidir.

Okunmamis = bu kullanici icin SATIRI OLMAYAN sikayet (LEFT JOIN ... IS NULL).
Boylece yeni gelen sikayet dogal olarak okunmamistir; ek yazma gerekmez.

Sikayet silinirse okuma kaydi da gider (CASCADE); kullanici silinirse de
(app_user CASCADE) — yetim satir kalmaz.

Revision ID: 0014_sikayet_okuma
Revises: 0013_goruntu_kirliligi
"""
from __future__ import annotations

from alembic import op

revision = "0014_sikayet_okuma"
down_revision = "0013_goruntu_kirliligi"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE unit_complaint_okuma (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id         uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            unit_complaint_id uuid NOT NULL,
            user_id           uuid NOT NULL,
            okundu_at         timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_unit_complaint_okuma
                UNIQUE (tenant_id, unit_complaint_id, user_id),
            FOREIGN KEY (unit_complaint_id, tenant_id)
                REFERENCES unit_complaint (id, tenant_id) ON DELETE CASCADE,
            FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    # Okunmamis sorgusu: "bu kullanicinin okuduklari" ile LEFT JOIN.
    op.execute(
        "CREATE INDEX ix_unit_complaint_okuma_user "
        "ON unit_complaint_okuma (tenant_id, user_id);"
    )
    op.execute("ALTER TABLE unit_complaint_okuma ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE unit_complaint_okuma FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY unit_complaint_okuma_isolation ON unit_complaint_okuma
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON unit_complaint_okuma TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS unit_complaint_okuma;")
