"""(P230 §4) Gorev TAKIBI — son tarih, baslama, atayan.

===========================================================================
OLCULEN DURUM
===========================================================================
`task` tablosunda takip icin gereken UC alan da yoktu:

  * DURUM alani YOK. P229'da tamamlama eklendi ("tamamlandi mi" artik
    `task_completion` varligindan turuyor) ama "baslandi mi" ve "gecikti
    mi" sorulari YANITLANAMIYORDU.
  * SON TARIH YOK -> gecikme HESAPLANAMIYORDU. `sonraki_planlanan` yalniz
    PERIYODIK gorevlerde dolu ve anlami farkli ("bir sonraki tekrar").
  * ATAYAN YOK. `atanan_user_id` kime atandigini soyluyor, KIMIN atadigini
    soylemiyor — "bu isi bana kim verdi" sorusunun yaniti hicbir yerde
    yoktu.

===========================================================================
NEDEN DURUM KOLONU DEGIL, TURETILMIS DURUM
===========================================================================
Dort durumun UCU zaten baska verilerden TURUYOR:

  atandi     : kayit var, baslama yok, tamamlama yok
  baslandi   : `baslama_zamani` dolu, tamamlama yok
  tamamlandi : `task_completion` satiri var (P229)
  gecikti    : `son_tarih` gecmis ve tamamlama yok

Ayri bir `durum` kolonu, bu uc kaynakla SENKRON TUTULMAK zorunda olurdu:
tamamlama silinince (P229 geri acma) durumu geri almayi unutan bir kod
yolu, gorevi "tamamlandi" gorunur birakirdi. Turetilmis durum boyle bir
ayrisma uretemez.

`baslama_zamani` TEK YENI GERCEKTIR: baska hicbir yerden turetilemez.
"""
from alembic import op
import sqlalchemy as sa

revision = "0133_gorev_takibi"
down_revision = "0132_kamera_alt_akis"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "task",
        sa.Column("son_tarih", sa.TIMESTAMP(timezone=True), nullable=True),
    )
    op.add_column(
        "task",
        sa.Column("baslama_zamani", sa.TIMESTAMP(timezone=True), nullable=True),
    )
    # KIM ATADI. FK YOK ve bilincli: atayan yonetici hesabi silinse/
    # anonimlestirilse de gorevin gecmisi kalmali (`audit_log.actor_user_id`
    # ile ayni gerekce). RESTRICT koysaydik, gorevi olan bir yoneticinin
    # hesabini silmek imkansizlasirdi.
    op.add_column(
        "task",
        sa.Column("olusturan_user_id", sa.dialects.postgresql.UUID(as_uuid=True), nullable=True),
    )
    # GECIKMIS GOREV SORGUSU: `son_tarih` uzerinden suzuluyor ve liste
    # ucunda sayfalaniyor. Kismi indeks: tamamlanmamis + son tarihi olan
    # satirlar kucuk bir alt kume.
    op.create_index(
        "ix_task_son_tarih",
        "task",
        ["tenant_id", "son_tarih"],
        postgresql_where=sa.text("son_tarih IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_task_son_tarih", table_name="task")
    op.drop_column("task", "olusturan_user_id")
    op.drop_column("task", "baslama_zamani")
    op.drop_column("task", "son_tarih")
