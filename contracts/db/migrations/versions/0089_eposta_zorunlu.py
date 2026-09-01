"""(P197) app_user.email ZORUNLU — e-postasiz hesap bir daha olusmaz

===========================================================================
NEDEN
===========================================================================
E-posta bu urunde bir ILETISIM ALANI degil, KIMLIGIN TASIYICISIDIR:
davet oradan gider, dogrulama kodu oradan gider, parola sifirlama oradan
gider. SMS urun genelinde KAPALI (`SMS_AKTIF=false`), yani e-postasi
olmayan bir hesap:
  * daveti ALAMAZ (hesap acilir ama sahiplenilemez),
  * parolasini SIFIRLAYAMAZ,
  * hesabini SILEMEZ (P196'da olculdu: silme kodu SMS'ten gidiyordu ve
    SMS kapali oldugu icin hicbir zaman ulasmiyordu).

Yani "e-postasiz kullanici" bir kullanim bicimi degil, SESSIZ BIR
CIKMAZDIR. Kural uygulama katmaninda parca parca uygulanmisti (P186 tekil
ekleme, P193 Excel aktarimi); veritabani hala izin veriyordu ve
SECURITY DEFINER fonksiyonlar bu izni FIILEN KULLANIYORDU.

===========================================================================
MEVCUT SATIRLAR: SILINMEDI, SENTETIK ADRESLE DOLDURULDU
===========================================================================
Uc secenek vardi:

  (a) SIL — ELENDI. `app_user` bir sur FK'nin hedefi (denetim kaydi,
      finansal hareket, okutma, talep). Cogu RESTRICT; goc yarida
      patlardi. Patlamasa bile SILME GERI ALINAMAZ: bir goc, geri
      alinabilir olmak zorunda ve `downgrade` silinen kullaniciyi geri
      getiremez.

  (b) ANONIMLESTIR — ELENDI. Anonimlestirme KVKK'nin bir aracidir ve
      kisinin TALEBI ya da saklama suresi dolmasi uzerine yapilir. Bir
      sema degisikligini gerekce sayip kimlik verisi silmek, o araci
      amaci disinda kullanmak olurdu.

  (c) SENTETIK ADRES — SECILDI. `gecersiz+<user_id>@yonetiyor.invalid`.
      * `.invalid` RFC 2606 ile AYRILMIS bir TLD'dir: DNS'te ASLA
        cozulmez. Yani bu adrese yanlislikla posta gonderilemez —
        gercek bir alan adi (orn. `ornek.com`) yazsaydik, bir gun o alan
        adinin sahibi bizim kod e-postalarimizi alirdi.
      * `user_id` iceriyor: `uq_app_user_tenant_email` benzersizligi
        kendiliginden saglanir, iki satir catismaz.
      * GERI ALINABILIR: `downgrade` tam olarak bu desendeki adresleri
        NULL'a cevirir — baska hicbir satira dokunmaz.
      * `eposta_dogrulandi` bu satirlarda FALSE'a cekilir: sentetik
        adres dogrulanmis SAYILAMAZ; aksi halde parola sifirlama gibi
        yollar "adres dogrulanmis" diye acilirdi.

Bu satirlarin sahipleri hesaplarini kullanamaz — ama ZATEN
KULLANAMIYORLARDI (yukaridaki cikmaz). Degisen sey, cikmazin artik
GORUNUR olmasi: adres `@yonetiyor.invalid` ile bitiyorsa hesap
sahiplenilmemis demektir.

===========================================================================
FONKSIYONLAR DA DEGISTI — ASIL SIZINTI ORADAYDI
===========================================================================
`create_tenant_with_yoneticis` ve `add_tenant_yonetici` (goc 0001/0041)
`app_user`a E-POSTASIZ yaziyordu. Bunlar SECURITY DEFINER'dir, yani
uygulama katmanindaki her dogrulamayi ATLAR. Sutunu NOT NULL yapip
fonksiyonlari birakmak, gocun ertesi gunu `POST /tenants`i 500'e
dusururdu. Ikisi de artik e-posta ALIR ve YAZAR.

Revision ID: 0089_eposta_zorunlu
Revises: 0088_tesis_adresi
Create Date: 2026-09-01
"""
from alembic import op

revision = "0089_eposta_zorunlu"
down_revision = "0088_tesis_adresi"
branch_labels = None
depends_on = None

#: Sentetik adres deseni — `downgrade` AYNI deseni geri alir.
SENTETIK_DESEN = "gecersiz+%@yonetiyor.invalid"


def upgrade() -> None:
    # 1) GERI DOLDUR. Bos dizge de NULL sayilir: `''` bir adres degildir
    #    ve NOT NULL onu YAKALAMAZDI.
    op.execute(
        """
        UPDATE app_user
           SET email = 'gecersiz+' || id::text || '@yonetiyor.invalid',
               eposta_dogrulandi = false
         WHERE email IS NULL OR btrim(email) = '';
        """
    )
    # 2) ZORUNLU KIL.
    op.execute("ALTER TABLE app_user ALTER COLUMN email SET NOT NULL;")
    # 3) BOS DIZGE DE YASAK: NOT NULL tek basina `''`e izin verir ve o,
    #    "adres var" gorunen bir adressizliktir.
    op.execute(
        """
        ALTER TABLE app_user
            ADD CONSTRAINT ck_app_user_email_bos_degil
            CHECK (btrim(email) <> '');
        """
    )

    # 4) SECURITY DEFINER FONKSIYONLAR — e-posta ALIR ve YAZAR.
    op.execute(
        """
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
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.add_tenant_yonetici(
            p_tenant_id uuid, p_ad text, p_telefon text,
            p_temp_code_hash text, p_eposta text)
        RETURNS uuid
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_id uuid;
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM public.tenant WHERE id = p_tenant_id
            ) THEN
                RETURN NULL;
            END IF;
            INSERT INTO public.app_user
                (tenant_id, ad, telefon, email, password_hash,
                 temp_code_hash, password_set, role, is_active, aranabilir,
                 birincil)
            VALUES (p_tenant_id, p_ad, p_telefon, p_eposta, NULL,
                    p_temp_code_hash, false,
                    'yonetici'::public.user_role, true, true, false)
            RETURNING id INTO v_id;
            RETURN v_id;
        END;
        $$;
        """
    )
    # ESKI IMZA DUSURULUR: kalirsa `add_tenant_yonetici(uuid,text,text,text)`
    # cagrisi COZULMEYE devam eder ve e-postasiz hesap acmayi surdururdu.
    # Asil kapatilmak istenen delik tam olarak budur.
    op.execute(
        "DROP FUNCTION IF EXISTS public.add_tenant_yonetici(uuid, text, text, text);"
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.add_tenant_yonetici(uuid, text, text, text, text) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.add_tenant_yonetici(uuid, text, text, text, text) TO app_rw;"
    )


def downgrade() -> None:
    # Fonksiyonlari ESKI imzalariyla geri koy (e-postasiz).
    op.execute(
        "DROP FUNCTION IF EXISTS public.add_tenant_yonetici(uuid, text, text, text, text);"
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.add_tenant_yonetici(
            p_tenant_id uuid, p_ad text, p_telefon text, p_temp_code_hash text)
        RETURNS uuid
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_id uuid;
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM public.tenant WHERE id = p_tenant_id
            ) THEN
                RETURN NULL;
            END IF;
            INSERT INTO public.app_user
                (tenant_id, ad, telefon, password_hash, temp_code_hash,
                 password_set, role, is_active, aranabilir, birincil)
            VALUES (p_tenant_id, p_ad, p_telefon, NULL, p_temp_code_hash,
                    false, 'yonetici'::public.user_role, true, true, false)
            RETURNING id INTO v_id;
            RETURN v_id;
        END;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.add_tenant_yonetici(uuid, text, text, text) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.add_tenant_yonetici(uuid, text, text, text) TO app_rw;"
    )
    op.execute(
        """
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
            RETURN QUERY
            INSERT INTO public.app_user
                (tenant_id, ad, telefon, password_hash, temp_code_hash,
                 password_set, role, is_active, aranabilir, birincil)
            SELECT
                v_tenant,
                y.value ->> 'ad',
                y.value ->> 'telefon',
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
    )
    op.execute(
        "ALTER TABLE app_user DROP CONSTRAINT IF EXISTS ck_app_user_email_bos_degil;"
    )
    op.execute("ALTER TABLE app_user ALTER COLUMN email DROP NOT NULL;")
    # SENTETIK ADRESLERI GERI AL — yalniz onlari, desenle.
    op.execute(
        """
        UPDATE app_user
           SET email = NULL
         WHERE email LIKE 'gecersiz+%@yonetiyor.invalid';
        """
    )
