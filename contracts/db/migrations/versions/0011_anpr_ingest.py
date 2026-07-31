"""anpr_ingest (0011) — KAYNAKTAN BAGIMSIZ plaka okuma (ANPR) girisi.

MASTER-PLAN P16. Frigate / Hikvision / Dahua ve elle giris AYNI uca yazar;
kaynaga ozgu bicimler adaptor katmaninda tek gövdeye cevrilir (sema ve
Frigate esleme tablosu: `docs/frigate-poc.md` §6).

Bu revizyon UC sey yapar:

1. `anpr_api_key` — TENANT BASINA giris anahtari.
   Kamera kutusu JWT tasiyamaz (kullanici oturumu yoktur, token yenilenemez);
   bu yuzden uzun omurlu bir anahtar gerekir. Anahtarin KENDISI SAKLANMAZ:
   yalniz sha256 OZETI tutulur — sizan bir yedekten anahtar geri uretilemez.
   Anahtar `<kimlik>.<sir>` bicimindedir; `kimlik` acik saklanir (indeksli
   arama), `sir` yalnizca ozetiyle. Cozumleme `anpr_key_coz` SECURITY DEFINER
   fonksiyonuyla yapilir: istek geldiginde tenant HENUZ BILINMEDIGI icin RLS
   baglami kurulamaz (mevcut `audit_log_list` / `list_all_tenants` deseni).

2. `anpr_event` — gelen HAM olay + islenme sonucu.
   `(tenant_id, kaynak, kaynak_olay_id)` TEKILDIR. Bu bir suslemeden ibaret
   degil, P15'te OLCULMUS bir gerekliliktir: Frigate ayni olayi `update` ve
   `end` olarak BIRDEN COK KEZ yayinlar. Tekillik olmadan tek bir aracin
   girisi iki gecis kaydi acardi.

3. `vehicle_pass` iki kolon kazanir:
   * `kaydeden_user_id` NULLABLE olur — ANPR gecisini BIR INSAN KAYDETMEZ.
     Eskiden NOT NULL + ON DELETE RESTRICT idi; sahte bir "sistem kullanicisi"
     uydurmak RBAC ve denetim kayitlarini kirletirdi (secenekler MASTER-PLAN
     P16 hazirlik notunda tartisildi).
   * `kaynak` = manuel | anpr — gecisin NASIL acildigi. Otopark dolulugu
     (G4) hala TEK sayimdir: "sayim ile kayit asla ayrisamaz" ilkesi korunur,
     yalnizca satirin kokeni isaretlenir.
   Ek olarak `ck_vehicle_pass_kaydeden` kisiti: `kaynak='manuel'` iken
   `kaydeden_user_id` ZORUNLU kalir — kolonu nullable yapmak elle kayitta
   izlenebilirligi kaybetmek DEMEK DEGILDIR.

4. `tenant` iki ayar kazanir: `anpr_guven_esigi` (varsayilan 0.85) ve
   `anpr_otomatik_cikis` (varsayilan true). Esik ALTINDAKI okumalar gecis
   ACMAZ, ONAY KUYRUGUNA duser — P15 olcumu Frigate'in `recognition_threshold`
   varsayilanini 0.9 ve `match_distance`ini 1 (bir karakter OCR toleransi)
   gosterdi; yani yanlis okuma BEKLENEN bir durumdur.

URETIM: additive + geriye-uyumlu. Mevcut satirlar `kaynak='manuel'` ve
`kaydeden_user_id` dolu olarak kalir; hicbir sorgu bozulmaz.

Revision ID: 0011_anpr_ingest
Revises: 0010_devriye_okutma_indeksi
"""
from __future__ import annotations

from alembic import op

revision = "0011_anpr_ingest"
down_revision = "0010_devriye_okutma_indeksi"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

_FN_SIG = "public.anpr_key_coz(text, text)"


def upgrade() -> None:
    # ---------------------------------------------------------------- enum'lar
    # Gecisin kokeni. Yeni kaynak eklemek MIGRATION ister (bilincli: sessiz
    # bir metin degeri yerine sema kisiti).
    op.execute("CREATE TYPE gecis_kaynak AS ENUM ('manuel', 'anpr');")
    # Olayin islenme sonucu:
    #   islendi        -> gecis acildi/kapandi
    #   onay_bekliyor  -> guven esigin ALTINDA; insan onayi bekliyor
    #   yok_sayildi    -> tekrar (idempotent) ya da anlamli eylem yok
    #   hata           -> adaptor/veri hatasi (govde ham olarak saklanir)
    op.execute(
        "CREATE TYPE anpr_olay_durum AS ENUM "
        "('islendi', 'onay_bekliyor', 'yok_sayildi', 'hata');"
    )
    # Gecis yonu. `bilinmiyor` GERCEK bir haldir: P15'te olculdu — Frigate yon
    # BILGISI URETMEZ; yon kamera ayarindan ya da zone gecisinden turetilir.
    op.execute("CREATE TYPE anpr_yon AS ENUM ('giris', 'cikis', 'bilinmiyor');")

    # -------------------------------------------------------- anpr_api_key
    op.execute(
        """
        CREATE TABLE anpr_api_key (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            -- Insan icin ad ("Ana kapi Frigate kutusu").
            ad          text NOT NULL,
            -- Anahtarin ACIK yarisi: `<kimlik>.<sir>` icindeki kimlik.
            -- Global TEKIL: cozumleme tenant bilinmeden yapilir.
            kimlik      text NOT NULL,
            -- `sir`in sha256 hex ozeti. Anahtarin kendisi ASLA saklanmaz.
            sir_hash    text NOT NULL,
            aktif       boolean NOT NULL DEFAULT true,
            son_kullanim timestamptz,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_anpr_api_key_kimlik UNIQUE (kimlik),
            CONSTRAINT uq_anpr_api_key_id_tenant UNIQUE (id, tenant_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_anpr_api_key_tenant ON anpr_api_key (tenant_id, created_at DESC);"
    )

    # -------------------------------------------------------- anpr_event
    op.execute(
        """
        CREATE TABLE anpr_event (
            id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id       uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            -- Hangi sistemden geldi: frigate | hikvision | dahua | manuel ...
            kaynak          text NOT NULL,
            -- Kaynagin KENDI olay kimligi — idempotency anahtari.
            kaynak_olay_id  text NOT NULL,
            -- NORMALIZE plaka (crud_helpers.norm_plaka ile ayni kural).
            plaka           text NOT NULL,
            -- Kaynagin gonderdigi HAM plaka metni (tani icin; normalize
            -- edilmemis hali kaybolmasin).
            plaka_ham       text,
            zaman           timestamptz NOT NULL,
            -- Serbest kamera adi/kimligi (FK DEGIL: kamera kaydi olmayabilir).
            kamera          text,
            yon             anpr_yon NOT NULL DEFAULT 'bilinmiyor',
            -- 0..1 okuma guveni. NULL = kaynak guven bildirmedi.
            guven           numeric(4, 3),
            -- MinIO obje anahtari (Frigate'in kendi saklama suresi kisadir;
            -- fotograf ingest sirasinda bize kopyalanir).
            foto_key        text,
            durum           anpr_olay_durum NOT NULL DEFAULT 'islendi',
            -- Neden onay bekliyor / neden yok sayildi (kisa KOD, PII yok).
            durum_nedeni    text,
            -- Acilan/kapanan gecis (varsa). Gecis silinirse olay KALIR.
            vehicle_pass_id uuid,
            -- Kaynagin ham govdesi (denetim + adaptor hata ayiklama).
            ham             jsonb NOT NULL DEFAULT '{}'::jsonb,
            created_at      timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_anpr_event_kaynak
                UNIQUE (tenant_id, kaynak, kaynak_olay_id),
            CONSTRAINT ck_anpr_event_plaka CHECK (plaka ~ '^[A-Z0-9]{2,20}$'),
            CONSTRAINT ck_anpr_event_guven
                CHECK (guven IS NULL OR (guven >= 0 AND guven <= 1)),
            -- Cross-tenant referansi ENGELLER; gecis silinince olay yetim
            -- kalmasin diye SET NULL (olay bir DEFTER kaydidir, silinmez).
            FOREIGN KEY (vehicle_pass_id, tenant_id)
                REFERENCES vehicle_pass (id, tenant_id) ON DELETE SET NULL
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_anpr_event_tenant_zaman "
        "ON anpr_event (tenant_id, zaman DESC);"
    )
    # Onay kuyrugu ekrani YALNIZ bekleyenleri listeler — kismi indeks.
    op.execute(
        "CREATE INDEX ix_anpr_event_onay ON anpr_event (tenant_id, created_at DESC) "
        "WHERE durum = 'onay_bekliyor';"
    )

    # ------------------------------------------------- vehicle_pass genisleme
    op.execute(
        "ALTER TABLE vehicle_pass "
        "ADD COLUMN kaynak gecis_kaynak NOT NULL DEFAULT 'manuel';"
    )
    op.execute(
        "ALTER TABLE vehicle_pass ALTER COLUMN kaydeden_user_id DROP NOT NULL;"
    )
    # Elle kayitta izlenebilirlik KAYBOLMAZ: kaydeden yalniz ANPR'da bos olur.
    op.execute(
        """
        ALTER TABLE vehicle_pass ADD CONSTRAINT ck_vehicle_pass_kaydeden
            CHECK (kaynak = 'anpr' OR kaydeden_user_id IS NOT NULL);
        """
    )

    # ------------------------------------------------------- tenant ayarlari
    op.execute(
        "ALTER TABLE tenant ADD COLUMN anpr_guven_esigi numeric(4, 3) "
        "NOT NULL DEFAULT 0.850;"
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_anpr_esik "
        "CHECK (anpr_guven_esigi >= 0 AND anpr_guven_esigi <= 1);"
    )
    # Cikis olayinda acik gecis OTOMATIK kapatilsin mi? Tek yonlu kapida
    # (yalniz giris kamerasi) kapatan olan olmaz; site bunu kapatabilmeli.
    op.execute(
        "ALTER TABLE tenant ADD COLUMN anpr_otomatik_cikis boolean "
        "NOT NULL DEFAULT true;"
    )

    # ---------------------------------------------------------------- RLS
    for tablo in ("anpr_api_key", "anpr_event"):
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_isolation ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
        op.execute(
            f"GRANT SELECT, INSERT, UPDATE, DELETE ON {tablo} TO {APP_ROLE};"
        )

    # ------------------------------------------- anahtar cozumleme (RLS disi)
    #
    # Istek geldiginde tenant HENUZ BILINMIYOR, dolayisiyla RLS baglami
    # kurulamaz. Cozumleme owner-sahipli SECURITY DEFINER fonksiyonla yapilir
    # (mevcut `audit_log_list` deseni). Fonksiyon YALNIZ tenant_id + anahtar
    # id'si doner — satirin geri kalanini (ad, hash) sizdirmaz.
    #
    # `son_kullanim` BU FONKSIYONDA guncellenmez: fonksiyon STABLE kalsin ve
    # her istekte bir UPDATE yazmasin diye. Damga uc katmaninda, ISLEM
    # basarili olunca atilir.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.anpr_key_coz(
            p_kimlik   text,
            p_sir_hash text
        )
        RETURNS TABLE(tenant_id uuid, key_id uuid)
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT k.tenant_id, k.id
            FROM public.anpr_api_key k
            WHERE k.kimlik = p_kimlik
              AND k.sir_hash = p_sir_hash
              AND k.aktif = true
            LIMIT 1;
        $$;
        """
    )
    op.execute(f"REVOKE ALL ON FUNCTION {_FN_SIG} FROM PUBLIC;")
    op.execute(f"GRANT EXECUTE ON FUNCTION {_FN_SIG} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute(f"DROP FUNCTION IF EXISTS {_FN_SIG};")
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_anpr_esik;")
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS anpr_otomatik_cikis;")
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS anpr_guven_esigi;")
    op.execute(
        "ALTER TABLE vehicle_pass DROP CONSTRAINT IF EXISTS ck_vehicle_pass_kaydeden;"
    )
    # NOT NULL'a geri donmeden once ANPR satirlari temizlenmeli; downgrade
    # yalniz dev icindir (prod'da 0011 geri alinmaz).
    op.execute("DELETE FROM vehicle_pass WHERE kaydeden_user_id IS NULL;")
    op.execute(
        "ALTER TABLE vehicle_pass ALTER COLUMN kaydeden_user_id SET NOT NULL;"
    )
    op.execute("ALTER TABLE vehicle_pass DROP COLUMN IF EXISTS kaynak;")
    op.execute("DROP TABLE IF EXISTS anpr_event;")
    op.execute("DROP TABLE IF EXISTS anpr_api_key;")
    op.execute("DROP TYPE IF EXISTS anpr_yon;")
    op.execute("DROP TYPE IF EXISTS anpr_olay_durum;")
    op.execute("DROP TYPE IF EXISTS gecis_kaynak;")
