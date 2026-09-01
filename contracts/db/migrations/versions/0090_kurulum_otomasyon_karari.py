"""(P199) Kurulum sihirbazi: OTOMASYON TERCIHI KARARI kaydedilir.

===========================================================================
NEDEN AYRI BIR SUTUN — NEDEN VERIDEN TURETILMIYOR
===========================================================================
Sihirbazin butun adimlari "yapildi mi"yi VERIDEN sayar (blok satiri var
mi, kasa var mi). Otomasyon adimi bu kalibi TASIYAMAZ, cunku dogru cevap
"kapali birak" OLABILIR:

  * `hatirlatma_ayari.aktif` varsayilani FALSE (P192 karari: otomasyonlar
    varsayilan kapali). "Kapali" satirin kendisi, "yonetici bakti ve
    kapali birakti" ile "yoneticiye hic sorulmadi"yi AYIRT ETMEZ.
  * Satirin VARLIGI da olcut olamaz: `routers/otomasyon.py::_ayar`
    get-or-create'tir ve satiri GET de yaratir — finans ekranini acan
    herkes adimi "tamamlamis" gorunurdu.

Bu yuzden olculen sey KARARIN KENDISIDIR: yonetici otomasyon
tercihlerini bir kez KAYDETTI mi. Bayrak yalnizca PATCH uclarindan
yazilir (hatirlatma ayari / gecikme ayari), GET'ten asla.

Varsayilan FALSE: mevcut tesisler "sorulmadi" durumunda baslar ve
sihirbaz onlara da sorar. Adim ZORUNLU DEGIL — atlanabilir.

Geri alinabilir: `downgrade` sutunu dusurur, veri kaybi yalnizca bu
bayraktir ve yeniden sorularak elde edilir.
"""
from alembic import op
import sqlalchemy as sa

revision = "0090_kurulum_otomasyon_karari"
down_revision = "0089_eposta_zorunlu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tenant",
        sa.Column(
            "kurulum_otomasyon_karari",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )


def downgrade() -> None:
    op.drop_column("tenant", "kurulum_otomasyon_karari")
