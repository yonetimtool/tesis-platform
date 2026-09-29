"""(P249 §3) GUVENLIKTEN DAIREYE ULASMA — onay talebi, sesli mesaj, telefon izni.

===========================================================================
(a) ZIYARETCI ONAY TALEBI — mevcut `visitor` kaydinin GENISLETMESI
===========================================================================
Ziyaretci kaydi LOG'du ("onay/red YOKTUR"). Saha sorunu: ev sahibi evde
degil, biri "beni bekliyor" diyor ve guvenlik dogrulayamiyor. Kayda
ISTEGE BAGLI bir onay talebi eklenir:

  * `onay_durum` NULL        — onay istenmedi (eski LOG davranisi AYNEN),
  * `bekliyor`               — daire sakinlerine soruldu,
  * `onaylandi` / `reddedildi` — ILK yanit gecerli,
  * `cevap_yok`              — sure doldu (beat).

Yeni bir tablo DEGIL: ayni ziyaretin iki kaydi olmasin — liste, cikis ve
gecmis zaten `visitor` uzerinden.

===========================================================================
(b) SESLI MESAJ — `daire_sesli_mesaj`
===========================================================================
Ses KISISEL VERIDIR. Dosya depoda (`depo_anahtari`), satir 7 gun sonra
gece imha goreviyle HEM kayittan HEM depodan silinir. Sakin istedigi an
siler (`silindi_at` + dosya silinir). Satir silinmez, "silindi" isaretlenir
— denetim izi kalsin, icerik kalmasin.

===========================================================================
(e) TELEFON YEDEGI — `app_user.yonetim_arayabilir`
===========================================================================
VARSAYILAN KAPALI. Sakin acmadikca numarasi guvenlige HICBIR YOLDAN
gosterilmez; acsa bile yalniz "daireye ulas" ekraninda, tek kisi icin ve
denetim kaydiyla.
"""
from alembic import op

APP_ROLE = "app_rw"

revision = "0159_p249_daireye_ulasma"
down_revision = "0158_p249_tatbikat"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # (a) ziyaretci onay talebi
    op.execute(
        "ALTER TABLE visitor "
        "ADD COLUMN onay_durum text, "
        "ADD COLUMN onay_son_at timestamptz, "
        "ADD COLUMN onay_yanit_at timestamptz, "
        "ADD COLUMN onay_yanitlayan_user_id uuid, "
        "ADD CONSTRAINT ck_visitor_onay_durum CHECK (onay_durum IS NULL OR "
        "onay_durum IN ('bekliyor', 'onaylandi', 'reddedildi', 'cevap_yok'));"
    )
    op.execute(
        "CREATE INDEX ix_visitor_onay_bekliyor ON visitor (onay_son_at) "
        "WHERE onay_durum = 'bekliyor';"
    )

    # (b) sesli mesaj
    op.execute(
        """
        CREATE TABLE daire_sesli_mesaj (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            unit_id uuid NOT NULL,
            gonderen_user_id uuid,
            depo_anahtari text,
            sure_ms integer NOT NULL,
            boyut integer NOT NULL,
            icerik_turu text NOT NULL,
            dinlendi_at timestamptz,
            dinleyen_user_id uuid,
            silindi_at timestamptz,
            created_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_sesli_mesaj_sure CHECK (sure_ms > 0 AND sure_ms <= 60000),
            CONSTRAINT ck_sesli_mesaj_boyut CHECK (boyut > 0 AND boyut <= 1048576),
            CONSTRAINT fk_sesli_mesaj_unit FOREIGN KEY (unit_id)
                REFERENCES unit(id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_sesli_mesaj_unit ON daire_sesli_mesaj (unit_id, created_at DESC);"
    )
    # FK oncu kolonu (tenant silinince RI tetigi seq scan etmesin) +
    # gece imha sorgusu (created_at) — `test_indeks_kapsam`.
    op.execute(
        "CREATE INDEX ix_sesli_mesaj_tenant ON daire_sesli_mesaj (tenant_id, created_at);"
    )
    op.execute("ALTER TABLE daire_sesli_mesaj ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE daire_sesli_mesaj FORCE ROW LEVEL SECURITY;")
    op.execute(
        "CREATE POLICY daire_sesli_mesaj_isolation ON daire_sesli_mesaj "
        "USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid) "
        "WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);"
    )
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON daire_sesli_mesaj TO {APP_ROLE};")

    # (e) telefon yedegi izni
    op.execute(
        "ALTER TABLE app_user ADD COLUMN yonetim_arayabilir boolean NOT NULL DEFAULT false;"
    )

    for deger in ("ziyaretci_onay_istegi", "ziyaretci_onay_yaniti", "sesli_mesaj"):
        op.execute(f"ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS '{deger}';")


def downgrade() -> None:
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS yonetim_arayabilir;")
    op.execute("DROP TABLE IF EXISTS daire_sesli_mesaj;")
    op.execute("DROP INDEX IF EXISTS ix_visitor_onay_bekliyor;")
    op.execute(
        "ALTER TABLE visitor DROP CONSTRAINT IF EXISTS ck_visitor_onay_durum, "
        "DROP COLUMN IF EXISTS onay_yanitlayan_user_id, DROP COLUMN IF EXISTS onay_yanit_at, "
        "DROP COLUMN IF EXISTS onay_son_at, DROP COLUMN IF EXISTS onay_durum;"
    )
