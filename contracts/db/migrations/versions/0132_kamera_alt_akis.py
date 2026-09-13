"""(P230 §1) Kamera ALT AKIS adresi — H265 ana akis, H264 alt akis.

===========================================================================
OLCULEN DURUM: ZINCIR SUNUCUDA KOPMUYOR
===========================================================================
RTSP canli yayin zinciri adim adim olculdu (P230 §1):

  (b) API -> MediaMTX `/v3/paths/list`      : HTTP 200, 54 yol
  (c) MediaMTX -> RTSP kaynagi              : `[RTSP source] ready: 1 track (H265)`
  (d) HLS uretimi                           : index.m3u8 200,
                                              CODECS="hvc1.4.10.L63.9e.8",
                                              640x360@15, segmentler dolu
  (e) ISTEMCI COZME                         : KOPMA BURADA

Sunucu tarafi calisiyor. Kamera H265 yayin yapiyor ve masaustu
tarayicilarin cogu (Chrome donanima gore, Firefox cogu kurulumda) HEVC'yi
MSE uzerinden cozemiyor.

===========================================================================
NEDEN YENI KOLON, `stream_url`I DEGISTIRMEK DEGIL
===========================================================================
Mevcut hata mesaji kullaniciya "adresi H264 alt akisla DEGISTIRIN" diyor.
Bu calisir ama BEDELI VAR: `stream_url` yalniz canli izleme icin
kullanilmiyor —

  * `GET /cameras/{id}/kare` izgara karesini ffmpeg ile ONDAN cekiyor,
  * NVR kayit oynatma ve kayit araliklari ONA bagli.

ffmpeg H265'i sorunsuz coozuyor; yani ana akisi alt akisla degistirmek,
COZULMESI GEREKMEYEN bir yerde cozunurlugu dusurmek olurdu. Iki adres
AYRI SAKLANIR: ana akis kare/kayit icin, alt akis CANLI izleme icin.

`restream_url`DEN AYRI: o, disaridaki bir gecidin (Frigate/go2rtc) HAZIR
HLS adresi. `alt_stream_url` kameranin KENDI ikinci RTSP akisidir ve
yine MediaMTX'ten gecer.
"""
from alembic import op
import sqlalchemy as sa

revision = "0132_kamera_alt_akis"
down_revision = "0131_gorev_tamamlandi_bildirimi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "camera",
        sa.Column("alt_stream_url", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("camera", "alt_stream_url")
