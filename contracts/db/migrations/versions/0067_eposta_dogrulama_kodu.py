"""(P172 §5) E-POSTA DOGRULAMA KODU — mevcut kod altyapisi e-postaya acilir.

===========================================================================
NEDEN AYRI BIR SISTEM KURULMADI
===========================================================================
`kayit_dogrulama` zaten kodun butun guvenlik ozelliklerini tasiyor: kod
DUZ METIN TUTULMAZ (bcrypt), sureli, deneme sayaci AYRI OTURUMDA
kalicilastiriliyor ve `amac` ayrimi "giris kodu hesap silmeyi onaylayamaz"
kuralini yapisal olarak uyguluyor.

Ikinci bir tablo acmak, bu dort korumayi ikinci kez — ve bir gun eksik —
yazmak olurdu. Degisen tek sey KIMLIGIN NE OLDUGU.

===========================================================================
TELEFON ARTIK ZORUNLU DEGIL, AMA BIRI ZORUNLU
===========================================================================
`telefon` NOT NULL idi. E-posta ile gelen bir kodun telefonu olmayabilir
(`app_user.telefon` NULL olabiliyor — panel kullanicilari e-posta ile
girer). Kolon NULL'a aciliyor ve yerine BIR CHECK geliyor: satirin
telefonu YA DA e-postasi olmali. Ikisi de bos bir kod satiri, kimseye
gonderilemeyen ve kimsenin dogrulayamayacagi bir kayittir.

===========================================================================
E-POSTA GLOBAL DEGIL, TENANT ICINDE BENZERSIZ — VE BU ONEMLI
===========================================================================
Telefon PLATFORM GENELINDE benzersiz (`tenant_id_by_phone` bu yuzden
calisiyor) ve acik basvuru indeksi de global: bir numara tum platformda
tek acik basvuru tasir. Bu yuzden telefon satirlarini temizlemek
`SECURITY DEFINER` bir fonksiyon gerektiriyordu (RLS altinda baska
tenant'in satiri GORULEMEZ).

E-posta oyle DEGIL: `uq_app_user_tenant_email` tenant icinde benzersizdir,
yani ayni e-posta iki tesiste bulunabilir. Sonucu sadelestirici: e-posta
kod satirlari TENANT ICINDE kalir, temizligi duz `DELETE` ile RLS altinda
yapilir ve capraz-tenant bir fonksiyona GEREK YOKTUR. Daha az yetki, daha
az yuzey.

Kismi indeks arama icin: (tenant_id, eposta, amac) — dogrulama yolu tam
olarak bu ucluyle bakiyor.

Revision ID: 0067_eposta_dogrulama_kodu
Revises: 0066_html_temizleme_onarimi
"""
from alembic import op

revision = "0067_eposta_dogrulama_kodu"
down_revision = "0066_html_temizleme_onarimi"
branch_labels = None
depends_on = None

KISIT = "ck_kayit_dogrulama_kimlik"
INDEKS = "ix_kayit_dogrulama_eposta"


def upgrade() -> None:
    op.execute("ALTER TABLE kayit_dogrulama ALTER COLUMN telefon DROP NOT NULL")
    op.execute("ALTER TABLE kayit_dogrulama ADD COLUMN eposta text")
    # NOT VALID YOK: tablo kucuk ve mevcut satirlarin HEPSINDE telefon
    # dolu (kolon dun NOT NULL'di), yani dogrulama anlik.
    op.execute(
        f"ALTER TABLE kayit_dogrulama ADD CONSTRAINT {KISIT} "
        "CHECK (telefon IS NOT NULL OR eposta IS NOT NULL)"
    )
    op.execute(
        f"CREATE INDEX {INDEKS} ON kayit_dogrulama (tenant_id, eposta, amac) "
        "WHERE eposta IS NOT NULL"
    )


def downgrade() -> None:
    op.execute(f"DROP INDEX IF EXISTS {INDEKS}")
    op.execute(f"ALTER TABLE kayit_dogrulama DROP CONSTRAINT IF EXISTS {KISIT}")
    # E-POSTA SATIRLARI SILINIR: kolon dusurulecek ve `telefon` yeniden
    # NOT NULL olacak; telefonu olmayan satirlar o kisiti ihlal ederdi.
    # Bunlar kisa omurlu dogrulama kodlaridir, veri kaybi degil.
    op.execute("DELETE FROM kayit_dogrulama WHERE telefon IS NULL")
    op.execute("ALTER TABLE kayit_dogrulama DROP COLUMN eposta")
    op.execute("ALTER TABLE kayit_dogrulama ALTER COLUMN telefon SET NOT NULL")
