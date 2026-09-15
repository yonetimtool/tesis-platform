"""(P237 §3) ANKET — hedef kitle, gorsel, tarih araligi, ANONIMLIK.

===========================================================================
OLCULEN DURUM (once)
===========================================================================
`anket` uc alan tasiyordu: baslik, aciklama, kapanis_at. Panel formu
bunlardan YALNIZ baslik'i soruyordu. Eksikler:

  * gorsel        YOK
  * baslangic     YOK (anket hemen aciliyordu)
  * hedef kitle   YOK (herkes gorurdu)
  * ANONIMLIK     YOK (`anket_oy.user_id` her zaman doluydu)
  * katilim orani HESAPLANAMIYOR (payda yok: "kac kisiye gitti")

===========================================================================
ANONIMLIK VERITABANI DUZEYINDE GARANTI EDILIR
===========================================================================
Brief: "Anonim ise oylar KESINLIKLE kimliksiz kalsin; yonetici veya
platform admini bile goremesin." Uygulama katmaninda "bu ucta user_id
dondurme" demek YETMEZ: veri ORADA durdugu surece bir sonraki sorgu,
bir sonraki rapor ya da bir veritabani yedegi onu acar.

Bu yuzden anonim ankette `anket_oy.user_id` **NULL**dur ve bunu bir
CHECK kisiti zorlar. Kisitin `anket.anonim`e ulasabilmesi icin anonimlik
oy satirina DENORMALIZE edilir ve BILESIK YABANCI ANAHTARLA ankete
baglanir:

    anket_oy (anket_id, anonim) -> anket (id, anonim)
    CHECK (NOT anonim OR user_id IS NULL)

Bu iki satir birlikte sunu garanti eder: anonim bir ankette kimlik
tasiyan bir oy satiri YAZILAMAZ. Uygulama hatasi, elle SQL, hatta
bakim betigi — hicbiri gecemez.

===========================================================================
TEK OY KURALI ANONIMDE NASIL KORUNUYOR
===========================================================================
Kimlik oy satirindan cikinca "bir kisi bir kez" nasil zorlanir? AYRI
DEFTER: `anket_katilim` yalnizca KIMIN oy verdigini tutar, NEYE oy
verdigini TUTMAZ. Iki tablo arasinda baglanti YOKTUR — katilim defteri
ile oy defterini yan yana koyup kimin neye oy verdigini cikarmak
mumkun degil (sira/zaman uzerinden eslestirmeyi engellemek icin
`anket_katilim` zaman damgasi GUNE yuvarlanir).

===========================================================================
ANONIMLIK SONRADAN DEGISTIRILEMEZ (KILIT)
===========================================================================
Brief: "Degistirilebilirse 'anonim sanip oy veren' kisinin kimligi
sonradan acilir; bu bir guven ihlalidir."

IKI KATMAN:
  1. Yukaridaki bilesik FK: ankette oy varken `anonim` degistirilmek
     istenirse referans veren satirlar yuzunden PostgreSQL REDDEDER.
  2. Tetikleyici: HENUZ OY YOKKEN bile degisimi reddeder. Cunku 1.
     katman yalniz oy varsa korur; anket acildiktan sonra ilk oy
     gelmeden yapilan bir degisiklik de kullaniciya gosterilmis
     vaadi bozardi (anket listede "anonim" yaziyordu).
"""
from alembic import op

revision = "0137_anket_hedef_kitle_anonim"
down_revision = "0136_gorev_alt_adimlari"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

ANONIM_KILIT = """
CREATE OR REPLACE FUNCTION public.anket_anonim_kilit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.anonim IS DISTINCT FROM OLD.anonim THEN
        RAISE EXCEPTION 'anket_anonimlik_degistirilemez'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
"""


def upgrade() -> None:
    # --- ANKET: gorsel, tarih araligi, hedef kitle, anonimlik -------------
    op.execute("ALTER TABLE anket ADD COLUMN gorsel_key text;")
    # BASLANGIC: `kapanis_at` zaten vardi. Ikisi de OPSIYONEL — bos
    # birakilan bir anket "hemen acik, suresiz" demektir ve en sik
    # kullanilan hal budur.
    op.execute("ALTER TABLE anket ADD COLUMN baslangic_at timestamptz;")
    # HEDEF KITLE: ROL DIZISI. NULL/bos = HERKES.
    #
    # Ayri bir `anket_hedef` tablosu KURULMADI: hedef kitle bir anketin
    # ozelligidir, ayri yasam dongusu olan bir varlik degil; her okumada
    # bir JOIN daha istemek ve tutarliligi iki yerde korumak icin sebep
    # yok. Dizi PostgreSQL'de indekslenebilir ve `= ANY()` ile sorgulanir.
    op.execute("ALTER TABLE anket ADD COLUMN hedef_roller text[];")
    # MALIK/KIRACI AYRIMI: `unit_resident.rol_tipi` ZATEN bu ayrimi
    # tasiyor (P218: `oturuyor` bayragi mulkiyetten ayri). NULL = ayrim
    # yapma. Yalniz `resident` hedeflendiginde anlamlidir.
    op.execute(
        "ALTER TABLE anket ADD COLUMN hedef_sakin_tipi text "
        "CHECK (hedef_sakin_tipi IN ('malik', 'kiraci'));"
    )
    op.execute(
        "ALTER TABLE anket ADD COLUMN anonim boolean NOT NULL DEFAULT false;"
    )
    # BILESIK FK'nin HEDEFI: `anket_oy` (anket_id, anonim) ciftine
    # baglanacak; PostgreSQL referans verilen sutunlarda BENZERSIZ bir
    # kisit ister.
    op.execute(
        "ALTER TABLE anket ADD CONSTRAINT uq_anket_id_anonim "
        "UNIQUE (id, anonim);"
    )
    op.execute(ANONIM_KILIT)
    op.execute(
        "CREATE TRIGGER trg_anket_anonim_kilit BEFORE UPDATE ON anket "
        "FOR EACH ROW EXECUTE FUNCTION public.anket_anonim_kilit();"
    )

    # --- ANKET_OY: kimlik ARTIK OPSIYONEL, anonimde YASAK ----------------
    op.execute("ALTER TABLE anket_oy ALTER COLUMN user_id DROP NOT NULL;")
    op.execute(
        "ALTER TABLE anket_oy ADD COLUMN anonim boolean NOT NULL DEFAULT false;"
    )
    op.execute(
        "ALTER TABLE anket_oy ADD CONSTRAINT fk_anket_oy_anonim "
        "FOREIGN KEY (anket_id, anonim) REFERENCES anket (id, anonim);"
    )
    # ANONIMLIK GARANTISI — TEK SATIR. Yonetici de, platform admini de,
    # elle SQL de gecemez: veri ORADA DEGIL.
    op.execute(
        "ALTER TABLE anket_oy ADD CONSTRAINT ck_anket_oy_anonim_kimliksiz "
        "CHECK (NOT anonim OR user_id IS NULL);"
    )
    # Eski BENZERSIZLIK (tenant, anket, user) anonimde ise yaramaz
    # (user_id NULL -> PostgreSQL'de NULL'lar cakismaz). Tek oy kurali
    # artik `anket_katilim`da; buradaki kisit ADLI anketler icin KALIR.
    op.execute("ALTER TABLE anket_oy DROP CONSTRAINT IF EXISTS uq_anket_oy;")
    op.execute(
        "CREATE UNIQUE INDEX uq_anket_oy_adli ON anket_oy "
        "(tenant_id, anket_id, user_id) WHERE user_id IS NOT NULL;"
    )

    # --- ANKET_KATILIM: KIM oy verdi (NEYE DEGIL) ------------------------
    op.execute(
        """
        CREATE TABLE anket_katilim (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            anket_id   uuid NOT NULL,
            user_id    uuid NOT NULL,
            -- ZAMAN GUNE YUVARLANIR: tam zaman damgasi, katilim defteri
            -- ile oy defterini SIRAYA gore eslestirmeyi mumkun kilardi
            -- ve anonimlik pratikte cozulurdu.
            gun        date NOT NULL DEFAULT (now() AT TIME ZONE 'UTC')::date,
            CONSTRAINT uq_anket_katilim UNIQUE (tenant_id, anket_id, user_id),
            CONSTRAINT fk_anket_katilim_anket
                FOREIGN KEY (anket_id, tenant_id)
                REFERENCES anket (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_anket_katilim_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute("ALTER TABLE anket_katilim ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE anket_katilim FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY anket_katilim_isolation ON anket_katilim
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON anket_katilim TO {APP_ROLE};"
    )

    # --- BILDIRIM TIPI ---------------------------------------------------
    # Anket acilinca HEDEF KITLEYE bildirim. `duyuru` tipine bindirilmedi:
    # bildirim tercihinde "duyurulari al, anket bildirimini alma" demek
    # mumkun kalmali (0131/0136 ile ayni gerekce).
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'anket_acildi';"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS anket_katilim;")
    op.execute("DROP INDEX IF EXISTS uq_anket_oy_adli;")
    op.execute(
        "ALTER TABLE anket_oy DROP CONSTRAINT IF EXISTS ck_anket_oy_anonim_kimliksiz;"
    )
    op.execute("ALTER TABLE anket_oy DROP CONSTRAINT IF EXISTS fk_anket_oy_anonim;")
    op.execute("ALTER TABLE anket_oy DROP COLUMN IF EXISTS anonim;")
    # Anonim oylar silinmeden NOT NULL geri konamaz; geri alma onlari
    # SILER — anonim oy zaten kimliksizdir, tasinacak bir sey yok.
    op.execute("DELETE FROM anket_oy WHERE user_id IS NULL;")
    op.execute("ALTER TABLE anket_oy ALTER COLUMN user_id SET NOT NULL;")
    op.execute(
        "ALTER TABLE anket_oy ADD CONSTRAINT uq_anket_oy "
        "UNIQUE (tenant_id, anket_id, user_id);"
    )
    op.execute("DROP TRIGGER IF EXISTS trg_anket_anonim_kilit ON anket;")
    op.execute("DROP FUNCTION IF EXISTS public.anket_anonim_kilit();")
    op.execute("ALTER TABLE anket DROP CONSTRAINT IF EXISTS uq_anket_id_anonim;")
    for k in ("anonim", "hedef_sakin_tipi", "hedef_roller", "baslangic_at", "gorsel_key"):
        op.execute(f"ALTER TABLE anket DROP COLUMN IF EXISTS {k};")
