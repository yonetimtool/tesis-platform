"""kamera_restream (0012) — RTSP kameralarin OYNATILABILIR hale gelmesi.

MASTER-PLAN P17. Bugune kadar `tur='rtsp'` bir kamera KAYDEDILEBILIYOR ama
telefon onu NATIVE oynatamiyordu (`oynatilabilir=false`). Sahadaki IP
kameralarin ezici cogunlugu RTSP konustugu icin bu, kamera modulunun en buyuk
pratik bosluguydu.

P15'te OLCULDU: Frigate'in icindeki go2rtc kameranin RTSP'sini alip HLS/WebRTC
olarak YENIDEN YAYINLIYOR ve bu yayin oynatilabilir
(`h264 / 1280x720 / 10 fps`, ffprobe ile dogrulandi). Yani cozum istemcide
degil, MIMARIDE: kayda opsiyonel bir `restream_url` eklenir.

  * `restream_url` DOLU ise istemci ONU oynatir → `oynatilabilir=true`
    (kameranin `tur`u rtsp olsa bile).
  * BOS ise davranis DEGISMEZ (rtsp → oynatilamaz).

Neden yeni bir KOLON, `stream_url`i degistirmek degil: iki adres AYRI seylerdir
ve ikisi de gereklidir. `stream_url` kameranin KENDI adresidir (envanter,
Frigate yapilandirmasi, saha teshisi); `restream_url` gecidin adresidir ve
gecit yeniden kurulunca DEGISIR. Tek kolona sikistirmak, restream bozulunca
kameranin gercek adresini KAYBETMEK demekti.

GUVENLIK: `restream_url` yalnizca http(s) olabilir (istemci HLS oynatir);
`ck_camera_restream_sema` bunu semada zorlar. Backend yayini HIC cekmez —
SSRF yuzeyi yoktur (kamera modulunun kurulusundaki karar).

URETIM: additive + geriye-uyumlu. Mevcut satirlar `restream_url IS NULL`
kalir; hicbir sorgu/istemci bozulmaz.

Revision ID: 0012_kamera_restream
Revises: 0011_anpr_ingest
"""
from __future__ import annotations

from alembic import op

revision = "0012_kamera_restream"
down_revision = "0011_anpr_ingest"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE camera ADD COLUMN restream_url text;")
    op.execute(
        """
        ALTER TABLE camera ADD CONSTRAINT ck_camera_restream_sema
            CHECK (restream_url IS NULL OR restream_url ~ '^https?://');
        """
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE camera DROP CONSTRAINT IF EXISTS ck_camera_restream_sema;"
    )
    op.execute("ALTER TABLE camera DROP COLUMN IF EXISTS restream_url;")
