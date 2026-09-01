"""(P202) Zorunlu guncelleme — PLATFORM BASINA SURUM POLITIKASI.

===========================================================================
NEDEN TABLO, NEDEN ORTAM DEGISKENI DEGIL
===========================================================================
Politika, YENI SURUM YAYINLAMADAN degistirilebilmeli (istek §2). Ortam
degiskeni bunu saglamaz: her degisiklik `api`nin yeniden kurulmasini
ister ve platform yoneticisinin elinde bir dugme olmaz. Tablo, panel
uzerinden duzenlenebilir.

===========================================================================
NEDEN `tenant_id` YOK — ve ERISIM NASIL KAPATILIYOR
===========================================================================
Surum politikasi PLATFORM GENELIDIR: magazadaki paket tektir, tesise
gore degismez. `tenant_id` koymak, ayni gercegin tesis sayisi kadar
kopyasini uretirdi.

`tanitim_iletisim` (0033) ve `yonetici_basvuru` (0068) ile AYNI DESEN:
RLS ACIK + FORCE, POLITIKA YOK, erisim yalniz SECURITY DEFINER
fonksiyonlarindan. Yani `app_rw` tabloyu DOGRUDAN goremez.

ILK YAZIMDA RLS HIC ACILMAMISTI ve gerekce "satirlar zaten herkese
acik sayilar" idi. `test_rls_kapsam.py` bunu dusurdu ve HAKLIYDI:
kural "her tablo RLS+FORCE"dur ve istisnasi, sinifin GORUNUR ve
SAYILI kalmasidir. Sizintinin olmamasi, kapiyi acik birakmanin
gerekcesi degildir — bir gun bu tabloya hassas bir alan eklendiginde
(orn. hedefli dagitim listesi) korumayi hatirlayacak kimse olmazdi.

===========================================================================
IKI ESIK, TEK SATIR
===========================================================================
`asgari_surum`  — bunun ALTI kullanilamaz (ZORUNLU).
`onerilen_surum`— bunun ALTI uyarilir ama kullanmaya DEVAM EDER.

Ikisi de BOS olabilir ve BOS = O SEVIYE KAPALI. Varsayilan olarak ikisi
de bostur: goc uygulanir uygulanmaz kimse kilitlenmez. Bir guncelleme
politikasinin, kimse ondan haberdar olmadan yururluge girmesi
kabul edilemez.

`mesaj` JSONB: dil kodu -> metin (7 dil). BOS BIRAKILABILIR; o zaman
uygulama KENDI yerellestirilmis metnini kullanir. Operatorun ozelligi
kullanabilmek icin yedi dili doldurmak zorunda kalmasi, ozelligi
kullanilmaz yapardi.

Geri alinabilir: `downgrade` tabloyu dusurur.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

APP_ROLE = "app_rw"

revision = "0091_surum_politikasi"
down_revision = "0090_kurulum_otomasyon_karari"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "surum_politikasi",
        # PLATFORM BIRINCIL ANAHTAR: 'ios' | 'android'. Ayri bir `id`
        # sutunu "hangi satir gecerli" sorusunu dogururdu.
        sa.Column("platform", sa.Text(), primary_key=True),
        sa.Column("asgari_surum", sa.Text(), nullable=True),
        sa.Column("onerilen_surum", sa.Text(), nullable=True),
        sa.Column(
            "mesaj",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "platform IN ('ios','android')", name="ck_surum_politikasi_platform"
        ),
    )
    # IKI SATIR BOS DEGERLERLE ACILIR: panel ekrani "kayit yok" durumunu
    # ayrica ele almak zorunda kalmasin. Bos esik = o seviye KAPALI.
    op.execute(
        "INSERT INTO surum_politikasi (platform) VALUES ('ios'), ('android')"
    )
    # RLS ACIK + FORCE, POLITIKA YOK: `app_rw` tabloyu DOGRUDAN goremez.
    # FORCE olmadan tablo SAHIBI politikalari atlardi.
    op.execute("ALTER TABLE surum_politikasi ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE surum_politikasi FORCE ROW LEVEL SECURITY;")

    # --- ERISIM: iki SECURITY DEFINER fonksiyonu -------------------------- #
    #
    # OKUMA fonksiyonu KIMLIKSIZ cagrilir (kontrol ucu public; gerekce
    # `routers/surum.py` basliginda). Verdigi tek sey iki esik ve mesaj —
    # yani magazadaki surum numaralari. TEK SATIR doner: `platform`
    # parametresi disindaki hicbir satiri gostermez.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.surum_politikasi_oku(p_platform text)
        RETURNS TABLE (asgari_surum text, onerilen_surum text, mesaj jsonb)
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path = public, pg_temp
        AS $$
            SELECT s.asgari_surum, s.onerilen_surum, s.mesaj
            FROM surum_politikasi s
            WHERE s.platform = p_platform;
        $$;
        """
    )
    # YAZMA fonksiyonu: rol kapisi UYGULAMA KATMANINDA (`require_role
    # ("admin")`). Fonksiyon yalniz BILINEN iki platformu kabul eder ve
    # yeni satir YARATMAZ — kume kapalidir.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.surum_politikasi_yaz(
            p_platform  text,
            p_asgari    text,
            p_onerilen  text,
            p_mesaj     jsonb
        )
        RETURNS TABLE (asgari_surum text, onerilen_surum text, mesaj jsonb)
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = public, pg_temp
        AS $$
        BEGIN
            IF p_platform NOT IN ('ios', 'android') THEN
                RAISE EXCEPTION 'gecersiz platform: %', p_platform;
            END IF;
            UPDATE surum_politikasi s SET
                asgari_surum   = p_asgari,
                onerilen_surum = p_onerilen,
                mesaj          = COALESCE(p_mesaj, '{}'::jsonb),
                updated_at     = now()
            WHERE s.platform = p_platform;
            RETURN QUERY
                SELECT s.asgari_surum, s.onerilen_surum, s.mesaj
                FROM surum_politikasi s WHERE s.platform = p_platform;
        END;
        $$;
        """
    )
    # REVOKE PUBLIC ONCE: Postgres yeni fonksiyonlara VARSAYILAN olarak
    # PUBLIC EXECUTE verir. Yalniz GRANT yazmak, fonksiyonu veritabanina
    # baglanabilen HERKESE acik birakirdi (`test_secdef_kapsam` bunu
    # olcuyor ve ilk yazimda YAKALADI).
    op.execute(
        "REVOKE ALL ON FUNCTION public.surum_politikasi_oku(text) FROM PUBLIC;"
    )
    op.execute(
        "REVOKE ALL ON FUNCTION "
        "public.surum_politikasi_yaz(text, text, text, jsonb) FROM PUBLIC;"
    )
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.surum_politikasi_oku(text) "
        f"TO {APP_ROLE};"
    )
    op.execute(
        f"GRANT EXECUTE ON FUNCTION "
        f"public.surum_politikasi_yaz(text, text, text, jsonb) TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.surum_politikasi_oku(text);")
    op.execute(
        "DROP FUNCTION IF EXISTS "
        "public.surum_politikasi_yaz(text, text, text, jsonb);"
    )
    op.drop_table("surum_politikasi")
