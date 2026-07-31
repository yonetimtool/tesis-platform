"""daire_tip_grup (0016) — Bagimsiz Bolum TIPLERI + GRUPLARI.

MASTER-PLAN P26 (ref: docs/design-refs/apsiyon/).

IKI AYRI KAVRAM, BILEREK IKI TABLO:
  * `unit_grup` — bolumun NE OLDUGU (Daire / Villa / Dukkan / Depo). Kucuk,
    yavas degisen bir liste; raporlamada kirilim eksenidir.
  * `unit_tip`  — bolumun BUYUKLUGU/duzeni (1+0, 1+1, 2+1, dubleks…) ve buna
    bagli VARSAYILAN AIDAT TUTARI. Tamamen serbest metindir: kullanici ne
    yazarsa o (sabit bir enum, "1+1,5" ya da "stüdyo" diyen siteyi disarida
    birakirdi).
Tek tabloda birlestirmek ("tip" alani hem Villa hem 2+1 tutsun) her villa x
her tip kombinasyonunu ayri satira zorlardi ve varsayilan aidat tanimi
anlamsizlasirdi.

AIDAT TUTARI KURUS (bigint), TL DEGIL: para birimi ondaliklari `numeric`
ile bile yuvarlanma tartismasi acar; depoda TAM SAYI kurus tutulur (repo
genelindeki `*_kurus` kurali).

UNIT BAGLANTILARI NULLABLE ve ON DELETE SET NULL: tip/grup TANIM'dir, dairenin
varligi ona bagli degildir. Bir tip silinince daireler silinmez, yalniz
siniflandirmasiz kalir (P28 o daire icin varsayilan aidat bulamaz ve site
genel tutarina duser — sessiz bir 0 uretmez).

DIKKAT — `SET NULL (sutun)` SUTUN LISTESI ZORUNLU: FK BILESIKTIR
(`(unit_tip_id, tenant_id)`), ve sutun listesi verilmezse PostgreSQL
ANAHTARIN TAMAMINI null'lar — yani `unit.tenant_id`i de. O sutun NOT NULL
oldugu icin tip silme `NotNullViolation` ile 500 verirdi (testte cikti).
PostgreSQL 15+ `ON DELETE SET NULL (sutun)` sozdizimini destekler; yigin
PG 16'dir.

Revision ID: 0016_daire_tip_grup
Revises: 0015_kamera_url_siniri
"""
from __future__ import annotations

from alembic import op

revision = "0016_daire_tip_grup"
down_revision = "0015_kamera_url_siniri"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def _tanim_tablosu(ad: str, ek: str = "") -> str:
    return f"""
        CREATE TABLE {ad} (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad         text NOT NULL,
            aktif      boolean NOT NULL DEFAULT true,
            {ek}
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_{ad}_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_{ad}_tenant_ad UNIQUE (tenant_id, ad),
            CONSTRAINT ck_{ad}_ad_bos_degil CHECK (btrim(ad) <> ''),
            CONSTRAINT ck_{ad}_ad_uzunluk CHECK (length(ad) <= 60)
        );
    """


def upgrade() -> None:
    op.execute(_tanim_tablosu("unit_grup"))
    op.execute(
        _tanim_tablosu(
            "unit_tip",
            # Varsayilan aidat OPSIYONEL: tipi tanimlayip tutari sonra girmek
            # yaygin bir akistir. NULL "tanimsiz" demektir, 0 DEGIL — 0 gecerli
            # bir tutardir (muaf daire).
            "varsayilan_aidat_kurus bigint NULL "
            "CHECK (varsayilan_aidat_kurus IS NULL "
            "OR varsayilan_aidat_kurus >= 0),",
        )
    )

    for tablo in ("unit_grup", "unit_tip"):
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_isolation ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
        op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON {tablo} TO {APP_ROLE};")

    # --- unit baglantilari ------------------------------------------------- #
    op.execute("ALTER TABLE unit ADD COLUMN unit_tip_id uuid NULL;")
    op.execute("ALTER TABLE unit ADD COLUMN unit_grup_id uuid NULL;")
    # BILESIK FK (id, tenant_id): baska tenant'in tipine baglanmak imkansiz.
    op.execute(
        "ALTER TABLE unit ADD CONSTRAINT fk_unit_tip "
        "FOREIGN KEY (unit_tip_id, tenant_id) "
        "REFERENCES unit_tip (id, tenant_id) ON DELETE SET NULL (unit_tip_id);"
    )
    op.execute(
        "ALTER TABLE unit ADD CONSTRAINT fk_unit_grup "
        "FOREIGN KEY (unit_grup_id, tenant_id) "
        "REFERENCES unit_grup (id, tenant_id) ON DELETE SET NULL (unit_grup_id);"
    )
    # "Bu tipteki daireler" sorgusu (P28 aidat tahakkuku + panel kirilimi).
    op.execute("CREATE INDEX ix_unit_tenant_tip ON unit (tenant_id, unit_tip_id);")
    op.execute("CREATE INDEX ix_unit_tenant_grup ON unit (tenant_id, unit_grup_id);")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_unit_tenant_grup;")
    op.execute("DROP INDEX IF EXISTS ix_unit_tenant_tip;")
    op.execute("ALTER TABLE unit DROP CONSTRAINT IF EXISTS fk_unit_grup;")
    op.execute("ALTER TABLE unit DROP CONSTRAINT IF EXISTS fk_unit_tip;")
    op.execute("ALTER TABLE unit DROP COLUMN IF EXISTS unit_grup_id;")
    op.execute("ALTER TABLE unit DROP COLUMN IF EXISTS unit_tip_id;")
    op.execute("DROP TABLE IF EXISTS unit_tip;")
    op.execute("DROP TABLE IF EXISTS unit_grup;")
