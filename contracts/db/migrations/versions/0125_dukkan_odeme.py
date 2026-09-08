"""(DUKKAN F8c) ODEME — satin alma, saklanan kart TOKEN'i, abonelik.

===========================================================================
KART BILGISI HICBIR KOSULDA BURADA DEGIL
===========================================================================
`odeme_yontemi` tablosunda kart numarasi, CVV ya da son kullanma tarihi
YOK. Yalniz:
  * saglayicinin verdigi TOKEN'lar,
  * gosterim icin son dort hane + marka.

Kart numarasi hicbir zaman bizim surecimizden GECMEZ: kullanici onu
saglayicinin sayfasinda/alanlarinda girer, saglayici bize token doner.
Token calinsa bile baska bir uye isyerinde kullanilamaz.

Kilit: `test_dukkan_odeme.py::test_KART_ALANI_HICBIR_TABLODA_YOK` —
tablolari TARAYIP kart ima eden sutun arar.

===========================================================================
FATURA ALANLARI SATIN ALMA ANINDA DONDURULUYOR
===========================================================================
`reklam_satin_alma` unvan, VKN, vergi dairesi, adres, tutar, KDV ve
tarihi KENDI SATIRINDA tutar — isletme tablosuna JOIN ATMAZ.

Sebep: fatura, kesildigi ANDAKI bilgilerle kesilir. Isletme yarin unvan
ya da adres degistirirse, gecen ayin faturasi DEGISMEMELI. JOIN'li bir
tasarim, gecmis faturalari sessizce yeniden yazardi.

Bu ayni zamanda e-Arsiv entegratorune gecisi veri toplamaya
BAGIMLI KILMIYOR: V1'de fatura elle kesilecek (aylik ~30 satisa kadar
mali musavir ucretine dahil), ama gerekli her alan bugunden kayitli.

===========================================================================
TEKRARLAYAN ODEME ALTYAPIDA VAR, URUNDE VARSAYILAN DEGIL
===========================================================================
`abonelik` tablosu var ve `reklam` ile ayni odeme altyapisini kullaniyor
(istegin sarti). Ama reklam urunu VARSAYILAN OLARAK TEK SEFERLIKTIR:
`abonelik` satiri ancak isletme ACIKCA yenileme actiginda dogar.

Sessizce kart cekmek en cok sikayet ureten seydir (F8b karari); altyapi
destegi ile urun varsayilani AYRI seylerdir.

===========================================================================
`reklam_id` NULLABLE — VE BU ONEMLI
===========================================================================
Odeme ONCE alinir, reklam SONRA acilir. Odeme basarili olup reklam acma
adimi patlarsa (or. bu arada slot doldu), elimizde SAHIPSIZ BIR TAHSILAT
kalir ve o satirin GORUNMESI gerekir — iade edilecek para odur.

`reklam_id` NOT NULL olsaydi o satir hic yazilamaz, para alinir ve iz
kalmazdi.

GERI ALINABILIR.
"""
from alembic import op

revision = "0125_dukkan_odeme"
down_revision = "0124_dukkan_reklam"
branch_labels = None
depends_on = None

SEMA = "dukkan"
ROL = "dukkan_app"


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 1. ODEME YONTEMI — SAKLANAN KART TOKEN'I (kart bilgisi DEGIL)
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        CREATE TABLE {SEMA}.odeme_yontemi (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            kullanici_id      uuid NOT NULL
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE CASCADE,
            saglayici         text NOT NULL,
            -- SAGLAYICIDAKI TOKEN'LAR. Kart numarasi DEGIL.
            kart_token        text NOT NULL,
            kullanici_token   text,
            -- GOSTERIM ICIN: kullanici "hangi kart" sorusunu ancak
            -- bununla yanitlar. Son dort hane PCI kapsaminda saklanabilir.
            son_dort          char(4),
            marka             text,
            takma_ad          text,
            varsayilan        boolean NOT NULL DEFAULT false,
            durum             text NOT NULL DEFAULT 'aktif'
                CHECK (durum IN ('aktif','silindi','gecersiz')),
            created_at        timestamptz NOT NULL DEFAULT now(),
            updated_at        timestamptz NOT NULL DEFAULT now(),
            -- AYNI TOKEN IKI KEZ KAYDEDILMEZ.
            UNIQUE (saglayici, kart_token)
        );
        """
    )
    op.execute(f"CREATE INDEX ix_odeme_yontemi_kullanici "
               f"ON {SEMA}.odeme_yontemi (kullanici_id) "
               "WHERE durum = 'aktif';")
    # BIR KULLANICIDA TEK VARSAYILAN KART: iki varsayilan olsaydi
    # tekrarlayan cekimin hangisinden yapilacagi belirsiz olurdu.
    op.execute(f"CREATE UNIQUE INDEX uq_odeme_yontemi_varsayilan "
               f"ON {SEMA}.odeme_yontemi (kullanici_id) "
               "WHERE varsayilan AND durum = 'aktif';")

    # ------------------------------------------------------------------ #
    # 2. REKLAM SATIN ALMA — FATURA ALANLARI DONDURULMUS
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        CREATE TABLE {SEMA}.reklam_satin_alma (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            isletme_id        uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE RESTRICT,
            paket_id          uuid REFERENCES {SEMA}.reklam_paketi(id)
                ON DELETE SET NULL,
            -- Odeme ONCE, reklam SONRA: basarili odemeden sonra reklam
            -- acma adimi patlarsa SAHIPSIZ TAHSILAT gorunur kalmali.
            reklam_id         uuid REFERENCES {SEMA}.reklam(id)
                ON DELETE SET NULL,

            -- ---------------- PARA (KURUS `bigint`, `float` ASLA) ------
            tutar_kurus       bigint NOT NULL CHECK (tutar_kurus >= 0),
            kdv_orani         numeric(5,2) NOT NULL,
            kdv_kurus         bigint NOT NULL CHECK (kdv_kurus >= 0),
            -- Toplam AYRICA saklaniyor, hesaplanmiyor: KDV orani ya da
            -- yuvarlama kurali degisirse GECMIS TOPLAM degismemeli.
            toplam_kurus      bigint NOT NULL CHECK (toplam_kurus >= 0),
            para_birimi       text NOT NULL DEFAULT 'TRY',

            -- ---------------- FATURA (SATIN ALMA ANINDAKI HALI) --------
            fatura_unvan      text,
            fatura_vkn        text,
            fatura_vergi_dairesi text,
            fatura_adres      text,
            fatura_il         text,
            fatura_ilce       text,
            fatura_eposta     text,
            -- Elle kesilen faturanin numarasi/tarihi (V1: mali musavir).
            fatura_no         text,
            fatura_tarihi     date,

            -- ---------------- ODEME IZI -------------------------------
            saglayici         text NOT NULL,
            saglayici_islem_id text,
            siparis_no        text NOT NULL UNIQUE,
            durum             text NOT NULL DEFAULT 'beklemede'
                CHECK (durum IN ('beklemede','basarili','reddedildi',
                                 'iade','iptal','yapilandirilmadi')),
            hata              text,
            saglayici_kodu    text,
            odendi_at         timestamptz,
            iade_at           timestamptz,
            iade_kurus        bigint CHECK (iade_kurus IS NULL
                                            OR iade_kurus >= 0),
            created_at        timestamptz NOT NULL DEFAULT now(),
            updated_at        timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(f"CREATE INDEX ix_reklam_satin_alma_isletme "
               f"ON {SEMA}.reklam_satin_alma (isletme_id, created_at DESC);")
    # MUTABAKAT SORGUSU: "bu ay ne tahsil edildi".
    op.execute(f"CREATE INDEX ix_reklam_satin_alma_odendi "
               f"ON {SEMA}.reklam_satin_alma (odendi_at) "
               "WHERE durum = 'basarili';")
    # SAHIPSIZ TAHSILAT: odendi ama reklam acilmadi -> IADE EDILECEK.
    # Kismi indeks, o sorguyu bir tarama olmaktan cikariyor ve varligi
    # sorunun SORULACAGINI belgeliyor.
    op.execute(f"CREATE INDEX ix_reklam_satin_alma_sahipsiz "
               f"ON {SEMA}.reklam_satin_alma (created_at) "
               "WHERE durum = 'basarili' AND reklam_id IS NULL;")

    # ------------------------------------------------------------------ #
    # 3. ABONELIK — tekrarlayan odeme (URUNDE VARSAYILAN DEGIL)
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        CREATE TABLE {SEMA}.abonelik (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            isletme_id        uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            paket_id          uuid NOT NULL
                REFERENCES {SEMA}.reklam_paketi(id) ON DELETE RESTRICT,
            odeme_yontemi_id  uuid
                REFERENCES {SEMA}.odeme_yontemi(id) ON DELETE SET NULL,
            -- Yenilenecek reklamin bolge/kategori bilgisi: abonelik
            -- "ayni yeri yenile" demek. Reklam satiri her donem YENIDEN
            -- dogar (eskisi gecmis olarak kalir).
            kapsam            text NOT NULL
                CHECK (kapsam IN ('mahalle','ilce','il')),
            mahalle_id        uuid REFERENCES {SEMA}.mahalle(id) ON DELETE CASCADE,
            ilce_id           uuid REFERENCES {SEMA}.ilce(id) ON DELETE CASCADE,
            il_id             uuid REFERENCES {SEMA}.il(id) ON DELETE CASCADE,
            kategori_id       uuid NOT NULL
                REFERENCES {SEMA}.kategori(id) ON DELETE CASCADE,

            durum             text NOT NULL DEFAULT 'aktif'
                CHECK (durum IN ('aktif','duraklatildi','iptal',
                                 'odeme_basarisiz')),
            sonraki_cekim     timestamptz NOT NULL,
            -- Ust uste kac cekim basarisiz oldu. Belli bir sayidan sonra
            -- abonelik durur; sonsuza kadar denemek hem bankada hem
            -- kullanicida gurultu yaratir.
            basarisiz_sayi    integer NOT NULL DEFAULT 0,
            son_hata          text,
            iptal_at          timestamptz,
            iptal_sebebi      text,
            created_at        timestamptz NOT NULL DEFAULT now(),
            updated_at        timestamptz NOT NULL DEFAULT now(),

            CONSTRAINT abonelik_bolge_tutarli CHECK (
                (kapsam = 'mahalle' AND mahalle_id IS NOT NULL
                     AND ilce_id IS NULL AND il_id IS NULL)
             OR (kapsam = 'ilce'    AND ilce_id IS NOT NULL
                     AND mahalle_id IS NULL AND il_id IS NULL)
             OR (kapsam = 'il'      AND il_id IS NOT NULL
                     AND mahalle_id IS NULL AND ilce_id IS NULL)
            )
        );
        """
    )
    op.execute(f"CREATE INDEX ix_abonelik_cekim ON {SEMA}.abonelik "
               "(sonraki_cekim) WHERE durum = 'aktif';")
    op.execute(f"CREATE INDEX ix_abonelik_isletme ON {SEMA}.abonelik "
               "(isletme_id, created_at DESC);")

    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON "
        f"{SEMA}.odeme_yontemi, {SEMA}.reklam_satin_alma, {SEMA}.abonelik "
        f"TO {ROL};"
    )


def downgrade() -> None:
    for t in ("abonelik", "reklam_satin_alma", "odeme_yontemi"):
        op.execute(f"DROP TABLE IF EXISTS {SEMA}.{t} CASCADE;")
