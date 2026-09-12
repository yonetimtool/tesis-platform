"""(P224) TESIS SILME KORUMASI — son platform admini + arsivleme.

===========================================================================
OLCULEN KAZA
===========================================================================
Prod'da "Yönetio Platform" tesisi silindi. Platform admin hesabi o
tesise bagliydi ve `ON DELETE CASCADE` ile gitti:

    SELECT ... FROM app_user WHERE role='admin'  ->  0 satir

Panele girilemez hale gelindi. Sistem HICBIR NOKTADA DIRENMEDI:
son admin korumasi yok, kendi tesisini silme engeli yok, onemlisi
onay kelimesi her tesiste ayni ("SİL") oldugu icin yanlis tesisi
silmeye karsi hicbir sey yapmiyordu.

===========================================================================
NEDEN TRIGGER — UYGULAMA KATMANI YETMEZ
===========================================================================
Uc katmanindaki bir kontrol ATLANABILIR: `psql`, bir goc, bir bakim
betigi ya da ileride yazilacak baska bir uc. Bu kaza TEK BIR HESABIN
kaybiyla TUM PLATFORMU yonetilemez birakti; korumanin veritabaninda
olmasi gerekiyor.

IKI YONLU, cunku kaza dogrudan silmeyle degil DOLAYLI oldu:
  (a) `app_user` uzerinde: son `role='admin'` satiri SILINEMEZ,
  (b) `tenant` uzerinde: icinde platform admini olan tesis SILINEMEZ.
(b) olmadan (a) tek basina bugunku kazayi TEKRAR yasatirdi: kimse
admini silmedi, tesisi sildi.

===========================================================================
ARSIVLEME (yumusak silme) — COP KUTUSU DEGIL
===========================================================================
`tenant.arsivlendi_at` eklendi. Secim gerekcesi:

  * COP KUTUSU (satirlari ayri bir tabloya tasimak) 100 cascade
    tablosunun tamamini kopyalamayi ve geri yazmayi gerektirirdi;
    her yeni tablo bu mekanizmayi sessizce eksik birakirdi.
  * YUMUSAK SILME tek kolon: veri YERINDE kalir, hicbir FK kirilmaz,
    geri getirmek tek UPDATE'tir.

Maliyeti: her sorgunun "arsivli mi" suzgecini tasimasi gerekir. Bunu
tek yerde cozuyoruz — RLS politikasi (asagida).
"""
from alembic import op

revision = "0126_tesis_silme_korumasi"
down_revision = "0125_dukkan_odeme"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 1) ARSIV KOLONU
    # ------------------------------------------------------------------ #
    op.execute(
        "ALTER TABLE public.tenant "
        "ADD COLUMN IF NOT EXISTS arsivlendi_at timestamptz NULL"
    )
    op.execute(
        "COMMENT ON COLUMN public.tenant.arsivlendi_at IS "
        "'(P224) Dolu ise tesis ARSIVDE: hicbir yuzeyde gorunmez, girisi "
        "kapalidir. Veri YERINDE durur; geri getirmek tek UPDATE.'"
    )

    # ------------------------------------------------------------------ #
    # 2) SON PLATFORM ADMINI SILINEMEZ  (app_user)
    # ------------------------------------------------------------------ #
    #
    # `BEFORE DELETE ... FOR EACH ROW`: cascade silmelerde de tetiklenir,
    # yani tesis silinirken admin satirina gelindiginde de calisir. Asil
    # koruma bu — kaza tam oradan gecmisti.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.son_platform_admini_koru()
        RETURNS trigger
        LANGUAGE plpgsql
        -- (P224) SEARCH_PATH SART: trigger fonksiyonu CAGIRANIN
        -- search_path'ini devralir ve uygulama baglantisi `public`i
        -- tasimayabilir. Olculdu: eksikken silme
        -- `type "user_role" does not exist` ile 500 veriyordu — yani
        -- koruma calismiyor, ISLEM DE calismiyordu.
        SET search_path TO 'public', 'pg_temp'
        AS $$
        DECLARE
            kalan integer;
        BEGIN
            IF OLD.role <> 'admin'::public.user_role THEN
                RETURN OLD;
            END IF;
            -- KALAN ADMIN SAYISI: silinecek satir HARIC. Birden cok admin
            -- varken birini silmek MESRU bir istektir ve engellenmemeli;
            -- koruma "her admin dokunulmaz" degil "platform adminsiz
            -- kalmasin" demektir.
            SELECT count(*) INTO kalan
            FROM public.app_user
            WHERE role = 'admin'::public.user_role AND id <> OLD.id;

            IF kalan = 0 THEN
                RAISE EXCEPTION
                    'SON PLATFORM ADMINI SILINEMEZ (app_user.id=%). Once '
                    'baska bir platform admini olusturun.', OLD.id
                    USING ERRCODE = 'restrict_violation';
            END IF;
            RETURN OLD;
        END;
        $$;
        """
    )
    op.execute("DROP TRIGGER IF EXISTS trg_son_platform_admini_koru ON public.app_user")
    op.execute(
        "CREATE TRIGGER trg_son_platform_admini_koru "
        "BEFORE DELETE ON public.app_user "
        "FOR EACH ROW EXECUTE FUNCTION public.son_platform_admini_koru()"
    )

    # ------------------------------------------------------------------ #
    # 3) PLATFORM ADMININ TESISI SILINEMEZ  (tenant)
    # ------------------------------------------------------------------ #
    #
    # (2) tek basina yetmez ve sebebi tam olarak BUGUNKU KAZA: kimse
    # admini silmedi, TESISI sildi. Cascade sirasinda (2) de atesleniyor
    # ama hata mesaji "son admin silinemez" oluyor ve kullanici NEYI
    # yanlis yaptigini anlamiyor. Bu trigger AYRI ve NET konusur.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.admin_tesisini_koru()
        RETURNS trigger
        LANGUAGE plpgsql
        SET search_path TO 'public', 'pg_temp'
        AS $$
        DECLARE
            admin_sayisi integer;
        BEGIN
            SELECT count(*) INTO admin_sayisi
            FROM public.app_user
            WHERE tenant_id = OLD.id AND role = 'admin'::public.user_role;

            IF admin_sayisi > 0 THEN
                RAISE EXCEPTION
                    'PLATFORM ADMININ BAGLI OLDUGU TESIS SILINEMEZ '
                    '(tenant.id=%, admin sayisi=%). Adminleri baska bir '
                    'tesise tasiyin ya da once onlari silin.',
                    OLD.id, admin_sayisi
                    USING ERRCODE = 'restrict_violation';
            END IF;
            RETURN OLD;
        END;
        $$;
        """
    )
    op.execute("DROP TRIGGER IF EXISTS trg_admin_tesisini_koru ON public.tenant")
    op.execute(
        "CREATE TRIGGER trg_admin_tesisini_koru "
        "BEFORE DELETE ON public.tenant "
        "FOR EACH ROW EXECUTE FUNCTION public.admin_tesisini_koru()"
    )


    # ------------------------------------------------------------------ #
    # 4) PLATFORM ADMIN SAYACI — uc katmaninin ANLASILIR mesaj verebilmesi
    # ------------------------------------------------------------------ #
    #
    # Trigger asil korumadir ama `restrict_violation` kullaniciya hicbir
    # sey anlatmaz. Uc, silmeden ONCE sorup net bir cumle kurabilsin diye
    # bu sayac var. RLS tenant'a kilitli oldugu icin SECURITY DEFINER.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.platform_admin_sayisi(
            p_haric uuid DEFAULT NULL
        ) RETURNS integer
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path TO 'public', 'pg_temp'
        AS $$
            SELECT count(*)::int FROM public.app_user
             WHERE role = 'admin'::user_role
               AND (p_haric IS NULL OR id <> p_haric);
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.platform_admin_sayisi(uuid) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.platform_admin_sayisi(uuid) TO app_rw;"
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.platform_admin_sayisi(uuid);")
    op.execute("DROP TRIGGER IF EXISTS trg_admin_tesisini_koru ON public.tenant")
    op.execute("DROP FUNCTION IF EXISTS public.admin_tesisini_koru()")
    op.execute("DROP TRIGGER IF EXISTS trg_son_platform_admini_koru ON public.app_user")
    op.execute("DROP FUNCTION IF EXISTS public.son_platform_admini_koru()")
    op.execute("ALTER TABLE public.tenant DROP COLUMN IF EXISTS arsivlendi_at")
