"""icerik_ceviri (0007) — yayin iceriginin OTOMATIK CEVIRISI (7 dil).

Urun gereksinimi: yonetimin yazdigi YAYIN icerigi (duyuru, site kurali,
etkinlik) sakinin KENDI dilinde okunabilmeli. Mimari: ceviri YAZMA aninda
uretilir, TUM diller saklanir, okuma Accept-Language ile servis edilir;
ORIJINAL metin her zaman korunur ve makine-cevirisi bayrakla isaretlenir.

SAKLAMA KARARI — entity basina AYRI YAN TABLO (JSONB kolon DEGIL):
  * Ceviri satirlari ic-ice degil SATIR bazli: her (entity, dil) icin durum /
    elle_duzeltildi / kaynak_hash birer KOLON — indekslenebilir ve tek satir
    UPSERT'i ile guncellenir. Worker 6 dili birbirinden bagimsiz yazar; tek
    JSONB kolonda bu okuma-degistirme-yazma yarisi (clobber) olurdu.
  * Mevcut tablolara DOKUNMAZ (yalniz kaynak_dil kolonu eklenir) — var olan
    sorgular/testler etkilenmez; tam ADDITIVE.
  * Polymorphic TEK tablo yerine 3 tablo: boylece composite FK
    (entity_id, tenant_id) -> entity (id, tenant_id) ON DELETE CASCADE
    kurulabiliyor. Icerik silinince cevirileri de gider (yetim satir YOK;
    silinmis duyurunun metni ceviri tablosunda YASAMAZ). Polymorphic tabloda
    bu FK kurulamazdi. Kod tarafi tek yol: tablo adi kayittan (registry) gelir.

Ceviri ALANLARI `alanlar` jsonb icinde tutulur (entity'ye gore anahtarlar
degisir: duyuru baslik+govde, kural baslik+icerik, etkinlik baslik+aciklama) —
boylece 3 tablo AYNI sema ile calisir. Ceviriye girmeyen alanlar (konum, foto,
tarih, sira) bilincli olarak DISARIDA: yer adi/gorsel/tarih cevrilmez.

kaynak_hash (ELLE DUZELTME KURALININ ANAHTARI): cevirinin uretildigi KAYNAK
metnin sha256'si. Icerik guncellenince yeni hash hesaplanir; elle duzeltilmis
(elle_duzeltildi=true) bir ceviri YALNIZCA kaynak metin AYNI kaldiysa korunur
(orn. yalniz foto/tarih degismis). Kaynak metin degistiyse elle duzeltme de
GECERSIZDIR ve yeniden cevrilir — yoksa yanlis/eski ceviri kalici olurdu.

URETIM: additive + geriye-uyumlu; 0001-0006 IMMUTABLE.
"""
from alembic import op

# revision identifiers, used by Alembic.
revision = "0007_icerik_ceviri"
down_revision = "0006_support_foto"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

# (ceviri tablosu, kaynak tablo, FK kolonu) — kod tarafindaki registry ile ayni.
_CEVIRI_TABLOLARI = (
    ("announcement_ceviri", "announcement", "announcement_id"),
    ("site_kurali_ceviri", "site_kurali", "site_kurali_id"),
    ("etkinlik_ceviri", "etkinlik", "etkinlik_id"),
)

# Desteklenen diller — mobil UI ile AYNI kume (tr varsayilan + 6).
_DILLER = ("tr", "en", "ar", "ru", "de", "fr", "es")


def upgrade() -> None:
    # Ceviri durumu: hazir (servis edilebilir) | bekliyor (kuyrukta) |
    # hata (saglayici basarisiz — orijinal servis edilir).
    op.execute("CREATE TYPE ceviri_durum AS ENUM ('hazir', 'bekliyor', 'hata');")

    # Kaynak dil: icerigin YAZILDIGI dil. Simdilik tr sabit (admin secimi
    # sonraki tur); orijinal metin bu dilde kabul edilir.
    for kaynak in ("announcement", "site_kurali", "etkinlik"):
        op.execute(
            f"ALTER TABLE {kaynak} "
            "ADD COLUMN kaynak_dil text NOT NULL DEFAULT 'tr';"
        )

    dil_listesi = ", ".join(f"'{d}'" for d in _DILLER)
    for tablo, kaynak, fk_kolon in _CEVIRI_TABLOLARI:
        op.execute(
            f"""
            CREATE TABLE {tablo} (
                id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
                {fk_kolon} uuid NOT NULL,
                -- Hedef dil (ISO 639-1). Kume genisletmek MIGRATION ister.
                dil        text NOT NULL,
                -- Cevrilmis alanlar: {{"baslik": "...", "govde"/"icerik"/"aciklama": "..."}}
                alanlar    jsonb NOT NULL DEFAULT '{{}}'::jsonb,
                durum      ceviri_durum NOT NULL DEFAULT 'bekliyor',
                -- MAKINE cevirisi mi? Elle duzeltilen ceviride false olur.
                cevirildi_mi    boolean NOT NULL DEFAULT true,
                -- Yonetici elle duzeltti: kaynak metin degismedikce KORUNUR.
                elle_duzeltildi boolean NOT NULL DEFAULT false,
                -- Cevirinin uretildigi KAYNAK metnin sha256'si (bkz. modul notu).
                kaynak_hash text NOT NULL,
                -- durum='hata' iken kisa neden (saglayici mesaji; PII tasimaz).
                hata_mesaji text,
                created_at timestamptz NOT NULL DEFAULT now(),
                updated_at timestamptz NOT NULL DEFAULT now(),
                CONSTRAINT uq_{tablo} UNIQUE (tenant_id, {fk_kolon}, dil),
                CONSTRAINT ck_{tablo}_dil CHECK (dil IN ({dil_listesi})),
                -- Cross-tenant referansi ENGELLER + icerik silinince cevirileri
                -- de siler (composite FK deseni, bkz. 0001).
                FOREIGN KEY ({fk_kolon}, tenant_id)
                    REFERENCES {kaynak} (id, tenant_id) ON DELETE CASCADE
            );
            """
        )
        # Okuma deseni: "bu icerigin su dildeki cevirisi" (tekil) — UNIQUE
        # indeksi zaten karsilar. Liste ucu icin (tenant, dil) ile tarama:
        op.execute(f"CREATE INDEX ix_{tablo}_dil ON {tablo} (tenant_id, dil);")

        # RLS: tenant-kapsamli, diger tablolarla AYNI desen (ENABLE + FORCE).
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_isolation ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
        # Tam DML: worker UPSERT eder, icerik silinince CASCADE siler.
        op.execute(
            f"GRANT SELECT, INSERT, UPDATE, DELETE ON {tablo} TO {APP_ROLE};"
        )


def downgrade() -> None:
    for tablo, _kaynak, _fk in _CEVIRI_TABLOLARI:
        op.execute(f"DROP TABLE IF EXISTS {tablo};")
    op.execute("DROP TYPE IF EXISTS ceviri_durum;")
    for kaynak in ("announcement", "site_kurali", "etkinlik"):
        op.execute(f"ALTER TABLE {kaynak} DROP COLUMN IF EXISTS kaynak_dil;")
