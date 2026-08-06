"""(P148) Sakin KENDI kaydolur: tesis kodu + daire + telefon dogrulamasi.

BUGUNE KADAR sakini YONETICI aciyordu. Yeni akista sakin uygulamayi indirip
tesis kodunu, blok-daire numarasini ve telefonunu girer; telefon SMS koduyla
dogrulanir ve kullanici ilgili daireye BAGLANIR.

IKI YENI SEY, KULLANICI TABLOSUNA DOKUNULMADAN:
  * `tenant.kayit_kodu` — tesise ait, INSANIN YAZABILECEGI kisa kod.
  * `kayit_dogrulama` — bekleyen kayit + telefon kodu. Kod DUZ METIN
    TUTULMAZ (hash) ve deneme sayisi sayilir.

PAROLA SUTUNU EKLENMEDI ve gerekmiyor: `app_user.password_hash` ZATEN
nullable, `password_set` ZATEN var. Parolasiz kimlik icin yeni bir sema
degil, var olanin kullanilmasi yeter.

KOD ALFABESI KARISTIRILABILIR HARFLERI DISLAR (I/1, O/0): kod telefonda
ELLE yazilir ve "sanirim sifirdi" turu destek cagrisi uretmemeli.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "0036_sakin_kendi_kaydolur"
down_revision = "0035_sakin_bildirimleri"
branch_labels = None
depends_on = None

_ALFABE = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def upgrade() -> None:
    # Kod URETIMI VERITABANINDA: `NOT NULL` yapip varsayilan vermemek yeni
    # tesis acmayi kirdi (testler yakaladi). Kodu her cagiranin uretmesini
    # beklemek — kayit akisi, tanitim formu, tohumlama, testler — ayni
    # kurali dort yere kopyalamak olurdu.
    op.execute(
        f"""
        -- KRIPTOGRAFIK RASTGELELIK ZORUNLU: `random()` tohumlanmis bir
        -- PRNG'dir ve bir tesisin kodunu goren biri digerlerini tahmin
        -- edebilir. Kerem daire sahipligi dogrulamasini KAPATTIGI icin
        -- (bkz. P148) bu kod, daire verisini koruyan TEK denetim —
        -- tahmin edilebilir olmamali. pgcrypto zaten kurulu (0001).
        CREATE OR REPLACE FUNCTION public.gen_kayit_kodu() RETURNS text
        LANGUAGE sql VOLATILE AS $$
            SELECT string_agg(
                substr('{_ALFABE}',
                       1 + (get_byte(b, i) % length('{_ALFABE}')), 1), '')
            FROM (SELECT gen_random_bytes(8) AS b) s,
                 generate_series(0, 7) AS i;
        $$;
        """
    )
    op.add_column("tenant", sa.Column("kayit_kodu", sa.Text(), nullable=True))
    # Mevcut tesislere kod URET: sutun NOT NULL yapilacaksa once dolmali.
    # `gen_random_uuid()` tabanli, alfabeye indirgenmis 8 karakter.
    op.execute(
        f"""
        UPDATE tenant SET kayit_kodu = (
            SELECT string_agg(
                substr('{_ALFABE}',
                       1 + (get_byte(sha, i) % length('{_ALFABE}')), 1), '')
            FROM generate_series(0, 7) AS i,
                 LATERAL (SELECT digest(id::text || 'kayit', 'sha256') AS sha) d
        )
        WHERE kayit_kodu IS NULL;
        """
    )
    op.alter_column(
        "tenant", "kayit_kodu", nullable=False,
        server_default=sa.text("public.gen_kayit_kodu()"),
    )
    op.create_unique_constraint("uq_tenant_kayit_kodu", "tenant", ["kayit_kodu"])

    op.create_table(
        "kayit_dogrulama",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("tenant_id", UUID(as_uuid=True),
                  sa.ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False),
        sa.Column("unit_id", UUID(as_uuid=True), nullable=False),
        sa.Column("telefon", sa.Text(), nullable=False),
        # Kod DUZ METIN tutulmaz — giris kodlariyla ayni kural.
        sa.Column("kod_hash", sa.Text(), nullable=False),
        sa.Column("son_gecerlilik", sa.DateTime(timezone=True), nullable=False),
        # Deneme sayaci: kaba kuvvet 6 haneli kodu dakikalar icinde bulur.
        sa.Column("deneme", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    # Telefon basina TEK bekleyen kayit: yeni istek eskisini EZER, yoksa
    # ayni numaraya art arda kod isteyip hepsini gecerli birakmak olurdu.
    op.create_unique_constraint(
        "uq_kayit_dogrulama_telefon", "kayit_dogrulama", ["telefon"]
    )

    # RLS BOOTSTRAP: kayit ucu OTURUMSUZ cagrilir, yani tenant baglami
    # HENUZ YOK. `tenant_id_by_slug` ile AYNI desen — SECURITY DEFINER
    # fonksiyon yalnizca kod -> tenant_id cevirir, baska hicbir sey
    # dondurmez (tesis adi bile ayri ve YETKILI okunur).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_id_by_kayit_kodu(p_kod text)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = public
        AS $$
            SELECT id FROM tenant WHERE upper(kayit_kodu) = upper(p_kod)
        $$;
        """
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.tenant_id_by_kayit_kodu(text);")
    op.execute("DROP FUNCTION IF EXISTS public.gen_kayit_kodu();")
    op.drop_table("kayit_dogrulama")
    op.drop_constraint("uq_tenant_kayit_kodu", "tenant", type_="unique")
    op.drop_column("tenant", "kayit_kodu")
