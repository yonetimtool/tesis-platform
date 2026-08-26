"""(P181 Bölüm 1) app_user.eposta_dogrulandi + kod_amaci 'eposta_ekle'

E-posta doğrulama DURUMU kalıcı bir bayrakla tutulur. Bugüne dek yalnız
`kayit_dogrulama`'da KODLAR vardı; kullanıcının e-postasının doğrulanmış olup
olmadığını tutan alan YOKTU. Bu bayrak Bölüm 2 (parola sıfırlama) ve Bölüm 4
(OTP giriş) için ÖN KOŞUL: "doğrulanmamış e-postaya kod/bağlantı gönderilmez".

GERİYE DÖNÜK: mevcut kullanıcılar `false` (doğrulanmamış) başlar — güvenli
varsayılan. E-postalı ama doğrulanmamış kullanıcılar giriş yapar, KİLİTLENMEZ;
reset/OTP'yi kullanmak için e-postalarını doğrularlar.

`eposta_ekle`: mevcut kullanıcının e-posta ekleme/doğrulama akışının kod amacı —
`kayit`tan ayrı ki kayıt kodu ile karışmasın.

Revision ID: 0070_eposta_dogrulandi
Revises: 0069_yonetici_by_email
Create Date: 2026-08-26
"""
import sqlalchemy as sa
from alembic import op

revision = "0070_eposta_dogrulandi"
down_revision = "0069_yonetici_by_email"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # PG16: ADD VALUE migration transaction'ında güvenli (değer bu tx'te
    # KULLANILMIYOR, yalnız ekleniyor). IF NOT EXISTS -> idempotent.
    op.execute("ALTER TYPE kod_amaci ADD VALUE IF NOT EXISTS 'eposta_ekle'")
    op.add_column(
        "app_user",
        sa.Column(
            "eposta_dogrulandi",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    # DB server_default KALIR (false): app_user'a HAM SQL ile yazan yollar
    # (create_tenant_with_yoneticis, seed) bu kolonu adlandırmaz; default olmadan
    # NOT NULL ihlali olurdu. Doğrulanmış hesaplar bayrağı AÇIKÇA true yazar.


def downgrade() -> None:
    op.drop_column("app_user", "eposta_dogrulandi")
    # kod_amaci 'eposta_ekle' geri ALINMAZ: PG enum değeri düşürülemez, zararsız.
