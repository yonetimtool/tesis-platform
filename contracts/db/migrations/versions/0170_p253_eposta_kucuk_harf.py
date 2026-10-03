"""(P253 acil) E-POSTA KUCUK HARF — mevcut kayitlar + yazma tetigi.

OLCULEN KUSUR (prod): 4 adres buyuk harfle basliyor; 4 adres harf farkiyla
IKI kez kayitli. Ekranlar buyuk harfi engellemiyordu, sunucu da kucultmuyordu.

Bu goc:

1. `public.eposta_normalle(text)`: bas/son bosluk kirpilir, YALNIZ ASCII
   A-Z kucultulur. `lower()` DEGIL: veritabaninin yerel ayarina baglidir ve
   Turkce kurali (I -> ı) e-postayi bozardi. Python karsiligi
   `app/eposta.py::eposta_normalle` — ikisi ayni sonucu verir (test kilidi).

2. E-posta tasiyan 15 sutunun HER BIRINE `BEFORE INSERT OR UPDATE OF <sutun>`
   tetigi: hangi yoldan yazilirsa yazilsin (API, SSO, Excel, tohum, SQL
   fonksiyonu) kayda kucuk harf girer. Uygulama da ayrica kucultur; tetik
   unutulan bir yolun guvencesidir. `UPDATE OF`: yalniz e-posta sutunu
   yazilinca calisir — e-postasina dokunulmayan satirin baska guncellemesi
   etkilenmez.

3. Mevcut kayitlar SATIR SATIR kucultulur. Kucuk hali bir BENZERSIZLIK
   kuralina takilan satir (ornek: AYNI tesiste `Ali@x` ve `ali@x`)
   DEGISTIRILMEZ ve BIRLESTIRILMEZ — kullanici karari: "listele, bana sor".
   Atlananlar `docs/eposta-harf-cakisma.sql` sorgusuyla listelenir (o
   sorgu gocten sonra da ayni sonucu verir: atlanan = hala kucuk olmayan).

   Farkli tesislerdeki harf farki cakisma DEGILDIR (`app_user` benzersizligi
   tesis icinde) — yalniz kucultulur.

   `tesis_uyelik` ozel: `uq_tesis_uyelik_birincil_eposta` TUM tesislerde
   tekildir. Iki tesiste harf farkiyla iki "birincil" satir kucultulunce
   cakisir; tablo bugun okunmuyor (models.TesisUyelik) ve iki satir da
   korunur — yalniz EN ESKISI birincil kalir.
"""
from alembic import op

revision = "0170_p253_eposta_kucuk_harf"
down_revision = "0169_p253_parti_rapor_hazir"
branch_labels = None
depends_on = None

#: (sema, tablo, sutun) — e-posta tasiyan HER sutun (information_schema
#: taramasi, 2026-10-03). Yeni e-posta sutunu eklenirse buraya da yazilir;
#: `test_eposta_kucuk_harf.py` katalogdaki sutunlarla bu listeyi karsilastirir.
SUTUNLAR = (
    ("public", "app_user", "email"),
    ("public", "tesis_uyelik", "eposta"),
    ("public", "oauth_kimlik", "eposta"),
    ("public", "yonetici_basvuru", "eposta"),
    ("public", "kayit_onay_kuyrugu", "eposta"),
    ("public", "kayit_dogrulama", "eposta"),
    ("public", "personel_kayit", "email"),
    ("public", "firma", "email"),
    ("public", "tenant", "yonetim_email"),
    ("public", "tenant_portal", "iletisim_email"),
    ("public", "iletisim_mesaji", "email"),
    ("public", "tanitim_iletisim", "email"),
    ("dukkan", "dukkan_kullanici", "eposta"),
    ("dukkan", "isletme", "eposta"),
    ("dukkan", "reklam_satin_alma", "fatura_eposta"),
)


def _tetik_adi(tablo: str) -> str:
    return f"trg_{tablo}_eposta_kucuk"


def birincil_ikiz_sql(tablo: str = "tesis_uyelik") -> str:
    """Harf farkli birincil ikizlerde yalniz EN ESKISI birincil kalir."""
    return f"""
        UPDATE {tablo} t SET birincil = false
         WHERE t.birincil
           AND EXISTS (
             SELECT 1 FROM {tablo} o
              WHERE o.birincil AND o.id <> t.id
                AND public.eposta_normalle(o.eposta) = public.eposta_normalle(t.eposta)
                AND (o.created_at, o.id) < (t.created_at, t.id));
        """


def kucult_sql(sema: str, tablo: str, sutun: str) -> str:
    """Satir satir kucultur; benzersizlige takilan satir ATLANIR (birlestirme
    yok). Test (`test_eposta_kucuk_harf.py`) ayni SQL'i gecici tabloda kosar."""
    return f"""
        DO $$
        DECLARE r record; atlanan int := 0;
        BEGIN
          FOR r IN SELECT ctid AS c FROM {sema}.{tablo}
                    WHERE {sutun} IS DISTINCT FROM public.eposta_normalle({sutun})
          LOOP
            BEGIN
              UPDATE {sema}.{tablo} SET {sutun} = public.eposta_normalle({sutun})
               WHERE ctid = r.c;
            EXCEPTION WHEN unique_violation THEN
              atlanan := atlanan + 1;
            END;
          END LOOP;
          IF atlanan > 0 THEN
            RAISE WARNING '{sema}.{tablo}.{sutun}: % satir harf cakismasi '
              'nedeniyle KUCULTULMEDI — docs/eposta-harf-cakisma.sql', atlanan;
          END IF;
        END $$;
        """


def upgrade() -> None:
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.eposta_normalle(e text)
        RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
          SELECT translate(btrim(e), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                                     'abcdefghijklmnopqrstuvwxyz')
        $$;
        """
    )
    # Genel tetik: sutun adi TG_ARGV[0]. jsonb_populate_record ile NEW'in
    # o alani degistirilir (PL/pgSQL'de dinamik alan atamasi yok).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.eposta_kucuk_tetik()
        RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE
          ham text := to_jsonb(NEW) ->> TG_ARGV[0];
        BEGIN
          IF ham IS NOT NULL AND ham IS DISTINCT FROM public.eposta_normalle(ham) THEN
            NEW := jsonb_populate_record(
              NEW, jsonb_build_object(TG_ARGV[0], public.eposta_normalle(ham)));
          END IF;
          RETURN NEW;
        END $$;
        """
    )

    # tesis_uyelik: harf farkli birincil ikizlerde yalniz en eskisi birincil.
    op.execute(birincil_ikiz_sql())

    for sema, tablo, sutun in SUTUNLAR:
        op.execute(kucult_sql(sema, tablo, sutun))
        op.execute(
            f"""
            CREATE TRIGGER {_tetik_adi(tablo)}
            BEFORE INSERT OR UPDATE OF {sutun} ON {sema}.{tablo}
            FOR EACH ROW EXECUTE FUNCTION public.eposta_kucuk_tetik('{sutun}');
            """
        )


def downgrade() -> None:
    # Kucultulen veri GERI BUYUTULMEZ (eski hali bilinmiyor ve gereksiz).
    for sema, tablo, _ in SUTUNLAR:
        op.execute(f"DROP TRIGGER IF EXISTS {_tetik_adi(tablo)} ON {sema}.{tablo};")
    op.execute("DROP FUNCTION IF EXISTS public.eposta_kucuk_tetik();")
    op.execute("DROP FUNCTION IF EXISTS public.eposta_normalle(text);")
