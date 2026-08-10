"""(P154 / Asama 6.4) NOT VE EK — her varliga takilabilen TEK sistem.

===========================================================================
NEDEN TEK TABLO, NEDEN HER MODULE AYRI
===========================================================================
Brief: "Not ve ek (attachment) sistemi ortak olacak, her varliga
takilabilsin (daire, kisi, gorev, icra, dokuman). Her modul icin ayri
dosya yukleme yazma."

Bugun yalnizca `complaint_photo` var: TEK bir varliga bagli, YALNIZ
gorsel tutan, kendi FK'sini tasiyan bir tablo. Ayni deseni sekiz modul
icin tekrarlamak sekiz tablo, sekiz uc ve sekiz yetki karari demekti —
ve biri unutuldugunda o modulde ek HIC olmazdi.

===========================================================================
POLIMORFIK BAG — FK YOK, ve bu bir TAKAS
===========================================================================
`(varlik_tipi, varlik_id)` ciftiyle baglaniyoruz. Bunun BEDELI acik:
veritabani bu bagi ZORLAYAMAZ, yani ust kayit silindiginde ek YETIM
kalir. Alternatif — her varlik icin ayri NULLABLE FK sutunu + "tam biri
dolu" CHECK'i — butunlugu verirdi ama yeni bir varlik turu eklemek her
seferinde GOC gerektirirdi ve "her varliga takilabilsin" maddesi tam da
bunu istemiyor.

BEDELI ODENMEDEN BIRAKILMADI, uc yerde karsilandi:
  * `varlik_tipi` bir CHECK ile SABIT KUMEYE kapali — serbest metin
    olsaydi yazim hatasi sessizce erisilemez bir ek uretirdi,
  * uc, ek yazmadan ONCE ust kaydin VAR OLDUGUNU ve cagiranin onu
    GOREBILDIGINI dogrular (bkz. routers/ekler.py),
  * yetim temizligi ust varligin silme yolunun sorumlulugundadir ve
    `docs/erp-yol-haritasi.md`e is olarak yazildi. Sessizce birakilmadi.

===========================================================================
NOT VE DOSYA AYNI TABLODA — `tur` ayrimiyla
===========================================================================
Ikisi de "bu kayda iliskin ek bilgi" ve ayni yetki kuralina tabi. Ayri
tablolar, listeleme ucunu ikiye bolerdi (kullanici notlari ve dosyalari
TEK bir zaman cizgisinde gormek ister).

`tur='not'` -> `metin` dolu, `dosya_key` bos.
`tur='dosya'` -> `dosya_key` dolu, `metin` opsiyonel (aciklama).
CHECK ikisini de zorunlu kiliyor; aksi hâlde "not" gorunumlu bos satirlar
birikirdi.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ENUM, UUID

revision = "0043_varlik_eki"
down_revision = "0042_kayit_dogrulama_rls"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

#: Ek takilabilen varliklar. CHECK ile kapali kume — serbest metin
#: birakmak, `unit` yerine `units` yazan bir cagiranin sessizce
#: erisilemez bir ek uretmesi demekti.
VARLIK_TIPLERI = (
    "unit", "app_user", "task", "icra_dosyasi", "tenant_dokuman",
    "complaint", "firma", "building_block",
)


def upgrade() -> None:
    op.execute(
        "CREATE TYPE ek_turu AS ENUM ('not', 'dosya');"
    )
    op.create_table(
        "varlik_eki",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("tenant_id", UUID(as_uuid=True),
                  sa.ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False),
        sa.Column("varlik_tipi", sa.Text(), nullable=False),
        sa.Column("varlik_id", UUID(as_uuid=True), nullable=False),
        # `postgresql.ENUM` — `sa.Enum` DEGIL. `create_type=False` YALNIZ
        # dialekt tipinde gecerli; `sa.Enum`da SESSIZCE yok sayiliyor ve
        # `create_table` ikinci bir `CREATE TYPE` uretiyor:
        #   [SQL: CREATE TYPE ek_turu AS ENUM ()]  -> "already exists"
        # (olculdu). 0038/0039 `sa.Enum(name=..., create_type=False)`
        # kullaniyor ama onlar `alter_column` icinde — orada CREATE TYPE
        # hic uretilmiyor, o yuzden fark gorunmuyordu.
        sa.Column("tur", ENUM(name="ek_turu", create_type=False), nullable=False),
        sa.Column("metin", sa.Text(), nullable=True),
        sa.Column("dosya_key", sa.Text(), nullable=True),
        sa.Column("dosya_adi", sa.Text(), nullable=True),
        # Kim ekledi — notun sahibi gorunmeli; "kim yazdi" bilinmeyen bir
        # not, kayit defterinde ise yaramaz.
        sa.Column("olusturan_user_id", UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("now()")),
    )

    op.create_check_constraint(
        "ck_varlik_eki_tipi",
        "varlik_eki",
        "varlik_tipi IN ("
        + ", ".join(f"'{t}'" for t in VARLIK_TIPLERI)
        + ")",
    )
    # ICERIK ZORUNLU: `tur`a gore dolu olmasi gereken alan bos gecilemez.
    # Aksi hâlde ekranda "not" gorunumlu bos satirlar birikirdi.
    op.create_check_constraint(
        "ck_varlik_eki_icerik",
        "varlik_eki",
        "(tur = 'not' AND metin IS NOT NULL AND length(btrim(metin)) > 0) "
        "OR (tur = 'dosya' AND dosya_key IS NOT NULL)",
    )

    # LISTELEME INDEKSI: her okuma `(tenant, varlik_tipi, varlik_id)` ile
    # gelir. Onsuz her ek listesi tam tarama olurdu.
    op.create_index(
        "ix_varlik_eki_varlik",
        "varlik_eki",
        ["tenant_id", "varlik_tipi", "varlik_id", "created_at"],
    )

    # RLS — 0001'deki desenin aynisi. FORCE olmadan tablo SAHIBI
    # politikalari atlar ve `test_rls_kapsam` bunu (hakli olarak) kusur
    # sayar.
    op.execute("ALTER TABLE public.varlik_eki ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE public.varlik_eki FORCE ROW LEVEL SECURITY;")
    op.execute(
        """
        CREATE POLICY varlik_eki_isolation ON public.varlik_eki
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON public.varlik_eki TO {APP_ROLE};")


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS varlik_eki_isolation ON public.varlik_eki;")
    op.drop_index("ix_varlik_eki_varlik", table_name="varlik_eki")
    op.drop_table("varlik_eki")
    # TIP TABLODAN SONRA: sutun hâlâ ona bagliyken `DROP TYPE` patlar.
    op.execute("DROP TYPE IF EXISTS ek_turu;")
