"""goruntu_kirliligi (0013) — daire sikayeti kategorisine yeni deger.

MASTER-PLAN P22(g). Kerem'in istegi: "görüntü kirliliği" bir sikayet
kategorisi olarak secilebilsin ve OTOPARK baglamindan da bildirilebilsin
(hurda arac, dagilmis esya, cop yigini...).

NEDEN SIKAYET KATEGORISI, IHLAL DEGIL: `violation` kaydi serbest metin
`baslik` + `kaynak` (kamera|manuel|devriye) tasir; sabit bir kategori enum'u
YOKTUR — yani "ihlal kategorisi" diye eklenecek bir yer yok. `unit_complaint`
ise zaten kategorili (gurultu / kapi_onu_ayakkabi / zarar_verme / diger) ve
sakinin actigi kanal odur. Dolayisiyla dogru yer burasi.

POSTGRES NOTU: `ALTER TYPE ... ADD VALUE` islem icinde calisir ama AYNI
islemde KULLANILAMAZ; burada yalniz eklenir, kullanan kod sonraki isteklerde
gelir. `IF NOT EXISTS` tekrar kosuma karsi guvenli kilar.

GERI ALMA: Postgres enum degeri DUSURMEYI desteklemez. `downgrade` tipi
yeniden kurmak yerine, o degeri kullanan satirlari `diger`e cekip degeri
yerinde birakir — veri KAYBETTIRMEZ ve sema tersinirlik olcumu (yalniz
dev'de kosar) buna gore yazildi.

Revision ID: 0013_goruntu_kirliligi
Revises: 0012_kamera_restream
"""
from __future__ import annotations

from alembic import op

revision = "0013_goruntu_kirliligi"
down_revision = "0012_kamera_restream"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "ALTER TYPE unit_complaint_kategori ADD VALUE IF NOT EXISTS "
        "'goruntu_kirliligi';"
    )


def downgrade() -> None:
    # Enum degeri dusurulemez; kullanan satirlar 'diger'e cekilir.
    op.execute(
        "UPDATE unit_complaint SET kategori = 'diger' "
        "WHERE kategori = 'goruntu_kirliligi';"
    )
