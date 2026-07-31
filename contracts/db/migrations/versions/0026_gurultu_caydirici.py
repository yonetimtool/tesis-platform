"""gurultu caydirici (0026) — MASTER-PLAN P37: esik -> eylem -> sifirlama.

AYRI BIR WEBHOOK KONFIGURASYONU ACILMADI. C1b'nin `integration` tablosu
zaten SSRF-korumali gonderim, KEK ile sifreli sir ve tenant izolasyonu
sunuyor; ikinci bir URL/sir alani ayni guvenlik kontrollerini IKINCI KEZ
yazmak ve birini gunceleyip digerini unutmak demekti. Tenant yalnizca
HANGI entegrasyonun caydirici oldugunu secer.

MANUEL MOD BIR HATA DURUMU DEGIL, BIRINCI SINIF MOD: entegrasyonu olmayan
sitede (cogu site) esik asilinca yoneticiye BILDIRIM gider ve anonsu o
yapar. `gurultu_integration_id` NULL olmasi "ozellik calismiyor" degil
"manuel mod" demektir.

SIFIRLAMA KAYIT SILMEZ: esige varinca o dairenin ACIK sikayetleri
`kapali`ya cekilir — kayitlar GECMISTE DURUR, yalnizca sayac (dolayisiyla
P24 renk skalasi) yesile doner. Silmek, uyarinin dayanagini yok etmek
olurdu.

UYARI KAYDI AYRI TABLODUR: "bu daireye ne zaman, hangi sayacla, hangi
metinle uyari verildi" sorusu denetlenebilir olmali. Bunu sikayet
satirlarina gomulu bir bayrakla tutmak, uyarinin kendisini bir sikayetin
alt-ozelligi yapardi.

YERINDE DUZENLEME ISTISNASI (MIGRATION-POLITIKASI.md kural 3): FK'yi
kapsayan `ix_tenant_gurultu_integration` indeksi, dosya ilk yazildiktan
sonra AYNI oturumda eklendi (indeks kapsami envanteri "ust satir silinince
RI tetigi tenant'i seq scan eder" diye yakaladi). Revizyon o an hicbir
ortama gitmemisti — commit/push/prod yok; yalniz gelistirici veritabanina
uygulanmisti ve `downgrade` -> `upgrade` ile yeniden kuruldu.

Revision ID: 0026_gurultu_caydirici
Revises: 0025_kvkk_riza
"""
from __future__ import annotations

from alembic import op

revision = "0026_gurultu_caydirici"
down_revision = "0025_kvkk_riza"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TYPE uyari_kanal AS ENUM ('webhook', 'manuel');"
    )
    # `manuel_bekliyor`: anons YONETICIDEN bekleniyor. `basarisiz`: webhook
    # denendi ve olmadi — yeniden deneme kuyrugundadir (silinmez: kac kez
    # denendigi ve neden basarisiz oldugu denetim verisidir).
    op.execute(
        "CREATE TYPE uyari_durum AS ENUM "
        "('gonderildi', 'basarisiz', 'manuel_bekliyor', 'manuel_yapildi');"
    )
    op.execute(
        """
        ALTER TABLE tenant
            ADD COLUMN gurultu_esigi integer NOT NULL DEFAULT 5,
            -- NULL = varsayilan metin (uygulama katalogundan, kullanicinin
            -- dilinde). Bos metin ile NULL FARKLIDIR: bos metin
            -- "anons metnini bilerek bosalttim" demek olurdu ve anons
            -- iceriksiz giderdi.
            ADD COLUMN gurultu_uyari_metni text NULL,
            -- NULL = MANUEL MOD (hata degil, birinci sinif mod).
            ADD COLUMN gurultu_integration_id uuid NULL,
            ADD CONSTRAINT ck_tenant_gurultu_esigi
                CHECK (gurultu_esigi BETWEEN 1 AND 50),
            ADD CONSTRAINT fk_tenant_gurultu_integration
                FOREIGN KEY (gurultu_integration_id)
                REFERENCES integration (id) ON DELETE SET NULL;
        """
    )
    # FK'nin ONCU kolonunu kapsayan indeks: entegrasyon silinince RI tetigi
    # tenant tablosunu seq scan etmesin (indeks kapsami envanteri).
    op.execute(
        "CREATE INDEX ix_tenant_gurultu_integration ON tenant "
        "(gurultu_integration_id) WHERE gurultu_integration_id IS NOT NULL;"
    )
    op.execute(
        """
        CREATE TABLE unit_uyari (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            unit_id     uuid NOT NULL,
            -- Esik ve sayac O ANKI degerleriyle KOPYALANIR: ayar sonradan
            -- degisirse gecmis uyari "5'te verildi" demeye devam etmeli.
            esik        integer NOT NULL,
            sayac       integer NOT NULL,
            -- Gonderilen METIN de kopyalanir (P32 gecmisiyle ayni gerekce):
            -- sablon degisse de ne soylendigi kanit olarak durur.
            metin       text NOT NULL,
            kanal       uyari_kanal NOT NULL,
            durum       uyari_durum NOT NULL,
            deneme      integer NOT NULL DEFAULT 0,
            hata        text NULL,
            son_deneme_at timestamptz NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_unit_uyari_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_unit_uyari_deneme CHECK (deneme >= 0),
            CONSTRAINT fk_unit_uyari_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_unit_uyari_tenant ON unit_uyari "
        "(tenant_id, created_at DESC);"
    )
    # Yeniden deneme kuyrugu: yalniz basarisiz satirlar taranir (kismi indeks
    # — tablonun tamami buyudukce kuyruk taramasi buyumemeli).
    op.execute(
        "CREATE INDEX ix_unit_uyari_kuyruk ON unit_uyari "
        "(tenant_id, son_deneme_at) WHERE durum = 'basarisiz';"
    )
    op.execute("ALTER TABLE unit_uyari ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE unit_uyari FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY unit_uyari_tenant_isolation ON unit_uyari
            USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);
        """
    )
    op.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON unit_uyari TO app_rw;")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS unit_uyari;")
    op.execute("DROP TYPE IF EXISTS uyari_durum;")
    op.execute("DROP TYPE IF EXISTS uyari_kanal;")
    op.execute("DROP INDEX IF EXISTS ix_tenant_gurultu_integration;")
    op.execute(
        "ALTER TABLE tenant "
        "DROP CONSTRAINT IF EXISTS fk_tenant_gurultu_integration;"
    )
    op.execute(
        "ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_gurultu_esigi;"
    )
    op.execute(
        "ALTER TABLE tenant "
        "DROP COLUMN IF EXISTS gurultu_integration_id, "
        "DROP COLUMN IF EXISTS gurultu_uyari_metni, "
        "DROP COLUMN IF EXISTS gurultu_esigi;"
    )
