"""muhasebe_tanimlari (0017) — MASTER-PLAN P27 "Tanimlar" katmani.

Yedi kayit defteri + tenant ayarlari. Hepsi TENANT KAPSAMLI ve RLS'li.

TASARIM KARARLARI (her biri bir alternatifi ELEYEREK):

1. PARA HER YERDE `bigint` KURUS. `numeric` ile bile "0.1 + 0.2" tartismasi
   acilir ve iki farkli sutun tipi (kurus / numeric) raporda toplanirken
   sessiz yuvarlama uretirdi. Repo geneli `*_kurus` kurali.

2. ACILIS BAKIYESI ISARETSIZ TUTAR + AYRI YON (`borc | alacak`), negatif
   sayi DEGIL. "-500" bir firmada "biz mi borcluyuz, o mu" sorusunu
   yanitlamaz; yon acikca saklanir.

3. `gelir_gider_dagitim` ENUM'UNDA SIMDILIK IKI DEGER var
   (`bagimsiz_bolumlere_esit`, `tipe_gore`). "arsa_payi" ve "kisi_sayisi"
   BILEREK EKLENMEDI: enum'a koyup P28'de uygulamamak, kullaniciya SECILEBILIR
   ama YANLIS BORCLANDIRAN bir secenek gosterirdi. Genisleme tek satirdir
   (`ALTER TYPE ... ADD VALUE`), 0013'te ayni sey yapildi.

4. PERSONEL KAYDI ile `app_user` AYRI. Her personelin uygulama hesabi yoktur
   (temizlik, bahcivan) ve her kullanici personel degildir (sakin). Ortusenler
   `app_user_id` ile BAGLANIR; bag opsiyoneldir ve kullanici silinirse kayit
   durur (SET NULL) — bordro gecmisi kimlik kaydina bagli olmamali.

5. ARAC KAYDI plakayi NORMALIZE saklar (bosluksuz + BUYUK), `vehicle_pass`
   ile AYNI kural — P17 rozetleri "kayitli mi" sorusunu bu tablodan
   soracak ve iki farkli normalizasyon iki farkli cevap verirdi.

6. SAYACLAR IKI TABLO: `sayac_ana` (site geneli, ortak alan dagitimi) ve
   `sayac_bolum` (daire sayaci, bir ana sayaca bagli). Tek tabloda "ana mi"
   bayragiyla tutmak, ana sayaca ozgu alanlari (ortak alan yuzdesi) daire
   satirlarinda anlamsizca null birakirdi.

7. EVRAK SERI/SIRA + PARA BIRIMI `tenant` sutunudur, ayri tablo degil: tenant
   basina TEK satirlik ayarlardir. `para_birimi` YALNIZ GOSTERIMDIR — depo
   ve hesaplama ₺ kalir (cok para birimi ayri bir karardir).

Revision ID: 0017_muhasebe_tanimlari
Revises: 0016_daire_tip_grup
"""
from __future__ import annotations

from alembic import op

revision = "0017_muhasebe_tanimlari"
down_revision = "0016_daire_tip_grup"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

TABLOLAR = (
    "kasa",
    "gelir_gider_grup",
    "gelir_gider_tanim",
    "firma",
    "personel_kayit",
    "arac_kayit",
    "sayac_ana",
    "sayac_bolum",
)


def _rls(tablo: str) -> None:
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


def upgrade() -> None:
    # ------------------------------ enum'lar ------------------------------- #
    op.execute("CREATE TYPE gelir_gider_tip AS ENUM ('gelir','gider','her_ikisi');")
    op.execute(
        "CREATE TYPE gelir_gider_dagitim AS ENUM "
        "('bagimsiz_bolumlere_esit','tipe_gore');"
    )
    op.execute("CREATE TYPE bakiye_yon AS ENUM ('borc','alacak');")
    op.execute(
        "CREATE TYPE sayac_tip AS ENUM ('su','elektrik','dogalgaz','isi','diger');"
    )

    # -------------------------------- kasa --------------------------------- #
    op.execute(
        """
        CREATE TABLE kasa (
            id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id            uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            kod                  text NOT NULL,
            ad                   text NOT NULL,
            acilis_tarihi        date NULL,
            acilis_bakiye_kurus  bigint NOT NULL DEFAULT 0,
            banka_mi             boolean NOT NULL DEFAULT false,
            iban                 text NULL,
            banka_adi            text NULL,
            sube                 text NULL,
            aktif                boolean NOT NULL DEFAULT true,
            created_at           timestamptz NOT NULL DEFAULT now(),
            updated_at           timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_kasa_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_kasa_tenant_kod UNIQUE (tenant_id, kod),
            CONSTRAINT ck_kasa_kod CHECK (btrim(kod) <> '' AND length(kod) <= 20),
            CONSTRAINT ck_kasa_ad CHECK (btrim(ad) <> '' AND length(ad) <= 100),
            -- IBAN yalniz BANKA kasasinda anlamlidir; banka olmayan bir kasada
            -- dolu IBAN, odemeyi yanlis hesaba yonlendirme riskidir.
            CONSTRAINT ck_kasa_banka_alanlari CHECK (
                banka_mi OR (iban IS NULL AND banka_adi IS NULL AND sube IS NULL)
            ),
            CONSTRAINT ck_kasa_iban CHECK (
                iban IS NULL OR iban ~ '^TR[0-9]{24}$'
            )
        );
        """
    )

    # -------------------------- gelir/gider grubu -------------------------- #
    op.execute(
        """
        CREATE TABLE gelir_gider_grup (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad         text NOT NULL,
            aktif      boolean NOT NULL DEFAULT true,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_gg_grup_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_gg_grup_tenant_ad UNIQUE (tenant_id, ad),
            CONSTRAINT ck_gg_grup_ad CHECK (btrim(ad) <> '' AND length(ad) <= 100)
        );
        """
    )

    # -------------------------- gelir/gider tanimi ------------------------- #
    op.execute(
        """
        CREATE TABLE gelir_gider_tanim (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad            text NOT NULL,
            tip           gelir_gider_tip NOT NULL,
            grup_id       uuid NULL,
            dagitim_sekli gelir_gider_dagitim NULL,
            aktif         boolean NOT NULL DEFAULT true,
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_gg_tanim_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_gg_tanim_tenant_ad UNIQUE (tenant_id, ad),
            CONSTRAINT ck_gg_tanim_ad CHECK (btrim(ad) <> '' AND length(ad) <= 100),
            -- Dagitim sekli YALNIZ gider/her_ikisi icin anlamlidir: bir GELIR
            -- kalemi bagimsiz bolumlere "dagitilmaz", tahsil edilir.
            CONSTRAINT ck_gg_tanim_dagitim CHECK (
                dagitim_sekli IS NULL OR tip <> 'gelir'
            ),
            FOREIGN KEY (grup_id, tenant_id)
                REFERENCES gelir_gider_grup (id, tenant_id)
                ON DELETE SET NULL (grup_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_gg_tanim_tenant_grup ON gelir_gider_tanim (tenant_id, grup_id);"
    )

    # -------------------------------- firma -------------------------------- #
    op.execute(
        """
        CREATE TABLE firma (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id           uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad                  text NOT NULL,
            vergi_no            text NULL,
            vergi_dairesi       text NULL,
            telefon             text NULL,
            email               text NULL,
            adres               text NULL,
            yetkili_ad          text NULL,
            yetkili_telefon     text NULL,
            acilis_bakiye_kurus bigint NOT NULL DEFAULT 0,
            acilis_bakiye_yon   bakiye_yon NOT NULL DEFAULT 'borc',
            aktif               boolean NOT NULL DEFAULT true,
            created_at          timestamptz NOT NULL DEFAULT now(),
            updated_at          timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_firma_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_firma_tenant_ad UNIQUE (tenant_id, ad),
            CONSTRAINT ck_firma_ad CHECK (btrim(ad) <> '' AND length(ad) <= 150),
            -- Vergi no 10 hane (tuzel), TC 11 hane (sahis) — ikisi de kabul.
            CONSTRAINT ck_firma_vergi_no CHECK (
                vergi_no IS NULL OR vergi_no ~ '^[0-9]{10,11}$'
            ),
            -- ISARETSIZ tutar + AYRI yon (bkz. dosya basligi, karar 2).
            CONSTRAINT ck_firma_acilis CHECK (acilis_bakiye_kurus >= 0)
        );
        """
    )

    # ------------------------------- personel ------------------------------ #
    op.execute(
        """
        CREATE TABLE personel_kayit (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad            text NOT NULL,
            tc            text NULL,
            gorev         text NULL,
            telefon       text NULL,
            email         text NULL,
            giris_tarihi  date NULL,
            cikis_tarihi  date NULL,
            maas_kurus    bigint NULL,
            -- Uygulama hesabiyla BAG (opsiyonel): her personelin hesabi yoktur
            -- ve her kullanici personel degildir. Hesap silinirse kayit DURUR.
            app_user_id   uuid NULL,
            aktif         boolean NOT NULL DEFAULT true,
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_personel_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_personel_ad CHECK (btrim(ad) <> '' AND length(ad) <= 150),
            CONSTRAINT ck_personel_tc CHECK (tc IS NULL OR tc ~ '^[0-9]{11}$'),
            CONSTRAINT ck_personel_maas CHECK (maas_kurus IS NULL OR maas_kurus >= 0),
            -- Cikis girisden ONCE olamaz (veri girisi hatasi).
            CONSTRAINT ck_personel_tarih CHECK (
                cikis_tarihi IS NULL OR giris_tarihi IS NULL
                OR cikis_tarihi >= giris_tarihi
            ),
            FOREIGN KEY (app_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id)
                ON DELETE SET NULL (app_user_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_personel_tenant_user ON personel_kayit (tenant_id, app_user_id);"
    )

    # --------------------------------- arac -------------------------------- #
    op.execute(
        """
        CREATE TABLE arac_kayit (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            plaka      text NOT NULL,
            user_id    uuid NULL,
            unit_id    uuid NULL,
            marka      text NULL,
            model      text NULL,
            renk       text NULL,
            aktif      boolean NOT NULL DEFAULT true,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_arac_id_tenant UNIQUE (id, tenant_id),
            -- Bir plaka site icinde TEK kayit: iki daireye kayitli bir arac,
            -- P17 rozetinin hangi daireyi gosterecegini belirsiz birakirdi.
            CONSTRAINT uq_arac_tenant_plaka UNIQUE (tenant_id, plaka),
            -- `vehicle_pass` ile AYNI normalizasyon kurali (bosluksuz + BUYUK).
            CONSTRAINT ck_arac_plaka CHECK (plaka ~ '^[A-Z0-9]{2,20}$'),
            FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (user_id),
            FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE SET NULL (unit_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_arac_tenant_unit ON arac_kayit (tenant_id, unit_id);")

    # ------------------------------- sayaclar ------------------------------ #
    op.execute(
        """
        CREATE TABLE sayac_ana (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id           uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad                  text NOT NULL,
            tip                 sayac_tip NOT NULL DEFAULT 'diger',
            tesisat_no          text NULL,
            -- Ortak alan tuketiminin bagimsiz bolumlere dagitim sekli + payi.
            ortak_alan_dagitim  gelir_gider_dagitim NULL,
            ortak_alan_yuzde    numeric(5,2) NULL,
            aktif               boolean NOT NULL DEFAULT true,
            created_at          timestamptz NOT NULL DEFAULT now(),
            updated_at          timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_sayac_ana_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_sayac_ana_tenant_ad UNIQUE (tenant_id, ad),
            CONSTRAINT ck_sayac_ana_ad CHECK (btrim(ad) <> '' AND length(ad) <= 100),
            CONSTRAINT ck_sayac_ana_yuzde CHECK (
                ortak_alan_yuzde IS NULL
                OR (ortak_alan_yuzde >= 0 AND ortak_alan_yuzde <= 100)
            )
        );
        """
    )
    op.execute(
        """
        CREATE TABLE sayac_bolum (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            unit_id       uuid NOT NULL,
            ana_sayac_id  uuid NULL,
            tesisat_no    text NULL,
            ilk_okuma     numeric(12,3) NULL,
            aktif         boolean NOT NULL DEFAULT true,
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_sayac_bolum_id_tenant UNIQUE (id, tenant_id),
            -- Bir daire bir ANA SAYAC icin tek sayac tasir (su + elektrik ayri
            -- ana sayaclardir, yani ikisi de kaydedilebilir).
            CONSTRAINT uq_sayac_bolum_unit_ana UNIQUE (tenant_id, unit_id, ana_sayac_id),
            CONSTRAINT ck_sayac_bolum_ilk_okuma CHECK (
                ilk_okuma IS NULL OR ilk_okuma >= 0
            ),
            FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            FOREIGN KEY (ana_sayac_id, tenant_id)
                REFERENCES sayac_ana (id, tenant_id)
                ON DELETE SET NULL (ana_sayac_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_sayac_bolum_tenant_ana ON sayac_bolum (tenant_id, ana_sayac_id);"
    )

    for t in TABLOLAR:
        _rls(t)

    # --------------------------- tenant ayarlari --------------------------- #
    op.execute(
        """
        ALTER TABLE tenant
            ADD COLUMN evrak_seri text NOT NULL DEFAULT 'A',
            ADD COLUMN evrak_sira bigint NOT NULL DEFAULT 1,
            -- YALNIZ GOSTERIM: depo ve hesaplama ₺ kalir (cok para birimi
            -- ayri bir karardir, bkz. P27 kapsami).
            ADD COLUMN para_birimi text NOT NULL DEFAULT 'TRY';
        """
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_evrak_seri "
        "CHECK (evrak_seri ~ '^[A-Z]{1,5}$');"
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_evrak_sira CHECK (evrak_sira >= 1);"
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_para_birimi "
        "CHECK (para_birimi ~ '^[A-Z]{3}$');"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_para_birimi;")
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_evrak_sira;")
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_evrak_seri;")
    op.execute(
        "ALTER TABLE tenant "
        "DROP COLUMN IF EXISTS para_birimi, "
        "DROP COLUMN IF EXISTS evrak_sira, "
        "DROP COLUMN IF EXISTS evrak_seri;"
    )
    for t in reversed(TABLOLAR):
        op.execute(f"DROP TABLE IF EXISTS {t};")
    for e in ("sayac_tip", "bakiye_yon", "gelir_gider_dagitim", "gelir_gider_tip"):
        op.execute(f"DROP TYPE IF EXISTS {e};")
