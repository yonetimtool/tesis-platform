"""(P225) Tesis listesi: arama + kurulum suzgeci + platform admin bayragi.

===========================================================================
ARAMA SUNUCUDA — VE NEDEN
===========================================================================
Bugun 8 tesis var; istemcide suzmek de calisirdi. Sunucu secildi cunku:

  * Suzgec VERININ YANINDA durursa, sayfalama eklendigi gun arama
    TASINMAK ZORUNDA KALMAZ. Istemcide suzen bir liste, ilk sayfalama
    denemesinde "yalniz bu sayfada ara" haline duser ve bu SESSIZ bir
    gerilemedir.
  * TURKCE HARF KATLAMASI TEK KURAL OLMALI. Dukkan aramasi ayni sorunu
    `slug` uzerinden cozdu (`ad ILIKE :q OR slug LIKE :qs`); tesis
    tablosunda da ASCII katlanmis `slug` ZATEN VAR (`slugify_tenant`).
    Istemcide ikinci bir katlama yazmak, iki yerde iki farkli "cekmekoy"
    tanimi demekti.

"arikoy" -> `Arıköy Sitesi`in slug'i `arikoy-sitesi-xxxxxx` oldugu icin
`slug LIKE '%arikoy%'` ile bulunur. Ad alani ILIKE ile ayrica taranir
(Turkce klavyesi olan kullanici "Arıköy" yazinca da bulsun).

===========================================================================
PLATFORM ADMIN BAYRAGI — LISTEDE, SATIR BASINA SORGU YOK
===========================================================================
Panel, platform admini barindiran tesiste Sil dugmesini HIC cizmeyecek.
Bunu ogrenmenin alternatifi her satir icin `silme-ozeti` cagirmakti —
8 tesiste 8 istek, 200 tesiste 200. Bayrak listenin kendisinde doner.
"""
from alembic import op

revision = "0130_tesis_listesi_arama"
down_revision = "0129_tesis_ozet_ve_arsiv_fn"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.list_all_tenants(boolean);")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.list_all_tenants(
            p_arsivli boolean DEFAULT false,
            p_q text DEFAULT NULL,
            p_qs text DEFAULT NULL,
            p_kurulum boolean DEFAULT NULL
        )
        RETURNS TABLE(id uuid, ad text, kayit_kodu text,
                      kurulum_tamamlandi boolean, created_at timestamptz,
                      arsivlendi_at timestamptz, platform_admin int)
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path TO 'public', 'pg_temp'
        AS $function$
            SELECT t.id, t.ad, t.kayit_kodu, t.kurulum_tamamlandi,
                   t.created_at, t.arsivlendi_at,
                   (SELECT count(*)::int FROM public.app_user u
                     WHERE u.tenant_id = t.id
                       AND u.role = 'admin'::public.user_role)
            FROM public.tenant t
            -- VARSAYILAN: yalniz AKTIF tesisler (arsiv ayri bir gorunum).
            WHERE ((p_arsivli AND t.arsivlendi_at IS NOT NULL)
                OR (NOT p_arsivli AND t.arsivlendi_at IS NULL))
              -- ARAMA: ad (Turkce klavyeyle yazan icin) VEYA slug (ASCII
              -- katlanmis; "cekmekoy" -> "Çekmeköy") VEYA kayit kodu.
              AND (p_q IS NULL
                   OR t.ad ILIKE p_q
                   OR t.slug LIKE p_qs
                   OR t.kayit_kodu ILIKE p_q)
              AND (p_kurulum IS NULL OR t.kurulum_tamamlandi = p_kurulum)
            ORDER BY t.created_at DESC;
        $function$;
        """
    )
    imza = "public.list_all_tenants(boolean, text, text, boolean)"
    op.execute(f"REVOKE ALL ON FUNCTION {imza} FROM PUBLIC;")
    op.execute(f"GRANT EXECUTE ON FUNCTION {imza} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute(
        "DROP FUNCTION IF EXISTS "
        "public.list_all_tenants(boolean, text, text, boolean);"
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.list_all_tenants(
            p_arsivli boolean DEFAULT false
        )
        RETURNS TABLE(id uuid, ad text, kayit_kodu text,
                      kurulum_tamamlandi boolean, created_at timestamptz,
                      arsivlendi_at timestamptz)
        LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
        AS $function$
            SELECT id, ad, kayit_kodu, kurulum_tamamlandi, created_at,
                   arsivlendi_at
            FROM public.tenant
            WHERE (p_arsivli AND arsivlendi_at IS NOT NULL)
               OR (NOT p_arsivli AND arsivlendi_at IS NULL)
            ORDER BY created_at DESC;
        $function$;
        """
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.list_all_tenants(boolean) "
        f"TO {APP_ROLE};"
    )
