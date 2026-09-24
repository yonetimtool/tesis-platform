"""(P247 §3) KARGO VE ZIYARETCI "BEKLIYOR"DA KALIYORDU.

===========================================================================
OLCULEN DURUM (once)
===========================================================================
Uctan uca surus (tesis p247kargo): backend akislari KENDI tasarimina gore
calisiyordu; kayitlar yine de kapanmiyordu, cunku KAPANISI YAPACAK KISI
ya yetkisizdi ya da dugmesi yoktu:

  * KARGO: `PATCH /kargo/{id}` YALNIZ sakine acikti. Paketi kapida fiilen
    sakine VEREN guvenlik isaretleyemiyordu (403). Sakin uygulamada
    "teslim aldim"a basmazsa (ya da uygulamasi yoksa — daireye bagli ama
    oturmayan malik, yasli sakin) kayit sonsuza dek `bekliyor` kaliyordu.
  * ZIYARETCI: `POST /visitors/{id}/checkout` backend'de vardi, ama
    guvenligin TEK yuzeyi olan mobilde cikis dugmesi YOKTU (model
    `cikis_zamani`ni bile okumuyordu). Web ekrani P129 geregi park
    edilmisti. Sonuc: guvenlik ana ekranindaki "N iceride" sayaci
    yalnizca artiyordu.

===========================================================================
BU GOC
===========================================================================
  * `kargo.teslim_eden_user_id` — paketi sakine VEREN guvenlik. Sakin
    kendisi isaretlerse NULL kalir. `teslim_alan_user_id`den AYRI kolon:
    ikisini tek kolona yazmak "kim teslim aldi" sorusuna guvenligin adini
    cevap olarak verirdi.
  * `visitor.cikis_otomatik` — beat isinin kapattigi kayit. `cikis_zamani`
    doldurulur (kayit artik "iceride" sayilmaz) ama bu bayrak "cikis
    GORULMEDI, sistem kapatti" der; ekranlar "Cikis kaydedilmedi" yazar.
  * `notification_tip` += `kargo_teslim` — guvenlik teslim ettiginde
    dairenin sakinlerine kalici bildirim.

Goc `app.*` ithal ETMEZ (dondurulmus kopya kurali).
"""
from alembic import op

revision = "0153_p247_kargo_ziyaretci"
down_revision = "0152_e2e_duyuru_hedef"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE kargo ADD COLUMN IF NOT EXISTS teslim_eden_user_id uuid;")
    # Kolon-ozel SET NULL (fk_kargo_teslim_alan ile ayni desen): guvenlik
    # hesabi silinirse yalniz bu kolon NULL'lanir, tenant_id korunur.
    # IDEMPOTENT (DO blogu): dev veritabanina ayni DDL elle uygulanmis
    # olabilir; goc ikinci kez kosarsa kisit catismasi vermemeli.
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'fk_kargo_teslim_eden'
            ) THEN
                ALTER TABLE kargo ADD CONSTRAINT fk_kargo_teslim_eden
                    FOREIGN KEY (teslim_eden_user_id, tenant_id)
                    REFERENCES app_user (id, tenant_id)
                    ON DELETE SET NULL (teslim_eden_user_id);
            END IF;
        END $$;
        """
    )
    op.execute(
        "ALTER TABLE visitor ADD COLUMN IF NOT EXISTS cikis_otomatik boolean "
        "NOT NULL DEFAULT false;"
    )
    op.execute("ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'kargo_teslim';")


def downgrade() -> None:
    op.execute("ALTER TABLE visitor DROP COLUMN IF EXISTS cikis_otomatik;")
    op.execute("ALTER TABLE kargo DROP CONSTRAINT IF EXISTS fk_kargo_teslim_eden;")
    op.execute("ALTER TABLE kargo DROP COLUMN IF EXISTS teslim_eden_user_id;")
    # notification_tip degeri GERI ALINMAZ (goc 0131/0140/0144 emsali).
