"""(P154) Tesis kodu saglamlastirma + tesis basina COKLU YONETICI yonetimi.

Iki isi tek gocte tasiyor cunku ikisi de AYNI kapiyi (admin panelinden tesis
kurulumu) tamamliyor ve ikisi de yalniz SECURITY DEFINER fonksiyonlara
dokunuyor; tablo semasi DEGISMIYOR.

===========================================================================
1) `kayit_kodu_uret` — YEREL BAGIMSIZ hale getirildi
===========================================================================

Kilitli kural 3: kod = adin ilk 4 harfi + '-' + YYAAGG.

P148.1'deki govde `upper(translate(...))` sirasiyla calisiyordu ve `upper()`
VERITABANI CTYPE'INA BAGLIDIR. `en_US.utf8`ta `upper('i') = 'I'` doner ve
her sey yolundadir — bugunku kurulumda oyle. Ama TURKCE ctype'li bir
veritabaninda (`tr_TR.utf8`) `upper('i')` **`İ` (U+0130)** doner; hemen
ardindaki `regexp_replace('[^A-Z]', '')` suzgeci onu ATAR ve
"istanbul konaklari" -> `ISTA` yerine `STAN` olurdu.

BU BUGUN PATLAMIYOR, YARIN PATLARDI: Asama A yeni bir sunucu kuruyor.
`initdb` yerel ayarini isletim sisteminden alir; Turkce yapilandirilmis bir
makinede ayni ad BASKA bir tesis kodu uretir ve iki ortam sessizce
ayrisirdi. Kod telefonda elle yazilan bir tanimlayici oldugu icin bu
"biraz farkli" degil, "yanlis" olurdu.

COZUM: `upper`DAN SONRA ikinci bir `translate`. Ne cikarsa ciksin
(`İ`/`ı`/`Ş`...) ASCII'ye indirilir. Yerel ne olursa olsun ayni girdi ayni
kodu verir.

OLCULDU (calisan veritabaninda, yan yana): 17 kenar durumu (Turkce
buyuk/kucuk, 4 harften kisa, rakamla baslayan, harfsiz, bosluklu,
noktalamali) eski ve yeni govdede AYNI ciktiyi verdi; mevcut tesislerin
tamaminda fark sayisi **0**. Yani bu goc bu kurulumda DAVRANISSIZDIR ve
yalniz gelecekteki bir yerel farkina karsi kilittir.

`SET search_path = ''` ACIKCA yaziliyor: 0040 bu ayari `ALTER FUNCTION` ile
koymustu ve `CREATE OR REPLACE` govdeyi degistirirken belirtilmeyen
ozellikleri varsayilana dondurur. Yazmasaydik 0040'in kapattigi hatayi
(prod'da `create_tenant_with_yoneticis` -> 500) yeniden acardik.

===========================================================================
2) `tenant_kayit_kodu_ata` — cakisma eki SIRALI degil RASTGELE
===========================================================================

Kilitli kural 3: "Cakismada ikinci kayda RASTGELE SAYI eklenir."

P148.1 sirali sayac koymustu (`-2`, `-3`). Brief bunu acikca degistiriyor
ve KILITLI KURALLAR basligi altinda duruyor; yeni ve acik kural kazanir.

TAKAS DURUSTCE: sirali ek daha akilda kalicidir ve kodun tum amaci akilda
kalmaktir. Rastgele ek bunu bir parca zayiflatir. Bunun karsiliginda
"ikinci Oltu"nun kacinci oldugunu sizdirmaz. Zarari kucuk tutmak icin ek
IKI HANELIDIR (10-99): `OLTU-260715-47`. Dort haneli bir sayi kodu telefonda
okunamaz hale getirirdi.

SONLANMA GARANTISI: 90 aday tukenirse (ayni ad + ayni gun 90 kez) dongu
sonsuza girerdi. 20 denemeden sonra md5 tabanli 6 karakterlik bir eke
dusulur. Sonsuz dongu, INSERT'i asan ve tesis olusturmayi kilitleyen bir
hata olurdu — "olmaz" demek yerine yazili bir cikis kondu.

MEVCUT KODLAR DEGISMEZ: tetikleyici YALNIZ `BEFORE INSERT` ve yalniz
`kayit_kodu IS NULL` iken calisir. 0037'nin dolgu UPDATE'i TEKRAR
KOSTURULMUYOR. Kilitli kural 1 (mevcut kullanicilar erisim kaybetmez)
korunur.

===========================================================================
3) COKLU YONETICI — ekleme ve silme (brief Asama 1 "EKSIK")
===========================================================================

BUGUNKU DURUM OLCULDU: `create_tenant_with_yoneticis` N yonetici aciyor
(ilki BIRINCIL). Ama `tenant_detail` LATERAL ile YALNIZ birincili donuyor
ve panelde tek yonetici gorunuyor; olusturulduktan SONRA yonetici ekleme
ya da silme HICBIR ucta yok. Yani "birden fazla yonetici olabilir" kurali
yazma anindaki tek atisla sinirliydi.

Uc yeni SECURITY DEFINER fonksiyon (hepsi owner-sahipli, `search_path=''`,
`REVOKE ... FROM PUBLIC` + `GRANT ... TO app_rw`; API yalniz `admin`e acar):

* `tenant_yoneticiler(uuid)`  — tesisin TUM yoneticileri (birincil once)
* `add_tenant_yonetici(...)`  — yeni yonetici (birincil DEGIL)
* `remove_tenant_yonetici(..)` — yoneticiyi tesisten cikarir

SILME — NEDEN SERT SILME, NEDEN KORUMALI:
Yumusak silme (`is_active=false`) zaten `update_tenant_yonetici` ile
mumkun; "sil" dugmesi ondan farkli bir sey yapmali, yoksa iki dugme ayni
isi yapip kullaniciyi yanilirdi. Ama korumasiz `DELETE` iki felaket uretir:

  (a) SON yoneticiyi silmek tesisi YONETILEMEZ birakir. -> `son_yonetici`
  (b) BIRINCIL yoneticiyi silmek `tenant_detail`i bos dondurur; panel
      "tesiste yonetici yok" der, oysa yoneticiler vardir. Ayrica
      `uq_app_user_birincil` yeni birincil atanmasini kendiliginden
      yapmaz. -> `birincil` (once baskasi birincil yapilmali)

Fonksiyon metin doner (`silindi` | `son_yonetici` | `birincil`) ya da
satir yoksa NULL. Istisna yerine metin secildi: cagiran uc, ucunu de
FARKLI hata koduna cevirebilsin ve kullaniciya NE yapacagini
soyleyebilsin. Yabanci anahtar kisitina takilma (`ON DELETE RESTRICT`
tasiyan kayitlari olan yonetici) istisna olarak KALIR ve uc onu 409'a
cevirir — orada kullaniciya soylenecek sey zaten farklidir ("kayitlari
var, pasiflestirin").
"""
from alembic import op

revision = "0041_kod_ve_coklu_yonetici"
down_revision = "0040_tetikleyici_search_path"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    # ----------------------------------------------------------------- #
    # 1) Yerel bagimsiz kod uretici.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kayit_kodu_uret(p_ad text, p_tarih date)
        RETURNS text
        LANGUAGE sql
        IMMUTABLE
        SET search_path = ''
        AS $$
            SELECT rpad(
                       left(
                           regexp_replace(
                               -- IKINCI translate `upper`DAN SONRA: Turkce
                               -- ctype'ta upper('i') = 'İ' doner ve asagidaki
                               -- [^A-Z] suzgeci onu atardi.
                               translate(
                                   upper(translate(p_ad,
                                       'çÇğĞıİöÖşŞüÜ', 'cCgGiIoOsSuU')),
                                   'İıŞşĞğÇçÖöÜü', 'IISSGGCCOOUU'),
                               '[^A-Z]', '', 'g'),
                           4),
                       4, 'X')
                   || '-' || to_char(p_tarih, 'YYMMDD');
        $$;
        """
    )

    # ----------------------------------------------------------------- #
    # 2) Cakismada RASTGELE ek (kilitli kural 3).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_kayit_kodu_ata()
        RETURNS trigger
        LANGUAGE plpgsql
        SET search_path = ''
        AS $$
        DECLARE
            taban  text;
            aday   text;
            deneme int := 0;
        BEGIN
            IF NEW.kayit_kodu IS NOT NULL THEN
                RETURN NEW;
            END IF;
            taban := public.kayit_kodu_uret(
                NEW.ad, COALESCE(NEW.created_at, now())::date);
            aday := taban;
            WHILE EXISTS (
                SELECT 1 FROM public.tenant WHERE kayit_kodu = aday
            ) LOOP
                deneme := deneme + 1;
                IF deneme > 20 THEN
                    -- SONLANMA GARANTISI: 90 iki haneli aday tukendiyse.
                    aday := taban || '-' || substr(
                        md5(random()::text || clock_timestamp()::text), 1, 6);
                ELSE
                    aday := taban || '-'
                            || (10 + floor(random() * 90))::int::text;
                END IF;
            END LOOP;
            NEW.kayit_kodu := aday;
            RETURN NEW;
        END;
        $$;
        """
    )

    # ----------------------------------------------------------------- #
    # 3a) Tesisin TUM yoneticileri. BIRINCIL ONCE: panel ilk satiri
    #     "tesisin sahibi" gibi gosterir; created_at sirasi birincili
    #     ortada birakabilirdi.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_yoneticiler(p_tenant_id uuid)
        RETURNS TABLE(
            yonetici_id uuid, yonetici_ad text, telefon text,
            is_active boolean, password_set boolean, birincil boolean,
            created_at timestamptz)
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT u.id, u.ad, u.telefon, u.is_active, u.password_set,
                   u.birincil, u.created_at
            FROM public.app_user u
            WHERE u.tenant_id = p_tenant_id
              AND u.role = 'yonetici'::public.user_role
            ORDER BY u.birincil DESC, u.created_at, u.id;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.tenant_yoneticiler(uuid) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.tenant_yoneticiler(uuid) "
        f"TO {APP_ROLE};"
    )

    # 3b) Yonetici EKLE. Yeni yonetici ASLA birincil degildir: birincil
    #     `uq_app_user_birincil` ile tenant basina tektir ve sahipligi
    #     sessizce devretmek, panelde kimin sorumlu oldugunu degistirirdi.
    #     `aranabilir=true` — yonetici iletisim karti numarayi tenant'a
    #     acar (auth.md gizlilik istisnasi), 0001'deki toplu olusturmayla
    #     ayni davranis.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.add_tenant_yonetici(
            p_tenant_id      uuid,
            p_ad             text,
            p_telefon        text,
            p_temp_code_hash text
        )
        RETURNS uuid
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_id uuid;
        BEGIN
            -- Bilinmeyen tesise yonetici acmak, hicbir yerde gorunmeyen
            -- bir hesap birakirdi. NULL doner -> uc 404.
            IF NOT EXISTS (
                SELECT 1 FROM public.tenant WHERE id = p_tenant_id
            ) THEN
                RETURN NULL;
            END IF;
            INSERT INTO public.app_user
                (tenant_id, ad, telefon, password_hash, temp_code_hash,
                 password_set, role, is_active, aranabilir, birincil)
            VALUES (p_tenant_id, p_ad, p_telefon, NULL, p_temp_code_hash,
                    false, 'yonetici'::public.user_role, true, true, false)
            RETURNING id INTO v_id;
            RETURN v_id;
        END;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.add_tenant_yonetici"
        "(uuid, text, text, text) FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.add_tenant_yonetici"
        f"(uuid, text, text, text) TO {APP_ROLE};"
    )

    # 3c) Yonetici SIL — korumali (bkz. modul basligi).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.remove_tenant_yonetici(
            p_tenant_id uuid,
            p_user_id   uuid
        )
        RETURNS text
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = ''
        AS $$
        DECLARE
            v_birincil boolean;
            v_kalan    int;
        BEGIN
            SELECT birincil INTO v_birincil
            FROM public.app_user
            WHERE tenant_id = p_tenant_id
              AND id = p_user_id
              AND role = 'yonetici'::public.user_role;
            IF NOT FOUND THEN
                RETURN NULL;              -- uc 404
            END IF;

            SELECT count(*) INTO v_kalan
            FROM public.app_user
            WHERE tenant_id = p_tenant_id
              AND role = 'yonetici'::public.user_role;
            IF v_kalan <= 1 THEN
                RETURN 'son_yonetici';    -- uc 409
            END IF;
            IF v_birincil THEN
                RETURN 'birincil';        -- uc 409
            END IF;

            -- Yabanci anahtar RESTRICT tasiyan kayitlari varsa burada
            -- istisna yukselir; uc onu 409 `yonetici_kayitlari_var`a
            -- cevirir ve kullaniciya "pasiflestirin" der.
            DELETE FROM public.app_user
            WHERE tenant_id = p_tenant_id AND id = p_user_id;
            RETURN 'silindi';
        END;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.remove_tenant_yonetici(uuid, uuid) "
        "FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.remove_tenant_yonetici(uuid, uuid) "
        f"TO {APP_ROLE};"
    )


    # ----------------------------------------------------------------- #
    # 4) (P154) `tenant_id_by_kayit_kodu` — IKI KUSUR, ayni sinif.
    #
    # BU TURDA BULUNDU, BU TURDA URETILMEDI: 0036'da eklendi ve iki kapiya
    # birden takiliyordu (`test_secdef_kapsam` zaten KIRMIZIYDI):
    #
    #   (a) PUBLIC EXECUTE. Fonksiyon SECURITY DEFINER'dir, yani RLS'i
    #       BYPASS eder; `REVOKE ... FROM PUBLIC` yazilmadigi icin proacl
    #       NULL kalmis ve varsayilan olarak HERKESE acik olmus. Diger her
    #       SECURITY DEFINER fonksiyonda bu iki satir var; burada
    #       unutulmus.
    #
    #   (b) `SET search_path = public` + govdede NITELENMEMIS `FROM tenant`.
    #       0040'in belgeledigi kuralin tam tersi: oneri, SECURITY DEFINER
    #       govdelerinde search_path'i BOS birakip her referansi TAM
    #       NITELEMEKTIR. `public` uzerinde yaratma yetkisi olan biri ayni
    #       adla bir nesne acip cagriyi golgeleyebilir.
    #
    # PUBLIC kalmasi GEREKEN sey ERISIM DEGIL, KIMLIK ONCESI CAGRIDIR:
    # sakin kaydolurken henuz oturumu yoktur ve tesisi koddan cozmek gerekir.
    # O cagri `app_rw` ile yapilir — dolayisiyla GRANT app_rw yeterlidir;
    # veritabanindaki her role acik olmasi gerekmiyordu.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_id_by_kayit_kodu(p_kod text)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT id FROM public.tenant
             WHERE upper(kayit_kodu) = upper(p_kod)
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.tenant_id_by_kayit_kodu(text) "
        "FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.tenant_id_by_kayit_kodu(text) "
        f"TO {APP_ROLE};"
    )


    # ----------------------------------------------------------------- #
    # 5) (P154) `kayit_dogrulama.tenant_id` icin ONCU KOLON INDEKSI.
    #
    # `test_indeks_kapsam` bunu zaten kirmizi tutuyordu: yabanci anahtarin
    # oncu kolonunu kapsayan bir indeks yoksa, UST SATIR silindiginde
    # (tesis silme) referans butunlugu tetigi bu tabloyu SEQ SCAN eder.
    # Tesis silme zaten agir bir islem; buna bir de tam tarama eklemek
    # gereksizdi.
    #
    # RLS BU GOCTE ACILMADI — BILINCLI (bkz. rapor): `kayit_dogrulama`
    # KIMLIK ONCESI okunur. `auth.kayit_dogrula` ve `telefon_kodu.
    # kodu_dogrula` satiri TELEFONDAN bulur ve o anda tenant HENUZ
    # BILINMEZ; `app.current_tenant_id` set edilemez. Tenant izolasyon
    # politikasi eklemek bu iki akisi (sakin kaydi + parolasiz giris)
    # SESSIZCE sifir satira dusururdu. Dogru cozum, `tenant_id_by_phone`
    # gibi bir SECURITY DEFINER cozucudur ve ayri bir tasarim karari
    # gerektirir; kacak kapatmak icin akis kirilmadi.
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_kayit_dogrulama_tenant_id "
        "ON public.kayit_dogrulama (tenant_id);"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS public.ix_kayit_dogrulama_tenant_id;")

    # `tenant_id_by_kayit_kodu` 0036'daki (kusurlu) hâline doner. Kusuru
    # birlikte geri getirmek DOGRUDUR: downgrade'in isi semayi onceki
    # revizyona esitlemektir, iyilestirmeyi saklamak degil — aksi hâlde
    # "0040'a dondum" diyen bir veritabani 0040'ta olmayan bir yetki
    # kisitlamasi tasirdi.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_id_by_kayit_kodu(p_kod text)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = public
        AS $$
            SELECT id FROM tenant WHERE upper(kayit_kodu) = upper(p_kod)
        $$;
        """
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.tenant_id_by_kayit_kodu(text) "
        "TO PUBLIC;"
    )

    # Yeni fonksiyonlar kalkar.
    op.execute(
        "DROP FUNCTION IF EXISTS public.remove_tenant_yonetici(uuid, uuid);"
    )
    op.execute(
        "DROP FUNCTION IF EXISTS public.add_tenant_yonetici"
        "(uuid, text, text, text);"
    )
    op.execute("DROP FUNCTION IF EXISTS public.tenant_yoneticiler(uuid);")

    # Kod uretici 0040'in birakti hâle doner: TEK translate, `search_path`
    # yine ACIKCA yazili (0040'in ALTER'i bu CREATE OR REPLACE ile
    # kaybolacagi icin).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.kayit_kodu_uret(p_ad text, p_tarih date)
        RETURNS text
        LANGUAGE sql
        IMMUTABLE
        SET search_path = ''
        AS $$
            SELECT rpad(
                       left(
                           regexp_replace(
                               upper(translate(p_ad,
                                   'çÇğĞıİöÖşŞüÜ', 'cCgGiIoOsSuU')),
                               '[^A-Z]', '', 'g'),
                           4),
                       4, 'X')
                   || '-' || to_char(p_tarih, 'YYMMDD');
        $$;
        """
    )
    # Cakisma eki SIRALI hâline doner.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_kayit_kodu_ata()
        RETURNS trigger
        LANGUAGE plpgsql
        SET search_path = ''
        AS $$
        DECLARE
            taban text;
            aday  text;
            n     int := 1;
        BEGIN
            IF NEW.kayit_kodu IS NOT NULL THEN
                RETURN NEW;
            END IF;
            taban := public.kayit_kodu_uret(
                NEW.ad, COALESCE(NEW.created_at, now())::date);
            aday := taban;
            WHILE EXISTS (
                SELECT 1 FROM public.tenant WHERE kayit_kodu = aday
            ) LOOP
                n := n + 1;
                aday := taban || '-' || n::text;
            END LOOP;
            NEW.kayit_kodu := aday;
            RETURN NEW;
        END;
        $$;
        """
    )
