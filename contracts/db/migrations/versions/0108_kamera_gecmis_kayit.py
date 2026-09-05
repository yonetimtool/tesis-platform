"""(P213 §6) GECMIS KAYIT (NVR/DVR) ERISIM ALANLARI.

===========================================================================
KARAR: KAYIT BIZDE DEGIL, SITENIN NVR'INDA KALIR
===========================================================================
Kaydi kendimiz tutma secenegi (MediaMTX `record`) OLCULDU ve REDDEDILDI:
2 Mbit/s'lik tek kamera ~21 GB/gun, ~650 GB/ay; 8 kamerali bir site 30 gun
saklama isterse ~5 TB. Site zaten yerinde 30 gun tutan bir NVR'a para
vermis durumda — ayni veriyi buluta ikinci kez tasimak hem faturayi hem
KVKK yuzeyini ikiye katlardi. Ayrintili karsilastirma:
`docs/P213-06-gecmis-kayit-analiz.md`.

Bu goc, o karara gore YALNIZ ERISIM bilgisini saklar.

===========================================================================
ALANLAR ve NEDEN BOYLE
===========================================================================
`kayit_aktif`  : KAMERA BASINA, VARSAYILAN KAPALI. Gecmis kayit geriye
                 donuk gozetimdir; hicbir tesiste "kendiliginden acik"
                 gelmemeli.
`kayit_saglayici`: `sablon` | `hikvision` | `dahua`. ENUM DEGIL METIN —
                 yeni marka eklemek goc gerektirmesin. Taninmayan deger
                 adaptor secilirken reddedilir (fail-closed), yani metin
                 olmasi bir gevseklik degil.
`kayit_adres`  : NVR HTTP tabani. BOS ise `stream_url`in konagi kullanilir
                 (cogu kurulumda kamera ile NVR ayni cihaz).
`kayit_kanal`  : marka basina anlami degisen kanal kimligi (Hikvision
                 `101`, Dahua `1`).
`kayit_kullanici` / `kayit_parola_sifreli`:
                 NVR YONETIM kimligi — canli yayin kimliginden AYRI
                 saklanir, cunku arama API'si genelde daha yetkili bir
                 hesap ister. Parola AES-GCM (app/crypto.py); GET
                 yanitlarinda ASLA donmez.

GERI ALINABILIR: `downgrade` alti sutunu da dusurur. Sifreli parolalar
geri alinmada COZULMEZ — geri alma bu ozelligi kapatmak demektir ve
parolayi bir yere duz yazmak, kapatma isleminin en kotu yan etkisi
olurdu.
"""
from alembic import op
import sqlalchemy as sa

revision = "0108_kamera_gecmis_kayit"
down_revision = "0107_kamera_kimlik_ayrimi"
branch_labels = None
depends_on = None

_SUTUNLAR = (
    ("kayit_saglayici", sa.Text()),
    ("kayit_adres", sa.Text()),
    ("kayit_kanal", sa.Text()),
    ("kayit_kullanici", sa.Text()),
    ("kayit_parola_sifreli", sa.Text()),
)


def upgrade() -> None:
    op.add_column(
        "camera",
        sa.Column("kayit_aktif", sa.Boolean(), nullable=False,
                  server_default=sa.text("false")),
    )
    for ad, tur in _SUTUNLAR:
        op.add_column("camera", sa.Column(ad, tur, nullable=True))


def downgrade() -> None:
    for ad, _ in _SUTUNLAR:
        op.execute(f"ALTER TABLE camera DROP COLUMN IF EXISTS {ad};")
    op.execute("ALTER TABLE camera DROP COLUMN IF EXISTS kayit_aktif;")
