"""(P192 §1) TEK DEFTER — para hareketi yalnizca `finansal_hareket`te

===========================================================================
OLCULEN KUSUR
===========================================================================
`docs/finans-analiz.md`: para UC ayri deftere yaziliyordu ve okumalar da
bolunmustu.

    Islem                     dues_payment  finansal_hareket  budget_entry
    POST /dues/payments            yazar          YAZMAZ          yazar
    POST /finans/tahsilat          YAZMAZ         yazar           YAZMAZ
    Banka eslestirme               yazar          yazar           YAZMAZ

Sahada gorulen uc sonuc:
  1. Vezneden tahsilat girilince sakinin borcu KAPANMIYORDU.
  2. `/dues/payments` ile odeme kasa bakiyesini ARTIRMIYORDU.
  3. "Tahsilat orani" mobil ana ekranda ve panelde FARKLI cikiyordu.

===========================================================================
KARAR: `finansal_hareket` TEK DOGRU KAYNAK
===========================================================================
Gerekce `app/defter.py` modul basliginda; ozeti: kasa bagi, append-only
(DELETE yetkisi 0047'de geri alindi), ters kayit/iade ayrimi, merkezi belge
no, idempotency ve onay durumu YALNIZ bu tabloda birlikte var. Digerleri
onun eksik kopyalariydi.

`dues_assessment` (BORC) yerinde kalir: bir borc para hareketi degildir.

===========================================================================
BU GOC NE YAPAR
===========================================================================
1. `finansal_hareket`e odeme alanlarini ekler (yontem, donem, provider,
   provider_ref) — `dues_payment`in TASIDIGI ama defterin tasimadigi
   bilgiler. Bunlar eklenmeseydi tek deftere gecmek VERI KAYBI olurdu.
2. `budget_category_id` ekler: butce siniflandirmasi (P-Wave 2A) korunur;
   `budget_entry` satiri defterdeki satira TASINIR, kategorisi kaybolmaz.
3. `hareket_durum`a `iptal` ekler — kartli odemenin saglayicidan
   BASARISIZ donmesi. `bekliyor`da birakmak, hicbir zaman gelmeyecek
   parayi sonsuza kadar "bekleyen" gostermek olurdu.
4. Mevcut `dues_payment` ve MANUEL `budget_entry` satirlarini deftere
   TASIR.

GERI ALINABILIR: tasinan her satir `goc_kaynak`/`kaynak_id` tasir ve
`downgrade()` tam olarak onlari siler. Kaynak tablolar SILINMEZ, yalniz
yazilmaz olur — geri donuste veri yerinde durur.

===========================================================================
IKI BILINCLI SINIR
===========================================================================
* `durum='iptal'` odemeler TASINMAZ: hicbir zaman para hareketi
  olmamislardir (kart saglayicidan basarisiz dondu). Deftere yazmak,
  gerceklesmemis bir hareketi kayit altina almak olurdu. Kayitlari
  `dues_payment`ta yerinde durur.
* `kaynak='aidat_odeme'` butce satirlari TASINMAZ: ayni parayi ikinci kez
  yazarlardi — odemenin kendisi zaten `tahsilat` satiri olarak tasiniyor.

===========================================================================
KASA
===========================================================================
Tasinan satirlarin kasasi yoktu (`dues_payment`in kasa kavrami yok).
Odemesi olup aktif kasasi olmayan her tesise `KASA / Merkez Kasa` acilir ve
satirlar oraya yazilir. Alternatif `kasa_id=NULL` birakmakti; o zaman para
defterde gorunur ama HICBIR kasa bakiyesinde gorunmezdi — P192 §2.1'in
duzelttigi kusurun aynisi.

Revision ID: 0083_tek_defter
Revises: 0082_cihaz_kimligi
Create Date: 2026-08-31
"""
from alembic import op

revision = "0083_tek_defter"
down_revision = "0082_cihaz_kimligi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- 1) SEMA ---------------------------------------------------------- #
    op.execute("ALTER TYPE hareket_durum ADD VALUE IF NOT EXISTS 'iptal';")
    op.execute(
        """
        ALTER TABLE finansal_hareket
          ADD COLUMN yontem dues_yontem,
          ADD COLUMN donem text,
          ADD COLUMN provider text,
          ADD COLUMN provider_ref text,
          ADD COLUMN budget_category_id uuid,
          ADD COLUMN goc_kaynak text,
          ADD COLUMN kaynak_id uuid;
        """
    )
    op.execute(
        """
        ALTER TABLE finansal_hareket
          ADD CONSTRAINT fk_hareket_budget_kategori
          FOREIGN KEY (budget_category_id, tenant_id)
          REFERENCES budget_category (id, tenant_id) ON DELETE RESTRICT;
        """
    )
    # Bir kaynak satir IKI KEZ tasinamaz: goc yeniden kosarsa (ya da bir
    # gun elle tekrar calistirilirsa) ayni para iki kez deftere girerdi.
    op.execute(
        """
        CREATE UNIQUE INDEX uq_hareket_goc_kaynak
          ON finansal_hareket (tenant_id, goc_kaynak, kaynak_id)
          WHERE goc_kaynak IS NOT NULL;
        """
    )
    # Daire/tahakkuk bazli bakiye sorgularinin tarayacagi satirlar.
    op.execute(
        "CREATE INDEX ix_hareket_unit_durum "
        "ON finansal_hareket (tenant_id, unit_id, durum) "
        "WHERE unit_id IS NOT NULL;"
    )
    op.execute(
        "CREATE INDEX ix_hareket_assessment "
        "ON finansal_hareket (tenant_id, assessment_id) "
        "WHERE assessment_id IS NOT NULL;"
    )
    op.execute(
        "CREATE INDEX ix_hareket_budget_kategori "
        "ON finansal_hareket (budget_category_id, tenant_id) "
        "WHERE budget_category_id IS NOT NULL;"
    )

    # Saglayici referansi TEKIL: bir kart odemesinin webhook'u iki satira
    # denk gelseydi "hangisi odendi" sorusu cevapsiz kalirdi. `dues_payment`
    # uzerindeki `uq_payment_provider_ref` ile ayni kural.
    op.execute(
        """
        CREATE UNIQUE INDEX uq_hareket_provider_ref
          ON finansal_hareket (provider, provider_ref)
          WHERE provider_ref IS NOT NULL;
        """
    )

    # --- 2) EKSIK KASALAR ------------------------------------------------- #
    op.execute(
        """
        INSERT INTO kasa (tenant_id, kod, ad, banka_mi)
        SELECT DISTINCT t.tenant_id, 'KASA', 'Merkez Kasa', false
        FROM (
            SELECT tenant_id FROM dues_payment WHERE durum <> 'iptal'
            UNION
            SELECT tenant_id FROM budget_entry WHERE kaynak = 'manuel'
        ) t
        WHERE NOT EXISTS (
            SELECT 1 FROM kasa k
            WHERE k.tenant_id = t.tenant_id AND k.banka_mi = false AND k.aktif
        );
        """
    )

    # --- 3) dues_payment -> finansal_hareket ------------------------------ #
    #
    # `belge_no`: odemenin makbuz numarasi KORUNUR ama yalniz cakismiyorsa.
    # `uq_hareket_belge_no` tenant icinde tekildir; iki odemede ayni elle
    # yazilmis numara varsa ikincisi numarasiz tasinir ve numara
    # aciklamasina yazilir — sessizce UZERINE YAZMAK, iki farkli makbuzu
    # ayni belgeye baglamak olurdu.
    op.execute(
        """
        WITH aday AS (
            SELECT p.*,
                   CASE
                     WHEN p.makbuz_no IS NOT NULL
                      AND NOT EXISTS (
                            SELECT 1 FROM finansal_hareket f
                            WHERE f.tenant_id = p.tenant_id
                              AND f.belge_no = p.makbuz_no)
                      AND row_number() OVER (
                            PARTITION BY p.tenant_id, p.makbuz_no
                            ORDER BY p.created_at, p.id) = 1
                     THEN p.makbuz_no
                   END AS yeni_belge
            FROM dues_payment p
            WHERE p.durum <> 'iptal'
        )
        INSERT INTO finansal_hareket (
            tenant_id, tip, yon, tutar_kurus, tarih, kasa_id,
            user_id, unit_id, assessment_id, belge_no, aciklama,
            kaydeden_user_id, idempotency_key, idem_satir, durum,
            yontem, donem, provider, provider_ref, goc_kaynak, kaynak_id
        )
        SELECT
            a.tenant_id, 'tahsilat', 'giris', a.tutar_kurus,
            (a.odeme_zamani AT TIME ZONE 'UTC')::date,
            k.id,
            asm.hedef_user_id, a.unit_id, a.assessment_id,
            a.yeni_belge,
            CASE WHEN a.makbuz_no IS NOT NULL AND a.yeni_belge IS NULL
                 THEN 'Makbuz no: ' || a.makbuz_no END,
            a.kaydeden_user_id, a.idempotency_key, 0,
            CASE a.durum WHEN 'basarili' THEN 'odendi' ELSE 'bekliyor' END::hareket_durum,
            a.yontem, a.donem, a.provider, a.provider_ref,
            'dues_payment', a.id
        FROM aday a
        LEFT JOIN dues_assessment asm ON asm.id = a.assessment_id
        LEFT JOIN LATERAL (
            SELECT k.id FROM kasa k
            WHERE k.tenant_id = a.tenant_id AND k.banka_mi = false AND k.aktif
            ORDER BY (k.kod = 'KASA') DESC, k.created_at, k.id
            LIMIT 1
        ) k ON true;
        """
    )

    # --- 4) budget_entry (MANUEL) -> finansal_hareket --------------------- #
    op.execute(
        """
        INSERT INTO finansal_hareket (
            tenant_id, tip, yon, tutar_kurus, tarih, kasa_id,
            aciklama, kaydeden_user_id, durum,
            budget_category_id, goc_kaynak, kaynak_id
        )
        SELECT
            b.tenant_id,
            b.tip::text::hareket_tip,
            CASE b.tip WHEN 'gelir' THEN 'giris' ELSE 'cikis' END::hareket_yon,
            b.tutar_kurus, b.tarih, k.id,
            b.aciklama, b.created_by, 'odendi',
            b.kategori_id, 'budget_entry', b.id
        FROM budget_entry b
        LEFT JOIN LATERAL (
            SELECT k.id FROM kasa k
            WHERE k.tenant_id = b.tenant_id AND k.banka_mi = false AND k.aktif
            ORDER BY (k.kod = 'KASA') DESC, k.created_at, k.id
            LIMIT 1
        ) k ON true
        WHERE b.kaynak = 'manuel';
        """
    )


    # --- 5) WEBHOOK TENANT COZUMU DEFTERE BAKAR --------------------------- #
    #
    # Kartli odeme artik `dues_payment`e yazilmadigi icin bu SECURITY
    # DEFINER fonksiyon eski tabloya baksaydi HER webhook 404 doner ve
    # basarili kart odemeleri sonsuza kadar "bekliyor" kalirdi.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.payment_tenant_by_ref(
            p_provider text, p_provider_ref text)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT tenant_id FROM public.finansal_hareket
            WHERE provider = p_provider AND provider_ref = p_provider_ref;
        $$;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.payment_tenant_by_ref(
            p_provider text, p_provider_ref text)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT tenant_id FROM public.dues_payment
            WHERE provider = p_provider AND provider_ref = p_provider_ref;
        $$;
        """
    )
    # TASINAN SATIRLAR TAM OLARAK SILINIR. `goc_kaynak` bu yuzden var:
    # "hangi satirlar bu gocte olustu" sorusu aciklama metnine ya da
    # zaman damgasina birakilamazdi.
    op.execute("DELETE FROM finansal_hareket WHERE goc_kaynak IS NOT NULL;")
    op.execute("DROP INDEX IF EXISTS ix_hareket_budget_kategori;")
    op.execute("DROP INDEX IF EXISTS ix_hareket_assessment;")
    op.execute("DROP INDEX IF EXISTS ix_hareket_unit_durum;")
    op.execute("DROP INDEX IF EXISTS uq_hareket_goc_kaynak;")
    op.execute("DROP INDEX IF EXISTS uq_hareket_provider_ref;")
    op.execute(
        "ALTER TABLE finansal_hareket "
        "DROP CONSTRAINT IF EXISTS fk_hareket_budget_kategori;"
    )
    op.execute(
        """
        ALTER TABLE finansal_hareket
          DROP COLUMN IF EXISTS kaynak_id,
          DROP COLUMN IF EXISTS goc_kaynak,
          DROP COLUMN IF EXISTS budget_category_id,
          DROP COLUMN IF EXISTS provider_ref,
          DROP COLUMN IF EXISTS provider,
          DROP COLUMN IF EXISTS donem,
          DROP COLUMN IF EXISTS yontem;
        """
    )
    # ENUM DEGERI DUSURULEMEZ (Postgres). `iptal` kalir; kullanan satir
    # kalmadigi icin zararsizdir. Acilan `KASA` kayitlari da kalir:
    # silmek, arada elle hareket girilmis bir kasayi yok etmek olurdu.
