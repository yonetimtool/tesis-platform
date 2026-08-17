"""(P167 Asama 6.3) DOKUMAN SAKLAMA — yumusak silme + gecelik supurme.

===========================================================================
BRIEF NE ISTIYOR, NE ISTEMIYOR
===========================================================================
Brief: "Dosyalar MinIO'da saklansin, retention politikasina dahil edilsin."

Bunu "yonetim dokumanlarini N ay sonra sil" diye okumak YANLIS olurdu ve
soylemekte fayda var: yonetim plani, butce, bilanco ve genel kurul
tutanagi KISISEL VERI DEGIL, tesisin KENDI ARSIVIDIR. KVKK'nin saklama
sinirlamasi kisisel veri icindir; site arsivini yasla silmek, mevzuatin
istemedigi bir kaybi yaratirdi (ve bu kayip GERI ALINAMAZ).

Gercek eksik baska bir yerdeydi ve olculebilir: `DELETE /dokumanlar/{id}`
kaydi siliyor ama MinIO objesini BIRAKIYORDU (bilincli bir karardi:
"yanlislikla silinen bir yonetim plani geri alinabilsin"). Sonuc: kaydi
silinmis her dosya depoda SONSUZA KADAR kaliyor — ve artik hicbir
uygulama yolundan erisilemedigi icin kimse farkina varmiyor.

===========================================================================
COZUM: YUMUSAK SILME + SUREYE BAGLI SUPURME
===========================================================================
`silindi_at` sutunu geliyor. Silme artik bu alani doldurur:

  * Kayit listeden KALKAR (kullanici icin silinmistir).
  * Obje ve satir bir SURE daha durur — "yanlislikla sildim" penceresi
    ARTIK GERCEKTEN VAR; onceki tasarimda kayit zaten yok oldugu icin
    dosyaya yalnizca depoya elle baglanan biri ulasabiliyordu.
  * Gecelik retention, suresi dolanlarin ONCE MinIO objesini sonra
    satirini siler (kargo/talep fotografiyla AYNI desen: depo
    erisilemezse satir O GECE silinmez, yani obje asla kayitsiz kalmaz).

Yani dokumanlar retention politikasina GIRDI — ama giren sey arsivin
kendisi degil, SILINMIS olanin artigi.

===========================================================================
INDEKS
===========================================================================
Liste sorgusu artik `silindi_at IS NULL` suzuyor ve supurme
`silindi_at < esik` ariyor. Ikisi de kismi indeksle karsilanir; tam
indeks, canli listenin cok daha sik okundugu bir tabloda gereksiz
genislik olurdu.
"""
from alembic import op

revision = "0060_dokuman_saklama"
down_revision = "0059_rapor_isi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE tenant_dokuman ADD COLUMN silindi_at timestamptz")
    # CANLI LISTE: silinmemis kayitlar, yeniden eskiye.
    op.execute(
        """
        CREATE INDEX ix_dokuman_canli
          ON tenant_dokuman (tenant_id, created_at DESC)
          WHERE silindi_at IS NULL
        """
    )
    # SUPURME: yalnizca silinmis kayitlar taranir.
    op.execute(
        """
        CREATE INDEX ix_dokuman_silinmis
          ON tenant_dokuman (silindi_at)
          WHERE silindi_at IS NOT NULL
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_dokuman_silinmis")
    op.execute("DROP INDEX IF EXISTS ix_dokuman_canli")
    op.execute("ALTER TABLE tenant_dokuman DROP COLUMN IF EXISTS silindi_at")
