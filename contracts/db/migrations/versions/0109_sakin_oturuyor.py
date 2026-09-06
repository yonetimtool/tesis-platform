"""(P218) SAKIN BAGINA `oturuyor` — MULKIYET ile KULLANIM AYRILIYOR.

===========================================================================
NEDEN
===========================================================================
Kat Mulkiyeti Kanunu md. 20 gider sorumlulugunu IKI AYRI gercege
baglar:
  * isletme giderleri (kapici, elektrik, su, asansor isletme, temizlik)
    -> KULLANAN oder,
  * anayapinin bakim / onarim / guclendirme giderleri -> MALIK oder.

Model bugune kadar yalnizca `rol_tipi` (malik|kiraci) tasiyordu ve UC
DURUMDAN BIRINI TEMSIL EDEMIYORDU:
  1. Malik, dairede oturmuyor (kiraya vermis)      -> temsil edilebiliyor
  2. Kiraci, dairede oturuyor                       -> temsil edilebiliyor
  3. MALIK, DAIREDE OTURUYOR                        -> EDILEMIYOR

Ucuncusu olculdu: ayni kisi ayni daireye ikinci bir rolle baglanamiyor
(`409 Bu kullanici daireye zaten aktif olarak bagli`). Yonetici ya
`malik` yaziyor (oturdugu bilgisi kayboluyor) ya `kiraci` (yanlis).

===========================================================================
NEDEN `rol_tipi`YE UCUNCU DEGER DEGIL
===========================================================================
`malik_oturan` diye bir enum degeri eklemek, "malikler" sorgusunu iki
degeri birden aramak zorunda birakirdi ve bunu BIR YERDE unutmak sessiz
bir hata olurdu. Mulkiyet ve kullanim ayri iki gercek; ayri iki alanda
durmalari dogru.

===========================================================================
MEVCUT VERI
===========================================================================
`kiraci` olan baglar `true` isaretlenir (kiraci tanimi geregi oturur);
malik ve rolsuz baglar `false` kalir. Bu, BUGUNKU DAVRANISI BIREBIR
KORUR: `hedef_sec`in "kullanan" kurali bugun de kiraciyi seciyor.

GERI ALINABILIR: `downgrade` sutunu dusurur; hedefleme eski (kiraci
oncelikli) davranisina doner.
"""
from alembic import op
import sqlalchemy as sa

revision = "0109_sakin_oturuyor"
down_revision = "0108_kamera_gecmis_kayit"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "unit_resident",
        sa.Column("oturuyor", sa.Boolean(), nullable=False,
                  server_default=sa.text("false")),
    )
    # Kiraci = oturan. Malik ve rolsuz baglar DOKUNULMADAN false kalir:
    # "oturuyor mu" bilgisi onlar icin BILINMIYOR ve varsaymak, bakim
    # giderini yanlis kisiye yazdirabilirdi.
    op.execute("UPDATE unit_resident SET oturuyor = true WHERE rol_tipi = 'kiraci';")


def downgrade() -> None:
    op.execute("ALTER TABLE unit_resident DROP COLUMN IF EXISTS oturuyor;")
