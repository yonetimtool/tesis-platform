"""(P224) Tesis silme ozeti + arsiv anahtari — SECURITY DEFINER.

===========================================================================
NEDEN FONKSIYON, NEDEN DUZ SORGU DEGIL
===========================================================================
Ilk yazimda ozet sorgusunu uc icinde duz SQL olarak kostum ve ANINDA
patladi:

    asyncpg.exceptions.InvalidTextRepresentationError:
    invalid input syntax for type uuid: ""

Sebep: bu uclar PLATFORM uclarıdır ve tenant baglami OLMADAN calisir;
`tenant` RLS politikasi `id = current_setting('app.current_tenant_id')`
diyor, ayar bos olunca cast patliyor. Yani platform admini BASKA bir
tesisin satirlarini RLS altinda zaten sayamaz.

Depodaki butun platform uclari bu yuzden SECURITY DEFINER fonksiyondan
gecer (`list_all_tenants`, `delete_tenant`, `tenant_uyelikleri`...).
Ayni deseni izliyoruz.
"""
from alembic import op

revision = "0129_tesis_ozet_ve_arsiv_fn"
down_revision = "0128_arsiv_gorunurlugu"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

OZET = """
CREATE OR REPLACE FUNCTION public.tenant_silme_ozeti(p_tid uuid)
RETURNS TABLE(ad text, slug text, arsivlendi_at timestamptz,
              kullanici int, daire int, finans int, sikayet int,
              belge int, denetim int, platform_admin int)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
    -- SAYILAR TEMSILI: 100 cascade tablosunun hepsini saymak hem yavas
    -- hem okunmaz olurdu. Kullanicinin "bunu gercekten silecek miyim"
    -- sorusunu yanitlayacak olanlar secildi.
    SELECT t.ad, t.slug, t.arsivlendi_at,
      (SELECT count(*)::int FROM app_user         WHERE tenant_id = t.id),
      (SELECT count(*)::int FROM unit             WHERE tenant_id = t.id),
      (SELECT count(*)::int FROM finansal_hareket WHERE tenant_id = t.id),
      (SELECT count(*)::int FROM complaint        WHERE tenant_id = t.id),
      (SELECT count(*)::int FROM tenant_dokuman   WHERE tenant_id = t.id),
      (SELECT count(*)::int FROM audit_log        WHERE tenant_id = t.id),
      (SELECT count(*)::int FROM app_user
         WHERE tenant_id = t.id AND role = 'admin'::user_role)
    FROM tenant t WHERE t.id = p_tid;
$$;
"""

ARSIV = """
CREATE OR REPLACE FUNCTION public.tenant_arsiv_ayarla(
    p_tid uuid, p_arsivle boolean
) RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v timestamptz;
BEGIN
    UPDATE public.tenant
       SET arsivlendi_at = CASE WHEN p_arsivle THEN now() ELSE NULL END
     WHERE id = p_tid
    RETURNING arsivlendi_at INTO v;
    RETURN v;
END;
$$;
"""


def upgrade() -> None:
    for sql, imza in (
        (OZET, "public.tenant_silme_ozeti(uuid)"),
        (ARSIV, "public.tenant_arsiv_ayarla(uuid, boolean)"),
    ):
        op.execute(sql)
        op.execute(f"REVOKE ALL ON FUNCTION {imza} FROM PUBLIC;")
        op.execute(f"GRANT EXECUTE ON FUNCTION {imza} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.tenant_arsiv_ayarla(uuid, boolean);")
    op.execute("DROP FUNCTION IF EXISTS public.tenant_silme_ozeti(uuid);")
