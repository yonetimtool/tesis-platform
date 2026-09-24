"""(P247 §1) VARDIYA ROTASYONU — DONGU KALIPLARI.

===========================================================================
YENI BIR VARDIYA KAVRAMI YOK — KALIP VE PARTI GENISLEDI
===========================================================================
Sahadaki donguler ("2 gece, 2 gunduz, 2 tatil" / "iki hafta gece 12/36,
iki hafta gunduz 12/36") P207'nin KALIBI ile P207'nin PARTISI'nin
birlesimidir: kalip gunu dilimlere boler, parti uretilen satirlari tek
adimda geri aldirir. Eksik olan uc sey vardi ve uc kolon/tablo ekleniyor:

1. `vardiya_kalibi.adimlar` — DONGU. JSONB, gun uzunlugunda ADIM dizisi:
   her adim o gun calisilacak dilimlerin SIRA NUMARALARI (`[0]`, `[1]`,
   `[0,1]`), bos dizi = TATIL. NULL = klasik (P207) kalip: her secili
   gune tum dilimler. 12/36 da ayni dizi: `[[0],[]]` (gun asiri).

2. `vardiya_dongu_atama` — KISI x DONGU x BASLANGIC. Dongu "kisiye
   baslangic tarihiyle atanir, sistem ileriye dogru uretir": bu, bir
   kere yazilip biten bir parti degil, SURESIZ bir iliski. Beat bu
   tablodan okuyup kayan ufku doldurur; `uretildi_kadar` filigrani
   ayni gunu iki kez uretmeyi (ve elle degistirilmis/iptal edilmis bir
   satiri yeniden yazmayi) imkansiz kilar.

3. `vardiya_plani.dongu_atama_id` — satirin HANGI atamadan geldigi.
   Atama sonlandirilinca yalniz ONUN gelecek satirlari iptal edilir
   (ekibin partisinin tamami degil).

Goc `app.*` ithal ETMEZ (dondurulmus kopya kurali). IF NOT EXISTS: gelistirme
ortaminda DDL goc zincirinden once elle uygulanmis olabilir.
"""
from alembic import op

revision = "0154_p247_vardiya_dongu"
down_revision = "0153_p247_kargo_ziyaretci"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute("ALTER TABLE vardiya_kalibi ADD COLUMN IF NOT EXISTS adimlar jsonb;")
    # 1..84 GUN (12 hafta). Ust sinir: dongu ekranda gun gun cizilir ve
    # uc aydan uzun bir "dongu" pratikte bir yillik plandir, dongu degil.
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = "
        "'ck_vardiya_kalibi_adimlar') THEN "
        "ALTER TABLE vardiya_kalibi ADD CONSTRAINT ck_vardiya_kalibi_adimlar "
        "CHECK (adimlar IS NULL OR (jsonb_typeof(adimlar) = 'array' "
        "AND jsonb_array_length(adimlar) BETWEEN 1 AND 84)); "
        "END IF; END $$;"
    )

    op.execute(
        """
        CREATE TABLE IF NOT EXISTS vardiya_dongu_atama (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            kalip_id uuid REFERENCES vardiya_kalibi(id) ON DELETE SET NULL,
            user_id uuid NOT NULL,
            referans date NOT NULL,
            baslangic date NOT NULL,
            bitis date,
            uretildi_kadar date,
            parti_id uuid NOT NULL,
            molalar jsonb NOT NULL DEFAULT '[]'::jsonb,
            not_metni text,
            atlanan jsonb NOT NULL DEFAULT '[]'::jsonb,
            olusturan_user_id uuid,
            iptal_at timestamptz,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_dongu_atama_user FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT ck_dongu_atama_bitis CHECK (bitis IS NULL OR bitis >= baslangic - 1)
        );
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_dongu_atama_tenant "
        "ON vardiya_dongu_atama (tenant_id) WHERE iptal_at IS NULL;"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_dongu_atama_parti "
        "ON vardiya_dongu_atama (tenant_id, parti_id);"
    )
    # FK oncu kolon indeksi: kalip silinirken RI tetigi seq scan etmesin
    # (`test_indeks_kapsam` kilidi).
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_dongu_atama_kalip "
        "ON vardiya_dongu_atama (kalip_id);"
    )
    op.execute("ALTER TABLE vardiya_dongu_atama ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE vardiya_dongu_atama FORCE ROW LEVEL SECURITY;")
    op.execute(
        "DO $$ BEGIN "
        "IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = "
        "'vardiya_dongu_atama' AND policyname = 'vardiya_dongu_atama_isolation') THEN "
        "CREATE POLICY vardiya_dongu_atama_isolation ON vardiya_dongu_atama "
        "USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid) "
        "WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid); "
        "END IF; END $$;"
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON vardiya_dongu_atama TO {APP_ROLE};"
    )

    op.execute(
        "ALTER TABLE vardiya_plani ADD COLUMN IF NOT EXISTS dongu_atama_id uuid "
        "REFERENCES vardiya_dongu_atama(id) ON DELETE SET NULL;"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_vardiya_plani_dongu "
        "ON vardiya_plani (dongu_atama_id, tarih) WHERE dongu_atama_id IS NOT NULL;"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_vardiya_plani_dongu;")
    op.execute("ALTER TABLE vardiya_plani DROP COLUMN IF EXISTS dongu_atama_id;")
    op.execute("DROP TABLE IF EXISTS vardiya_dongu_atama;")
    op.execute(
        "ALTER TABLE vardiya_kalibi DROP CONSTRAINT IF EXISTS ck_vardiya_kalibi_adimlar;"
    )
    op.execute("ALTER TABLE vardiya_kalibi DROP COLUMN IF EXISTS adimlar;")
