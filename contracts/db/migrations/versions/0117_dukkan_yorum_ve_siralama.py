"""(DUKKAN F3) `yorum` tablosu + siralama indeksleri.

===========================================================================
NEDEN `yorum` F5'TE DEGIL BURADA
===========================================================================
`01-veri-modeli.md` §8'de "bos tablo acma" kurali var: bos tablo, yarin
onu dolduracak kisiyi bugunku yarim fikre mahkum eder.

`yorum` O SINIFTAN DEGIL. Iki sebeple:
  1. Sekli TAMAMEN tasarlanmis (01 §6 ve 03 §2) — yarim bir fikir degil.
  2. F3'un SIRALAMA FORMULU ona DAYANIYOR. F5'e birakmak, F3'te
     yayinlanan formulu bir YALAN yapardi: agirliklardan soz edip
     karsiligi olmayan bir hesap yazmak.

Bos bir `yorum` tablosuyla formul dogru calisir (yorum bileseni 0) ve
F5 geldiginde TEK SATIR degismez.

===========================================================================
`is_id` NULLABLE — urunun en zor karari
===========================================================================
Islerin cogu telefonda hallolur; yalniz platform uzerinden biten ise
yorum hakki vermek yorum sayisini sifira yakin tutar ve pazar yeri
YORUMSUZ kalir. Yorumsuz pazar yeri ise yaramaz.

Cozum yorumlari FILTRELEMEK degil AYIRMAK: `kaynak` sutunu hangi yorumun
neye dayandigini SAKLAMIYOR, GOSTERIYOR.

GERI ALINABILIR.
"""
from alembic import op

revision = "0117_dukkan_yorum_ve_siralama"
down_revision = "0116_dukkan_sms_gonderim_izi"
branch_labels = None
depends_on = None

SEMA = "dukkan"
ROL = "dukkan_app"


def upgrade() -> None:
    op.execute(
        f"""
        CREATE TABLE {SEMA}.yorum (
            id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            isletme_id     uuid NOT NULL
                REFERENCES {SEMA}.isletme(id) ON DELETE CASCADE,
            yazan_id       uuid NOT NULL
                REFERENCES {SEMA}.dukkan_kullanici(id) ON DELETE RESTRICT,
            -- DOLU = dogrulanmis (platform uzerinden is). `is` tablosu
            -- F4'te geliyor; FK o gocte eklenecek.
            is_id          uuid,
            kaynak         text NOT NULL CHECK (kaynak IN ('platform', 'davet')),
            puan           smallint NOT NULL CHECK (puan BETWEEN 1 AND 5),
            metin          text,
            durum          text NOT NULL DEFAULT 'beklemede'
                CHECK (durum IN ('beklemede','yayinda','reddedildi','gizlendi')),
            moderasyon_not text,
            yayinlandi_at  timestamptz,
            created_at     timestamptz NOT NULL DEFAULT now(),
            updated_at     timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    # BIR ISE BIR YORUM. Kismi indeks cunku `is_id` davetli yorumlarda NULL
    # ve NULL'lar birbirine esit sayilmaz (normal UNIQUE ise yaramazdi).
    op.execute(
        f"CREATE UNIQUE INDEX uq_yorum_is ON {SEMA}.yorum (is_id) "
        "WHERE is_id IS NOT NULL;"
    )
    # DAVETLI yorumda: bir isletme + bir kisi = bir yorum.
    # (90 gunluk tekrar kurali uygulama katmaninda; bu kisit "ayni gun iki
    # yorum" gibi kaba tekrari veritabaninda keser.)
    op.execute(
        f"CREATE UNIQUE INDEX uq_yorum_davet_kisi ON {SEMA}.yorum "
        "(isletme_id, yazan_id) WHERE kaynak = 'davet';"
    )
    # Profil sayfasinin sicak yolu.
    op.execute(
        f"CREATE INDEX ix_yorum_isletme ON {SEMA}.yorum "
        "(isletme_id, durum, yayinlandi_at DESC);"
    )
    # Siralama hesabinin okudugu kume.
    op.execute(
        f"CREATE INDEX ix_yorum_hesap ON {SEMA}.yorum (isletme_id, kaynak) "
        "WHERE durum = 'yayinda';"
    )

    # ------------------------------------------------------------------ #
    # SIRALAMA INDEKSLERI (F3 arama yollari)
    # ------------------------------------------------------------------ #
    # `ix_isletme_gorunur` (goc 0115) `siralama_puani DESC` uzerinde ama
    # IKINCIL ANAHTAR YOK. Esit puanlarda PostgreSQL sirayi garanti etmez
    # ve sayfa 2'de ayni isletme tekrar cikabilir. Indeksi (puan, id)
    # ikilisiyle yeniliyoruz — sorgudaki ORDER BY ile BIREBIR ayni.
    op.execute(f"DROP INDEX IF EXISTS {SEMA}.ix_isletme_gorunur;")
    op.execute(
        f"CREATE INDEX ix_isletme_gorunur ON {SEMA}.isletme "
        "(siralama_puani DESC, id) "
        "WHERE durum = 'onayli' AND dogrulama_seviyesi >= 1;"
    )
    # "Yeni eklenenler" siralamasi.
    op.execute(
        f"CREATE INDEX ix_isletme_yeni ON {SEMA}.isletme "
        "(onaylandi_at DESC, id) "
        "WHERE durum = 'onayli' AND dogrulama_seviyesi >= 1;"
    )

    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON {SEMA}.yorum TO {ROL};")


def downgrade() -> None:
    op.execute(f"DROP TABLE IF EXISTS {SEMA}.yorum CASCADE;")
    op.execute(f"DROP INDEX IF EXISTS {SEMA}.ix_isletme_yeni;")
    op.execute(f"DROP INDEX IF EXISTS {SEMA}.ix_isletme_gorunur;")
    op.execute(
        f"CREATE INDEX ix_isletme_gorunur ON {SEMA}.isletme "
        "(siralama_puani DESC) "
        "WHERE durum = 'onayli' AND dogrulama_seviyesi >= 1;"
    )
