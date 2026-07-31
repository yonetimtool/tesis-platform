"""yonetisim (0022) — MASTER-PLAN P33: karar defteri, dokuman, is takibi.

IS TAKIBI — ONCE DENETIM (kapsam "AUDIT ... and unify" diyor):
Denetim, OMURGANIN ZATEN VAR OLDUGUNU gosterdi. `complaint` (Talep/Ariza)
ile `task` (Is Emri) Ticketing v1'de birbirine baglanmisti ve mobil akislar
bunun uzerinde calisiyor. UNIFY ETMEK — yani `complaint` ile
`unit_complaint`i tek tabloya indirmek — P22(e)'nin BILINCLI ayrimini
(sakin->yonetim talebi vs. sakin->KOMSU sikayeti) bozardi: ikisinin
gizlilik kurallari, hedefi ve gorunurlugu FARKLIDIR.

Bu yuzden yapilan sey BIRLESTIRME DEGIL GENISLETME: `complaint` tabloya
UC ALAN kazanir ve P33'un istedigi bilet omurgasi tamamlanir:
  * `unit_id`            — bagimsiz bolum (yoktu; talep hangi daireye ait),
  * `oncelik`            — dusuk|normal|yuksek|acil,
  * `atanan_personel_id` — P27 personel kaydi (app_user DEGIL: temizlik/
    bahcivan gibi hesabi olmayan personele de is atanabilmeli).

KARAR DEFTERI iki tablodur: karar + UYELER. Uyeleri tek metin sutununa
virgulle yazmak, "bu karara kim katildi" sorgusunu metin aramasina
cevirirdi ve bir uyenin adi degisince gecmis kararlar yanlis kalirdi.

DOKUMAN yalnizca META veriyi tutar; dosyanin kendisi MinIO'dadir (mevcut
presign akisi). Icerigi veritabaninda tutmak, yedek boyutunu ve tek satirlik
bir sorgunun maliyetini gereksizce buyuturdu.

Revision ID: 0022_yonetisim
Revises: 0021_mesaj_sablonu
"""
from __future__ import annotations

from alembic import op

revision = "0022_yonetisim"
down_revision = "0021_mesaj_sablonu"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        "CREATE TYPE talep_oncelik AS ENUM ('dusuk','normal','yuksek','acil');"
    )

    # ---------------------------- karar defteri ---------------------------- #
    op.execute(
        """
        CREATE TABLE karar_defteri (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            karar_no   text NOT NULL,
            konu       text NOT NULL,
            tarih      date NOT NULL DEFAULT CURRENT_DATE,
            metin      text NOT NULL,
            baskan_ad  text NULL,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_karar_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_karar_tenant_no UNIQUE (tenant_id, karar_no),
            CONSTRAINT ck_karar_no CHECK (
                btrim(karar_no) <> '' AND length(karar_no) <= 30
            ),
            CONSTRAINT ck_karar_konu CHECK (
                btrim(konu) <> '' AND length(konu) <= 200
            ),
            CONSTRAINT ck_karar_metin CHECK (btrim(metin) <> '')
        );
        """
    )
    op.execute(
        """
        CREATE TABLE karar_uyesi (
            id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            karar_id  uuid NOT NULL,
            -- Uye ADI SAKLANIR (kullaniciya referans DEGIL): uye site
            -- disindan biri olabilir (denetci, avukat) ve kullanici kaydi
            -- silinse bile gecmis karar KIMLERIN katildigini gostermeli.
            ad        text NOT NULL,
            gorev     text NULL,
            CONSTRAINT uq_karar_uyesi_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_karar_uyesi_ad CHECK (
                btrim(ad) <> '' AND length(ad) <= 150
            ),
            FOREIGN KEY (karar_id, tenant_id)
                REFERENCES karar_defteri (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_karar_uyesi_karar ON karar_uyesi (tenant_id, karar_id);"
    )

    # ------------------------------- dokuman -------------------------------- #
    op.execute(
        """
        CREATE TABLE tenant_dokuman (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad          text NOT NULL,
            -- MinIO obje anahtari (tenant onekli). Dosyanin KENDISI burada
            -- DEGIL; icerigi veritabaninda tutmak yedek boyutunu ve tek
            -- satirlik sorgunun maliyetini gereksizce buyuturdu.
            obje_anahtari text NOT NULL,
            icerik_tipi text NULL,
            boyut_bayt  bigint NULL,
            aciklama    text NULL,
            yukleyen_user_id uuid NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_dokuman_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_dokuman_tenant_anahtar UNIQUE (tenant_id, obje_anahtari),
            CONSTRAINT ck_dokuman_ad CHECK (
                btrim(ad) <> '' AND length(ad) <= 200
            ),
            -- 25 MB ust sinir: daha buyuk dosya presign akisinda zaman
            -- asimina ve mobilde bellek baskisina yol acar.
            CONSTRAINT ck_dokuman_boyut CHECK (
                boyut_bayt IS NULL OR (boyut_bayt > 0 AND boyut_bayt <= 26214400)
            ),
            FOREIGN KEY (yukleyen_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id)
                ON DELETE SET NULL (yukleyen_user_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_dokuman_tenant_tarih ON tenant_dokuman "
        "(tenant_id, created_at DESC);"
    )

    for tablo in ("karar_defteri", "karar_uyesi", "tenant_dokuman"):
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

    # ------------------------ is takibi GENISLETMESI ------------------------ #
    op.execute(
        """
        ALTER TABLE complaint
            ADD COLUMN unit_id uuid NULL,
            ADD COLUMN oncelik talep_oncelik NOT NULL DEFAULT 'normal',
            ADD COLUMN atanan_personel_id uuid NULL;
        """
    )
    op.execute(
        "ALTER TABLE complaint ADD CONSTRAINT fk_complaint_unit "
        "FOREIGN KEY (unit_id, tenant_id) REFERENCES unit (id, tenant_id) "
        "ON DELETE SET NULL (unit_id);"
    )
    op.execute(
        "ALTER TABLE complaint ADD CONSTRAINT fk_complaint_personel "
        "FOREIGN KEY (atanan_personel_id, tenant_id) "
        "REFERENCES personel_kayit (id, tenant_id) "
        "ON DELETE SET NULL (atanan_personel_id);"
    )
    op.execute(
        "CREATE INDEX ix_complaint_tenant_personel ON complaint "
        "(tenant_id, atanan_personel_id);"
    )
    op.execute(
        "CREATE INDEX ix_complaint_tenant_unit ON complaint (tenant_id, unit_id);"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_complaint_tenant_unit;")
    op.execute("DROP INDEX IF EXISTS ix_complaint_tenant_personel;")
    op.execute("ALTER TABLE complaint DROP CONSTRAINT IF EXISTS fk_complaint_personel;")
    op.execute("ALTER TABLE complaint DROP CONSTRAINT IF EXISTS fk_complaint_unit;")
    op.execute(
        """
        ALTER TABLE complaint
            DROP COLUMN IF EXISTS atanan_personel_id,
            DROP COLUMN IF EXISTS oncelik,
            DROP COLUMN IF EXISTS unit_id;
        """
    )
    op.execute("DROP TABLE IF EXISTS tenant_dokuman;")
    op.execute("DROP TABLE IF EXISTS karar_uyesi;")
    op.execute("DROP TABLE IF EXISTS karar_defteri;")
    op.execute("DROP TYPE IF EXISTS talep_oncelik;")
