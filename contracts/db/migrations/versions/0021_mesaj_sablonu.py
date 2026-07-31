"""mesaj_sablonu (0021) — MASTER-PLAN P32: SMS + e-posta iletisim paketi.

IKI TABLO:
  * `mesaj_sablonu`  — kanal basina sablon (etiket interpolasyonlu govde),
  * `mesaj_gonderim` — GECMIS: kime, hangi sablonla, hangi metinle, ne oldu.

GONDERILEN METIN GECMISE KOPYALANIR (`govde` sutunu), sablona referans
YETMEZ: sablon sonradan degistirilirse gecmis kayit "ne gonderdik" sorusuna
YANLIS cevap verirdi — bu bir KVKK ve hukuk sorusudur (ihtar/bildirim
kaniti).

AMAC (`pazarlama | operasyonel`) SABLONDA durur, gonderim aninda secilmez:
ayni sablonun bir gun pazarlama bir gun operasyonel gonderilmesi, riza
denetimini anlamsiz kilardi. Pazarlama gonderimi P36'nin rizasini ister;
operasyonel finansal bildirim AYRI bir hukuki dayanaktir (KMK yukumluluk).

Revision ID: 0021_mesaj_sablonu
Revises: 0020_odeme_kodu
"""
from __future__ import annotations

from alembic import op

revision = "0021_mesaj_sablonu"
down_revision = "0020_odeme_kodu"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute("CREATE TYPE mesaj_kanal AS ENUM ('sms','eposta');")
    op.execute("CREATE TYPE mesaj_amac AS ENUM ('pazarlama','operasyonel');")
    op.execute(
        "CREATE TYPE mesaj_durum AS ENUM "
        "('kuyrukta','gonderildi','iletildi','okundu','basarisiz');"
    )

    op.execute(
        """
        CREATE TABLE mesaj_sablonu (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            kanal      mesaj_kanal NOT NULL,
            ad         text NOT NULL,
            -- Konu YALNIZ e-postada anlamlidir; SMS'te dolu konu, gonderilen
            -- metne GIRMEYEN bir alan olurdu (kullanici yazip kaybeder).
            konu       text NULL,
            govde      text NOT NULL,
            amac       mesaj_amac NOT NULL DEFAULT 'operasyonel',
            aktif      boolean NOT NULL DEFAULT true,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_sablon_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_sablon_tenant_kanal_ad UNIQUE (tenant_id, kanal, ad),
            CONSTRAINT ck_sablon_ad CHECK (btrim(ad) <> '' AND length(ad) <= 100),
            CONSTRAINT ck_sablon_govde CHECK (
                btrim(govde) <> '' AND length(govde) <= 4000
            ),
            CONSTRAINT ck_sablon_konu CHECK (
                konu IS NULL OR (kanal = 'eposta' AND length(konu) <= 200)
            )
        );
        """
    )

    op.execute(
        """
        CREATE TABLE mesaj_gonderim (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            sablon_id  uuid NULL,
            kanal      mesaj_kanal NOT NULL,
            amac       mesaj_amac NOT NULL,
            user_id    uuid NULL,
            -- Gonderildigi ADRES/NUMARA: kullanici sonradan degistirse bile
            -- "nereye gonderdik" sorusu cevaplanabilmeli.
            hedef      text NOT NULL,
            konu       text NULL,
            -- COZULMUS metin (etiketler yerine konmus hali) — sablon
            -- degisirse gecmis YANLIS cevap vermesin.
            govde      text NOT NULL,
            durum      mesaj_durum NOT NULL DEFAULT 'kuyrukta',
            hata       text NULL,
            saglayici  text NULL,
            gonderen_user_id uuid NULL,
            created_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_gonderim_id_tenant UNIQUE (id, tenant_id),
            FOREIGN KEY (sablon_id, tenant_id)
                REFERENCES mesaj_sablonu (id, tenant_id)
                ON DELETE SET NULL (sablon_id),
            FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (user_id),
            FOREIGN KEY (gonderen_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id)
                ON DELETE SET NULL (gonderen_user_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_gonderim_tenant_tarih ON mesaj_gonderim "
        "(tenant_id, created_at DESC);"
    )
    op.execute(
        "CREATE INDEX ix_gonderim_tenant_kisi ON mesaj_gonderim (tenant_id, user_id);"
    )

    for tablo in ("mesaj_sablonu", "mesaj_gonderim"):
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
    op.execute("DROP TABLE IF EXISTS mesaj_gonderim;")
    op.execute("DROP TABLE IF EXISTS mesaj_sablonu;")
    op.execute("DROP TYPE IF EXISTS mesaj_durum;")
    op.execute("DROP TYPE IF EXISTS mesaj_amac;")
    op.execute("DROP TYPE IF EXISTS mesaj_kanal;")
