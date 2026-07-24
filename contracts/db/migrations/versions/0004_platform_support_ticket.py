"""platform_support_ticket — yonetici → Yonetio ekibi destek kanali (0004).

Minimal v1, salt-metin: yonetici konu+aciklama ile bilet acar; platform
admin'i durum (acik|cozuldu) + admin_cevap ile yanitlar. Kisisel veri
DEGERI icermez (konu/aciklama serbest metin — kullanicinin kendi beyani).

* Tenant-ici erisim RLS ile (diger tablolarla ayni policy deseni).
* Admin (platform) capraz-tenant okuma `support_ticket_list` SECURITY
  DEFINER fonksiyonuyla (owner=superuser → RLS bypass; audit_log_list /
  list_all_tenants deseni). Admin yaniti da SECURITY DEFINER
  `support_ticket_answer` ile (admin tenant-token'siz calisir).

URETIM: additive + geriye-uyumlu; 0001-0003 IMMUTABLE, uzerine ILERI-YONLU
(yalniz yeni tablo + fonksiyonlar; mevcut veriye dokunmaz).
"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "0004_platform_support_ticket"
down_revision = "0003_transparency_publication"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

_LIST_FN = "public.support_ticket_list(uuid, text, integer, integer)"
_ANSWER_FN = "public.support_ticket_answer(uuid, text, text)"


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE platform_support_ticket (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            -- FK yok (audit ile ayni gerekce): acan kullanici silinse/
            -- anonimlesse de bilet kaydi bagimsiz kalir.
            acan_user_id  uuid NOT NULL,
            konu          text NOT NULL,
            aciklama      text NOT NULL,
            durum         text NOT NULL DEFAULT 'acik'
                          CHECK (durum IN ('acik', 'cozuldu')),
            admin_cevap   text,
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_support_ticket_tenant_created "
        "ON platform_support_ticket (tenant_id, created_at DESC);"
    )
    # RLS: tenant-kapsamli (yonetici kendi tenant biletlerini gorur/acar).
    op.execute("ALTER TABLE platform_support_ticket ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE platform_support_ticket FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY platform_support_ticket_isolation ON platform_support_ticket
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    # app_rw: SELECT + INSERT yeter (yonetici acar/okur; durum/cevap guncellemesi
    # YALNIZ admin'in SECURITY DEFINER fonksiyonundan gecer → UPDATE grant YOK).
    op.execute(
        f"GRANT SELECT, INSERT ON platform_support_ticket TO {APP_ROLE};"
    )

    # Admin capraz-tenant liste (audit_log_list deseni).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.support_ticket_list(
            p_tenant_id uuid,
            p_durum     text,
            p_limit     integer,
            p_offset    integer
        )
        RETURNS TABLE(
            id uuid, tenant_id uuid, tenant_ad text, acan_user_id uuid,
            konu text, aciklama text, durum text, admin_cevap text,
            created_at timestamptz, updated_at timestamptz, total bigint
        )
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            WITH f AS (
                SELECT s.*, t.ad AS tenant_ad
                FROM public.platform_support_ticket s
                JOIN public.tenant t ON t.id = s.tenant_id
                WHERE (p_tenant_id IS NULL OR s.tenant_id = p_tenant_id)
                  AND (p_durum     IS NULL OR s.durum     = p_durum)
            )
            SELECT id, tenant_id, tenant_ad, acan_user_id, konu, aciklama,
                   durum, admin_cevap, created_at, updated_at,
                   count(*) OVER() AS total
            FROM f
            ORDER BY created_at DESC
            LIMIT COALESCE(p_limit, 50) OFFSET COALESCE(p_offset, 0);
        $$;
        """
    )
    # Admin yaniti/durum degisikligi — tek satir, degisen satiri doner
    # (bulunamazsa bos → API 404 uretir).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.support_ticket_answer(
            p_id     uuid,
            p_durum  text,
            p_cevap  text
        )
        RETURNS TABLE(
            id uuid, tenant_id uuid, acan_user_id uuid, konu text,
            aciklama text, durum text, admin_cevap text,
            created_at timestamptz, updated_at timestamptz
        )
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            UPDATE public.platform_support_ticket s
            SET durum       = COALESCE(p_durum, s.durum),
                admin_cevap = COALESCE(p_cevap, s.admin_cevap),
                updated_at  = now()
            WHERE s.id = p_id
              AND (p_durum IS NULL OR p_durum IN ('acik', 'cozuldu'))
            RETURNING s.id, s.tenant_id, s.acan_user_id, s.konu, s.aciklama,
                      s.durum, s.admin_cevap, s.created_at, s.updated_at;
        $$;
        """
    )
    # Fonksiyonlar yalniz app rolune (API katmanindaki RBAC admin'i zorlar;
    # PUBLIC'ten cek — SECURITY DEFINER hijyeni).
    for fn in (_LIST_FN, _ANSWER_FN):
        op.execute(f"REVOKE ALL ON FUNCTION {fn} FROM PUBLIC;")
        op.execute(f"GRANT EXECUTE ON FUNCTION {fn} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute(f"DROP FUNCTION IF EXISTS {_ANSWER_FN};")
    op.execute(f"DROP FUNCTION IF EXISTS {_LIST_FN};")
    op.execute("DROP TABLE IF EXISTS platform_support_ticket;")
