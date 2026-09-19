"""(P241 §2) VARDIYA EKRANI YENIDEN — izin, molalar, rol/lokasyon, yayin.

===========================================================================
REFERANS KORU KORUNE KOPYALANMADI
===========================================================================
Istek bunu acikca soyluyor: referans yazilim SUBE soruyor ve calisani
SIFIRDAN eklettiriyor. Bizde sube YOK (tesis var), calisan ZATEN kayitli
(`app_user`). Bu yuzden:
  * "Sube lokasyonu" -> BLOK (FK) ya da ORTAK ALAN metni,
  * "calisan ekle" -> YOK; personel listeden secilir.

===========================================================================
IZIN AYRI TABLO — vardiya satirina "tur=izin" yazilmadi
===========================================================================
Izni `vardiya_plani`ya bir tur olarak eklemek kolay gorunurdu ve YANLIS
olurdu:
  * izin TARIH ARALIGIDIR (12-20 Agustos), vardiya GUNDUR;
  * izin ONAY tasir, vardiya tasimaz;
  * izinli gun vardiya URETMEZ — ayni tabloda olsalardi mesai hesabi
    (`routers/mesai.py`, `durum='planli'` okur) izni CALISMA SAYARDI ve
    izne cikan kisiye fazla mesai yazilirdi.

===========================================================================
MOLALAR JSONB — ayri tablo acilmadi
===========================================================================
Molalar HEP BIRLIKTE okunur/yazilir ve bagimsiz bir yasami yoktur
(`vardiya_kalibi.dilimler` ile ayni gerekce). Sira da dizide korunur.

MOLA CALISMA SURESINDEN DUSER: 4857 md. 68/son "ara dinlenmeleri
calisma suresinden sayilmaz". Bu yalniz izgaradaki toplami degil MESAI
HESABINI da duzeltiyor — bugune kadar 12 saatlik bir vardiyanin 1
saatlik molasi da fazla mesai olarak ucretlendiriliyordu.

===========================================================================
YAYIN: ENUM DEGIL ZAMAN DAMGASI
===========================================================================
`yayinlandi_at` NULL ise satir TASLAKTIR; doluysa yayinlanmistir.
Enum yerine damga secildi cunku istek "yayinlanmis planda degisiklik
yapilirsa TEKRAR yayinlansin" diyor: `updated_at > yayinlandi_at`
karsilastirmasi bunu EK BIR SUTUN OLMADAN verir ve "kac degisiklik
yayinlanacak" sayisi da ayni karsilastirmadan cikar.

MEVCUT SATIRLAR YAYINLANMIS SAYILIR: aksi halde goc calistigi anda
sahadaki herkesin plani EKRANDAN KAYBOLURDU.
"""
from alembic import op

revision = "0145_vardiya_yeniden"
down_revision = "0144_bakim_takibi"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    # ----------------------------- IZIN --------------------------------- #
    op.execute(
        "CREATE TYPE izin_turu AS ENUM "
        "('yillik', 'mazeret', 'hastalik', 'ucretsiz', 'resmi_tatil');"
    )
    op.execute(
        "CREATE TYPE izin_durum AS ENUM "
        "('onay_bekliyor', 'onaylandi', 'reddedildi');"
    )
    op.execute(
        """
        CREATE TABLE vardiya_izin (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            user_id     uuid NOT NULL,
            tur         izin_turu NOT NULL,
            baslangic   date NOT NULL,
            bitis       date NOT NULL,
            -- SAATLIK IZIN: `tum_gun=false` ise saatler ZORUNLU ve izin
            -- TEK GUNE aittir. Cok gunlu saatlik izin ("her gun 09-11")
            -- baska bir kavramdir ve uydurulmadi.
            tum_gun     boolean NOT NULL DEFAULT true,
            baslangic_saat time,
            bitis_saat  time,
            durum       izin_durum NOT NULL DEFAULT 'onay_bekliyor',
            not_metni   text,
            olusturan_user_id uuid,
            onaylayan_user_id uuid,
            onay_at     timestamptz,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_izin_aralik CHECK (bitis >= baslangic),
            CONSTRAINT ck_izin_saat CHECK (
                (tum_gun AND baslangic_saat IS NULL AND bitis_saat IS NULL)
                OR (NOT tum_gun AND baslangic_saat IS NOT NULL
                    AND bitis_saat IS NOT NULL AND bitis = baslangic)
            ),
            CONSTRAINT fk_izin_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute("CREATE INDEX ix_vardiya_izin_tenant ON vardiya_izin (tenant_id);")
    # Izgara her cizimde "bu kisi bu tarihte izinli mi" diye soruyor.
    op.execute(
        "CREATE INDEX ix_vardiya_izin_kisi "
        "ON vardiya_izin (tenant_id, user_id, baslangic, bitis);"
    )

    op.execute("ALTER TABLE vardiya_izin ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE vardiya_izin FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY vardiya_izin_isolation ON vardiya_izin
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON vardiya_izin TO {APP_ROLE};"
    )

    # ------------------------ VARDIYA SATIRI ---------------------------- #
    #: `[{"tur": "yasal"|"sirket", "baslangic": "12:30"|null, "dakika": 30}]`
    op.execute(
        "ALTER TABLE vardiya_plani ADD COLUMN molalar jsonb "
        "NOT NULL DEFAULT '[]'::jsonb;"
    )
    #: BU VARDIYADA hangi rolle calisiyor (guvenlik, temizlik...).
    #: `app_user.role` DEGIL: ayni kisi bir gun guvenlik, ertesi gun
    #: temizlik vardiyasi alabilir ve hesabinin rolu bundan degismez.
    op.execute("ALTER TABLE vardiya_plani ADD COLUMN vardiya_rolu text;")
    #: LOKASYON — blok BAGI ya da serbest alan (otopark, bahce, kapi).
    op.execute("ALTER TABLE vardiya_plani ADD COLUMN blok_id uuid;")
    op.execute("ALTER TABLE vardiya_plani ADD COLUMN alan text;")
    op.execute(
        """
        ALTER TABLE vardiya_plani ADD CONSTRAINT fk_vardiya_plani_blok
            FOREIGN KEY (blok_id, tenant_id)
            REFERENCES building_block (id, tenant_id) ON DELETE SET NULL;
        """
    )
    op.execute("ALTER TABLE vardiya_plani ADD COLUMN yayinlandi_at timestamptz;")
    # MEVCUT SATIRLAR YAYINLANMIS: aksi halde goc calistigi anda sahadaki
    # herkesin plani ekrandan kaybolurdu.
    op.execute("UPDATE vardiya_plani SET yayinlandi_at = created_at;")
    # Personelin okumasi bu sutundan suzuluyor.
    op.execute(
        "CREATE INDEX ix_vardiya_plani_yayin "
        "ON vardiya_plani (tenant_id, yayinlandi_at);"
    )

    # `vardiya_plani` UNIQUE (id, tenant_id) TASIMIYORDU — izin/blok
    # baglari icin degil ama ILERIDE bir bilesik FK gerekirse diye
    # EKLENMEDI: var olmayan bir ihtiyac icin kisit yazmak, sonradan
    # kaldirilmasi gereken bir sey birakmaktir.

    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'vardiya_yayinlandi';"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_vardiya_plani_yayin;")
    op.execute(
        "ALTER TABLE vardiya_plani DROP CONSTRAINT IF EXISTS fk_vardiya_plani_blok;"
    )
    for sutun in ("yayinlandi_at", "alan", "blok_id", "vardiya_rolu", "molalar"):
        op.execute(f"ALTER TABLE vardiya_plani DROP COLUMN IF EXISTS {sutun};")
    op.execute("DROP TABLE IF EXISTS vardiya_izin;")
    op.execute("DROP TYPE IF EXISTS izin_durum;")
    op.execute("DROP TYPE IF EXISTS izin_turu;")
