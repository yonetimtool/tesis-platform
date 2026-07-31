"""borclandirma (0018) — MASTER-PLAN P28 borclandirma motoru.

BIRLESTIRME KARARI (kapsam "FIRST audit the existing dues module and EXTEND
it" diyor): PARALEL BIR SISTEM KURULMADI. `dues_assessment` zaten
"bir daireye bir donem icin borc" kaydidir; ihtiyac duyulan her sey ona
SUTUN olarak eklendi. Ayri bir `borclandirma` tablosu, `dues_payment`in
neye baglanacagini ikiye bolerdi ve mobil "Aidatim" ekrani ile
`/reports/financial-summary` iki kaynagi toplamak zorunda kalirdi.

EKLENENLER:
  * `gelir_gider_tanim_id` — borclandirma TURU (P27 tanimi). NULL = eski
    kayitlar + tur belirtilmeden acilan aidat.
  * `hedef_user_id`        — borcun KIME yazildigi. NULL = "daireye" (eski
    davranis); dolu = malik/kiraci hedeflemesi (P23 bag verisinden cozulur).
  * `tarih`                — borclandirma tarihi. `donem` (YYYY-MM) muhasebe
    donemidir; tarih ise islemin gunudur ve ikisi ayni sey DEGILDIR
    (Ocak doneminin borcu Subat'ta acilabilir).
  * `gecikme_uygula`       — bu kaleme gecikme tazminati islesin mi.
  * `kaynak`               — tekil | toplu | sayac | ice_aktarim (izlenebilirlik).

BENZERSIZLIK DEGISTI — VE BU MADDENIN OMURGASI:
Eski kisit `UNIQUE (tenant_id, unit_id, donem)` idi: bir daireye bir donemde
YALNIZ BIR borc acilabiliyordu. Oysa gercek bir sitede ayni ay hem aidat hem
elektrik hem demirbas borclandirilir. Kisit `(tenant_id, unit_id, donem,
COALESCE(gelir_gider_tanim_id, ...))` benzersiz INDEKSINE cevrildi:
  * TUR BELIRTILMEDEN acilan kayitlar icin ESKI DAVRANIS AYNEN KORUNUR
    (hepsi ayni COALESCE degerine duser -> donem basina tek kayit, 409),
  * tur belirtilince her tur icin ayri bir kayit acilabilir.
Postgres'te NULL'lar benzersizlik acisindan FARKLI sayildigi icin duz bir
`UNIQUE (..., gelir_gider_tanim_id)` eski korumayi SESSIZCE KALDIRIRDI.

GECIKME TAZMINATI tenant ayaridir (`gecikme_aylik_yuzde`): tutar SAKLANMAZ,
raporlama/tahsilat aninda hesaplanir — saklansaydi oran degistiginde gecmis
kayitlar tutarsiz kalirdi.

HEDEF KURALI `gelir_gider_tanim`da: aidat/faturalar KIRACI ONCELIKLI,
yatirim/demirbas MALIK. Kural TANIMDA durur, borclandirma aninda secilmez —
aksi halde ayni kalem farkli aylarda farkli kisiye yazilabilirdi.

Revision ID: 0018_borclandirma
Revises: 0017_muhasebe_tanimlari
"""
from __future__ import annotations

from alembic import op

revision = "0018_borclandirma"
down_revision = "0017_muhasebe_tanimlari"
branch_labels = None
depends_on = None

#: COALESCE nobetci degeri — "tur belirtilmemis" kayitlarin hepsi buraya
#: duser ve boylece eski "donem basina tek kayit" korumasi AYNEN kalir.
NOBETCI = "00000000-0000-0000-0000-000000000000"


def upgrade() -> None:
    op.execute(
        "CREATE TYPE borc_hedef_kurali AS ENUM ('kiraci_oncelikli','malik');"
    )
    op.execute(
        "CREATE TYPE borclandirma_kaynak AS ENUM "
        "('tekil','toplu','sayac','ice_aktarim');"
    )

    op.execute(
        """
        ALTER TABLE gelir_gider_tanim
            ADD COLUMN hedef_kurali borc_hedef_kurali NOT NULL
                DEFAULT 'kiraci_oncelikli';
        """
    )

    op.execute(
        """
        ALTER TABLE dues_assessment
            ADD COLUMN gelir_gider_tanim_id uuid NULL,
            ADD COLUMN hedef_user_id uuid NULL,
            ADD COLUMN tarih date NOT NULL DEFAULT CURRENT_DATE,
            ADD COLUMN gecikme_uygula boolean NOT NULL DEFAULT true,
            ADD COLUMN kaynak borclandirma_kaynak NOT NULL DEFAULT 'tekil';
        """
    )
    op.execute(
        "ALTER TABLE dues_assessment ADD CONSTRAINT fk_assessment_gg_tanim "
        "FOREIGN KEY (gelir_gider_tanim_id, tenant_id) "
        "REFERENCES gelir_gider_tanim (id, tenant_id) "
        "ON DELETE SET NULL (gelir_gider_tanim_id);"
    )
    op.execute(
        "ALTER TABLE dues_assessment ADD CONSTRAINT fk_assessment_hedef "
        "FOREIGN KEY (hedef_user_id, tenant_id) "
        "REFERENCES app_user (id, tenant_id) "
        "ON DELETE SET NULL (hedef_user_id);"
    )

    # Eski kisiti BIRAKIP tur-farkindali benzersiz indekse gec.
    op.execute(
        "ALTER TABLE dues_assessment "
        "DROP CONSTRAINT IF EXISTS uq_assessment_tenant_unit_donem;"
    )
    op.execute(
        f"""
        CREATE UNIQUE INDEX uq_assessment_unit_donem_tur
            ON dues_assessment (
                tenant_id, unit_id, donem,
                COALESCE(gelir_gider_tanim_id, '{NOBETCI}'::uuid)
            );
        """
    )
    op.execute(
        "CREATE INDEX ix_assessment_tenant_hedef "
        "ON dues_assessment (tenant_id, hedef_user_id);"
    )

    # Gecikme tazminati orani — tutar SAKLANMAZ, anlik hesaplanir.
    op.execute(
        """
        ALTER TABLE tenant
            ADD COLUMN gecikme_aylik_yuzde numeric(5,2) NOT NULL DEFAULT 0;
        """
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_gecikme_yuzde "
        "CHECK (gecikme_aylik_yuzde >= 0 AND gecikme_aylik_yuzde <= 100);"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_gecikme_yuzde;")
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS gecikme_aylik_yuzde;")
    op.execute("DROP INDEX IF EXISTS ix_assessment_tenant_hedef;")
    op.execute("DROP INDEX IF EXISTS uq_assessment_unit_donem_tur;")
    # Eski kisiti geri koy — birden fazla tur varsa ihlal olur, o yuzden
    # ONCE fazlaliklar temizlenir (geri alma bilgi kaybi demektir; downgrade
    # zaten yalniz gelistirme/olcum yolunda kosar).
    op.execute(
        """
        DELETE FROM dues_assessment a
         USING dues_assessment b
         WHERE a.tenant_id = b.tenant_id AND a.unit_id = b.unit_id
           AND a.donem = b.donem AND a.ctid > b.ctid;
        """
    )
    op.execute(
        "ALTER TABLE dues_assessment ADD CONSTRAINT uq_assessment_tenant_unit_donem "
        "UNIQUE (tenant_id, unit_id, donem);"
    )
    op.execute(
        "ALTER TABLE dues_assessment DROP CONSTRAINT IF EXISTS fk_assessment_hedef;"
    )
    op.execute(
        "ALTER TABLE dues_assessment DROP CONSTRAINT IF EXISTS fk_assessment_gg_tanim;"
    )
    op.execute(
        """
        ALTER TABLE dues_assessment
            DROP COLUMN IF EXISTS kaynak,
            DROP COLUMN IF EXISTS gecikme_uygula,
            DROP COLUMN IF EXISTS tarih,
            DROP COLUMN IF EXISTS hedef_user_id,
            DROP COLUMN IF EXISTS gelir_gider_tanim_id;
        """
    )
    op.execute("ALTER TABLE gelir_gider_tanim DROP COLUMN IF EXISTS hedef_kurali;")
    op.execute("DROP TYPE IF EXISTS borclandirma_kaynak;")
    op.execute("DROP TYPE IF EXISTS borc_hedef_kurali;")
