"""(P249 §2) TATBIKAT MODU — deprem/yangin/gaz/tahliye provasi.

===========================================================================
TATBIKAT GERCEK ALARMIN AYNISI — AYRI BIR SISTEM DEGIL
===========================================================================
Tatbikat `panik_alarm` satiri olarak YAYINLANIR: ayni bildirim, ayni tam
ekran, ayni ses, ayni "Guvendeyim". Ayri bir tatbikat akisi yazmak, provada
calisan yolun gercek gunde CALISMADIGINI gizlerdi — provanin tek amaci
gercek yolu sinamaktir.

`panik_tatbikat` ise PLANI ve RAPORU tasir: kim, ne zaman, hangi kapsam,
onceden duyuru gitti mi. Alarm satiri `tatbikat_id` ile ona baglanir.

===========================================================================
KARISTIRILAMAZLIK
===========================================================================
`panik_alarm.tatbikat_id` NULL DEGILSE:
  * metin `panik_tatbikat_<k>` — her dilde basligin ONUNDE "TATBIKAT",
    govdenin basinda "Bu bir tatbikattir.",
  * yanlis alarm sayacina GIRMEZ,
  * SMS, diyafon anonsu ve akilli ev senaryolari CALISMAZ (kapi acan bir
    senaryo provada calismamali),
  * gercek alarm her zaman ONCE gosterilir; gercek bir TOPLU alarm
    yayinlanirsa aktif tatbikat DURDURULUR.

===========================================================================
KAPSAM
===========================================================================
`site` (tum site) ya da `blok` (yalniz o bloktaki sakinler + tum
personel). Blok METIN olarak tutulur — `unit.blok` ile ayni zayif bag
(bkz. blok-daire kurallari); FK yok.
"""
from alembic import op

#: Uygulama rolu — GRANT hedefi (diger goclerle ayni kaynak).
APP_ROLE = "app_rw"

revision = "0158_p249_tatbikat"
down_revision = "0157_p249_sos_alici"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE panik_tatbikat (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            kategori panik_kategori NOT NULL,
            kapsam text NOT NULL,
            blok text,
            planlanan_at timestamptz,
            duyuru boolean NOT NULL DEFAULT false,
            duyuru_gonderildi_at timestamptz,
            durum text NOT NULL DEFAULT 'planli',
            olusturan_user_id uuid,
            basladi_at timestamptz,
            bitti_at timestamptz,
            bitis_nedeni text,
            aciklama text,
            created_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_panik_tatbikat_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_panik_tatbikat_kategori
                CHECK (kategori IN ('deprem', 'yangin', 'gaz', 'tahliye')),
            CONSTRAINT ck_panik_tatbikat_kapsam
                CHECK (kapsam IN ('site', 'blok')),
            CONSTRAINT ck_panik_tatbikat_blok
                CHECK ((kapsam = 'blok') = (blok IS NOT NULL AND btrim(blok) <> '')),
            CONSTRAINT ck_panik_tatbikat_durum
                CHECK (durum IN ('planli', 'aktif', 'bitti', 'iptal')),
            CONSTRAINT ck_panik_tatbikat_aciklama
                CHECK (aciklama IS NULL OR length(aciklama) <= 2000),
            CONSTRAINT fk_panik_tatbikat_olusturan
                FOREIGN KEY (olusturan_user_id, tenant_id)
                REFERENCES app_user(id, tenant_id) ON DELETE SET NULL (olusturan_user_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_panik_tatbikat_planli ON panik_tatbikat (planlanan_at) "
        "WHERE durum = 'planli';"
    )
    op.execute(
        "CREATE INDEX ix_panik_tatbikat_tenant ON panik_tatbikat (tenant_id, created_at DESC);"
    )
    # RLS — diger tenant tablolariyla ayni desen.
    op.execute("ALTER TABLE panik_tatbikat ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE panik_tatbikat FORCE ROW LEVEL SECURITY;")
    op.execute(
        "CREATE POLICY panik_tatbikat_isolation ON panik_tatbikat "
        "USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid) "
        "WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);"
    )
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON panik_tatbikat TO {APP_ROLE};")

    op.execute("ALTER TABLE panik_alarm ADD COLUMN tatbikat_id uuid;")
    op.execute(
        "ALTER TABLE panik_alarm ADD CONSTRAINT fk_panik_alarm_tatbikat "
        "FOREIGN KEY (tatbikat_id, tenant_id) "
        "REFERENCES panik_tatbikat(id, tenant_id) ON DELETE SET NULL (tatbikat_id);"
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_panik_alarm_tatbikat ON panik_alarm (tatbikat_id) "
        "WHERE tatbikat_id IS NOT NULL;"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'panik_tatbikat_duyuru';"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_panik_alarm_tatbikat;")
    op.execute(
        "ALTER TABLE panik_alarm DROP CONSTRAINT IF EXISTS fk_panik_alarm_tatbikat;"
    )
    op.execute("ALTER TABLE panik_alarm DROP COLUMN IF EXISTS tatbikat_id;")
    op.execute("DROP TABLE IF EXISTS panik_tatbikat;")
    # notification_tip degeri GERI ALINMAZ (0140 notu).
