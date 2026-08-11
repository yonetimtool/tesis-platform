"""(P154 / Asama 8) ICE AKTARIM CATISI — kosum kaydi + GERI ALMA izi.

===========================================================================
NEDEN IKI TABLO
===========================================================================
Brief: "Akis: sablon indirme → yukleme → kolon esleme → dogrulama →
ONIZLEME → islem icinde aktarim → hata raporu → GERI ALMA."

Bugun `/site-aktar` bu akisin ALTISINI karsiliyor; eksik olan **kolon
esleme** ve **GERI ALMA**. Geri alma, "bu kosumda NE YARATILDI" sorusunu
yanitlayabilmeyi gerektirir — ve bu bilgi hicbir yerde durmuyor.

  * `ice_aktarim`      — kosumun KENDISI (tur, sayimlar, durum, kim).
  * `ice_aktarim_kayit` — o kosumda yaratilan HER SATIRIN izi.

===========================================================================
NEDEN IZ TABLOSU, NEDEN HEDEF TABLOLARA "aktarim_id" SUTUNU DEGIL
===========================================================================
Alternatif, ice aktarilan her tabloya (`building_block`, `unit`,
`app_user`, `unit_resident`, `arac_kayit`, `finansal_hareket`...) bir
`aktarim_id` sutunu eklemekti. Reddedildi:

  * ALTI TABLOYA GOC demekti ve her yeni ice aktarim turu YENI BIR GOC
    gerektirirdi — oysa tur eklemek uygulama bilgisidir,
  * o sutunlar ice aktarilmamis satirlarda SONSUZA KADAR bos dururdu,
  * ve en onemlisi: `finansal_hareket` gibi DEFTER tablolarina "bunu bir
    dosya yazdi" bilgisini gomerdi; defterin isi para hareketini
    anlatmaktir, nereden geldigini degil.

Iz tablosu bu bilgiyi DISARIDA tutar: hedef tablolar hic degismez.

===========================================================================
GERI ALMA HEP YA DA HIC
===========================================================================
`ice_aktarim_kayit` satirlari `sira` ile saklanir ve geri alma TERS
SIRADA siler (once cocuk, sonra ebeveyn). Bir satir silinemiyorsa —
ornegin ice aktarilan daireye sonradan tahakkuk yazilmissa — TUM geri
alma duser ve kullaniciya bunun sebebi soylenir.

KISMI GERI ALMA YAPILMAZ ve bu bilincli: yarim geri alinmis bir aktarim,
kullanicinin "sildim" sandigi ama bir kismi duran bir veri birakirdi.
Silinemeyen satiri BILEREK tutup otekini silmek, veriyi tutarsiz bir ara
hâlde birakmaktir.

===========================================================================
KOSUM KAYDI SILINMEZ, DURUMU DEGISIR
===========================================================================
Geri alinan kosum tablodan SILINMEZ; `durum='geri_alindi'` olur. Silmek,
"bu dosya bir kez yuklendi ve geri alindi" gercegini yok etmek olurdu —
denetim izinin tam da anlatmasi gereken sey budur.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "0045_ice_aktarim"
down_revision = "0044_kurulum_atlanan"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

#: Ice aktarim TURLERI — brief'in oncelik sirasi. Kume CHECK ile kapali:
#: serbest metin, yazim hatasi olan bir turu sessizce kabul ederdi.
TURLER = ("daire", "kisi", "acilis_bakiye", "arac")

DURUMLAR = ("uygulandi", "geri_alindi")


def upgrade() -> None:
    op.create_table(
        "ice_aktarim",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("tenant_id", UUID(as_uuid=True),
                  sa.ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tur", sa.Text(), nullable=False),
        # Dosya adi KULLANICI ICINDIR: gecmis listesinde "hangi dosyaydi"
        # sorusunu yanitlar. Dosyanin KENDISI saklanmaz — icinde kisisel
        # veri olabilir ve saklamanin bir amaci yok (KVKK: veri en az).
        sa.Column("dosya_adi", sa.Text(), nullable=True),
        sa.Column("satir_sayisi", sa.Integer(), nullable=False,
                  server_default=sa.text("0")),
        sa.Column("olusan", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("atlanan", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("hatali", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("durum", sa.Text(), nullable=False,
                  server_default=sa.text("'uygulandi'")),
        sa.Column("olusturan_user_id", UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
        sa.Column("geri_alma_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_check_constraint(
        "ck_ice_aktarim_tur", "ice_aktarim",
        "tur IN (" + ", ".join(f"'{t}'" for t in TURLER) + ")",
    )
    op.create_check_constraint(
        "ck_ice_aktarim_durum", "ice_aktarim",
        "durum IN (" + ", ".join(f"'{d}'" for d in DURUMLAR) + ")",
    )
    op.create_index(
        "ix_ice_aktarim_tenant", "ice_aktarim", ["tenant_id", "created_at"],
    )

    op.create_table(
        "ice_aktarim_kayit",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("tenant_id", UUID(as_uuid=True),
                  sa.ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False),
        # KOSUM SILINIRSE IZ DE GIDER: iz tek basina anlamsizdir.
        sa.Column("aktarim_id", UUID(as_uuid=True),
                  sa.ForeignKey("ice_aktarim.id", ondelete="CASCADE"),
                  nullable=False),
        # Tablo adi METIN: FK yok cunku hedef ONLARCA tablodan biri
        # olabilir. Kume uygulama tarafinda kapali (routers/ice_aktarim.py)
        # — yeni bir tur eklemek GOC gerektirmemeli.
        sa.Column("tablo", sa.Text(), nullable=False),
        sa.Column("kayit_id", UUID(as_uuid=True), nullable=False),
        # YARATILMA SIRASI: geri alma TERS SIRADA siler (once cocuk, sonra
        # ebeveyn). Sirasiz silmek, FK yuzunden rastgele basarisiz olurdu.
        sa.Column("sira", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )
    # IKI FK, IKI INDEKS. Tabloda iki yabanci anahtar var (`tenant_id` ve
    # `aktarim_id`) ve ust satir silindiginde RI tetigi HER IKISI icin de
    # bu tabloyu tarar; oncu kolonu kapsamayan FK seq scan yer
    # (`test_indeks_kapsam` bunu iki kez yakaladi — once `tenant_id`
    # acikti, tek indeksi one alinca bu kez `aktarim_id` acikta kaldi).
    op.create_index(
        "ix_ice_aktarim_kayit_aktarim",
        "ice_aktarim_kayit", ["aktarim_id", "sira"],
    )
    op.create_index(
        "ix_ice_aktarim_kayit_tenant", "ice_aktarim_kayit", ["tenant_id"],
    )

    for tablo in ("ice_aktarim", "ice_aktarim_kayit"):
        op.execute(f"ALTER TABLE public.{tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE public.{tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_isolation ON public.{tablo}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
        op.execute(
            f"GRANT SELECT, INSERT, UPDATE, DELETE ON public.{tablo} TO {APP_ROLE};"
        )


def downgrade() -> None:
    for tablo in ("ice_aktarim_kayit", "ice_aktarim"):
        op.execute(f"DROP POLICY IF EXISTS {tablo}_isolation ON public.{tablo};")
    op.drop_index("ix_ice_aktarim_kayit_tenant", table_name="ice_aktarim_kayit")
    op.drop_index("ix_ice_aktarim_kayit_aktarim", table_name="ice_aktarim_kayit")
    op.drop_table("ice_aktarim_kayit")
    op.drop_index("ix_ice_aktarim_tenant", table_name="ice_aktarim")
    op.drop_table("ice_aktarim")
