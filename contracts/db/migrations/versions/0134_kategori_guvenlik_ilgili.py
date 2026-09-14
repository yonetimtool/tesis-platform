"""(P231 §3) Gorev/talep kategorisi GUVENLIGI ILGILENDIRIR mi.

===========================================================================
NEDEN YENI BIR ALAN GEREKTI
===========================================================================
Amirin "yalniz guvenlikle ilgili sikayetleri gormesi" istendi. Olctum:
sikayet kategorileri `task_category` tablosundan geliyor ve bunlar
YONETICI-TANIMLI SERBEST METIN ("Tesisat", "Bahce"...). Yani "hangi
kategori guvenligi ilgilendirir" bilgisi sistemde HICBIR YERDE YOK.

Uc secenek vardi:
  1. Kategori ADINA gore tahmin ("guvenlik" gecenler) — KIRILGAN: tesis
     "Asayis" yazarsa calismaz, "Guvenlik Kapisi Tamiri" yazarsa yanlis
     calisir. Ustelik yedi dilde.
  2. Amire TUM sikayetleri vermek — istegin acik sartina aykiri.
  3. KATEGORIYE ACIK BIR BAYRAK — secilen bu.

Bayragi YONETICI koyar: hangi sikayetin guvenligi ilgilendirdigine
tesisin kendisi karar verir. Varsayilan FALSE (fail-closed): yeni bir
kategori acan yonetici, farkinda olmadan amire yeni bir veri kumesi
ACMAZ.

KATEGORISIZ SIKAYET AMIRE GORUNMEZ: ilgisi KURULAMAZ bir kaydi
"ilgilendiriyor olabilir" diye gostermek, en az yetki ilkesinin tersi
olurdu.
"""
from alembic import op
import sqlalchemy as sa

revision = "0134_kategori_guvenlik_ilgili"
down_revision = "0133_gorev_takibi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "task_category",
        sa.Column(
            "guvenlik_ilgili",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("task_category", "guvenlik_ilgili")
