"""(P149) Telefon kodu UC AMACA hizmet eder: kayit, giris, hesap silme.

NEDEN AYRI BIR TABLO DEGIL: `kayit_dogrulama` zaten dogru guvenlik
ozelliklerini tasiyor — kod DUZ METIN tutulmaz (hash), sure sinirli, deneme
sayaci var ve o sayacin ayri oturumda kalicilastirilmasi gerektigi ACI BIR
DERSLE ogrenildi (P148'de koruma hic calismiyordu). Ayni mekanizmayi ikinci
kez kurmak, o dersi ikinci kez ogrenme riski demekti.

`amac` sutunu satirin NE ICIN uretildigini soyler ve dogrulama yollari
BIRBIRININ KODUNU KABUL ETMEZ: giris icin uretilmis bir kod hesap silmeyi
onaylayamaz. Bu, "tek kod her kapiyi acar" hatasini yapisal olarak engeller.

Tablo adi `kayit_dogrulama` KALIYOR: yeniden adlandirmak calisan gocleri ve
kodu genis bir yuzeyde kirardi; anlamini yorum tasiyor.
"""
from alembic import op
import sqlalchemy as sa

revision = "0039_telefon_kodu_amaci"
down_revision = "0038_kayit_onayi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TYPE kod_amaci AS ENUM ('kayit', 'giris', 'hesap_silme');"
    )
    op.add_column(
        "kayit_dogrulama",
        sa.Column(
            "amac",
            sa.Enum(name="kod_amaci", create_type=False),
            nullable=False,
            server_default=sa.text("'kayit'"),
        ),
    )
    # `unit_id` artik YALNIZ kayit amacinda anlamli: giris/silme kodunun
    # dairesi yoktur.
    op.alter_column("kayit_dogrulama", "unit_id", nullable=True)

    # ACIK BASVURU TEKILLIGI AMACA GORE: ayni telefon ayni anda hem giris
    # kodu hem silme kodu isteyebilmeli — eski indeks bunu engellerdi.
    op.execute("DROP INDEX IF EXISTS uq_kayit_acik_basvuru;")
    op.execute(
        """
        CREATE UNIQUE INDEX uq_kayit_acik_basvuru
            ON kayit_dogrulama (telefon, amac)
            WHERE durum IN ('telefon_bekliyor', 'onay_bekliyor');
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_kayit_acik_basvuru;")
    op.execute(
        """
        CREATE UNIQUE INDEX uq_kayit_acik_basvuru
            ON kayit_dogrulama (telefon)
            WHERE durum IN ('telefon_bekliyor', 'onay_bekliyor');
        """
    )
    op.drop_column("kayit_dogrulama", "amac")
    op.execute("DROP TYPE IF EXISTS kod_amaci;")
