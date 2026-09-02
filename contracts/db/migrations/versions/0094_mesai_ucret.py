"""(P203 §5) FAZLA MESAI — saatlik ucret + mesai katsayisi.

===========================================================================
ONCE OLCUM: NE VAR, NE YOK
===========================================================================
VAR:
  * `personel_kayit.maas_kurus`  — AYLIK ucret (zaten duruyordu),
  * `personel_kayit.app_user_id` — vardiya planiyla bagi kuran alan,
  * `finansal_hareket.gerceklesme_durumu = 'onay_bekliyor'` — P167'de
    eklenmis ONAY KUYRUGU. §5'in "otomatik gider yazma, onaya dussun"
    sarti icin YENI BIR SEY GEREKMIYOR.

YOK:
  * SAATLIK ucret,
  * mesai KATSAYISI.

Bu goc yalnizca o ikisini ekler. AYRI BIR MESAI TABLOSU ACILMADI ve
bu P192'nin TEK DEFTER kuralinin geregi: mesai gideri de bir GIDERDIR
ve `finansal_hareket`e yazilir. Ikinci bir tablo, "bu ay ne kadar gider
yaptik" sorusunu iki yerden toplamak demekti.

===========================================================================
SAATLIK UCRET NEDEN NULLABLE
===========================================================================
Bos birakilirsa AYLIKTAN TURETILIR: `maas_kurus / 225`.

225 Turkiye'de aylik ucretten saatlik ucret cikarmanin standart
bolenidir (30 gun x 7,5 saat). Zorunlu kilmak, aylik ucreti zaten
girmis bir yoneticiye ayni bilgiyi ikinci kez sordurmakti; hic
sormamak ise farkli sozlesmeleri (saatlik calisan) imkansiz kilardi.

Geri alinabilir: `downgrade` iki sutunu da dusurur.
"""
from alembic import op
import sqlalchemy as sa

revision = "0094_mesai_ucret"
down_revision = "0093_vardiya_plani"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "personel_kayit",
        sa.Column("saatlik_ucret_kurus", sa.BigInteger(), nullable=True),
    )
    op.add_column(
        "tenant",
        sa.Column(
            "mesai_katsayisi",
            sa.Numeric(4, 2),
            nullable=False,
            # (4857/41) Fazla calisma ucreti normal saat ucretinin
            # YUZDE ELLI FAZLASIDIR. Varsayilan yasal orandir ama
            # DEGISTIRILEBILIR: toplu is sozlesmesi daha yuksek bir
            # oran belirleyebilir ve yazilim onu imkansiz kilmamali.
            server_default=sa.text("1.50"),
        ),
    )


def downgrade() -> None:
    op.drop_column("tenant", "mesai_katsayisi")
    op.drop_column("personel_kayit", "saatlik_ucret_kurus")
