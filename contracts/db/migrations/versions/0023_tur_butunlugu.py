"""tur butunlugu (0023) — MASTER-PLAN P34: konum, gecikme alarmi, baslangic fotografi.

KONUM SESSIZ KALMAZ. `scan_event` zaten `gps_lat/gps_lng` tutuyordu ama
NULL'un ANLAMI YOKTU: "izin verilmedi" mi, "sinyal yok" mu, "eski istemci
hic gondermedi" mi ayirt edilemiyordu. Uc durum ayni gorunurken amir
"konumsuz okutma" diye bir sey OLDUGUNU bile fark edemezdi. Bu yuzden
`konum_durumu` eklendi ve mevcut satirlar KORUNARAK siniflandirildi:
gps dolu ise 'var', bos ise 'bilinmiyor' (uydurma yapilmadi — eski
satirlarin neden konumsuz oldugu GERCEKTEN bilinmiyor).

`gps_dogruluk_m` AYRI bir alandir: 5 metre dogrulukla alinmis bir konumla
2 kilometre dogrulukla alinmis bir konum ekranda AYNI gorunurdu ve
ikincisi "gorevli noktadaydi" kanit degeri tasimaz.

GECIKME ALARMI (tolerans) TENANT AYARIDIR: 10 dakika bir sitede makul,
kampus buyuklugunde bir yerlesimde erken alarm demektir. Tekrar sayisi da
ayardir — SONSUZ tekrar bildirim yorgunlugu uretir ve alarm ANLAMINI
kaybeder.

BASLANGIC FOTOGRAFI bir TENANT ANAHTARIDIR, zorunlu bir urun kurali degil:
gece vardiyasinda kamera kullanimi her sitede kabul gormez (personel
mahremiyeti). Kapali oldugunda hicbir akis degismez.

YERINDE DUZENLEME ISTISNASI (MIGRATION-POLITIKASI.md kural 3): bu dosyanin
bildirim TEKLIGI bolumu, ilk yazilisindan sonra AYNI oturumda eklendi. Revizyon
o an HICBIR ORTAMA gitmemisti — commit edilmemis, push edilmemis, prod'a
uygulanmamisti; yalnizca gelistirici veritabanina uygulanmisti ve o da
`downgrade` -> `upgrade` ile yeniden kuruldu. Gerekce: gecikme alarmi
yazilirken `uq_notification_tenant_tip_window` teklignin ikinci alarmi
SESSIZCE dusurdugu olculdu; duzeltmeyi ayri bir 0024 revizyonuna koymak,
hicbir yerde bulunmayan bir ara durumu kalici olarak belgelemek olurdu.

Revision ID: 0023_tur_butunlugu
Revises: 0022_yonetisim
"""
from __future__ import annotations

from alembic import op

revision = "0023_tur_butunlugu"
down_revision = "0022_yonetisim"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ---------------------------- konum durumu ------------------------------ #
    # 'bilinmiyor': eski satirlar + konum alanini hic gondermeyen istemciler.
    # Bunu 'izin_yok' saymak, olmayan bir izin reddi RAPORLAMAK olurdu.
    op.execute(
        "CREATE TYPE konum_durumu AS ENUM "
        "('var', 'izin_yok', 'servis_kapali', 'zaman_asimi', 'bilinmiyor');"
    )
    op.execute(
        """
        ALTER TABLE scan_event
            ADD COLUMN konum_durumu konum_durumu NOT NULL DEFAULT 'bilinmiyor',
            ADD COLUMN gps_dogruluk_m numeric(7,1) NULL,
            ADD CONSTRAINT ck_scan_dogruluk
                CHECK (gps_dogruluk_m IS NULL OR gps_dogruluk_m >= 0),
            -- Konum "var" ise koordinat da OLMALIDIR: aksi halde rapor
            -- konumu oldugunu soyleyip gosteremezdi.
            ADD CONSTRAINT ck_scan_konum_tutarli
                CHECK (
                    konum_durumu <> 'var'
                    OR (gps_lat IS NOT NULL AND gps_lng IS NOT NULL)
                );
        """
    )
    # Mevcut satirlari SINIFLANDIR (silme/uydurma yok).
    op.execute(
        "UPDATE scan_event SET konum_durumu = 'var' "
        "WHERE gps_lat IS NOT NULL AND gps_lng IS NOT NULL;"
    )
    # Amir "konumsuz okutmalar" gorunumunu gun bazinda acar; tam tarama
    # yapmasin diye kismi indeks (yalniz konumsuz satirlar indekslenir —
    # normal durumda tablonun kucuk bir yuzdesi).
    op.execute(
        "CREATE INDEX ix_scan_konumsuz ON scan_event (tenant_id, okutma_zamani DESC) "
        "WHERE konum_durumu <> 'var';"
    )

    # ---------------- bildirim: pencere basina TEK -> TIPE GORE -------------- #
    # BULGU: `uq_notification_tenant_tip_window` (tenant, tip, pencere) TEKLIGI
    # kacirilan tur icin DOGRUYDU (bir pencere bir kez kacirilir) ama gecikme
    # alarmi TEKRAR ETMEK ZORUNDADIR — tek bir bildirim telefonun sessizde
    # oldugu bir anda kaybolur. Kisitlama oldugu gibi birakilsaydi ikinci
    # alarm sessizce dusurulurdu (ON CONFLICT baska bir indeksi hedefliyor).
    # Cozum: teklik KISMI indekse cevrildi — `gecikmis_okutma` HARIC her tip
    # icin eskisi gibi calisir; gecikme alarminin idempotencysi
    # `dedup_key` (tip:pencere:ADIM) ile saglanir.
    op.execute(
        "ALTER TABLE notification "
        "DROP CONSTRAINT IF EXISTS uq_notification_tenant_tip_window;"
    )
    op.execute(
        "CREATE UNIQUE INDEX uq_notification_tenant_tip_window "
        "ON notification (tenant_id, tip, patrol_window_id) "
        "WHERE tip <> 'gecikmis_okutma'::notification_tip;"
    )

    # -------------------------- tenant ayarlari ----------------------------- #
    op.execute(
        """
        ALTER TABLE tenant
            ADD COLUMN tur_gecikme_toleransi_dk integer NOT NULL DEFAULT 10,
            ADD COLUMN tur_alarm_tekrar_sayisi integer NOT NULL DEFAULT 3,
            ADD COLUMN tur_baslangic_foto_zorunlu boolean NOT NULL DEFAULT false,
            ADD CONSTRAINT ck_tenant_tur_tolerans
                CHECK (tur_gecikme_toleransi_dk BETWEEN 1 AND 240),
            -- 0 = alarm KAPALI (gecerli bir tercih); ust sinir bildirim
            -- yorgunlugunu onler.
            ADD CONSTRAINT ck_tenant_tur_tekrar
                CHECK (tur_alarm_tekrar_sayisi BETWEEN 0 AND 10);
        """
    )


def downgrade() -> None:
    # Kisitlamayi geri koymadan ONCE tekrarlari ayikla: 0023 sonrasi bir
    # pencere icin birden fazla `gecikmis_okutma` satiri OLABILIR ve
    # kisitlama bunlarla kurulamaz. En ESKI kayit korunur (alarmin ILK
    # gonderimi olay kaydidir; sonrakiler tekrarlardir).
    op.execute(
        """
        DELETE FROM notification n
        USING notification k
        WHERE n.tip = 'gecikmis_okutma'
          AND k.tip = 'gecikmis_okutma'
          AND n.tenant_id = k.tenant_id
          AND n.patrol_window_id IS NOT DISTINCT FROM k.patrol_window_id
          AND n.created_at > k.created_at;
        """
    )
    # Once KISIT, sonra INDEKS: ayni ad iki farkli nesne turunde olabilir ve
    # kisit tarafindan tutulan bir indeks dogrudan DROP EDILEMEZ.
    op.execute(
        "ALTER TABLE notification "
        "DROP CONSTRAINT IF EXISTS uq_notification_tenant_tip_window;"
    )
    op.execute("DROP INDEX IF EXISTS uq_notification_tenant_tip_window;")
    op.execute(
        "ALTER TABLE notification ADD CONSTRAINT uq_notification_tenant_tip_window "
        "UNIQUE (tenant_id, tip, patrol_window_id);"
    )
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_tur_tekrar;")
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_tur_tolerans;")
    op.execute(
        "ALTER TABLE tenant "
        "DROP COLUMN IF EXISTS tur_baslangic_foto_zorunlu, "
        "DROP COLUMN IF EXISTS tur_alarm_tekrar_sayisi, "
        "DROP COLUMN IF EXISTS tur_gecikme_toleransi_dk;"
    )
    op.execute("DROP INDEX IF EXISTS ix_scan_konumsuz;")
    op.execute("ALTER TABLE scan_event DROP CONSTRAINT IF EXISTS ck_scan_konum_tutarli;")
    op.execute("ALTER TABLE scan_event DROP CONSTRAINT IF EXISTS ck_scan_dogruluk;")
    op.execute(
        "ALTER TABLE scan_event "
        "DROP COLUMN IF EXISTS gps_dogruluk_m, "
        "DROP COLUMN IF EXISTS konum_durumu;"
    )
    op.execute("DROP TYPE IF EXISTS konum_durumu;")
