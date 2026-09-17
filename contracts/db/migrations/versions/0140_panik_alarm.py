"""(P240 §1) PANIK BUTONU — alarm, alicilar ve yetki askisi.

===========================================================================
UC AYRI TIP, TEK TABLO
===========================================================================
Sakin panigi / guvenlik panigi / yonetici anonsu AYNI yasam dongusunu
yasar (acilir, gorulur, mudahale edilir, kapanir) ve ayni takip
sorularina yanit verir. Uc ayri tablo, ayni sorguyu uc kez yazmak ve
"toplam kac alarm" sorusunu UNION'a cevirmek olurdu.

Ayri olan sey ALICI KUMESI ve KIM TETIKLEYEBILIR — ikisi de KODDA
(`panik.py`), cunku ikisi de YETKI kararidir ve yetki kararlari
veritabani satirlarina gomulmez (rol matrisi tek kaynaktir).

===========================================================================
IPTAL PENCERESI: SATIR ONCE YAZILIR, BILDIRIM SONRA GIDER
===========================================================================
Alarm satiri BASILDIGI ANDA yazilir (`durum='beklemede'`), bildirimler
ise gecikmeli bir gorevle gonderilir. Bu sira bilincli:

  * Satiri once yazmak, IPTAL EDILEN alarmin bile denetim kaydinda
    kalmasini saglar. "Bastim, vazgectim" bir OLAYDIR; kaydi silmek,
    suistimali gorunmez kilardi.
  * Bildirimi geciktirmek, iptalin GERCEKTEN hicbir seyin gitmemesini
    saglar. Once gonderip sonra "iptal" demek, alici telefonunda calmis
    bir alarmi geri alamaz.

===========================================================================
DURUMLAR
===========================================================================
  beklemede    — iptal penceresi acik, HENUZ BILDIRIM GITMEDI
  acik         — bildirimler gonderildi, kimse mudahale etmedi
  mudahale     — biri "gidiyorum" dedi
  kapandi      — sonuclandi (kapatan + not)
  iptal        — pencere ICINDE iptal edildi, hicbir bildirim GITMEDI
  yanlis_alarm — pencere SONRASI iptal, alicilara "yanlis alarm" gitti

`iptal` ile `yanlis_alarm` AYRI: birincisinde kimse rahatsiz edilmedi,
ikincisinde edildi. Tek duruma indirmek, suistimal olcumunu kor yapardi.

===========================================================================
ALICI TABLOSU — "kime ulasti, kim gordu" bunsuz olculemez
===========================================================================
Bildirimin GONDERILDIGI ile GORULDUGU ayri seylerdir ve takip tam olarak
bu farki sorar. `notification` tablosu bunu tasiyamaz: o, bildirimin
kendisidir; burada olculen sey ALARMA verilen INSAN TEPKISIDIR.

===========================================================================
KONUM: NFC NOKTASI VEYA GPS — IKISI DE OPSIYONEL
===========================================================================
Guvenlik panigi konumla anlamli, ama konum ALINAMAYABILIR (izin yok,
kapali alan, GPS yok). Konumu ZORUNLU kilmak, konum alinamadigi icin
alarmin HIC gitmemesi demekti — acil durumda kabul edilemez.

===========================================================================
KAMERA ISARETLEME: KAYIT KOPYALANMAZ, ISARET KONUR
===========================================================================
Kayitlar NVR'da durur (P213); sunucu onlari saklamaz. "Kaydi isaretle"
burada ALARMIN uzerine kamera + an yazmak demektir; oynatma zaten var
olan `/cameras/{id}/kayit/oynat` ucundan yapilir. Kaydi kopyalamak,
saatlerce video indirmek ve depolamak olurdu.

===========================================================================
YETKI ASKISI: SURELI, GEREKCELI, SILINMEZ
===========================================================================
`app_user.panik_askida_bitis` NULL degilse ve gelecekteyse, kullanicinin
alarmi SATIR OLARAK YAZILIR ama BILDIRIM GITMEZ. Satirin yazilmasi
onemli: askidaki bir kullanicinin basmaya devam etmesi, askinin
gerekcesini dogrulayan ya da CURUTEN bir olcumdur.

SURESIZ ASKI YOK: `bitis` zorunlu. Suresiz aski, unutulan bir aski
demektir ve unutulan aski gercek bir acil durumu sessizce yutar.
"""
from alembic import op

#: Uygulama rolu — GRANT hedefi (diger goclerle ayni kaynak).
APP_ROLE = "app_rw"

revision = "0140_panik_alarm"
down_revision = "0139_devriye_haftalik_gunler"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # (P240 §1) `camera`ya (id, tenant_id) BENZERSIZLIGI EKLENIYOR.
    #
    # Depo deseni capraz-tenant FK engelidir: `FOREIGN KEY (x_id,
    # tenant_id) REFERENCES x (id, tenant_id)`. `unit`, `checkpoint` ve
    # `app_user`da bu benzersizlik VAR, `camera`da YOKTU — yani kameraya
    # bu desenle baglanan ILK tabloyuz. Alternatif, yalniz `camera(id)`ye
    # baglanmakti; o da baska tesisin kamerasinin bir alarma
    # baglanabilmesi demekti (RLS sorguyu suzer ama FK'yi DEGIL).
    #
    # `id` zaten birincil anahtar oldugu icin kisit bir SATIRI BILE
    # reddetmez; yalnizca FK'nin dayanacagi indeksi acar.
    op.execute(
        "ALTER TABLE camera ADD CONSTRAINT camera_id_tenant_id_key "
        "UNIQUE (id, tenant_id);"
    )
    op.execute(
        "CREATE TYPE panik_tip AS ENUM ('sakin', 'guvenlik', 'yonetici_anons');"
    )
    op.execute(
        "CREATE TYPE panik_durum AS ENUM "
        "('beklemede', 'acik', 'mudahale', 'kapandi', 'iptal', 'yanlis_alarm');"
    )

    op.execute(
        """
        CREATE TABLE panik_alarm (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            tip               panik_tip NOT NULL,
            durum             panik_durum NOT NULL DEFAULT 'beklemede',
            -- TETIKLEYEN SILINSE DE ALARM KALIR: guvenlik olayinin kaydi,
            -- hesabin yasam suresine baglanamaz (denetim).
            olusturan_user_id uuid,
            -- Sakin paniginde daire; guvenlik paniginde bos.
            unit_id           uuid,
            -- Konum: NFC noktasi VEYA GPS. Ikisi de opsiyonel.
            checkpoint_id     uuid,
            -- KONUM OLCUSU `numeric(9,6)`: depoda checkpoint ve
            -- scan_event ayni tipi kullaniyor (~11 cm cozunurluk).
            -- `double precision` sessizce BASKA bir yuvarlama uretir ve
            -- ayni nokta iki tabloda farkli gorunurdu.
            gps_lat           numeric(9, 6),
            gps_lng           numeric(9, 6),
            -- Kamera ISARETI (kayit kopyalanmaz; NVR'da durur).
            camera_id         uuid,
            kayit_an          timestamptz,
            -- Serbest metin: "3. katta duman var" gibi.
            aciklama          text,
            -- Kapanis
            kapatan_user_id   uuid,
            kapanis_notu      text,
            gonderildi_at     timestamptz,
            mudahale_at       timestamptz,
            kapandi_at        timestamptz,
            iptal_at          timestamptz,
            created_at        timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT fk_panik_olusturan
                FOREIGN KEY (olusturan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (olusturan_user_id),
            CONSTRAINT fk_panik_kapatan
                FOREIGN KEY (kapatan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (kapatan_user_id),
            CONSTRAINT fk_panik_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE SET NULL (unit_id),
            CONSTRAINT fk_panik_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE SET NULL (checkpoint_id),
            CONSTRAINT fk_panik_camera
                FOREIGN KEY (camera_id, tenant_id)
                REFERENCES camera (id, tenant_id) ON DELETE SET NULL (camera_id),
            -- GPS IKILISI BIRLIKTE: tek basina enlem bir konum DEGILDIR
            -- ve haritada sessizce yanlis yere pin koyar.
            CONSTRAINT ck_panik_gps CHECK (
                (gps_lat IS NULL) = (gps_lng IS NULL)
            )
        );
        """
    )
    op.execute("CREATE INDEX ix_panik_alarm_tenant ON panik_alarm (tenant_id);")
    op.execute(
        "CREATE INDEX ix_panik_alarm_olusturan ON panik_alarm (olusturan_user_id);"
    )
    op.execute("CREATE INDEX ix_panik_alarm_unit ON panik_alarm (unit_id);")
    op.execute("CREATE INDEX ix_panik_alarm_checkpoint ON panik_alarm (checkpoint_id);")
    op.execute("CREATE INDEX ix_panik_alarm_camera ON panik_alarm (camera_id);")
    op.execute("CREATE INDEX ix_panik_alarm_kapatan ON panik_alarm (kapatan_user_id);")
    # AKTIF ALARM SORGUSU en sik kosandir (mobil her acilista sorar).
    op.execute(
        "CREATE INDEX ix_panik_alarm_aktif ON panik_alarm (tenant_id, durum, created_at DESC);"
    )

    op.execute(
        """
        CREATE TABLE panik_alici (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            alarm_id      uuid NOT NULL,
            user_id       uuid NOT NULL,
            bildirildi_at timestamptz NOT NULL DEFAULT now(),
            goruldu_at    timestamptz,
            mudahale_at   timestamptz,
            UNIQUE (alarm_id, user_id),
            CONSTRAINT fk_panik_alici_alarm
                FOREIGN KEY (alarm_id, tenant_id)
                REFERENCES panik_alarm (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_panik_alici_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute("CREATE INDEX ix_panik_alici_tenant ON panik_alici (tenant_id);")
    op.execute("CREATE INDEX ix_panik_alici_alarm ON panik_alici (alarm_id);")
    op.execute("CREATE INDEX ix_panik_alici_user ON panik_alici (user_id);")

    # --- RLS: TENANT IZOLASYONU ------------------------------------------
    #
    # FORCE olmadan tablo SAHIBI politikalari ATLAR — yani gocleri kosan
    # rol ve ayni rolle baglanan bir arac tum tesislerin alarmlarini
    # gorurdu. `test_rls_kapsam` bunu ilk yazimda YAKALADI ve hakliydi:
    # ENABLE + FORCE + politika ucu birden yazilmadan tablo "izole" degil,
    # yalnizca "izole gorunuyor".
    for tablo in ("panik_alarm", "panik_alici"):
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_isolation ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
        op.execute(
            f"GRANT SELECT, INSERT, UPDATE, DELETE ON {tablo} TO {APP_ROLE};"
        )

    # YETKI ASKISI — SURELI ve GEREKCELI.
    op.execute("ALTER TABLE app_user ADD COLUMN panik_askida_bitis timestamptz;")
    op.execute("ALTER TABLE app_user ADD COLUMN panik_aski_nedeni text;")

    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'panik_alarm';"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'panik_yanlis_alarm';"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'panik_kapandi';"
    )


def downgrade() -> None:
    # notification_tip degerleri GERI ALINMAZ: PostgreSQL enum degeri
    # dusuremez ve tipi yeniden yaratmak, o tipi kullanan TUM tablolari
    # yeniden yazmak demektir (goc 0131 emsali).
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS panik_aski_nedeni;")
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS panik_askida_bitis;")
    op.execute("DROP TABLE IF EXISTS panik_alici;")
    op.execute("DROP TABLE IF EXISTS panik_alarm;")
    op.execute("DROP TYPE IF EXISTS panik_durum;")
    op.execute("DROP TYPE IF EXISTS panik_tip;")
    op.execute(
        "ALTER TABLE camera DROP CONSTRAINT IF EXISTS camera_id_tenant_id_key;"
    )
