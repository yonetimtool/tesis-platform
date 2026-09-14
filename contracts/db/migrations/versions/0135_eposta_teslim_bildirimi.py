"""(P234 §1) E-POSTA TESLIM GERI BILDIRIMI — bounce panele yansisin.

===========================================================================
OLCULEN KUSUR
===========================================================================
`mesaj_gonderim.durum` bir e-posta gonderildiginde `gonderildi` oluyor ve
ORADA KALIYOR. Saglayici mesaji geri cevirse (bounce), alici spam
isaretlese ya da mail hic teslim edilmese de panelde "gonderildi" yaziyor.

Bu, urunun baska yerlerde ozenle kacindigi seyin ta kendisi: panelde
GONDERILMEMIS bir mesaji gonderilmis gibi gostermek (bkz.
`YapilandirilmamisSaglayici` yorumu). Fark su ki orada denenmedigini
biliyorduk; burada denendi ama SONUCU bilmiyoruz.

Resend webhook gonderiyor. Webhook'un elindeki tek tanitici KENDI mesaj
kimligidir; onu kaydetmezsek geri bildirim gelir ama hangi satira
yazilacagi bilinemez. Bu goc o baglanti noktasini aciyor.

===========================================================================
NEDEN YENI ENUM DEGERI YOK
===========================================================================
`mesaj_durum` zaten `iletildi` ve `okundu` tasiyor — Resend'in
`delivered`/`opened` olaylari tam olarak bunlar. `bounced` ve
`complained` icin UCUNCU bir deger eklemedim:

  * enum'a deger eklemek KOLAY, GERI ALMAK DEGIL (`goc-tersinirlik.sh`
    downgrade sonrasi semayi karsilastiriyor; artik kalan bir enum degeri
    o kapiyi kirar) — `gonderim.py` bas yorumundaki ayni gerekce,
  * ikisi de aynÄ± eyleme cikiyor: BU ADRESE BIR DAHA YAZMA. `basarisiz` +
    ayirt edici `hata` kodu (`bounce_kalici`, `bounce_gecici`,
    `spam_sikayeti`) hem durumu hem sebebi tasiyor.

SIKAYET NEDEN `basarisiz`: mesaj teknik olarak TESLIM EDILDI, yani
"basarili" da denebilirdi. Ama sikayet, bir sonraki gonderimin spam
klasorune dusme olasiligini artiran EN ONEMLI sinyaldir; onu "basarili"
kutusuna koymak, yoneticinin gormesi gereken tek satiri gizlemek olurdu.

===========================================================================
WEBHOOK OLAY DEFTERI — NEDEN AYRI VE NEDEN TENANT'SIZ
===========================================================================
Saglayici ayni olayi birden cok kez gonderebilir (teslim garantisi
"en az bir kez"dir). `payment_webhook_event` ayni sorunu tenant basina
cozuyor; burada tenant webhook GELDIGINDE HENUZ BILINMIYOR — once mesaj
kimliginden cozuluyor. Bu yuzden defter TENANT'SIZ; icinde yalnizca
saglayici olay kimligi var, kisisel veri yok.

TENANT'SIZ AMA RLS'SIZ DEGIL — PLATFORM TABLOSU DESENI.
Ilk yazimda tabloyu RLS'siz birakip `app_rw`ye dogrudan INSERT verdim ve
`test_rls_kapsam` dustu: depoda "RLS'siz tablo" diye bir sinif YOK.
Tenant'siz uc tablo (`tanitim_iletisim`, `yonetici_basvuru`,
`surum_politikasi`) AYNI deseni tasiyor — RLS ACIK + FORCE, POLITIKA YOK,
erisim YALNIZ SECURITY DEFINER fonksiyonundan. Bu, "politikasi
unutulmus" bir tablonun sinifa sessizce katilmasini imkansiz kilar.
Dorduncu uye olarak ayni desene uyduruldu.
"""
from alembic import op
import sqlalchemy as sa

revision = "0135_eposta_teslim_bildirimi"
down_revision = "0134_kategori_guvenlik_ilgili"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

#: Olay defterine YAZAR — tablo RLS FORCE oldugu icin dogrudan INSERT
#: edilemez. Doner: TRUE = ilk kez gorundu, FALSE = tekrar.
#:
#: Fonksiyon HICBIR SEY OKUTMAZ, yalnizca "bu olayi daha once gordum mu"
#: sorusunu yanitlar — imzasi dogrulanmamis bir cagri (ki imzasizsa zaten
#: 401) veri sizdiramaz.
OLAY_EKLE = """
CREATE OR REPLACE FUNCTION public.eposta_webhook_olay_ekle(p_olay text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    INSERT INTO public.eposta_webhook_olay (olay_id) VALUES (p_olay)
    ON CONFLICT (olay_id) DO NOTHING;
    RETURN FOUND;
END;
$$;
"""

#: Mesaj kimliginden TENANT cozer — webhook'ta baglam YOK.
#:
#: `payment_tenant_by_ref` ile ayni desen ve ayni gerekce: RLS acikken
#: baglam kurulmadan hicbir satir gorunmez, ama webhook baglami ancak
#: satiri bularak kurabilir. Fonksiyon TEK BIR SUTUN doner (tenant_id) —
#: mesajin govdesini ya da alicisini DONDURMEZ, yani imzasi dogrulanmamis
#: bir cagri veri sizdiramaz.
COZUCU = """
CREATE OR REPLACE FUNCTION public.gonderim_tenant_by_saglayici_id(p_mid text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
    SELECT tenant_id FROM public.mesaj_gonderim
     WHERE saglayici_mesaj_id = p_mid
     LIMIT 1;
$$;
"""


def upgrade() -> None:
    op.add_column(
        "mesaj_gonderim",
        sa.Column("saglayici_mesaj_id", sa.Text(), nullable=True),
    )
    # KISMI BENZERSIZ INDEKS: kimlik saglayici genelinde benzersizdir ve
    # webhook onunla ARAR — indeks hem aramayi hizlandirir hem ayni
    # kimligin iki satira yazilmasini engeller. `WHERE NOT NULL`: SMTP ile
    # giden satirlarin hepsi NULL kalir ve bunlar cakismamali.
    op.execute(
        "CREATE UNIQUE INDEX ix_mesaj_gonderim_saglayici_mid "
        "ON mesaj_gonderim (saglayici_mesaj_id) "
        "WHERE saglayici_mesaj_id IS NOT NULL"
    )
    op.create_table(
        "eposta_webhook_olay",
        sa.Column("olay_id", sa.Text(), primary_key=True),
        sa.Column(
            "alindi_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    # PLATFORM TABLOSU DESENI: RLS ACIK + FORCE, POLITIKA YOK.
    # `app_rw` tabloyu DOGRUDAN goremez/yazamaz; erisimin tamami
    # `eposta_webhook_olay_ekle` fonksiyonundan gecer.
    op.execute("ALTER TABLE eposta_webhook_olay ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE eposta_webhook_olay FORCE ROW LEVEL SECURITY")
    op.execute(OLAY_EKLE)
    op.execute(
        "REVOKE ALL ON FUNCTION public.eposta_webhook_olay_ekle(text) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.eposta_webhook_olay_ekle(text) "
        f"TO {APP_ROLE};"
    )
    op.execute(COZUCU)
    op.execute(
        "REVOKE ALL ON FUNCTION public.gonderim_tenant_by_saglayici_id(text) "
        "FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.gonderim_tenant_by_saglayici_id(text) "
        f"TO {APP_ROLE};"
    )


def downgrade() -> None:
    op.execute(
        "DROP FUNCTION IF EXISTS public.gonderim_tenant_by_saglayici_id(text);"
    )
    op.execute("DROP FUNCTION IF EXISTS public.eposta_webhook_olay_ekle(text);")
    op.drop_table("eposta_webhook_olay")
    op.execute("DROP INDEX IF EXISTS ix_mesaj_gonderim_saglayici_mid")
    op.drop_column("mesaj_gonderim", "saglayici_mesaj_id")
