"""(P168 §2) ICRA DOSYA DURUMU — brief'in BES degeri.

===========================================================================
NEDEN TIP DEGISIYOR, NEDEN "YENI DEGER EKLE" DEGIL
===========================================================================
Brief dosya durumu icin TAM OLARAK su bes degeri istiyor:

    Baginiz · Beklemede · Avukatta · Mahkeme Surecinde · Kapandi

Bugunku tip baska bir sozluk tasiyor: `acik`, `takipte`, `tahsil_edildi`,
`kapandi`. Yeni degerleri EKLEYIP eskileri birakmak en kolay yoldu ve
YANLIS olurdu: tabloda IKI SOZLUK birden yasardi, acilir liste bes deger
gosterirken veritabani dokuz deger kabul ederdi ve eski satirlar listede
karsiligi OLMAYAN bir durumla gorunurdu ("durum: takipte" ama secenekler
arasinda "Takipte" yok). Postgres enum'dan DEGER SILEMEZ; o yuzden tip
yeniden kuruluyor.

===========================================================================
ESKI -> YENI ESLEME (ve bir kaybin durustce beyani)
===========================================================================
    acik           -> beklemede    (dosya acilmis, henuz islem yok)
    takipte        -> avukatta     (icra takibi avukat eliyle yurur)
    tahsil_edildi  -> kapandi
    kapandi        -> kapandi

SON ESLEMEDE BIR AYRIM KAYBOLUYOR: "tahsil edildi" ile "kapandi" ayni
degere dusuyor, yani dosyanin NEDEN kapandigi durum alanindan artik
okunamiyor. Bunu gizlemek yerine yaziyorum. Alternatifleri tarttim:

  * Altinci bir deger (`tahsil_edildi`) birakmak — brief'in "tam olarak
    su bes deger" kismini ihlal ederdi.
  * `aciklama` metnine not dusmek — kullanicinin yazdigi metni gocun
    degistirmesi, kaybettiginden daha kotu bir seydir.

Kaybolan sey SATIR degil, tek bir AYRIMDIR; tahsilatin kendisi
`dues_payment` defterinde durur ve oradan okunabilir. Dev veritabaninda
etkilenen satir sayisi SIFIR olcuLdu; test sunucusunda varsa yukaridaki
esleme uygulanir.
"""
from alembic import op

revision = "0062_icra_durum_yeniden"
down_revision = "0061_dokuman_sakine_acik"
branch_labels = None
depends_on = None

YENI = "('baginiz','beklemede','avukatta','mahkemede','kapandi')"

ESLEME = {
    "acik": "beklemede",
    "takipte": "avukatta",
    "tahsil_edildi": "kapandi",
    "kapandi": "kapandi",
}

# Geri alirken: yeni degerlerin eski sozlukteki en yakin karsiligi.
# `baginiz` ve `mahkemede`nin eski sozlukte karsiligi YOK — ikisi de
# "takipte"ye duser, cunku eski sozluk bu ayrimlari hic tasimiyordu.
TERS = {
    "baginiz": "takipte",
    "beklemede": "acik",
    "avukatta": "takipte",
    "mahkemede": "takipte",
    "kapandi": "kapandi",
}


def _degistir(tip_adi: str, degerler: str, esleme: dict[str, str], varsayilan: str) -> None:
    """Enum tipini yeniden kurar ve satirlari esleyerek tasir.

    VARSAYILAN ONCE DUSURULUR: sutunun `DEFAULT`u eski tipe baglidir ve
    tip degisirken birakilirsa `ALTER` patlar.
    """
    op.execute("ALTER TABLE icra_dosyasi ALTER COLUMN durum DROP DEFAULT")
    op.execute(f"CREATE TYPE {tip_adi}_yeni AS ENUM {degerler}")
    dal = " ".join(
        f"WHEN '{eski}' THEN '{yeni}'" for eski, yeni in esleme.items()
    )
    op.execute(
        f"""
        ALTER TABLE icra_dosyasi
          ALTER COLUMN durum TYPE {tip_adi}_yeni
          USING (CASE durum::text {dal} ELSE '{varsayilan}' END)::{tip_adi}_yeni
        """
    )
    op.execute(f"DROP TYPE {tip_adi}")
    op.execute(f"ALTER TYPE {tip_adi}_yeni RENAME TO {tip_adi}")
    op.execute(
        f"ALTER TABLE icra_dosyasi ALTER COLUMN durum SET DEFAULT '{varsayilan}'"
    )


def upgrade() -> None:
    _degistir("icra_durum", YENI, ESLEME, "beklemede")


def downgrade() -> None:
    _degistir(
        "icra_durum",
        "('acik','takipte','tahsil_edildi','kapandi')",
        TERS,
        "acik",
    )
