"""(P224) KISI BASINA TEK BIRINCIL UYELIK.

===========================================================================
OLCULEN TUTARSIZLIK — PROD KURTARMASI SIRASINDA GORULDU
===========================================================================
Kurtarma sonrasi `tesis_uyelik` su hale geldi:

    yonetici | birincil=t | kurulum-bekliyor-aa86f1 | Oltu Sitesi
    admin    | birincil=t | platform                | Yönetio Platform

Iki satir, AYNI KISI (ayni e-posta), IKISI DE birincil.

`birincil` alani goc 0068'de su gerekceyle konmustu:

    -- Kisinin ASIL (varsayilan) tesisi. Bugun herkesin tek uyeligi var
    -- ve o birincildir; cok tesisli acildiginda uygulama acilista
    -- buraya bakacak.

Yani alan KISI BASINADIR, tesis basina degil. Iki satirda birden `true`
olmasi, "acilista hangi tesise girilecek" sorusunu YANITSIZ birakir.
Bugun hicbir giris yolu bu tabloyu OKUMADIGI icin gorunur bir zarari
yok — ve tam bu yuzden tehlikeli: cok tesisli giris acildigi gun,
kimsenin dokunmadigi eski satirlar yuzunden rastgele bir tesise
girilir ve sebebi aylar sonra aranir.

===========================================================================
NEDEN KISMI BENZERSIZ INDEKS, NEDEN TRIGGER DEGIL
===========================================================================
Kural tek cumleyle ifade edilebiliyor: "bir e-posta icin en fazla bir
`birincil` satir". Bunu indeks zorlar, yazmasi ve okumasi kolaydir,
yarissizdir. Trigger yazmak ayni seyi daha fazla kodla ve daha zayif
garantiyle yapmak olurdu (es zamanli iki INSERT'te trigger'in gordugu
sayim eskiyebilir; benzersiz indeks eskiyemez).

MEVCUT IHLALLER ONCE DUZELTILIR ve KARAR DETERMINISTIKTIR: en ESKI
uyelik birincil kalir. "Ilk katildigi tesis" savunulabilir bir
varsayilandir; rastgele birini secmek ya da hepsini birincilsiz
birakmak (o zaman acilista HICBIR tesis secilemez) degildir.
"""
from alembic import op

revision = "0127_birincil_uyelik_tek"
down_revision = "0126_tesis_silme_korumasi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1) MEVCUT IHLALLERI DUZELT — en eski uyelik birincil kalir.
    op.execute(
        """
        UPDATE public.tesis_uyelik u
           SET birincil = false
         WHERE u.birincil
           AND u.id <> (
               SELECT k.id
                 FROM public.tesis_uyelik k
                WHERE k.eposta = u.eposta AND k.birincil
                ORDER BY k.created_at ASC, k.id ASC
                LIMIT 1
           );
        """
    )

    # 2) KURALI ZORLA.
    op.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS uq_tesis_uyelik_birincil_eposta "
        "ON public.tesis_uyelik (eposta) WHERE birincil"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS public.uq_tesis_uyelik_birincil_eposta")
