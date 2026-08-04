"""tanitim iletisim (0033) — P127.2: kok alan adindaki iletisim formu.

NEDEN YENI BIR TABLO, `iletisim_mesaji` DEGIL: o tablo TENANT'A aittir
(P38 portal formu; bir sitenin ziyaretcisi o sitenin yonetimine yazar).
Buradaki form TANITIM SITESINDEDIR ve yazan kisinin HENUZ BIR TESISI
YOKTUR — gelen sey bir MUSTERI ADAYIDIR, platformun kendisine gelir.
`tenant_id`yi nullable yapip iki farkli anlami tek tabloya doldurmak, her
sorguda "bu satir hangi anlamda?" sorusunu uretirdi.

TENANT'SIZ TABLO + RLS: satirin sahibi bir tesis olmadigi icin
`app.current_tenant_id` uzerine kurulu bir politika yazilamaz. Iki secenek
vardi:
  (a) RLS'i bu tabloda kapatmak ve app_rw'ye dogrudan INSERT vermek,
  (b) yazma/okumayi SECURITY DEFINER fonksiyonlarina kapatmak.
(b) SECILDI (0002 `audit_log_list` ve 0004 `support_ticket_*` deseni):
app_rw tabloya DOGRUDAN erisemez; yazma tek bir fonksiyondan, okuma tek
bir fonksiyondan gecer. Boylece PUBLIC (kimliksiz) uc, tablonun tamamini
okuyabilecek bir yetki tasimaz — form gonderen biri baska adaylarin
adini/telefonunu HICBIR kosulda goremez.

KVKK: gelen kayit KISISEL VERIDIR (ad + iletisim). Gecelik retention
gorevine (`backend/app/retention.py`) BILEREK BAGLANMADI ve bu bir
eksiklik degil bekleyen bir KARARDIR: o gorev TENANT KAPSAMLI verinin
suresini uygular (ziyaretci, kargo, rezervasyon...); ticari iletisim
kaydinin ne kadar saklanacagi ise bir IS kararidir ve Kerem'e sorulmadan
sayi uydurmak, KVKK belgesinde savunulamayacak bir sure yazmak olurdu.
Bugunku durum: kayit KALICIDIR, `okundu` ile isaretlenir. Sure kararindan
sonra bu tabloya bir madde eklemek tek satirlik istir (plan: P127 Notes).

Revision ID: 0033_tanitim_iletisim
Revises: 0032_denetci_rolu
"""
from __future__ import annotations

from alembic import op

revision = "0033_tanitim_iletisim"
down_revision = "0032_denetci_rolu"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

_EKLE_FN = "public.tanitim_iletisim_ekle(text, text, text, text, text)"
_LISTE_FN = "public.tanitim_iletisim_listele(boolean, integer, integer)"
_OKUNDU_FN = "public.tanitim_iletisim_okundu(uuid, boolean)"


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE tanitim_iletisim (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ad         text NOT NULL,
            email      text,
            telefon    text,
            mesaj      text NOT NULL,
            -- Hangi dilde yazildi: donuste ayni dilde cevap yazilabilsin.
            dil        text,
            okundu     boolean NOT NULL DEFAULT false,
            created_at timestamptz NOT NULL DEFAULT now()
        );
        """
    )
    # Yeni/okunmamis kayitlar once gorunur (admin listesi bu siradadir).
    op.execute(
        "CREATE INDEX ix_tanitim_iletisim_created ON tanitim_iletisim (created_at DESC);"
    )
    # RLS ACIK ve POLITIKA YOK: app_rw tabloyu dogrudan goremez/yazamaz.
    # Erisim YALNIZ asagidaki SECURITY DEFINER fonksiyonlarindan.
    op.execute("ALTER TABLE tanitim_iletisim ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE tanitim_iletisim FORCE ROW LEVEL SECURITY;")

    # --- YAZMA: public uc buradan gecer (kimlik yok, tenant yok) ----------
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tanitim_iletisim_ekle(
            p_ad      text,
            p_email   text,
            p_telefon text,
            p_mesaj   text,
            p_dil     text
        )
        RETURNS uuid
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            INSERT INTO public.tanitim_iletisim (ad, email, telefon, mesaj, dil)
            VALUES (p_ad, p_email, p_telefon, p_mesaj, p_dil)
            RETURNING id;
        $$;
        """
    )

    # --- OKUMA: YALNIZ platform admini (API katmani rolu zorlar) ---------
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tanitim_iletisim_listele(
            p_okundu boolean,
            p_limit  integer,
            p_offset integer
        )
        RETURNS TABLE(
            id uuid, ad text, email text, telefon text, mesaj text,
            dil text, okundu boolean, created_at timestamptz, total bigint
        )
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            WITH f AS (
                SELECT * FROM public.tanitim_iletisim
                WHERE (p_okundu IS NULL OR okundu = p_okundu)
            )
            SELECT id, ad, email, telefon, mesaj, dil, okundu, created_at,
                   count(*) OVER() AS total
            FROM f
            ORDER BY created_at DESC
            LIMIT COALESCE(p_limit, 50) OFFSET COALESCE(p_offset, 0);
        $$;
        """
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tanitim_iletisim_okundu(
            p_id     uuid,
            p_okundu boolean
        )
        RETURNS TABLE(
            id uuid, ad text, email text, telefon text, mesaj text,
            dil text, okundu boolean, created_at timestamptz
        )
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            UPDATE public.tanitim_iletisim
            SET okundu = COALESCE(p_okundu, okundu)
            WHERE id = p_id
            RETURNING id, ad, email, telefon, mesaj, dil, okundu, created_at;
        $$;
        """
    )

    # Fonksiyonlar YALNIZ app rolune; PUBLIC'ten cekilir (SECURITY DEFINER
    # hijyeni — 0004 ile ayni).
    for fn in (_EKLE_FN, _LISTE_FN, _OKUNDU_FN):
        op.execute(f"REVOKE ALL ON FUNCTION {fn} FROM PUBLIC;")
        op.execute(f"GRANT EXECUTE ON FUNCTION {fn} TO {APP_ROLE};")


def downgrade() -> None:
    for fn in (_EKLE_FN, _LISTE_FN, _OKUNDU_FN):
        op.execute(f"DROP FUNCTION IF EXISTS {fn};")
    op.execute("DROP TABLE IF EXISTS tanitim_iletisim;")
