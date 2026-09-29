"""(P249 §1) SOS ALICI DENEYIMI — yanit ("guvendeyim"/"yardim") + kritik uyari.

===========================================================================
`panik_alici.yanit` — TOPLU UYARIDA SAYIM
===========================================================================
Deprem, yangin, gaz ve tahliyede kimse "yardim" istemiyor; herkese NE
YAPACAGI soyleniyor. Yoneticinin o anda bilmesi gereken sey kimin guvende
oldugu, kimin yardim istedigi ve kimin HIC YANIT VERMEDIGIDIR (tahliyede
sayim). `goruldu_at` bunu tasiyamaz: "gordum" ile "guvendeyim" ayni sey
degil.

  * NULL      — yanit yok (sayimin asil sorusu),
  * guvende   — "Guvendeyim",
  * yardim    — "Yardima ihtiyacim var" (guvenlige ayrica push gider).

CHECK ile, enum ile degil: iki degerli bir kume icin yeni bir tip,
geri alinmasi (enum degeri DUSURULEMEZ) zor bir sema degisikligi olurdu.

===========================================================================
`user_device.kritik_uyari` — iOS Critical Alerts
===========================================================================
Critical Alerts Apple onayina bagli bir YETKIDIR. Uygulama, cihazda bu
iznin ACIK oldugunu bildirim ayarlarindan okuyup kayitta gonderir; sunucu
kritik ses yukunu YALNIZ bu cihazlara yollar. Boylece onay geldiginde
degisecek tek yer uygulamanin yetki dosyasidir (docs/P249-kararlar.md
§1c) — sunucu ve Dart kodu bugunden hazirdir.

===========================================================================
`notification_tip` += `panik_yardim_talebi`
===========================================================================
Toplu uyarida "yardima ihtiyacim var" diyen sakin, guvenlik ve yonetime
KENDI BILDIRIMIYLE duyurulur: kime gidilecegini soyleyen bir yardim
cagrisidir ve alarm kanalindan gider.
"""
from alembic import op

revision = "0157_p249_sos_alici"
down_revision = "0156_p248_ad_sinirlari"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE panik_alici "
        "ADD COLUMN yanit text, "
        "ADD COLUMN yanit_at timestamptz, "
        "ADD CONSTRAINT ck_panik_alici_yanit "
        "CHECK (yanit IS NULL OR yanit IN ('guvende', 'yardim'));"
    )
    op.execute(
        "ALTER TABLE user_device "
        "ADD COLUMN kritik_uyari boolean NOT NULL DEFAULT false;"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'panik_yardim_talebi';"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE user_device DROP COLUMN IF EXISTS kritik_uyari;")
    op.execute(
        "ALTER TABLE panik_alici DROP CONSTRAINT IF EXISTS ck_panik_alici_yanit, "
        "DROP COLUMN IF EXISTS yanit_at, DROP COLUMN IF EXISTS yanit;"
    )
    # notification_tip degeri GERI ALINMAZ (PostgreSQL enum degeri
    # dusurulemez) — 0140'taki notun aynisi.
