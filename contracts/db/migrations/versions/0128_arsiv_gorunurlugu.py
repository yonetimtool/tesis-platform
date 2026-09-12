"""(P224) ARSIVLENMIS TESIS HICBIR YERDE GORUNMEZ.

===========================================================================
GORUNURLUK NEREDE KESILIYOR — VE NEDEN RLS'TE DEGIL
===========================================================================
Ilk aklima gelen, `tenant` RLS politikasina `arsivlendi_at IS NULL`
eklemekti. YANLIS OLURDU ve sebebi olculebilir:

  * `tenant` politikasi yalniz TENANT SATIRINI gizler. Veri 100 ayri
    tabloda ve her birinin KENDI politikasi `tenant_id` uzerinden
    calisiyor — tesis satiri gorunmese de `unit`, `complaint`,
    `finansal_hareket` gorunmeye devam ederdi.
  * Cozum "100 politikaya da ekleyelim" degil: her YENI tablo bu sarti
    sessizce unutur ve kimse fark etmez. Tam olarak bu depoda birden
    cok kez yasanmis bir kusur sinifi.

DOGRU YER KIMLIK SINIRIDIR: arsivli bir tesise ait TOKEN URETILEMEZ.
Veri katmanina hic gelinmez.

  1. `tenant_uyelikleri` (SECURITY DEFINER) — TUM giris yollarinin
     (parola, telefon, "tesislerim") tek gectigi yer. Arsivli tesis
     buradan DUSER, yani hicbir giris yolu onu goremez.
  2. Yenileme (refresh) ucunda ayri bir denetim var (routers/auth.py):
     arsivlenmeden ONCE alinmis bir oturum, yenilemede reddedilir.
  3. Erisim jetonu KISA OMURLU: arsivleme ile tam kopus arasinda en
     fazla o kadar sure gecer. Bunu "anlik" yapmak her istege bir
     sorgu eklemek demekti; arsivleme yikici olmayan ve geri
     alinabilir bir islem oldugu icin o bedel hakli degil.

`list_all_tenants` ARTIK SUZGECLI: platform admini arsivlileri ancak
ACIKCA isteyince gorur (`p_arsivli => true`), yani "tesisler" listesi
arsivi kazara icermez.
"""
from alembic import op

revision = "0128_arsiv_gorunurlugu"
down_revision = "0127_birincil_uyelik_tek"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 1) GIRIS YOLU — arsivli tesis uyelik listesinde GORUNMEZ
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_uyelikleri(p_kimlik text)
        RETURNS TABLE(tenant_id uuid, slug text, tenant_ad text, user_id uuid,
                      rol text, is_active boolean, password_hash text,
                      eposta_dogrulandi boolean)
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path TO 'public', 'pg_temp'
        AS $function$
            SELECT t.id, t.slug, t.ad, u.id, u.role::text, u.is_active,
                   u.password_hash, u.eposta_dogrulandi
            FROM app_user u
            JOIN tenant t ON t.id = u.tenant_id
            -- (P224) ARSIVLI TESIS GIRISE KAPALI. Suzgec BURADA cunku
            -- butun giris yollari (parola, telefon, "tesislerim") bu
            -- fonksiyondan geciyor; cagiranlara tek tek eklemek, birini
            -- unutmak demekti.
            WHERE t.arsivlendi_at IS NULL
              AND (lower(u.email) = lower(btrim(p_kimlik))
                   OR u.telefon = btrim(p_kimlik))
            ORDER BY t.ad;
        $function$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.tenant_uyelikleri(text) FROM PUBLIC;")
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.tenant_uyelikleri(text) TO {APP_ROLE};"
    )

    # ------------------------------------------------------------------ #
    # 2) TESIS LISTESI — arsivliler ACIKCA istenmedikce gelmez
    # ------------------------------------------------------------------ #
    op.execute("DROP FUNCTION IF EXISTS public.list_all_tenants();")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.list_all_tenants(
            p_arsivli boolean DEFAULT false
        )
        RETURNS TABLE(id uuid, ad text, kayit_kodu text,
                      kurulum_tamamlandi boolean, created_at timestamptz,
                      arsivlendi_at timestamptz)
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path TO 'public', 'pg_temp'
        AS $function$
            SELECT id, ad, kayit_kodu, kurulum_tamamlandi, created_at,
                   arsivlendi_at
            FROM public.tenant
            -- VARSAYILAN: yalniz AKTIF tesisler. Arsiv ayri bir ekrandir;
            -- ayni listeye karistirmak, silinmis sandigi bir tesisi
            -- listede goren yoneticiye "silinmemis" dedirtirdi.
            WHERE (p_arsivli AND arsivlendi_at IS NOT NULL)
               OR (NOT p_arsivli AND arsivlendi_at IS NULL)
            ORDER BY created_at DESC;
        $function$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.list_all_tenants(boolean) FROM PUBLIC;"
    )
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.list_all_tenants(boolean) TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.list_all_tenants(boolean);")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.list_all_tenants()
        RETURNS TABLE(id uuid, ad text, kayit_kodu text,
                      kurulum_tamamlandi boolean, created_at timestamptz)
        LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
        AS $function$
            SELECT id, ad, kayit_kodu, kurulum_tamamlandi, created_at
            FROM public.tenant ORDER BY created_at DESC;
        $function$;
        """
    )
    op.execute(f"GRANT EXECUTE ON FUNCTION public.list_all_tenants() TO {APP_ROLE};")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_uyelikleri(p_kimlik text)
        RETURNS TABLE(tenant_id uuid, slug text, tenant_ad text, user_id uuid,
                      rol text, is_active boolean, password_hash text,
                      eposta_dogrulandi boolean)
        LANGUAGE sql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
        AS $function$
            SELECT t.id, t.slug, t.ad, u.id, u.role::text, u.is_active,
                   u.password_hash, u.eposta_dogrulandi
            FROM app_user u JOIN tenant t ON t.id = u.tenant_id
            WHERE lower(u.email) = lower(btrim(p_kimlik))
               OR u.telefon = btrim(p_kimlik)
            ORDER BY t.ad;
        $function$;
        """
    )
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.tenant_uyelikleri(text) TO {APP_ROLE};"
    )
