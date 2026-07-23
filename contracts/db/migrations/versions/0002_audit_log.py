"""audit_log — KVKK degistirilemez (append-only) denetim kaydi.

WP1: kimlik olaylari + kisisel-veri kaynaklarindaki YAZMA islemleri + telefon
ifsasi/arama baslatma + foto presign-GET icin degistirilemez iz. Tasarim:
  * app_rw YALNIZ INSERT + SELECT alir; UPDATE/DELETE `setup_app_role.py`'de
    REVOKE edilir (blanket GRANT her migrate sonrasi kostugundan REVOKE orada
    olmali). Boylece uygulama denetim satirini DEGISTIREMEZ/SILEMEZ.
  * Admin (platform) capraz-tenant okuma `audit_log_list` SECURITY DEFINER
    fonksiyonuyla (owner=superuser → RLS bypass; mevcut list_all_tenants deseni).
  * Saklama purge'u (24 ay) YALNIZ owner ile calisir (retention task), app_rw ile
    degil — append-only iddiasi boyle korunur.

URETIM: additive + geriye-uyumlu; 0001 uzerine ILERI-YONLU uygulanir (yeni tablo
+ fonksiyon; mevcut veriye dokunmaz). Dev `down -v` ile geri alinabilir.
"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "0002_audit_log"
down_revision = "0001_initial_schema"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

_FN_SIG = (
    "public.audit_log_list(uuid, text, text, timestamptz, timestamptz, "
    "integer, integer)"
)


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE audit_log (
            id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ts             timestamptz NOT NULL DEFAULT now(),
            -- platform (tenant-siz) olaylar icin NULL olabilir; tenant silinince
            -- o tenant'in denetim satirlari da gider (diger tablolarla tutarli).
            tenant_id      uuid REFERENCES tenant (id) ON DELETE CASCADE,
            -- FK YOK (bilincli): kullanici anonimlestirilse/silinse de iz kalir;
            -- audit bagimsiz bir defterdir.
            actor_user_id  uuid,
            actor_rol      text,
            -- action serbest-metin enum-benzeri: login_ok, login_fail,
            -- <resource>_create/update/delete, phone_reveal, call_initiate,
            -- export, erasure_run, ...
            action         text NOT NULL,
            resource_type  text,
            resource_id    text,
            -- KVKK: YALNIZ id'ler ve alan ADLARI; ASLA kisisel veri DEGERI tutulmaz.
            meta           jsonb NOT NULL DEFAULT '{}'::jsonb
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_audit_log_tenant_ts ON audit_log (tenant_id, ts DESC);"
    )
    op.execute(
        "CREATE INDEX ix_audit_log_resource "
        "ON audit_log (resource_type, resource_id);"
    )
    # Admin capraz-tenant zaman sorgusu (tenant filtresiz) icin.
    op.execute("CREATE INDEX ix_audit_log_ts ON audit_log (ts DESC);")

    # RLS: tenant-kapsamli (defense-in-depth). app_rw dogrudan INSERT ederken
    # tenant baglami set olur (WITH CHECK gecer). Owner (SECURITY DEFINER /
    # retention) superuser oldugundan RLS'i bypass eder.
    op.execute("ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE audit_log FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY audit_log_isolation ON audit_log
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )

    # app_rw: INSERT + SELECT. UPDATE/DELETE VERILMEZ — ayrica setup_app_role.py
    # blanket GRANT sonrasi REVOKE ederek append-only'i kesinlestirir.
    op.execute(f"GRANT SELECT, INSERT ON audit_log TO {APP_ROLE};")

    # Admin (platform) capraz-tenant denetim okuyucusu. RLS FORCE oldugundan
    # app_rw yalniz kendi tenant'ini gorur; bu owner-sahipli SECURITY DEFINER
    # fonksiyon TUM tenant'lari (istege bagli filtreyle) doner. API yalniz
    # admin'e acar (RBAC). count(*) OVER() => sayfalama icin total.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.audit_log_list(
            p_tenant_id     uuid,
            p_action        text,
            p_resource_type text,
            p_from          timestamptz,
            p_to            timestamptz,
            p_limit         integer,
            p_offset        integer
        )
        RETURNS TABLE(
            id uuid, ts timestamptz, tenant_id uuid, actor_user_id uuid,
            actor_rol text, action text, resource_type text, resource_id text,
            meta jsonb, total bigint
        )
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            WITH f AS (
                SELECT * FROM public.audit_log a
                WHERE (p_tenant_id     IS NULL OR a.tenant_id     = p_tenant_id)
                  AND (p_action        IS NULL OR a.action        = p_action)
                  AND (p_resource_type IS NULL OR a.resource_type = p_resource_type)
                  AND (p_from          IS NULL OR a.ts >= p_from)
                  AND (p_to            IS NULL OR a.ts <  p_to)
            )
            SELECT id, ts, tenant_id, actor_user_id, actor_rol, action,
                   resource_type, resource_id, meta,
                   count(*) OVER() AS total
            FROM f
            ORDER BY ts DESC
            LIMIT COALESCE(p_limit, 50) OFFSET COALESCE(p_offset, 0);
        $$;
        """
    )
    op.execute(f"REVOKE ALL ON FUNCTION {_FN_SIG} FROM PUBLIC;")
    op.execute(f"GRANT EXECUTE ON FUNCTION {_FN_SIG} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute(f"DROP FUNCTION IF EXISTS {_FN_SIG};")
    op.execute("DROP TABLE IF EXISTS audit_log;")
