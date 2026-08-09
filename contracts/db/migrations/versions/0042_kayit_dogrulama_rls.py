"""(P154) `kayit_dogrulama` RLS altina alindi + KIMLIK ONCESI uc cozucu.

===========================================================================
SORUN — neden bu tablo bugune kadar RLS'siz kaldi
===========================================================================

`test_rls_kapsam` iki testi bu tablo yuzunden kirmiziydi (P148'den beri).
Ama politikayi "sadece ekleyip" gecmek MUMKUN DEGILDI: tablo KIMLIK
ONCESI okunuyor ve o anda `app.current_tenant_id` HENUZ SET EDILEMEZ.

Uc yer:

  * `auth.kayit_dogrula`     — satiri TELEFONDAN bulur; kullanicinin
                               hesabi HENUZ YOK, tenant bilinmiyor.
  * `auth.giris_kodu_dogrula`-> `telefon_kodu.kodu_dogrula` — ayni durum;
                               oturum acilmadan once kod dogrulanir.
  * `telefon_kodu.kod_uret_ve_gonder` — bekleyen kodu EZER.

Ilk ikisine tenant izolasyon politikasi eklemek, sorgulari SESSIZCE sifir
satira dusururdu: sakin kaydi ve parolasiz giris calismaz hâle gelir ve
HICBIR YERDE HATA CIKMAZDI — kullanici yalnizca "kod gecersiz" gorurdu.
Kapiyi yesile boyamak icin akis kirilmadi; dogru cozum, `tenant_id_by_slug`
/ `tenant_id_by_phone` ile AYNI desendir: kimlik oncesi ani, YALNIZ tenant
kimligi donduren bir SECURITY DEFINER fonksiyon asar.

===========================================================================
UCUNCU YER AYRI BIR SINIF: "ezme" TENANT SINIRINI GECMEK ZORUNDA
===========================================================================

`uq_kayit_acik_basvuru` KISMI ve **GLOBAL** bir benzersizlik indeksidir:

    UNIQUE (telefon, amac) WHERE durum IN ('telefon_bekliyor','onay_bekliyor')

Yani bir telefon, TUM PLATFORMDA tek bir acik basvuru tasiyabilir. Kisi A
sitesinde kayda baslayip sonra B sitesinde kaydolmaya calisirsa, B'nin
INSERT'i A'nin satiriyla catisir. Bugun `kod_uret_ve_gonder`in basindaki
DELETE bunu cozuyor.

RLS acilinca o DELETE **kendi tenant'ini** gorur ve A'nin satirini SILEMEZ
-> INSERT benzersizlik ihlali verir -> 500. Yani ezme, tanimi geregi
tenant sinirini gecen bir islemdir ve politikayla ifade EDILEMEZ.

Bu yuzden temizlik fonksiyonlari var. IKI TANE, cunku kodda IKI FARKLI
temizlik semantigi VARDI ve ikisi de korundu:

  * `kayit_dogrulama_acik_temizle(telefon, amac)` —
    `telefon_kodu.kod_uret_ve_gonder`in "bekleyen kodu ez"i.
    `durum='telefon_bekliyor'` + ayni amac. `onay_bekliyor` satirlari
    BILEREK silinmez: onlar zaten bugun de INSERT'i engelliyor.

  * `kayit_dogrulama_telefon_sifirla(telefon)` —
    `auth.kayit_basla`in "bastan basla"si. O yol `kod_uret_ve_gonder`i
    CAGIRMIYOR; kendi satir ici DELETE'ini tasiyor ve o DELETE'in `amac`
    VE `durum` suzgeci YOK (kisi onay bekleyen basvurusunu iptal edip
    bastan baslayabilsin diye). Davranis bit bit korundu.

Tek bir fonksiyona `p_amac IS NULL => hepsi` dali eklemek, cagiranin
hangi kuralin isledigini ancak govdeyi okuyarak anlamasi demekti.

BU IKINCI YOL ONCE GOZDEN KACTI ve `test_kayit_dogrulama_rls.py`
YAKALADI: `kod_uret_ve_gonder` duzeltildikten sonra bile `kayit_basla`
kendi DELETE'iyle 500 uretiyordu. Testin varlik sebebi tam olarak budur.

===========================================================================
NE SIZAR, NE SIZMAZ
===========================================================================

Ucu de SATIR DONDURMEZ:
  * `kayit_dogrulama_tenant_coz` yalniz `uuid` doner (kod, ad, daire, hic),
  * iki temizlik fonksiyonu yalniz silinen SAYIYI doner.

Ucu de `REVOKE ... FROM PUBLIC` + `GRANT ... TO app_rw`: veritabaninda
baska bir rol cagiramaz (0041'de `tenant_id_by_kayit_kodu` icin duzeltilen
kuralin aynisi). HTTP tarafinda ise cagiran uclar zaten "adimlari ayirt
ETTIRMEYEN" tek bir yanit doner, yani cozucunun NULL/degil ayrimi disariya
GORUNMEZ.

Ucu de `SET search_path = ''` tasir ve govdedeki her nesne tam
nitelenmistir (0040'in dersi).
"""
from alembic import op

revision = "0042_kayit_dogrulama_rls"
down_revision = "0041_kod_ve_coklu_yonetici"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    # ----------------------------------------------------------------- #
    # 1) Kimlik oncesi tenant cozucu.
    #
    # `durum='telefon_bekliyor'` SARTI ONEMLI: onaylanmis ya da reddedilmis
    # bir basvurunun tenant'ini donmek, kapanmis bir kaydi yeniden
    # kullanilabilir gosterirdi. Acik satir (telefon, amac) uzerinde
    # benzersiz oldugu icin sonuc DAIMA tekildir; yine de `LIMIT 1`
    # yaziliyor ki indeks bir gun gevserse fonksiyon patlamak yerine
    # belirli davransin.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kayit_dogrulama_tenant_coz(
            p_telefon text,
            p_amac    text
        )
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT k.tenant_id
            FROM public.kayit_dogrulama k
            WHERE k.telefon = p_telefon
              AND k.amac = p_amac::public.kod_amaci
              AND k.durum = 'telefon_bekliyor'::public.kayit_durum
            LIMIT 1
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.kayit_dogrulama_tenant_coz(text, text) "
        "FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.kayit_dogrulama_tenant_coz(text, text) "
        f"TO {APP_ROLE};"
    )

    # ----------------------------------------------------------------- #
    # 2) Tenant sinirini GECEN "ezme" (bkz. modul basligi).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kayit_dogrulama_acik_temizle(
            p_telefon text,
            p_amac    text
        )
        RETURNS integer
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_sayi integer;
        BEGIN
            DELETE FROM public.kayit_dogrulama
             WHERE telefon = p_telefon
               AND amac = p_amac::public.kod_amaci
               AND durum = 'telefon_bekliyor'::public.kayit_durum;
            GET DIAGNOSTICS v_sayi = ROW_COUNT;
            RETURN v_sayi;
        END;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.kayit_dogrulama_acik_temizle(text, text) "
        "FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.kayit_dogrulama_acik_temizle(text, text) "
        f"TO {APP_ROLE};"
    )

    # ----------------------------------------------------------------- #
    # 2b) KAYDA BASTAN BASLAMA — yukaridakinden FARKLI bir islem.
    #
    # NEDEN IKINCI BIR FONKSIYON (ve neden yukaridakine bir parametre
    # EKLENMEDI): `auth.kayit_basla` kendi satir ici temizligini yapiyor ve
    # o temizlik `DELETE ... WHERE telefon = :p` — yani `amac` VE `durum`
    # SUZGECI YOK. Bir kisi onay bekleyen basvurusunu iptal edip bastan
    # baslayabilsin diye boyle yazilmis.
    #
    # `acik_temizle`ye `p_amac IS NULL => hepsi` gibi bir dal eklemek, tek
    # fonksiyonu IKI FARKLI kurala sahip hâle getirirdi; cagiran taraf
    # hangi kuralin isledigini ancak govdeyi okuyarak anlardi. Iki ayri ad,
    # iki ayri anlam.
    #
    # DAVRANIS BIT BIT KORUNDU: eski satir ici DELETE ne siliyorsa bu da
    # onu siler — tek fark tenant sinirini gecmesi.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kayit_dogrulama_telefon_sifirla(
            p_telefon text
        )
        RETURNS integer
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_sayi integer;
        BEGIN
            DELETE FROM public.kayit_dogrulama WHERE telefon = p_telefon;
            GET DIAGNOSTICS v_sayi = ROW_COUNT;
            RETURN v_sayi;
        END;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.kayit_dogrulama_telefon_sifirla(text) "
        "FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.kayit_dogrulama_telefon_sifirla(text) "
        f"TO {APP_ROLE};"
    )

    # ----------------------------------------------------------------- #
    # 3) RLS — 0001'deki `_enable_rls` ile AYNI desen.
    #
    # FORCE de veriliyor: onsuz tablo SAHIBI politikalari atlar ve
    # `test_rls_kapsam` bunu (hakli olarak) kusur sayar.
    op.execute("ALTER TABLE public.kayit_dogrulama ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE public.kayit_dogrulama FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY kayit_dogrulama_isolation ON public.kayit_dogrulama
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )


def downgrade() -> None:
    op.execute(
        "DROP POLICY IF EXISTS kayit_dogrulama_isolation "
        "ON public.kayit_dogrulama;"
    )
    op.execute("ALTER TABLE public.kayit_dogrulama NO FORCE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE public.kayit_dogrulama DISABLE ROW LEVEL SECURITY;")
    op.execute(
        "DROP FUNCTION IF EXISTS public.kayit_dogrulama_telefon_sifirla(text);"
    )
    op.execute(
        "DROP FUNCTION IF EXISTS "
        "public.kayit_dogrulama_acik_temizle(text, text);"
    )
    op.execute(
        "DROP FUNCTION IF EXISTS "
        "public.kayit_dogrulama_tenant_coz(text, text);"
    )
