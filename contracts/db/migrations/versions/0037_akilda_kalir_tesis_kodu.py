"""(P148.1) Tesis kodu AKILDA KALICI olsun: ADIN ILK 4 HARFI + '-' + YYAAGG.

Kerem'in karari: "Oltu Sitesi" 15.07.2026'da kayitliysa -> `OLTU-260715`,
"Can Sitesi" 02.04.2025'te kayitliysa -> `CANS-250402`.

NEDEN TETIKLEYICI (sunucu varsayilani DEGIL): kod artik iki SUTUNDAN
turetiliyor (`ad`, `created_at`); sutun varsayilani baska sutunlari
goremez. Tetikleyici ayrica kurali TEK YERDE tutar — kayit akisi, tanitim
formu, tohumlama ve testler ayni kodu uretir.

CAKISMA GERCEK BIR IHTIMAL: "Oltu Sitesi" ve "Oltu Konaklari" ayni gun
kaydolursa ayni tabani uretir ve sutun UNIQUE. Cakismada sona `-2`, `-3`
eklenir; sessizce baska bir kod uydurmak, yoneticiye soyledigimiz kodun
tutmamasi demek olurdu.

GUVENLIK NOTU — BILEREK KAYDEDILIYOR: bu kod artik TAHMIN EDILEBILIR
(site adi ve kayit tarihi kamuya acik). P148'de daire sahipligi
dogrulamasi KAPATILDIGI icin kod, daire verisini koruyan tek denetimdi;
akilda kalicilik onu zayiflatti. Kerem'e bildirildi (bkz. MASTER-PLAN).
"""
from alembic import op

revision = "0037_akilda_kalir_tesis_kodu"
down_revision = "0036_sakin_kendi_kaydolur"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Turkce harfleri ASCII'ye indirger: kod telefonda ELLE yazilir ve
    # klavyede `ş`/`ğ` aramak zorunda birakilmamali.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kayit_kodu_uret(p_ad text, p_tarih date)
        RETURNS text
        LANGUAGE sql IMMUTABLE AS $$
            SELECT rpad(
                       left(
                           regexp_replace(
                               upper(translate(p_ad,
                                   'çÇğĞıİöÖşŞüÜ', 'cCgGiIoOsSuU')),
                               '[^A-Z]', '', 'g'),
                           4),
                       4, 'X')
                   || '-' || to_char(p_tarih, 'YYMMDD');
        $$;
        """
    )
    # `rpad(...,'X')`: adi dort harften kisa tesis ("As Sitesi" -> "ASSI"
    # olur ama "As" tek basina "AS") bicimi bozmasin.

    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_kayit_kodu_ata()
        RETURNS trigger
        LANGUAGE plpgsql AS $$
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
            WHILE EXISTS (SELECT 1 FROM tenant WHERE kayit_kodu = aday) LOOP
                n := n + 1;
                aday := taban || '-' || n::text;
            END LOOP;
            NEW.kayit_kodu := aday;
            RETURN NEW;
        END;
        $$;
        """
    )
    op.execute("DROP TRIGGER IF EXISTS trg_tenant_kayit_kodu ON tenant;")
    op.execute(
        """
        CREATE TRIGGER trg_tenant_kayit_kodu
            BEFORE INSERT ON tenant
            FOR EACH ROW EXECUTE FUNCTION public.tenant_kayit_kodu_ata();
        """
    )
    # Sutun varsayilani KALKAR: iki kaynak olsaydi hangisinin kazandigi
    # ekleme bicimine gore degisirdi.
    op.execute("ALTER TABLE tenant ALTER COLUMN kayit_kodu DROP DEFAULT;")
    op.execute("DROP FUNCTION IF EXISTS public.gen_kayit_kodu();")

    # MEVCUT tesisler yeni bicime gecer. Cakisma ihtimali burada da var;
    # `row_number` ile ayni tabani paylasanlarin ikincisinden itibaren
    # sira eki alinir (tetikleyicideki kuralin aynisi).
    op.execute(
        """
        WITH y AS (
            SELECT id,
                   public.kayit_kodu_uret(ad, created_at::date) AS taban,
                   row_number() OVER (
                       PARTITION BY public.kayit_kodu_uret(ad, created_at::date)
                       ORDER BY created_at, id) AS sira
            FROM tenant
        )
        UPDATE tenant t
           SET kayit_kodu = CASE WHEN y.sira = 1
                                 THEN y.taban
                                 ELSE y.taban || '-' || y.sira::text END
          FROM y WHERE y.id = t.id;
        """
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS trg_tenant_kayit_kodu ON tenant;")
    op.execute("DROP FUNCTION IF EXISTS public.tenant_kayit_kodu_ata();")
    op.execute("DROP FUNCTION IF EXISTS public.kayit_kodu_uret(text, date);")
