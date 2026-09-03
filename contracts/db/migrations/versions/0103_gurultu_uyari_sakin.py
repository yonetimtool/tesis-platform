"""(P208 §1) GURULTU UYARISI SAKINE — pencere, susma suresi, bildirim tipleri.

===========================================================================
OLCULEN DURUM (P37'den beri)
===========================================================================
Esik asilinca sistem IKI SEYDEN BIRINI yapiyordu: webhook'la anons
cihazina gonderiyor ya da (entegrasyon yoksa) YONETICIYE "anonsu yapin"
bildirimi atiyordu. DAIRENIN SAKININE HICBIR SEY GITMIYORDU — yani
uyari, uyarilmasi gereken kisiye ulasmiyordu.

Ayrica sayim PENCERESIZDI: `durum='acik'` olan her sikayet sayiliyordu.
Bir yil once acilmis ve kimsenin kapatmadigi bir sikayet, dun geceki
kadar agirlik tasiyordu.

===========================================================================
UC YENI AYAR
===========================================================================
`gurultu_pencere_gun` (30): sikayetler bu kadar gun icinde sayilir.
  0 = ESKI DAVRANIS (sinirsiz) — mevcut tesisler icin kacis kapisi.

`gurultu_susma_gun` (7): bir daire uyarildiktan sonra bu kadar gun
  YENIDEN uyarilmaz. Her gece tekrarlanan bir uyari, kendisi gurultuye
  donusur ve okunmaz olur.

`gurultu_sakin_uyarisi` (true): sakine bildirim gonderilsin mi.
  Kapatilabilir cunku bazi tesisler bunu YONETIM ELIYLE yapmak
  isteyebilir (kapiya not, telefon) ve sistemin sakine dogrudan
  yazmasini istemeyebilir.
"""
from alembic import op
import sqlalchemy as sa

revision = "0103_gurultu_uyari_sakin"
down_revision = "0102_bildirim_tipi_vardiya"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tenant",
        sa.Column("gurultu_pencere_gun", sa.Integer(), nullable=False,
                  server_default=sa.text("30")),
    )
    op.add_column(
        "tenant",
        sa.Column("gurultu_susma_gun", sa.Integer(), nullable=False,
                  server_default=sa.text("7")),
    )
    op.add_column(
        "tenant",
        sa.Column("gurultu_sakin_uyarisi", sa.Boolean(), nullable=False,
                  server_default=sa.text("true")),
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_gurultu_pencere "
        "CHECK (gurultu_pencere_gun BETWEEN 0 AND 365 "
        "AND gurultu_susma_gun BETWEEN 0 AND 365);"
    )

    # (P208 §1) UYARI KAYDI SAKINE BILDIRILDI MI?
    #
    # Bildirimin GITTIGI defterde durmali: "uyarildim mi" sorusu bir
    # anlasmazlikta sorulur ve yaniti "push gonderildi mi" ile ayni sey
    # DEGILDIR (daire bos olabilir, ayar kapali olabilir). Kimlik
    # YAZILMAZ — bayrak yeter.
    op.add_column(
        "unit_uyari",
        sa.Column("sakin_bildirildi", sa.Boolean(), nullable=False,
                  server_default=sa.text("false")),
    )

    # SAKIN uyarisi ve YONETICI bilgisi AYRI TIPLER: tek tipe indirmek,
    # bildirim listesinde "size uyari geldi" ile "bir daireye uyari
    # gitti"yi ayirt edilemez yapardi.
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'gurultu_uyari_sakin';"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'gurultu_esik_yonetim';"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_gurultu_pencere;"
    )
    op.drop_column("tenant", "gurultu_sakin_uyarisi")
    op.drop_column("tenant", "gurultu_susma_gun")
    op.drop_column("tenant", "gurultu_pencere_gun")
    # IF EXISTS: gocun govdesi gelistirme sirasinda buyudu ve kismi
    # uygulanmis bir veritabaninda geri donusu patlatmamali.
    op.execute("ALTER TABLE unit_uyari DROP COLUMN IF EXISTS sakin_bildirildi;")
    # ENUM degeri SILINMEZ (Postgres'te DROP VALUE yok) — P207'deki
    # (goc 0102) ayni karar: fazladan bir enum degeri hicbir seyi
    # bozmaz, veri kaybi bozar.
