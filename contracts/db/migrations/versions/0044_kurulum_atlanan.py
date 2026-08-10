"""(P154 / Asama 7.3) KURULUM SIHIRBAZI — atlanan adimlar.

===========================================================================
NEDEN YALNIZCA "ATLANAN" SAKLANIYOR — "tamamlanan" DEGIL
===========================================================================
Brief sekiz adimlik bir kurulum sihirbazi istiyor ve sartlari arasinda
"tamamlananlarin KALICI isaretlenmesi" var.

Tamamlanma bir BAYRAK OLARAK TUTULMADI: her adimin ciktisi zaten
veritabaninda duruyor (blok satiri, daire satiri, daire tipi, sakin,
personel, gorev kategorisi, NFC noktasi, aidat tahakkuku). Ayrica bayrak
tutmak, ayni gercegin IKINCI bir kaynagini uretirdi ve ikisi ayrisirdi:
yonetici tek blogunu silince bayrak "tamamlandi" demeye devam ederdi.
Bu yuzden tamamlanma HER ISTEKTE VERIDEN SAYILIR.

ATLAMA ise veriden turetilemez. "Bu sitede NFC noktasi YOK" ile "henuz
eklemedim" verisel olarak AYNIDIR (ikisi de sifir satir) ama kullanici
icin ayni degil: biri bilincli bir karar, oteki yarim kalmis bir is.
Atlanan adim listesi bu karari tasir — ve YALNIZ bu.

===========================================================================
NEDEN TENANT SUTUNU, NEDEN CIHAZDA DEGIL
===========================================================================
Karar TESISE aittir, kullaniciya degil: bir tesiste iki yonetici olabilir
(P154 / Asama 1) ve biri "NFC yok" dediyse oteki de bunu gormeli. Tarayici
depolamasi bu yuzden yanlis yer olurdu — ayni yonetici baska bir
bilgisayarda sihirbazi yarim gorurdu.

AYRI TABLO ACILMADI: bu, tesise ait tek degerli bir tercih; satir
kimligi, zaman damgasi ya da iliski gerektirmiyor. Tablo acmak sekiz
satirlik bir listeyi yonetmek icin bir JOIN daha demekti.

DIZI DEGIL JSONB: Postgres dizisi de olurdu, ama tenant tablosunda zaten
JSONB kullanan alanlar var ve okuma/yazma yolu (SQLAlchemy `JSONB`) tek
desende kalsin. Icerik SABIT KUME olan adim kodlaridir; dogrulama UCTA
yapilir (bkz. routers/kurulum.py) cunku kod kumesi uygulama bilgisidir ve
yeni bir adim eklemek GOC gerektirmemeli.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision = "0044_kurulum_atlanan"
down_revision = "0043_varlik_eki"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tenant",
        sa.Column(
            "kurulum_atlanan",
            JSONB,
            nullable=False,
            # BOS DIZI, NULL DEGIL: "hicbir adim atlanmadi" ile "bilgi yok"
            # ayni sey degil ve uc tarafinda `null` kontrolu yazmak, her
            # okuma yerinde tekrarlanacak bir kosul olurdu.
            server_default=sa.text("'[]'::jsonb"),
        ),
    )


def downgrade() -> None:
    op.drop_column("tenant", "kurulum_atlanan")
