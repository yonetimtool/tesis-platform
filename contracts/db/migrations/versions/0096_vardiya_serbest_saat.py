"""(P205 §2) VARDIYA PLANINA KENDI SAATLERI — serbest (sablonsuz) vardiya.

===========================================================================
NEDEN
===========================================================================
P203 §4'te plan satiri saatlerini DAIMA `shift` sablonundan aliyordu.
§2'nin "Hizli Vardiya Ekle" penceresi ise BASLANGIC ve BITIS SAATI
soruyor: yonetici 22:00-05:00 diye bir vardiyayi, once bir sablon
tanimlamak zorunda kalmadan yazabilmeli. Sahada olculen ihtiyac bu —
"bu hafta Ali 14:00-22:00 kalsin" demek icin kalici bir vardiya tanimi
uretmek, tanim listesini bir kerelik kayitlarla sisirirdi.

===========================================================================
IKISI DE DURUYOR — SABLON KALDIRILMADI
===========================================================================
`shift_id` NULLABLE oldu, YOK OLMADI. Sablon hâlâ VARSAYILAN KADRONUN
ve `haftayi-doldur` tohumlamasinin dayanagidir; kaldirmak, yirmi kisilik
bir ekipte her hafta yuzlerce tiklama demekti.

Kural (CHECK): satir ya bir SABLONA baglidir ya da KENDI SAATLERINI
tasir. Ikisinin de bos oldugu bir satir, saati OLMAYAN bir vardiyadir —
cakisma ve mesai hesabi onu sessizce 0 saat sayardi.

Sablonlu satirda da saatler DOLDURULABILIR: o gunluk sapma
("bugun 1 saat erken cikiyor") sablonu degistirmeden yazilir. Okuma
kurali TEK YERDE: `app/vardiya.py::plan_araligi`.
"""
from alembic import op
import sqlalchemy as sa

revision = "0096_vardiya_serbest_saat"
down_revision = "0095_kimlik_uyelikleri"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("vardiya_plani", "shift_id", existing_type=sa.dialects.postgresql.UUID(), nullable=True)
    op.add_column(
        "vardiya_plani",
        sa.Column("baslangic_saat", sa.Time(), nullable=True),
    )
    op.add_column(
        "vardiya_plani", sa.Column("bitis_saat", sa.Time(), nullable=True)
    )
    op.create_check_constraint(
        "ck_vardiya_plani_saat_kaynagi",
        "vardiya_plani",
        "shift_id IS NOT NULL "
        "OR (baslangic_saat IS NOT NULL AND bitis_saat IS NOT NULL)",
    )


def downgrade() -> None:
    # GERI DONUS VERI KAYBEDER ve bu ACIKCA yaziliyor: sablonsuz
    # satirlarin saati baska hicbir yerde durmuyor. Once onlar silinir,
    # yoksa `shift_id` NOT NULL'a donerken kisit hatasi verir.
    op.execute("DELETE FROM vardiya_plani WHERE shift_id IS NULL;")
    op.drop_constraint("ck_vardiya_plani_saat_kaynagi", "vardiya_plani")
    op.drop_column("vardiya_plani", "bitis_saat")
    op.drop_column("vardiya_plani", "baslangic_saat")
    op.alter_column("vardiya_plani", "shift_id", existing_type=sa.dialects.postgresql.UUID(), nullable=False)
