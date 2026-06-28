"""initial schema: multi-tenant tesis guvenlik & operasyon

Revision ID: 0001_initial_schema
Revises:
Create Date: 2026-06-27

Tek dogruluk kaynagi (single source of truth) DB semasi.

Tasarim kararlari (detay icin /contracts/README.md):
  * Tum tablolarda tenant_id (tenant tablosunda id) + Row-Level Security (RLS).
  * Tenant izolasyonu uygulama katmaninda DEGIL, DB seviyesinde RLS ile zorlanir.
    Her istek basinda backend `SET app.current_tenant_id = '<uuid>'` calistirir;
    politikalar bu oturum degiskenini kullanir.
  * Cross-tenant FK referanslarini imkansiz kilmak icin composite FK
    (id, tenant_id) -> (id, tenant_id) kullanilir.
  * Tum zaman damgalari UTC `timestamptz`. Gun-ici saatler (shift, patrol_plan)
    `time` olarak tutulur ve tenant.timezone ile yorumlanir (gece 00:00 mantigi).
  * Birincil anahtarlar UUID (gen_random_uuid, pgcrypto/pg >= 13 yerlesik).
"""
from alembic import op


# revision identifiers, used by Alembic.
revision = "0001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


# Uygulama (backend) rolu. RLS bu rol icin zorlanir; migration'i calistiran
# superuser/owner BYPASSRLS oldugu icin politikalardan etkilenmez.
APP_ROLE = "app_rw"


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 0. Eklentiler ve uygulama rolu
    # ------------------------------------------------------------------ #
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")  # gen_random_uuid()

    op.execute(
        f"""
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{APP_ROLE}') THEN
                CREATE ROLE {APP_ROLE} NOLOGIN;
            END IF;
        END
        $$;
        """
    )

    # ------------------------------------------------------------------ #
    # 1. Enum tipleri
    # ------------------------------------------------------------------ #
    op.execute(
        "CREATE TYPE user_role AS ENUM ('admin', 'security', 'cleaning', 'resident');"
    )
    op.execute(
        "CREATE TYPE gun_tipi AS ENUM ('her_gun', 'hafta_ici', 'hafta_sonu', 'resmi_tatil');"
    )
    op.execute(
        "CREATE TYPE patrol_window_durum AS ENUM ('bekliyor', 'tamamlandi', 'kacirildi');"
    )
    # notification.tip — ilk deger 'kacirilan_tur'; ileride genisler (openapi Alarm.tip ile uyumlu).
    op.execute(
        "CREATE TYPE notification_tip AS ENUM "
        "('kacirilan_tur', 'eksik_checkpoint', 'gecikmis_okutma');"
    )
    # task.tip — esnek gorev tipi; ileride genisler.
    op.execute(
        "CREATE TYPE task_tip AS ENUM "
        "('temizlik', 'kontrol', 'ilaclama', 'bakim', 'diger');"
    )

    # ------------------------------------------------------------------ #
    # 2. tenant
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE tenant (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ad          text NOT NULL,
            -- slug: login'de tenant'i belirleyen kisa, benzersiz, insan-okunur ad.
            -- (email tenant-ici benzersiz oldugu icin login email tek basina yetmez;
            --  istemci tenant_slug gonderir -> tenant_id_by_slug ile cozumlenir.)
            slug        text NOT NULL,
            timezone    text NOT NULL DEFAULT 'Europe/Istanbul',
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_tenant_slug UNIQUE (slug),
            CONSTRAINT ck_tenant_slug CHECK (slug ~ '^[a-z0-9][a-z0-9-]*$')
        );
        """
    )

    # Login bootstrap: app_rw RLS'e tabidir ve tenant baglami HENUZ yokken
    # tenant tablosunu okuyamaz (yumurta-tavuk). Bu SECURITY DEFINER fonksiyon
    # owner (superuser) yetkisiyle calisir ve YALNIZCA slug -> id eslemesini
    # doner; baska tenant verisi sizdirmaz. Login bununla tenant_id'yi bulup
    # set_config('app.current_tenant_id', ...) yapar, sonrasi normal RLS akisi.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_id_by_slug(p_slug text)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT id FROM public.tenant WHERE slug = p_slug;
        $$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.tenant_id_by_slug(text) FROM PUBLIC;")
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.tenant_id_by_slug(text) TO {APP_ROLE};"
    )

    # ------------------------------------------------------------------ #
    # 3. app_user
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE app_user (
            id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id      uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad             text NOT NULL,
            email          text NOT NULL,
            telefon        text,
            password_hash  text NOT NULL,
            role           user_role NOT NULL,
            is_active      boolean NOT NULL DEFAULT true,
            created_at     timestamptz NOT NULL DEFAULT now(),
            updated_at     timestamptz NOT NULL DEFAULT now(),
            -- composite FK hedefi olabilmesi icin:
            UNIQUE (id, tenant_id),
            -- email tenant icinde benzersiz (case-insensitive):
            CONSTRAINT uq_app_user_tenant_email UNIQUE (tenant_id, email)
        );
        """
    )
    op.execute("CREATE INDEX ix_app_user_tenant ON app_user (tenant_id);")
    op.execute(
        "CREATE UNIQUE INDEX uq_app_user_tenant_email_lower "
        "ON app_user (tenant_id, lower(email));"
    )

    # ------------------------------------------------------------------ #
    # 4. shift  (tekrar eden gun-ici vardiya tanimi)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE shift (
            id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad              text NOT NULL,
            baslangic_saat  time NOT NULL,   -- gun-ici saat (UTC degil; tenant.timezone ile yorumlanir)
            bitis_saat      time NOT NULL,   -- gece yarisini gecebilir (bitis < baslangic => ertesi gun)
            gun_tipi        gun_tipi NOT NULL DEFAULT 'her_gun',
            created_at      timestamptz NOT NULL DEFAULT now(),
            updated_at      timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_shift_tenant ON shift (tenant_id);")

    # ------------------------------------------------------------------ #
    # 5. checkpoint  (NFC noktasi)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE checkpoint (
            id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad           text NOT NULL,
            nfc_tag_uid  text NOT NULL,
            gps_lat      numeric(9, 6),
            gps_lng      numeric(9, 6),
            aktif        boolean NOT NULL DEFAULT true,
            created_at   timestamptz NOT NULL DEFAULT now(),
            updated_at   timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT uq_checkpoint_tenant_nfc UNIQUE (tenant_id, nfc_tag_uid)
        );
        """
    )
    op.execute("CREATE INDEX ix_checkpoint_tenant ON checkpoint (tenant_id);")
    op.execute(
        "CREATE INDEX ix_checkpoint_nfc ON checkpoint (tenant_id, nfc_tag_uid);"
    )

    # ------------------------------------------------------------------ #
    # 6. patrol_plan
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE patrol_plan (
            id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad              text NOT NULL,
            shift_id        uuid,
            baslangic_saat  time NOT NULL,        -- orn 00:00 (gece turu)
            bitis_saat      time NOT NULL,        -- orn 06:00; bitis < baslangic => gece yarisini gecer
            periyot_dakika  integer NOT NULL,     -- orn 60 => saat basi pencere
            aktif           boolean NOT NULL DEFAULT true,
            created_at      timestamptz NOT NULL DEFAULT now(),
            updated_at      timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_patrol_plan_periyot CHECK (periyot_dakika > 0),
            -- shift ayni tenant'a ait olmali (cross-tenant FK engeli):
            -- Kolon-ozel SET NULL: sadece shift_id NULL'lanir; paylasilan NOT NULL
            -- tenant_id'ye dokunulmaz (PG15+). Bkz. /contracts/README.md.
            CONSTRAINT fk_patrol_plan_shift
                FOREIGN KEY (shift_id, tenant_id)
                REFERENCES shift (id, tenant_id) ON DELETE SET NULL (shift_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_patrol_plan_tenant ON patrol_plan (tenant_id);")
    op.execute("CREATE INDEX ix_patrol_plan_shift ON patrol_plan (shift_id);")

    # ------------------------------------------------------------------ #
    # 7. patrol_plan_checkpoint  (plan <-> checkpoint, sirali)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE patrol_plan_checkpoint (
            tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            patrol_plan_id   uuid NOT NULL,
            checkpoint_id    uuid NOT NULL,
            sira             integer NOT NULL,
            PRIMARY KEY (patrol_plan_id, checkpoint_id),
            CONSTRAINT fk_ppc_plan
                FOREIGN KEY (patrol_plan_id, tenant_id)
                REFERENCES patrol_plan (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_ppc_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT uq_ppc_plan_sira UNIQUE (patrol_plan_id, sira),
            CONSTRAINT ck_ppc_sira CHECK (sira >= 0)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_ppc_tenant ON patrol_plan_checkpoint (tenant_id);"
    )
    op.execute(
        "CREATE INDEX ix_ppc_checkpoint ON patrol_plan_checkpoint (checkpoint_id);"
    )

    # ------------------------------------------------------------------ #
    # 8. patrol_window  (scheduler tarafindan uretilen somut pencereler)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE patrol_window (
            id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id          uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            patrol_plan_id     uuid NOT NULL,
            pencere_baslangic  timestamptz NOT NULL,   -- UTC, somut an
            pencere_bitis      timestamptz NOT NULL,   -- UTC, somut an
            durum              patrol_window_durum NOT NULL DEFAULT 'bekliyor',
            created_at         timestamptz NOT NULL DEFAULT now(),
            updated_at         timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT fk_patrol_window_plan
                FOREIGN KEY (patrol_plan_id, tenant_id)
                REFERENCES patrol_plan (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT ck_patrol_window_aralik CHECK (pencere_bitis > pencere_baslangic),
            -- ayni plan icin ayni pencere bir kez uretilsin (scheduler idempotent):
            CONSTRAINT uq_patrol_window_plan_baslangic
                UNIQUE (patrol_plan_id, pencere_baslangic)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_patrol_window_tenant ON patrol_window (tenant_id);"
    )
    op.execute(
        "CREATE INDEX ix_patrol_window_plan ON patrol_window (patrol_plan_id);"
    )
    # Dashboard/live ve scheduler sorgulari icin:
    op.execute(
        "CREATE INDEX ix_patrol_window_durum_baslangic "
        "ON patrol_window (tenant_id, durum, pencere_baslangic);"
    )

    # ------------------------------------------------------------------ #
    # 9. scan_event  (mobilin gonderdigi tur kaniti)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE scan_event (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            guard_id          uuid NOT NULL,
            checkpoint_id     uuid NOT NULL,
            patrol_window_id  uuid,                 -- ad-hoc okutma olabilir => nullable
            nfc_tag_uid       text NOT NULL,
            okutma_zamani     timestamptz NOT NULL, -- cihazin okuttugu an (UTC)
            gps_lat           numeric(9, 6),
            gps_lng           numeric(9, 6),
            foto_url          text,
            imza_dogrulandi   boolean NOT NULL DEFAULT false,
            idempotency_key   text NOT NULL,
            created_at        timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_scan_guard
                FOREIGN KEY (guard_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            CONSTRAINT fk_scan_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE RESTRICT,
            -- Kolon-ozel SET NULL: sadece patrol_window_id NULL'lanir; paylasilan
            -- NOT NULL tenant_id'ye dokunulmaz (PG15+). Bkz. /contracts/README.md.
            CONSTRAINT fk_scan_window
                FOREIGN KEY (patrol_window_id, tenant_id)
                REFERENCES patrol_window (id, tenant_id) ON DELETE SET NULL (patrol_window_id),
            -- offline cift gonderim engeli (idempotency):
            CONSTRAINT uq_scan_tenant_idempotency UNIQUE (tenant_id, idempotency_key)
        );
        """
    )
    op.execute("CREATE INDEX ix_scan_tenant ON scan_event (tenant_id);")
    op.execute("CREATE INDEX ix_scan_guard ON scan_event (guard_id);")
    op.execute("CREATE INDEX ix_scan_checkpoint ON scan_event (checkpoint_id);")
    op.execute("CREATE INDEX ix_scan_window ON scan_event (patrol_window_id);")
    op.execute(
        "CREATE INDEX ix_scan_okutma_zamani "
        "ON scan_event (tenant_id, okutma_zamani DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9b. notification  (kacirilan tur vb. kalici bildirim kaydi)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE notification (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            tip               notification_tip NOT NULL,
            patrol_window_id  uuid,
            patrol_plan_id    uuid,
            checkpoint_id     uuid,
            mesaj             text NOT NULL,
            okundu            boolean NOT NULL DEFAULT false,
            created_at        timestamptz NOT NULL DEFAULT now(),
            -- Kolon-ozel SET NULL: yalnizca ilgili FK kolonu NULL'lanir; paylasilan
            -- NOT NULL tenant_id korunur (PG15+). Bkz. /contracts/README.md.
            CONSTRAINT fk_notification_window
                FOREIGN KEY (patrol_window_id, tenant_id)
                REFERENCES patrol_window (id, tenant_id) ON DELETE SET NULL (patrol_window_id),
            CONSTRAINT fk_notification_plan
                FOREIGN KEY (patrol_plan_id, tenant_id)
                REFERENCES patrol_plan (id, tenant_id) ON DELETE SET NULL (patrol_plan_id),
            CONSTRAINT fk_notification_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE SET NULL (checkpoint_id),
            -- Idempotent bildirim: ayni kacirilan pencere icin tek kayit.
            -- (patrol_window_id NULL ise NULLS DISTINCT geregi dedup uygulanmaz;
            --  pencere-bazli alarmlar icin window dolu oldugundan calisir.)
            CONSTRAINT uq_notification_tenant_tip_window
                UNIQUE (tenant_id, tip, patrol_window_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_notification_tenant ON notification (tenant_id);")
    op.execute(
        "CREATE INDEX ix_notification_list "
        "ON notification (tenant_id, created_at DESC);"
    )
    op.execute(
        "CREATE INDEX ix_notification_okundu ON notification (tenant_id, okundu);"
    )

    # ------------------------------------------------------------------ #
    # 9c. task  (esnek gorev: temizlik/kontrol/ilaclama... tek modelde)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE task (
            id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            tip              task_tip NOT NULL,
            ad               text NOT NULL,
            aciklama         text,
            atanan_user_id   uuid,
            checkpoint_id    uuid,
            periyot_dakika   integer,   -- periyodik gorev; tek seferlikse NULL
            aktif            boolean NOT NULL DEFAULT true,
            created_at       timestamptz NOT NULL DEFAULT now(),
            updated_at       timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_task_periyot CHECK (periyot_dakika IS NULL OR periyot_dakika > 0),
            -- Kolon-ozel SET NULL: yalnizca ilgili kolon NULL'lanir; tenant_id korunur.
            CONSTRAINT fk_task_atanan
                FOREIGN KEY (atanan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (atanan_user_id),
            CONSTRAINT fk_task_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE SET NULL (checkpoint_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_task_tenant ON task (tenant_id);")
    op.execute("CREATE INDEX ix_task_tip ON task (tenant_id, tip);")
    op.execute("CREATE INDEX ix_task_atanan ON task (atanan_user_id);")

    # ------------------------------------------------------------------ #
    # 9d. task_completion  (gorev tamamlama kaniti — NFC/GPS/foto)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE task_completion (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id           uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            task_id             uuid NOT NULL,
            tamamlayan_user_id  uuid NOT NULL,
            tamamlanma_zamani   timestamptz NOT NULL,
            nfc_tag_uid         text,
            gps_lat             numeric(9, 6),
            gps_lng             numeric(9, 6),
            foto_key            text,       -- MinIO obje anahtari
            foto_url            text,
            notlar              text,       -- ('not' SQL anahtar kelimesi oldugu icin 'notlar')
            idempotency_key     text NOT NULL,
            created_at          timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_completion_task
                FOREIGN KEY (task_id, tenant_id)
                REFERENCES task (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_completion_user
                FOREIGN KEY (tamamlayan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- offline cift gonderim korumasi (scan_event ile ayni desen):
            CONSTRAINT uq_completion_tenant_idempotency UNIQUE (tenant_id, idempotency_key)
        );
        """
    )
    op.execute("CREATE INDEX ix_completion_tenant ON task_completion (tenant_id);")
    op.execute("CREATE INDEX ix_completion_task ON task_completion (task_id);")
    op.execute(
        "CREATE INDEX ix_completion_zaman "
        "ON task_completion (tenant_id, tamamlanma_zamani DESC);"
    )

    # ------------------------------------------------------------------ #
    # 10. Row-Level Security
    # ------------------------------------------------------------------ #
    # Politika: satir, oturumdaki app.current_tenant_id ile eslesirse gorunur.
    # current_setting(..., true) => degisken set degilse NULL doner (hata atmaz),
    # NULL karsilastirmasi false uretir => hicbir satir gorunmez (guvenli varsayilan).
    _enable_rls_tenant_table()
    for table in (
        "app_user",
        "shift",
        "checkpoint",
        "patrol_plan",
        "patrol_plan_checkpoint",
        "patrol_window",
        "scan_event",
        "notification",
        "task",
        "task_completion",
    ):
        _enable_rls(table)

    # Backend rolune tablo ayricaliklari:
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO {APP_ROLE};"
    )


def _enable_rls_tenant_table() -> None:
    # tenant tablosunda tenant_id yok; izolasyon id uzerinden.
    op.execute("ALTER TABLE tenant ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE tenant FORCE ROW LEVEL SECURITY;")
    op.execute(
        f"""
        CREATE POLICY tenant_isolation ON tenant
            USING (id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )


def _enable_rls(table: str) -> None:
    op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;")
    op.execute(f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY;")
    op.execute(
        f"""
        CREATE POLICY {table}_isolation ON {table}
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.tenant_id_by_slug(text);")
    for table in (
        "task_completion",
        "task",
        "notification",
        "scan_event",
        "patrol_window",
        "patrol_plan_checkpoint",
        "patrol_plan",
        "checkpoint",
        "shift",
        "app_user",
        "tenant",
    ):
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE;")

    op.execute("DROP TYPE IF EXISTS task_tip;")
    op.execute("DROP TYPE IF EXISTS notification_tip;")
    op.execute("DROP TYPE IF EXISTS patrol_window_durum;")
    op.execute("DROP TYPE IF EXISTS gun_tipi;")
    op.execute("DROP TYPE IF EXISTS user_role;")
    # app_rw rolu ve pgcrypto eklentisi paylasimli olabilecegi icin birakilir.
