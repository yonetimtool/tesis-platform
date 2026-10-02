"""(P251 §10) PLATFORM GONDERIM GUNLUGU — e-posta, SMS, push; tum tesisler.

E-posta/SMS geri bildirimi (`mesaj_gonderim`) ve push denemeleri
(`push_gonderim`) tesis yoneticisinin ekranlarindaydi: ham saglayici
hatalari (535, 5.7.8, gecersiz jeton) yoneticiye gosteriliyordu. Bu
TEKNIK bir gunluktur ve platforma aittir.

RLS FORCE oldugundan uygulama rolu yalniz kendi tesisini gorur; platform
okuyucusu `audit_log_list` desenindeki gibi sahip yetkili SECURITY DEFINER
fonksiyondur. API yalniz `admin`e acar (RBAC). Arama, tesis, kanal, durum,
tarih araligi ve "yalniz basarisiz" suzgecleri; `count(*) OVER()` toplam.

`basarisiz` tanimi: e-posta/SMS -> basarisiz | yapilandirilmadi;
push -> basarisiz | gecersiz_token | yapilandirilmadi | noop | hedef_yok.
"""
from alembic import op

revision = "0166_p251_gonderim_gunlugu"
down_revision = "0165_p251_ortak_alan_gorsel"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"
_FN_SIG = (
    "public.gonderim_gunlugu_list(text, uuid, text, text, timestamptz, "
    "timestamptz, boolean, integer, integer)"
)


def upgrade() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.gonderim_gunlugu_list(
            p_kanal     text,
            p_tenant_id uuid,
            p_durum     text,
            p_ara       text,
            p_from      timestamptz,
            p_to        timestamptz,
            p_basarisiz boolean,
            p_limit     integer,
            p_offset    integer
        )
        RETURNS TABLE(
            id uuid, kanal text, tenant_id uuid, tesis_ad text,
            alici_ad text, hedef text, amac text, durum text, hata text,
            saglayici text, created_at timestamptz, total bigint
        )
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            WITH birlesik AS (
                SELECT m.id, m.kanal::text AS kanal, m.tenant_id,
                       u.ad AS alici_ad, m.hedef,
                       COALESCE(m.tur, m.amac::text) AS amac,
                       m.durum::text AS durum, m.hata, m.saglayici,
                       m.created_at,
                       (m.durum::text IN ('basarisiz', 'yapilandirilmadi')) AS basarisiz
                FROM public.mesaj_gonderim m
                LEFT JOIN public.app_user u ON u.id = m.user_id
                UNION ALL
                SELECT p.id, 'push' AS kanal, p.tenant_id,
                       u.ad AS alici_ad,
                       COALESCE(p.platform, '') ||
                         CASE WHEN p.token_son6 IS NULL THEN '' ELSE ' …' || p.token_son6 END
                         AS hedef,
                       p.kimlik AS amac, p.durum, p.hata_kodu AS hata, p.saglayici,
                       p.created_at,
                       (p.durum IN ('basarisiz', 'gecersiz_token', 'yapilandirilmadi',
                                    'noop', 'hedef_yok')) AS basarisiz
                FROM public.push_gonderim p
                LEFT JOIN public.app_user u ON u.id = p.user_id
            ),
            f AS (
                SELECT b.*, t.ad AS tesis_ad
                FROM birlesik b
                LEFT JOIN public.tenant t ON t.id = b.tenant_id
                WHERE (p_kanal     IS NULL OR b.kanal = p_kanal)
                  AND (p_tenant_id IS NULL OR b.tenant_id = p_tenant_id)
                  AND (p_durum     IS NULL OR b.durum = p_durum)
                  AND (p_basarisiz IS NOT TRUE OR b.basarisiz)
                  AND (p_from      IS NULL OR b.created_at >= p_from)
                  AND (p_to        IS NULL OR b.created_at <  p_to)
                  AND (p_ara IS NULL OR p_ara = ''
                       OR b.alici_ad ILIKE '%' || p_ara || '%'
                       OR b.hedef    ILIKE '%' || p_ara || '%'
                       OR t.ad       ILIKE '%' || p_ara || '%'
                       OR b.hata     ILIKE '%' || p_ara || '%')
            )
            SELECT id, kanal, tenant_id, tesis_ad, alici_ad, hedef, amac,
                   durum, hata, saglayici, created_at,
                   count(*) OVER() AS total
            FROM f
            ORDER BY created_at DESC, id
            LIMIT COALESCE(p_limit, 50) OFFSET COALESCE(p_offset, 0);
        $$;
        """
    )
    op.execute(f"REVOKE ALL ON FUNCTION {_FN_SIG} FROM PUBLIC;")
    op.execute(f"GRANT EXECUTE ON FUNCTION {_FN_SIG} TO {APP_ROLE};")
    # Platform zaman sorgusu (tesis suzgecsiz) icin.
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_mesaj_gonderim_zaman "
        "ON mesaj_gonderim (created_at DESC);"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_push_gonderim_zaman "
        "ON push_gonderim (created_at DESC);"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_push_gonderim_zaman;")
    op.execute("DROP INDEX IF EXISTS ix_mesaj_gonderim_zaman;")
    op.execute(f"DROP FUNCTION IF EXISTS {_FN_SIG};")
