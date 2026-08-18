"""(P168 §4) MESAJ YAPILANDIRMASI — tesis basina saglayici + "yapilandirilmadi".

===========================================================================
1. YENI DURUM: `yapilandirilmadi`
===========================================================================
Brief: "SMS saglayicisi henuz yapilandirilmadi: saglayici yoksa gonderim
'yapilandirilmadi' durumuyla kaydedilsin, SESSIZCE 'gonderildi' DEMESIN."

Bugunku davranis TAM OLARAK bu kusurdu ve kodda yaziliydi:
`LogSmsSaglayici.gonder()` hicbir sey gondermeden `"gonderildi"` donuyordu.
Sonuc: yonetici "Gonderim" listesinde yesil bir "Gonderildi" satiri
goruyor, sakin ise hicbir sey almiyor. Bir SMS'in gidip gitmedigi
hukuki bir sorudur (bildirim kaniti); yanlis "gonderildi" kaydi, olmayan
bir bildirimi ISPAT gibi gosterirdi.

`basarisiz` DE DOGRU DEGIL: basarisizlik "denedik, olmadi" demektir ve
kullaniciyi "tekrar dene" ye iter. Burada HIC DENENMEDI ve tekrar denemek
de ayni sonucu verir; yapilmasi gereken sey AYARLARI DOLDURMAKTIR. Ayri
bir durum, arayuzun dogru eylemi onerebilmesini saglar.

===========================================================================
2. `mesaj_yapilandirma` — TESIS BASINA, ENV DEGIL
===========================================================================
Saglayici bilgisi bugun ENV'de (`SMS_SAGLAYICI`, `SMTP_HOST`...) yani
BUTUN TESISLER ICIN TEK. Coklu tesis bir platformda bu yanlis: her tesis
kendi SMS bayiligini ve kendi e-posta sunucusunu kullanir, faturasi da
kendine cikar. Brief de "Ayarlar" sekmesinde tesis yoneticisinin bunlari
girmesini istiyor.

ENV YEDEK OLARAK KALIR: tesis kaydi yoksa mevcut ENV yapilandirmasi
kullanilir. Boylece bugun calisan kurulumlar bozulmaz ve gecis
kademeli olur.

SIRLAR: `sms_parola` ve `smtp_parola` burada ACIK metin tutulur —
uygulamanin onlari saglayiciya AYNEN gondermesi gerekir, yani geri
donusu olmayan bir ozet (hash) ise yaramaz. Koruma katmani veritabani
erisimidir (RLS + `app_rw`), ve ARAYUZ bunlari MASKELI gosterir
(`sms_parola_var` gibi bayraklar doner, degerin kendisi DONMEZ).
"""
from alembic import op

revision = "0063_mesaj_yapilandirma"
down_revision = "0062_icra_durum_yeniden"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"
TENANT_AYARI = "app.current_tenant_id"


def upgrade() -> None:
    op.execute("ALTER TYPE mesaj_durum ADD VALUE IF NOT EXISTS 'yapilandirilmadi'")
    op.execute(
        """
        CREATE TABLE mesaj_yapilandirma (
            tenant_id      uuid PRIMARY KEY
                           REFERENCES tenant(id) ON DELETE CASCADE,
            sms_saglayici  text,
            sms_kullanici  text,
            sms_parola     text,
            sms_baslik     text,
            smtp_host      text,
            smtp_port      integer NOT NULL DEFAULT 587,
            smtp_kullanici text,
            smtp_parola    text,
            smtp_gonderen  text,
            -- GUNLUK KOTA: bir yazim hatasi ya da yanlis segment secimi
            -- yuzunden binlerce SMS gitmesini ve faturanin patlamasini
            -- engelleyen tek durak. 0 = sinirsiz DEGIL, KAPALI demek
            -- olurdu; bu yuzden NULL "sinir yok" anlamini tasir.
            gunluk_kota    integer,
            updated_at     timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_mesaj_yap_kota CHECK (gunluk_kota IS NULL OR gunluk_kota > 0),
            CONSTRAINT ck_mesaj_yap_port CHECK (smtp_port BETWEEN 1 AND 65535)
        )
        """
    )
    op.execute("ALTER TABLE public.mesaj_yapilandirma ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE public.mesaj_yapilandirma FORCE ROW LEVEL SECURITY")
    op.execute(
        """
        CREATE POLICY mesaj_yapilandirma_tenant ON public.mesaj_yapilandirma
          USING (tenant_id = current_setting('{AYAR}', true)::uuid)
          WITH CHECK (tenant_id = current_setting('{AYAR}', true)::uuid)
        """.replace("{AYAR}", TENANT_AYARI)
    )
    op.execute(
        "GRANT SELECT, INSERT, UPDATE, DELETE ON public.mesaj_yapilandirma "
        f"TO {APP_ROLE}"
    )


def downgrade() -> None:
    op.execute(
        "DROP POLICY IF EXISTS mesaj_yapilandirma_tenant ON public.mesaj_yapilandirma"
    )
    op.execute("DROP TABLE IF EXISTS public.mesaj_yapilandirma")
    # ENUM DEGERI GERI ALINMAZ: Postgres enum'dan deger silemez ve tipi
    # yeniden kurmak, o degeri kullanan gecmis satirlari kaybetmek
    # olurdu. Fazladan bir deger zararsizdir.
