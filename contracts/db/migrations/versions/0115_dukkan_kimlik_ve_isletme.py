"""(DUKKAN F2) KIMLIK + ISLETME — arz tarafinin tablolari.

===========================================================================
NEDEN ARZ TARAFI ONCE
===========================================================================
Bos bir pazar yerine talep getirmek, kullaniciya "aradigin bolgede kimse
yok" gostermektir ve o kullanici BIR DAHA GELMEZ. Isletme toplamak yavas
bir istir; erken baslamali.

===========================================================================
KIMLIK TELEFONA CAPALI — OLCUME DAYANIYOR
===========================================================================
Yonetiyor'da `uq_app_user_telefon` telefonu GLOBAL benzersiz yapar, ama
e-posta yalnizca TESIS ICINDE benzersizdir (`uq_app_user_tenant_email`).

Sonucu su: e-posta bir KISIYI tekillestiremez. Ortak bir ofis/aile
e-postasi iki farkli tesiste iki FARKLI insana ait olabilir. Dukkan
kimligini e-postaya capalasaydik o iki insan tek hesapta BIRLESIRDI ve
birinin talepleri otekine gorunurdu — sessiz ve ciddi bir sizinti.

Bu yuzden: `dukkan_kullanici.telefon` UNIQUE ve dogrulanmadan hicbir
eylem yapilamaz.

===========================================================================
YONETIYOR BAGI NEDEN AYRI TABLO
===========================================================================
Bir kisi BIRDEN COK TESISTE olabilir. Uc sitede yoneticilik yapan biri
Yonetiyor'da 3 `app_user` satiridir ama TEK TELEFONDUR -> Dukkan'da tek
kullanici, UC bag. Bagi `dukkan_kullanici` uzerinde iki sutun olarak
tutsaydik bu kisi ya uc hesaba bolunur ya da uc tesisten ikisi kaybolurdu.

`yonetiyor_user_id` bilerek FK DEGIL: semalar arasi FK, `dukkan_app`
rolunun `public` yasagini delerdi (goc 0113). Butunluk uygulama
katmaninda; sarkan kayit riski kabul edilmis durumda.

===========================================================================
`dogrulama_seviyesi` VE ARAMADA GORUNURLUK
===========================================================================
    0  Kayitli        e-posta/telefon yok         -> ARAMADA CIKMAZ
    1  Telefon dogrulandi                          -> cikar
    2  Belge dogrulandi (INSAN inceledi)           -> "Dogrulanmis" rozeti
    3  (V2) Kurumsal — e-imza/MERSIS

Seviye 0'in aramada cikmamasi kritik: kayit ucretsiz ve aninda; gorunur
kilmak sahte isletmeyi (T3) DAVET etmek olurdu.

Telefon dogrulamasi KIMLIK KANITI DEGILDIR — yalnizca numaranin
kontrolunu kanitlar; on odemeli hat 50 liraya alinir. Seviye 1 ile 2'nin
ayri olmasinin sebebi bu: "bu numara gercek" demek "bu isletme gercek"
demek DEGIL. Ikisini tek rozette birlestirmek kullaniciya yalan olurdu.

GERI ALINABILIR: downgrade tablolari dusurur.
"""
from alembic import op

revision = "0115_dukkan_kimlik_ve_isletme"
down_revision = "0114_dukkan_veri_kaynagi"
branch_labels = None
depends_on = None

SEMA = "dukkan"
ROL = "dukkan_app"


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # KIMLIK
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        CREATE TABLE {SEMA}.dukkan_kullanici (
            id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            telefon               text NOT NULL UNIQUE,
            telefon_dogrulandi_at timestamptz,
            ad_soyad              text,
            -- E-posta UNIQUE DEGIL ve bu BILINCLI (bkz. baslik).
            eposta                text,
            eposta_dogrulandi_at  timestamptz,
            tip                   text NOT NULL DEFAULT 'bireysel'
                                  CHECK (tip IN ('bireysel', 'isletme_sahibi')),
            durum                 text NOT NULL DEFAULT 'aktif'
                                  CHECK (durum IN ('aktif', 'askida', 'silindi')),
            varsayilan_mahalle_id uuid REFERENCES {SEMA}.mahalle(id) ON DELETE SET NULL,
            kvkk_onay_at          timestamptz,
            son_giris_at          timestamptz,
            created_at            timestamptz NOT NULL DEFAULT now(),
            updated_at            timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        f"""
        CREATE TABLE {SEMA}.dukkan_yonetiyor_bag (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            dukkan_kullanici_id uuid NOT NULL
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE CASCADE,
            -- FK DEGIL: semalar arasi FK `dukkan_app`in public yasagini deler.
            yonetiyor_user_id   uuid NOT NULL,
            yonetiyor_tenant_id uuid NOT NULL,
            created_at          timestamptz NOT NULL DEFAULT now(),
            UNIQUE (yonetiyor_user_id, yonetiyor_tenant_id)
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_dky_bag_kullanici ON {SEMA}.dukkan_yonetiyor_bag "
        "(dukkan_kullanici_id);"
    )

    # TELEFON DOGRULAMA — kod HASH'LENEREK saklanir.
    #
    # Duz metin saklamak, veritabani okuyabilen birinin baskasinin
    # hesabina girmesini saglardi. Yonetiyor tarafinda ayni ilke zaten
    # parola icin uygulaniyor; OTP de bir kimlik dogrulayicisidir.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.telefon_dogrulama (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            telefon       text NOT NULL,
            kod_hash      text NOT NULL,
            amac          text NOT NULL DEFAULT 'giris'
                          CHECK (amac IN ('giris', 'isletme_telefon')),
            deneme        smallint NOT NULL DEFAULT 0,
            kullanildi_at timestamptz,
            gecerlilik    timestamptz NOT NULL,
            ip            text,
            created_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_telefon_dogrulama_arama ON {SEMA}.telefon_dogrulama "
        "(telefon, amac, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # ISLETME
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        CREATE TABLE {SEMA}.isletme (
            id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            sahip_kullanici_id    uuid NOT NULL
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE RESTRICT,
            ad                    text NOT NULL,
            slug                  text NOT NULL UNIQUE,
            aciklama              text,
            telefon               text NOT NULL,
            telefon_dogrulandi_at timestamptz,
            whatsapp              text,
            eposta                text,
            vergi_no              text,
            vergi_dairesi         text,
            adres_mahalle_id      uuid REFERENCES {SEMA}.mahalle(id) ON DELETE SET NULL,
            adres_detay           text,
            durum                 text NOT NULL DEFAULT 'taslak'
                CHECK (durum IN ('taslak','onay_bekliyor','onayli','askida','reddedildi')),
            dogrulama_seviyesi    smallint NOT NULL DEFAULT 0
                CHECK (dogrulama_seviyesi BETWEEN 0 AND 3),
            red_sebebi            text,
            askiya_alma_sebebi    text,
            -- TURETILMIS sutunlar. Kategori sayfasinda 20 isletme
            -- listelenirken her biri icin yorum toplami hesaplamak N+1
            -- uretir. TEK BIR fonksiyon gunceller; ikinci bir yazma yolu
            -- acilirsa sayi sessizce kayar (P192 "tek defter" dersinin
            -- buradaki karsiligi).
            ortalama_puan         numeric(3,2),
            yorum_sayisi          integer NOT NULL DEFAULT 0,
            siralama_puani        numeric(8,4) NOT NULL DEFAULT 0,
            onaylandi_at          timestamptz,
            created_at            timestamptz NOT NULL DEFAULT now(),
            updated_at            timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_isletme_sahip ON {SEMA}.isletme (sahip_kullanici_id);"
    )
    # Listeleme icin KISMI indeks: yalniz gorunur isletmeler. Kismi olmasi
    # onemli — taslak/askida kayitlar bu indekste yer kaplamaz.
    op.execute(
        f"CREATE INDEX ix_isletme_gorunur ON {SEMA}.isletme "
        "(siralama_puani DESC) WHERE durum = 'onayli' AND dogrulama_seviyesi >= 1;"
    )
    op.execute(
        f"CREATE INDEX ix_isletme_ad_trgm ON {SEMA}.isletme "
        "USING gin (ad gin_trgm_ops);"
    )
    # Moderasyon kuyrugu: bekleyenler tarih sirasinda.
    op.execute(
        f"CREATE INDEX ix_isletme_kuyruk ON {SEMA}.isletme (created_at) "
        "WHERE durum = 'onay_bekliyor';"
    )

    op.execute(
        f"""
        CREATE TABLE {SEMA}.isletme_kategori (
            isletme_id  uuid NOT NULL REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            kategori_id uuid NOT NULL REFERENCES {SEMA}.kategori(id) ON DELETE CASCADE,
            PRIMARY KEY (isletme_id, kategori_id)
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_isletme_kategori_ters ON {SEMA}.isletme_kategori "
        "(kategori_id, isletme_id);"
    )

    # HIZMET ALANI — eslesme motorunun TAMAMI bu tablo.
    # 40 mahalle secen bir isletme 40 satir; kucuk ve indekslenebilir.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.isletme_hizmet_alani (
            isletme_id uuid NOT NULL REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            mahalle_id uuid NOT NULL REFERENCES {SEMA}.mahalle(id) ON DELETE CASCADE,
            PRIMARY KEY (isletme_id, mahalle_id)
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_hizmet_alani_ters ON {SEMA}.isletme_hizmet_alani "
        "(mahalle_id, isletme_id);"
    )

    # BELGE — INCELEME IZI burada.
    #
    # Bir isletme sonradan sorun cikardiginda "biz bunu onaylarken neye
    # baktik?" sorusunun cevabi olmali. Iz yoksa cevap "hatirlamiyorum"dur
    # ve bu hem hukuki hem operasyonel olarak savunulamaz.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.isletme_belge (
            id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            isletme_id   uuid NOT NULL REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            tip          text NOT NULL
                CHECK (tip IN ('vergi_levhasi','ustalik_belgesi','sicil','diger')),
            dosya_yolu   text NOT NULL,
            durum        text NOT NULL DEFAULT 'bekliyor'
                CHECK (durum IN ('bekliyor','onaylandi','reddedildi')),
            inceleyen_id uuid REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE SET NULL,
            incelendi_at timestamptz,
            not_metni    text,
            created_at   timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_isletme_belge_isletme ON {SEMA}.isletme_belge (isletme_id);"
    )

    op.execute(
        f"""
        CREATE TABLE {SEMA}.isletme_calisma_saati (
            isletme_id uuid NOT NULL REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            gun        smallint NOT NULL CHECK (gun BETWEEN 0 AND 6),
            acilis     time,
            kapanis    time,
            kapali     boolean NOT NULL DEFAULT false,
            PRIMARY KEY (isletme_id, gun)
        );
        """
    )

    # ------------------------------------------------------------------ #
    # MODERATOR + DENETIM
    # ------------------------------------------------------------------ #
    # Moderator AYRI TABLO, `dukkan_kullanici` uzerinde bayrak DEGIL:
    # bayrak olsaydi bir UPDATE hatasi siradan bir kullaniciyi moderator
    # yapabilirdi. Ayri tabloya satir eklemek KASITLI bir eylemdir.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.moderator (
            kullanici_id uuid PRIMARY KEY
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE CASCADE,
            atayan       text,
            created_at   timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    # DENETIM — Dukkan Yonetiyor'un `audit_log`una YAZAMAZ (goc 0113).
    # Kendi denetim tablosu bu yuzden var.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.denetim (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            aktor_id   uuid REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE SET NULL,
            aktor_tip  text NOT NULL DEFAULT 'kullanici',
            eylem      text NOT NULL,
            hedef_tip  text,
            hedef_id   uuid,
            gerekce    text,
            meta       jsonb NOT NULL DEFAULT '{{}}'::jsonb,
            ip         text,
            created_at timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_denetim_hedef ON {SEMA}.denetim "
        "(hedef_tip, hedef_id, created_at DESC);"
    )

    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA {SEMA} "
        f"TO {ROL};"
    )
    # DENETIM APPEND-ONLY: UPDATE/DELETE geri alinir.
    # Gerekce Yonetiyor'un `audit_log`uyla ayni (goc 0002): bir moderasyon
    # karari sonradan "hic verilmemis" hale getirilemez. Itiraz sureci
    # buna dayaniyor.
    op.execute(f"REVOKE UPDATE, DELETE ON {SEMA}.denetim FROM {ROL};")


def downgrade() -> None:
    for t in (
        "denetim", "moderator", "isletme_calisma_saati", "isletme_belge",
        "isletme_hizmet_alani", "isletme_kategori", "isletme",
        "telefon_dogrulama", "dukkan_yonetiyor_bag", "dukkan_kullanici",
    ):
        op.execute(f"DROP TABLE IF EXISTS {SEMA}.{t} CASCADE;")
