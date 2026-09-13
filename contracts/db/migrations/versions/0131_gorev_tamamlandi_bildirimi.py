"""(P229 §3) Gorev TAMAMLANINCA yonetime bildirim.

===========================================================================
NEDEN AYRI BIR TIP, `gorev_atandi`I YENIDEN KULLANMAK DEGIL
===========================================================================
Iki olayin YONU ters: `gorev_atandi` yonetimden SAHAYA gider ("sana is
verildi"), `gorev_tamamlandi` sahadan YONETIME gelir ("is bitti"). Tek
tipe indirmek, bildirim listesinde ikisini ayirt edilemez yapardi ve
kullanicinin bildirim tercihlerinde ("gorev bildirimleri") birini kapatmak
otekini de kapatirdi.

===========================================================================
KIME GIDIYOR
===========================================================================
Gorevi OLUSTURANA degil, TESISIN YONETIMINE (admin + yonetici). Olusturan
kisi izinli/ayrilmis olabilir; o zaman "is bitti" haberini kimse almazdi.

`ADD VALUE IF NOT EXISTS`: gocun tekrar kosulmasi (kurtarma sirasinda
olur) hata vermemeli.
"""
from alembic import op

revision = "0131_gorev_tamamlandi_bildirimi"
down_revision = "0130_tesis_listesi_arama"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS "
        "'gorev_tamamlandi';"
    )


def downgrade() -> None:
    # PostgreSQL enum'dan DEGER SILEMEZ. Geri alma, tipi yeniden kurup
    # tum kolonlari tasimak demekti; o islem bu satiri eklemenin
    # tasidigindan cok daha buyuk bir risk. Deger kalir, kullanilmaz.
    pass
