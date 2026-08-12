"""(P155 / §7) DAVET JETONU — tek kullanimlik, sureli kayit bagi.

===========================================================================
NE ISE YARAR
===========================================================================
Yonetici sakin/personel eklediginde, kisiye jetonlu bir kayit bagi gider:
    https://test.yonetio.site/davet/<jeton>
Jeton cozuldugunde TESIS, ROL, DAIRE ve TELEFON ZATEN bellidir; kullanici
yalniz yontem secer (Google/Microsoft/Apple/parola) ve gerekirse adini
duzeltir. Tesis kodu + daire no ekrani ATLANIR.

===========================================================================
JETON DUZ METIN SAKLANMAZ — HASH SAKLANIR
===========================================================================
Bagi goren herkes o daire adina kaydolabilecegi icin jeton bir SIRDIR.
Sema'da `jeton_hash` (sha256 hex) tutulur; duz jeton yalniz baglantida ve
yalniz bir kez uretilir. Veritabani sizsa bile jetonlar geri uretilemez —
parola hash'i ile ayni ilke.

===========================================================================
KISITLAR (kararlar davet.py + rol_secimli_kayit turunda gerekcelendirildi)
===========================================================================
* KULLANICI BASINA TEK davet (`uq_davet_user`): yeniden gonderim AYNI
  satiri tazeler (yeni jeton_hash + yeni son_gecerlilik), yeni satir
  acmaz. Boylece panel her zaman GUNCEL durumu gosterir.
* `jeton_hash` GLOBAL benzersiz (`uq_davet_jeton`): cozme tenant baglami
  OLMADAN, hash ile yapilir (kullanicinin henuz oturumu yok).
* `used_at` DOLDUGUNDA jeton olur: kayit tamamlaninca (parola belirlendi
  ya da sosyal kimlik baglandi) yazilir. COZME jetonu TUKETMEZ — bag
  tarayicida acilip sonra uygulamada da acilabilmeli.

DAVET COZUMU RLS'I ASAR (`davet_coz`, SECURITY DEFINER): kullanici henuz
hicbir tenant baglami tasimadan jetonu cozer. `kayit_dogrulama`nin goc
0042'deki deseninin aynisi.
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ENUM, UUID

revision = "0051_davet_jetonu"
down_revision = "0050_tesis_kodu_panelde"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.create_table(
        "davet",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("tenant_id", UUID(as_uuid=True),
                  sa.ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False),
        # Davetin ait oldugu (parolasiz) hesap. Silinirse davet de gider.
        sa.Column("user_id", UUID(as_uuid=True), nullable=False),
        sa.Column("jeton_hash", sa.Text(), nullable=False),
        sa.Column("son_gecerlilik", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        # Panel "gitmeyen davetler" gorunumu icin SON gonderim ozeti.
        # Ayrintili gecmis `mesaj_gonderim` tablosunda; buradaki ozet
        # yoneticinin tek bakista gormesi icindir. ENUM tipleri 0021'de
        # var; `create_type=False` ile YENIDEN YARATILMAZ (0043'te olculdu:
        # aksi halde ikinci bir CREATE TYPE uretilir).
        sa.Column("son_kanal", ENUM(name="mesaj_kanal", create_type=False),
                  nullable=True),
        sa.Column("son_durum", ENUM(name="mesaj_durum", create_type=False),
                  nullable=True),
        sa.Column("son_hata", sa.Text(), nullable=True),
        sa.Column("son_gonderim_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("olusturan_id", UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        # TENANT'LI BILESIK FK — 0001 deseni; satirin tenant'i ile
        # kullanicinin tenant'i ayrisamaz.
        sa.ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            name="fk_davet_user",
            ondelete="CASCADE",
        ),
    )

    # Kullanici basina TEK davet (yeniden gonderim tazeler).
    op.create_index("uq_davet_user", "davet", ["user_id"], unique=True)
    # Hash ile GLOBAL cozme (tenant baglami olmadan).
    op.create_index("uq_davet_jeton", "davet", ["jeton_hash"], unique=True)
    # `tenant_id` FK'sinin oncu-kolon indeksi (test_indeks_kapsam arar).
    op.create_index("ix_davet_tenant", "davet", ["tenant_id"])

    op.execute("ALTER TABLE public.davet ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE public.davet FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY davet_isolation ON public.davet
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON public.davet TO {APP_ROLE};"
    )

    # --- PUBLIC COZME (RLS bypass) — kullanicinin henuz oturumu yok ---
    # Jeton_hash ile davet + baglam doner. tenant/rol/daire/telefon/ad.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.davet_coz(p_jeton_hash text)
        RETURNS TABLE(
            davet_id uuid, tenant_id uuid, tenant_ad text, user_id uuid,
            rol text, ad text, telefon text, daire_no text,
            son_gecerlilik timestamptz, used_at timestamptz,
            password_set boolean, is_active boolean)
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT d.id, d.tenant_id, t.ad, d.user_id,
                   u.role::text, u.ad, u.telefon, ur_unit.no,
                   d.son_gecerlilik, d.used_at,
                   u.password_set, u.is_active
            FROM public.davet d
            JOIN public.tenant t ON t.id = d.tenant_id
            JOIN public.app_user u ON u.id = d.user_id
            -- Sakinin AKTIF daire bagini (varsa) getir; digerlerinde NULL.
            LEFT JOIN LATERAL (
                SELECT un.no
                FROM public.unit_resident r
                JOIN public.unit un ON un.id = r.unit_id
                WHERE r.user_id = u.id AND r.bitis IS NULL
                ORDER BY r.created_at
                LIMIT 1
            ) ur_unit ON true
            WHERE d.jeton_hash = p_jeton_hash;
        $$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.davet_coz(text) FROM PUBLIC;")
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.davet_coz(text) TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.davet_coz(text);")
    op.drop_table("davet")
