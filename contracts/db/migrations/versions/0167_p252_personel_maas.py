"""(P252) Personel takibi — maas karti calisma bilgileri + otomatik maas gideri.

* `personel_kayit`: odeme gunu (1–31; ayda yoksa ayin son gunu), kasa,
  IBAN, not, otomasyon damgalari (`maas_ilk_donem`, `son_maas_donem`).
* Bir HESABA en cok BIR maas karti: P251'de uygulamada denetleniyordu,
  artik veritabani kisiti (kismi benzersiz indeks). Varsa cift bag
  (yalniz API ile kurulabiliyordu) EN ESKI kartta birakilir, digerlerinde
  bag kaldirilir — kart silinmez, ucret kaybolmaz.
* `finansal_hareket.personel_kayit_id`: gideri KISIYE baglar (hesapsiz
  personel dahil; `user_id` yalniz hesabi olanda dolu).
* `gelir_gider_tanim.sistem_kodu`: otomasyonun kalemleri ("Personel
  maasi", "Fazla mesai") ADINDAN degil KODUNDAN bulunur; yonetici adi
  degistirse de seffaflik birlestirmesi ve otomasyon bozulmaz.
* `tenant`: maas otomasyonu acik/kapali + otomatik onay (varsayilan
  ONAYLI — gerekce `docs/P252-kararlar.md` §2).
* `notification_tip`: `maas_yazildi`; `otomasyon_turu`: `maas`.
"""
from alembic import op

revision = "0167_p252_personel_maas"
down_revision = "0166_p251_gonderim_gunlugu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE personel_kayit "
        "ADD COLUMN odeme_gunu smallint, "
        "ADD COLUMN kasa_id uuid, "
        "ADD COLUMN iban text, "
        "ADD COLUMN notlar text, "
        "ADD COLUMN maas_ilk_donem text, "
        "ADD COLUMN son_maas_donem text, "
        "ADD CONSTRAINT ck_personel_odeme_gunu "
        "CHECK (odeme_gunu IS NULL OR odeme_gunu BETWEEN 1 AND 31);"
    )
    # Cift bag temizligi (bkz. baslik) — sonra kisit.
    op.execute(
        """
        UPDATE personel_kayit p SET app_user_id = NULL
        WHERE p.app_user_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM personel_kayit q
            WHERE q.tenant_id = p.tenant_id AND q.app_user_id = p.app_user_id
              AND (q.created_at, q.id) < (p.created_at, p.id)
        );
        """
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_personel_hesap ON personel_kayit (tenant_id, app_user_id) "
        "WHERE app_user_id IS NOT NULL;"
    )
    op.execute(
        "ALTER TABLE finansal_hareket ADD COLUMN personel_kayit_id uuid;"
    )
    op.execute(
        "CREATE INDEX ix_hareket_personel ON finansal_hareket (tenant_id, personel_kayit_id) "
        "WHERE personel_kayit_id IS NOT NULL;"
    )
    op.execute("ALTER TABLE gelir_gider_tanim ADD COLUMN sistem_kodu text;")
    op.execute(
        "CREATE UNIQUE INDEX uq_tanim_sistem_kodu ON gelir_gider_tanim (tenant_id, sistem_kodu) "
        "WHERE sistem_kodu IS NOT NULL;"
    )
    op.execute(
        "ALTER TABLE tenant "
        "ADD COLUMN maas_otomasyonu_aktif boolean NOT NULL DEFAULT true, "
        "ADD COLUMN maas_otomatik_onay boolean NOT NULL DEFAULT true;"
    )
    op.execute("ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'maas_yazildi';")
    op.execute("ALTER TYPE otomasyon_turu ADD VALUE IF NOT EXISTS 'maas';")


def downgrade() -> None:
    op.execute(
        "ALTER TABLE tenant DROP COLUMN IF EXISTS maas_otomatik_onay, "
        "DROP COLUMN IF EXISTS maas_otomasyonu_aktif;"
    )
    op.execute("DROP INDEX IF EXISTS uq_tanim_sistem_kodu;")
    op.execute("ALTER TABLE gelir_gider_tanim DROP COLUMN IF EXISTS sistem_kodu;")
    op.execute("DROP INDEX IF EXISTS ix_hareket_personel;")
    op.execute("ALTER TABLE finansal_hareket DROP COLUMN IF EXISTS personel_kayit_id;")
    op.execute("DROP INDEX IF EXISTS uq_personel_hesap;")
    op.execute(
        "ALTER TABLE personel_kayit DROP CONSTRAINT IF EXISTS ck_personel_odeme_gunu, "
        "DROP COLUMN IF EXISTS son_maas_donem, DROP COLUMN IF EXISTS maas_ilk_donem, "
        "DROP COLUMN IF EXISTS notlar, DROP COLUMN IF EXISTS iban, "
        "DROP COLUMN IF EXISTS kasa_id, DROP COLUMN IF EXISTS odeme_gunu;"
    )
    # notification_tip degeri GERI ALINMAZ (PostgreSQL enum degeri dusurulemez).
