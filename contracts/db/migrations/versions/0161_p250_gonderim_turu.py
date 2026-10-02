"""(P250 §2) Gonderim kaydina TUR ve HTML govde.

`mesaj_gonderim` P32'den beri "ne gonderdik" defteri ve P154'ten beri
yeniden deneme kuyrugu. P250 uc yeni e-posta ekliyor (odeme kodu §2, hos
geldiniz §3, aidat hatirlatma §7) ve uc soru dogdu:

  * TUR (`tur`): "bu kisiye ODEME KODU e-postasi en son ne zaman gitti,
    teslim edildi mi?" sorusu satirin hangi isten geldigini bilmeden
    cevaplanamaz. Sablon kimligi (`sablon_id`) yalniz yoneticinin kendi
    sablonlarini tasiyor. NULL = eski/genel gonderim.
  * HTML (`govde_html`): kuyruk yeniden denemede yalniz duz `govde`yi
    gonderiyordu — kurumsal HTML e-posta ikinci denemede duz metne
    dusuyordu. HTML de saklanir ve yeniden denemede ayni haliyle gider.
  * Dizin: "kisi + tur icin son satir" sorgusu (liste durum sutunu ve
    tekrar korumasi) tum gecmisi taramasin.
"""
from alembic import op

revision = "0161_p250_gonderim_turu"
down_revision = "0160_p250_soyad"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE mesaj_gonderim "
        "ADD COLUMN tur text NULL "
        "CONSTRAINT ck_gonderim_tur CHECK (tur IS NULL OR tur ~ '^[a-z_]{1,40}$'), "
        "ADD COLUMN govde_html text NULL;"
    )
    op.execute(
        "CREATE INDEX ix_gonderim_tur_kisi ON mesaj_gonderim "
        "(tenant_id, tur, user_id, created_at DESC) WHERE tur IS NOT NULL;"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_gonderim_tur_kisi;")
    op.execute(
        "ALTER TABLE mesaj_gonderim DROP COLUMN IF EXISTS govde_html, "
        "DROP COLUMN IF EXISTS tur;"
    )
