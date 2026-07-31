"""portal + anket (0027) — MASTER-PLAN P38: site web sayfasi ve oylama.

PORTAL VARSAYILAN KAPALIDIR (`yayinda = false`). Bir tesisin adi, adresi ve
fotograflari, yonetim ACIKCA yayinlamadan internete cikmamalidir — "once
yayinla sonra doldur" varsayilani, yarim dolu bir sayfayi arama motoruna
sunmak olurdu.

ANKET OYU DEGISTIRILEMEZ. `UNIQUE (tenant_id, anket_id, user_id)` tek oyu
zorlar; "oyumu degistireyim" akisi BILINCLI OLARAK YOK: degistirilebilir oy,
kapanis anina kadar sonucun anlamsiz olmasi ve kimin ne zaman dondugunun
kayda gecmesi demekti. Anket bir yoklama degil KARAR aracidir.

OY KIMLIGI SAKLANIR ama SONUC ANONIMDIR: `user_id` tek-oy kuralini zorlamak
icin sarttir; hicbir uc oy verenin kimligini DONDURMEZ (unit_complaint'in
`complainant_user_id` deseniyle ayni).

ILETISIM MESAJI TENANT'A YAZILIR, e-postaya DEGIL: e-posta gonderimi
yapilandirmaya baglidir ve yapilandirilmamis bir sitede mesaj SESSIZCE
KAYBOLURDU. Once kayit, sonra bildirim.

YERINDE DUZENLEME ISTISNASI (MIGRATION-POLITIKASI.md kural 3):
`ix_anket_secenek_tenant` indeksi dosya ilk yazildiktan sonra AYNI oturumda
eklendi — indeks kapsami envanteri `anket_secenek(tenant_id)` FK'sinin oncu
kolonunu kapsayan indeks olmadigini yakaladi (tenant silinince RI tetigi
tabloyu seq scan ederdi). Revizyon o an hicbir ortama gitmemisti; gelistirici
veritabani downgrade -> upgrade ile yeniden kuruldu.

Revision ID: 0027_portal_anket
Revises: 0026_gurultu_caydirici
"""
from __future__ import annotations

from alembic import op

revision = "0027_portal_anket"
down_revision = "0026_gurultu_caydirici"
branch_labels = None
depends_on = None

_TABLOLAR = (
    "tenant_portal", "portal_galeri", "anket", "anket_secenek",
    "anket_oy", "iletisim_mesaji",
)


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE tenant_portal (
            tenant_id   uuid PRIMARY KEY
                        REFERENCES tenant(id) ON DELETE CASCADE,
            -- VARSAYILAN KAPALI: yayin bilincli bir karardir.
            yayinda     boolean NOT NULL DEFAULT false,
            hero_baslik text NULL,
            hero_alt    text NULL,
            hakkimizda  text NULL,
            iletisim_adres text NULL,
            iletisim_telefon text NULL,
            iletisim_email text NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        """
        CREATE TABLE portal_galeri (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            -- Depo ANAHTARI (MinIO); sunucu dosyayi tasimaz (P33 deseni).
            obje_anahtari text NOT NULL,
            baslik      text NULL,
            sira        integer NOT NULL DEFAULT 0,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_portal_galeri_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_portal_galeri_obje UNIQUE (tenant_id, obje_anahtari)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_portal_galeri_tenant ON portal_galeri (tenant_id, sira);"
    )
    op.execute(
        """
        CREATE TABLE anket (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            baslik      text NOT NULL,
            aciklama    text NULL,
            -- Kapanis ZORUNLU DEGIL ama varsa oy alma o ana kadardir.
            kapanis_at  timestamptz NULL,
            aktif       boolean NOT NULL DEFAULT true,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_anket_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_anket_baslik CHECK (length(btrim(baslik)) > 0)
        );
        """
    )
    op.execute("CREATE INDEX ix_anket_tenant ON anket (tenant_id, created_at DESC);")
    op.execute(
        """
        CREATE TABLE anket_secenek (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            anket_id    uuid NOT NULL,
            metin       text NOT NULL,
            sira        integer NOT NULL DEFAULT 0,
            CONSTRAINT uq_anket_secenek_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_anket_secenek_metin CHECK (length(btrim(metin)) > 0),
            CONSTRAINT fk_anket_secenek_anket
                FOREIGN KEY (anket_id, tenant_id)
                REFERENCES anket (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_anket_secenek_anket ON anket_secenek (anket_id, sira);"
    )
    # FK oncu kolonu: tenant silinince RI tetigi tabloyu seq scan etmesin.
    # (Diger tablolarda `ix_*_tenant` bu isi zaten goruyor.)
    op.execute(
        "CREATE INDEX ix_anket_secenek_tenant ON anket_secenek (tenant_id);"
    )
    op.execute(
        """
        CREATE TABLE anket_oy (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            anket_id    uuid NOT NULL,
            secenek_id  uuid NOT NULL,
            -- Tek-oy kuralini ZORLAMAK icin sart; hicbir uc DONDURMEZ.
            user_id     uuid NOT NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            -- TEK OY: ayni ankete ikinci oy YOK ve oy DEGISTIRILEMEZ.
            CONSTRAINT uq_anket_oy UNIQUE (tenant_id, anket_id, user_id),
            CONSTRAINT fk_anket_oy_anket
                FOREIGN KEY (anket_id, tenant_id)
                REFERENCES anket (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_anket_oy_secenek
                FOREIGN KEY (secenek_id, tenant_id)
                REFERENCES anket_secenek (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_anket_oy_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute("CREATE INDEX ix_anket_oy_secenek ON anket_oy (secenek_id);")
    op.execute("CREATE INDEX ix_anket_oy_user ON anket_oy (tenant_id, user_id);")
    op.execute(
        """
        CREATE TABLE iletisim_mesaji (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad          text NOT NULL,
            telefon     text NULL,
            email       text NULL,
            mesaj       text NOT NULL,
            okundu      boolean NOT NULL DEFAULT false,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_iletisim_mesaj CHECK (length(btrim(mesaj)) > 0),
            -- EN AZ BIR DONUS YOLU: telefonu ve e-postasi olmayan bir mesaja
            -- yonetim cevap veremezdi.
            CONSTRAINT ck_iletisim_donus
                CHECK (telefon IS NOT NULL OR email IS NOT NULL)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_iletisim_mesaji_tenant ON iletisim_mesaji "
        "(tenant_id, created_at DESC);"
    )

    for tablo in _TABLOLAR:
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_tenant_isolation ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);
            """
        )
        op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON {tablo} TO app_rw;")


def downgrade() -> None:
    for tablo in reversed(_TABLOLAR):
        op.execute(f"DROP TABLE IF EXISTS {tablo};")
