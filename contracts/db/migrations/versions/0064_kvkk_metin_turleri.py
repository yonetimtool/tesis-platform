"""(P168 §5) KVKK VE YASAL METINLER — bes tur + yeniden onay bayragi.

===========================================================================
NEDEN MEVCUT TABLONUN UZERINE
===========================================================================
Brief: "Mevcut `kvkk_metin` tablosunu incele; varsa uzerine kur, yeniden
yazma." Dogru karar: tablo zaten P36'da dogru kurulmus — surumleme var,
yayinlanmis metin DEGISTIRILEMIYOR, onay SURUME bagli. Eksik olan tek sey
metnin TURU.

Bugun tablo tek bir metni tasiyor (aydinlatma metni). Brief bes tur
istiyor: Aydinlatma · Acik Riza · Gizlilik Politikasi · Kullanim
Kosullari · Cerez Politikasi.

===========================================================================
`tur` KOLONU VE KISITLARIN GENISLEMESI
===========================================================================
Surum numarasi artik TUR BASINA ilerler: `uq_kvkk_metin_surum`
(tenant, surum) -> (tenant, tur, surum). Aksi halde gizlilik politikasi
yayinlamak aydinlatma metninin surum numarasini atlatirdi ve "v3'u
onayladim" cumlesi hangi metne ait oldugu belirsiz kalirdi.

ONAY DA TUR BASINA: `uq_kvkk_onay` (tenant, user, surum) ->
(tenant, user, tur, surum). Bu kisit genislemeseydi, kullanici gizlilik
politikasinin 1. surumunu onayladiginda aydinlatma metninin 1. surumu de
onaylanmis SAYILIRDI — hukuki olarak yanlis, ve sessiz.

MEVCUT SATIRLAR `aydinlatma`ya tasinir: bugune kadar yayinlanan tek metin
oydu ve varsayilan da odur.

===========================================================================
`yeniden_onay_gerekir` — BRIEF'IN ISTEDIGI BAYRAK
===========================================================================
Brief: "Metin guncellenince kullanicilardan yeniden onay istensin mi —
bir 'yeniden onay gerektirir' bayragi olsun."

Gercek bir ihtiyac: bir yazim hatasini duzeltmek icin cikilan surum,
200 sakini yeniden onay ekranina sokmamali. Ama esasa iliskin bir
degisiklik (yeni bir veri isleme amaci) SOKMALI.

VARSAYILAN `true` VE BU BILINCLI: guvenli yon, sormaktir. Varsayilan
`false` olsaydi, esasli bir degisikligi yayinlayan yonetici kutuyu
isaretlemeyi unuttugunda kimseye sorulmaz ve bu SESSIZCE hukuki bir
eksiklik olurdu.

===========================================================================
YURURLUK DURUMU NEDEN KOLON DEGIL
===========================================================================
Brief "yururluk durumu" da istiyor. Ayri bir `yururlukte` kolonu
ACILMADI: iki satirin ayni anda yururlukte olmasi ya da hicbirinin
olmamasi mumkun hale gelirdi ve bu, "hangi metni onayliyorum" sorusunu
cevapsiz birakirdi.

Yururlukte olan, TUR BASINA EN YUKSEK SURUMDUR — turetilir, saklanmaz.
API `yururlukte: bool` doner; veri tabaninda tutarsizlik imkani yoktur.
"""
from alembic import op

revision = "0064_kvkk_metin_turleri"
down_revision = "0063_mesaj_yapilandirma"
branch_labels = None
depends_on = None

TURLER = (
    "('aydinlatma','acik_riza','gizlilik','kullanim_kosullari','cerez')"
)


def upgrade() -> None:
    op.execute(f"CREATE TYPE kvkk_metin_tur AS ENUM {TURLER}")
    for tablo in ("kvkk_metin", "kvkk_onay"):
        op.execute(
            f"ALTER TABLE {tablo} ADD COLUMN tur kvkk_metin_tur "
            "NOT NULL DEFAULT 'aydinlatma'"
        )
    op.execute(
        "ALTER TABLE kvkk_metin ADD COLUMN yeniden_onay_gerekir boolean "
        "NOT NULL DEFAULT true"
    )

    # Kisitlar TUR'u de kapsayacak sekilde yeniden kuruluyor.
    op.execute("ALTER TABLE kvkk_metin DROP CONSTRAINT IF EXISTS uq_kvkk_metin_surum")
    op.execute(
        "ALTER TABLE kvkk_metin ADD CONSTRAINT uq_kvkk_metin_surum "
        "UNIQUE (tenant_id, tur, surum)"
    )
    op.execute("ALTER TABLE kvkk_onay DROP CONSTRAINT IF EXISTS uq_kvkk_onay")
    op.execute(
        "ALTER TABLE kvkk_onay ADD CONSTRAINT uq_kvkk_onay "
        "UNIQUE (tenant_id, user_id, tur, surum)"
    )
    # Guncel surumu bulmak TUR + SURUM DESC ile taranir.
    op.execute(
        "CREATE INDEX ix_kvkk_metin_tur ON kvkk_metin (tenant_id, tur, surum DESC)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_kvkk_metin_tur")
    op.execute("ALTER TABLE kvkk_onay DROP CONSTRAINT IF EXISTS uq_kvkk_onay")
    op.execute("ALTER TABLE kvkk_metin DROP CONSTRAINT IF EXISTS uq_kvkk_metin_surum")
    # GERI ALIRKEN VERI KAYBI RISKI: `aydinlatma` disindaki turler
    # silinmeden eski (tenant, surum) kisiti kurulamaz — cunku ayni surum
    # numarasi farkli turlerde tekrar ediyor olabilir. Bu yuzden once
    # OTEKI TURLER SILINIR ve bu, geri alisin BILINEN bedelidir.
    op.execute("DELETE FROM kvkk_onay WHERE tur <> 'aydinlatma'")
    op.execute("DELETE FROM kvkk_metin WHERE tur <> 'aydinlatma'")
    op.execute(
        "ALTER TABLE kvkk_metin ADD CONSTRAINT uq_kvkk_metin_surum "
        "UNIQUE (tenant_id, surum)"
    )
    op.execute(
        "ALTER TABLE kvkk_onay ADD CONSTRAINT uq_kvkk_onay "
        "UNIQUE (tenant_id, user_id, surum)"
    )
    op.execute("ALTER TABLE kvkk_metin DROP COLUMN IF EXISTS yeniden_onay_gerekir")
    for tablo in ("kvkk_metin", "kvkk_onay"):
        op.execute(f"ALTER TABLE {tablo} DROP COLUMN IF EXISTS tur")
    op.execute("DROP TYPE IF EXISTS kvkk_metin_tur")
