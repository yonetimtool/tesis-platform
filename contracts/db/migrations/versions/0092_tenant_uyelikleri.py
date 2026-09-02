"""(P203 §2) COKLU TESIS — bir e-postanin uyelikleri.

===========================================================================
ONCE OLCUM: MODEL BUNU ZATEN DESTEKLIYOR MU
===========================================================================
EVET — ve bu, yaklasimin tamamini belirledi. Olculen kisitlar:

    uq_app_user_tenant_email        UNIQUE (tenant_id, email)
    uq_app_user_tenant_email_lower  UNIQUE (tenant_id, lower(email))
    uq_app_user_telefon             UNIQUE (telefon) WHERE telefon NOT NULL

E-posta TESIS ICINDE benzersiz, PLATFORM GENELINDE DEGIL. Yani ayni kisi
N tesiste N AYRI `app_user` satiri olarak durabilir ve HER SATIRIN KENDI
ROLU vardir. Istenen davranis ("birinde yonetici, otekinde sakin") sema
degisikligi GEREKTIRMIYOR.

TELEFON ISE GLOBAL BENZERSIZ: ayni kisi iki tesiste ayni telefonu
TASIYAMAZ. Bu bir kisittir ama akisi engellemez — P197'den beri kimlik
E-POSTADIR (telefon opsiyonel) ve giris e-postayla yapilir.

===========================================================================
NEDEN SECURITY DEFINER
===========================================================================
"Bu e-posta hangi tesislerde var" sorusu TANIMI GEREGI tenant sinirini
gecer; RLS altinda yanitlanamaz. `tenant_id_by_slug` / `yonetici_by_email`
ile AYNI SINIF ve ayni sertlestirme: `search_path` sabit, PUBLIC'ten
REVOKE, yalniz `app_rw`ye GRANT.

FONKSIYON PAROLA HASH'I DONER ve bu bilincli: cagiran uc, dogrulamayi
`verify_password` ile YAPAR. Alternatif (parolayi SQL'e sokmak) bcrypt'i
veritabanina tasimak olurdu. Uygulama katmani hash'i zaten okuyor —
`login` tek tenant icinde tam olarak bunu yapiyor; degisen sey KAPSAM.

SIZINTI YUZEYI: fonksiyon E-POSTAYI BILEN cagiriya uyelik listesi verir.
Bu yuzden onu KULLANAN uc parolayi da dogrular (`/auth/tesislerim`) ya da
zaten kimlikli oturum ister (`/me/tesislerim`). Fonksiyonun kendisi
`app_rw`ye acik; kapiyi UC koyar.
"""
from alembic import op

APP_ROLE = "app_rw"

revision = "0092_tenant_uyelikleri"
down_revision = "0091_surum_politikasi"
branch_labels = None
depends_on = None

_FN = "public.tenant_uyelikleri(text)"


def upgrade() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_uyelikleri(p_email text)
        RETURNS TABLE (
            tenant_id         uuid,
            slug              text,
            tenant_ad         text,
            user_id           uuid,
            rol               text,
            is_active         boolean,
            password_hash     text,
            eposta_dogrulandi boolean
        )
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path = public, pg_temp
        AS $$
            SELECT t.id, t.slug, t.ad, u.id, u.role::text, u.is_active,
                   u.password_hash, u.eposta_dogrulandi
            FROM app_user u
            JOIN tenant t ON t.id = u.tenant_id
            WHERE lower(u.email) = lower(btrim(p_email))
            ORDER BY t.ad;
        $$;
        """
    )
    op.execute(f"REVOKE ALL ON FUNCTION {_FN} FROM PUBLIC;")
    op.execute(f"GRANT EXECUTE ON FUNCTION {_FN} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute(f"DROP FUNCTION IF EXISTS {_FN};")
