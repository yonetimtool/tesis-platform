"""finansal_hareket (0019) — MASTER-PLAN P29: tahsilat, kasa, hareketler.

TEK DEFTER KARARI: tahsilat, gider, gelir, virman, iade ve acilis fisi AYRI
TABLOLAR DEGIL, tek `finansal_hareket` defterinde `tip` ile ayrilir.
Gerekce — "kasa bakiyesi = hareket toplami" tutarliligi ancak TEK kaynak
varken KANITLANABILIR; alti ayri tabloda bakiye, alti tablonun toplamini
dogru birlestirmeye bagli olurdu ve bir tabloyu unutmak sessiz bir fark
uretirdi.

BAKIYE SAKLANMAZ, TURETILIR: `kasa.acilis_bakiye_kurus` + o kasanin
hareketlerinin ISARETLI toplami. Saklanan bir bakiye, her yazma yolunda
elle guncellenmek zorunda kalir ve bir yol unutuldugunda defterle bakiye
sessizce ayrilir (bu maddenin kabul olcutu tam da bunu olcuyor).

ISARET `yon` SUTUNUNDADIR (`giris | cikis`), tutar HER ZAMAN POZITIF.
Negatif tutar saklamak, "iade" ile "eksi gider"i ayirt edilemez kilardi ve
raporda mutlak deger almak zorunda birakirdi.

VIRMAN IKI SATIRDIR (cikis + giris) ve `virman_grup_id` ile eslesir: tek
satirla iki kasayi etkilemek, "bu kasadan ne cikti" sorgusunu kasa basina
degil hareket basina cevaplamak zorunda birakirdi.

IADE, IADE ETTIGI HAREKETI GOSTERIR (`iade_edilen_id`): "hangi tahsilat
iade edildi" sorusunun cevabi aciklama metnine birakilamaz.

ICRA DOSYASI ayri tablodur (para hareketi degil, HUKUKI SUREC kaydidir) ve
kisiye baglanir; borclar zaten `dues_assessment`ta durur, kopyalanmaz.

Revision ID: 0019_finansal_hareket
Revises: 0018_borclandirma
"""
from __future__ import annotations

from alembic import op

revision = "0019_finansal_hareket"
down_revision = "0018_borclandirma"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        "CREATE TYPE hareket_tip AS ENUM "
        "('tahsilat','gider','gelir','virman','iade','acilis');"
    )
    op.execute("CREATE TYPE hareket_yon AS ENUM ('giris','cikis');")
    op.execute(
        "CREATE TYPE icra_durum AS ENUM "
        "('acik','takipte','tahsil_edildi','kapandi');"
    )

    op.execute(
        """
        CREATE TABLE finansal_hareket (
            id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id      uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            tip            hareket_tip NOT NULL,
            yon            hareket_yon NOT NULL,
            -- TUTAR HER ZAMAN POZITIF; isaret `yon`dadir.
            tutar_kurus    bigint NOT NULL,
            tarih          date NOT NULL DEFAULT CURRENT_DATE,
            kasa_id        uuid NULL,
            -- Kime/neye ait: kisi, daire, firma, gelir-gider turu.
            user_id        uuid NULL,
            unit_id        uuid NULL,
            firma_id       uuid NULL,
            gelir_gider_tanim_id uuid NULL,
            -- Tahsilatin kapattigi borc (varsa).
            assessment_id  uuid NULL,
            belge_no       text NULL,
            aciklama       text NULL,
            -- Virmanin iki satirini eslestirir.
            virman_grup_id uuid NULL,
            -- Iade edilen hareket.
            iade_edilen_id uuid NULL,
            kaydeden_user_id uuid NULL,
            created_at     timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_hareket_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_hareket_tutar CHECK (tutar_kurus > 0),
            CONSTRAINT ck_hareket_belge CHECK (
                belge_no IS NULL OR length(belge_no) <= 50
            ),
            FOREIGN KEY (kasa_id, tenant_id)
                REFERENCES kasa (id, tenant_id) ON DELETE SET NULL (kasa_id),
            FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (user_id),
            FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE SET NULL (unit_id),
            FOREIGN KEY (firma_id, tenant_id)
                REFERENCES firma (id, tenant_id) ON DELETE SET NULL (firma_id),
            FOREIGN KEY (gelir_gider_tanim_id, tenant_id)
                REFERENCES gelir_gider_tanim (id, tenant_id)
                ON DELETE SET NULL (gelir_gider_tanim_id),
            FOREIGN KEY (assessment_id, tenant_id)
                REFERENCES dues_assessment (id, tenant_id)
                ON DELETE SET NULL (assessment_id),
            FOREIGN KEY (iade_edilen_id, tenant_id)
                REFERENCES finansal_hareket (id, tenant_id)
                ON DELETE SET NULL (iade_edilen_id),
            FOREIGN KEY (kaydeden_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id)
                ON DELETE SET NULL (kaydeden_user_id)
        );
        """
    )
    # Kasa bakiyesi TEK sorguda cikarilabilsin.
    op.execute(
        "CREATE INDEX ix_hareket_tenant_kasa ON finansal_hareket "
        "(tenant_id, kasa_id, tarih);"
    )
    op.execute(
        "CREATE INDEX ix_hareket_tenant_kisi ON finansal_hareket "
        "(tenant_id, user_id, tarih);"
    )
    op.execute(
        "CREATE INDEX ix_hareket_tenant_tip_tarih ON finansal_hareket "
        "(tenant_id, tip, tarih);"
    )
    op.execute(
        "CREATE INDEX ix_hareket_virman ON finansal_hareket (tenant_id, virman_grup_id);"
    )

    op.execute(
        """
        CREATE TABLE icra_dosyasi (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            dosya_no    text NOT NULL,
            user_id     uuid NOT NULL,
            veris_tarihi date NULL,
            avukat      text NULL,
            durum       icra_durum NOT NULL DEFAULT 'acik',
            aciklama    text NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_icra_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_icra_tenant_dosya_no UNIQUE (tenant_id, dosya_no),
            CONSTRAINT ck_icra_dosya_no CHECK (
                btrim(dosya_no) <> '' AND length(dosya_no) <= 50
            ),
            FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute("CREATE INDEX ix_icra_tenant_kisi ON icra_dosyasi (tenant_id, user_id);")

    for tablo in ("finansal_hareket", "icra_dosyasi"):
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


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS icra_dosyasi;")
    op.execute("DROP TABLE IF EXISTS finansal_hareket;")
    op.execute("DROP TYPE IF EXISTS icra_durum;")
    op.execute("DROP TYPE IF EXISTS hareket_yon;")
    op.execute("DROP TYPE IF EXISTS hareket_tip;")
