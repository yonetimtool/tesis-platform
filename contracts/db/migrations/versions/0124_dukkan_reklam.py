"""(DUKKAN F8b) REKLAM — kapsam/sure/fiyat, slot siniri, bekleme listesi.

===========================================================================
GELIR MODELI
===========================================================================
Platformun TEK geliri. Isletme -> platform DOGRUDAN SATIS; odeme
araciligi degil, kendi hizmetimizin satisi. Hizmet bedeli akisiyla
(talep/teklif/is) HICBIR baglantisi yok ve olmayacak (goc 0123).

===========================================================================
DORT TABLO, DORT AYRI IS
===========================================================================
`reklam_paketi`      -> SATILAN SEY (kapsam + sure + fiyat). Yonetilebilir
                        bir katalog; fiyat kodda degil VERIDE.
`reklam_slot_kurali` -> KAC TANE satilabilir. Sayilar KODA GOMULMUYOR:
                        ilk uc ayda gercek veriyle ayarlanacaklar.
`reklam`             -> SATIN ALINMIS ve YAYINDA olan reklam.
`reklam_bekleme`     -> Bolge doluyken sira bekleyen isletme.

Odeme kaydi AYRI bir gocte (`reklam_satin_alma`, F8c): fatura alanlari
ve saglayici izleri ayri bir konudur ve reklam yayin mantigi onlar
olmadan da tamdir (elle acilan/hediye reklam mumkun olmali).

===========================================================================
SLOT SINIRI NEDEN VERIDE
===========================================================================
Mahalle 1 / ilce 2 / il 3 ve %20 tavan — bunlar TAHMIN. Bir mahallede kac
isletme oldugunu, bir ilcede kac arama yapildigini bugun bilmiyoruz.
Kodda sabit olsalardi, her ayar bir dagitim demek olurdu.

Tablo olarak: kapsam basina bir satir, `etkin_at` ile versiyonlu. Eski
satir SILINMEZ — "o tarihte kural neydi" sorusu bir itirazda sorulur.

===========================================================================
CAKISMA VERITABANINDA ENGELLENIYOR
===========================================================================
Ayni bolge + ayni kategori + cakisan tarih araligi icin slot sayisi
asilamaz. Uygulama duzeyinde saymak, es zamanli iki satin almada
IKISINI DE gecirirdi (klasik TOCTOU). Kisit `EXCLUDE` ile veritabaninda:
`btree_gist` eklentisi gerekiyor.

`btree_gist` PostgreSQL'in STANDART contrib eklentisi (postgres:16 imajinda
mevcut). PostGIS gibi agir bir bagimlilik degil.

===========================================================================
SURESI BITEN REKLAM SILINMEZ
===========================================================================
`durum` ile pasife alinir. Silmek, "gecen ay hangi reklam yayindaydi"
sorusunu cevapsiz birakirdi — o soru bir faturada ya da itirazda sorulur.

GERI ALINABILIR.
"""
from alembic import op

revision = "0124_dukkan_reklam"
down_revision = "0123_dukkan_para_akisi_yok"
branch_labels = None
depends_on = None

SEMA = "dukkan"
ROL = "dukkan_app"


def upgrade() -> None:
    # Tarih araligi cakismasini EXCLUDE ile engellemek icin gerekli.
    op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist;")

    # ------------------------------------------------------------------ #
    # 1. PAKET — satilan sey
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        CREATE TABLE {SEMA}.reklam_paketi (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ad            text NOT NULL,
            -- KAPSAM: isletme hangi bolgede one cikmak istiyorsa onu alir.
            kapsam        text NOT NULL
                CHECK (kapsam IN ('mahalle','ilce','il')),
            gun           integer NOT NULL CHECK (gun > 0),
            -- PARA KURUS `bigint` — `float` ASLA. KDV HARIC tutar;
            -- KDV oranini ayri tutuyoruz cunku oran degisebilir ve
            -- gecmis satislarin tutari DEGISMEMELI.
            fiyat_kurus   bigint NOT NULL CHECK (fiyat_kurus >= 0),
            kdv_orani     numeric(4,2) NOT NULL DEFAULT 20.00,
            aktif         boolean NOT NULL DEFAULT true,
            sira          integer NOT NULL DEFAULT 0,
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now(),
            UNIQUE (kapsam, gun, ad)
        );
        """
    )

    # ------------------------------------------------------------------ #
    # 2. SLOT KURALI — kac tane satilabilir (AYARLANABILIR)
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        CREATE TABLE {SEMA}.reklam_slot_kurali (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            kapsam        text NOT NULL
                CHECK (kapsam IN ('mahalle','ilce','il')),
            -- Ayni bolge+kategori icin en fazla kac reklam yayinda olabilir.
            azami_slot    integer NOT NULL CHECK (azami_slot >= 0),
            -- SAYFADAKI SPONSORLU ORANI TAVANI (yuzde). Mahallede 3
            -- isletme varsa 1 slot bile listenin ucte biri olurdu;
            -- oran tavani o durumda slot sayisini SIFIRA cekiyor.
            -- Reklamin degeri organik sonucun degerine bagli.
            -- `numeric(5,2)`: 100.00 DA GECERLI bir deger (oran tavani
            -- yok demek). (4,2) olsaydi en fazla 99.99 yazilabilirdi ve
            -- "tavan yok" ifade EDILEMEZDI.
            azami_oran    numeric(5,2) NOT NULL DEFAULT 20.00
                CHECK (azami_oran > 0 AND azami_oran <= 100),
            etkin_at      timestamptz NOT NULL DEFAULT now(),
            created_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(f"CREATE INDEX ix_reklam_slot_kurali_gecerli "
               f"ON {SEMA}.reklam_slot_kurali (kapsam, etkin_at DESC);")
    # BASLANGIC DEGERLERI — tahmin oldugu ACIKCA yazili (docs F8-kararlar).
    op.execute(
        f"""
        INSERT INTO {SEMA}.reklam_slot_kurali (kapsam, azami_slot, azami_oran)
        VALUES ('mahalle', 1, 20.00), ('ilce', 2, 20.00), ('il', 3, 20.00);
        """
    )

    # ------------------------------------------------------------------ #
    # 3. REKLAM — satin alinmis, yayinda
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        CREATE TABLE {SEMA}.reklam (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            isletme_id    uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            paket_id      uuid REFERENCES {SEMA}.reklam_paketi(id)
                ON DELETE SET NULL,
            kapsam        text NOT NULL
                CHECK (kapsam IN ('mahalle','ilce','il')),
            -- HEDEF BOLGE: kapsama gore YALNIZ BIRI dolu. CHECK bunu
            -- zorluyor — "mahalle reklami ama mahalle_id bos" gibi bir
            -- satir, arama sorgusunda SESSIZCE hicbir yere dusmezdi.
            mahalle_id    uuid REFERENCES {SEMA}.mahalle(id) ON DELETE CASCADE,
            ilce_id       uuid REFERENCES {SEMA}.ilce(id) ON DELETE CASCADE,
            il_id         uuid REFERENCES {SEMA}.il(id) ON DELETE CASCADE,
            -- KATEGORI: reklam bir kategoriye baglidir. "Cekmekoy'de one
            -- cik" degil, "Cekmekoy'de ELEKTRIKCI ararken one cik".
            -- Kategorisiz reklam, alakasiz aramalarda cikip hem
            -- kullaniciyi hem reklamvereni memnuniyetsiz birakirdi.
            kategori_id   uuid NOT NULL
                REFERENCES {SEMA}.kategori(id) ON DELETE CASCADE,
            baslangic     timestamptz NOT NULL DEFAULT now(),
            bitis         timestamptz NOT NULL,
            durum         text NOT NULL DEFAULT 'yayinda'
                CHECK (durum IN ('yayinda','bitti','iptal','beklemede')),
            -- Yayindan dusme sebebi (isletme askiya alindi, iade, ...).
            kapanis_sebebi text,
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now(),

            CONSTRAINT reklam_bolge_tutarli CHECK (
                (kapsam = 'mahalle' AND mahalle_id IS NOT NULL
                     AND ilce_id IS NULL AND il_id IS NULL)
             OR (kapsam = 'ilce'    AND ilce_id IS NOT NULL
                     AND mahalle_id IS NULL AND il_id IS NULL)
             OR (kapsam = 'il'      AND il_id IS NOT NULL
                     AND mahalle_id IS NULL AND ilce_id IS NULL)
            ),
            CONSTRAINT reklam_tarih_tutarli CHECK (bitis > baslangic)
        );
        """
    )
    # ARAMANIN SICAK YOLU: yayinda + bolge + kategori + tarih.
    op.execute(
        f"CREATE INDEX ix_reklam_yayin ON {SEMA}.reklam "
        "(kategori_id, kapsam, baslangic, bitis) WHERE durum = 'yayinda';"
    )
    op.execute(f"CREATE INDEX ix_reklam_isletme ON {SEMA}.reklam "
               "(isletme_id, created_at DESC);")
    op.execute(f"CREATE INDEX ix_reklam_mahalle ON {SEMA}.reklam "
               "(mahalle_id) WHERE mahalle_id IS NOT NULL;")
    op.execute(f"CREATE INDEX ix_reklam_ilce ON {SEMA}.reklam "
               "(ilce_id) WHERE ilce_id IS NOT NULL;")
    op.execute(f"CREATE INDEX ix_reklam_il ON {SEMA}.reklam "
               "(il_id) WHERE il_id IS NOT NULL;")

    # ------------------------------------------------------------------ #
    # AYNI ISLETME AYNI BOLGE+KATEGORIDE CAKISAN IKI REKLAM ALAMAZ
    # ------------------------------------------------------------------ #
    # Alabilseydi ayni parayi iki kez odeyip AYNI seyi alirdi ve bunu
    # ancak faturayi gorunce fark ederdi.
    #
    # `EXCLUDE ... WITH &&` tarih araligi CAKISMASINI engelliyor; es
    # zamanli iki istegin ikisini de gecirmesi (TOCTOU) mumkun degil.
    op.execute(
        f"""
        ALTER TABLE {SEMA}.reklam ADD CONSTRAINT reklam_ayni_isletme_cakisma
        EXCLUDE USING gist (
            isletme_id WITH =,
            kategori_id WITH =,
            kapsam WITH =,
            (COALESCE(mahalle_id, ilce_id, il_id)) WITH =,
            tstzrange(baslangic, bitis) WITH &&
        ) WHERE (durum = 'yayinda');
        """
    )

    # ------------------------------------------------------------------ #
    # 4. BEKLEME LISTESI — bolge doluyken
    # ------------------------------------------------------------------ #
    # ROTASYON YERINE BEKLEME: slot dolunca satis KAPANIR. Rotasyon
    # (fazla satip sirayla gostermek) daha cok gelir getirir ama isletme
    # ne satin aldigini bilemez, "ne kadar gorundum" sorusu dogar ve onu
    # KANITLAMAK zorunda kaliriz. Kapali satis durust: "bu bolge dolu,
    # siraya girin".
    op.execute(
        f"""
        CREATE TABLE {SEMA}.reklam_bekleme (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            isletme_id    uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            kapsam        text NOT NULL
                CHECK (kapsam IN ('mahalle','ilce','il')),
            mahalle_id    uuid REFERENCES {SEMA}.mahalle(id) ON DELETE CASCADE,
            ilce_id       uuid REFERENCES {SEMA}.ilce(id) ON DELETE CASCADE,
            il_id         uuid REFERENCES {SEMA}.il(id) ON DELETE CASCADE,
            kategori_id   uuid NOT NULL
                REFERENCES {SEMA}.kategori(id) ON DELETE CASCADE,
            -- Yer acildiginda bildirim gonderildi mi (bir kez).
            bildirildi_at timestamptz,
            -- Bekleme kaydi kalici degil: isletme vazgecerse ya da yer
            -- acilip satin alinca dusurulur.
            durum         text NOT NULL DEFAULT 'bekliyor'
                CHECK (durum IN ('bekliyor','yer_acildi','vazgecti',
                                 'satin_aldi')),
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    # AYNI ISLETME AYNI YERE IKI KEZ SIRAYA GIREMEZ.
    #
    # Tablo kisiti DEGIL, IFADE INDEKSI: PostgreSQL'de `UNIQUE (...)`
    # tablo kisiti ifade kabul etmez; `COALESCE` ancak indekste yazilir.
    # Kisit yalniz BEKLEYEN satirlara: vazgecen isletme sonra yeniden
    # siraya girebilmeli.
    op.execute(
        f"CREATE UNIQUE INDEX uq_reklam_bekleme_tekil "
        f"ON {SEMA}.reklam_bekleme "
        "(isletme_id, kapsam, kategori_id, "
        " COALESCE(mahalle_id, ilce_id, il_id)) "
        "WHERE durum = 'bekliyor';"
    )
    # SIRA created_at ILE: ilk gelen ilk hakki alir. Bunu bir sutunda
    # tutmak (sira_no) es zamanli eklemede cakisirdi.
    op.execute(
        f"CREATE INDEX ix_reklam_bekleme_sira ON {SEMA}.reklam_bekleme "
        "(kategori_id, kapsam, created_at) WHERE durum = 'bekliyor';"
    )

    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON "
        f"{SEMA}.reklam_paketi, {SEMA}.reklam_slot_kurali, {SEMA}.reklam, "
        f"{SEMA}.reklam_bekleme TO {ROL};"
    )


def downgrade() -> None:
    for t in ("reklam_bekleme", "reklam", "reklam_slot_kurali",
              "reklam_paketi"):
        op.execute(f"DROP TABLE IF EXISTS {SEMA}.{t} CASCADE;")
