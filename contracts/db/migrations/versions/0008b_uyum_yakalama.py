"""uyum_yakalama (0008b) — ZATEN GOC ETMIS bir veritabanini kanonik semaya getirir.

## Neden var

Bu depoda uzun sure "kanonik migration" kurali gecerliydi: sema degisiklikleri
YENI revizyon olarak degil, MEVCUT revizyon dosyalari YERINDE duzenlenerek
yazildi. Dev veritabani her seferinde sifirdan kuruldugu icin bu hic
gorunmedi. Prod ise bir kez goc etti ve o tarihten sonra yapilan yerinde
duzenlemeler ona HIC ULASMADI.

Yerinde duzenlenen dosyalar (git gecmisinden dogrulandi — diger sekiz revizyon
tek commit'lik, hic degismemis):
  * `0001_initial_schema.py` — 48 commit; prod paketinden (2026-07-22) SONRA
    iki kez duzenlendi: `bf1dc84` (mobil ana ekran sozlesme bosluklari) ve
    `1471c44` (kamera yonetimi + etkinlik gorseli).
  * `0005_home_gorsel.py` — 2 commit; `1471c44`de kamera alanlari eklendi.

Sonuc: prod `alembic upgrade head` calistirinca 0009 patliyordu, cunku 0009
`visitor.cikis_zamani` uzerinde indeks kuruyor ve o kolon prod'da YOK:

    psycopg.errors.UndefinedColumn: column "cikis_zamani" does not exist
    [SQL: CREATE INDEX IF NOT EXISTS ix_visitor_tenant_cikis
          ON visitor (tenant_id, cikis_zamani DESC) WHERE cikis_zamani IS NOT NULL;]

## Bu KISMI UYGULAMA DEGIL

`env.py` tum revizyonlari TEK ISLEMDE kosar (`context.begin_transaction()`,
"Will assume transactional DDL"). 0009 patlayinca ayni islemde kosan 0007 ve
0008 de GERI ALINDI. Yerelde birebir yeniden uretildi: basarisiz kosumdan
sonra veritabani hala 0006'daydi. Yani prod'un semasi TUTARLI ve kendi eski
revizyonunda; yarim uygulanmis bir sey yok, elle temizlik gerekmiyor.

## Neden 0008 ile 0009 ARASINA konuldu

0009 ve 0010, eksik kolonlara BAGIMLI. Bu yuzden yakalama onlardan ONCE
kosmali; sona (0011) konsa 0009 yine patlardi. Bu, 0009'un `down_revision`
alanini degistirmeyi gerektirdi — bu revizyon HICBIR dagitilmis ortamda
uygulanmadigi icin (prod atomik geri aldi) guvenli.

Zaten head'te olan bir veritabani (taze kurulmus dev) bu revizyonu ATLAR;
sorun degil, cunku taze kurulan sema tanim geregi eksiksizdir.

## Idempotent

Her ifade "varsa dokunma" bicimindedir (`IF NOT EXISTS`, `pg_constraint`
kontrolu, enum icin `duplicate_object` yakalama). Taze veritabaninda TAMAMEN
no-op'tur; prod'da yalniz eksigi ekler. Tekrar kosmak zarasiz.

## Veri kaybi yok

Delta TAMAMEN EKLEYICI — iki sema karsilastirilarak dogrulandi: kanonik
semada olup prod'da olmayan 28 kolon / 13 kisit / 15 indeks / 3 enum var;
TERS yonde (prod'da olup kanonikte olmayan) HICBIR SEY yok, yani yerinde
SILME ya da TIP DEGISTIRME yapilmamis. `NOT NULL` eklenen kolonlarin hepsi
DEFAULT tasiyor (mevcut satirlar deger alir); eklenen CHECK'ler NULL'a izin
verdigi icin mevcut satirlar dogrulamayi gecer.

KOLON SIRASI: `ADD COLUMN` kolonu tablonun SONUNA ekler, kanonik dosyada ise
ortada tanimlidirlar. Bu SEMANTIK bir fark degildir (uygulama kolonlara ADLA
erisir) ve tabloyu yeniden yazmadan duzeltilemez; `infra/goc-uyum-dogrula.sh`
bu yuzden semalari SIRA-DUYARSIZ karsilastirir ve ham `pg_dump` farkinin
YALNIZ sira kaynakli oldugunu ayrica gosterir.

Revision ID: 0008b_uyum_yakalama
Revises: 0008_bildirim_kimlik
"""
from __future__ import annotations

from alembic import op

revision = "0008b_uyum_yakalama"
down_revision = "0008_bildirim_kimlik"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

#: (enum adi, etiketler) — CREATE TYPE'in IF NOT EXISTS'i YOKTUR, bu yuzden
#: `duplicate_object` yakalanir.
_ENUMLAR = (
    ("camera_tur", ("hls", "mp4", "rtsp")),
    ("violation_kaynak", ("kamera", "manuel", "devriye")),
    ("violation_durum", ("yeni", "inceleniyor", "kapatildi")),
)

#: (tablo, kolon, tanim) — hepsi ADD COLUMN IF NOT EXISTS.
_KOLONLAR = (
    ("camera", "konum", "text"),
    ("camera", "tur", "camera_tur NOT NULL DEFAULT 'hls'"),
    ("camera", "aktif", "boolean NOT NULL DEFAULT true"),
    ("camera", "sakin_gorebilir", "boolean NOT NULL DEFAULT false"),
    ("etkinlik", "bitis_zamani", "timestamptz"),
    ("etkinlik", "foto_key", "text"),
    ("tenant", "otopark_kapasite", "integer"),
    ("visitor", "cikis_zamani", "timestamptz"),
)

#: (tablo, kisit adi, tanim) — ADD CONSTRAINT'in IF NOT EXISTS'i YOKTUR.
_KISITLAR = (
    ("etkinlik", "ck_etkinlik_bitis",
     "CHECK (bitis_zamani IS NULL OR bitis_zamani > tarih)"),
    ("tenant", "ck_tenant_otopark_kapasite",
     "CHECK (otopark_kapasite IS NULL OR otopark_kapasite >= 0)"),
)

#: Mevcut tablolara eklenen indeksler (yeni tablolarin indeksleri asagida).
_INDEKSLER = (
    "CREATE INDEX IF NOT EXISTS ix_camera_tenant_gorunur "
    "ON camera (tenant_id, aktif, sakin_gorebilir);",
    "CREATE INDEX IF NOT EXISTS ix_etkinlik_tenant_bitis "
    "ON etkinlik (tenant_id, COALESCE(bitis_zamani, tarih));",
    "CREATE INDEX IF NOT EXISTS ix_visitor_tenant_icerde "
    "ON visitor (tenant_id, created_at DESC) WHERE cikis_zamani IS NULL;",
)

#: Yeni tablolar — govdeler `0001_initial_schema.py`den BIREBIR alindi.
_VEHICLE_PASS = """
CREATE TABLE IF NOT EXISTS vehicle_pass (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    plaka            text NOT NULL,
    arac_tanim       text,
    giris_zamani     timestamptz NOT NULL DEFAULT now(),
    cikis_zamani     timestamptz,
    unit_id          uuid,
    ziyaretci_mi     boolean NOT NULL DEFAULT false,
    kaydeden_user_id uuid NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_vehicle_pass_id_tenant UNIQUE (id, tenant_id),
    CONSTRAINT ck_vehicle_pass_plaka CHECK (plaka ~ '^[A-Z0-9]{2,20}$'),
    CONSTRAINT ck_vehicle_pass_cikis CHECK (cikis_zamani IS NULL
                                            OR cikis_zamani >= giris_zamani),
    CONSTRAINT fk_vehicle_pass_unit
        FOREIGN KEY (unit_id, tenant_id)
        REFERENCES unit (id, tenant_id) ON DELETE SET NULL (unit_id),
    CONSTRAINT fk_vehicle_pass_kaydeden
        FOREIGN KEY (kaydeden_user_id, tenant_id)
        REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT
);
"""

_VIOLATION = """
CREATE TABLE IF NOT EXISTS violation (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id          uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
    baslik             text NOT NULL,
    aciklama           text,
    kaynak             violation_kaynak NOT NULL DEFAULT 'manuel',
    konum              text,
    durum              violation_durum NOT NULL DEFAULT 'yeni',
    olusturan_user_id  uuid NOT NULL,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_violation_id_tenant UNIQUE (id, tenant_id),
    CONSTRAINT fk_violation_olusturan
        FOREIGN KEY (olusturan_user_id, tenant_id)
        REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT
);
"""

_YENI_TABLO_INDEKSLERI = (
    "CREATE INDEX IF NOT EXISTS ix_vehicle_pass_tenant ON vehicle_pass (tenant_id);",
    "CREATE INDEX IF NOT EXISTS ix_vehicle_pass_acik "
    "ON vehicle_pass (tenant_id, giris_zamani DESC) WHERE cikis_zamani IS NULL;",
    "CREATE INDEX IF NOT EXISTS ix_vehicle_pass_tenant_giris "
    "ON vehicle_pass (tenant_id, giris_zamani DESC);",
    "CREATE INDEX IF NOT EXISTS ix_vehicle_pass_plaka "
    "ON vehicle_pass (tenant_id, plaka);",
    "CREATE UNIQUE INDEX IF NOT EXISTS uq_vehicle_pass_acik_plaka "
    "ON vehicle_pass (tenant_id, plaka) WHERE cikis_zamani IS NULL;",
    "CREATE INDEX IF NOT EXISTS ix_violation_tenant ON violation (tenant_id);",
    "CREATE INDEX IF NOT EXISTS ix_violation_tenant_durum "
    "ON violation (tenant_id, durum, created_at DESC);",
    "CREATE INDEX IF NOT EXISTS ix_violation_tenant_created "
    "ON violation (tenant_id, created_at DESC);",
)

#: Yeni tablolar RLS ALTINA alinir. FORCE olmadan tablo SAHIBI politikayi
#: atlar; `backend/tests/test_rls_kapsam.py` bunu katalogdan denetler.
_RLS_TABLOLARI = ("vehicle_pass", "violation")


def upgrade() -> None:
    for ad, etiketler in _ENUMLAR:
        degerler = ", ".join(f"'{e}'" for e in etiketler)
        op.execute(
            f"""
            DO $$ BEGIN
                CREATE TYPE {ad} AS ENUM ({degerler});
            EXCEPTION WHEN duplicate_object THEN NULL;
            END $$;
            """
        )

    for tablo, kolon, tanim in _KOLONLAR:
        op.execute(f"ALTER TABLE {tablo} ADD COLUMN IF NOT EXISTS {kolon} {tanim};")

    for tablo, ad, tanim in _KISITLAR:
        op.execute(
            f"""
            DO $$ BEGIN
                IF NOT EXISTS (
                    SELECT 1 FROM pg_constraint
                    WHERE conname = '{ad}' AND conrelid = '{tablo}'::regclass
                ) THEN
                    ALTER TABLE {tablo} ADD CONSTRAINT {ad} {tanim};
                END IF;
            END $$;
            """
        )

    op.execute(_VEHICLE_PASS)
    op.execute(_VIOLATION)

    for sql in _INDEKSLER + _YENI_TABLO_INDEKSLERI:
        op.execute(sql)

    for tablo in _RLS_TABLOLARI:
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        # CREATE POLICY'nin IF NOT EXISTS'i yoktur; once dusurulur.
        op.execute(f"DROP POLICY IF EXISTS {tablo}_isolation ON {tablo};")
        op.execute(
            f"""
            CREATE POLICY {tablo}_isolation ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
        # `setup_app_role.py` her dagitimda TUM tablolara GRANT veriyor; bu
        # satir revizyonu kendi kendine yeterli kilar (betik kosmasa da).
        op.execute(
            f"GRANT SELECT, INSERT, UPDATE, DELETE ON {tablo} TO {APP_ROLE};"
        )


def downgrade() -> None:
    """NO-OP — bilincli.

    Buradaki nesnelerin SAHIBI bu revizyon degil: hepsi kanonik 0001/0005
    tarafindan tanimlanir ve onlarin kendi `downgrade()`leri dusurur. Burada
    tekrar dusurmek, taze kurulmus bir veritabaninda (ki orada bu revizyon
    HICBIR SEY yaratmadi) 0001/0005'in nesnelerini silmek olurdu.

    `infra/goc-tersinirlik.sh` zinciri head'ten base'e indirip semayi duz
    upgrade ile karsilastiriyor; bu no-op o dogrulamayi bozmaz.
    """
