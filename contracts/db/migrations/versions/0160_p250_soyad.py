"""(P250 §1) Kisi adi: AYRI SOYAD sutunu.

`app_user.ad` TAM GORUNEN AD olarak kalir ("Mehmet Ali YILMAZ"); yeni
`soyad` sutunu soyadi ayrica tutar. Gerekce (docs/P250-kararlar.md §1):
otuzdan fazla okuyucu `ad`i kisinin adi diye gosteriyor, arama `ad`
uzerinde, siralama `ad` uzerinde. Hicbiri degismeden yeni kayitlar
soyadi ayri tasir.

MEVCUT KAYITLARA DOKUNULMAZ: geri doldurma YOK. Eski satirlarda soyad
NULL kalir; kisi duzenlenip kaydedilince dolar.
"""
from alembic import op

revision = "0160_p250_soyad"
down_revision = "0159_p249_daireye_ulasma"
branch_labels = None
depends_on = None


_YENI_KURULUM = """
        CREATE OR REPLACE FUNCTION public.create_tenant_with_yoneticis(
            p_ad text, p_slug text, p_timezone text, p_kurulum boolean,
            p_yonetim_email text, p_yoneticiler jsonb)
        RETURNS TABLE(tenant_id uuid, user_id uuid, telefon text,
                      birincil boolean)
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_tenant uuid;
        BEGIN
            INSERT INTO public.tenant (ad, slug, timezone, kurulum_tamamlandi,
                                       yonetim_email)
            VALUES (p_ad, p_slug, p_timezone, p_kurulum, p_yonetim_email)
            RETURNING id INTO v_tenant;

            -- (P197) `eposta` ARTIK ZORUNLU BIR ALAN: cagiran vermezse
            -- INSERT NOT NULL ihlaliyle duser. Sessizce NULL yazip
            -- sahiplenilemez bir hesap birakmaktansa, ISTEK BASARISIZ
            -- OLSUN — hata gorunur, sessiz cikmaz gorunmez.
            RETURN QUERY
            INSERT INTO public.app_user
                (tenant_id, ad, soyad, telefon, email, password_hash,
                 temp_code_hash, password_set, role, is_active, aranabilir,
                 birincil)
            SELECT
                v_tenant,
                y.value ->> 'ad',
                -- (P250 §1) Ayri soyad; anahtar yoksa NULL (eski cagiran).
                NULLIF(btrim(y.value ->> 'soyad'), ''),
                y.value ->> 'telefon',
                y.value ->> 'eposta',
                y.value ->> 'password_hash',
                y.value ->> 'temp_code_hash',
                (y.value ->> 'password_set')::boolean,
                'yonetici'::public.user_role,
                true,
                true,
                (y.ordinality = 1)
            FROM jsonb_array_elements(p_yoneticiler)
                 WITH ORDINALITY AS y(value, ordinality)
            RETURNING v_tenant, public.app_user.id, public.app_user.telefon,
                      public.app_user.birincil;
        END;
        $$;
"""

# Geri alma: 0089'daki tanim AYNEN (soyadsiz).
_ESKI_KURULUM = """
        CREATE OR REPLACE FUNCTION public.create_tenant_with_yoneticis(
            p_ad text, p_slug text, p_timezone text, p_kurulum boolean,
            p_yonetim_email text, p_yoneticiler jsonb)
        RETURNS TABLE(tenant_id uuid, user_id uuid, telefon text,
                      birincil boolean)
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_tenant uuid;
        BEGIN
            INSERT INTO public.tenant (ad, slug, timezone, kurulum_tamamlandi,
                                       yonetim_email)
            VALUES (p_ad, p_slug, p_timezone, p_kurulum, p_yonetim_email)
            RETURNING id INTO v_tenant;

            -- (P197) `eposta` ARTIK ZORUNLU BIR ALAN: cagiran vermezse
            -- INSERT NOT NULL ihlaliyle duser. Sessizce NULL yazip
            -- sahiplenilemez bir hesap birakmaktansa, ISTEK BASARISIZ
            -- OLSUN — hata gorunur, sessiz cikmaz gorunmez.
            RETURN QUERY
            INSERT INTO public.app_user
                (tenant_id, ad, telefon, email, password_hash,
                 temp_code_hash, password_set, role, is_active, aranabilir,
                 birincil)
            SELECT
                v_tenant,
                y.value ->> 'ad',
                y.value ->> 'telefon',
                y.value ->> 'eposta',
                y.value ->> 'password_hash',
                y.value ->> 'temp_code_hash',
                (y.value ->> 'password_set')::boolean,
                'yonetici'::public.user_role,
                true,
                true,
                (y.ordinality = 1)
            FROM jsonb_array_elements(p_yoneticiler)
                 WITH ORDINALITY AS y(value, ordinality)
            RETURNING v_tenant, public.app_user.id, public.app_user.telefon,
                      public.app_user.birincil;
        END;
        $$;
"""


def upgrade() -> None:
    op.execute(
        "ALTER TABLE app_user ADD COLUMN soyad text NULL "
        "CONSTRAINT ck_app_user_soyad CHECK "
        "(soyad IS NULL OR (btrim(soyad) <> '' AND length(soyad) <= 100));"
    )
    # (P250 §1) Kayitla acilan yoneticinin soyadi da ayri yazilsin. Imza
    # AYNI (CREATE OR REPLACE): jsonb'de `soyad` anahtari opsiyonel.
    op.execute(_YENI_KURULUM)


def downgrade() -> None:
    op.execute(_ESKI_KURULUM)
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS soyad;")
