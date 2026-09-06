"""(DUKKAN F1) `dukkan` SEMASI + `dukkan_app` ROLU + LOKASYON/KATEGORI.

===========================================================================
NEDEN AYRI SEMA DEGIL, AYRI **ROL**
===========================================================================
Kisit soyle konuldu: "Dukkan, Yonetiyor'un veritabanina DOGRUDAN YAZMASIN;
okumasi da API uzerinden olsun." Ayni PostgreSQL ornegi kullanilacak, ayri
sunucu kurulmayacak.

Ayri sema bu kisiti TEK BASINA ZORLAMAZ. `dukkan` semasi acmak yalnizca
isimleri ayirir; `dukkan` kodundaki bir hata `public.app_user`'a pekala
yazabilir. Yorum satiriyla yazilmis bir kural kisit degildir.

Kisiti ROL zorlar:
  * `dukkan_app` rolunun `public` semasindaki TABLOLARDA hicbir GRANT'i yok.
  * Dukkan modulu YALNIZ bu rolle baglanan ayri bir engine kullanir.
  * Dolayisiyla `SELECT * FROM public.app_user` -> `permission denied`.

Ve en onemlisi: bu kisit ARTIK TEST EDILEBILIR. `test_dukkan_sinir.py`
tam olarak bunu olcuyor. Kural bir gun bir `import` ile delinirse test
kirmizi yanar; belgedeki cumle yanmaz.

===========================================================================
SINIRIN GERCEKTE NEREDE OLDUGU (durust anlatim)
===========================================================================
PostgreSQL'de `public` semasi uzerindeki USAGE yetkisi varsayilan olarak
`PUBLIC` sozde-rolune verilidir ve HER rol PUBLIC uyesidir; bunu tek bir
rolden geri almak mumkun degildir. Yani `dukkan_app` semayi GOREBILIR.

Asil engel TABLO duzeyinde: tablolarin PUBLIC'e varsayilan GRANT'i YOKTUR,
`setup_app_role.py` DML'i yalnizca `app_rw`'ye verir. `dukkan_app` hicbir
tablo GRANT'i almadigi icin okuma da yazma da reddedilir.

Bu ayrimi burada aciklikla yaziyorum cunku "sema gorunuyor" ile "tablo
okunabiliyor" ayni sey degil; testin hangi hatayi bekledigi buna bagli
(`permission denied for table ...`).

===========================================================================
NEDEN AYRI VERITABANI DEGIL
===========================================================================
Ayri veritabani tek Alembic zincirini, tek baglanti havuzunu ve tek
yedekleme yolunu bolerdi. Tek sunucuda baglanti KIT kaynak — P187'de
prod'da idle-in-transaction 90/100 ile olculdu. Ayrica sonradan iki veriyi
bir arada okumak gerektiginde dblink/FDW'ye mahkum olunurdu.

===========================================================================
GOC ZINCIRI: TEK ZINCIR (olculdu, Ö3)
===========================================================================
Ikinci bir Alembic zinciri KURULMADI. Olcum sunu gosterdi: `migrate`
servisi zaten OWNER (`POSTGRES_USER`) ile baglaniyor, `api`/`worker`/`beat`
ise `APP_DB_USER` ile. Yani "gocu owner kosar, uygulama kisitli rolle
baglanir" deseni evde ZATEN VAR (bkz. `infra/scripts/setup_app_role.py`).
Dukkan bu desene ucuncu bir rol olarak katiliyor; ikinci bir zincir,
ikinci bir `migrate` servisi ve ikinci bir yedekleme yolu getirmekten
baska bir sey yapmazdi.

`dukkan_app` NOLOGIN olusturulur; LOGIN + parolayi `setup_dukkan_role.py`
verir (`app_rw` ile birebir ayni kalip).

GERI ALINABILIR: `downgrade` semayi ve rolu dusurur.
"""
from alembic import op

# revision identifiers.
revision = "0113_dukkan_sema_ve_rol"
down_revision = "0112_sikayet_harita_saat"
branch_labels = None
depends_on = None

SEMA = "dukkan"
DUKKAN_ROL = "dukkan_app"


def upgrade() -> None:
    # pg_trgm: isletme adi aramasi icin (01-veri-modeli §7). PostGIS YOK —
    # eslesme mahalle kimligi uzerinden yapiliyor, yaricap sorgusu yok.
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")

    op.execute(f"CREATE SCHEMA IF NOT EXISTS {SEMA};")

    op.execute(
        f"""
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{DUKKAN_ROL}') THEN
                CREATE ROLE {DUKKAN_ROL} NOLOGIN;
            END IF;
        END
        $$;
        """
    )

    # ------------------------------------------------------------------ #
    # SINIR: dukkan_app'in `public` semasinda ISI YOK.
    # ------------------------------------------------------------------ #
    # Asagidaki REVOKE'lar cogu durumda ZATEN bos bir kumeden geri alir
    # (dukkan_app hicbir GRANT almamisti). Yine de ACIKCA yaziliyorlar:
    # bu satirlar KASTI belgeliyor. Bir gun biri `setup_app_role.py`'ye
    # dukkan_app'i eklerse, buradaki satirlar o degisikligin bilincli
    # olmasi gerektigini soyluyor — ve `test_dukkan_sinir.py` kirilir.
    op.execute(f"REVOKE ALL ON ALL TABLES IN SCHEMA public FROM {DUKKAN_ROL};")
    op.execute(f"REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM {DUKKAN_ROL};")
    op.execute(f"REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM {DUKKAN_ROL};")
    op.execute(f"REVOKE CREATE ON SCHEMA public FROM {DUKKAN_ROL};")

    # Simetrik koruma: `app_rw` de Dukkan tablolarina DOKUNAMAZ. Kisit tek
    # yonlu istenmisti, ama iki yonlu kurmak bedava ve "hangi kod hangi
    # veriye bakiyor" sorusunu kesin yanitliyor. Yonetiyor tarafi Dukkan
    # verisine ihtiyac duyarsa bunu Dukkan'in KENDI ucundan alir.
    op.execute(f"REVOKE ALL ON SCHEMA {SEMA} FROM app_rw;")

    op.execute(f"GRANT USAGE ON SCHEMA {SEMA} TO {DUKKAN_ROL};")

    # ------------------------------------------------------------------ #
    # LOKASYON AGACI — ulke > il > ilce > mahalle
    # ------------------------------------------------------------------ #
    # `slug` KALICIDIR ve elle yonetilir: SEO yolu (`/istanbul/cekmekoy/
    # catalmese/elektrikci`) ona bagli. Slug'i addan her seferinde turetmek,
    # idari bir ad degisikliginde SESSIZCE olu baglanti uretirdi.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.ulke (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            kod         text NOT NULL UNIQUE,
            ad          text NOT NULL,
            created_at  timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        f"""
        CREATE TABLE {SEMA}.il (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ulke_id     uuid NOT NULL REFERENCES {SEMA}.ulke(id) ON DELETE CASCADE,
            ad          text NOT NULL,
            plaka       smallint,
            slug        text NOT NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            UNIQUE (ulke_id, slug)
        );
        """
    )
    op.execute(
        f"""
        CREATE TABLE {SEMA}.ilce (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            il_id       uuid NOT NULL REFERENCES {SEMA}.il(id) ON DELETE CASCADE,
            ad          text NOT NULL,
            slug        text NOT NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            UNIQUE (il_id, slug)
        );
        """
    )
    # `tip`: mahalle / koy / belde. Ayri tablo yapmadim — ucu de ayni
    # hiyerarsik konumda ve ayni sekilde adreslenip aranıyor; ayirmak
    # her sorguya bir UNION eklerdi.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.mahalle (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ilce_id     uuid NOT NULL REFERENCES {SEMA}.ilce(id) ON DELETE CASCADE,
            ad          text NOT NULL,
            slug        text NOT NULL,
            posta_kodu  text,
            tip         text NOT NULL DEFAULT 'mahalle'
                        CHECK (tip IN ('mahalle', 'koy', 'belde')),
            created_at  timestamptz NOT NULL DEFAULT now(),
            UNIQUE (ilce_id, slug)
        );
        """
    )

    # ------------------------------------------------------------------ #
    # KATEGORI — iki seviye (ana > hizmet)
    # ------------------------------------------------------------------ #
    # Ucuncu seviye BILEREK yok: hem URL'i hem kullaniciyi uzatir. Daraltma
    # V2'de kategoriye bagli SORU SETI ile yapilacak (armut kalibi), derin
    # agacla degil.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.kategori (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ust_id      uuid REFERENCES {SEMA}.kategori(id) ON DELETE CASCADE,
            ad          text NOT NULL,
            slug        text NOT NULL,
            aciklama    text,
            ikon        text,
            sira        integer NOT NULL DEFAULT 0,
            aktif       boolean NOT NULL DEFAULT true,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    # Kismi benzersiz indeks: ust_id NULL olan (ana) kategorilerde de slug
    # tekil olmali. `UNIQUE (ust_id, slug)` bunu YAPMAZ — NULL'lar birbirine
    # esit sayilmadigi icin iki ana kategori ayni slug'i alabilirdi ve
    # /kategori/{slug} hangisini gosterecegini bilemezdi.
    op.execute(
        f"CREATE UNIQUE INDEX uq_kategori_ana_slug ON {SEMA}.kategori (slug) "
        "WHERE ust_id IS NULL;"
    )
    op.execute(
        f"CREATE UNIQUE INDEX uq_kategori_alt_slug ON {SEMA}.kategori (ust_id, slug) "
        "WHERE ust_id IS NOT NULL;"
    )

    op.execute(f"CREATE INDEX ix_il_ulke ON {SEMA}.il (ulke_id);")
    op.execute(f"CREATE INDEX ix_ilce_il ON {SEMA}.ilce (il_id);")
    op.execute(f"CREATE INDEX ix_mahalle_ilce ON {SEMA}.mahalle (ilce_id);")
    op.execute(
        f"CREATE INDEX ix_mahalle_ad_trgm ON {SEMA}.mahalle "
        "USING gin (ad gin_trgm_ops);"
    )

    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA {SEMA} "
        f"TO {DUKKAN_ROL};"
    )
    # Gelecekte bu semaya eklenecek tablolar icin de otomatik GRANT.
    # Olmazsa her yeni Dukkan tablosu sessizce erisilemez olur ve hata
    # calisma aninda "permission denied" olarak cikar.
    op.execute(
        f"ALTER DEFAULT PRIVILEGES IN SCHEMA {SEMA} "
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {DUKKAN_ROL};"
    )
    op.execute(
        f"ALTER DEFAULT PRIVILEGES IN SCHEMA {SEMA} "
        f"GRANT USAGE, SELECT ON SEQUENCES TO {DUKKAN_ROL};"
    )


def downgrade() -> None:
    op.execute(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {SEMA} "
               f"REVOKE ALL ON TABLES FROM {DUKKAN_ROL};")
    op.execute(f"ALTER DEFAULT PRIVILEGES IN SCHEMA {SEMA} "
               f"REVOKE ALL ON SEQUENCES FROM {DUKKAN_ROL};")
    op.execute(f"DROP SCHEMA IF EXISTS {SEMA} CASCADE;")
    # Rol birakiliyor mu? DUSURULUYOR: sema gittiginde rolun sahipligi
    # kalmiyor. Ancak baska bir veritabaninda ayni rol kullanilıyorsa
    # DROP ROLE hata verir; bu yuzden kosullu ve hatayi yutmayan bicimde.
    op.execute(
        f"""
        DO $$
        BEGIN
            IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{DUKKAN_ROL}') THEN
                EXECUTE 'DROP OWNED BY {DUKKAN_ROL}';
                EXECUTE 'DROP ROLE {DUKKAN_ROL}';
            END IF;
        END
        $$;
        """
    )
