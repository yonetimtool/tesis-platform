"""(P154 / Asama 10) TERS KAYIT + DEFTERDE SILME KILIDI.

===========================================================================
NEDEN
===========================================================================
Apsiyon triyajinda B kovasinda kalan ve hicbir kodlama asamasinin
sahiplenmedigi iki madde: "finansal kayit SILINMEZ, ters kayit kullanilir"
ve "finansal denetim kaydi (eski/yeni deger)". Tasarimi
`docs/erp-yol-haritasi.md` §8'de yapilmisti; burasi onu uyguluyor.

Yarim altyapi ZATEN VARDI: `iade` tipi ve `iade_edilen_id` sutunu "hangi
tahsilat iade edildi" sorusunu yanitliyordu. Eksik olan GENEL bir iptal
mekanizmasi ve DELETE'in kapatilmasiydi.

===========================================================================
DELETE UYGULAMA KATMANINDA DEGIL, VERITABANINDA KAPATILIR
===========================================================================
Bugun hicbir uc `finansal_hareket` silmiyor; yarin biri yazarsa kimse
fark etmez. Yetkiyi geri almak kurali KANITLANABILIR kilar — `audit_log`un
append-only yapildigi yolun (0002) aynisi.

BLANKET GRANT HER MIGRATE SONRASI KOSAR (`infra/scripts/setup_app_role.py`)
ve app_rw'ye DELETE'i GERI VERIR. Bu yuzden REVOKE hem BURADA hem O
BETIKTE yapilir — yalniz burada yapmak, ilk `migrate` kosumundan sonra
kilidi sessizce acardi.

===========================================================================
CAKISMA VE COZUMU: ASAMA 8'IN GERI ALMASI
===========================================================================
Asama 8'in ice aktarim GERI ALMASI, `acilis_bakiye` turunde yarattigi
`finansal_hareket` satirlarini SILIYORDU. DELETE kapatilinca bu yol
kirilirdi.

Cozum satiri silmemek degil, DOGRU olani yapmak: geri alma artik defter
satirlari icin TERS KAYIT yaziyor. Bu, defterin kendi ilkesiyle de
uyumlu — bir muhasebe kaydi "hic olmamis" hâle getirilemez, yalnizca
tersine cevrilebilir. (`routers/ice_aktarim.py` icinde uygulandi.)
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "0047_ters_kayit"
down_revision = "0046_mesaj_kuyrugu"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    # `iptal`: bir hareketi tersine ceviren satirin TIPI. `iade`den AYRI —
    # iade musteriye para donusudur (gercek bir hareket), iptal ise bir
    # KAYIT DUZELTMESIDIR ve ikisini ayni tiple yazmak raporlari bozardi.
    op.execute("ALTER TYPE hareket_tip ADD VALUE IF NOT EXISTS 'iptal';")

    op.add_column(
        "finansal_hareket",
        sa.Column("ters_kayit_id", UUID(as_uuid=True), nullable=True),
    )
    # YON: IPTAL SATIRI, IPTAL ETTIGI SATIRI GOSTERIR.
    #
    # Yol haritasi tersini onermisti ("iptal edilen, kendisini iptal edeni
    # gosterir") ama tabloda ZATEN ayni isi yapan bir sutun var:
    # `iade_edilen_id` — ve o, IADE SATIRINDA durup iade ettigini
    # gosteriyor. Iki benzer bagi iki farkli yonde tutmak, her okuyanin
    # "hangisi hangisini gosteriyordu" diye durup bakmasi demekti.
    #
    # "Bu hareket iptal edilmis mi" sorusu asagidaki KISMI INDEKSLE
    # yanitlanir; sutunu ters yone koymanin tek kazanci olan O(1) okuma,
    # tutarliliktan daha ucuz bir kazanc.
    op.create_index(
        "ix_hareket_ters_kayit",
        "finansal_hareket",
        ["tenant_id", "ters_kayit_id"],
        postgresql_where=sa.text("ters_kayit_id IS NOT NULL"),
    )

    # DEFTERDE SILME YOK. Bkz. modul basligi — ayni REVOKE
    # `infra/scripts/setup_app_role.py`te de var, cunku blanket GRANT her
    # migrate sonrasi kosar.
    op.execute(
        f"REVOKE DELETE ON public.finansal_hareket FROM {APP_ROLE};"
    )


def downgrade() -> None:
    # DELETE geri verilir — aksi hâlde downgrade edilmis bir veritabani,
    # eski kodun (silebilen) beklentisiyle uyusmazdi.
    op.execute(f"GRANT DELETE ON public.finansal_hareket TO {APP_ROLE};")
    op.drop_index("ix_hareket_ters_kayit", table_name="finansal_hareket")
    op.drop_column("finansal_hareket", "ters_kayit_id")
    # PostgreSQL enum'dan DEGER SILMEYI desteklemez. Geri alis, tipi
    # yeniden yaratip butun kullanan sutunlari tasimayi gerektirir — veri
    # kaybi riski tasir ve bu goc icin GEREKSIZDIR (yeni deger eskiyi
    # bozmaz). 0034 ile ayni konvansiyon.
