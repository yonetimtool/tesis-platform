"""(P155 / §6) Tesis kodu panelde birincil — `list_all_tenants` + `tenant_detail`.

===========================================================================
OLCULEN KUSUR
===========================================================================
Panel "Tesisler" listesindeki "Kimlik (ID)" sutunu tenant UUID'sini
gosteriyordu (`18d9fb6c-e72a-...`). Oysa yoneticinin sakine/personele
ILETECEGI sey `kayit_kodu`dur (`OLTU-260715`). Yani panel, ise yarayan
tanimlayiciyi HIC gostermiyor, teknik olani birincil yapiyordu.

Iki SECURITY DEFINER gorunum fonksiyonu `kayit_kodu`yu DONMUYORDU; bu goc
onu ekler. Fonksiyonlar `0001`de tanimliydi ama MIGRATION-POLITIKASI
geregi yerinde duzenlenmez — yeni revizyon.

===========================================================================
NEDEN DROP + CREATE (CREATE OR REPLACE DEGIL)
===========================================================================
Iki fonksiyonun da RETURNS TABLE(...) imzasi DEGISIYOR (yeni sutun).
PostgreSQL `CREATE OR REPLACE FUNCTION` ile donus tipini degistirmeye izin
VERMEZ ("cannot change return type of existing function"). Bu yuzden once
DROP, sonra CREATE. `downgrade` eski (kodsuz) imzayi ayni sekilde geri
kurar; `goc-tersinirlik.sh` zincirini yesil tutar.

GRANT'lar YENIDEN yazilir: DROP, izinleri de dusurur.
"""
from alembic import op

revision = "0050_tesis_kodu_panelde"
down_revision = "0049_daire_rol_tekilligi"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    # --- list_all_tenants: + kayit_kodu ---
    op.execute("DROP FUNCTION IF EXISTS public.list_all_tenants();")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.list_all_tenants()
        RETURNS TABLE(id uuid, ad text, kayit_kodu text,
                      kurulum_tamamlandi boolean, created_at timestamptz)
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT id, ad, kayit_kodu, kurulum_tamamlandi, created_at
            FROM public.tenant ORDER BY created_at DESC;
        $$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.list_all_tenants() FROM PUBLIC;")
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.list_all_tenants() TO {APP_ROLE};"
    )

    # --- tenant_detail: + tenant_kayit_kodu ---
    op.execute("DROP FUNCTION IF EXISTS public.tenant_detail(uuid);")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_detail(p_tenant_id uuid)
        RETURNS TABLE(
            tenant_id uuid, tenant_ad text, tenant_kayit_kodu text,
            kurulum_tamamlandi boolean, tenant_created_at timestamptz,
            yonetici_id uuid, yonetici_ad text, telefon text,
            is_active boolean, password_set boolean)
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT t.id, t.ad, t.kayit_kodu, t.kurulum_tamamlandi, t.created_at,
                   u.id, u.ad, u.telefon, u.is_active, u.password_set
            FROM public.tenant t
            LEFT JOIN LATERAL (
                SELECT id, ad, telefon, is_active, password_set
                FROM public.app_user
                WHERE tenant_id = t.id
                  AND role = 'yonetici'::public.user_role
                  AND birincil
                LIMIT 1
            ) u ON true
            WHERE t.id = p_tenant_id;
        $$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.tenant_detail(uuid) FROM PUBLIC;")
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.tenant_detail(uuid) TO {APP_ROLE};"
    )


def downgrade() -> None:
    # 0001'deki imzalari (kayit_kodu'suz) geri kur.
    op.execute("DROP FUNCTION IF EXISTS public.list_all_tenants();")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.list_all_tenants()
        RETURNS TABLE(id uuid, ad text, kurulum_tamamlandi boolean,
                      created_at timestamptz)
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT id, ad, kurulum_tamamlandi, created_at
            FROM public.tenant ORDER BY created_at DESC;
        $$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.list_all_tenants() FROM PUBLIC;")
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.list_all_tenants() TO {APP_ROLE};"
    )

    op.execute("DROP FUNCTION IF EXISTS public.tenant_detail(uuid);")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_detail(p_tenant_id uuid)
        RETURNS TABLE(
            tenant_id uuid, tenant_ad text, kurulum_tamamlandi boolean,
            tenant_created_at timestamptz, yonetici_id uuid, yonetici_ad text,
            telefon text, is_active boolean, password_set boolean)
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT t.id, t.ad, t.kurulum_tamamlandi, t.created_at,
                   u.id, u.ad, u.telefon, u.is_active, u.password_set
            FROM public.tenant t
            LEFT JOIN LATERAL (
                SELECT id, ad, telefon, is_active, password_set
                FROM public.app_user
                WHERE tenant_id = t.id
                  AND role = 'yonetici'::public.user_role
                  AND birincil
                LIMIT 1
            ) u ON true
            WHERE t.id = p_tenant_id;
        $$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.tenant_detail(uuid) FROM PUBLIC;")
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.tenant_detail(uuid) TO {APP_ROLE};"
    )
