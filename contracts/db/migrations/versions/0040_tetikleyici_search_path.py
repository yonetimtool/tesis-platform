"""(P151) `tenant_kayit_kodu_ata()` bos search_path altinda patliyordu.

PROD HATASI: `create_tenant_with_yoneticis` -> 500
`UndefinedTableError: relation "tenant" does not exist`

KOK NEDEN — cagrilan fonksiyonda DEGIL, TETIKLEDIGI YERDE:
`create_tenant_with_yoneticis` SECURITY DEFINER ve `SET search_path = ''`
tasiyor; govdesindeki her sey `public.` ile nitelenmis. Ama
`INSERT INTO public.tenant` **tetikleyiciyi** atesliyor ve P148.1'de
yazilan `tenant_kayit_kodu_ata()` govdesinde su satir NITELENMEMISTI:

    WHILE EXISTS (SELECT 1 FROM tenant WHERE kayit_kodu = aday)

Tetikleyici fonksiyonun KENDI `SET search_path`'i de yoktu, dolayisiyla
cagiranin bos search_path'ini MIRAS ALDI ve `tenant` cozulemedi.

GOC SIRASINDA NEDEN PATLAMADI: gocteki dolgu sorgusu (ayni dosyada,
nitelenmemis `FROM tenant`) normal search_path ile kostu. Hata yalnizca
bos search_path'li bir cagirandan gelindiginde ortaya cikiyor — yani
uretimdeki ilk gercek tesis olusturmada.

SEARCH_PATH SECIMI — `''` (BOS) KORUNDU, `public, pg_temp` SECILMEDI:
PostgreSQL'in guncel onerisi, SECURITY DEFINER govdelerinde search_path'i
BOS birakip her referansi TAM NITELEMEKTIR. `public, pg_temp` eski
oneridir ve `public` uzerinde yazma yetkisi olan biri ayni adla bir nesne
yaratip cagriyi golgeleyebilir. Cozum search_path'i gevsetmek degil,
EKSIK NITELEMEYI tamamlamaktir.

Tetikleyici fonksiyona AYRICA kendi `SET search_path = ''` verildi:
boylece davranisi CAGIRANDAN BAGIMSIZ olur. Bugun cagiran bos search_path
tasidigi icin patliyordu; yarin baska bir cagiran normal search_path ile
gelse hata SESSIZCE kaybolur ve kusur gizlenirdi.
"""
from alembic import op

revision = "0040_tetikleyici_search_path"
down_revision = "0039_telefon_kodu_amaci"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_kayit_kodu_ata()
        RETURNS trigger
        LANGUAGE plpgsql
        SET search_path = ''
        AS $$
        DECLARE
            taban text;
            aday  text;
            n     int := 1;
        BEGIN
            IF NEW.kayit_kodu IS NOT NULL THEN
                RETURN NEW;
            END IF;
            taban := public.kayit_kodu_uret(
                NEW.ad, COALESCE(NEW.created_at, now())::date);
            aday := taban;
            -- (P151) `public.` EKLENDI — hatanin tam olarak patladigi satir.
            WHILE EXISTS (
                SELECT 1 FROM public.tenant WHERE kayit_kodu = aday
            ) LOOP
                n := n + 1;
                aday := taban || '-' || n::text;
            END LOOP;
            NEW.kayit_kodu := aday;
            RETURN NEW;
        END;
        $$;
        """
    )
    # `kayit_kodu_uret` govdesinde nitelenmemis nesne YOK (yalnizca
    # string_agg/substr/translate/to_char — hepsi pg_catalog'da ve
    # pg_catalog search_path bos olsa bile ORTULU olarak aranir). Yine de
    # cagirandan bagimsiz olsun diye ona da sabit search_path veriliyor.
    op.execute(
        "ALTER FUNCTION public.kayit_kodu_uret(text, date) SET search_path = '';"
    )


def downgrade() -> None:
    # Eski (kusurlu) surume donmek anlamsiz; yalniz sabitlemeyi kaldiririz.
    op.execute(
        "ALTER FUNCTION public.tenant_kayit_kodu_ata() RESET search_path;"
    )
    op.execute(
        "ALTER FUNCTION public.kayit_kodu_uret(text, date) RESET search_path;"
    )
