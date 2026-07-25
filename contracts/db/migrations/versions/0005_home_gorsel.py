"""home_gorsel (0005) — ana ekran gorsel zenginlestirme semasi.

* tenant.konum_ad/lat/lon : hava durumu konumu (varsayilan Istanbul).
* app_user.avatar_key     : personel profil fotografi (MinIO anahtari;
                            yalniz personel rolleri yukler — API katmani zorlar).
* shift_assignment        : vardiya <-> personel atamasi (yonetici atar).
* camera                  : site kamera yayin URL'leri (istemci oynatir;
                            backend yayini HIC cekmez — SSRF yuzeyi yok).
                            ad/konum/stream_url/tur/aktif/sakin_gorebilir —
                            sakin gorunurlugu YALNIZ sakin_gorebilir ile acilir
                            (varsayilan false).

URETIM: additive + geriye-uyumlu; 0001-0004 IMMUTABLE.
"""
from alembic import op

revision = "0005_home_gorsel"
down_revision = "0004_platform_support_ticket"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE tenant
            ADD COLUMN konum_ad  text NOT NULL DEFAULT 'İstanbul',
            ADD COLUMN konum_lat numeric(9,6) NOT NULL DEFAULT 41.0082,
            ADD COLUMN konum_lon numeric(9,6) NOT NULL DEFAULT 28.9784;
        """
    )
    op.execute("ALTER TABLE app_user ADD COLUMN avatar_key text;")

    op.execute(
        """
        CREATE TABLE shift_assignment (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            shift_id   uuid NOT NULL,
            user_id    uuid NOT NULL,
            created_at timestamptz NOT NULL DEFAULT now(),
            UNIQUE (tenant_id, shift_id, user_id),
            FOREIGN KEY (shift_id, tenant_id)
                REFERENCES shift (id, tenant_id) ON DELETE CASCADE,
            -- personel siteden cikinca atama otomatik duser
            FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    # Yayin turu: hls/mp4 istemcide OYNAR; rtsp saklanir ama native
    # oynatilamaz (API `oynatilabilir=false` isaretler — ileride medya gecidi).
    op.execute("CREATE TYPE camera_tur AS ENUM ('hls', 'mp4', 'rtsp');")
    op.execute(
        """
        CREATE TABLE camera (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad         text NOT NULL,
            -- Serbest konum metni (orn. "Ana Kapı - Giriş").
            konum      text,
            stream_url text NOT NULL,
            tur        camera_tur NOT NULL DEFAULT 'hls',
            -- Pasif kamera hicbir sakine/gorevliye gosterilmez (yonetim gorur).
            aktif      boolean NOT NULL DEFAULT true,
            -- KVKK ANAHTARI: sakin/tesis gorevlisi gorunurlugu YALNIZ bu
            -- bayrakla acilir; varsayilan KAPALI (kamera mahremiyet tasir).
            sakin_gorebilir boolean NOT NULL DEFAULT false,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            UNIQUE (tenant_id, ad)
        );
        """
    )
    # Sakine acik + aktif kamera listesi en sik sorgu (ana ekran seridi).
    op.execute(
        "CREATE INDEX ix_camera_tenant_gorunur ON camera "
        "(tenant_id, aktif, sakin_gorebilir);"
    )
    for table in ("shift_assignment", "camera"):
        op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {table}_isolation ON {table}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
    # Atama declarative-replace: SELECT+INSERT+DELETE yeter (UPDATE yok).
    op.execute(f"GRANT SELECT, INSERT, DELETE ON shift_assignment TO {APP_ROLE};")
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON camera TO {APP_ROLE};")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS camera;")
    op.execute("DROP TYPE IF EXISTS camera_tur;")
    op.execute("DROP TABLE IF EXISTS shift_assignment;")
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS avatar_key;")
    op.execute(
        "ALTER TABLE tenant DROP COLUMN IF EXISTS konum_ad, "
        "DROP COLUMN IF EXISTS konum_lat, DROP COLUMN IF EXISTS konum_lon;"
    )
