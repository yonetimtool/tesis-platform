"""(P167 Asama 4) MERKEZI BELGE NUMARALANDIRMA — tek sayac tablosu.

===========================================================================
BRIEF'IN ZORUNLU ILKESI
===========================================================================
"Belge numaralandirma MERKEZI olsun, her modul kendi numarasini
uretmesin."

BUGUNKU DURUM: `finansal_hareket.belge_no` SERBEST METIN. Kullanici ne
yazarsa o. Sonuclari olculebilir:

  * AYNI NUMARA IKI BELGEDE olabilir — ve bu bir muhasebe kaydinda
    "hangi fis?" sorusunu cevapsiz birakir,
  * BOSLUK birakilabilir (alan opsiyonel), yani bir hareketin belgesi
    HIC olmayabilir,
  * her modul kendi bicimini uydurur; rapor ve ekstre ciktilarinda
    numaralar birbirine benzemez.

===========================================================================
NEDEN SAYAC TABLOSU, NEDEN POSTGRES `SEQUENCE` DEGIL
===========================================================================
`SEQUENCE` cazip: atomik, hizli, kilit derdi yok. Ama uc sebeple
kullanilamaz:

 1. TENANT BASINA AYRI SAYMAK gerekiyor. Tek bir global dizi, A tesisinin
    fis numarasini B tesisinin islem hacmine bagimli kilardi — musteri
    "neden 1'den baslamiyor" diye hakli olarak sorardi. Tenant basina
    sequence acmak ise her yeni tesiste DDL calistirmak demek.
 2. YIL BASINDA SIFIRLANMASI gerekiyor (Turkiye'de fis numaralari yillik
    seri halinde tutulur). `SEQUENCE`i yilbasinda sifirlamak elle
    yapilan, unutulabilir bir bakim isi olurdu.
 3. `SEQUENCE` ISLEM DISIDIR: geri alinan bir islemde tuketilen numara
    KAYBOLUR ve seride bosluk kalir. Muhasebe serisinde bosluk,
    denetimde aciklanmasi gereken bir seydir.

Sayac tablosu ucunu de cozer: satir (tenant, tip, yil) ile adreslenir,
tek `INSERT ... ON CONFLICT DO UPDATE` ile atomik artar ve islem geri
alinirsa numara da geri alinir.

===========================================================================
KILIT NEDEN GEREKMIYOR
===========================================================================
Artirma TEK IFADEYLE yapiliyor:

    INSERT INTO belge_sayaci (...) VALUES (...)
    ON CONFLICT (tenant_id, tip, yil)
    DO UPDATE SET son_no = belge_sayaci.son_no + 1
    RETURNING son_no

Postgres catisan yazicilari o satirda siraya sokar; "once SELECT sonra
UPDATE" yazsaydik iki es zamanli fis AYNI numarayi alabilirdi ve bunu
ancak aylar sonra bir mutabakatta fark ederdik.

===========================================================================
`yil` NEDEN SUTUN, NEDEN `belge_no`DAN TURETILMIYOR
===========================================================================
Seri yillik oldugu icin sayac da yillik. `yil`i satirin bir parcasi
yapmak, 2027'nin ilk fisinin kendiliginden 1'den baslamasini saglar —
hicbir bakim adimi, hicbir zamanlanmis is gerekmez.
"""
from alembic import op

revision = "0058_belge_sayaci"
down_revision = "0057_kayitsiz_blok_onarimi"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"
TENANT_AYARI = "app.current_tenant_id"


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE belge_sayaci (
            tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            -- Belge TURU: tahsilat, gider, gelir, virman, iade, acilis,
            -- borclandirma, iptal. ENUM DEGIL METIN: yeni bir belge turu
            -- eklemek bir UYGULAMA karari ve her seferinde `ALTER TYPE`
            -- gerektirmemeli. Gecerli kume `app/belge_no.py`de.
            tip        text NOT NULL,
            yil        integer NOT NULL,
            son_no     bigint NOT NULL DEFAULT 0,
            updated_at timestamptz NOT NULL DEFAULT now(),
            PRIMARY KEY (tenant_id, tip, yil),
            CONSTRAINT ck_belge_sayaci_yil CHECK (yil BETWEEN 2000 AND 2200),
            CONSTRAINT ck_belge_sayaci_no CHECK (son_no >= 0)
        )
        """
    )
    op.execute("ALTER TABLE public.belge_sayaci ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE public.belge_sayaci FORCE ROW LEVEL SECURITY")
    op.execute(
        """
        CREATE POLICY belge_sayaci_tenant ON public.belge_sayaci
          USING (tenant_id = current_setting('{AYAR}', true)::uuid)
          WITH CHECK (tenant_id = current_setting('{AYAR}', true)::uuid)
        """.replace("{AYAR}", TENANT_AYARI)
    )
    # SILME YETKISI VERILMEDI ve bu bilincli: bir sayaci silmek, seriyi
    # bastan baslatmak ve daha once uretilmis numaralarin ikizini uretmek
    # demektir. Uygulamanin boyle bir ihtiyaci YOK.
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE ON public.belge_sayaci TO {APP_ROLE}"
    )

    # `finansal_hareket.belge_no` TENANT ICINDE BENZERSIZ olmali — merkezi
    # uretimin anlami bu. KISMI indeks: `belge_no` NULL olabilir (gecmis
    # satirlarda ve belgesiz hareketlerde) ve NULL'lar cakismaz.
    #
    # MEVCUT KOPYALARI KIRMAMAK ICIN once temizlik YAPILMADI: kisit
    # `CREATE UNIQUE INDEX` ile konuluyor ve gecmiste ayni numaradan iki
    # tane varsa goc DUSER. Bu bilincli — sessizce birini degistirmek,
    # bir muhasebe kaydini haber vermeden yeniden numaralandirmak olurdu.
    # Boyle bir durumda dogru davranis DURUP SORMAKTIR.
    op.execute(
        """
        CREATE UNIQUE INDEX uq_hareket_belge_no
          ON finansal_hareket (tenant_id, belge_no)
          WHERE belge_no IS NOT NULL
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_hareket_belge_no")
    op.execute("DROP POLICY IF EXISTS belge_sayaci_tenant ON public.belge_sayaci")
    op.execute("DROP TABLE IF EXISTS public.belge_sayaci")
