"""(P243 §5c) PANIK KATEGORISI — deprem, yangin, gaz, tahliye, saglik...

===========================================================================
NEDEN KATEGORI
===========================================================================
Tek bir "acil durum" alarmi, ALAN KISIYE NE YAPACAGINI SOYLEMIYOR.
Deprem uyarisiyla gaz kacagi uyarisi ayni cumleyi kullanamaz:

  * depremde ASANSOR KULLANILMAZ ve cok-kapan-tutun,
  * gaz kacaginda ELEKTRIK DUGMESINE DOKUNULMAZ (kivilcim),
  * tahliyede BINA TERK EDILIR.

Bunlar birbirini DISLAYAN talimatlar; "acil durum var" demek, dogru
davranisi kullanicinin tahminine birakmakti.

===========================================================================
`tip` KALDIRILMADI — KATEGORI ONUN YERINE GECMEZ
===========================================================================
`tip` (sakin / guvenlik / yonetici_anons) KIMIN tetikledigini ve alarmin
KAPSAMINI soyluyor; kategori NE OLDUGUNU. Ikisi ayri sorular:
"sakin, dairesinde yangin" ile "yonetici, site geneli tahliye" ayni
kategoriyi tasiyabilir ama ayni alarm degildir.

Kategori NULL kalabilir: P240'ta yazilmis alarmlarin kategorisi yok ve
uydurmak, olmayan bir bilgiyi kayda gecirmek olurdu.

===========================================================================
ALICI KUMESI KATEGORIDEN DE TURER
===========================================================================
Bina geneli tehlikeler (deprem/yangin/gaz/tahliye) TUM SITEYE gider:
herkesin yapacagi bir sey var. Saglik ve guvenlik tehdidi YALNIZ
yonetim+guvenlige gider:

  * SAGLIK: kisinin sagligi KISISEL VERIDIR; tum siteye "3. katta
    saglik acili" duyurmak KVKK acisindan da gereksiz bir ifsadir.
  * GUVENLIK TEHDIDI: saldirgan ihtimalinde sakinleri koridora
    cikaracak bir duyuru RISKI ARTIRIR. Yonetici gerekirse
    `yonetici_anons` ile siteye ayrica seslenir — o karar INSANIN.

Kod tarafi: `app/panik.py::KATEGORI_ALICI`.
"""
from alembic import op

revision = "0146_panik_kategori"
down_revision = "0145_vardiya_yeniden"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE TYPE panik_kategori AS ENUM "
        "('deprem', 'yangin', 'gaz', 'tahliye', 'saglik', "
        " 'guvenlik_tehdidi', 'diger');"
    )
    op.execute("ALTER TABLE panik_alarm ADD COLUMN kategori panik_kategori;")
    # Kategori bazli push metni kimlikleri — `notification_tip`e GIRMEZ:
    # bildirim TIPI hâlâ `panik_alarm`dir (okundu/sil akislari ona bagli);
    # kategori metni `mesaj_kimlik` uzerinden secilir.


def downgrade() -> None:
    op.execute("ALTER TABLE panik_alarm DROP COLUMN IF EXISTS kategori;")
    op.execute("DROP TYPE IF EXISTS panik_kategori;")
