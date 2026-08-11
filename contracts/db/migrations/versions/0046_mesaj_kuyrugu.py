"""(P154 / Asama 9) MESAJ KUYRUGU — yeniden deneme defteri.

===========================================================================
NEDEN YENI TABLO DEGIL, IKI SUTUN
===========================================================================
Brief: "Gonderim kaydi: kime, ne zaman, hangi sablon, durum, hata. Kuyruk
+ yeniden deneme."

`mesaj_gonderim` ZATEN kuyrugun tasiyabilecegi her seyi tutuyor: alici,
kanal, govde, durum (`kuyrukta` degeri enum'da MEVCUT) ve hata. Ayri bir
kuyruk tablosu acmak, ayni satiri iki yerde tutmak ve "gonderim gecmisi"
ile "kuyruk" arasinda hangisinin dogru oldugu sorusunu uretmek olurdu.

Eksik olan tek sey ZAMANLAMA defteriydi:
  * `deneme`        — kacinci deneme (geri cekilme bunun ussu),
  * `son_deneme_at` — en son ne zaman denendi.

===========================================================================
GECMIS SATIRLAR NEDEN 0 ILE BASLAR
===========================================================================
`deneme` varsayilani 0'dir ve bu, tabloda duran ESKI `basarisiz`
satirlarini kuyruga SOKMAZ: kuyruk yalnizca `durum='kuyrukta'` satirlari
okur. Yani goc, gecmiste basarisiz olmus bir gonderimi kendiliginden
yeniden denemez — kullanicinin haberi olmadan aylar once vazgecilmis bir
SMS'i gondermek, en hafif tabirle surpriz olurdu.
"""
from alembic import op
import sqlalchemy as sa

revision = "0046_mesaj_kuyrugu"
down_revision = "0045_ice_aktarim"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "mesaj_gonderim",
        sa.Column(
            "deneme", sa.Integer(), nullable=False, server_default=sa.text("0")
        ),
    )
    op.add_column(
        "mesaj_gonderim",
        sa.Column("son_deneme_at", sa.DateTime(timezone=True), nullable=True),
    )
    # KUYRUK TARAMASI INDEKSI: her tur "vadesi gelmis kuyrukta satir" diye
    # bakar. Onsuz her tarama tam tablo taramasi olurdu ve tablo
    # gecmisi de tasidigi icin surekli buyur.
    op.create_index(
        "ix_mesaj_gonderim_kuyruk",
        "mesaj_gonderim",
        ["tenant_id", "durum", "son_deneme_at"],
        postgresql_where=sa.text("durum = 'kuyrukta'"),
    )


def downgrade() -> None:
    op.drop_index("ix_mesaj_gonderim_kuyruk", table_name="mesaj_gonderim")
    op.drop_column("mesaj_gonderim", "son_deneme_at")
    op.drop_column("mesaj_gonderim", "deneme")
