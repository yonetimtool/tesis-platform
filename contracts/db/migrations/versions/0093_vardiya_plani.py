"""(P203 §4) VARDIYA PLANI — gun bazli atama.

===========================================================================
ONCE OLCUM: MEVCUT MODEL PLANLAMA YAPAMIYOR
===========================================================================
    shift             = SABLON  (ad + baslangic/bitis saati + gun_tipi)
    shift_assignment  = (tenant, shift_id, user_id)   -- TARIH YOK

Yani bugun soylenebilen tek sey "Ali GECE vardiyasindadir" — hangi GUN
oldugu yok. Istenen her sey tarih boyutu gerektiriyor:

  * haftalik plan (hangi gun kim),
  * GUN ICI degisiklik (hastalik/izin/acil) — sablon atamasini
    degistirmek GECMISI ve TUM GELECEK gunleri de degistirirdi,
  * cakisma kontrolu ("ayni anda iki vardiyada olamaz") — "ayni an"
    ancak tarihle tanimlanir,
  * planlanan/gerceklesen karsilastirmasi (§5 mesai hesabi).

===========================================================================
IKI TABLO, IKI FARKLI SORU — VE `shift_assignment` KALIYOR
===========================================================================
`shift_assignment` SILINMEDI ve bu bilincli: o artik VARSAYILAN KADRODUR
("Ali normalde gece vardiyasinda calisir"). `vardiya_plani` ise O GUN
GERCEKTE kimin planlandigini soyler ve kadrodan TOHUMLANIR.

Ayrimi kaldirip tek tabloya inmek, "her hafta bastan atama" demekti —
yirmi kisilik bir ekipte haftada yuzlerce tiklama.

===========================================================================
DURUM: PLANLI | IPTAL
===========================================================================
Iptal edilen atama SILINMEZ, `iptal` isaretlenir. Gun ici degisiklikler
DENETIME yaziliyor (istek §4.3) ve silinen bir satirin denetim kaydi
"neyin degistigini" gosteremezdi: "Ali cikarildi, Veli eklendi" iki ayri
satir olarak DURMALI.

Geri alinabilir: `downgrade` tabloyu dusurur.
"""
from alembic import op
import sqlalchemy as sa

APP_ROLE = "app_rw"

revision = "0093_vardiya_plani"
down_revision = "0092_tenant_uyelikleri"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE vardiya_plani (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            shift_id   uuid NOT NULL,
            -- TARIH: planin tasidigi TEK yeni bilgi ve varlik sebebi.
            tarih      date NOT NULL,
            user_id    uuid NOT NULL,
            durum      text NOT NULL DEFAULT 'planli'
                       CHECK (durum IN ('planli', 'iptal')),
            -- Degisiklik SEBEBI (hastalik/izin/acil). Serbest metin:
            -- sabit bir liste, sahada karsilasilan sebepleri kapsamaz
            -- ve "diger" secenegi bilgiyi yine metne iterdi.
            not_metni  text,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_vardiya_plani_shift
                FOREIGN KEY (shift_id, tenant_id)
                REFERENCES shift (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_vardiya_plani_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    # AYNI KISI AYNI VARDIYAYA AYNI GUN IKI KEZ yazilamaz. Kismi indeks:
    # iptal edilmis bir satir, yeniden planlamayi ENGELLEMEMELI (kisi
    # cikarilip geri konabilir).
    op.execute(
        "CREATE UNIQUE INDEX uq_vardiya_plani_planli "
        "ON vardiya_plani (tenant_id, shift_id, tarih, user_id) "
        "WHERE durum = 'planli';"
    )
    # Haftalik gorunum SORGUSU: tenant + tarih araligi.
    op.execute(
        "CREATE INDEX ix_vardiya_plani_tarih "
        "ON vardiya_plani (tenant_id, tarih);"
    )
    # Cakisma kontrolu ve "su an kim gorevde": kisi + tarih.
    op.execute(
        "CREATE INDEX ix_vardiya_plani_kisi "
        "ON vardiya_plani (tenant_id, user_id, tarih);"
    )
    op.execute("ALTER TABLE vardiya_plani ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE vardiya_plani FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY vardiya_plani_isolation ON vardiya_plani
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON vardiya_plani TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS vardiya_plani;")
