"""(P180) yonetici_by_email — e-posta ile YONETICI hesap eslesmesi (SSO kayit)

SSO ile yonetici kaydinda (niyet=kayit), sosyal kimlik henuz bir hesaba bagli
degilse, saglayicidan gelen e-postanin zaten bir YONETICI hesabina ait olup
olmadigi sorulur (kriter 4: yeni hesap acma, mevcuda bagla + giris).

RLS BOOTSTRAP: kullanicinin oturumu/tenant'i yok -> SECURITY DEFINER; tenant_id
_by_phone / tenant_id_by_oauth ile AYNI SINIF. search_path = '' + REVOKE PUBLIC +
GRANT app_rw: sizinti yuzeyi minimal.

YALNIZ role='yonetici' ve is_active: e-posta tesis-kapsamli benzersizdir (global
DEGIL); farkli baglamdaki (sakin) hesaba yanlis baglamayi onler. SETOF: birden cok
tesis yoneten kisi COK satir dondurur; cagiran YALNIZ TEK eslesmede baglar, aksi
halde yeni kayit acar (bkz. docs/P180-kararlar.md D5).

Revision ID: 0069_yonetici_by_email
Revises: 0068_yeni_kayit_akisi
Create Date: 2026-08-26
"""
from alembic import op

revision = "0069_yonetici_by_email"
down_revision = "0068_yeni_kayit_akisi"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.yonetici_by_email(p_eposta text)
        RETURNS TABLE (tenant_id uuid, user_id uuid)
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT tenant_id, id FROM public.app_user
             WHERE lower(email) = lower(p_eposta)
               AND role = 'yonetici'::public.user_role
               AND is_active = true
        $$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.yonetici_by_email(text) FROM PUBLIC;")
    op.execute(f"GRANT EXECUTE ON FUNCTION public.yonetici_by_email(text) TO {APP_ROLE};")


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.yonetici_by_email(text);")
