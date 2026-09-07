"""(DUKKAN F4) TALEP + TEKLIF + IS — ve KVKK'nin gobegi.

===========================================================================
BU GOCUN EN ONEMLI SATIRLARI: `paylas_*` DEFAULT false
===========================================================================
Sakinin adi, telefonu, DAIRE NUMARASI ve acik adresi bir isletmeye
HICBIR KOSULDA kendiliginden gitmez.

Varsayilan `true` olsaydi, formda onay kutusunu kaldirmayi unutan bir
kullanici verisini PAYLASMIS olurdu. `false` ile unutmanin cezasi "veri
paylasilmadi"dir — guvenli yon.

Bu bir arayuz tercihi degil VERITABANI VARSAYILANI: ikinci bir istemci
(mobil) geldiginde arayuzdeki bir kutu unutulsa bile sutun `false` baslar.

===========================================================================
IKI ASAMALI GORUNURLUK
===========================================================================
  TEKLIF asamasi  -> isletme yalniz MAHALLE gorur
  IS kabul edildi -> acik adres + telefon YALNIZ kabul edilen isletmeye

`is` satirinin VARLIGI iki seyin tek anahtari:
  1. acik adres ve telefonun acilmasi,
  2. DOGRULANMIS yorum hakkinin dogmasi (F5).

===========================================================================
TABLO ADI `is` DEGIL `is_kaydi` — `is` AYRILMIS ANAHTAR KELIME
===========================================================================
Ilk yazimda tablo adi `is`ti ve TUM sorgular 500 verdi:

    syntax error at or near "i"

`IS` SQL'de ayrilmis bir anahtar kelimedir (`IS NULL`, `IS DISTINCT
FROM`). `FROM is i` ayristirilamaz.

Cozum "her yerde tirnakla" DEGIL. Tirnak gerektiren bir tablo adi KALICI
BIR TUZAKTIR: bir gun yazilan bir sorguda tirnak unutulur ve kusur, o
sorgu ilk kez calistigi anda — aylar sonra, belki prod'da — ortaya cikar.
Ad degistirmek bir kereliktir; tirnak disiplini sonsuza kadar surer.

===========================================================================
`talep_id` UNIQUE — bir talepten BIR is
===========================================================================
Ayni talebi iki ustaya vermek isteyen kullanici IKINCI BIR TALEP acar.
Aksi halde "hangi isin yorumu bu?" sorusu cevapsiz kalirdi.

===========================================================================
PARA KURUS `bigint` — `float` ASLA
===========================================================================
V1'de odeme YOK; ama teklif tutari bir para degeri ve `float` ile
saklanan para her zaman yanlis toplanir. Odeme geldiginde (V2) bu sutun
hazir olacak (docs/dukkan/00-mimari.md §8).

GERI ALINABILIR.
"""
from alembic import op

revision = "0118_dukkan_talep_teklif_is"
down_revision = "0117_dukkan_yorum_ve_siralama"
branch_labels = None
depends_on = None

SEMA = "dukkan"
ROL = "dukkan_app"


def upgrade() -> None:
    op.execute(
        f"""
        CREATE TABLE {SEMA}.talep (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            kullanici_id      uuid NOT NULL
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE RESTRICT,
            kategori_id       uuid NOT NULL
                REFERENCES {SEMA}.kategori(id) ON DELETE RESTRICT,
            -- TEKLIF ASAMASINDA GORUNEN TEK KONUM. Isletmenin teklif
            -- verebilmesi icin gerekli; daha dari (sokak) sizinti olurdu.
            mahalle_id        uuid NOT NULL
                REFERENCES {SEMA}.mahalle(id) ON DELETE RESTRICT,
            baslik            text,
            aciklama          text NOT NULL,
            butce_min_kurus   bigint,
            butce_max_kurus   bigint,
            durum             text NOT NULL DEFAULT 'acik'
                CHECK (durum IN ('acik','teklif_var','is_verildi','iptal',
                                 'suresi_doldu')),
            son_gecerlilik    timestamptz,

            -- ================================================== --
            -- KVKK: PAYLASIM TERCIHLERI — UCUYE DE `false`
            -- ================================================== --
            paylas_ad         boolean NOT NULL DEFAULT false,
            paylas_telefon    boolean NOT NULL DEFAULT false,
            paylas_adres      boolean NOT NULL DEFAULT false,

            -- ACIK ADRES: `is` kaydi DOGMADAN hicbir yanitta yer almaz.
            -- Kural SUNUCUDA (routers) ve testle kilitli; arayuzde
            -- gizlemek YETMEZ — ikinci istemci o gizlemeyi tasimaz.
            acik_adres        text,
            adres_mahalle_id  uuid REFERENCES {SEMA}.mahalle(id) ON DELETE SET NULL,
            -- Yonetiyor tesisi ise YALNIZ IZ. FK DEGIL: semalar arasi FK
            -- `dukkan_app`in public yasagini delerdi (goc 0113).
            tesis_id_beyan    uuid,
            created_at        timestamptz NOT NULL DEFAULT now(),
            updated_at        timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(f"CREATE INDEX ix_talep_kullanici ON {SEMA}.talep "
               "(kullanici_id, created_at DESC);")
    # Isletmeye talep akisinin SICAK YOLU: acik talepler, mahalle+kategori.
    op.execute(f"CREATE INDEX ix_talep_akis ON {SEMA}.talep "
               "(mahalle_id, kategori_id, created_at DESC) "
               "WHERE durum IN ('acik', 'teklif_var');")

    op.execute(
        f"""
        CREATE TABLE {SEMA}.teklif (
            id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            talep_id     uuid NOT NULL
                REFERENCES {SEMA}.talep(id) ON DELETE CASCADE,
            isletme_id   uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            -- NULL = "yerinde gormem gerek". Zorunlu yapmak ustayi
            -- uydurma rakam yazmaya iter; sonra musteri "fiyat tutmadi"
            -- diye sikayet eder. Bos birakabilmek daha durust.
            tutar_kurus  bigint CHECK (tutar_kurus IS NULL OR tutar_kurus >= 0),
            mesaj        text,
            durum        text NOT NULL DEFAULT 'gonderildi'
                CHECK (durum IN ('gonderildi','kabul','red','geri_cekildi')),
            gecerlilik   timestamptz,
            created_at   timestamptz NOT NULL DEFAULT now(),
            updated_at   timestamptz NOT NULL DEFAULT now(),
            -- BIR ISLETME BIR TALEBE BIR TEKLIF.
            UNIQUE (talep_id, isletme_id)
        );
        """
    )
    op.execute(f"CREATE INDEX ix_teklif_isletme ON {SEMA}.teklif "
               "(isletme_id, created_at DESC);")

    op.execute(
        f"""
        CREATE TABLE {SEMA}.is_kaydi (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            -- BIR TALEPTEN BIR IS.
            talep_id      uuid NOT NULL UNIQUE
                REFERENCES {SEMA}.talep(id) ON DELETE CASCADE,
            teklif_id     uuid NOT NULL
                REFERENCES {SEMA}.teklif(id) ON DELETE RESTRICT,
            isletme_id    uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE RESTRICT,
            kullanici_id  uuid NOT NULL
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE RESTRICT,
            durum         text NOT NULL DEFAULT 'kabul'
                CHECK (durum IN ('kabul','devam','tamamlandi','iptal',
                                 'anlasmazlik')),
            kabul_at      timestamptz NOT NULL DEFAULT now(),
            tamamlandi_at timestamptz,
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(f"CREATE INDEX ix_is_kaydi_isletme ON {SEMA}.is_kaydi "
               "(isletme_id, created_at DESC);")
    op.execute(f"CREATE INDEX ix_is_kaydi_kullanici ON {SEMA}.is_kaydi "
               "(kullanici_id, created_at DESC);")

    # `yorum.is_id` FK'si ARTIK KURULABILIR: `is` tablosu dogdu.
    # Goc 0117'de FK yoktu cunku hedef tablo yoktu — o gocte bu acikca
    # yaziliydi ve burada kapatiliyor.
    op.execute(
        f"ALTER TABLE {SEMA}.yorum ADD CONSTRAINT fk_yorum_is "
        f"FOREIGN KEY (is_id) REFERENCES {SEMA}.is_kaydi(id) ON DELETE SET NULL;"
    )

    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON "
        f"{SEMA}.talep, {SEMA}.teklif, {SEMA}.is_kaydi TO {ROL};"
    )


def downgrade() -> None:
    op.execute(f"ALTER TABLE {SEMA}.yorum DROP CONSTRAINT IF EXISTS fk_yorum_is;")
    for t in ("is_kaydi", "teklif", "talep"):
        op.execute(f"DROP TABLE IF EXISTS {SEMA}.{t} CASCADE;")
