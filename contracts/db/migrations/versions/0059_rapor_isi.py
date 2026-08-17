"""(P167 Asama 5) RAPOR KUYRUGU — buyuk raporlar arka planda uretilir.

===========================================================================
NEDEN KUYRUK
===========================================================================
Brief: "PDF ve Excel uretimi sunucu tarafinda olsun; buyuk raporlar
kuyruga girsin ve hazir olunca indirilebilsin (senkron uretim tarayiciyi
kilitler)."

Olculebilir sorun: `borc_alacak` ve `detayli_borc` TUM defteri tarar. 500
daireli bir sitede bu, her dairenin butun tahakkuk ve tahsilat gecmisini
okuyup gecikme tazminatini tek tek hesaplamak demek. Istek yolunda
yapildiginda:
  * tarayici sekmesi yanit gelene kadar bekler (indirme baslamaz),
  * ters vekil (Caddy) ve uvicorn zaman asimi siniri devreye girebilir,
  * ve zaman asimi olursa is YARIM kalir — kullanici neyin olduğunu
    bilmez, yeniden dener, sunucu ayni isi bir kez daha yapar.

===========================================================================
`rapor_isi` — NE TUTAR, NE TUTMAZ
===========================================================================
PARAMETRE JSONB OLARAK SAKLANIR: is kuyruga girdikten sonra kullanicinin
sectigi suzgecler DEGISMEMELI. Yeniden calistirma ("ayni raporu tekrar
al") da bu kayittan beslenir.

DOSYA VERITABANINDA DEGIL MinIO'DA: bir Excel dosyasi megabaytlarca
olabilir ve `bytea` sutunu her yedegi, her replikasyonu ve her `SELECT *`i
sisirir. Tabloda yalnizca ANAHTAR durur.

`hata` METNI SAKLANIR: basarisiz bir is "durum=hata" deyip sebebi
soylemezse kullanici yalnizca yeniden deneyebilir. Metin KULLANICIYA
gosterilecek olandir (hata katalogundan cozulmus), yigin izi degil —
yigin izi log'a aittir ve arayuze sizmamalidir.

===========================================================================
SAHIPLIK VE TEMIZLIK
===========================================================================
`user_id` ZORUNLU ve gorunurluk kapisi odur: rapor ciktisi kisi adlari ve
site finansi tasir; ayni tesisteki baska bir yoneticinin baskasinin
istedigi dosyayi indirmesi icin bir sebep yok.

`created_at` INDEKSLI: temizlik (eski isleri ve dosyalarini silme) tarihe
gore tarar. Bu goc bir temizlik ISI KURMAZ — retention zaten gecelik
calisiyor (`app/retention.py`) ve kural oraya eklenmelidir; burada
yalnizca indeks hazir birakiliyor.
"""
from alembic import op

revision = "0059_rapor_isi"
down_revision = "0058_belge_sayaci"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"
TENANT_AYARI = "app.current_tenant_id"


def upgrade() -> None:
    op.execute(
        "CREATE TYPE rapor_is_durum AS ENUM "
        "('bekliyor', 'uretiliyor', 'hazir', 'hata')"
    )
    op.execute(
        """
        CREATE TABLE rapor_isi (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            user_id     uuid NOT NULL,
            kod         text NOT NULL,
            bicim       text NOT NULL,
            parametre   jsonb NOT NULL DEFAULT '{}'::jsonb,
            durum       rapor_is_durum NOT NULL DEFAULT 'bekliyor',
            dosya_key   text,
            dosya_adi   text,
            hata        text,
            created_at  timestamptz NOT NULL DEFAULT now(),
            biten_at    timestamptz,
            CONSTRAINT fk_rapor_isi_user
              FOREIGN KEY (user_id, tenant_id)
              REFERENCES app_user (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT ck_rapor_isi_bicim CHECK (bicim IN ('excel', 'pdf')),
            -- HAZIR BIR IS DOSYASIZ OLAMAZ. Kisit veritabaninda cunku
            -- "durum hazir ama dosya yok" hali, arayuzde tiklanan ve
            -- hicbir sey indirmeyen bir baglanti demektir — kullanicinin
            -- sebebini anlayamayacagi bir sessizlik.
            CONSTRAINT ck_rapor_isi_hazir
              CHECK (durum <> 'hazir' OR dosya_key IS NOT NULL)
        )
        """
    )
    op.execute(
        """
        CREATE INDEX ix_rapor_isi_sahip
          ON rapor_isi (tenant_id, user_id, created_at DESC)
        """
    )
    op.execute("ALTER TABLE public.rapor_isi ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE public.rapor_isi FORCE ROW LEVEL SECURITY")
    op.execute(
        """
        CREATE POLICY rapor_isi_tenant ON public.rapor_isi
          USING (tenant_id = current_setting('{AYAR}', true)::uuid)
          WITH CHECK (tenant_id = current_setting('{AYAR}', true)::uuid)
        """.replace("{AYAR}", TENANT_AYARI)
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON public.rapor_isi TO {APP_ROLE}"
    )


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS rapor_isi_tenant ON public.rapor_isi")
    op.execute("DROP TABLE IF EXISTS public.rapor_isi")
    # TIP TABLODAN SONRA: sutun hâlâ ona bagliyken `DROP TYPE` patlar.
    op.execute("DROP TYPE IF EXISTS rapor_is_durum")
