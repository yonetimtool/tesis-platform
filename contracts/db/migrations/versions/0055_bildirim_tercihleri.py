"""(P167 §1.7) Kisi basina BILDIRIM KANALI tercihleri — e-posta / SMS / mobil.

===========================================================================
NEDEN PAZARLAMA IZINLERININ YANINA YENI UC KOLON
===========================================================================
`app_user`da ZATEN `pazarlama_eposta / pazarlama_sms / pazarlama_arama`
var (0036). Ilk bakista "ayni sey" gorunuyor ve tek kume ile idare
edilebilirmis gibi duruyor. EDILEMEZ, cunku ikisi HUKUKEN ve ISLEVSEL
olarak farkli:

* PAZARLAMA bir RIZADIR. KVKK md. 5/1: acik riza. Varsayilani KAPALI
  olmak ZORUNDA, her an geri alinabilir ve geri alinmasi gonderimi
  tamamen durdurur.
* BILDIRIM bir TERCIHTIR. "Aidat borcunuz olustu", "gorev size atandi",
  "ziyaretciniz kapida" — bunlar sozlesme iliskisinin isleyisidir, riza
  gerektirmez. Varsayilani ACIK olmali; kullanici GURULTU azaltmak icin
  kapatir.

Ikisini tek bayrakta birlestirmek, pazarlamayi kapatan kullanicinin
aidat bildirimini de kaybetmesi demekti — ya da tersi, pazarlama
gonderimini bir tercihe indirip KVKK ihlali. Bu yuzden AYRI kolonlar.

===========================================================================
KOLONLAR
===========================================================================
`bildirim_eposta`, `bildirim_sms`, `bildirim_mobil` — hepsi
`NOT NULL DEFAULT true`.

UCU AYRI, tek bir "bildirim" bayragi DEGIL: telefonu uygulamada acik
duran kullanici SMS istemez (ayni bilgiyi iki kez alir ve SMS ucretlidir);
uygulamayi kurmamis olan ise yalniz e-postayla ulasilabilir. Tek bayrak
bu kisiyi "hepsi ya da hicbiri"ne zorlardi.

`arama` KANALI BURADA YOK ve olmamali: telefonla aranmak `aranabilir`
kolonuyla ZATEN yonetiliyor (C1a riza kapisi) ve orasi bir numara
ACIKLAMA karari — bir bildirim kanali degil. Ikizini acmak, ayni sorunun
iki yerde farkli cevabi olmasi demekti.
"""
from alembic import op

revision = "0055_bildirim_tercihleri"
down_revision = "0054_rezervasyon_gecmis_saklama"
branch_labels = None
depends_on = None

_KOLONLAR = ("bildirim_eposta", "bildirim_sms", "bildirim_mobil")


def upgrade() -> None:
    for kolon in _KOLONLAR:
        op.execute(
            f"""
            ALTER TABLE app_user
              ADD COLUMN {kolon} boolean NOT NULL DEFAULT true
            """
        )


def downgrade() -> None:
    # TERSINIR ve veri kaybi ANLAMLI DEGIL: kolonlar dustugunde herkes
    # varsayilana (hepsi acik) doner — yani kimse bir bildirimi KACIRMAZ,
    # yalnizca kapatma tercihi unutulur. Ters yonde (kapaliyken kolonun
    # kaybi) bir bildirim SIZINTISI olmaz, gurultu olur.
    for kolon in _KOLONLAR:
        op.execute(f"ALTER TABLE app_user DROP COLUMN IF EXISTS {kolon}")
