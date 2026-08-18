"""(P170 §2) KVKK YONETIMI PLATFORMA GECER — capraz-tenant SQL islevleri.

===========================================================================
NEDEN GEREKLI: VERI TENANT'A BAGLI, YETKI PLATFORMA GECIYOR
===========================================================================
`kvkk_metin` TENANT ICERIGIDIR ve oyle kalmali (bkz. `models.KvkkMetin`
basligi): her tesisin veri sorumlusu KENDISIDIR; platforma gomulu tek bir
metin 200 tesise BASKASININ metnini imzalatmak olurdu. Onaylar da tenant
kapsamli ve satirlar RLS ile korunuyor.

Degisen sey VERININ YERI DEGIL, YAYINLAMA YETKISI: metinleri artik
platform yonetir. Yani platform yoneticisi KENDI tenant'inda degil,
SECTIGI tenant'ta yazmali. RLS `app.current_tenant_id`ye bagli oldugu icin
bu, normal uygulama yolundan yapilamaz — ve yapilabilir olsaydi kotu
olurdu: her ucun capraz-tenant yazabildigi bir sistemde RLS'in anlami
kalmaz.

Cozum, panelin `tenants` uclarinda ZATEN KULLANILAN desen: DAR, tek isli,
`SECURITY DEFINER` islevler. Her biri tek bir sey yapar, girdisi
dogrulanir, `app_rw` disindaki herkesten yetkisi ALINIR.

===========================================================================
NEDEN UC AYRI ISLEV
===========================================================================
Tek bir "her seyi yapan" islev yazmak, capraz-tenant yetkisini genis bir
yuzeye yaymak olurdu. Uc islev, uc cumle:
  * `kvkk_metin_listele`  — bir tesisin TUM surumleri (okuma),
  * `kvkk_metin_yayinla`  — yeni surum (yazma),
  * `kvkk_onay_ozeti`     — tesiste tur basina kac kisi onaylamis (okuma).

SURUM SUNUCUDA HESAPLANIR: istemciden gelen bir surum numarasi, iki es
zamanli yayinda ayni numarayi uretebilirdi. `uq_kvkk_metin_surum` bunu
zaten reddederdi ama kullaniciya sebebi anlasilmaz bir 409 donerdi.

AYNI GOVDE YENIDEN YAYINLANMAZ: degismemis bir metin icin herkesi yeniden
onaya zorlamak, onayi anlamsiz bir tikla dondururdu. Islev NULL doner ve
uc bunu 409'a cevirir.

Revision ID: 0065_kvkk_platform_yonetimi
Revises: 0064_kvkk_metin_turleri
"""

from alembic import op

revision = "0065_kvkk_platform_yonetimi"
down_revision = "0064_kvkk_metin_turleri"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    # ---------------------------------------------------------------- #
    # 1) LISTELE — bir tesisin butun KVKK metin surumleri.
    #
    # `govde` DE DONER: platform yoneticisi yayinlamadan once mevcut
    # metni okuyabilmeli; okumadan surum cikarmak, ne degistigini
    # bilmeden yayinlamak olurdu.
    # ---------------------------------------------------------------- #
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kvkk_metin_listele(
            p_tenant_id uuid
        )
        RETURNS TABLE (
            id uuid,
            tur text,
            surum integer,
            baslik text,
            govde text,
            yeniden_onay_gerekir boolean,
            created_at timestamptz
        )
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT m.id, m.tur::text, m.surum, m.baslik, m.govde,
                   m.yeniden_onay_gerekir, m.created_at
            FROM public.kvkk_metin m
            WHERE m.tenant_id = p_tenant_id
            ORDER BY m.tur, m.surum DESC;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.kvkk_metin_listele(uuid) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.kvkk_metin_listele(uuid) "
        f"TO {APP_ROLE};"
    )

    # ---------------------------------------------------------------- #
    # 2) YAYINLA — yeni surum.
    #
    # `yayinlayan_user_id` NULL YAZILIR ve bu bir eksiklik degil ZORUNLU:
    # yayinlayan bir PLATFORM kullanicisidir; kolon (user_id, tenant_id)
    # bileske yabanci anahtariyla O TENANT'IN kullanicisina baglidir ve
    # platform yoneticisi o tenant'ta YOKTUR. Kendi kimligini oraya yazmak,
    # var olmayan bir yabanci anahtari zorlamak olurdu.
    #
    # BILINEN BOSLUK, YAZILI BIRAKILIYOR: platform tarafinda yapilan bu
    # islem tenant'in `audit_log`una DUSMUYOR — `tenants.py`daki oteki
    # capraz-tenant uclari da dusurmuyor (yonetici ekleme/silme dahil).
    # Platform islemleri icin ayri bir denetim kanali bir sonraki turun
    # isi; burada uydurma bir kullanici kimligi yazmaktansa bosluk
    # gorunur birakiliyor.
    # ---------------------------------------------------------------- #
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kvkk_metin_yayinla(
            p_tenant_id uuid,
            p_tur       text,
            p_baslik    text,
            p_govde     text,
            p_yeniden_onay boolean
        )
        RETURNS TABLE (sonuc text, id uuid, surum integer)
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_surum integer;
            v_id    uuid;
        BEGIN
            -- SONUC KODU ISLEVIN KENDISINDEN DONER, IKINCI BIR SORGUDAN
            -- DEGIL. Ilk yazimda "bos sonuc" donuluyor, sebebi (tesis yok
            -- mu, govde mi degismedi) ayirt etmek icin uc ayrica
            -- `public.tenant`a bakiyordu — VE O SORGU RLS'E TAKILIYORDU:
            -- platform baglaminda `app.current_tenant_id` bos ve politika
            -- onu uuid'ye cevirmeye calisip 500 uretiyordu (olculdu).
            -- `SECURITY DEFINER` islev RLS'i asar; cevabi burada uretmek
            -- hem dogru hem tek gidis-donus.
            IF NOT EXISTS (
                SELECT 1 FROM public.tenant t WHERE t.id = p_tenant_id
            ) THEN
                sonuc := 'yok'; RETURN NEXT; RETURN;
            END IF;

            -- AYNI GOVDE ISE YAYINLAMA (bkz. modul basligi). Karsilastirma
            -- YURURLUKTEKI (en yuksek surumlu) metinle yapilir.
            IF EXISTS (
                SELECT 1 FROM public.kvkk_metin m
                WHERE m.tenant_id = p_tenant_id
                  AND m.tur::text = p_tur
                  AND m.surum = (
                      SELECT max(m2.surum) FROM public.kvkk_metin m2
                      WHERE m2.tenant_id = p_tenant_id
                        AND m2.tur::text = p_tur
                  )
                  AND m.govde = p_govde
            ) THEN
                sonuc := 'degismedi'; RETURN NEXT; RETURN;
            END IF;

            SELECT coalesce(max(m.surum), 0) + 1 INTO v_surum
            FROM public.kvkk_metin m
            WHERE m.tenant_id = p_tenant_id AND m.tur::text = p_tur;

            INSERT INTO public.kvkk_metin
                (tenant_id, tur, surum, baslik, govde,
                 yeniden_onay_gerekir, yayinlayan_user_id)
            VALUES (p_tenant_id, p_tur::public.kvkk_metin_tur, v_surum,
                    p_baslik, p_govde, p_yeniden_onay, NULL)
            RETURNING public.kvkk_metin.id INTO v_id;

            sonuc := 'tamam';
            id := v_id;
            surum := v_surum;
            RETURN NEXT;
        END;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.kvkk_metin_yayinla"
        "(uuid, text, text, text, boolean) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.kvkk_metin_yayinla"
        f"(uuid, text, text, text, boolean) TO {APP_ROLE};"
    )

    # ---------------------------------------------------------------- #
    # 3) ONAY OZETI — tur basina kac kisi YURURLUKTEKI surumu onaylamis.
    #
    # Platform yoneticisinin tek gercek sorusu bu: "yayinladigim metni kac
    # kisi gordu?" Kisi listesi DONMEZ — capraz-tenant bir uctan kisi
    # dokumu almak, yonetim isi icin gereksiz bir kisisel veri akisi olurdu.
    # ---------------------------------------------------------------- #
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kvkk_onay_ozeti(
            p_tenant_id uuid
        )
        RETURNS TABLE (tur text, surum integer, onaylayan integer)
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT g.tur::text, g.surum,
                   (SELECT count(*)::integer FROM public.kvkk_onay o
                     WHERE o.tenant_id = p_tenant_id
                       AND o.tur = g.tur
                       AND o.surum = g.surum)
            FROM (
                SELECT DISTINCT ON (m.tur) m.tur, m.surum
                FROM public.kvkk_metin m
                WHERE m.tenant_id = p_tenant_id
                ORDER BY m.tur, m.surum DESC
            ) g;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.kvkk_onay_ozeti(uuid) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.kvkk_onay_ozeti(uuid) "
        f"TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.kvkk_onay_ozeti(uuid);")
    op.execute(
        "DROP FUNCTION IF EXISTS public.kvkk_metin_yayinla"
        "(uuid, text, text, text, boolean);"
    )
    op.execute("DROP FUNCTION IF EXISTS public.kvkk_metin_listele(uuid);")
