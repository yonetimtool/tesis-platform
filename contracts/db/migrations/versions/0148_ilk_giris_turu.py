"""(P243 §6d) ILK GIRIS TURU — kullanici basina "gordum" damgasi.

===========================================================================
NEDEN KULLANICI BASINA, TESIS BASINA DEGIL
===========================================================================
Tur, yeni bir INSANA urunu tanitir. Tesis basina tutulsaydi ayni siteye
ikinci bir yonetici eklendiginde tur ONA HIC gosterilmezdi — oysa o da
urunu ilk kez goruyor.

===========================================================================
NEDEN SUTUN, NEDEN `localStorage` DEGIL
===========================================================================
Tarayici deposu cihaza baglidir: ofiste turu atlayan yonetici, evdeki
bilgisayarda onu YENIDEN gorurdu. "Bir kez gosterilir" sozu ancak
hesapta tutulursa tutulabilir.

DAMGA, BAYRAK DEGIL: ne zaman gorduğunu da biliyoruz. Ileride tur
degisirse "su tarihten once gorenlere yeniden goster" denebilir; bayrak
bunu soyleyemezdi.
"""
from alembic import op

revision = "0148_ilk_giris_turu"
down_revision = "0147_web_gorunum_modu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE app_user ADD COLUMN IF NOT EXISTS tur_goruldu_at "
        "timestamptz;"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS tur_goruldu_at;")
