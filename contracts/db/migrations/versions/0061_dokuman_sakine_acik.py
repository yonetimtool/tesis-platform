"""(P167 ek) DOKUMAN GORUNURLUGU — sakine acik mi?

===========================================================================
NEDEN BAYRAK, NEDEN "UCU SAKINE AC" DEGIL
===========================================================================
Istek: "mobilde sakinler dokumanlari okuyabilsin."

`tenant_dokuman` bugun TEK BIR ARSIV ve icinde ne oldugu sozlesmede
belirli DEGIL: yonetim plani ve butce de olabilir, personel sozlesmesi,
hukuki yazisma, ihale teklifi veya bir sakinin borc dosyasi da.

`GET /dokumanlar`i oldugu gibi sakine acmak, bu tabloya BUGUNE KADAR
"yalnizca yonetim gorur" varsayimiyla yuklenmis HER DOSYAYI geriye donuk
yayinlamak olurdu. Bu sessiz bir sizinti olurdu: yonetici bir gun
panelini acip yillar once yukledigi bir sozlesmenin sakin uygulamasinda
durdugunu gorurdu.

===========================================================================
VARSAYILAN `false` — VE BU GOCUN ASIL KARARI BUDUR
===========================================================================
`DEFAULT false` mevcut arsivi OLDUGU YERDE birakir. Yonetici hangi
dosyanin sakine acik oldugunu TEK TEK isaretler.

Tersi (`DEFAULT true`) tek satirlik bir tercih gibi gorunur ama goc
calistigi anda butun arsivi yayina cikarirdi ve geri almak, o arada
indirilmis dosyalari geri getirmezdi. Guvenli yon TEK YONDUR: kapalidan
acmaya.

===========================================================================
INDEKS
===========================================================================
Sakin listesi `sakine_acik AND silindi_at IS NULL` suzer. Kismi indeks bu
sorguyu karsilar; tam indeks, satirlarin cogunun kapali oldugu bir
tabloda gereksiz genislik olurdu.
"""
from alembic import op

revision = "0061_dokuman_sakine_acik"
down_revision = "0060_dokuman_saklama"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE tenant_dokuman "
        "ADD COLUMN sakine_acik boolean NOT NULL DEFAULT false"
    )
    op.execute(
        """
        CREATE INDEX ix_dokuman_sakine_acik
          ON tenant_dokuman (tenant_id, created_at DESC)
          WHERE sakine_acik AND silindi_at IS NULL
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_dokuman_sakine_acik")
    op.execute("ALTER TABLE tenant_dokuman DROP COLUMN IF EXISTS sakine_acik")
