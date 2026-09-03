"""(P207 §1) VARDIYA KALIBI + TOPLU PARTI (geri alinabilir).

===========================================================================
IKI YENI SEY, IKI AYRI SEBEP
===========================================================================

1. `vardiya_kalibi` — GUNU VARDIYALARA BOLME KALIBI.
   "2 vardiya: 08:00-20:00 / 20:00-08:00" ya da "3 vardiya: 08-16 /
   16-24 / 00-08" gibi bir tanim, her ay basinda ELLE tekrar
   girilmemeli. Kalip TESISE aittir ve bir kez tanimlanip tekrar
   kullanilir.

   DILIMLER JSONB: ayri bir `vardiya_kalibi_dilim` tablosu acmak, hep
   BIRLIKTE okunan ve BIRLIKTE yazilan bir listeyi iki tabloya bolmek
   olurdu — dilimlerin bagimsiz bir yasami yok (kalipsiz dilim
   anlamsiz) ve tek tek sorgulanmiyorlar. Sira ONEMLI ve JSONB dizisi
   sirayi zaten tasiyor.

2. `vardiya_plani.parti_id` — TOPLU ISLEMIN GERI ALINABILMESI.
   Istegin acik sarti: "30 gunluk yanlis plan olusturan yonetici tek
   tek silmek zorunda kalmasin." Ayni istekte yazilan satirlar AYNI
   parti kimligini tasir; geri alma o kimlige bakar.

   NEDEN `created_at` ARALIGI DEGIL: iki yonetici ayni dakika icinde
   iki ayri toplu islem yapabilir ve zaman araligiyla geri almak,
   otekinin satirlarini da iptal ederdi. Parti kimligi bunu imkansiz
   kilar.

   SATIR SILINMEZ, `durum='iptal'` olur — P203'ten beri gecerli kural
   (denetim izi: "Ali cikarildi, Veli eklendi" IKI AYRI SATIR).
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision = "0099_vardiya_kalibi"
down_revision = "0098_ek_finansal_hareket"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.create_table(
        "vardiya_kalibi",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("tenant_id", UUID(as_uuid=True),
                  sa.ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False),
        sa.Column("ad", sa.Text(), nullable=False),
        # [{"ad": "Gunduz", "baslangic": "08:00", "bitis": "20:00"}, ...]
        sa.Column("dilimler", JSONB(), nullable=False),
        sa.Column("aktif", sa.Boolean(), nullable=False,
                  server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    op.create_index("ix_vardiya_kalibi_tenant", "vardiya_kalibi", ["tenant_id"])
    op.create_unique_constraint(
        "uq_vardiya_kalibi_ad", "vardiya_kalibi", ["tenant_id", "ad"]
    )
    # BOS KALIP OLMAZ: dilimsiz bir kalip uygulandiginda hicbir sey
    # olusmaz ve kullanici sebebini anlayamazdi.
    op.execute(
        "ALTER TABLE vardiya_kalibi ADD CONSTRAINT ck_vardiya_kalibi_dilim "
        "CHECK (jsonb_typeof(dilimler) = 'array' "
        "AND jsonb_array_length(dilimler) BETWEEN 1 AND 6);"
    )
    op.execute("ALTER TABLE vardiya_kalibi ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE vardiya_kalibi FORCE ROW LEVEL SECURITY;")
    op.execute(
        "CREATE POLICY vardiya_kalibi_isolation ON vardiya_kalibi "
        "USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid) "
        "WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);"
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON vardiya_kalibi TO {APP_ROLE};"
    )

    op.add_column(
        "vardiya_plani",
        sa.Column("parti_id", UUID(as_uuid=True), nullable=True),
    )
    # GERI ALMA SORGUSU BU INDEKSI KULLANIR: partisiz satirlar (tekil
    # atamalar) indekse GIRMEZ — kismi indeks, tablonun buyuk cogunlugu
    # icin bedava.
    op.create_index(
        "ix_vardiya_plani_parti", "vardiya_plani", ["tenant_id", "parti_id"],
        postgresql_where=sa.text("parti_id IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_vardiya_plani_parti", table_name="vardiya_plani")
    op.drop_column("vardiya_plani", "parti_id")
    op.execute("DROP POLICY IF EXISTS vardiya_kalibi_isolation ON vardiya_kalibi;")
    op.drop_index("ix_vardiya_kalibi_tenant", table_name="vardiya_kalibi")
    op.drop_table("vardiya_kalibi")
