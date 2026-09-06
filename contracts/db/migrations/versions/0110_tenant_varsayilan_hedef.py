"""(P218) TESIS BAZINDA VARSAYILAN BORC HEDEFI.

===========================================================================
NEDEN
===========================================================================
Uygulamada siteler farkli davraniyor: bazilari HER SEYI malige yaziyor,
bazilari KMK md. 20 ayrimini uyguluyor, bazilari kira sozlesmesine
bakiyor. Urun bunlardan birini dayatamaz.

Bu ayar YENI acilan gelir/gider tanimlarinin varsayilanini belirler.

===========================================================================
NEDEN ZORLAYICI DEGIL, YALNIZCA VARSAYILAN
===========================================================================
Tenant duzeyinde "her seyi malige yaz" diye bir KILIT koysaydik, o
siteye bir gun su faturasini kiraciya yazmak gerektiginde ayar TUM
turleri birden etkilerdi. Varsayilan yeni tanim dogarken uygulanir;
sonrasinda tur bazinda degistirilebilir (`gelir_gider_tanim.
hedef_kurali`).

MEVCUT TANIMLARA DOKUNULMAZ: bu goc yalnizca yeni tanimlarin
baslangic degerini etkiler; calisan bir sitenin gecmis kurulumunu
degistirmek, kimsenin istemedigi bir davranis degisimi olurdu.

GERI ALINABILIR: `downgrade` sutunu dusurur, varsayilan yine
`kiraci_oncelikli` olur (enum'un kendi varsayilani).
"""
from alembic import op
import sqlalchemy as sa

revision = "0110_tenant_varsayilan_hedef"
down_revision = "0109_sakin_oturuyor"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tenant",
        sa.Column(
            "varsayilan_hedef_kurali",
            # Enum ZATEN VAR (`borc_hedef_kurali`, goc 0028); yeniden
            # yaratmiyoruz — ayni kavramin ikinci bir tipi olsaydi ikisi
            # zamanla ayrisirdi.
            sa.Enum("kiraci_oncelikli", "malik", name="borc_hedef_kurali",
                    create_type=False),
            nullable=False,
            server_default=sa.text("'kiraci_oncelikli'"),
        ),
    )


def downgrade() -> None:
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS varsayilan_hedef_kurali;")
