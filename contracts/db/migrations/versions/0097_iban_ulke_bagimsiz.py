"""(P206 §3.1) IBAN KISITI ULKE BAGIMSIZ — `^TR[0-9]{24}$` KALKTI.

===========================================================================
NEDEN
===========================================================================
`ck_kasa_iban` yalniz TR IBAN'ina izin veriyordu. Iki ucta birden
yanlisti:

  * COK DAR: yurt disindaki bir tesis kendi IBAN'ini KAYDEDEMIYORDU ve
    hata "deger kisit ihlali" diyordu — kullanici NEDEN olmadigini
    anlayamazdi.
  * COK GEVSEK: "TR" + 24 rakamin HERHANGI biri gecerliydi; tek hanesi
    yanlis yazilmis bir IBAN kabul ediliyor, para YANLIS HESABA
    gidiyordu.

Yeni kisit YAPISALDIR ve dar olani UYGULAMADA yapilir:
  * VERITABANI: ISO 13616 genel bicimi (2 harf + 2 rakam + 11-30 alnum,
    toplam 15-34) — "bu alan bir IBAN'dir" demenin veritabaninda
    soylenebilecek en dogru hali.
  * UYGULAMA: ulke uzunlugu + MOD 97 saglama toplami (`app/iban.py`).
    Mod 97'yi CHECK icinde yazmak mumkun ama okunmaz bir ifade olurdu
    ve kural iki dilde iki kez bakim isterdi.

MEVCUT VERI: kayitli TR IBAN'lari yeni kisiti da SAGLAR (26 hane, iki
harf + iki rakam ile baslar) — veri donusumu GEREKMIYOR.
"""
from alembic import op

revision = "0097_iban_ulke_bagimsiz"
down_revision = "0096_vardiya_serbest_saat"
branch_labels = None
depends_on = None

_YENI = (
    "iban IS NULL OR iban ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$'"
)
_ESKI = "iban IS NULL OR iban ~ '^TR[0-9]{24}$'"


def upgrade() -> None:
    op.execute("ALTER TABLE kasa DROP CONSTRAINT IF EXISTS ck_kasa_iban;")
    op.execute(f"ALTER TABLE kasa ADD CONSTRAINT ck_kasa_iban CHECK ({_YENI});")


def downgrade() -> None:
    # GERI DONUSTE TR DISI IBAN'LAR KISITI IHLAL EDER: once temizlenir.
    # Sessizce birakmak, `ALTER TABLE`i patlatir ve gocu yarida keserdi.
    op.execute(
        "UPDATE kasa SET iban = NULL WHERE iban IS NOT NULL "
        "AND iban !~ '^TR[0-9]{24}$';"
    )
    op.execute("ALTER TABLE kasa DROP CONSTRAINT IF EXISTS ck_kasa_iban;")
    op.execute(f"ALTER TABLE kasa ADD CONSTRAINT ck_kasa_iban CHECK ({_ESKI});")
