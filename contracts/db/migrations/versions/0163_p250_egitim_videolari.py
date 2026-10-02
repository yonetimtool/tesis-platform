"""(P250 §4) KURULUM EGITIM VIDEOLARI — baglanti platformda, izlenme hesapta.

===========================================================================
(a) `egitim_videosu` — PLATFORM TABLOSU (tenant'siz)
===========================================================================
Videolari platform yoneticisi YouTube'a "liste disi" yukler; sistem YALNIZ
video KIMLIGINI saklar (11 karakter) — video sunucumuzda DURMAZ. Ayni video
butun tesislere gosterilir, yani satir tesise ait degil.

Desen `surum_politikasi` (0091) ile ayni: RLS ACIK + FORCE, POLITIKA YOK,
erisim yalniz iki SECURITY DEFINER fonksiyonundan. `app_rw` tabloyu
dogrudan goremez ve yazamaz; yazma fonksiyonu uc tarafinda platform
admini kapisinin arkasinda (`require_role("admin")`).

`set_kodu`: bugun yalniz `yonetici` (kurulum sihirbazi). Yapi ileride
sakin ve guvenlik icin AYRI video setlerine izin verir — yeni set yeni
satirlardir, sema degismez.

`surum`: video DEGISTIRILINCE (youtube_id farkliysa) bir artar. Izlendi
isareti hangi surum icin konduysa ONA aittir; yeni video "izlenmedi"
gorunur. Baslik/aciklama/sira/aktiflik degisimi surumu ARTIRMAZ.
Gerekce: docs/P250-kararlar.md §4.

===========================================================================
(b) `egitim_izleme` — HESABA KAYITLI izlendi bilgisi
===========================================================================
Web ve mobil AYNI satiri okur. Tesis kapsamli (RLS politikasi). Bir
satir = bir kisi + bir adim; yeniden izleme `surum`u ve zamani gunceller.
"""
from alembic import op

APP_ROLE = "app_rw"

revision = "0163_p250_egitim_videolari"
down_revision = "0162_p250_hosgeldin"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE egitim_videosu (
            set_kodu    text NOT NULL,
            adim_kodu   text NOT NULL,
            youtube_id  text NOT NULL
                CONSTRAINT ck_egitim_videosu_id CHECK (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
            baslik      text NOT NULL
                CONSTRAINT ck_egitim_videosu_baslik CHECK (btrim(baslik) <> '' AND length(baslik) <= 200),
            aciklama    text NULL
                CONSTRAINT ck_egitim_videosu_aciklama CHECK (aciklama IS NULL OR length(aciklama) <= 500),
            sira        integer NOT NULL DEFAULT 0,
            aktif       boolean NOT NULL DEFAULT true,
            surum       integer NOT NULL DEFAULT 1,
            updated_at  timestamptz NOT NULL DEFAULT now(),
            updated_by  uuid NULL,
            PRIMARY KEY (set_kodu, adim_kodu),
            CONSTRAINT ck_egitim_videosu_set CHECK (set_kodu ~ '^[a-z_]{1,30}$'),
            CONSTRAINT ck_egitim_videosu_adim CHECK (adim_kodu ~ '^[a-z_]{1,40}$')
        );
        """
    )
    op.execute("ALTER TABLE egitim_videosu ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE egitim_videosu FORCE ROW LEVEL SECURITY;")

    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.egitim_videosu_oku(p_set text)
        RETURNS TABLE (adim_kodu text, youtube_id text, baslik text,
                       aciklama text, sira integer, aktif boolean,
                       surum integer, updated_at timestamptz)
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path = public, pg_temp
        AS $$
            SELECT v.adim_kodu, v.youtube_id, v.baslik, v.aciklama, v.sira,
                   v.aktif, v.surum, v.updated_at
              FROM egitim_videosu v
             WHERE v.set_kodu = p_set
             ORDER BY v.sira, v.adim_kodu;
        $$;
        """
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.egitim_videosu_yaz(
            p_set text, p_adim text, p_youtube_id text, p_baslik text,
            p_aciklama text, p_sira integer, p_aktif boolean, p_kisi uuid)
        RETURNS TABLE (adim_kodu text, youtube_id text, baslik text,
                       aciklama text, sira integer, aktif boolean,
                       surum integer, updated_at timestamptz)
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = public, pg_temp
        AS $$
        -- Donus sutunlari (adim_kodu...) tablo sutunlariyla AYNI ADDA;
        -- ON CONFLICT (...) sutun olarak okunsun.
        #variable_conflict use_column
        BEGIN
            INSERT INTO egitim_videosu AS v
                (set_kodu, adim_kodu, youtube_id, baslik, aciklama, sira,
                 aktif, updated_by)
            VALUES (p_set, p_adim, p_youtube_id, p_baslik, p_aciklama,
                    p_sira, p_aktif, p_kisi)
            ON CONFLICT (set_kodu, adim_kodu) DO UPDATE SET
                youtube_id = EXCLUDED.youtube_id,
                baslik     = EXCLUDED.baslik,
                aciklama   = EXCLUDED.aciklama,
                sira       = EXCLUDED.sira,
                aktif      = EXCLUDED.aktif,
                updated_by = EXCLUDED.updated_by,
                updated_at = now(),
                -- VIDEO DEGISTIYSE yeni surum: eski "izlendi" isaretleri
                -- yeni videoya SAYILMAZ (bkz. goc basligi).
                surum = CASE WHEN v.youtube_id IS DISTINCT FROM EXCLUDED.youtube_id
                             THEN v.surum + 1 ELSE v.surum END;
            RETURN QUERY
                SELECT e.adim_kodu, e.youtube_id, e.baslik, e.aciklama,
                       e.sira, e.aktif, e.surum, e.updated_at
                  FROM egitim_videosu e
                 WHERE e.set_kodu = p_set AND e.adim_kodu = p_adim;
        END;
        $$;
        """
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.egitim_videosu_sil(p_set text, p_adim text)
        RETURNS boolean
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path = public, pg_temp
        AS $$
            WITH s AS (
                DELETE FROM egitim_videosu
                 WHERE set_kodu = p_set AND adim_kodu = p_adim
                RETURNING 1
            )
            SELECT EXISTS (SELECT 1 FROM s);
        $$;
        """
    )
    for imza in (
        "egitim_videosu_oku(text)",
        "egitim_videosu_yaz(text, text, text, text, text, integer, boolean, uuid)",
        "egitim_videosu_sil(text, text)",
    ):
        op.execute(f"REVOKE ALL ON FUNCTION public.{imza} FROM PUBLIC;")
        op.execute(f"GRANT EXECUTE ON FUNCTION public.{imza} TO {APP_ROLE};")

    # (b) izlenme — tesis kapsamli
    op.execute(
        """
        CREATE TABLE egitim_izleme (
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            user_id     uuid NOT NULL,
            set_kodu    text NOT NULL,
            adim_kodu   text NOT NULL,
            surum       integer NOT NULL,
            izlendi_at  timestamptz NOT NULL DEFAULT now(),
            PRIMARY KEY (tenant_id, user_id, set_kodu, adim_kodu),
            CONSTRAINT fk_egitim_izleme_user FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute("ALTER TABLE egitim_izleme ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE egitim_izleme FORCE ROW LEVEL SECURITY;")
    op.execute(
        "CREATE POLICY egitim_izleme_isolation ON egitim_izleme "
        "USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid) "
        "WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);"
    )
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON egitim_izleme TO {APP_ROLE};")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS egitim_izleme;")
    op.execute("DROP FUNCTION IF EXISTS public.egitim_videosu_sil(text, text);")
    op.execute(
        "DROP FUNCTION IF EXISTS public.egitim_videosu_yaz"
        "(text, text, text, text, text, integer, boolean, uuid);"
    )
    op.execute("DROP FUNCTION IF EXISTS public.egitim_videosu_oku(text);")
    op.execute("DROP TABLE IF EXISTS egitim_videosu;")
