"""akis_indeksleri (0009) — /activity birlesik akisinin dal indeksleri.

Tur 77'de olculdu: `GET /activity` 13 kaynagi `UNION ALL` ile birlestirip
LIMIT'i YALNIZ DIS sorguda uyguluyordu, yani Postgres her kaynagin TAMAMINI
materyalize edip siraliyordu. 200 bin `scan_event` + 100 bin `notification` +
50 bin `dues_payment` iceren bir olcum veritabaninda TEK istek 350 BIN satir
okuyordu (EXPLAIN ANALYZE: `Parallel Seq Scan on scan_event`, top-N heapsort
tum birlesim uzerinde).

Asil duzeltme router'da: siralama+LIMIT her DALA itildi (bkz.
`app/routers/activity.py`). Burada eksik DAL INDEKSLERI eklenir — her akis
parcasi kendi zaman kolonuna gore siralanir ve `(tenant_id, <zaman> DESC)`
indeksi olmayan alti dal, itme sonrasinda da tam tarama yapmaya devam ederdi:

  * dues_payment  (tenant_id, odeme_zamani DESC)      -> _AIDAT
  * unit_complaint(tenant_id, created_at DESC)        -> _SIKAYET
  * complaint     (tenant_id, updated_at DESC)        -> _TALEP
    (mevcut `ix_complaint_tenant_created` created_at uzerinde; akis
     `updated_at`e gore siralar)
  * visitor       (tenant_id, cikis_zamani DESC) KISMI -> _ZIYARETCI_CIKIS
  * kargo         (tenant_id, teslim_zamani DESC) KISMI -> _KARGO_TESLIM
  * vehicle_pass  (tenant_id, cikis_zamani DESC) KISMI -> _ARAC_CIKIS

Son ucu KISMI indekstir (`WHERE <kolon> IS NOT NULL`): ilgili dallar zaten
`IS NOT NULL` suzuyor ve acik ziyaret/kargo/gecis kayitlarinda kolon NULL'dur.

UC KOLONLU INDEKS GEREKMEZ (olculdu): siralama `(<zaman> DESC, id DESC)`
oldugu icin iki kolonlu indeks tam sirayi vermez; Postgres `Incremental Sort`
ile tamamlar. Planlayici bunu kucuk tabloda maliyetli bulup seq scan secebilir
— ama tablo buyudukce KENDILIGINDEN cevirir: `dues_payment` 50 binde seq scan,
ayni sorgu 200 binde `Incremental Sort + Index Scan` (21 satir okuyor). Yani
sorun olculebilir hale geldigi hacimde plan zaten dogru. 13 tabloya ucuncu
kolon eklemenin yazma maliyeti bu yuzden alinmadi.

ONCESINDE 0008b GELIR: bu revizyondaki `ix_visitor_tenant_cikis`
`visitor.cikis_zamani` kolonuna baglidir ve o kolon, ZATEN GOC ETMIS bir
veritabaninda (prod) YOKTU — kanonik 0001 dosyasina prod'un gocundan SONRA
yerinde eklenmisti. Prod `upgrade head` tam burada patliyordu. Eksigi kapatan
`0008b_uyum_yakalama` bu revizyondan ONCE kosmali; bu yuzden `down_revision`
0008 yerine 0008b'yi gosteriyor. (Bu degisiklik guvenli: 0009 hicbir
dagitilmis ortamda uygulanmamisti — prod'un basarisiz kosumu tek islemde
atomik geri alinmisti.)

Revision ID: 0009_akis_indeksleri
Revises: 0008b_uyum_yakalama
"""
from __future__ import annotations

from alembic import op

revision = "0009_akis_indeksleri"
down_revision = "0008b_uyum_yakalama"
branch_labels = None
depends_on = None

#: (indeks adi, tablo, kolonlar, kismi kosul)
_INDEKSLER = (
    ("ix_payment_tenant_odeme", "dues_payment", "tenant_id, odeme_zamani DESC", None),
    ("ix_unit_complaint_tenant_created", "unit_complaint",
     "tenant_id, created_at DESC", None),
    ("ix_complaint_tenant_updated", "complaint", "tenant_id, updated_at DESC", None),
    ("ix_visitor_tenant_cikis", "visitor", "tenant_id, cikis_zamani DESC",
     "cikis_zamani IS NOT NULL"),
    ("ix_kargo_tenant_teslim", "kargo", "tenant_id, teslim_zamani DESC",
     "teslim_zamani IS NOT NULL"),
    ("ix_vehicle_pass_tenant_cikis", "vehicle_pass", "tenant_id, cikis_zamani DESC",
     "cikis_zamani IS NOT NULL"),
)


def upgrade() -> None:
    for ad, tablo, kolonlar, kosul in _INDEKSLER:
        nerede = f" WHERE {kosul}" if kosul else ""
        op.execute(
            f"CREATE INDEX IF NOT EXISTS {ad} ON {tablo} ({kolonlar}){nerede};"
        )


def downgrade() -> None:
    for ad, _tablo, _kolonlar, _kosul in reversed(_INDEKSLER):
        op.execute(f"DROP INDEX IF EXISTS {ad};")
