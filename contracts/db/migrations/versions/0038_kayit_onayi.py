"""(P148.2) Sakin kaydi YONETICI ONAYINDAN gecer — hesap onaydan SONRA acilir.

NEDEN: P148.1 kodu akilda kalici yapti (adin ilk 4 harfi + tarih) ve bununla
birlikte TAHMIN EDILEBILIR oldu. Daire sahipligi dogrulamasi kapaliyken kod
tek denetimdi; site adini bilen herkes herhangi bir daireye kaydolabilirdi.
Kerem onay adimini acmayi secti: akilda kalicilik KORUNUR, acik KAPANIR.

AKIS DEGISTI: telefon kodu dogrulaninca kullanici ARTIK ACILMIYOR. Basvuru
`onay_bekliyor` durumunda BEKLER ve hicbir veriye erisimi yoktur; yonetici
onaylayinca `app_user` + `unit_resident` yazilir.

`kayit_dogrulama` bir "bekleyen kayit" tablosuydu, artik BASVURU tablosu:
dogrulama sonrasi SILINMIYOR, durum tasiyor.
"""
from alembic import op
import sqlalchemy as sa

revision = "0038_kayit_onayi"
down_revision = "0037_akilda_kalir_tesis_kodu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TYPE kayit_durum AS ENUM "
        "('telefon_bekliyor', 'onay_bekliyor', 'onaylandi', 'reddedildi');"
    )
    op.add_column("kayit_dogrulama", sa.Column("ad", sa.Text(), nullable=True))
    op.add_column(
        "kayit_dogrulama",
        sa.Column(
            "durum",
            sa.Enum(name="kayit_durum", create_type=False),
            nullable=False,
            server_default=sa.text("'telefon_bekliyor'"),
        ),
    )
    op.add_column(
        "kayit_dogrulama",
        sa.Column("karar_at", sa.TIMESTAMP(timezone=True), nullable=True),
    )
    # Onaylanan basvuru hangi kullaniciyi actigini TASIR: onay iki kez
    # islenirse ikinci kullanici acilmasin (idempotens) ve iz kalsin.
    op.add_column(
        "kayit_dogrulama",
        sa.Column("user_id", sa.dialects.postgresql.UUID(as_uuid=True), nullable=True),
    )
    # Telefon basina TEK basvuru kurali KALKAR: reddedilen bir basvurudan
    # sonra ayni numara yeniden basvurabilmeli. Yerine "ayni telefon icin
    # ACIK basvuru tek" kismi indeksi gelir.
    op.drop_constraint("uq_kayit_dogrulama_telefon", "kayit_dogrulama", type_="unique")
    op.execute(
        """
        CREATE UNIQUE INDEX uq_kayit_acik_basvuru
            ON kayit_dogrulama (telefon)
            WHERE durum IN ('telefon_bekliyor', 'onay_bekliyor');
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_kayit_acik_basvuru;")
    op.create_unique_constraint(
        "uq_kayit_dogrulama_telefon", "kayit_dogrulama", ["telefon"]
    )
    for sutun in ("user_id", "karar_at", "durum", "ad"):
        op.drop_column("kayit_dogrulama", sutun)
    op.execute("DROP TYPE IF EXISTS kayit_durum;")
