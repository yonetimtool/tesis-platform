"""(P205 §1) COK YONLU GIRIS — uyelikler E-POSTA VEYA TELEFONLA.

===========================================================================
NEDEN GEREKTI
===========================================================================
`tenant_uyelikleri` (goc 0092) yalniz `lower(email)` esliyordu. P205
tek bir giris alani istiyor: kullanici e-posta da yazabilir telefon da.

Fonksiyon DEGISTIRILDI, YENISI ACILMADI: iki fonksiyon tutmak, cagirinin
"hangisini cagirayim" karari vermesi demekti ve o karar zaten
fonksiyonun kendi isi (girdiyi tanimak).

===========================================================================
TELEFON BENZERSIZLIGI KALDIRILMADI
===========================================================================
P204 karari: `uq_app_user_telefon` UC yerde tasiyici
(`login-phone`, `giris/kod-iste`, kayit akisi) ve `tenant_id_by_phone`
onunla tenant cozuyor. Kaldirmak TELEFONLA GIRISI KIRARDI. Bu goc
kisiti GORMEZDEN GELMEZ, ondan FAYDALANIR: telefonla eslesme en fazla
BIR satir dondurur ve tesis secimi o durumda zaten cikmaz.

Geri alinabilir: `downgrade` fonksiyonu 0092'deki hâline dondurur.
"""
from alembic import op

APP_ROLE = "app_rw"

revision = "0095_kimlik_uyelikleri"
down_revision = "0094_mesai_ucret"
branch_labels = None
depends_on = None

_FN = "public.tenant_uyelikleri(text)"


def upgrade() -> None:
    # ONCE DROP: Postgres `CREATE OR REPLACE` ile GIRDI PARAMETRESININ
    # ADINI degistirtmiyor ("cannot change name of input parameter") ve
    # 0092'de ad `p_email`di. Olculdu — goc ilk kosumda bu hatayla
    # dustu. Ad `p_kimlik` olmali: fonksiyon artik yalniz e-posta
    # eslemiyor ve eski ad okuyani yaniltirdi.
    op.execute(f"DROP FUNCTION IF EXISTS {_FN};")
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_uyelikleri(p_kimlik text)
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
            -- E-POSTA VEYA TELEFON. Ikisi de tek sorguda taranir cunku
            -- cagiri girdinin turunu SOYLEMEK ZORUNDA DEGIL: "hangisini
            -- yazdim" karari kullanicinin degil sistemin isi (P205 §1).
            --
            -- Telefon E.164 normalize edilmis olarak gelir (istemci ve
            -- sunucu `normalize_phone` kullanir); burada HAM esleme
            -- yapilir, aksi hâlde ayni numaranin iki yazimi iki farkli
            -- kimlik sayilirdi.
            SELECT t.id, t.slug, t.ad, u.id, u.role::text, u.is_active,
                   u.password_hash, u.eposta_dogrulandi
            FROM app_user u
            JOIN tenant t ON t.id = u.tenant_id
            WHERE lower(u.email) = lower(btrim(p_kimlik))
               OR u.telefon = btrim(p_kimlik)
            ORDER BY t.ad;
        $$;
        """
    )
    op.execute(f"REVOKE ALL ON FUNCTION {_FN} FROM PUBLIC;")
    op.execute(f"GRANT EXECUTE ON FUNCTION {_FN} TO {APP_ROLE};")


def downgrade() -> None:
    op.execute(f"DROP FUNCTION IF EXISTS {_FN};")
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
