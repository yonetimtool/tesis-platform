"""(P177 §4-§6) YENI KAYIT AKISI — yonetici basvurusu, onay kuyrugu, cok-tesis uyeligi.

===========================================================================
UC TABLO, UC AYRI SEBEP
===========================================================================

1) `yonetici_basvuru` — TENANT'SIZ, cunku HENUZ TESIS YOK.
   Yonetici tanitim sitesinden kaydoluyor; tesis ancak e-posta
   dogrulandiktan SONRA, "site adi" adiminda aciliyor. Arada bir kayit
   tutulmali: adi, e-postasi, parola ozeti ve ONAYLARI.

   `app_user` KULLANILAMAZ: o tablo `tenant_id NOT NULL` tasir ve
   dogrulanmamis bir basvuru icin bos bir tesis acmak, terk edilen her
   basvuru icin sahipsiz bir tesis birakirdi.

2) `kayit_onay_kuyrugu` — TENANT KAPSAMLI.
   §6'nin dogrulama kurali uc sarti BIRLIKTE ariyor (gecerli Tesis ID +
   e-postanin yonetici listesinde olmasi + o adrese giden kodun
   dogrulanmasi). Sartlardan biri tutmazsa hesap ACILMAZ ama deneme
   KAYBOLMAMALI: yoneticinin panelinde bir onay kuyrugunda gorunur.

3) `tesis_uyelik` — BUGUN KULLANILMIYOR, YARIN GOC GEREKTIRIR.
   §6'nin son maddesi: "Bir kisi birden cok tesise baglanabilecek
   sekilde modelle. Bugun kullanilmayacak ama sonradan eklemek sema
   gocu gerektirir." Tam olarak bu yuzden BUGUN aciliyor.

===========================================================================
ONAYLAR NEDEN AYRI BIR TABLOYA KONMADI
===========================================================================
Dorduncu bir `kullanici_onayi` tablosu dusunuldu ve YAZILMADI. Onaylar
`yonetici_basvuru` satirinda duruyor cunku ISPAT KAYDI ZATEN O SATIRDIR:
hangi metin, ne zaman, hangi IP'den onaylandi. Ayri bir tabloya
kopyalamak, ayni gercegi iki yere yazip birinin gunun birinde otekiyle
uyusmamasi demekti.

Basvuru satiri tesis acildiktan SONRA DA SILINMEZ — `durum='tamamlandi'`
olur ve KVKK m.5/2-f (ispat) icin durur. Yalniz `parola_hash` NULL'lanir:
o andan itibaren parola `app_user`dadir ve ikinci bir kopyasini tutmanin
hicbir gerekcesi yoktur.

===========================================================================
TICARI ILETI: RIZA SAKLANIR, GONDERIM KAPALI
===========================================================================
`onay_ticari` kolonu var ve doldurulur; `settings.ticari_ileti_aktif`
varsayilan `False`. Sirket ve IYS kaydi olmadan ticari ileti gondermek
idari para cezasi sebebidir. Riza toplamak yasal, gondermek degil.

===========================================================================
RLS
===========================================================================
`yonetici_basvuru` TENANT'SIZ oldugu icin tenant politikasi YAZILAMAZ.
`tanitim_iletisim` (goc 0033) ile AYNI desen: RLS acik, POLITIKA YOK,
erisim yalniz SECURITY DEFINER fonksiyonlarindan. Boylece kimliksiz
kayit ucu, tablonun tamamini okuyabilecek bir yetki TASIMAZ — kaydolan
biri baska basvuranlarin adini/e-postasini goremez.

Oteki iki tablo tenant kapsamlidir ve standart tenant politikasini alir.

Revision ID: 0068_yeni_kayit_akisi
Revises: 0067_eposta_dogrulama_kodu
"""
from __future__ import annotations

from alembic import op

revision = "0068_yeni_kayit_akisi"
down_revision = "0067_eposta_dogrulama_kodu"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"
TENANT_AYARI = "app.current_tenant_id"

_EKLE_FN = (
    "public.yonetici_basvuru_ekle(text, text, text, text, text, "
    "boolean, boolean, boolean, text, text, integer, text, integer)"
)
_BUL_FN = "public.yonetici_basvuru_bul(text)"
_DOGRULA_FN = "public.yonetici_basvuru_dogrula(uuid)"
_TAMAMLA_FN = "public.yonetici_basvuru_tamamla(uuid)"
_DENEME_FN = "public.yonetici_basvuru_deneme_artir(uuid)"
_GETIR_FN = "public.yonetici_basvuru_getir(uuid)"


def upgrade() -> None:
    # ==================================================================== #
    # 1) yonetici_basvuru — TENANT'SIZ
    # ==================================================================== #
    op.execute(
        """
        CREATE TABLE yonetici_basvuru (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ad            text NOT NULL,
            soyad         text NOT NULL,
            -- KUCUK HARFE NORMALLESTIRILMIS olarak yazilir (uygulama
            -- katmani). Benzersizlik indeksi de bunun uzerinde.
            eposta        text NOT NULL,
            telefon       text NOT NULL,
            -- Tesis acildiktan sonra NULL'lanir (bkz. modul basligi).
            parola_hash   text,

            -- --- E-POSTA DOGRULAMA KODU ---
            -- NEDEN `kayit_dogrulama` KULLANILMIYOR: o tablo
            -- `tenant_id NOT NULL` tasir ve RLS politikasi tenant
            -- uzerinedir. Yonetici basvurusunda HENUZ TESIS YOKTUR;
            -- kolonu NULL'a acmak, o tablodaki her satirin RLS altinda
            -- gorunurlugunu bulandirirdi (tenant'siz satiri hangi
            -- politika gosterecek?).
            --
            -- MEKANIZMA YINE DE IKIYE BOLUNMUYOR: sure (`KOD_OMRU_DK`),
            -- deneme siniri (`MAX_DENEME`) ve kodun bcrypt'lenmesi
            -- `app/telefon_kodu.py`de TEK YERDE duruyor; buradaki
            -- kolonlar yalniz DEPOLAMADIR, kural degil.
            kod_hash      text,
            kod_son_gecerlilik timestamptz,
            kod_deneme    integer NOT NULL DEFAULT 0,

            -- --- ONAYLAR (§4) ---
            -- Uc kutu da AYRI kolon: "hepsini kabul ettim" diye tek bir
            -- bayrak, hangi metnin onaylandigini ispat edemezdi ve
            -- ucuncusu ISTEGE BAGLI oldugu icin digerleriyle ayni anlami
            -- tasimiyor.
            onay_sozlesme boolean NOT NULL,
            onay_kvkk     boolean NOT NULL,
            onay_ticari   boolean NOT NULL DEFAULT false,
            -- Onay ANI ve KAYNAGI — KVKK'da ispat yukumlulugu veri
            -- sorumlusundadir. `onay_at` ayri bir kolon (created_at
            -- degil): satir sonradan guncellenebilir, onay ani sabittir.
            onay_at       timestamptz NOT NULL DEFAULT now(),
            onay_ip       text,
            onay_ajan     text,

            -- beklemede | dogrulandi | tamamlandi
            durum         text NOT NULL DEFAULT 'beklemede',
            -- Dogrulanmamis basvurunun son kullanma ani.
            son_gecerlilik timestamptz NOT NULL,
            -- TENANT_ID / USER_ID KOLONLARI BILEREK YOK.
            --
            -- Ilk yazimda "hangi basvuru hangi tesis oldu" izlemesi icin
            -- vardilar ve OLCULEN BIR SORUNA yol actilar:
            -- `test_rls_kapsam::test_her_tablonun_politikasi_var` bir
            -- tabloyu YAPISAL olarak siniflandiriyor — `tenant_id`
            -- kolonu VARSA tenant kapsamlidir ve politikasi OLMALIDIR.
            -- Bu tablo tenant'siz (basvuru anininda tesis YOK), yani
            -- kolon tabloyu "kapsamli gorunup politikasiz" hâle
            -- getiriyordu: tam olarak o testin aradigi tehlike.
            --
            -- Bilgi de KAYBOLMUYOR: tamamlanan basvurunun e-postasi
            -- `app_user.email`de ve `tesis_uyelik.eposta`da duruyor;
            -- destek sorusu ("bu basvuru hangi tesis oldu") e-posta
            -- uzerinden yanitlanir. Iki kolon icin bir izolasyon
            -- kuralini bulandirmak dogru olmazdi.
            created_at    timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_yonetici_basvuru_durum
                CHECK (durum IN ('beklemede', 'dogrulandi', 'tamamlandi')),
            -- ZORUNLU IKI ONAY VERITABANINDA DA ZORLANIR. Arayuz ve API
            -- zaten kontrol ediyor; buradaki kisit, ileride yazilacak bir
            -- ucun onayi atlamasini YAPISAL olarak engeller.
            CONSTRAINT ck_yonetici_basvuru_zorunlu_onay
                CHECK (onay_sozlesme AND onay_kvkk)
        );
        """
    )
    # AYNI E-POSTAYLA TEK ACIK BASVURU. Kismi indeks: tamamlanmis
    # basvurular ispat kaydi olarak durur ve ayni kisi yillar sonra ikinci
    # bir tesis acabilir — onlari kisitlamak yanlis olurdu.
    op.execute(
        "CREATE UNIQUE INDEX uq_yonetici_basvuru_acik "
        "ON yonetici_basvuru (eposta) WHERE durum <> 'tamamlandi'"
    )
    op.execute("ALTER TABLE yonetici_basvuru ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE yonetici_basvuru FORCE ROW LEVEL SECURITY")

    # --- YAZMA: kimliksiz uc buradan gecer -----------------------------
    # UPSERT: ayni adresle ikinci kez basvuran kullanici (ilk kodu
    # kaybetti, sekmeyi kapatti) DUVARA CARPMAMALI. Acik basvuru
    # TAZELENIR — yeni parola, yeni onay damgasi, yeni sure. Bu, kodun
    # ezilme kuralinin (`telefon_kodu`) ayni mantigi: art arda uretilen
    # kayitlarin hepsinin gecerli kalmasi saldirgana coklu hedef verirdi.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.yonetici_basvuru_ekle(
            p_ad text, p_soyad text, p_eposta text, p_telefon text,
            p_parola_hash text,
            p_onay_sozlesme boolean, p_onay_kvkk boolean, p_onay_ticari boolean,
            p_ip text, p_ajan text, p_omur_saat integer,
            p_kod_hash text, p_kod_omru_dk integer
        )
        RETURNS uuid
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            INSERT INTO public.yonetici_basvuru (
                ad, soyad, eposta, telefon, parola_hash,
                onay_sozlesme, onay_kvkk, onay_ticari,
                onay_ip, onay_ajan, son_gecerlilik,
                kod_hash, kod_son_gecerlilik, kod_deneme
            )
            VALUES (
                p_ad, p_soyad, lower(p_eposta), p_telefon, p_parola_hash,
                p_onay_sozlesme, p_onay_kvkk, p_onay_ticari,
                p_ip, p_ajan, now() + make_interval(hours => p_omur_saat),
                p_kod_hash, now() + make_interval(mins => p_kod_omru_dk), 0
            )
            ON CONFLICT (eposta) WHERE durum <> 'tamamlandi'
            DO UPDATE SET
                ad = EXCLUDED.ad,
                soyad = EXCLUDED.soyad,
                telefon = EXCLUDED.telefon,
                parola_hash = EXCLUDED.parola_hash,
                onay_sozlesme = EXCLUDED.onay_sozlesme,
                onay_kvkk = EXCLUDED.onay_kvkk,
                onay_ticari = EXCLUDED.onay_ticari,
                onay_at = now(),
                onay_ip = EXCLUDED.onay_ip,
                onay_ajan = EXCLUDED.onay_ajan,
                durum = 'beklemede',
                son_gecerlilik = EXCLUDED.son_gecerlilik,
                -- KOD TAZELENIR ve SAYAC SIFIRLANIR. Ezme bilincli:
                -- art arda istenen kodlarin HEPSININ gecerli kalmasi,
                -- saldirgana ayni anda bes gecerli hedef verirdi
                -- (`telefon_kodu.kod_uret_ve_gonder` ile ayni kural).
                kod_hash = EXCLUDED.kod_hash,
                kod_son_gecerlilik = EXCLUDED.kod_son_gecerlilik,
                kod_deneme = 0
            RETURNING id;
        $$;
        """
    )

    # --- OKUMA: yalniz TEK bir basvuru, e-postasiyla --------------------
    # Liste dondurmez ve dondurmemeli: kimliksiz bir ucun cagirdigi
    # fonksiyon, tablonun tamamini gorebilen bir yetki tasimamali.
    # `parola_hash` DONMEZ: cagiran onu hicbir yerde kullanmiyor.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.yonetici_basvuru_bul(p_eposta text)
        RETURNS TABLE(
            id uuid, ad text, soyad text, eposta text, telefon text,
            onay_ticari boolean, durum text, son_gecerlilik timestamptz,
            kod_hash text, kod_son_gecerlilik timestamptz, kod_deneme integer
        )
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT id, ad, soyad, eposta, telefon,
                   onay_ticari, durum, son_gecerlilik,
                   kod_hash, kod_son_gecerlilik, kod_deneme
            FROM public.yonetici_basvuru
            WHERE eposta = lower(p_eposta) AND durum <> 'tamamlandi';
        $$;
        """
    )
    # --- DENEME SAYACI: kaba kuvvet kapisi ------------------------------
    # AYRI FONKSIYON cunku cagiran onu AYRI BIR OTURUMDA calistirir:
    # dogrulama istegi hata ile bitecek ve cagiranin transaction'i geri
    # sarilacak — ayni oturumda artirmak sayaci SIFIRLARDI. Bu kusur
    # P148'de olculdu ve koruma HIC CALISMIYORDU.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.yonetici_basvuru_deneme_artir(p_id uuid)
        RETURNS integer
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            UPDATE public.yonetici_basvuru
            SET kod_deneme = kod_deneme + 1
            WHERE id = p_id
            RETURNING kod_deneme;
        $$;
        """
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.yonetici_basvuru_dogrula(p_id uuid)
        RETURNS TABLE(id uuid, ad text, soyad text, eposta text,
                      telefon text, parola_hash text, onay_ticari boolean)
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            UPDATE public.yonetici_basvuru
            -- KOD TUKETILIR: ayni kod ikinci kez gecmez.
            SET durum = 'dogrulandi', kod_hash = NULL
            WHERE id = p_id AND durum = 'beklemede'
              AND son_gecerlilik > now()
            RETURNING id, ad, soyad, eposta, telefon, parola_hash, onay_ticari;
        $$;
        """
    )
    # --- KIMLIKLE OKUMA: tesis acma adiminda gerekli --------------------
    # NEDEN FONKSIYON, NEDEN DUZ SELECT DEGIL: tablo RLS altinda ve
    # POLITIKASI YOK; app_rw ondan DOGRUDAN HICBIR SATIR OKUYAMAZ. Duz
    # bir `SELECT ... WHERE id = ...` sessizce SIFIR SATIR doner ve
    # "jeton gecersiz" gibi gorunur — tam olarak bu olculdu.
    #
    # `parola_hash` DONER cunku tesis acilirken `app_user`a yazilacak
    # olan odur; fonksiyon YALNIZ KIMLIKLE cagrilir (tarama yapilamaz)
    # ve calistirma yetkisi app_rw ile sinirlidir.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.yonetici_basvuru_getir(p_id uuid)
        RETURNS TABLE(
            id uuid, ad text, soyad text, eposta text, telefon text,
            parola_hash text, onay_ticari boolean, durum text
        )
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT id, ad, soyad, eposta, telefon,
                   parola_hash, onay_ticari, durum
            FROM public.yonetici_basvuru
            WHERE id = p_id;
        $$;
        """
    )
    # --- TAMAMLAMA: tesis acildi ----------------------------------------
    # `parola_hash` NULL'lanir (bkz. modul basligi). Yalniz `dogrulandi`
    # durumundan gecer: dogrulanmamis bir basvuruyla tesis acilamaz.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.yonetici_basvuru_tamamla(p_id uuid)
        RETURNS uuid
        LANGUAGE sql
        VOLATILE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            UPDATE public.yonetici_basvuru
            SET durum = 'tamamlandi',
                parola_hash = NULL
            WHERE id = p_id AND durum = 'dogrulandi'
            RETURNING id;
        $$;
        """
    )
    for fn in (_EKLE_FN, _BUL_FN, _DOGRULA_FN, _TAMAMLA_FN, _DENEME_FN, _GETIR_FN):
        op.execute(f"REVOKE ALL ON FUNCTION {fn} FROM PUBLIC;")
        op.execute(f"GRANT EXECUTE ON FUNCTION {fn} TO {APP_ROLE};")

    # ==================================================================== #
    # 2) kayit_onay_kuyrugu — TENANT KAPSAMLI
    # ==================================================================== #
    op.execute(
        """
        CREATE TABLE kayit_onay_kuyrugu (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            eposta     text NOT NULL,
            -- Kisinin BEYAN ETTIGI rol. Dogrulanmis degil — zaten bu
            -- yuzden kuyrukta.
            rol        text NOT NULL,
            ad         text,
            telefon    text,
            -- Neden kuyruga dustu: 'liste_disi' | 'rol_uyusmuyor' |
            -- 'hesap_kullanimda'. Yonetici karari bunu gorerek verir;
            -- "bir sey oldu" demek, yoneticiyi tahmine birakirdi.
            sebep      text NOT NULL,
            -- bekliyor | onaylandi | reddedildi
            durum      text NOT NULL DEFAULT 'bekliyor',
            karar_at   timestamptz,
            karar_veren_id uuid,
            created_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_kayit_onay_durum
                CHECK (durum IN ('bekliyor', 'onaylandi', 'reddedildi'))
        );
        """
    )
    # AYNI ADRESTEN TEK ACIK KAYIT: ayni kisi bes kez denerse yoneticinin
    # kuyrugunda bes satir olusmamali. Tekrar deneme mevcut satiri tazeler.
    op.execute(
        "CREATE UNIQUE INDEX uq_kayit_onay_acik ON kayit_onay_kuyrugu "
        "(tenant_id, eposta) WHERE durum = 'bekliyor'"
    )
    op.execute(
        "CREATE INDEX ix_kayit_onay_tenant ON kayit_onay_kuyrugu "
        "(tenant_id, created_at DESC)"
    )
    op.execute("ALTER TABLE kayit_onay_kuyrugu ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE kayit_onay_kuyrugu FORCE ROW LEVEL SECURITY")
    op.execute(
        """
        CREATE POLICY kayit_onay_kuyrugu_tenant ON public.kayit_onay_kuyrugu
          USING (tenant_id = current_setting('{AYAR}', true)::uuid)
          WITH CHECK (tenant_id = current_setting('{AYAR}', true)::uuid)
        """.replace("{AYAR}", TENANT_AYARI)
    )
    op.execute(
        "GRANT SELECT, INSERT, UPDATE, DELETE ON public.kayit_onay_kuyrugu "
        f"TO {APP_ROLE}"
    )
    # --- KUYRUGA YAZMA: KIMLIKSIZ YOLDAN --------------------------------
    # Kaydolmaya calisan kisinin oturumu YOKTUR ve `set_tenant` cagrisi
    # yapabilmesi icin once tesisi cozmesi gerekir — bunu zaten
    # `tenant_id_by_kayit_kodu` yapiyor. Yani politikayi kurabiliyoruz ve
    # SECURITY DEFINER bir fonksiyona GEREK YOK. Tablo tenant kapsamli
    # oldugu icin duz INSERT, RLS altinda, dogru tenant'a yazar.

    # ==================================================================== #
    # 3) tesis_uyelik — COK TESISLI UYELIK (bugun kullanilmiyor)
    # ==================================================================== #
    op.execute(
        """
        CREATE TABLE tesis_uyelik (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            user_id    uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
            -- KIMLIK ANAHTARI: ayni kisiyi FARKLI tesislerdeki farkli
            -- `app_user` satirlariyla eslestiren sey budur. `user_id`
            -- tenant'a bagli, e-posta ise KISIYE.
            eposta     text NOT NULL,
            rol        text NOT NULL,
            -- Kisinin ASIL (varsayilan) tesisi. Bugun herkesin tek
            -- uyeligi var ve o birincildir; cok tesisli acildiginda
            -- uygulama acilista buraya bakacak.
            birincil   boolean NOT NULL DEFAULT true,
            created_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_tesis_uyelik UNIQUE (tenant_id, user_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_tesis_uyelik_eposta ON tesis_uyelik (lower(eposta))"
    )
    # `user_id` FK'sinin ONCU kolon indeksi.
    #
    # `uq_tesis_uyelik (tenant_id, user_id)` bunu KARSILAMAZ: `user_id`
    # o indekste IKINCI kolondur. Bir `app_user` satiri silindiginde RI
    # tetigi `tesis_uyelik`i `user_id` uzerinden arar ve oncu kolon
    # indeksi yoksa SEQ SCAN eder — `test_indeks_kapsam` bunu olcuyor ve
    # ilk yazimda DUSTU.
    op.execute("CREATE INDEX ix_tesis_uyelik_user ON tesis_uyelik (user_id)")
    op.execute("ALTER TABLE tesis_uyelik ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE tesis_uyelik FORCE ROW LEVEL SECURITY")
    op.execute(
        """
        CREATE POLICY tesis_uyelik_tenant ON public.tesis_uyelik
          USING (tenant_id = current_setting('{AYAR}', true)::uuid)
          WITH CHECK (tenant_id = current_setting('{AYAR}', true)::uuid)
        """.replace("{AYAR}", TENANT_AYARI)
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON public.tesis_uyelik TO {APP_ROLE}"
    )
    # --- GERIYE DOLDURMA ------------------------------------------------
    # Mevcut her (e-postali) kullanici icin bir uyelik satiri. E-POSTASI
    # OLMAYANLAR ATLANIR: `app_user.email` sakinlerde NULL olabilir ve
    # kimlik anahtari e-postadir — bos bir anahtarla satir yazmak, ileride
    # "ayni kisi" eslesmesini bozardi.
    #
    # Bu bir VERI GOCU ve tabloyu acan gocla AYNI dosyada olmasi dogru:
    # ikisini ayirmak, tablosu olan ama bos duran bir ara durum birakirdi.
    op.execute(
        """
        INSERT INTO tesis_uyelik (tenant_id, user_id, eposta, rol, birincil)
        SELECT tenant_id, id, lower(email), role, true
        FROM app_user
        WHERE email IS NOT NULL AND email <> ''
        ON CONFLICT DO NOTHING;
        """
    )


def downgrade() -> None:
    op.execute("DROP POLICY IF EXISTS tesis_uyelik_tenant ON public.tesis_uyelik")
    op.execute("DROP TABLE IF EXISTS public.tesis_uyelik")
    op.execute(
        "DROP POLICY IF EXISTS kayit_onay_kuyrugu_tenant "
        "ON public.kayit_onay_kuyrugu"
    )
    op.execute("DROP TABLE IF EXISTS public.kayit_onay_kuyrugu")
    for fn in (_EKLE_FN, _BUL_FN, _DOGRULA_FN, _TAMAMLA_FN, _DENEME_FN, _GETIR_FN):
        op.execute(f"DROP FUNCTION IF EXISTS {fn};")
    op.execute("DROP TABLE IF EXISTS public.yonetici_basvuru")
