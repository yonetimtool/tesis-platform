"""(P181 Bölüm 2) kod_amaci enum'una 'sifre_sifirla' — parola sıfırlama kodu

"Şifremi unuttum" akışının kod amacı. `giris`/`kayit`/`eposta_ekle`'den AYRI ki
kod satırları karışmasın (aynı e-postaya aynı anda giriş kodu + sıfırlama kodu
gidebilir; `eposta_kodunu_dogrula` amaca göre süzer).

E-POSTA TABANLI, SMS YOK. Yalnız `eposta_dogrulandi=true` kullanıcıya kod gider
(Bölüm 1 ön koşulu); doğrulanmamış/olmayan adres için de AYNI yanıt döner
(sızıntısız).

Revision ID: 0071_kod_amaci_sifre_sifirla
Revises: 0070_eposta_dogrulandi
Create Date: 2026-08-26
"""
from alembic import op

revision = "0071_kod_amaci_sifre_sifirla"
down_revision = "0070_eposta_dogrulandi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # PG16: ADD VALUE bu tx'te KULLANILMIYOR (yalnız ekleniyor) -> güvenli.
    # IF NOT EXISTS -> idempotent.
    op.execute("ALTER TYPE kod_amaci ADD VALUE IF NOT EXISTS 'sifre_sifirla'")


def downgrade() -> None:
    # PG enum değeri düşürülemez; zararsız kalır.
    pass
