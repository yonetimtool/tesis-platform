"""(P238) CIHAZ KAYDINA UYGULAMA SURUMU — YALNIZ VERI TOPLAMA.

===========================================================================
NEDEN SIMDI, PUSH MANTIGI OLMADAN
===========================================================================
Hedef: "asgari surum yukseltildiginde ESKI SURUMDEKI cihazlara tek
seferlik bildirim". O mantik BU GOCTE YOK ve bilincli olarak yok — 1.5.0'a
birakildi (`docs/P238-kararlar.md` §2).

Kolon yine de BUGUN aciliyor, cunku bir cihaz surumunu ancak O ALANI
GONDEREN bir yapimi calistirdiginda bildirir. Bugun acilmazsa 1.5.0
geldiginde 1.4.x istemciler de gorunmez olur ve ayni sorun bir tur sonra
tekrarlanir. Yani: veri toplamaya bugun baslanir, mantik sonra yazilir.

===========================================================================
NULLABLE VE KALICI OLARAK NULLABLE
===========================================================================
Alani gondermeyen surumler sahada calisiyor (`dil` ve `cihaz_kimligi` ile
ayni gerekce). "Surumu bilinmeyen cihaz" gecerli bir durumdur ve
1.5.0'daki hedefleme sorgusu onu ELEMEK zorunda kalacak — bu bir kusur
degil, olcumun dogal siniri.

===========================================================================
INDEKS YOK
===========================================================================
Bu kolon bugun HICBIR SORGUDA SUZGEC DEGIL. Indeksi simdi eklemek,
kullanilmayan bir yapiyi her INSERT/UPDATE'te guncellemek olurdu.
Hedefleme sorgusu yazildiginda (1.5.0) olculur ve gerekiyorsa o zaman
eklenir.

===========================================================================
KVKK
===========================================================================
Uygulama surumu KISISEL VERI DEGIL; cihazin teknik meta verisidir ve
kayit zaten `platform`, `dil`, `cihaz_kimligi` tasiyor. Yeni bir riza
gerekmiyor; saklama suresi cihaz kaydiyla AYNI (cihaz silinince gider).
"""
from alembic import op

revision = "0138_cihaz_uygulama_surumu"
down_revision = "0137_anket_hedef_kitle_anonim"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE user_device ADD COLUMN uygulama_surum text;")


def downgrade() -> None:
    op.execute("ALTER TABLE user_device DROP COLUMN IF EXISTS uygulama_surum;")
