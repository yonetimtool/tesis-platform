"""(P241 §1) PERIYODIK BAKIM TAKIBI — ekipman + bakim kaydi.

===========================================================================
NEDEN DEMIRBASIN (`asset`) ICINE YAZILMADI — OLCULDU
===========================================================================
Istek "Demirbas modulu var, bakim oraya mi baglanmali" diye sordu.
Olculen `asset` semasi:

    ad, kategori (ekipman|arac|alet|diger), nfc_tag_uid,
    durum (musait|zimmetli|bakimda), aciklama, aktif
    + asset_checkout (alan_user_id, birakan_user_id, zaman damgalari)

Yani demirbas KIME ZIMMETLENDIGINI takip eder: tasinabilir, elden ele
gecen, geri getirilmesi beklenen esya (matkap, telsiz, arac). Tasidigi
alanlarin HICBIRI bakim takibinin sordugu soruyu yanitlamiyor: konum
YOK, periyot YOK, gecmis bakim kaydi YOK, maliyet YOK, yasal zorunluluk
YOK, sonraki tarih YOK.

Asansor ise kimseye zimmetlenmez. Onu `asset`e koymak, `asset_checkout`
tablosunu asansor icin anlamsiz hale getirir ve "musait / zimmetli"
durumunu bir asansor icin yorumlanamaz kilardi.

AYRI TABLO, AMA KOPRULU: `bakim_ekipmani.asset_id` OPSIYONEL. Jeneratoru
demirbas olarak da kaydetmis bir site iki kayit tutmak zorunda kalmasin;
bagi kuran, tek kaydi iki yerden gorur.

NOT — `duzenli_gider` ile de karistirilmamali: o tablonun ornegi bile
"asansor bakimi"dir ama tuttugu sey PARA (her ay cikan tutar), bu
tablonun tuttugu sey TARIH ve UYGUNLUK (ne zaman yapildi, ne zaman
yapilmali, yasal mi). Ikisi ayri sorulardir; baglanti kurmak isteyen
bakim kaydina gider yazdirabilir (asagida).

===========================================================================
SONRAKI TARIH NEDEN SUTUN — turetilmiyor
===========================================================================
`sonraki_bakim` her zaman `son_bakim + periyot` DEGILDIR: asansor
muayenesi firmanin takvimine gore kayar, yasal kontrol sabit bir aya
baglanabilir. Istek de "otomatik hesaplansin, ELLE DE DEGISTIRILEBILSIN"
diyor. Turetilmis bir ifade elle degistirilemez; bu yuzden sutun.
Hesaplama YAZARKEN yapilir (uc), okurken degil.

===========================================================================
BILDIRIM DAMGALARI: KADEME BASINA BIR KEZ
===========================================================================
Uc kademe (yaklasti / bugun / gecikti) ayri ayri damgalanir. Tek damga
olsaydi "yaklasiyor" bildirimi gonderilen bir ekipman icin "bugun"
bildirimi HIC gitmezdi. Damgalar `sonraki_bakim` degisince (yani bakim
yapilinca) temizlenir — bir sonraki donem yeniden bildirilsin.

GECIKMISTE HER GUN HATIRLATMA YOK: `gecikme_bildirildi_at` bir kez
yazilir ve HAFTADA BIR tekrarlanir (`BAKIM_GECIKME_TEKRAR_GUN`).
Gunluk hatirlatma bildirim yorgunlugu uretir ve yorgun kullanici
bildirimleri KAPATIR — o an gercekten aciliyeti olan panik alarmi da
dahil olmak uzere. Haftalik tekrar, unutulmayi onlemeye yetiyor.
"""
from alembic import op

revision = "0144_bakim_takibi"
down_revision = "0143_akilli_ev"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        "CREATE TYPE bakim_periyot AS ENUM "
        "('aylik', 'uc_aylik', 'alti_aylik', 'yillik', 'gun');"
    )
    # DURUM SUTUN DEGIL: `sonraki_bakim` ve bugunun tarihinden TURETILIR.
    # Sutun olsaydi her gece bir is onu guncellemek zorunda kalir, is
    # kosmadigi gun liste yanlis gorunurdu.
    op.execute(
        """
        CREATE TABLE bakim_ekipmani (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad          text NOT NULL,
            tur         text NOT NULL,
            -- KONUM: blok BAGI (FK) + serbest alan metni. Otopark ya da
            -- catidaki bir ekipmanin blogu YOKTUR; zorunlu FK, veriyi
            -- uydurmaya zorlardi.
            blok_id     uuid,
            alan        text,
            periyot     bakim_periyot NOT NULL,
            -- Yalniz `periyot='gun'` iken anlamli. CHECK ikisini birbirine
            -- bagliyor: "aylik ama 45 gun" gibi celiskili bir satir
            -- yazilamasin.
            periyot_gun smallint,
            son_bakim   date,
            sonraki_bakim date NOT NULL,
            -- Sorumlu: SISTEMDEKI FIRMA (dis hizmet defteri) ya da serbest
            -- metin. Ikisi de opsiyonel: bakimi kapici yapiyorsa firma yok.
            firma_id    uuid,
            sorumlu_ad  text,
            sorumlu_telefon text,
            -- YASAL ZORUNLULUK: asansor yillik kontrolu gibi. Listede
            -- ayrica isaretlenir ve raporda ayri sayilir — denetime
            -- verilen belgede "zorunlu olanlarin kaci yapildi" sorusu
            -- her zaman sorulur.
            yasal       boolean NOT NULL DEFAULT false,
            -- NULL = TESIS VARSAYILANI (`tenant.bakim_uyari_gun`). Sabit
            -- bir sayi yazmak, yangin tupu (30 gun onceden yeter) ile
            -- asansor muayenesini (randevu icin 60 gun gerekir) ayni
            -- kefeye koyardi.
            uyari_gun   smallint,
            asset_id    uuid,
            notlar      text,
            aktif       boolean NOT NULL DEFAULT true,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            yaklasti_bildirildi_at timestamptz,
            bugun_bildirildi_at    timestamptz,
            gecikme_bildirildi_at  timestamptz,
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_bakim_periyot_gun CHECK (
                (periyot = 'gun' AND periyot_gun IS NOT NULL
                                 AND periyot_gun BETWEEN 1 AND 3650)
                OR (periyot <> 'gun' AND periyot_gun IS NULL)
            ),
            CONSTRAINT ck_bakim_uyari_gun CHECK (
                uyari_gun IS NULL OR uyari_gun BETWEEN 0 AND 365
            ),
            CONSTRAINT fk_bakim_blok
                FOREIGN KEY (blok_id, tenant_id)
                REFERENCES building_block (id, tenant_id) ON DELETE SET NULL,
            CONSTRAINT fk_bakim_firma
                FOREIGN KEY (firma_id, tenant_id)
                REFERENCES firma (id, tenant_id) ON DELETE SET NULL,
            CONSTRAINT fk_bakim_asset
                FOREIGN KEY (asset_id, tenant_id)
                REFERENCES asset (id, tenant_id) ON DELETE SET NULL
        );
        """
    )
    op.execute("CREATE INDEX ix_bakim_ekipmani_tenant ON bakim_ekipmani (tenant_id);")
    # Listenin VARSAYILAN SIRASI ve beat isinin taramasi ayni kolondan
    # gidiyor: yaklasan bakim en ustte.
    op.execute(
        "CREATE INDEX ix_bakim_ekipmani_sonraki "
        "ON bakim_ekipmani (tenant_id, sonraki_bakim);"
    )

    op.execute(
        """
        CREATE TABLE bakim_kaydi (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ekipman_id  uuid NOT NULL,
            tarih       date NOT NULL,
            -- KIM YAPTI: firma ya da personel ya da serbest metin.
            firma_id    uuid,
            yapan_user_id uuid,
            yapan_ad    text,
            islem       text,
            -- MALIYET DEFTERE YAZILMAZ, DEFTERE BAGLANIR: tutar burada
            -- BILGI olarak durur, para hareketi `finansal_hareket`te
            -- yasar (P192: TEK DEFTER). `hareket_id` o satiri gosterir.
            -- Tutari burada tutup deftere yazmamak, iki yerde iki farkli
            -- "toplam bakim gideri" uretirdi.
            tutar_kurus bigint,
            hareket_id  uuid,
            created_at  timestamptz NOT NULL DEFAULT now(),
            olusturan_user_id uuid,
            UNIQUE (id, tenant_id),
            -- UST SINIR SEMADAKIYLE AYNI (`KURUS_UST_SINIR` = 10^15).
            -- Farkli olsaydi sema kabul edip DB reddeder ve kullanici
            -- 422 yerine 500 gorurdu (P211'de bir kez yasandi).
            CONSTRAINT ck_bakim_tutar CHECK (
                tutar_kurus IS NULL OR tutar_kurus BETWEEN 0 AND 1000000000000000
            ),
            CONSTRAINT fk_bakim_kaydi_ekipman
                FOREIGN KEY (ekipman_id, tenant_id)
                REFERENCES bakim_ekipmani (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_bakim_kaydi_firma
                FOREIGN KEY (firma_id, tenant_id)
                REFERENCES firma (id, tenant_id) ON DELETE SET NULL,
            CONSTRAINT fk_bakim_kaydi_user
                FOREIGN KEY (yapan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL
        );
        """
    )
    op.execute("CREATE INDEX ix_bakim_kaydi_tenant ON bakim_kaydi (tenant_id);")
    op.execute(
        "CREATE INDEX ix_bakim_kaydi_ekipman "
        "ON bakim_kaydi (ekipman_id, tarih DESC);"
    )

    for tablo in ("bakim_ekipmani", "bakim_kaydi"):
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_isolation ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
        op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON {tablo} TO {APP_ROLE};")

    # TESIS VARSAYILANI — ekipmanda `uyari_gun` bos birakilirsa bu gecerli.
    op.execute(
        "ALTER TABLE tenant ADD COLUMN IF NOT EXISTS bakim_uyari_gun smallint "
        "NOT NULL DEFAULT 30;"
    )
    op.execute(
        "ALTER TABLE tenant ADD CONSTRAINT ck_tenant_bakim_uyari_gun "
        "CHECK (bakim_uyari_gun BETWEEN 0 AND 365);"
    )

    # EK MEKANIZMASI YENIDEN KULLANILIYOR — ayri bir `bakim_eki` tablosu
    # ACILMADI. Asansor muayene raporu da gider fisi de ayni seydir:
    # bir kaydin yanindaki kanit. CHECK kumesi genisletiliyor.
    op.execute(
        "ALTER TABLE varlik_eki DROP CONSTRAINT IF EXISTS ck_varlik_eki_tipi;"
    )
    op.execute(
        """
        ALTER TABLE varlik_eki ADD CONSTRAINT ck_varlik_eki_tipi CHECK (
            varlik_tipi = ANY (ARRAY[
                'unit', 'app_user', 'task', 'icra_dosyasi', 'tenant_dokuman',
                'complaint', 'firma', 'building_block', 'finansal_hareket',
                'bakim_kaydi', 'bakim_ekipmani'
            ])
        );
        """
    )

    for tip in ("bakim_yaklasti", "bakim_bugun", "bakim_gecikti"):
        op.execute(
            f"ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS '{tip}';"
        )


def downgrade() -> None:
    # notification_tip degerleri GERI ALINMAZ (goc 0131/0140/0141 emsali).
    op.execute(
        "ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_bakim_uyari_gun;"
    )
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS bakim_uyari_gun;")
    op.execute(
        "ALTER TABLE varlik_eki DROP CONSTRAINT IF EXISTS ck_varlik_eki_tipi;"
    )
    op.execute(
        """
        ALTER TABLE varlik_eki ADD CONSTRAINT ck_varlik_eki_tipi CHECK (
            varlik_tipi = ANY (ARRAY[
                'unit', 'app_user', 'task', 'icra_dosyasi', 'tenant_dokuman',
                'complaint', 'firma', 'building_block', 'finansal_hareket'
            ])
        );
        """
    )
    op.execute("DELETE FROM varlik_eki WHERE varlik_tipi LIKE 'bakim_%';")
    op.execute("DROP TABLE IF EXISTS bakim_kaydi;")
    op.execute("DROP TABLE IF EXISTS bakim_ekipmani;")
    op.execute("DROP TYPE IF EXISTS bakim_periyot;")
