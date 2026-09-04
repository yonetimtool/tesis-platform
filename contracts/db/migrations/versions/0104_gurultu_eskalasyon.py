"""(P212 §3) GURULTU ESKALASYONU — ikinci esikte GUVENLIGE bildirim.

===========================================================================
ISTENEN AKIS
===========================================================================
Birinci esik (P208, DEGISMEDI): 5 gurultu sikayeti -> sakine SESLI uyari,
sayac sifirlanir.

Ikinci esik (YENI): ayni daire icin sikayet TEKRAR 5'e ulasirsa ->
GUVENLIGE bildirim: daire + "ikinci kez 5 gurultu sikayeti" + "polise
haber veriniz". Sistem KIMSEYI ARAMAZ; arama karari ve eylemi guvenlik
gorevlisinindir.

===========================================================================
VERI MODELI: NEDEN YENI TABLO DEGIL, NEDEN YINE DE BIR SUTUN
===========================================================================
"Bu daire icin esik kac kez asildi" sorusu ZATEN turetilebilir:
`unit_uyari` tablosunda o daireye ait satir sayisi. Bu yuzden yeni bir
"sayac tablosu" ACILMADI — ayni gercegi iki yerde tutmak, ikisinin
gunun birinde ayrismasi demekti.

Yine de `asama` sutunu EKLENIYOR ve o anki degeriyle DAMGALANIYOR;
gerekcesi `esik`/`sayac`/`metin` sutunlariyla birebir ayni (bkz. model
belgesi): pencere ayari (`gurultu_pencere_gun`) sonradan degisirse
GECMIS bir uyarinin kacinci asama oldugu yeniden hesaplandiginda BASKA
cikar. Damga, "o gun ne yapildi" sorusunun yanitini sabitler.

`asama = 1` VARSAYILANI gecmis satirlar icin dogrudur: eskalasyon
bugune kadar yoktu, hepsi birinci asamaydi.

GERI ALINABILIR: `downgrade` sutunu dusurur (IF EXISTS) ve enum
degerlerini BIRAKIR — Postgres'te `DROP VALUE` yoktur; fazladan bir enum
degeri hicbir seyi bozmaz, veri kaybi bozar (goc 0102/0103 ile ayni
karar).
"""
from alembic import op
import sqlalchemy as sa

revision = "0104_gurultu_eskalasyon"
down_revision = "0103_gurultu_uyari_sakin"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "unit_uyari",
        sa.Column("asama", sa.Integer(), nullable=False,
                  server_default=sa.text("1")),
    )
    op.execute(
        "ALTER TABLE unit_uyari ADD CONSTRAINT ck_unit_uyari_asama "
        "CHECK (asama >= 1);"
    )
    # GUVENLIGE giden eskalasyon ve YONETIME giden bilgi AYRI TIPLER:
    # tek tipe indirmek, bildirim listesinde "polise haber ver" ile
    # "haberin olsun"u ayirt edilemez yapardi.
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS "
        "'gurultu_eskalasyon_guvenlik';"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS "
        "'gurultu_eskalasyon_yonetim';"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE unit_uyari DROP CONSTRAINT IF EXISTS ck_unit_uyari_asama;"
    )
    op.execute("ALTER TABLE unit_uyari DROP COLUMN IF EXISTS asama;")
