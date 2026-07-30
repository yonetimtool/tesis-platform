"""devriye_okutma_indeksi (0010) — (tenant_id, checkpoint_id, okutma_zamani).

Tur 78'de olculdu. Tur 77'nin tarama olcumu YALNIZ 8 tabloya hacim yaziyordu;
kalan ~40 tablo bos oldugu icin onlarin uzerinden gecen uclar SESSIZ kaliyordu.
Hacim tum semaya yayilinca yeni bir sinif ortaya cikti:

  GET /dashboard/live  ->  scan_event = 200.000 satir SIRALI okuma

`_AKTIF_TURLAR_SQL` okutmalari `s.checkpoint_id = c.id AND s.okutma_zamani
>= w.pencere_baslangic AND s.okutma_zamani < w.pencere_bitis` ile birlestiriyor.
Mevcut indeksler bu erisimi karsilamiyordu:
  * `ix_scan_checkpoint (checkpoint_id)` — zaman araligini TASIMIYOR, bir
    checkpoint'in TUM gecmisini getirir,
  * `ix_scan_okutma_zamani (tenant_id, okutma_zamani DESC)` — checkpoint'e gore
    daraltmiyor.
Planlayici bu yuzden `scan_event`i tamamen tariyordu.

OLCUM (200 bin okutma, 1434 bugunku pencere):
    seq scan  784,9 ms   ->   Index Only Scan  43,7 ms   (~18x)

AYNI ERISIM DESENI UC YERDE:
  * `app/routers/dashboard.py`   — panel canli ozeti (POLLANAN uc),
  * `app/routers/me_patrol.py`   — gorevlinin kendi penceresi,
  * `app/scheduler/service.py`   — pencere tespiti, checkpoint BASINA
    `okutma_zamani >= %s AND okutma_zamani < %s LIMIT 1` (periyodik is).
Tek indeks ucunu de karsilar; zaman en sonda oldugu icin aralik taramasi
indeksin son kolonunda kalir.

`ix_scan_checkpoint` KALDIRILMADI: bu indeks `(checkpoint_id)` ile basliyor ve
tenant baglami OLMADAN calisan yollar (owner baglantisiyla kosan bakim
sorgulari) icin hala tek secenek.

Revision ID: 0010_devriye_okutma_indeksi
Revises: 0009_akis_indeksleri
"""
from __future__ import annotations

from alembic import op

revision = "0010_devriye_okutma_indeksi"
down_revision = "0009_akis_indeksleri"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_scan_checkpoint_zaman "
        "ON scan_event (tenant_id, checkpoint_id, okutma_zamani);"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_scan_checkpoint_zaman;")
