"""(P191-ek §1) user_device.cihaz_kimligi — AYNI CİHAZ İÇİN TEK SATIR

===========================================================================
ÖLÇÜLEN KUSUR
===========================================================================
Bir tesiste 18 kayıtlı cihaz vardı ve **hepsi tek kullanıcıya aitti**:
uygulama her yeniden kurulumda / veri temizliğinde / uzun aradan sonra
FCM'den YENİ bir jeton alır, backend onu `UNIQUE (tenant_id, fcm_token)`
kuralına göre YENİ BİR SATIR olarak yazardı. Eski satır "aktif" kalır ve
her gönderimde boşuna denenir; FCM `UNREGISTERED` döner.

Tekillik yanlış anahtardaydı: **jeton bir cihaz kimliği değildir**, cihazın
o anki adresidir. Adres değişince kayıt çoğalmamalı, GÜNCELLENMELİDİR.

===========================================================================
KARAR: CİHAZ KİMLİĞİ İSTEMCİDEN GELİR, NULLABLE'DIR
===========================================================================
`cihaz_kimligi` uygulamanın ilk açılışta üretip güvenli depoda sakladığı
kararlı bir kurulum kimliğidir (donanım kimliği DEĞİL: donanım kimliği
kalıcı bir izleyicidir ve KVKK açısından gereksiz bir veridir; kurulum
kimliği uygulama silinince yok olur).

**NULLABLE ve öyle kalmalı:** alanı göndermeyen ESKİ SÜRÜMLER sahada
çalışmaya devam ediyor. Zorunlu kılmak, güncellemeyen kullanıcının
bildirimlerini tamamen kesmek olurdu. Kimlik yoksa eski davranış (jeton
bazlı satır) aynen sürer.

Kısmi UNIQUE indeks: aynı kullanıcının aynı cihazı için AKTİF tek satır.
`aktif=false` satırlar indeksin DIŞINDA — geçmiş korunur, aynı cihaz
yeniden kaydolabilir.

Revision ID: 0082_cihaz_kimligi
Revises: 0081_banka_push_fk_indeks
Create Date: 2026-08-31
"""
from alembic import op

revision = "0082_cihaz_kimligi"
down_revision = "0081_banka_push_fk_indeks"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE user_device ADD COLUMN cihaz_kimligi text;")
    op.execute(
        "CREATE UNIQUE INDEX uq_user_device_cihaz "
        "ON user_device (tenant_id, user_id, cihaz_kimligi) "
        "WHERE cihaz_kimligi IS NOT NULL AND aktif;"
    )
    # "Bu kullanicinin aktif cihazlari" sorgusu (temizlik + teshis).
    op.execute(
        "CREATE INDEX ix_user_device_aktif "
        "ON user_device (tenant_id, aktif) WHERE aktif;"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_user_device_aktif;")
    op.execute("DROP INDEX IF EXISTS uq_user_device_cihaz;")
    op.execute("ALTER TABLE user_device DROP COLUMN IF EXISTS cihaz_kimligi;")
