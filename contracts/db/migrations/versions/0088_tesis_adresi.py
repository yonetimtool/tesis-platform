"""(P193 §4) tenant adres alanlari — makbuzda ve resmi ciktida adres

===========================================================================
NEDEN
===========================================================================
Yonetici kurulum rehberi yazilirken bulundu (eksik 1): sistemde tesisin
POSTA ADRESI hicbir yerde tutulmuyordu — ne web'de ne mobilde. Makbuz
PDF'i yalnizca site ADINI yaziyordu; oysa bir tahsilat makbuzu, elden
verildiginde ya da bir anlasmazlikta, hangi tesise ait oldugunu adresiyle
gostermek zorundadir. Yonetici bugun bunu yazamiyordu.

===========================================================================
DORT AYRI ALAN, TEK METIN DEGIL
===========================================================================
"adres" diye tek bir serbest metin de yazilabilirdi ve daha az is olurdu.
Elendi: il/ilce daha sonra RAPORLANABILIR ve SUZULEBILIR alanlardir
(bolgeye gore tesis listesi, e-devlet/e-fatura entegrasyonu). Serbest
metinden il cikarmak, sonradan yazilan bir ayristiricinin isi olurdu ve
"Istanbul" ile "ISTANBUL" ayni sayilmazdi.

Posta kodu da AYRI: kargo ve resmi yazismada tek basina kullanilir.

===========================================================================
HEPSI NULL EDILEBILIR — VE BU BILINCLI
===========================================================================
Zorunlu yapmak, bugun calisan her tesisi bir anda "eksik" hâle getirir ve
gocun kendisi NOT NULL kisitinda patlardi. Adres kurulum sihirbazinda
SORULUR (istege bagli adim) ve makbuzda yalnizca DOLU satirlar yazilir;
bos adres, makbuzda bos bir satir birakmaz.

Revision ID: 0088_tesis_adresi
Revises: 0087_butce_hedefi
Create Date: 2026-09-01
"""
from alembic import op

revision = "0088_tesis_adresi"
down_revision = "0087_butce_hedefi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE tenant
            ADD COLUMN IF NOT EXISTS adres text,
            ADD COLUMN IF NOT EXISTS ilce text,
            ADD COLUMN IF NOT EXISTS il text,
            ADD COLUMN IF NOT EXISTS posta_kodu text;
        """
    )
    # Posta kodu SERBEST METIN DEGIL: bes hane. Kisit CHECK ile duruyor
    # cunku "12 34" gibi bir deger kargo etiketinde sessizce ise yaramaz
    # bir adres uretir. NULL serbest (adres girmeyen tesis).
    op.execute(
        """
        ALTER TABLE tenant
            ADD CONSTRAINT ck_tenant_posta_kodu
            CHECK (posta_kodu IS NULL OR posta_kodu ~ '^[0-9]{5}$');
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_posta_kodu;")
    op.execute(
        """
        ALTER TABLE tenant
            DROP COLUMN IF EXISTS posta_kodu,
            DROP COLUMN IF EXISTS il,
            DROP COLUMN IF EXISTS ilce,
            DROP COLUMN IF EXISTS adres;
        """
    )
