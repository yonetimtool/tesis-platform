"""(E2E 2026-09) BILDIRIM-12 — DUYURUDA HEDEF KITLE.

===========================================================================
OLCULEN DURUM (once)
===========================================================================
`POST /announcements` yalniz `baslik, govde, foto_key` aliyordu; web ve
mobil formda hedef alani yoktu. Gorselli bir duyuru olusturuldugunda push
TENANT'TAKI TUM ROLLERE gitti — duyuruyu yazan yonetici DAHIL. Plan §7
"hedef kitle secimi (yalniz A blok / yalniz malikler)" karsilanmiyordu.

===========================================================================
TASARIM — ANKETLE AYNI DESEN (goc 0137) + BLOK
===========================================================================
Ayri bir `duyuru_hedef` tablosu KURULMADI (0137'deki gerekceyle ayni):
hedef kitle duyurunun kendi niteligi, baska bir kayda baglanmiyor ve
duyuru ile birlikte olusur. Uc kolon:

  * hedef_roller      text[]  NULL/bos = HERKES (rol ayrimi yok)
  * hedef_sakin_tipi  text    'malik' | 'kiraci' | NULL (yalniz sakinlere)
  * hedef_bloklar     text[]  NULL/bos = TUM bloklar (yalniz sakinlere)

`unit.blok` zayif METIN baglantisidir (FK yok, bkz. blok-daire kurallari);
blok adi burada da metin olarak tutulur. Blok yeniden adlandirilirsa eski
duyurunun hedefi eski adda kalir — duyuru O GUNUN kitlesine yazilmistir,
bu bilincli.

Mevcut duyurularin kolonlari NULL kalir = herkes (bugunku davranis).

Goc `app.*` ithal ETMEZ (dondurulmus kopya kurali).
"""
from alembic import op

revision = "0152_e2e_duyuru_hedef"
down_revision = "0151_e2e_tesis"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE announcement ADD COLUMN IF NOT EXISTS hedef_roller text[];")
    op.execute(
        "ALTER TABLE announcement ADD COLUMN IF NOT EXISTS hedef_sakin_tipi text;"
    )
    op.execute(
        "ALTER TABLE announcement ADD CONSTRAINT ck_announcement_hedef_sakin_tipi "
        "CHECK (hedef_sakin_tipi IS NULL OR hedef_sakin_tipi IN ('malik', 'kiraci'));"
    )
    op.execute("ALTER TABLE announcement ADD COLUMN IF NOT EXISTS hedef_bloklar text[];")


def downgrade() -> None:
    op.execute(
        "ALTER TABLE announcement DROP CONSTRAINT IF EXISTS "
        "ck_announcement_hedef_sakin_tipi;"
    )
    op.execute("ALTER TABLE announcement DROP COLUMN IF EXISTS hedef_bloklar;")
    op.execute("ALTER TABLE announcement DROP COLUMN IF EXISTS hedef_sakin_tipi;")
    op.execute("ALTER TABLE announcement DROP COLUMN IF EXISTS hedef_roller;")
