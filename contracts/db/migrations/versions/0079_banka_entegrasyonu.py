"""(P191 §4) Banka entegrasyonu v1 — bank_transaction / payment_match / receipt

===========================================================================
MİMARİ KURAL: BU SIFIRDAN BİR SİSTEM DEĞİL
===========================================================================
Kullanıcının koyduğu sınır aynen uygulandı:

  * YENİ site/apartman/sakin tablosu AÇILMADI — `tenant`, `unit`, `app_user`
    zaten var ve daire-kişi bağı `unit_resident`ta duruyor.
  * Daireye özel referans için `app_user.odeme_kodu` KULLANILIYOR (P30);
    yeni bir referans alanı üretilmedi.
  * Muhasebe kaydı `finansal_hareket`e yazılır (append-only defter; DELETE
    yetkisi kasten yok). Borç kapanışı ürünün kendi yolundan —
    `dues_payment` — geçer; bakiye oradan hesaplanıyor.
  * Kuyruk Celery, depo MinIO, veritabanı PostgreSQL — mevcut yığın.

Bu göç YALNIZ üç tablo açar.

===========================================================================
1) bank_transaction — HAM BANKA HAREKETİ, DEĞİŞTİRİLEMEZ
===========================================================================
`external_transaction_id` tenant içinde BENZERSİZ: aynı ekstre iki kez
yüklenirse ikinci yükleme yeni satır AÇMAZ (idempotency). Bankanın referans
numarası yoksa içe aktarma katmanı (tarih|tutar|açıklama|sıra) üçlüsünden
kararlı bir kimlik türetir — kimliği ÜRETEN taraf içe aktarmadır, tablo
değil.

`raw_data` DEĞİŞTİRİLEMEZ ve bu bir tetikleyiciyle zorlanır: ham kayıt
delilin kendisidir. "Eşleştirme yanlıştı, açıklamayı düzeltelim" diyen bir
düzeltme, sonradan denetlenemez bir defter bırakırdı.

IBAN TAM SAKLANIR ama okuma yolu MASKELER (son 4 hane): eşleştirme motoru
"bu IBAN daha önce kiminle eşleşti" sorusunu sormak zorunda; maskeli değer
bu soruyu cevaplayamaz. Sızıntı yüzeyi API katmanında kapatılır.

===========================================================================
2) payment_match — EŞLEŞME KAYDI
===========================================================================
Bir banka hareketi BİRDEN ÇOK borcu kapatabilir (FIFO: tek transferle üç
ay). Bu yüzden eşleşme hareket başına DEĞİL, (hareket, hedef) başına bir
satırdır ve `tutar_kurus` o satıra düşen payı taşır.

`durum='geri_alindi'` — YANLIŞ EŞLEŞMEYİ GERİ ALMA. Satır SİLİNMEZ: ters
kayıt yazılır ve borç yeniden açılır. Silme, "bu para nereye gitti"
sorusunu cevapsız bırakırdı.

===========================================================================
3) receipt — MAKBUZ
===========================================================================
PDF MinIO'da; tabloda yalnız anahtar + belge no + tutar. Dosyayı veritabanına
koymak, yedeklemeyi ve saklama sürelerini iki farklı sisteme bölerdi.

Revision ID: 0079_banka_entegrasyonu
Revises: 0078_gorev_aidat_bildirim
Create Date: 2026-08-30
"""
from alembic import op

revision = "0079_banka_entegrasyonu"
down_revision = "0078_gorev_aidat_bildirim"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

#: Hareketin işlenme durumu.
#:   yeni             henüz eşleştirilmedi
#:   eslesti          en az bir onaylanmış eşleşmesi var
#:   manuel_inceleme  motor karar veremedi / eşik altı / çelişki
#:   ilgisiz_gelir    yönetici "bu aidat değil" dedi (kira, faiz, iade...)
#:   masraf           banka masrafı/komisyon — yönetici onayı bekler
#:   ters_kayit       iade/ters kayıt hareketi
_TX_DURUM = ("yeni", "eslesti", "manuel_inceleme", "ilgisiz_gelir", "masraf", "ters_kayit")

#: Eşleşmenin nasıl kurulduğu — güven puanının GEREKÇESİ.
_MATCH_TIP = ("odeme_kodu", "iban", "ad_tutar", "manuel")

#: Eşleşmenin durumu.
_MATCH_DURUM = ("onerildi", "onaylandi", "geri_alindi", "reddedildi")


def upgrade() -> None:
    tx_durum = ", ".join(f"'{d}'" for d in _TX_DURUM)
    m_tip = ", ".join(f"'{d}'" for d in _MATCH_TIP)
    m_durum = ", ".join(f"'{d}'" for d in _MATCH_DURUM)

    op.execute(
        f"""
        CREATE TABLE bank_transaction (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            -- Kaynak katmanı TAKILABİLİR: bugün 'ekstre' (CSV/Excel/MT940),
            -- yarın 'acik_bankacilik' AYNI motora bağlanır.
            kaynak      text NOT NULL DEFAULT 'ekstre',
            -- MÜKERRER KORUMASI. Bkz. modül başlığı.
            external_transaction_id text NOT NULL,
            islem_tarihi date NOT NULL,
            -- Tutar HER ZAMAN POZİTİF; işaret `yon`da (finansal_hareket kuralı).
            tutar_kurus bigint NOT NULL,
            yon         text NOT NULL,
            para_birimi text NOT NULL DEFAULT 'TRY',
            aciklama    text,
            karsi_ad    text,
            karsi_iban  text,
            -- Bankanın verdiği satırın TAMAMI. DEĞİŞTİRİLEMEZ (tetikleyici).
            raw_data    jsonb NOT NULL DEFAULT '{{}}'::jsonb,
            durum       text NOT NULL DEFAULT 'yeni',
            -- Yöneticinin notu (ilgisiz gelir / masraf kararı gerekçesi).
            not_metni   text,
            karar_veren_user_id uuid REFERENCES app_user (id) ON DELETE SET NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_bank_tx_tenant_external
                UNIQUE (tenant_id, external_transaction_id),
            CONSTRAINT uq_bank_tx_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_bank_tx_tutar CHECK (tutar_kurus > 0),
            CONSTRAINT ck_bank_tx_yon CHECK (yon IN ('giris','cikis')),
            CONSTRAINT ck_bank_tx_durum CHECK (durum IN ({tx_durum})),
            CONSTRAINT ck_bank_tx_kaynak CHECK (kaynak IN ('ekstre','acik_bankacilik'))
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_bank_tx_tenant_durum "
        "ON bank_transaction (tenant_id, durum, islem_tarihi DESC);"
    )
    # IBAN GEÇMİŞİ SORGUSU: "bu IBAN daha önce kiminle eşleşti".
    op.execute(
        "CREATE INDEX ix_bank_tx_iban ON bank_transaction (tenant_id, karsi_iban) "
        "WHERE karsi_iban IS NOT NULL;"
    )

    # --- raw_data DEĞİŞTİRİLEMEZ ------------------------------------------ #
    # Uygulama katmanında "yazmayız" demek yeterli değildi: bir sonraki
    # geliştirici bunu bilmez. Kural veritabanında durur.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION bank_tx_raw_data_sabit()
        RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
            IF NEW.raw_data IS DISTINCT FROM OLD.raw_data THEN
                RAISE EXCEPTION 'bank_transaction.raw_data degistirilemez';
            END IF;
            IF NEW.external_transaction_id IS DISTINCT FROM OLD.external_transaction_id THEN
                RAISE EXCEPTION 'bank_transaction.external_transaction_id degistirilemez';
            END IF;
            IF NEW.tutar_kurus IS DISTINCT FROM OLD.tutar_kurus
               OR NEW.yon IS DISTINCT FROM OLD.yon
               OR NEW.islem_tarihi IS DISTINCT FROM OLD.islem_tarihi THEN
                RAISE EXCEPTION 'bank_transaction tutar/yon/tarih degistirilemez';
            END IF;
            NEW.updated_at := now();
            RETURN NEW;
        END $$;
        """
    )
    op.execute(
        "CREATE TRIGGER trg_bank_tx_raw_data_sabit BEFORE UPDATE ON bank_transaction "
        "FOR EACH ROW EXECUTE FUNCTION bank_tx_raw_data_sabit();"
    )

    op.execute(
        f"""
        CREATE TABLE payment_match (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            bank_transaction_id uuid NOT NULL,
            -- Borcun sahibi. Kişi silinirse iz kalır (SET NULL).
            user_id     uuid REFERENCES app_user (id) ON DELETE SET NULL,
            unit_id     uuid,
            -- Kapatılan tahakkuk. NULL = daire alacağına yazılan FAZLA ödeme.
            assessment_id uuid,
            -- Bu satıra düşen pay (FIFO'da her ay ayrı satır).
            tutar_kurus bigint NOT NULL,
            confidence_score smallint NOT NULL DEFAULT 0,
            match_type  text NOT NULL,
            durum       text NOT NULL DEFAULT 'onerildi',
            -- Defter kaydı ve borç kapanışı — ikisi de İZLENEBİLİR olsun.
            finansal_hareket_id uuid,
            dues_payment_id uuid,
            receipt_id  uuid,
            karar_veren_user_id uuid REFERENCES app_user (id) ON DELETE SET NULL,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_payment_match_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_payment_match_tutar CHECK (tutar_kurus > 0),
            CONSTRAINT ck_payment_match_tip CHECK (match_type IN ({m_tip})),
            CONSTRAINT ck_payment_match_durum CHECK (durum IN ({m_durum})),
            FOREIGN KEY (bank_transaction_id, tenant_id)
                REFERENCES bank_transaction (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_payment_match_tx ON payment_match (tenant_id, bank_transaction_id);"
    )
    op.execute(
        "CREATE INDEX ix_payment_match_user "
        "ON payment_match (tenant_id, user_id, created_at DESC);"
    )
    # AYNI TAHAKKUK İKİ KEZ KAPATILAMAZ: onaylanmış eşleşmede (assessment,
    # tenant) tekildir. Kısmi indeks — geri alınmış/reddedilmiş satırlar
    # yolu yeniden açar (borç yeniden açılır, yeni eşleşme yazılabilir).
    op.execute(
        "CREATE UNIQUE INDEX uq_payment_match_acik_assessment "
        "ON payment_match (tenant_id, assessment_id) "
        "WHERE assessment_id IS NOT NULL AND durum = 'onaylandi';"
    )

    op.execute(
        """
        CREATE TABLE receipt (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            user_id     uuid REFERENCES app_user (id) ON DELETE SET NULL,
            unit_id     uuid,
            bank_transaction_id uuid,
            belge_no    text NOT NULL,
            tutar_kurus bigint NOT NULL,
            -- MinIO nesne anahtarı; PDF'in kendisi burada DEĞİL.
            pdf_key     text,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_receipt_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_receipt_tenant_belge UNIQUE (tenant_id, belge_no),
            CONSTRAINT ck_receipt_tutar CHECK (tutar_kurus > 0),
            FOREIGN KEY (bank_transaction_id, tenant_id)
                REFERENCES bank_transaction (id, tenant_id) ON DELETE SET NULL
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_receipt_user ON receipt (tenant_id, user_id, created_at DESC);"
    )

    for tablo in ("bank_transaction", "payment_match", "receipt"):
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_isolation ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
        # DELETE YOK — üçü de kayıt tutar. Yanlış eşleşme SİLİNMEZ,
        # `durum='geri_alindi'` olur ve ters kayıt yazılır (finansal_hareket
        # ile aynı ilke).
        op.execute(f"GRANT SELECT, INSERT, UPDATE ON {tablo} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS receipt;")
    op.execute("DROP TABLE IF EXISTS payment_match;")
    op.execute("DROP TRIGGER IF EXISTS trg_bank_tx_raw_data_sabit ON bank_transaction;")
    op.execute("DROP TABLE IF EXISTS bank_transaction;")
    op.execute("DROP FUNCTION IF EXISTS bank_tx_raw_data_sabit();")
