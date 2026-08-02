"""demo modu (0030) — MASTER-PLAN P115: App Store denetcisi icin.

SORUN: Apple denetcisi ne fiziksel NFC etiketimizi okutabilir ne de bir
sitede durabilir. Uygulamanin OMURGASI (devriye turu) donanima bagli
oldugu icin, denetci onu HIC goremeden reddedebilir ("ozellik
calismiyor").

COZUM: TENANT KAPSAMLI demo modu. Yalniz bu bayragi tasiyan tesiste
"simule okutma" yolu acilir; gercek tesislerde uc YOK gibi davranir.

NEDEN TENANT BAYRAGI (istemci bayragi ya da derleme bayragi DEGIL):
  * ISTEMCI bayragi olsaydi, herhangi bir kullanici uygulamayi
    "demo" moduna alip GERCEK bir tesiste sahte tur kaydi uretebilirdi
    — yani guvenlik kaniti degersizlesirdi.
  * DERLEME bayragi (ayri bir demo yapimi) olsaydi denetciye
    magazadakinden BASKA bir uygulama gonderilmis olurdu; Apple bunu
    acikca yasaklar.
Bayrak SUNUCUDA durur ve yalniz platform operatoru (admin) acar.

Revision ID: 0030_demo_mod
Revises: 0029_hesap_silme_kaydi
"""
from __future__ import annotations

from alembic import op

revision = "0030_demo_mod"
down_revision = "0029_hesap_silme_kaydi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE tenant ADD COLUMN demo_mod boolean NOT NULL DEFAULT false;"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS demo_mod;")
