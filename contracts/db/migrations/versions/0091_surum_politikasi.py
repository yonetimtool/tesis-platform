"""(P202) Zorunlu guncelleme — PLATFORM BASINA SURUM POLITIKASI.

===========================================================================
NEDEN TABLO, NEDEN ORTAM DEGISKENI DEGIL
===========================================================================
Politika, YENI SURUM YAYINLAMADAN degistirilebilmeli (istek §2). Ortam
degiskeni bunu saglamaz: her degisiklik `api`nin yeniden kurulmasini
ister ve platform yoneticisinin elinde bir dugme olmaz. Tablo, panel
uzerinden duzenlenebilir.

===========================================================================
NEDEN `tenant_id` YOK — ve bu neden GUVENLI
===========================================================================
Surum politikasi PLATFORM GENELIDIR: magazadaki paket tektir, tesise
gore degismez. `tenant_id` koymak, ayni gercegin tesis sayisi kadar
kopyasini uretirdi.

Bu yuzden tabloda RLS YOKTUR. Sizinti riski de yoktur: satirlar hicbir
tesise ait olmayan, zaten magazada herkese acik olan sayilardir
(en son surum numarasi). Okuma ucu de bilincli olarak PUBLIC'tir —
gerekce `routers/surum.py` basliginda.

`tenant_id` tasimadigi icin `test_tesis_izolasyonu_tarama.py`nin sema
kapisina da GIRMEZ (o kapi yalniz `tenant_id` tasiyan tablolari sorar).

===========================================================================
IKI ESIK, TEK SATIR
===========================================================================
`asgari_surum`  — bunun ALTI kullanilamaz (ZORUNLU).
`onerilen_surum`— bunun ALTI uyarilir ama kullanmaya DEVAM EDER.

Ikisi de BOS olabilir ve BOS = O SEVIYE KAPALI. Varsayilan olarak ikisi
de bostur: goc uygulanir uygulanmaz kimse kilitlenmez. Bir guncelleme
politikasinin, kimse ondan haberdar olmadan yururluge girmesi
kabul edilemez.

`mesaj` JSONB: dil kodu -> metin (7 dil). BOS BIRAKILABILIR; o zaman
uygulama KENDI yerellestirilmis metnini kullanir. Operatorun ozelligi
kullanabilmek icin yedi dili doldurmak zorunda kalmasi, ozelligi
kullanilmaz yapardi.

Geri alinabilir: `downgrade` tabloyu dusurur.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

APP_ROLE = "app_rw"

revision = "0091_surum_politikasi"
down_revision = "0090_kurulum_otomasyon_karari"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "surum_politikasi",
        # PLATFORM BIRINCIL ANAHTAR: 'ios' | 'android'. Ayri bir `id`
        # sutunu "hangi satir gecerli" sorusunu dogururdu.
        sa.Column("platform", sa.Text(), primary_key=True),
        sa.Column("asgari_surum", sa.Text(), nullable=True),
        sa.Column("onerilen_surum", sa.Text(), nullable=True),
        sa.Column(
            "mesaj",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "platform IN ('ios','android')", name="ck_surum_politikasi_platform"
        ),
    )
    # IKI SATIR BOS DEGERLERLE ACILIR: panel ekrani "kayit yok" durumunu
    # ayrica ele almak zorunda kalmasin. Bos esik = o seviye KAPALI.
    op.execute(
        "INSERT INTO surum_politikasi (platform) VALUES ('ios'), ('android')"
    )
    # Uygulama rolu OKUR; YAZMA da ayni rolden gecer (uc admin kapisinda).
    op.execute(f"GRANT SELECT, INSERT, UPDATE ON surum_politikasi TO {APP_ROLE};")


def downgrade() -> None:
    op.drop_table("surum_politikasi")
