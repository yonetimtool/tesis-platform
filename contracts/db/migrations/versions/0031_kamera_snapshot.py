"""kamera_snapshot (0031) — izgarada canli karo icin DURAGAN kare adresi.

MASTER-PLAN P121. Kerem izgarada oynatici acmadan canli goruntu istiyor.

NEDEN OYNATICI DEGIL: bir izgarada N video oynaticiyi otomatik oynatmak
pil/isi/bant genisligi acisindan pahalidir ve iOS es zamanli AVPlayer
sayisini SINIRLAR — altinci-yedinci karo sessizce siyah kalirdi. Cozum
durağan kare: karo 5-10 sn'de bir tek bir JPEG ceker.

NEDEN AYRI KOLON:
  * `stream_url` kameranin KENDI adresidir (rtsp olabilir; goruntu degil),
  * `restream_url` gecidin OYNATILABILIR yayinidir (HLS; yine video),
  * `snapshot_url` TEK KARE dondurur (image/jpeg).
Uc adres uc AYRI seydir; Frigate'in `/api/<kamera>/latest.jpg` ucu tam olarak
bu ucuncusudur ve P17'de doldurulacaktir. Tek kolona sikistirmak, gecit
yeniden kurulunca hangisinin ne oldugunu kaybetmek demekti.

BACKEND YAYINI/KARESI HIC CEKMEZ — SSRF yuzeyi yoktur (kamera modulunun
kurulusundaki karar korunur). Kareyi ISTEMCI ceker.

SEMA KISITI `restream_url` ile AYNI GEREKCE: yalniz http(s). `rtsp://` bir
kare adresi olamaz; istemci onu <img> gibi cekemez ve karo sessizce bos
kalirdi.

URETIM: additive + geriye-uyumlu. Mevcut satirlar `snapshot_url IS NULL`
kalir; hicbir sorgu/istemci bozulmaz — kare yoksa karo bugunku yer
tutucuyu gostermeye devam eder.

Revision ID: 0031_kamera_snapshot
Revises: 0030_demo_mod
"""
from __future__ import annotations

from alembic import op

revision = "0031_kamera_snapshot"
down_revision = "0030_demo_mod"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE camera ADD COLUMN snapshot_url text;")
    op.execute(
        """
        ALTER TABLE camera ADD CONSTRAINT ck_camera_snapshot_sema
            CHECK (snapshot_url IS NULL OR snapshot_url ~ '^https?://');
        """
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE camera DROP CONSTRAINT IF EXISTS ck_camera_snapshot_sema;"
    )
    op.execute("ALTER TABLE camera DROP COLUMN IF EXISTS snapshot_url;")
