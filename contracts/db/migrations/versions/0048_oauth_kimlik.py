"""(P154 / Asama 4) OAUTH KIMLIKLERI — Google / Microsoft / Apple.

===========================================================================
BRIEF'IN MERKEZ CUMLESI: "SOSYAL HESAP ESLESME ANAHTARI DEGIL"
===========================================================================
Brief bunu KRITIK diye isaretliyor: "saglayici telefon vermiyor ama
eslesme modelimiz tesis ID + telefon. Sosyal hesapla kaydolan da tesis ID
ve telefon girecek; sosyal hesap kimlik dogrulama YONTEMI, eslesme
anahtari degil."

Bu tablo tam olarak onu ifade eder: burada bir KULLANICI YARATILMAZ. Satir
her zaman ZATEN VAR OLAN bir `app_user`a baglanir. Google hesabi, o
kullaniciya ait ikinci bir KAPIDIR; kim oldugunu soyleyen sey telefondur.

Tersi tasarim (saglayici e-postasindan kullanici turetmek) uc sey birden
kirardi: (1) tesis eslesmesi kaybolurdu — hangi siteye ait oldugu
bilinmez, (2) Apple private relay adresleri kalici kimlik degildir,
(3) kilitli kural 4 ("bir daire icin en fazla 1 hesap") delinirdi.

===========================================================================
IKI BENZERSIZLIK, IKI FARKLI SORU
===========================================================================
`uq_oauth_kimlik_subject (saglayici, subject)` — GLOBAL, tenant-uzeri.
  Bir Google hesabi platformda TEK kullaniciya baglanabilir. `app_user`in
  telefonu icin zaten ayni kural var (`uq_app_user_telefon`, 0001) ve
  ayni sebeple: kimlik dogrulama anahtari iki kisiyi isaret edemez.
  Tenant-ici yapmak, ayni Google hesabinin iki sitede iki AYRI kisiyi
  acmasi demekti — "kim giris yapti" sorusunun yaniti tesise gore
  degisirdi.

`uq_oauth_kimlik_user_saglayici (user_id, saglayici)` — kullanici basina
  saglayici basina TEK kimlik. Bir kullanicinin iki Google hesabini ayni
  anda baglamasi, "yontemi kaldir" ekranini iki ayni satirla doldururdu
  ve hangisinin kaldirildigi belirsizlesirdi. Yeni bir Google hesabi
  baglamak, eskisinin YERINE gecer (uc bunu acikca yapar).

===========================================================================
SAGLAYICI JETONLARI SAKLANMIYOR — BILINCLI
===========================================================================
Tabloda `access_token`/`refresh_token` YOK. Saglayicinin jetonuna yalniz
GIRIS ANINDA, kimligi dogrulamak icin ihtiyac var; ondan sonra oturumu
bizim kendi JWT ciftimiz yurutur (degismedi). Takvim/mail gibi hicbir
saglayici API'si cagrilmiyor.

Saklamak, hicbir isi olmayan bir sorumluluk olurdu: sizmasi halinde
kullanicinin GOOGLE HESABINA erisim verir ve KVKK'nin "veri en az"
ilkesiyle celisir. Ihtiyac dogarsa ayri bir tablo ve ayri bir riza akisi
gerektirir — bu gocun isi degil.

`eposta` GORUNTULEME ICINDIR: kullanici "hangi hesabi bagladim" diye
sorabilmeli. Eslesmede KULLANILMAZ ve `app_user.email`i EZMEZ — Apple
private relay (`...@privaterelay.appleid.com`) kalici bir adres degildir
ve orayi ezmek kullanicinin gercek e-postasini yok ederdi.

===========================================================================
`kod_amaci`'na 'oauth' EKLENIYOR
===========================================================================
Sosyal hesabin ILK baglanmasi SMS ile dogrulanir (gerekce uc katmaninda).
`amac` ayriminin tum varlik sebebi "bir amac icin uretilen kod baska bir
kapiyi ACAMAZ"; 'kayit' kodunu yeniden kullanmak o ayrimi silerdi —
'kayit' yolu `password_set=false` sarti tasir, oauth baglama tasimaz.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ENUM, UUID

revision = "0048_oauth_kimlik"
down_revision = "0047_ters_kayit"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

#: Desteklenen saglayicilar. ENUM, serbest metin DEGIL: yazim hatasi
#: (`gogle`) sessizce erisilemez bir kimlik satiri uretirdi.
SAGLAYICILAR = ("google", "microsoft", "apple")


def upgrade() -> None:
    op.execute("ALTER TYPE kod_amaci ADD VALUE IF NOT EXISTS 'oauth';")
    op.execute(
        "CREATE TYPE oauth_saglayici AS ENUM ("
        + ", ".join(f"'{s}'" for s in SAGLAYICILAR)
        + ");"
    )

    op.create_table(
        "oauth_kimlik",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("tenant_id", UUID(as_uuid=True),
                  sa.ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", UUID(as_uuid=True), nullable=False),
        # `postgresql.ENUM(create_type=False)` — `sa.Enum` DEGIL. Gerekce
        # 0043'te olculdu: `create_type` yalniz dialekt tipinde onurlanir,
        # `sa.Enum`da sessizce yok sayilip ikinci bir CREATE TYPE uretir.
        sa.Column("saglayici", ENUM(name="oauth_saglayici", create_type=False),
                  nullable=False),
        # Saglayicinin `sub` iddiasi. DEGISMEZ olan tek alan budur;
        # e-posta da ad da degisebilir, `sub` degismez.
        sa.Column("subject", sa.Text(), nullable=False),
        # YALNIZ GORUNTULEME (bkz. modul basligi). Apple private relay
        # adresi buraya yazilir ve eslesmede kullanilmaz.
        sa.Column("eposta", sa.Text(), nullable=True),
        sa.Column("son_giris_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        # TENANT'LI BILESIK FK — 0001'in her yerde kullandigi desen. Tekil
        # `user_id` FK'si, satirin tenant'i ile kullanicinin tenant'inin
        # AYRISMASINA izin verirdi.
        sa.ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            name="fk_oauth_kimlik_user",
            ondelete="CASCADE",
        ),
    )

    op.create_index(
        "uq_oauth_kimlik_subject", "oauth_kimlik",
        ["saglayici", "subject"], unique=True,
    )
    op.create_index(
        "uq_oauth_kimlik_user_saglayici", "oauth_kimlik",
        ["user_id", "saglayici"], unique=True,
    )
    # `tenant_id` FK'sinin ONCU KOLON indeksi. `test_indeks_kapsam` bunu
    # arar: onsuz tesis silindiginde butunluk tetigi bu tabloyu SEQ SCAN
    # eder. `user_id` FK'sini yukaridaki benzersiz indeks zaten kapsiyor.
    op.create_index("ix_oauth_kimlik_tenant", "oauth_kimlik", ["tenant_id"])

    # RLS — 0001'deki desenin aynisi; FORCE olmadan tablo SAHIBI
    # politikalari atlar ve `test_rls_kapsam` bunu kusur sayar.
    op.execute("ALTER TABLE public.oauth_kimlik ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE public.oauth_kimlik FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY oauth_kimlik_isolation ON public.oauth_kimlik
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON public.oauth_kimlik TO {APP_ROLE};"
    )

    # ------------------------------------------------------------------ #
    # KIMLIK ONCESI COZUCU — `tenant_id_by_phone` ile AYNI SINIF.
    #
    # Sosyal giriste kullanicinin oturumu YOKTUR: hangi tesise ait oldugu
    # bilinmeden `app.current_tenant_id` set edilemez, set edilmeden de
    # RLS satiri gostermez. Dongu, telefon girisinde oldugu gibi bir
    # SECURITY DEFINER cozucuyle kirilir.
    #
    # YALNIZ uuid DONER: satir vermez, e-posta/ad/rol sizdirmaz. Bu, tum
    # `tenant_id_by_*` ailesinin ortak kuralidir.
    #
    # `search_path = ''` + TAM NITELENMIS referans (0040/0041'in kurali):
    # `public` uzerinde nesne yaratabilen biri, nitelenmemis bir referansi
    # kendi tablosuna yonlendirip owner yetkisiyle kosturabilirdi.
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_id_by_oauth(
            p_saglayici text, p_subject text
        )
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT tenant_id FROM public.oauth_kimlik
             WHERE saglayici = p_saglayici::public.oauth_saglayici
               AND subject = p_subject
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.tenant_id_by_oauth(text, text) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.tenant_id_by_oauth(text, text) "
        f"TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.tenant_id_by_oauth(text, text);")
    op.execute("DROP POLICY IF EXISTS oauth_kimlik_isolation ON public.oauth_kimlik;")
    op.drop_index("ix_oauth_kimlik_tenant", table_name="oauth_kimlik")
    op.drop_index("uq_oauth_kimlik_user_saglayici", table_name="oauth_kimlik")
    op.drop_index("uq_oauth_kimlik_subject", table_name="oauth_kimlik")
    op.drop_table("oauth_kimlik")
    op.execute("DROP TYPE IF EXISTS oauth_saglayici;")
    # `kod_amaci`'ndaki 'oauth' KALIR. PostgreSQL enum'dan deger silmeyi
    # desteklemez; tipi yeniden yaratip kullanan sutunlari tasimak veri
    # kaybi riski tasir ve bu goc icin gereksizdir (yeni deger eskiyi
    # bozmaz). 0034/0047 ile ayni konvansiyon.
