"""(P192 §3) Tahakkuk: kalem tipi, çoklu kalem, ters kayıt, arsa payı

===========================================================================
1) TEKILLIK KISITI KALDIRILMADI — KALEM-FARKINDALI YAPILDI
===========================================================================
`docs/finans-analiz.md` "UNIQUE (tenant, unit, donem) ayni aya ikinci
kalemi engelliyor" diye raporlamisti. ÖLÇÜM BUNU DÜZELTTİ: modeldeki
`__table_args__` eskiydi; veritabaninda 0018'den beri TUR-FARKINDALI bir
kismi indeks var:

    uq_assessment_unit_donem_tur
      (tenant_id, unit_id, donem, COALESCE(gelir_gider_tanim_id, nobetci))

Yani "Mart aidati + Mart elektrigi" ZATEN mumkundu (farkli tanim). Gercek
bosluk TANIMSIZ kalemlerdeydi: tanim verilmeyen iki kalem ayni nobetci
degere dusuyor ve ikincisi 409 aliyordu — "Mart aidati + Mart cati
onarimi" tanimsiz akista imkansizdi.

KISITI TAMAMEN KALDIRMAK YANLIS OLURDU ve olculdu: dort mevcut test
(`test_toplu_TEKRAR_calistirilinca_ATLAR`, `test_assessment_duplicate...`,
`test_TURSUZ_kayitlarda_ESKI_koruma...`, `test_ice_aktarim_MUKERRER...`)
tam da bu korumayi kilitliyor. Kaldirmak, aylik toplu tahakkuku yanlislikla
iki kez calistiran yoneticinin butun siteyi IKI KAT borclandirmasi
demekti.

Bu yuzden indeks GENISLETILDI:

    (tenant_id, unit_id, donem,
     COALESCE(gelir_gider_tanim_id, nobetci),
     kalem_tipi,
     COALESCE(kaynak_assessment_id, nobetci))

  * `kalem_tipi` — tanimsiz akista "aidat" ile "olaganustu" ayrisir.
  * `kaynak_assessment_id` — bir dairenin AYNI AYDA birden cok gecikmis
    borcu icin ayri ayri faiz kalemi acilabilsin. Olmasaydi ikinci borcun
    faizi sessizce yazilamazdi.
  * `WHERE ters_kayit_id IS NULL AND NOT iptal_edildi` — DUZELTILMIS
    CIFTIN IKI SATIRI DA indeksin DISINDA. Ters kayit, duzelttigi satirla
    ayni (daire, donem, tur, kalem) dortlusune sahiptir; kosul olmasaydi
    hicbir tahakkuk duzeltilemezdi. Duzeltilen ORIJINAL de disarida
    olmali, yoksa "yanlis tutari duzelt, dogrusunu yaz" akisi ikinci
    adimda 409 alirdi (ikisi de olculdu).

    `iptal_edildi` DENORMALIZE bir bayraktir ve olmak zorunda: kismi
    indeks predikatinda ALT SORGU kullanilamaz. Ters kayit ucu iki satiri
    AYNI islemde yazar, yani bayrak defterle ayrisamaz.
    Duzeltmenin tekilligini `uq_assessment_ters_kayit` sagliyor.

Ve asil sikayet — SESSIZ ATLAMA — kaldirildi: atlanan satirlar artik
DOKUMLU donuyor (`DuesAssessmentResult.atlananlar`, neden bilgisiyle).

===========================================================================
2) `kalem_tipi` — borç NEYİN borcu
===========================================================================
Aynı aya birden çok kalem yazılabiliyorsa, kalemlerin birbirinden ayırt
edilmesi gerekir: aidat mı, demirbaş mı, olağanüstü mü, gecikme faizi mi.
`aciklama` metnine bakmak bunu ayırt etmezdi (serbest metin) ve "bu ay ne
kadar FAİZ tahakkuk etti" sorusu cevapsız kalırdı.

Varsayılan `aidat`: bugüne kadar yazılmış her satır bir aidat kalemidir.

===========================================================================
3) `ters_kayit_id` — TAHAKKUK DÜZELTME (§6.3)
===========================================================================
Yanlış tahakkuk edilirse ne olacağı belirsizdi: silme ucu yok (ve olmamalı),
düzeltme yolu da yoktu. Defterdeki (`finansal_hareket`) çözümün AYNISI
uygulandı: satır silinmez, TERS KAYIT yazılır.

Ters kayıt satırı da POZİTİF tutar taşır (`ck_assessment_tutar` yerinde
kalır); işaret `ters_kayit_id`den gelir — bakiye hesabı onu EKSİ sayar
(bkz. `app/defter.py::tahakkuk_etkisi`). Negatif tutar saklamak, "iade" ile
"eksi borç"u ayırt edilemez kılardı.

Kısmi UNIQUE: bir tahakkuk İKİ KEZ ters kayıtlanamaz — iki ters kayıt
borcu geri getirmiş gibi görünen bir bakiye üretirdi.

===========================================================================
4) `kaynak_assessment_id` — FAİZ HANGİ BORÇTAN DOĞDU
===========================================================================
Gecikme faizi hesaplanıyor ama HİÇBİR YERE YAZILMIYORDU: sakin borcunu
ödeyince faiz buharlaşıyordu. Artık faiz AYRI BİR BORÇ KALEMİDİR ve hangi
borçtan doğduğunu taşır.

Kısmi UNIQUE `(tenant_id, kaynak_assessment_id, donem)` faiz kalemlerinde:
aynı borç için aynı dönemde İKİNCİ bir faiz kalemi açılamaz. Faiz işleme
görevi iki kez çalışsa bile borç iki katına çıkmaz (idempotency).

===========================================================================
5) `unit.arsa_payi` — Kat Mülkiyeti Kanunu md. 20
===========================================================================
KMK gider paylaşımını ARSA PAYINA göre tanımlar; üründe yalnız eşit ve
daire tipi vardı. NUMERIC ve NULLABLE: arsa payı girilmemiş daire
dağıtımın dışında kalır ve bu kullanıcıya SÖYLENİR (sessizce sıfır
borçlandırmak, fark edilmeyen eksik tahakkuk üretirdi).

===========================================================================
6) `tenant.gecikme_uygula` — bazı siteler faiz almaz
===========================================================================
Oran zaten ayarlanabiliyordu ama "hiç uygulama" demek için oranı 0
yapmak gerekiyordu; o da "oran henüz girilmedi" ile aynı görünürdü. Ayrı
bir anahtar, kararı AÇIKÇA kaydeder.

Revision ID: 0085_tahakkuk_kalemleri
Revises: 0084_banka_hesabi_ve_onay
Create Date: 2026-08-31
"""
from alembic import op

#: Nobetci UUID: Postgres'te NULL'lar benzersizlikte FARKLI sayilir, bu
#: yuzden NULL tanim/kaynak degerleri sabit bir degere cekilir. Duz bir
#: UNIQUE(..., tanim_id) eski korumayi SESSIZCE kaldirirdi (0018 notu).
NOBETCI = "00000000-0000-0000-0000-000000000000"

revision = "0085_tahakkuk_kalemleri"
down_revision = "0084_banka_hesabi_ve_onay"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TYPE dues_kalem_tipi AS ENUM "
        "('aidat', 'demirbas', 'olaganustu', 'faiz', 'sayac', 'diger');"
    )
    op.execute(
        """
        ALTER TABLE dues_assessment
          ADD COLUMN kalem_tipi dues_kalem_tipi NOT NULL DEFAULT 'aidat',
          ADD COLUMN ters_kayit_id uuid,
          ADD COLUMN kaynak_assessment_id uuid,
          ADD COLUMN iptal_edildi boolean NOT NULL DEFAULT false;
        """
    )
    # Ters kayit AYNI TESISIN bir tahakkukunu gostermeli.
    op.execute(
        """
        ALTER TABLE dues_assessment
          ADD CONSTRAINT fk_assessment_ters_kayit
          FOREIGN KEY (ters_kayit_id, tenant_id)
          REFERENCES dues_assessment (id, tenant_id) ON DELETE RESTRICT,
          ADD CONSTRAINT fk_assessment_kaynak
          FOREIGN KEY (kaynak_assessment_id, tenant_id)
          REFERENCES dues_assessment (id, tenant_id) ON DELETE RESTRICT;
        """
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_assessment_ters_kayit "
        "ON dues_assessment (tenant_id, ters_kayit_id) "
        "WHERE ters_kayit_id IS NOT NULL;"
    )
    # 0018'in indeksi KALEM-FARKINDALI olanla degistirilir.
    op.execute("DROP INDEX IF EXISTS uq_assessment_unit_donem_tur;")
    op.execute(
        f"""
        CREATE UNIQUE INDEX uq_assessment_unit_donem_kalem
            ON dues_assessment (
                tenant_id, unit_id, donem,
                COALESCE(gelir_gider_tanim_id, '{NOBETCI}'::uuid),
                kalem_tipi,
                COALESCE(kaynak_assessment_id, '{NOBETCI}'::uuid)
            )
            WHERE ters_kayit_id IS NULL AND NOT iptal_edildi;
        """
    )
    # FK bas sutunu indekssiz kalmasin (goc 0081 kurali).
    op.execute(
        "CREATE INDEX ix_assessment_kaynak "
        "ON dues_assessment (kaynak_assessment_id, tenant_id) "
        "WHERE kaynak_assessment_id IS NOT NULL;"
    )
    op.execute(
        "CREATE INDEX ix_assessment_kalem_tipi "
        "ON dues_assessment (tenant_id, kalem_tipi);"
    )

    op.execute("ALTER TABLE unit ADD COLUMN arsa_payi numeric(12,4);")
    op.execute(
        "ALTER TABLE tenant ADD COLUMN gecikme_uygula boolean NOT NULL DEFAULT true;"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS gecikme_uygula;")
    op.execute("ALTER TABLE unit DROP COLUMN IF EXISTS arsa_payi;")
    op.execute("DROP INDEX IF EXISTS ix_assessment_kalem_tipi;")
    op.execute("DROP INDEX IF EXISTS ix_assessment_kaynak;")
    op.execute("DROP INDEX IF EXISTS uq_assessment_unit_donem_kalem;")
    op.execute("DROP INDEX IF EXISTS uq_assessment_ters_kayit;")
    # FAIZ ve TERS KAYIT SATIRLARI SILINIR: eski semada "kalem tipi" yok ve
    # bu satirlar orada AIDAT gibi gorunurdu — geri donuste sakinin borcu
    # faiz kadar FAZLA cikardi. Silmek, yanlis okunacak veriyi birakmaktan
    # iyidir; ikisi de bu gocte oluşmus satirlardir.
    op.execute(
        "DELETE FROM dues_assessment "
        "WHERE ters_kayit_id IS NOT NULL OR kalem_tipi = 'faiz';"
    )
    op.execute(
        """
        ALTER TABLE dues_assessment
          DROP CONSTRAINT IF EXISTS fk_assessment_kaynak,
          DROP CONSTRAINT IF EXISTS fk_assessment_ters_kayit,
          DROP COLUMN IF EXISTS iptal_edildi,
          DROP COLUMN IF EXISTS kaynak_assessment_id,
          DROP COLUMN IF EXISTS ters_kayit_id,
          DROP COLUMN IF EXISTS kalem_tipi;
        """
    )
    op.execute("DROP TYPE IF EXISTS dues_kalem_tipi;")
    # 0018'in indeksi GERI KONULUR ama ayni (tenant, unit, donem, tur)
    # dortlusunden BIRDEN COK satir varsa goc DUSER. Bu bilincli: sessizce
    # birini silmek, bir borcu haber vermeden yok etmek olurdu. Boyle bir
    # durumda dogru davranis DURUP SORMAKTIR.
    op.execute(
        """
        CREATE UNIQUE INDEX uq_assessment_unit_donem_tur
            ON dues_assessment (
                tenant_id, unit_id, donem,
                COALESCE(gelir_gider_tanim_id,
                         '00000000-0000-0000-0000-000000000000'::uuid)
            );
        """
    )
