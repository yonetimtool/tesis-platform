"""(P192 §5.4) butce_hedefi — BÜTÇE ile GERÇEKLEŞEN yan yana

===========================================================================
NEDEN YENİ BİR TABLO
===========================================================================
Üründe "bütçe" diye bir şey vardı ama o **gerçekleşen** defterdi
(`budget_entry`, P192 §1'den beri `finansal_hareket`). PLANLANAN tutarı
tutan hiçbir yer yoktu; dolayısıyla "bütçe ile gerçekleşen yan yana,
sapma görünsün" sorusu cevaplanamıyordu — karşılaştırılacak ikinci sayı
yoktu.

`finansal_hareket`e "plan" diye bir satır yazmak DÜŞÜNÜLDÜ ve ELENDİ:
defter GERÇEKLEŞMİŞ para hareketlerinin kaydıdır ve bir plan para değildir.
Oraya yazılan bir hedef, kasa bakiyesine karışma riski taşırdı (yalnızca
`durum` süzgeciyle ayrılırdı ve o süzgeci bir gün unutan bir sorgu,
harcanmamış parayı harcanmış gösterirdi).

===========================================================================
DÖNEM: YIL + (İSTEĞE BAĞLI) AY
===========================================================================
Bir site bütçesi genelde YILLIK onaylanır (genel kurul) ama aylık
izlenir. `donem` NULL = yıllık hedef; dolu = o aya ait hedef.

Kısmi benzersizlik iki ayrı indeksle kurulur çünkü Postgres'te NULL'lar
benzersizlikte FARKLI sayılır: `(tenant, yil, kategori)` yıllık satır
için, `(tenant, yil, donem, kategori)` aylık satır için. Tek indeks
yazmak, aynı kategoriye ikinci bir yıllık hedef açılmasına izin verirdi.

Revision ID: 0087_butce_hedefi
Revises: 0086_otomasyon
Create Date: 2026-08-31
"""
from alembic import op

revision = "0087_butce_hedefi"
down_revision = "0086_otomasyon"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE butce_hedefi (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            yil smallint NOT NULL CHECK (yil BETWEEN 2000 AND 2100),
            -- NULL = YILLIK hedef; dolu ('YYYY-MM') = o ayin hedefi.
            donem text,
            kategori_id uuid NOT NULL,
            tutar_kurus bigint NOT NULL CHECK (tutar_kurus >= 0),
            aciklama text,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_butce_hedefi_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT fk_butce_hedefi_kategori
                FOREIGN KEY (kategori_id, tenant_id)
                REFERENCES budget_category (id, tenant_id) ON DELETE RESTRICT
        );
        """
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_butce_hedefi_yillik "
        "ON butce_hedefi (tenant_id, yil, kategori_id) WHERE donem IS NULL;"
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_butce_hedefi_aylik "
        "ON butce_hedefi (tenant_id, yil, donem, kategori_id) "
        "WHERE donem IS NOT NULL;"
    )
    op.execute(
        "CREATE INDEX ix_butce_hedefi_kategori "
        "ON butce_hedefi (kategori_id, tenant_id);"
    )
    op.execute("ALTER TABLE butce_hedefi ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE butce_hedefi FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY butce_hedefi_tenant ON butce_hedefi
            USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);
        """
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON butce_hedefi TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS butce_hedefi CASCADE;")
