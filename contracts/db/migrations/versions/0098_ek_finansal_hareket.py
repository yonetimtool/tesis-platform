"""(P206 §4.3) EK VARLIK TIPI: `finansal_hareket` — GIDER FISI.

===========================================================================
NEDEN
===========================================================================
Mobil gider kaydinda fisin fotografini eklemek, sahada olan TEK kanit
parcasini kaydin yanina koyar. Nakit gider site muhasebesinde en cok
tartisilan kalemdir ve "fis nerede" sorusu her denetimde sorulur.

AYRI TABLO ACILMADI: ek mekanizmasi (goc 0043) zaten var ve yetki
kumesini ILGILI ROUTERDAN okuyor. Yeni bir "gider eki" tablosu, ayni
kurallari (kim okur, kim yazar, dosya nasil saklanir) ikinci kez
yazmak olurdu.

CHECK KISITI ROUTER'LA AYNI KUMEYI TUTAR: `test_ekler.py::
test_varlik_tipleri_GOCLE_AYNI` iki yonde de ayrismayi yakaliyor —
routerda olup CHECK'te olmayan tip 500 verir, tersi ise HIC
kullanilamaz.
"""
from alembic import op

revision = "0098_ek_finansal_hareket"
down_revision = "0097_iban_ulke_bagimsiz"
branch_labels = None
depends_on = None

_TIPLER = [
    "unit", "app_user", "task", "icra_dosyasi", "tenant_dokuman",
    "complaint", "firma", "building_block",
]
_YENI = _TIPLER + ["finansal_hareket"]


def _kisit(tipler: list[str]) -> str:
    dizi = ", ".join(f"'{t}'::text" for t in tipler)
    return f"varlik_tipi = ANY (ARRAY[{dizi}])"


def upgrade() -> None:
    op.execute("ALTER TABLE varlik_eki DROP CONSTRAINT IF EXISTS ck_varlik_eki_tipi;")
    op.execute(
        "ALTER TABLE varlik_eki ADD CONSTRAINT ck_varlik_eki_tipi "
        f"CHECK ({_kisit(_YENI)});"
    )


def downgrade() -> None:
    # GERI DONUSTE gider ekleri kisiti ihlal eder: once SILINIR.
    # Sessizce birakmak `ALTER TABLE`i patlatir ve gocu yarida keserdi.
    op.execute("DELETE FROM varlik_eki WHERE varlik_tipi = 'finansal_hareket';")
    op.execute("ALTER TABLE varlik_eki DROP CONSTRAINT IF EXISTS ck_varlik_eki_tipi;")
    op.execute(
        "ALTER TABLE varlik_eki ADD CONSTRAINT ck_varlik_eki_tipi "
        f"CHECK ({_kisit(_TIPLER)});"
    )
