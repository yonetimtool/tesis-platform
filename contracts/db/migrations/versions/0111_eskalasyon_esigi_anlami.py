"""(P219 §1) ESKALASYON ESIGI: DEGER ile ANLAM HIZALANIYOR.

===========================================================================
OLCULEN KUSUR
===========================================================================
Ayarin adi "Guvenlige eskalasyon esigi", varsayilani `1`. Ama kod
`asama > esik` diye bakiyordu:

    ayar=1 -> ILK eskalasyon 2. uyarida
    ayar=2 -> ILK eskalasyon 3. uyarida
    ayar=3 -> ILK eskalasyon 4. uyarida

Yani ekranda "1" yazan bir alan aslinda "2. uyarida" demekti. Ipucu bunu
bir cumleyle telafi etmeye calisiyordu ("1 = ikinci kez esige
ulasildiginda") — ama bir ayarin ANLAMINI dipnotla duzeltmek, ayarin
kendisinin yanlis oldugunu kabul etmektir. Kullanici hakli olarak
"1 kez polis mi cagrilacak" diye okuyordu.

===========================================================================
KARAR: DEGERI ANLAMA ESITLE
===========================================================================
Ayar artik DOGRUDAN "kacinci uyarida guvenlige bildirilsin" demek ve kod
`asama >= esik` diye bakiyor:

    ayar=2 -> 2. uyarida (eski `1`in davranisi)
    ayar=1 -> ILK uyarida (yeni, mesru bir tercih)

Alternatif — etiketi degistirip degeri korumak — reddedildi: alana "1"
yazip ekranda "2. uyari" gormek ayni karisikligi surdururdu.

===========================================================================
GOC: MEVCUT DAVRANIS BIREBIR KORUNUR
===========================================================================
Her tesisin degeri BIR ARTIRILIR. Eski `1` (=2. uyarida) yeni `2`
(=2. uyarida) olur; hicbir sitede eskalasyon davranisi degismez.

Ust sinir 10'dan 11'e cikarilmaz: sema sinirlari (1-10) arayuzde;
10 yazan bir tesis 11 olur ve semayi asardi. Bu yuzden ARTIRMA
10'DA DURDURULUR — o siteye pratikte hicbir fark getirmez (10. asima
ulasan bir daire zaten cok once eskale olmustur).

GERI ALINABILIR: `downgrade` degerleri bir azaltir.
"""
from alembic import op

revision = "0111_eskalasyon_esigi_anlami"
down_revision = "0110_tenant_varsayilan_hedef"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "UPDATE tenant SET gurultu_eskalasyon_esigi = "
        "LEAST(gurultu_eskalasyon_esigi + 1, 10);"
    )
    # Yeni tesisler icin varsayilan da kayar: 1 -> 2 (ayni davranis).
    op.execute(
        "ALTER TABLE tenant ALTER COLUMN gurultu_eskalasyon_esigi "
        "SET DEFAULT 2;"
    )


def downgrade() -> None:
    op.execute(
        "UPDATE tenant SET gurultu_eskalasyon_esigi = "
        "GREATEST(gurultu_eskalasyon_esigi - 1, 1);"
    )
    op.execute(
        "ALTER TABLE tenant ALTER COLUMN gurultu_eskalasyon_esigi "
        "SET DEFAULT 1;"
    )
