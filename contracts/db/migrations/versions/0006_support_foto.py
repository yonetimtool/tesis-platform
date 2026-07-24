"""support_foto (0006) — destek taleplerine gorsel (WP-G).

* platform_support_ticket.foto_key            : yonetici talep fotosu (MinIO).
* platform_support_ticket.admin_cevap_foto_key: admin cevap fotosu (MinIO).

0004'teki SECURITY DEFINER fonksiyonlari (support_ticket_list /
support_ticket_answer) YENIDEN olusturulur: iki farkla (davranis bire bir
korunur):
  * RETURNS TABLE + SELECT listelerine iki foto kolonu eklenir.
  * answer'a p_cevap_foto_key parametresi: admin cevap fotosunu COALESCE'lar.

Return-type / imza degistigi icin CREATE OR REPLACE yetmez → once DROP.

URETIM: additive + geriye-uyumlu; 0001-0005 IMMUTABLE.
"""
from alembic import op

revision = "0006_support_foto"
down_revision = "0005_home_gorsel"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

# Eski (0004) imzalar — DROP edilecek.
_OLD_LIST_FN = "public.support_ticket_list(uuid, text, integer, integer)"
_OLD_ANSWER_FN = "public.support_ticket_answer(uuid, text, text)"
# Yeni imzalar — GRANT edilecek (list imzasi ayni; answer'a yeni text param).
_NEW_LIST_FN = "public.support_ticket_list(uuid, text, integer, integer)"
_NEW_ANSWER_FN = "public.support_ticket_answer(uuid, text, text, text)"


def upgrade() -> None:
    op.execute(
        "ALTER TABLE platform_support_ticket "
        "ADD COLUMN foto_key text, ADD COLUMN admin_cevap_foto_key text;"
    )
    # Eski imzalar DUSURULUR (return-type/param degisimi CREATE OR REPLACE'i
    # engeller; yeni parametreyle overload da olusturmamak icin).
    op.execute(f"DROP FUNCTION IF EXISTS {_OLD_LIST_FN};")
    op.execute(f"DROP FUNCTION IF EXISTS {_OLD_ANSWER_FN};")

    op.execute(
        """
        CREATE FUNCTION public.support_ticket_list(
            p_tenant_id uuid,
            p_durum     text,
            p_limit     integer,
            p_offset    integer
        )
        RETURNS TABLE(
            id uuid, tenant_id uuid, tenant_ad text, acan_user_id uuid,
            konu text, aciklama text, durum text, admin_cevap text,
            foto_key text, admin_cevap_foto_key text,
            created_at timestamptz, updated_at timestamptz, total bigint
        )
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            WITH f AS (
                SELECT s.*, t.ad AS tenant_ad
                FROM public.platform_support_ticket s
                JOIN public.tenant t ON t.id = s.tenant_id
                WHERE (p_tenant_id IS NULL OR s.tenant_id = p_tenant_id)
                  AND (p_durum     IS NULL OR s.durum     = p_durum)
            )
            SELECT id, tenant_id, tenant_ad, acan_user_id, konu, aciklama,
                   durum, admin_cevap, foto_key, admin_cevap_foto_key,
                   created_at, updated_at,
                   count(*) OVER() AS total
            FROM f
            ORDER BY created_at DESC
            LIMIT COALESCE(p_limit, 50) OFFSET COALESCE(p_offset, 0);
        $$;
        """
    )
    op.execute(
        """
        CREATE FUNCTION public.support_ticket_answer(
            p_id            uuid,
            p_durum         text,
            p_cevap         text,
            p_cevap_foto_key text
        )
        RETURNS TABLE(
            id uuid, tenant_id uuid, acan_user_id uuid, konu text,
            aciklama text, durum text, admin_cevap text,
            foto_key text, admin_cevap_foto_key text,
            created_at timestamptz, updated_at timestamptz
        )
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            UPDATE public.platform_support_ticket s
            SET durum                = COALESCE(p_durum, s.durum),
                admin_cevap          = COALESCE(p_cevap, s.admin_cevap),
                admin_cevap_foto_key = COALESCE(p_cevap_foto_key,
                                                s.admin_cevap_foto_key),
                updated_at           = now()
            WHERE s.id = p_id
              AND (p_durum IS NULL OR p_durum IN ('acik', 'cozuldu'))
            RETURNING s.id, s.tenant_id, s.acan_user_id, s.konu, s.aciklama,
                      s.durum, s.admin_cevap, s.foto_key, s.admin_cevap_foto_key,
                      s.created_at, s.updated_at;
        $$;
        """
    )
    for fn in (_NEW_LIST_FN, _NEW_ANSWER_FN):
        op.execute(f"REVOKE ALL ON FUNCTION {fn} FROM PUBLIC;")
        op.execute(f"GRANT EXECUTE ON FUNCTION {fn} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute(f"DROP FUNCTION IF EXISTS {_NEW_ANSWER_FN};")
    op.execute(f"DROP FUNCTION IF EXISTS {_NEW_LIST_FN};")
    # 0004 imzalarini geri kur.
    op.execute(
        """
        CREATE FUNCTION public.support_ticket_list(
            p_tenant_id uuid,
            p_durum     text,
            p_limit     integer,
            p_offset    integer
        )
        RETURNS TABLE(
            id uuid, tenant_id uuid, tenant_ad text, acan_user_id uuid,
            konu text, aciklama text, durum text, admin_cevap text,
            created_at timestamptz, updated_at timestamptz, total bigint
        )
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            WITH f AS (
                SELECT s.*, t.ad AS tenant_ad
                FROM public.platform_support_ticket s
                JOIN public.tenant t ON t.id = s.tenant_id
                WHERE (p_tenant_id IS NULL OR s.tenant_id = p_tenant_id)
                  AND (p_durum     IS NULL OR s.durum     = p_durum)
            )
            SELECT id, tenant_id, tenant_ad, acan_user_id, konu, aciklama,
                   durum, admin_cevap, created_at, updated_at,
                   count(*) OVER() AS total
            FROM f
            ORDER BY created_at DESC
            LIMIT COALESCE(p_limit, 50) OFFSET COALESCE(p_offset, 0);
        $$;
        """
    )
    op.execute(
        """
        CREATE FUNCTION public.support_ticket_answer(
            p_id     uuid,
            p_durum  text,
            p_cevap  text
        )
        RETURNS TABLE(
            id uuid, tenant_id uuid, acan_user_id uuid, konu text,
            aciklama text, durum text, admin_cevap text,
            created_at timestamptz, updated_at timestamptz
        )
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            UPDATE public.platform_support_ticket s
            SET durum       = COALESCE(p_durum, s.durum),
                admin_cevap = COALESCE(p_cevap, s.admin_cevap),
                updated_at  = now()
            WHERE s.id = p_id
              AND (p_durum IS NULL OR p_durum IN ('acik', 'cozuldu'))
            RETURNING s.id, s.tenant_id, s.acan_user_id, s.konu, s.aciklama,
                      s.durum, s.admin_cevap, s.created_at, s.updated_at;
        $$;
        """
    )
    for fn in (_OLD_LIST_FN, _OLD_ANSWER_FN):
        op.execute(f"REVOKE ALL ON FUNCTION {fn} FROM PUBLIC;")
        op.execute(f"GRANT EXECUTE ON FUNCTION {fn} TO {APP_ROLE};")
    op.execute(
        "ALTER TABLE platform_support_ticket "
        "DROP COLUMN IF EXISTS admin_cevap_foto_key, DROP COLUMN IF EXISTS foto_key;"
    )
