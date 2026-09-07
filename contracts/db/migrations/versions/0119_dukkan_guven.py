"""(DUKKAN F5) GUVEN — yorum daveti, cevap, sikayet, aski gecmisi.

===========================================================================
`yorum` TABLOSU F3'TE ACILMISTI
===========================================================================
Siralama formulu ona dayaniyordu ve ertelemek formulu bir YALAN yapardi
(bkz. goc 0117 basligi). Bu goc yorumun CEVRESINI kuruyor.

===========================================================================
IKI KATMANLI YORUM — NEDEN
===========================================================================
Ideal kural "yalniz platform uzerinden tamamlanmis ise yorum yazilir"
olurdu ve sahte yorumu neredeyse tumuyle keserdi.

Gercek hayat baska: kullanici numarayi gorur, TELEFONLA ARAR, is biter.
Platform bunu hic gormez. Bu bir kacak degil, BEKLENEN davranis.

Ideal kurali uygularsak yorumlarin ~%90'i DOGMAZ, isletmelerin cogu
"0 yorum" gorunur ve pazar yeri YORUMSUZ kalir. Yorumsuz pazar yeri ise
yaramaz. KATI OLAN KURAL, BURADA GUVENLI OLAN KURAL DEGIL.

Cozum yorumlari FILTRELEMEK degil AYIRMAK:
  kaynak='platform' -> `is_kaydi` kaydina bagli, ROZETLI, tam agirlik
  kaynak='davet'    -> isletmenin daveti + OTP, rozetsiz, 0.3 agirlik

===========================================================================
DAVET KOTASI — SAHTE YORUMUN MALIYETINI GERCEK ISE BAGLAMAK
===========================================================================
Kotasiz davet, "bana 50 yorum yaz" demenin platform onayli yolu olurdu.
Kota, sahte yorum uretmenin maliyetini GERCEK IS YAPMAYA bagliyor: hic
teklif vermemis bir isletme davet GONDEREMEZ.

Bu sahte yorumu BITIRMIYOR — PAHALI hale getiriyor. Bitirdigini iddia
eden bir tasarim yanlis olurdu (docs/dukkan/03-guven-ve-fraud.md §7).

GERI ALINABILIR.
"""
from alembic import op

revision = "0119_dukkan_guven"
down_revision = "0118_dukkan_talep_teklif_is"
branch_labels = None
depends_on = None

SEMA = "dukkan"
ROL = "dukkan_app"


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # YORUM DAVETI
    # ------------------------------------------------------------------ #
    # Kod HASH'LENEREK saklanir (telefon dogrulamayla ayni ilke): duz
    # metin saklamak, veritabanini okuyabilen birinin baskasi adina yorum
    # yazmasi demekti.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.yorum_daveti (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            isletme_id    uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            telefon       text NOT NULL,
            kod_hash      text NOT NULL,
            durum         text NOT NULL DEFAULT 'gonderildi'
                CHECK (durum IN ('gonderildi','kullanildi','suresi_doldu')),
            deneme        smallint NOT NULL DEFAULT 0,
            gecerlilik    timestamptz NOT NULL,
            kullanildi_at timestamptz,
            created_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_yorum_daveti_kota ON {SEMA}.yorum_daveti "
        "(isletme_id, created_at DESC);"
    )
    op.execute(
        f"CREATE INDEX ix_yorum_daveti_telefon ON {SEMA}.yorum_daveti "
        "(telefon, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # YORUMA CEVAP — cogu durumda EN IYI SAVUNMA
    # ------------------------------------------------------------------ #
    # Isletme yorumu SILEMEZ (silebilseydi sistemin tamami anlamsiz
    # olurdu) ama CEVAP VEREBILIR. Okuyucu iki tarafi gorur.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.yorum_cevap (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            yorum_id   uuid NOT NULL UNIQUE
                REFERENCES {SEMA}.yorum(id) ON DELETE CASCADE,
            isletme_id uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            metin      text NOT NULL,
            durum      text NOT NULL DEFAULT 'yayinda'
                CHECK (durum IN ('yayinda','gizlendi')),
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now()
        );
        """
    )

    # ------------------------------------------------------------------ #
    # SIKAYET — 6563 gereginden BAGIMSIZ olarak da dogru
    # ------------------------------------------------------------------ #
    # `sikayetci_id` NULLABLE: sikayet KIMLIKSIZ de yapilabilmeli.
    # Kimlik zorunlu olsaydi, dolandirilan ve hesabi olmayan bir
    # kullanici sikayet EDEMEZDI — oysa en cok onun sesi duyulmali.
    op.execute(
        f"""
        CREATE TABLE {SEMA}.sikayet (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            sikayetci_id  uuid REFERENCES {SEMA}.dukkan_kullanici(id)
                          ON DELETE SET NULL,
            iletisim      text,
            isletme_id    uuid REFERENCES {SEMA}.isletme(id) ON DELETE SET NULL,
            yorum_id      uuid REFERENCES {SEMA}.yorum(id) ON DELETE SET NULL,
            is_id         uuid REFERENCES {SEMA}.is_kaydi(id) ON DELETE SET NULL,
            tip           text NOT NULL
                CHECK (tip IN ('odeme','hizmet','sahte_isletme','yorum',
                               'kisisel_veri','diger')),
            metin         text NOT NULL,
            durum         text NOT NULL DEFAULT 'acik'
                CHECK (durum IN ('acik','incelemede','kapandi')),
            sonuc         text,
            atanan_id     uuid REFERENCES {SEMA}.dukkan_kullanici(id)
                          ON DELETE SET NULL,
            ip            text,
            kapandi_at    timestamptz,
            created_at    timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    op.execute(
        f"CREATE INDEX ix_sikayet_kuyruk ON {SEMA}.sikayet (created_at) "
        "WHERE durum IN ('acik','incelemede');"
    )
    # ODEME SIKAYETI SAYIMININ SICAK YOLU: otomatik aski esigi buna bakar.
    op.execute(
        f"CREATE INDEX ix_sikayet_isletme_tip ON {SEMA}.sikayet "
        "(isletme_id, tip, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # YORUM: moderasyon icin ek alanlar
    # ------------------------------------------------------------------ #
    op.execute(
        f"""
        ALTER TABLE {SEMA}.yorum
          ADD COLUMN inceleyen_id uuid REFERENCES {SEMA}.dukkan_kullanici(id)
                     ON DELETE SET NULL,
          ADD COLUMN incelendi_at timestamptz,
          -- Supheli oruntu ISARETI. Otomatik RET DEGIL: ortak ev/isyeri
          -- IP'si mesru olabilir. Yalnizca moderasyon kuyruguna dusurur.
          ADD COLUMN supheli_sebep text,
          ADD COLUMN ip text;
        """
    )
    op.execute(
        f"CREATE INDEX ix_yorum_moderasyon ON {SEMA}.yorum (created_at) "
        "WHERE durum = 'beklemede';"
    )

    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON "
        f"{SEMA}.yorum_daveti, {SEMA}.yorum_cevap, {SEMA}.sikayet TO {ROL};"
    )


def downgrade() -> None:
    op.execute(
        f"ALTER TABLE {SEMA}.yorum "
        "DROP COLUMN IF EXISTS inceleyen_id, "
        "DROP COLUMN IF EXISTS incelendi_at, "
        "DROP COLUMN IF EXISTS supheli_sebep, "
        "DROP COLUMN IF EXISTS ip;"
    )
    for t in ("sikayet", "yorum_cevap", "yorum_daveti"):
        op.execute(f"DROP TABLE IF EXISTS {SEMA}.{t} CASCADE;")
