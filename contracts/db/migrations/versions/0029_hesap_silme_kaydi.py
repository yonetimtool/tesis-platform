"""hesap silme kaydi (0029) — MASTER-PLAN P112: App Store 5.1.1(v) + KVKK kaniti.

NE ICIN: kullanici uygulama icinden hesabini sildiginde (ya da yonetim bir
sakini cikardiginda) geriye **silindiginin kaniti** kalmali. Kisisel verinin
kendisi gitmis olacagi icin kanit, veriden BAGIMSIZ bir satir olmak zorunda.

NEDEN `audit_log` YETMIYOR: denetim kaydi saklama politikasi geregi PURGE
edilir (`retention_audit_months`, varsayilan 24 ay). Silme talebi eden bir
kisi ya da denetleyen bir kurum bundan **sonra** sorabilir; o an "sildik"
diyebilmenin dayanagi kalmazdi. Bu tablo retention motoruna DAHIL DEGILDIR.

ICINDE KISISEL VERI YOKTUR — ve olamaz da: tam olarak kisisel veriyi
sildigimizi kanitlamak icin var. Yalniz kimlikler, rol, mod ve zaman.

`user_id`de FK **YOKTUR** (bilincli): "hard_delete" modunda `app_user`
satiri artik mevcut degildir; FK olsaydi kanit satirini yazmak imkansiz
olurdu ya da kaniti kaydin kendisini silerek kaybederdik.

`mod`:
  * `hard_delete` — hesabin hicbir gecmisi yoktu, satir tamamen silindi,
  * `anonymize`   — finans/denetim satirlari yasal olarak saklandigi icin
    hesap satiri KALDI, kimlik alanlari temizlendi.

`kendi_istegi`: true ise **kullanicinin kendisi** sildi (App Store
5.1.1(v) akisi), false ise yonetim cikardi. Ayrimi tutmak, "kullanici
silme hakkini kullanabiliyor mu" sorusunun sayiyla yanitlanmasini saglar.

Revision ID: 0029_hesap_silme_kaydi
Revises: 0028_vezne_idempotency
"""
from __future__ import annotations

from alembic import op

revision = "0029_hesap_silme_kaydi"
down_revision = "0028_vezne_idempotency"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE hesap_silme_kaydi (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            -- FK YOK: hard_delete modunda app_user satiri artik yoktur.
            user_id       uuid NOT NULL,
            rol           user_role NOT NULL,
            mod           text NOT NULL,
            kendi_istegi  boolean NOT NULL,
            created_at    timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_hesap_silme_mod
                CHECK (mod IN ('hard_delete', 'anonymize'))
        );
        """
    )
    # AYNI HESAP IKI KEZ SILINEMEZ: anonimlestirilmis bir satir icin ikinci
    # bir silme istegi gelirse kanit satiri COGALMAMALI (sayim bozulurdu).
    op.execute(
        "CREATE UNIQUE INDEX uq_hesap_silme_user "
        "ON hesap_silme_kaydi (tenant_id, user_id);"
    )
    op.execute(
        "CREATE INDEX ix_hesap_silme_zaman "
        "ON hesap_silme_kaydi (tenant_id, created_at DESC);"
    )
    op.execute("ALTER TABLE hesap_silme_kaydi ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE hesap_silme_kaydi FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY hesap_silme_kaydi_tenant_isolation ON hesap_silme_kaydi
            USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);
        """
    )
    # KANIT SATIRI GUNCELLENEMEZ/SILINEMEZ: `audit_log` ile ayni gerekce —
    # degistirilebilen bir kanit kanit degildir. app_rw yalniz okur ve yazar.
    op.execute("GRANT SELECT, INSERT ON hesap_silme_kaydi TO app_rw;")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS hesap_silme_kaydi;")
