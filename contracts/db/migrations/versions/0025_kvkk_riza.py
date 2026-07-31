"""kvkk riza (0025) — MASTER-PLAN P36: aydinlatma metni + onay + pazarlama izinleri.

METIN TENANT ICERIGIDIR, urun sabiti DEGIL: her tesisin veri sorumlusu
kendisidir ve aydinlatma metnini kendi hukuk danismani yazar. Platforma
gomulu tek bir metin, 200 tesise BASKASININ metnini imzalatmak olurdu.

SURUM YERINE DUZENLEME YOK: yayinlanmis bir metnin govdesi DEGISTIRILEMEZ,
yeni SURUM acilir. Yerinde duzenlemeye izin verilseydi, dun onay vermis bir
kullanicinin onayi BUGUN BASKA BIR METNE ait gorunurdu — onay kaydinin tek
degeri "hangi metne, ne zaman" olmasidir.

ONAY SATIRI SILINMEZ, GUNCELLENMEZ: (kullanici, surum) basina TEK satir ve
sonrasinda dokunulmaz. Onayi "geri almak" onay kaydini silmek DEGILDIR;
KVKK'da aydinlatma bir BILDIRIMDIR ve geri alinmaz — geri alinabilen sey
PAZARLAMA RIZASIDIR ve o ayri kolonlarda tutulur.

PAZARLAMA IZINLERI UC AYRI KOLON, tek bir "pazarlama" bayragi DEGIL: kisi
e-posta isteyip SMS istemeyebilir. Tek bayrak, istemedigi kanaldan mesaj
almak ya da hic almamak arasinda secim birakirdi. UCU DE VARSAYILAN
KAPALIDIR (KVKK: riza ACIK olmali, varsayilan olamaz).

Revision ID: 0025_kvkk_riza
Revises: 0024_guvenlik_amiri
"""
from __future__ import annotations

from alembic import op

revision = "0025_kvkk_riza"
down_revision = "0024_guvenlik_amiri"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE kvkk_metin (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            surum       integer NOT NULL,
            baslik      text NOT NULL,
            govde       text NOT NULL,
            yayinlayan_user_id uuid,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_kvkk_metin_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_kvkk_metin_surum UNIQUE (tenant_id, surum),
            CONSTRAINT ck_kvkk_surum CHECK (surum >= 1),
            CONSTRAINT ck_kvkk_govde CHECK (length(btrim(govde)) > 0),
            -- Yayinlayan hesap silinse de METIN DURUR: onay kayitlarinin
            -- refere ettigi metnin yok olmasi, onaylari anlamsiz kilardi.
            CONSTRAINT fk_kvkk_metin_yayinlayan
                FOREIGN KEY (yayinlayan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id)
                ON DELETE SET NULL (yayinlayan_user_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_kvkk_metin_tenant ON kvkk_metin (tenant_id, surum DESC);"
    )

    op.execute(
        """
        CREATE TABLE kvkk_onay (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            user_id       uuid NOT NULL,
            kvkk_metin_id uuid NOT NULL,
            -- Surum AYRICA kopyalanir: metin satiri bir gun silinse bile
            -- "hangi surumu onayladi" sorusu yanitlanabilir kalmali.
            surum         integer NOT NULL,
            onay_at       timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_kvkk_onay UNIQUE (tenant_id, user_id, surum),
            CONSTRAINT fk_kvkk_onay_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_kvkk_onay_metin
                FOREIGN KEY (kvkk_metin_id, tenant_id)
                REFERENCES kvkk_metin (id, tenant_id) ON DELETE RESTRICT
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_kvkk_onay_user ON kvkk_onay (tenant_id, user_id);"
    )

    op.execute(
        """
        ALTER TABLE app_user
            ADD COLUMN pazarlama_eposta boolean NOT NULL DEFAULT false,
            ADD COLUMN pazarlama_sms boolean NOT NULL DEFAULT false,
            ADD COLUMN pazarlama_arama boolean NOT NULL DEFAULT false,
            -- Rizanin NE ZAMAN verildigi/kaldirildigi: KVKK'da ispat
            -- yukumlulugu veri sorumlusundadir.
            ADD COLUMN pazarlama_guncelleme_at timestamptz NULL;
        """
    )

    # RLS: yeni tablolar da tenant-izole (depo kurali — bkz. test_rls_kapsam).
    for tablo in ("kvkk_metin", "kvkk_onay"):
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
    op.execute(
        "ALTER TABLE app_user "
        "DROP COLUMN IF EXISTS pazarlama_guncelleme_at, "
        "DROP COLUMN IF EXISTS pazarlama_arama, "
        "DROP COLUMN IF EXISTS pazarlama_sms, "
        "DROP COLUMN IF EXISTS pazarlama_eposta;"
    )
    op.execute("DROP TABLE IF EXISTS kvkk_onay;")
    op.execute("DROP TABLE IF EXISTS kvkk_metin;")
