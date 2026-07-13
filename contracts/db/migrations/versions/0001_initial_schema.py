"""initial schema: multi-tenant tesis guvenlik & operasyon

Revision ID: 0001_initial_schema
Revises:
Create Date: 2026-06-27

Tek dogruluk kaynagi (single source of truth) DB semasi.

Tasarim kararlari (detay icin /contracts/README.md):
  * Tum tablolarda tenant_id (tenant tablosunda id) + Row-Level Security (RLS).
  * Tenant izolasyonu uygulama katmaninda DEGIL, DB seviyesinde RLS ile zorlanir.
    Her istek basinda backend `SET app.current_tenant_id = '<uuid>'` calistirir;
    politikalar bu oturum degiskenini kullanir.
  * Cross-tenant FK referanslarini imkansiz kilmak icin composite FK
    (id, tenant_id) -> (id, tenant_id) kullanilir.
  * Tum zaman damgalari UTC `timestamptz`. Gun-ici saatler (shift, patrol_plan)
    `time` olarak tutulur ve tenant.timezone ile yorumlanir (gece 00:00 mantigi).
  * Birincil anahtarlar UUID (gen_random_uuid, pgcrypto/pg >= 13 yerlesik).
"""
from alembic import op


# revision identifiers, used by Alembic.
revision = "0001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


# Uygulama (backend) rolu. RLS bu rol icin zorlanir; migration'i calistiran
# superuser/owner BYPASSRLS oldugu icin politikalardan etkilenmez.
APP_ROLE = "app_rw"


def upgrade() -> None:
    # ------------------------------------------------------------------ #
    # 0. Eklentiler ve uygulama rolu
    # ------------------------------------------------------------------ #
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")  # gen_random_uuid()
    # rezervasyon cakisma engeli: EXCLUDE USING gist icinde uuid '=' operatoru
    # icin gerekli (bkz. 9z5 rezervasyon — ex_rezervasyon_onayli_cakisma).
    op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist;")

    op.execute(
        f"""
        DO $$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '{APP_ROLE}') THEN
                CREATE ROLE {APP_ROLE} NOLOGIN;
            END IF;
        END
        $$;
        """
    )

    # ------------------------------------------------------------------ #
    # 1. Enum tipleri
    # ------------------------------------------------------------------ #
    op.execute(
        "CREATE TYPE user_role AS ENUM "
        "('admin', 'yonetici', 'security', 'tesis_gorevlisi', 'resident');"
    )
    op.execute(
        "CREATE TYPE gun_tipi AS ENUM ('her_gun', 'hafta_ici', 'hafta_sonu', 'resmi_tatil');"
    )
    op.execute(
        "CREATE TYPE patrol_window_durum AS ENUM ('bekliyor', 'tamamlandi', 'kacirildi');"
    )
    # notification.tip — tur + peyzaj + acil durum; ileride genisler.
    op.execute(
        "CREATE TYPE notification_tip AS ENUM "
        "('kacirilan_tur', 'eksik_checkpoint', 'gecikmis_okutma', "
        "'peyzaj_yaklasan', 'peyzaj_kacirilan', 'acil_durum');"
    )
    # task.tip — esnek gorev tipi (peyzaj dahil); ileride genisler.
    op.execute(
        "CREATE TYPE task_tip AS ENUM "
        "('temizlik', 'kontrol', 'ilaclama', 'bakim', 'peyzaj', 'diger');"
    )
    # asset (demirbas) kategori + durum.
    op.execute(
        "CREATE TYPE asset_kategori AS ENUM ('ekipman', 'arac', 'alet', 'diger');"
    )
    op.execute(
        "CREATE TYPE asset_durum AS ENUM ('musait', 'zimmetli', 'bakimda');"
    )
    # acil durum alarm durumu.
    op.execute("CREATE TYPE emergency_durum AS ENUM ('acik', 'cozuldu');")

    op.execute(
        "CREATE TYPE complaint_durum AS ENUM ('acik', 'inceleniyor', 'cozuldu');"
    )
    # Talep turu (opsiyonel): gurultu/goruntu kirliligi istatistikleri icin
    # temel; NULL = belirtilmemis (eski kayitlar geriye uyumlu).
    op.execute(
        "CREATE TYPE complaint_kategori AS ENUM ('gurultu', 'goruntu', 'diger');"
    )
    # aidat: sakin rol tipi + odeme yontemi + odeme durumu.
    op.execute("CREATE TYPE resident_rol AS ENUM ('malik', 'kiraci');")
    op.execute("CREATE TYPE dues_yontem AS ENUM ('elden', 'havale', 'kart', 'diger');")
    op.execute("CREATE TYPE dues_durum AS ENUM ('basarili', 'bekliyor', 'iptal');")
    # push: cihaz platformu (FCM device token kaydi).
    op.execute("CREATE TYPE device_platform AS ENUM ('android', 'ios', 'web');")
    # (ziyaretci artik LOG-ONLY kayittir: onay/red akisi kaldirildi — durum
    #  enum'u yok; guvenlik kaydeder + hedef sakine BILGILENDIRME push'u gider.)
    # kargo/paket takibi durumu: kapida teslim alinmayi bekler -> sakin alir.
    op.execute("CREATE TYPE kargo_durum AS ENUM ('bekliyor', 'teslim_alindi');")
    # yonetici tek-seferlik ziyaretci/paket goruntuleme izin talebi durumu:
    # bekliyor -> sakin onaylar/reddeder; onaylandi ise TEK KULLANIMLIK izin
    # (ilk okumada tuketilir — bkz. unit_access_permission.used).
    op.execute(
        "CREATE TYPE access_request_durum AS ENUM "
        "('bekliyor', 'onaylandi', 'reddedildi');"
    )
    # ortak alan rezervasyon talebi durumu (yonetici karar verir).
    op.execute(
        "CREATE TYPE rezervasyon_durum AS ENUM ('bekliyor', 'onaylandi', 'reddedildi');"
    )
    # Entegrasyon kanal turu (C1b): generic webhook temel; megafon/akilli-ev
    # PRESET'leri de generic webhook uzerinde calisir (marka-bagimsiz). C1a
    # 'phone' kanalinin yanina eklenir (call/notify soyutlamasi genisler).
    op.execute(
        "CREATE TYPE integration_channel AS ENUM "
        "('webhook', 'megaphone', 'smarthome');"
    )
    # etkinlik RSVP durumu (sakin katilim beyani; degistirilebilir).
    op.execute(
        "CREATE TYPE katilim_durum AS ENUM ('katiliyorum', 'katilmiyorum');"
    )
    # Daire-sikayeti (D1) turu ve durumu — yonetim 'complaint'inden AYRI.
    op.execute(
        "CREATE TYPE unit_complaint_kategori AS ENUM "
        "('gurultu', 'ayakkabi', 'diger');"
    )
    op.execute(
        "CREATE TYPE unit_complaint_durum AS ENUM ('acik', 'kapali');"
    )

    # ------------------------------------------------------------------ #
    # 2. tenant
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE tenant (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            ad          text NOT NULL,
            -- slug: login'de tenant'i belirleyen kisa, benzersiz, insan-okunur ad.
            -- (email tenant-ici benzersiz oldugu icin login email tek basina yetmez;
            --  istemci tenant_slug gonderir -> tenant_id_by_slug ile cozumlenir.)
            slug        text NOT NULL,
            timezone    text NOT NULL DEFAULT 'Europe/Istanbul',
            -- acil durumda mobilin arayacagi yonetim numarasi (backend saklar, aramaz).
            acil_durum_telefon text,
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_tenant_slug UNIQUE (slug),
            CONSTRAINT ck_tenant_slug CHECK (slug ~ '^[a-z0-9][a-z0-9-]*$')
        );
        """
    )

    # Login bootstrap: app_rw RLS'e tabidir ve tenant baglami HENUZ yokken
    # tenant tablosunu okuyamaz (yumurta-tavuk). Bu SECURITY DEFINER fonksiyon
    # owner (superuser) yetkisiyle calisir ve YALNIZCA slug -> id eslemesini
    # doner; baska tenant verisi sizdirmaz. Login bununla tenant_id'yi bulup
    # set_config('app.current_tenant_id', ...) yapar, sonrasi normal RLS akisi.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.tenant_id_by_slug(p_slug text)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT id FROM public.tenant WHERE slug = p_slug;
        $$;
        """
    )
    op.execute("REVOKE ALL ON FUNCTION public.tenant_id_by_slug(text) FROM PUBLIC;")
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.tenant_id_by_slug(text) TO {APP_ROLE};"
    )

    # ------------------------------------------------------------------ #
    # 3. app_user
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE app_user (
            id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id      uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad             text NOT NULL,
            -- personel icin zorunlu (login anahtari); resident icin OPSIYONEL
            -- (sakin daire no + parola ile girer — bkz. /contracts/auth.md §1.2).
            email          text,
            telefon        text,
            -- Rol-bazli arama (C1a): kullanici telefonuyla ARANMAYA riza verdi mi?
            -- Numara YALNIZ riza=true iken ve yetkili arayan role /call-target
            -- ile aciklanir (KVKK — amaç-sınırlı, riza-kapili). Yonetim tarafindan
            -- girilir; kullanici bu turda kendi yonetmez.
            aranabilir     boolean NOT NULL DEFAULT false,
            -- resident ilk giriste parola belirleyene kadar NULL olabilir.
            password_hash  text,
            -- yonetici'nin sakine ilettigi TEK SEFERLIK gecici kod (bcrypt hash;
            -- duz metin ASLA saklanmaz). Parola belirlenince NULL'lanir.
            temp_code_hash text,
            -- sakin kendi kalici parolasini belirledi mi? (ilk giris akisi)
            password_set   boolean NOT NULL DEFAULT false,
            role           user_role NOT NULL,
            is_active      boolean NOT NULL DEFAULT true,
            created_at     timestamptz NOT NULL DEFAULT now(),
            updated_at     timestamptz NOT NULL DEFAULT now(),
            -- composite FK hedefi olabilmesi icin:
            UNIQUE (id, tenant_id),
            -- email tenant icinde benzersiz (case-insensitive; NULL'lar serbest):
            CONSTRAINT uq_app_user_tenant_email UNIQUE (tenant_id, email),
            -- personel email'siz olamaz; resident'ta serbest:
            CONSTRAINT ck_app_user_staff_email
                CHECK (role = 'resident' OR email IS NOT NULL)
        );
        """
    )
    op.execute("CREATE INDEX ix_app_user_tenant ON app_user (tenant_id);")
    op.execute(
        "CREATE UNIQUE INDEX uq_app_user_tenant_email_lower "
        "ON app_user (tenant_id, lower(email));"
    )

    # ------------------------------------------------------------------ #
    # 4. shift  (tekrar eden gun-ici vardiya tanimi)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE shift (
            id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad              text NOT NULL,
            baslangic_saat  time NOT NULL,   -- gun-ici saat (UTC degil; tenant.timezone ile yorumlanir)
            bitis_saat      time NOT NULL,   -- gece yarisini gecebilir (bitis < baslangic => ertesi gun)
            gun_tipi        gun_tipi NOT NULL DEFAULT 'her_gun',
            created_at      timestamptz NOT NULL DEFAULT now(),
            updated_at      timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_shift_tenant ON shift (tenant_id);")

    # ------------------------------------------------------------------ #
    # 5. checkpoint  (NFC noktasi)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE checkpoint (
            id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad           text NOT NULL,
            nfc_tag_uid  text NOT NULL,
            gps_lat      numeric(9, 6),
            gps_lng      numeric(9, 6),
            aktif        boolean NOT NULL DEFAULT true,
            -- NTAG424 SDM: AES-128 etiket anahtari (SDM_KEK ile AES-GCM sifreli,
            -- base64); NULL = provision edilmemis. sdm_son_sayac = replay korumasi
            -- (kabul edilen en buyuk okuma sayaci).
            sdm_key_sifreli  text,
            sdm_son_sayac    bigint NOT NULL DEFAULT 0,
            created_at   timestamptz NOT NULL DEFAULT now(),
            updated_at   timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT uq_checkpoint_tenant_nfc UNIQUE (tenant_id, nfc_tag_uid)
        );
        """
    )
    op.execute("CREATE INDEX ix_checkpoint_tenant ON checkpoint (tenant_id);")
    op.execute(
        "CREATE INDEX ix_checkpoint_nfc ON checkpoint (tenant_id, nfc_tag_uid);"
    )

    # ------------------------------------------------------------------ #
    # 6. patrol_plan
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE patrol_plan (
            id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad              text NOT NULL,
            shift_id        uuid,
            baslangic_saat  time NOT NULL,        -- orn 00:00 (gece turu)
            bitis_saat      time NOT NULL,        -- orn 06:00; bitis < baslangic => gece yarisini gecer
            periyot_dakika  integer NOT NULL,     -- orn 60 => saat basi pencere
            aktif           boolean NOT NULL DEFAULT true,
            created_at      timestamptz NOT NULL DEFAULT now(),
            updated_at      timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_patrol_plan_periyot CHECK (periyot_dakika > 0),
            -- shift ayni tenant'a ait olmali (cross-tenant FK engeli):
            -- Kolon-ozel SET NULL: sadece shift_id NULL'lanir; paylasilan NOT NULL
            -- tenant_id'ye dokunulmaz (PG15+). Bkz. /contracts/README.md.
            CONSTRAINT fk_patrol_plan_shift
                FOREIGN KEY (shift_id, tenant_id)
                REFERENCES shift (id, tenant_id) ON DELETE SET NULL (shift_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_patrol_plan_tenant ON patrol_plan (tenant_id);")
    op.execute("CREATE INDEX ix_patrol_plan_shift ON patrol_plan (shift_id);")

    # ------------------------------------------------------------------ #
    # 7. patrol_plan_checkpoint  (plan <-> checkpoint, sirali)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE patrol_plan_checkpoint (
            tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            patrol_plan_id   uuid NOT NULL,
            checkpoint_id    uuid NOT NULL,
            sira             integer NOT NULL,
            PRIMARY KEY (patrol_plan_id, checkpoint_id),
            CONSTRAINT fk_ppc_plan
                FOREIGN KEY (patrol_plan_id, tenant_id)
                REFERENCES patrol_plan (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_ppc_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT uq_ppc_plan_sira UNIQUE (patrol_plan_id, sira),
            CONSTRAINT ck_ppc_sira CHECK (sira >= 0)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_ppc_tenant ON patrol_plan_checkpoint (tenant_id);"
    )
    op.execute(
        "CREATE INDEX ix_ppc_checkpoint ON patrol_plan_checkpoint (checkpoint_id);"
    )

    # ------------------------------------------------------------------ #
    # 8. patrol_window  (scheduler tarafindan uretilen somut pencereler)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE patrol_window (
            id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id          uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            patrol_plan_id     uuid NOT NULL,
            pencere_baslangic  timestamptz NOT NULL,   -- UTC, somut an
            pencere_bitis      timestamptz NOT NULL,   -- UTC, somut an
            durum              patrol_window_durum NOT NULL DEFAULT 'bekliyor',
            created_at         timestamptz NOT NULL DEFAULT now(),
            updated_at         timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT fk_patrol_window_plan
                FOREIGN KEY (patrol_plan_id, tenant_id)
                REFERENCES patrol_plan (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT ck_patrol_window_aralik CHECK (pencere_bitis > pencere_baslangic),
            -- ayni plan icin ayni pencere bir kez uretilsin (scheduler idempotent):
            CONSTRAINT uq_patrol_window_plan_baslangic
                UNIQUE (patrol_plan_id, pencere_baslangic)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_patrol_window_tenant ON patrol_window (tenant_id);"
    )
    op.execute(
        "CREATE INDEX ix_patrol_window_plan ON patrol_window (patrol_plan_id);"
    )
    # Dashboard/live ve scheduler sorgulari icin:
    op.execute(
        "CREATE INDEX ix_patrol_window_durum_baslangic "
        "ON patrol_window (tenant_id, durum, pencere_baslangic);"
    )

    # ------------------------------------------------------------------ #
    # 9. scan_event  (mobilin gonderdigi tur kaniti)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE scan_event (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            guard_id          uuid NOT NULL,
            checkpoint_id     uuid NOT NULL,
            patrol_window_id  uuid,                 -- ad-hoc okutma olabilir => nullable
            nfc_tag_uid       text NOT NULL,
            okutma_zamani     timestamptz NOT NULL, -- cihazin okuttugu an (UTC)
            gps_lat           numeric(9, 6),
            gps_lng           numeric(9, 6),
            foto_url          text,
            imza_dogrulandi   boolean NOT NULL DEFAULT false,
            idempotency_key   text NOT NULL,
            created_at        timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_scan_guard
                FOREIGN KEY (guard_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            CONSTRAINT fk_scan_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE RESTRICT,
            -- Kolon-ozel SET NULL: sadece patrol_window_id NULL'lanir; paylasilan
            -- NOT NULL tenant_id'ye dokunulmaz (PG15+). Bkz. /contracts/README.md.
            CONSTRAINT fk_scan_window
                FOREIGN KEY (patrol_window_id, tenant_id)
                REFERENCES patrol_window (id, tenant_id) ON DELETE SET NULL (patrol_window_id),
            -- offline cift gonderim engeli (idempotency):
            CONSTRAINT uq_scan_tenant_idempotency UNIQUE (tenant_id, idempotency_key)
        );
        """
    )
    op.execute("CREATE INDEX ix_scan_tenant ON scan_event (tenant_id);")
    op.execute("CREATE INDEX ix_scan_guard ON scan_event (guard_id);")
    op.execute("CREATE INDEX ix_scan_checkpoint ON scan_event (checkpoint_id);")
    op.execute("CREATE INDEX ix_scan_window ON scan_event (patrol_window_id);")
    op.execute(
        "CREATE INDEX ix_scan_okutma_zamani "
        "ON scan_event (tenant_id, okutma_zamani DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9b. notification  (kacirilan tur vb. kalici bildirim kaydi)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE notification (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            tip               notification_tip NOT NULL,
            patrol_window_id  uuid,
            patrol_plan_id    uuid,
            checkpoint_id     uuid,
            -- task_id: peyzaj/gorev kaynakli bildirim referansi (log; FK YOK — notification
            -- tablosu task'tan ONCE olusur ve append-only log'dur).
            task_id           uuid,
            -- dedup_key: pencere-disi bildirimler icin idempotency anahtari
            -- (orn. peyzaj: '<tip>:<task_id>:<planlanan_iso>'). UNIQUE asagida.
            dedup_key         text,
            mesaj             text NOT NULL,
            okundu            boolean NOT NULL DEFAULT false,
            created_at        timestamptz NOT NULL DEFAULT now(),
            -- Kolon-ozel SET NULL: yalnizca ilgili FK kolonu NULL'lanir; paylasilan
            -- NOT NULL tenant_id korunur (PG15+). Bkz. /contracts/README.md.
            CONSTRAINT fk_notification_window
                FOREIGN KEY (patrol_window_id, tenant_id)
                REFERENCES patrol_window (id, tenant_id) ON DELETE SET NULL (patrol_window_id),
            CONSTRAINT fk_notification_plan
                FOREIGN KEY (patrol_plan_id, tenant_id)
                REFERENCES patrol_plan (id, tenant_id) ON DELETE SET NULL (patrol_plan_id),
            CONSTRAINT fk_notification_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE SET NULL (checkpoint_id),
            -- Idempotent bildirim: ayni kacirilan pencere icin tek kayit.
            -- (patrol_window_id NULL ise NULLS DISTINCT geregi dedup uygulanmaz;
            --  pencere-bazli alarmlar icin window dolu oldugundan calisir.)
            CONSTRAINT uq_notification_tenant_tip_window
                UNIQUE (tenant_id, tip, patrol_window_id),
            -- pencere-disi bildirimler icin idempotency (dedup_key NULL => NULLS DISTINCT,
            -- pencere-bazli kayitlari etkilemez):
            CONSTRAINT uq_notification_dedup UNIQUE (tenant_id, dedup_key)
        );
        """
    )
    op.execute("CREATE INDEX ix_notification_tenant ON notification (tenant_id);")
    op.execute(
        "CREATE INDEX ix_notification_list "
        "ON notification (tenant_id, created_at DESC);"
    )
    op.execute(
        "CREATE INDEX ix_notification_okundu ON notification (tenant_id, okundu);"
    )

    # ------------------------------------------------------------------ #
    # 9c-0. task_category  (yonetici-tanimli gorev kategorileri — A6)
    # ------------------------------------------------------------------ #
    # Sabit task_tip enum'unun yaninda tenant'a ozel, yonetici CRUD'lu
    # kategori seti. SOFT-DELETE (aktif=false): gorev gecmisi kategori
    # adina referans verebilir, hard silme kaydi koparir.
    op.execute(
        """
        CREATE TABLE task_category (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad          text NOT NULL,
            aktif       boolean NOT NULL DEFAULT true,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz,
            UNIQUE (id, tenant_id),
            CONSTRAINT uq_task_category_tenant_ad UNIQUE (tenant_id, ad)
        );
        """
    )
    op.execute("CREATE INDEX ix_task_category_tenant ON task_category (tenant_id);")

    # ------------------------------------------------------------------ #
    # 9c. task  (esnek gorev: temizlik/kontrol/ilaclama... tek modelde)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE task (
            id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            tip              task_tip NOT NULL,
            ad               text NOT NULL,
            aciklama         text,
            atanan_user_id   uuid,
            checkpoint_id    uuid,
            kategori_id      uuid,      -- yonetici-tanimli kategori (A6); NULL = kategorisiz
            periyot_dakika   integer,   -- tekrar araligi (periyodik gorev/peyzaj); tek seferlikse NULL
            sonraki_planlanan timestamptz,  -- bir sonraki planlanan an (UTC); peyzaj takvimi
            foto_zorunlu     boolean NOT NULL DEFAULT false,  -- completion'da foto kaniti sart (mobil §11)
            aktif            boolean NOT NULL DEFAULT true,
            created_at       timestamptz NOT NULL DEFAULT now(),
            updated_at       timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_task_periyot CHECK (periyot_dakika IS NULL OR periyot_dakika > 0),
            -- Kolon-ozel SET NULL: yalnizca ilgili kolon NULL'lanir; tenant_id korunur.
            CONSTRAINT fk_task_atanan
                FOREIGN KEY (atanan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (atanan_user_id),
            CONSTRAINT fk_task_checkpoint
                FOREIGN KEY (checkpoint_id, tenant_id)
                REFERENCES checkpoint (id, tenant_id) ON DELETE SET NULL (checkpoint_id),
            CONSTRAINT fk_task_kategori
                FOREIGN KEY (kategori_id, tenant_id)
                REFERENCES task_category (id, tenant_id) ON DELETE SET NULL (kategori_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_task_tenant ON task (tenant_id);")
    op.execute("CREATE INDEX ix_task_tip ON task (tenant_id, tip);")
    op.execute("CREATE INDEX ix_task_atanan ON task (atanan_user_id);")
    # peyzaj takvimi / hatirlatma sorgulari (yaklasan/kacirilan):
    op.execute(
        "CREATE INDEX ix_task_takvim ON task (tenant_id, tip, sonraki_planlanan);"
    )

    # ------------------------------------------------------------------ #
    # 9d. task_completion  (gorev tamamlama kaniti — NFC/GPS/foto)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE task_completion (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id           uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            task_id             uuid NOT NULL,
            tamamlayan_user_id  uuid NOT NULL,
            tamamlanma_zamani   timestamptz NOT NULL,
            nfc_tag_uid         text,
            gps_lat             numeric(9, 6),
            gps_lng             numeric(9, 6),
            foto_key            text,       -- MinIO obje anahtari
            foto_url            text,
            notlar              text,       -- ('not' SQL anahtar kelimesi oldugu icin 'notlar')
            idempotency_key     text NOT NULL,
            created_at          timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_completion_task
                FOREIGN KEY (task_id, tenant_id)
                REFERENCES task (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_completion_user
                FOREIGN KEY (tamamlayan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- offline cift gonderim korumasi (scan_event ile ayni desen):
            CONSTRAINT uq_completion_tenant_idempotency UNIQUE (tenant_id, idempotency_key)
        );
        """
    )
    op.execute("CREATE INDEX ix_completion_tenant ON task_completion (tenant_id);")
    op.execute("CREATE INDEX ix_completion_task ON task_completion (task_id);")
    op.execute(
        "CREATE INDEX ix_completion_zaman "
        "ON task_completion (tenant_id, tamamlanma_zamani DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9e. asset  (demirbas envanteri)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE asset (
            id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad           text NOT NULL,
            kategori     asset_kategori,
            nfc_tag_uid  text,                 -- demirbasa yapisik NFC; tenant icinde benzersiz
            durum        asset_durum NOT NULL DEFAULT 'musait',
            aciklama     text,
            aktif        boolean NOT NULL DEFAULT true,
            created_at   timestamptz NOT NULL DEFAULT now(),
            updated_at   timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_asset_tenant ON asset (tenant_id);")
    op.execute("CREATE INDEX ix_asset_durum ON asset (tenant_id, durum);")
    # nfc_tag_uid tenant icinde benzersiz (NULL haric — etiketsiz demirbas olabilir):
    op.execute(
        "CREATE UNIQUE INDEX uq_asset_tenant_nfc ON asset (tenant_id, nfc_tag_uid) "
        "WHERE nfc_tag_uid IS NOT NULL;"
    )

    # ------------------------------------------------------------------ #
    # 9f. asset_checkout  (zimmet: al/birak; tek aktif zimmet)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE asset_checkout (
            id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id                uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            asset_id                 uuid NOT NULL,
            alan_user_id             uuid NOT NULL,
            birakan_user_id          uuid,               -- zimmeti kapatan (sahibi/admin); acikken NULL
            alma_zamani              timestamptz NOT NULL DEFAULT now(),
            birakma_zamani           timestamptz,        -- NULL => hala uzerinde (acik zimmet)
            alma_nfc_tag_uid         text,
            birakma_nfc_tag_uid      text,
            alma_gps_lat             numeric(9, 6),
            alma_gps_lng             numeric(9, 6),
            birakma_gps_lat          numeric(9, 6),
            birakma_gps_lng          numeric(9, 6),
            notlar                   text,
            idempotency_key          text NOT NULL,      -- alma (checkout) idempotency
            birakma_idempotency_key  text,               -- birakma (checkin) idempotency
            created_at               timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_checkout_asset
                FOREIGN KEY (asset_id, tenant_id)
                REFERENCES asset (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_checkout_user
                FOREIGN KEY (alan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- Kolon-ozel SET NULL: yalnizca birakan_user_id NULL'lanir; tenant_id korunur.
            CONSTRAINT fk_checkout_birakan
                FOREIGN KEY (birakan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (birakan_user_id),
            -- offline cift gonderim korumasi (alma):
            CONSTRAINT uq_checkout_tenant_idempotency UNIQUE (tenant_id, idempotency_key)
        );
        """
    )
    op.execute("CREATE INDEX ix_checkout_tenant ON asset_checkout (tenant_id);")
    op.execute("CREATE INDEX ix_checkout_asset ON asset_checkout (asset_id);")
    op.execute(
        "CREATE INDEX ix_checkout_alma ON asset_checkout (tenant_id, alma_zamani DESC);"
    )
    # TEK AKTIF ZIMMET: bir asset icin en fazla bir acik (birakma_zamani NULL) checkout.
    op.execute(
        "CREATE UNIQUE INDEX uq_asset_open_checkout "
        "ON asset_checkout (tenant_id, asset_id) WHERE birakma_zamani IS NULL;"
    )
    # birakma (checkin) idempotency:
    op.execute(
        "CREATE UNIQUE INDEX uq_checkout_birakma_idem "
        "ON asset_checkout (tenant_id, birakma_idempotency_key) "
        "WHERE birakma_idempotency_key IS NOT NULL;"
    )

    # ------------------------------------------------------------------ #
    # 9g. emergency_alert  (acil durum butonu — saha -> yonetim anlik alarm)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE emergency_alert (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id           uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            tetikleyen_user_id  uuid NOT NULL,
            tetiklenme_zamani   timestamptz NOT NULL DEFAULT now(),
            gps_lat             numeric(9, 6),
            gps_lng             numeric(9, 6),
            durum               emergency_durum NOT NULL DEFAULT 'acik',
            cozen_user_id       uuid,
            cozulme_zamani      timestamptz,
            notlar              text,
            idempotency_key     text NOT NULL,
            created_at          timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_emergency_tetikleyen
                FOREIGN KEY (tetikleyen_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- Kolon-ozel SET NULL: yalnizca cozen_user_id NULL'lanir; tenant_id korunur.
            CONSTRAINT fk_emergency_cozen
                FOREIGN KEY (cozen_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (cozen_user_id),
            -- panik aninda mukerrer basim korumasi:
            CONSTRAINT uq_emergency_tenant_idempotency UNIQUE (tenant_id, idempotency_key)
        );
        """
    )
    op.execute("CREATE INDEX ix_emergency_tenant ON emergency_alert (tenant_id);")
    op.execute("CREATE INDEX ix_emergency_durum ON emergency_alert (tenant_id, durum);")
    op.execute(
        "CREATE INDEX ix_emergency_zaman "
        "ON emergency_alert (tenant_id, tetiklenme_zamani DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9h. unit  (konut/daire — aidat bu birime tahakkuk eder)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE unit (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            no          text NOT NULL,            -- ornek "A-12"
            blok        text,                     -- blok etiketi ("A")
            kat         integer,                  -- kat (0=zemin) — bina semasi
            sira        integer,                  -- kattaki sira/konum
            metrekare   numeric(8, 2),
            aktif       boolean NOT NULL DEFAULT true,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT uq_unit_tenant_no UNIQUE (tenant_id, no)
        );
        """
    )
    op.execute("CREATE INDEX ix_unit_tenant ON unit (tenant_id);")
    op.execute("CREATE INDEX ix_unit_blok ON unit (tenant_id, blok);")

    # ------------------------------------------------------------------ #
    # 9i. unit_resident  (daire <-> resident kullanici; aktif sakin = bitis NULL)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE unit_resident (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            unit_id     uuid NOT NULL,
            user_id     uuid NOT NULL,
            rol_tipi    resident_rol,             -- malik | kiraci
            baslangic   timestamptz,
            bitis       timestamptz,              -- NULL => aktif sakin
            created_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_unitresident_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_unitresident_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute("CREATE INDEX ix_unitresident_tenant ON unit_resident (tenant_id);")
    op.execute("CREATE INDEX ix_unitresident_unit ON unit_resident (unit_id);")
    op.execute("CREATE INDEX ix_unitresident_user ON unit_resident (user_id);")
    # Ayni daire+kullanici icin tek aktif baglanti (bitis NULL):
    op.execute(
        "CREATE UNIQUE INDEX uq_unitresident_aktif "
        "ON unit_resident (unit_id, user_id) WHERE bitis IS NULL;"
    )

    # ------------------------------------------------------------------ #
    # 9j. dues_assessment  (aidat tahakkuku — daireye/donem)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE dues_assessment (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            unit_id           uuid NOT NULL,
            donem             text NOT NULL,        -- ornek "2026-06"
            tutar_kurus       integer NOT NULL,     -- KURUS (minor units); float kullanma
            son_odeme_tarihi  date,
            aciklama          text,
            created_at        timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_assessment_tutar CHECK (tutar_kurus > 0),
            CONSTRAINT fk_assessment_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            -- ayni daireye ayni donem iki kez tahakkuk olmasin:
            CONSTRAINT uq_assessment_tenant_unit_donem UNIQUE (tenant_id, unit_id, donem)
        );
        """
    )
    op.execute("CREATE INDEX ix_assessment_tenant ON dues_assessment (tenant_id);")
    op.execute("CREATE INDEX ix_assessment_unit ON dues_assessment (unit_id);")
    op.execute("CREATE INDEX ix_assessment_donem ON dues_assessment (tenant_id, donem);")

    # ------------------------------------------------------------------ #
    # 9k. dues_payment  (odeme kaydi — manuel/soyut; gercek tahsilat sonraki prompt)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE dues_payment (
            id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            unit_id           uuid NOT NULL,
            assessment_id     uuid,                 -- hangi tahakkuk; serbest/kismi odemede NULL
            tutar_kurus       integer NOT NULL,     -- KURUS
            odeme_zamani      timestamptz NOT NULL DEFAULT now(),
            donem             text,                 -- 'YYYY-MM'; serbest odemede NULL olabilir (rapor atfi)
            yontem            dues_yontem NOT NULL,
            durum             dues_durum NOT NULL DEFAULT 'basarili',
            makbuz_no         text,
            -- gercek saglayici (kart): hangi provider + saglayici referansi (token/oid).
            provider          text,                 -- 'manual'|'iyzico'|'paytr'
            provider_ref      text,                 -- webhook bu referansla odemeyi bulur
            kaydeden_user_id  uuid NOT NULL,
            idempotency_key   text NOT NULL,
            created_at        timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_payment_tutar CHECK (tutar_kurus > 0),
            CONSTRAINT fk_payment_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            -- Kolon-ozel SET NULL: yalnizca assessment_id NULL'lanir; tenant_id korunur.
            CONSTRAINT fk_payment_assessment
                FOREIGN KEY (assessment_id, tenant_id)
                REFERENCES dues_assessment (id, tenant_id) ON DELETE SET NULL (assessment_id),
            CONSTRAINT fk_payment_kaydeden
                FOREIGN KEY (kaydeden_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- cift odeme kaydi korumasi:
            CONSTRAINT uq_payment_tenant_idempotency UNIQUE (tenant_id, idempotency_key),
            -- composite FK hedefi olabilmesi icin (butce otomatik gelir kaydi):
            CONSTRAINT uq_payment_id_tenant UNIQUE (id, tenant_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_payment_tenant ON dues_payment (tenant_id);")
    op.execute("CREATE INDEX ix_payment_unit ON dues_payment (unit_id);")
    op.execute("CREATE INDEX ix_payment_assessment ON dues_payment (assessment_id);")
    # donem bazli rapor filtresi (assessment'taki ix_assessment_donem ile ayni desen):
    op.execute("CREATE INDEX ix_payment_donem ON dues_payment (tenant_id, donem);")
    # provider_ref GLOBAL benzersiz (webhook tenant'i bundan cozer; RLS-bagimsiz lookup):
    op.execute(
        "CREATE UNIQUE INDEX uq_payment_provider_ref "
        "ON dues_payment (provider, provider_ref) WHERE provider_ref IS NOT NULL;"
    )

    # ------------------------------------------------------------------ #
    # 9l. payment_webhook_event  (saglayici webhook idempotency/denetim)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE payment_webhook_event (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            provider      text NOT NULL,
            event_id      text NOT NULL,
            provider_ref  text NOT NULL,
            created_at    timestamptz NOT NULL DEFAULT now(),
            -- ayni webhook olayi bir kez islensin (idempotency):
            CONSTRAINT uq_webhook_event UNIQUE (tenant_id, provider, event_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_webhook_event_tenant ON payment_webhook_event (tenant_id);")

    # Webhook RLS bootstrap: webhook token TASIMAZ; tenant'i provider_ref'ten
    # owner-sahipli SECURITY DEFINER fonksiyonla cozer (login slug deseni gibi).
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.payment_tenant_by_ref(p_provider text, p_provider_ref text)
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = ''
        AS $$
            SELECT tenant_id FROM public.dues_payment
            WHERE provider = p_provider AND provider_ref = p_provider_ref;
        $$;
        """
    )
    op.execute(
        "REVOKE ALL ON FUNCTION public.payment_tenant_by_ref(text, text) FROM PUBLIC;"
    )
    op.execute(
        f"GRANT EXECUTE ON FUNCTION public.payment_tenant_by_ref(text, text) TO {APP_ROLE};"
    )

    # ------------------------------------------------------------------ #
    # 9m. budget_category + budget_entry  (butce modulu — Wave 2A)
    #     Dinamik gelir/gider kategorileri + defter. Para INTEGER KURUS.
    #     Kategori silme = SOFT-DELETE (aktif=false): hareketi olan kategori
    #     hard-delete edilemez (ON DELETE RESTRICT) — gecmis kayitlar
    #     kategorisini korur.
    # ------------------------------------------------------------------ #
    op.execute("CREATE TYPE budget_tip AS ENUM ('gelir', 'gider');")
    # kaynak: manuel (elle girilen) | aidat_odeme (basarili aidat odemesinden
    # otomatik uretilen gelir kaydi — ilgili_payment_id ile baglanir).
    op.execute("CREATE TYPE budget_kaynak AS ENUM ('manuel', 'aidat_odeme');")
    op.execute(
        """
        CREATE TABLE budget_category (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad          text NOT NULL,
            tip         budget_tip NOT NULL,
            aktif       boolean NOT NULL DEFAULT true,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_budgetcat_id_tenant UNIQUE (id, tenant_id),
            -- ayni tip icinde ad tekrari yok (tenant-ici):
            CONSTRAINT uq_budgetcat_tenant_tip_ad UNIQUE (tenant_id, tip, ad)
        );
        """
    )
    op.execute("CREATE INDEX ix_budgetcat_tenant ON budget_category (tenant_id);")
    op.execute(
        """
        CREATE TABLE budget_entry (
            id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id          uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            kategori_id        uuid NOT NULL,
            -- tip kategoriden kopyalanir (denormalize): ozet toplamlari
            -- join'siz ve kategori tip'i sonradan degisse bile tutarli kalir.
            tip                budget_tip NOT NULL,
            tutar_kurus        integer NOT NULL,     -- KURUS; float ASLA
            tarih              date NOT NULL,
            aciklama           text,
            kaynak             budget_kaynak NOT NULL DEFAULT 'manuel',
            -- otomatik aidat kaydinin kaynagi; odeme silinirse kayit kalir (SET NULL).
            ilgili_payment_id  uuid,
            created_by         uuid NOT NULL,
            created_at         timestamptz NOT NULL DEFAULT now(),
            updated_at         timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT ck_budget_entry_tutar CHECK (tutar_kurus > 0),
            CONSTRAINT uq_budget_entry_id_tenant UNIQUE (id, tenant_id),
            -- hareketi olan kategori silinemez (soft-delete'e zorlar):
            CONSTRAINT fk_budget_entry_kategori
                FOREIGN KEY (kategori_id, tenant_id)
                REFERENCES budget_category (id, tenant_id) ON DELETE RESTRICT,
            CONSTRAINT fk_budget_entry_payment
                FOREIGN KEY (ilgili_payment_id, tenant_id)
                REFERENCES dues_payment (id, tenant_id) ON DELETE SET NULL (ilgili_payment_id),
            CONSTRAINT fk_budget_entry_created_by
                FOREIGN KEY (created_by, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- IDEMPOTENCY: ayni odemeden IKINCI gelir kaydi uretilmez.
            CONSTRAINT uq_budget_entry_payment UNIQUE (tenant_id, ilgili_payment_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_budget_entry_tenant ON budget_entry (tenant_id);")
    op.execute("CREATE INDEX ix_budget_entry_tarih ON budget_entry (tenant_id, tarih);")
    op.execute("CREATE INDEX ix_budget_entry_tip ON budget_entry (tenant_id, tip);")
    op.execute("CREATE INDEX ix_budget_entry_kategori ON budget_entry (kategori_id);")

    # ------------------------------------------------------------------ #
    # 9z. user_device  (FCM push token kaydi — kullanici basina cihaz(lar))
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE user_device (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            user_id     uuid NOT NULL,
            fcm_token   text NOT NULL,
            platform    device_platform NOT NULL,
            aktif       boolean NOT NULL DEFAULT true,
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            -- composite FK: cihaz sahibi ayni tenant'ta olmali (RLS ile tutarli).
            CONSTRAINT fk_user_device_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE,
            -- Ayni token tenant icinde TEK kayit (idempotent upsert anahtari).
            CONSTRAINT uq_user_device_tenant_token UNIQUE (tenant_id, fcm_token)
        );
        """
    )
    op.execute("CREATE INDEX ix_user_device_tenant ON user_device (tenant_id);")
    op.execute(
        "CREATE INDEX ix_user_device_user ON user_device (tenant_id, user_id, aktif);"
    )

    # ------------------------------------------------------------------ #
    # 9y. announcement  (duyuru — yonetimden tum tesise; auth.md §4:
    #     gonderme admin+yonetici, okuma TUM roller)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE announcement (
            id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id          uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            baslik             text NOT NULL,
            govde              text NOT NULL,
            foto_key           text,       -- opsiyonel gorsel (MinIO obje anahtari)
            olusturan_user_id  uuid NOT NULL,
            created_at         timestamptz NOT NULL DEFAULT now(),
            updated_at         timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_announcement_id_tenant UNIQUE (id, tenant_id),
            -- composite FK: duyuru sahibi ayni tenant'ta olmali (RLS ile tutarli).
            CONSTRAINT fk_announcement_olusturan
                FOREIGN KEY (olusturan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT
        );
        """
    )
    op.execute("CREATE INDEX ix_announcement_tenant ON announcement (tenant_id);")
    op.execute(
        "CREATE INDEX ix_announcement_tenant_created "
        "ON announcement (tenant_id, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9z. complaint  (sikayet/oneri — sakin -> yonetim talep kanali;
    #     auth.md §4: resident acar + KENDI kayitlarini okur,
    #     admin+yonetici tumunu okur + durum/yanit yazar,
    #     security/tesis_gorevlisi ERISMEZ)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE complaint (
            id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id            uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            acan_user_id         uuid NOT NULL,
            baslik               text NOT NULL,
            mesaj                text NOT NULL,
            foto_key             text,       -- opsiyonel gorsel (MinIO obje anahtari)
            kategori             complaint_kategori,  -- opsiyonel tur (NULL = belirtilmemis)
            durum                complaint_durum NOT NULL DEFAULT 'acik',
            yonetici_yaniti      text,
            yanitlayan_user_id   uuid,
            yanit_zamani         timestamptz,
            created_at           timestamptz NOT NULL DEFAULT now(),
            updated_at           timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_complaint_id_tenant UNIQUE (id, tenant_id),
            -- composite FK: acan sakin ayni tenant'ta olmali (RLS ile tutarli).
            CONSTRAINT fk_complaint_acan
                FOREIGN KEY (acan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- Kolon-ozel SET NULL: yalnizca yanitlayan_user_id NULL'lanir.
            CONSTRAINT fk_complaint_yanitlayan
                FOREIGN KEY (yanitlayan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (yanitlayan_user_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_complaint_tenant ON complaint (tenant_id);")
    op.execute(
        "CREATE INDEX ix_complaint_tenant_durum ON complaint (tenant_id, durum);"
    )
    op.execute(
        "CREATE INDEX ix_complaint_tenant_kategori "
        "ON complaint (tenant_id, kategori);"
    )
    op.execute(
        "CREATE INDEX ix_complaint_tenant_acan ON complaint (tenant_id, acan_user_id);"
    )
    op.execute(
        "CREATE INDEX ix_complaint_tenant_created "
        "ON complaint (tenant_id, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9z2. visitor  (ziyaretci LOG kaydi — guvenlik kaydeder + dairenin TEK
    #     hedef sakinine BILGILENDIRME push'u gider; onay/red YOKTUR. Kayit bir
    #     gunluk (log) girisidir; tam gecmis bu tabloda tutulur.
    #
    #     GSM'E HAZIR (ileride Twilio/Netgsm ile gercek arama): hedef sakinin
    #     telefonu zaten app_user.telefon'da; arama adimi ayri kolon/tablo ile
    #     eklenebilir (composite FK hedefi uq_visitor_id_tenant hazir) — bu
    #     tabloda yeniden tasarim gerekmez.)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE visitor (
            id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id            uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            unit_id              uuid NOT NULL,
            ziyaretci_ad         text NOT NULL,
            notlar               text,       -- opsiyonel not ("not" SQL anahtar sozcugu; emergency/asset deseni)
            kaydeden_user_id     uuid NOT NULL,   -- kaydi acan guvenlik
            target_resident_user_id uuid NOT NULL, -- guvenligin sectigi TEK sakin: bilgilendirme push'u + gorunurluk YALNIZ onda
            created_at           timestamptz NOT NULL DEFAULT now(),
            -- composite FK hedefi (ileride arama/meta tablolari icin de hazir).
            CONSTRAINT uq_visitor_id_tenant UNIQUE (id, tenant_id),
            -- composite FK: daire ayni tenant'ta olmali (RLS ile tutarli).
            CONSTRAINT fk_visitor_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_visitor_kaydeden
                FOREIGN KEY (kaydeden_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- Hedef sakin: bilgilendirme/gorunurluk sahibi; silinemez (RESTRICT).
            CONSTRAINT fk_visitor_target
                FOREIGN KEY (target_resident_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT
        );
        """
    )
    op.execute("CREATE INDEX ix_visitor_tenant ON visitor (tenant_id);")
    op.execute("CREATE INDEX ix_visitor_tenant_unit ON visitor (tenant_id, unit_id);")
    op.execute(
        "CREATE INDEX ix_visitor_tenant_target "
        "ON visitor (tenant_id, target_resident_user_id);"
    )
    op.execute(
        "CREATE INDEX ix_visitor_tenant_created ON visitor (tenant_id, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9z3. kargo  (kargo/paket takibi — guvenlik gelen paketi kaydeder
    #     (daire + firma + opsiyonel foto/not), dairenin TUM aktif sakinlerine
    #     push gider, sakin "teslim aldim" isaretler; tam gecmis bu tabloda.
    #     visitor ile ayni RBAC/izolasyon deseni; akis onay degil TESLIM.)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE kargo (
            id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id            uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            unit_id              uuid NOT NULL,
            firma                text NOT NULL,   -- kargo firmasi/tasiyici
            foto_key             text,       -- opsiyonel paket fotografi (MinIO obje anahtari, presign akisi)
            notlar               text,       -- opsiyonel not ("not" SQL anahtar sozcugu; visitor/emergency deseni)
            durum                kargo_durum NOT NULL DEFAULT 'bekliyor',
            kaydeden_user_id     uuid NOT NULL,   -- kaydi acan guvenlik
            teslim_alan_user_id  uuid,            -- teslim alan sakin
            teslim_zamani        timestamptz,
            created_at           timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_kargo_id_tenant UNIQUE (id, tenant_id),
            -- composite FK: daire ayni tenant'ta olmali (RLS ile tutarli).
            CONSTRAINT fk_kargo_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_kargo_kaydeden
                FOREIGN KEY (kaydeden_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- Kolon-ozel SET NULL: yalnizca teslim_alan_user_id NULL'lanir.
            CONSTRAINT fk_kargo_teslim_alan
                FOREIGN KEY (teslim_alan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (teslim_alan_user_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_kargo_tenant ON kargo (tenant_id);")
    op.execute("CREATE INDEX ix_kargo_tenant_unit ON kargo (tenant_id, unit_id);")
    op.execute("CREATE INDEX ix_kargo_tenant_durum ON kargo (tenant_id, durum);")
    op.execute(
        "CREATE INDEX ix_kargo_tenant_created ON kargo (tenant_id, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9z3b. unit_access_permission  (yonetici TEK-SEFERLIK ziyaretci/paket
    #     goruntuleme izni). Gizlilik: ziyaretci/kargo VARSAYILAN olarak
    #     yonetici'ye KAPALI (yonetici gecmisi goremez). Yonetici bir daireye
    #     izin TALEBI acar -> dairenin sakini onaylar/reddeder. Onay = TEK
    #     KULLANIMLIK izin (used=false); yonetici o dairenin kayitlarini ILK
    #     okudugunda tuketilir (used=true). Sureye bagli DEGIL (one-shot);
    #     tekrar gormek yeni talep gerektirir. durum tek satirda talep+izin
    #     yasam dongusunu tutar.
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE unit_access_permission (
            id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id                   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            unit_id                     uuid NOT NULL,
            granted_to_yonetici_user_id uuid NOT NULL,  -- talebi acan yonetici (izin ona verilir)
            granted_by_resident_user_id uuid,           -- karari veren sakin (karara kadar NULL)
            durum                       access_request_durum NOT NULL DEFAULT 'bekliyor',
            used                        boolean NOT NULL DEFAULT false,  -- ilk okumada true (one-shot)
            requested_at                timestamptz NOT NULL DEFAULT now(),
            decided_at                  timestamptz,
            used_at                     timestamptz,
            created_at                  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_uap_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT fk_uap_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_uap_yonetici
                FOREIGN KEY (granted_to_yonetici_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- Kolon-ozel SET NULL: yalnizca granted_by_resident_user_id NULL'lanir.
            CONSTRAINT fk_uap_resident
                FOREIGN KEY (granted_by_resident_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id)
                ON DELETE SET NULL (granted_by_resident_user_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_uap_tenant ON unit_access_permission (tenant_id);"
    )
    op.execute(
        "CREATE INDEX ix_uap_tenant_unit "
        "ON unit_access_permission (tenant_id, unit_id);"
    )
    # Izin dogrulama sorgusu: (tenant, unit, yonetici, durum, used) — gecerli
    # kullanilmamis onay hizli bulunur.
    op.execute(
        "CREATE INDEX ix_uap_lookup ON unit_access_permission "
        "(tenant_id, unit_id, granted_to_yonetici_user_id, durum, used);"
    )
    op.execute(
        "CREATE INDEX ix_uap_tenant_created "
        "ON unit_access_permission (tenant_id, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9z4. ortak_alan  (rezerve edilebilir ortak alan: havuz/teras/toplanti
    #     odasi — yonetici tanimlar; silme = SOFT-DELETE (aktif=false):
    #     rezervasyon gecmisi alanini korur, FK RESTRICT hard-delete engeller)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE ortak_alan (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad          text NOT NULL,
            aciklama    text,
            aktif       boolean NOT NULL DEFAULT true,
            created_at  timestamptz NOT NULL DEFAULT now(),
            -- composite FK hedefi (rezervasyon.alan_id).
            CONSTRAINT uq_ortak_alan_id_tenant UNIQUE (id, tenant_id),
            -- ayni tenant'ta ayni adla iki alan olmasin (yanlis secim onlenir).
            CONSTRAINT uq_ortak_alan_tenant_ad UNIQUE (tenant_id, ad)
        );
        """
    )
    op.execute("CREATE INDEX ix_ortak_alan_tenant ON ortak_alan (tenant_id);")

    # ------------------------------------------------------------------ #
    # 9z5. rezervasyon  (ortak alan rezervasyonu: sakin talep eder ->
    #     yonetici onaylar/reddeder; tam gecmis bu tabloda.
    #
    #     CAKISMA ENGELI (DB-duzeyi, yaris-durumu-guvenli): partial EXCLUDE
    #     constraint — ayni alanin ONAYLI iki rezervasyonu zaman araliginda
    #     kesisemez. tsrange '[)' oldugu icin bitis == diger.baslangic (bitisik
    #     slot) CAKISMA SAYILMAZ. bekliyor/reddedildi satirlar kisita dahil
    #     DEGIL (WHERE durum='onaylandi') => ust uste birden cok BEKLEYEN
    #     talep serbest; onaya kaldirma aninda (UPDATE) kisit devreye girer,
    #     es zamanli iki cakisan onaydan YALNIZ BIRI basarir (digerine 23P01
    #     -> API 409). uuid '=' gist icin btree_gist eklentisi gerekli.
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE rezervasyon (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id           uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            alan_id             uuid NOT NULL,
            unit_id             uuid NOT NULL,   -- talep eden daire
            talep_eden_user_id  uuid NOT NULL,   -- talebi acan sakin
            tarih               date NOT NULL,
            baslangic           time NOT NULL,
            bitis               time NOT NULL,
            kisi_sayisi         integer NOT NULL,
            notlar              text,       -- opsiyonel not ("not" SQL anahtar sozcugu)
            durum               rezervasyon_durum NOT NULL DEFAULT 'bekliyor',
            onaylayan_user_id   uuid,            -- karari veren yonetici
            karar_zamani        timestamptz,
            created_at          timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_rezervasyon_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_rezervasyon_aralik CHECK (bitis > baslangic),
            CONSTRAINT ck_rezervasyon_kisi CHECK (kisi_sayisi > 0),
            -- RESTRICT: rezervasyon gecmisi olan alan hard-delete edilemez
            -- (alan kaldirma = aktif=false).
            CONSTRAINT fk_rezervasyon_alan
                FOREIGN KEY (alan_id, tenant_id)
                REFERENCES ortak_alan (id, tenant_id) ON DELETE RESTRICT,
            CONSTRAINT fk_rezervasyon_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_rezervasyon_talep_eden
                FOREIGN KEY (talep_eden_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            -- Kolon-ozel SET NULL: yalnizca onaylayan_user_id NULL'lanir.
            CONSTRAINT fk_rezervasyon_onaylayan
                FOREIGN KEY (onaylayan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE SET NULL (onaylayan_user_id),
            -- Ayni alanin ONAYLI rezervasyonlari kesisemez (tarih+saat).
            CONSTRAINT ex_rezervasyon_onayli_cakisma
                EXCLUDE USING gist (
                    alan_id WITH =,
                    tsrange((tarih + baslangic)::timestamp,
                            (tarih + bitis)::timestamp) WITH &&
                ) WHERE (durum = 'onaylandi')
        );
        """
    )
    op.execute("CREATE INDEX ix_rezervasyon_tenant ON rezervasyon (tenant_id);")
    op.execute(
        "CREATE INDEX ix_rezervasyon_tenant_alan ON rezervasyon (tenant_id, alan_id);"
    )
    op.execute(
        "CREATE INDEX ix_rezervasyon_tenant_durum ON rezervasyon (tenant_id, durum);"
    )
    op.execute(
        "CREATE INDEX ix_rezervasyon_tenant_tarih ON rezervasyon (tenant_id, tarih);"
    )
    op.execute(
        "CREATE INDEX ix_rezervasyon_tenant_created "
        "ON rezervasyon (tenant_id, created_at DESC);"
    )

    # ------------------------------------------------------------------ #
    # 9z6. etkinlik + etkinlik_katilim  (etkinlik + RSVP: yonetici etkinlik
    #     olusturur (cenaze/mac izleme vb.) -> tum sakinlere push -> sakin
    #     katiliyorum/katilmiyorum beyan eder (degistirilebilir; kullanici
    #     basina TEK kayit — UNIQUE + upsert). SAYILAR SEFFAF: katilim
    #     sayisini herkes gorur; kim-katiliyor listesi URUN GEREGI YOK —
    #     kimlik degil, yalniz sayi paylasilir.)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE etkinlik (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id           uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            baslik              text NOT NULL,
            aciklama            text NOT NULL,
            tarih               timestamptz NOT NULL,   -- etkinlik zamani
            konum               text,                   -- opsiyonel yer bilgisi
            olusturan_user_id   uuid NOT NULL,
            created_at          timestamptz NOT NULL DEFAULT now(),
            updated_at          timestamptz NOT NULL DEFAULT now(),
            -- composite FK hedefi (etkinlik_katilim.etkinlik_id).
            CONSTRAINT uq_etkinlik_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT fk_etkinlik_olusturan
                FOREIGN KEY (olusturan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT
        );
        """
    )
    op.execute("CREATE INDEX ix_etkinlik_tenant ON etkinlik (tenant_id);")
    op.execute(
        "CREATE INDEX ix_etkinlik_tenant_tarih ON etkinlik (tenant_id, tarih DESC);"
    )

    op.execute(
        """
        CREATE TABLE etkinlik_katilim (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            etkinlik_id   uuid NOT NULL,
            user_id       uuid NOT NULL,
            durum         katilim_durum NOT NULL,
            created_at    timestamptz NOT NULL DEFAULT now(),
            updated_at    timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_katilim_etkinlik
                FOREIGN KEY (etkinlik_id, tenant_id)
                REFERENCES etkinlik (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_katilim_user
                FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE,
            -- kullanici basina TEK RSVP (degisiklik = upsert; cift kayit yok).
            CONSTRAINT uq_katilim_tenant_etkinlik_user
                UNIQUE (tenant_id, etkinlik_id, user_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_katilim_tenant ON etkinlik_katilim (tenant_id);")
    op.execute(
        "CREATE INDEX ix_katilim_etkinlik "
        "ON etkinlik_katilim (tenant_id, etkinlik_id, durum);"
    )

    # ------------------------------------------------------------------ #
    # 9z7. site_kurali  (site kurallari — blog-tarzi icerik: yonetici
    #     ekler/duzenler/siler, TUM roller okur; sira ile siralanir, baslikta
    #     ILIKE arama. Silme = HARD DELETE (karar): salt icerik — operasyonel
    #     gecmis/FK tasimaz, soft-delete karmasasi gereksiz.)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE site_kurali (
            id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id           uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            baslik              text NOT NULL,
            icerik              text NOT NULL,
            foto_key            text,       -- opsiyonel gorsel (MinIO obje anahtari, presign akisi)
            sira                integer NOT NULL DEFAULT 0,  -- liste sirasi (kucuk once)
            olusturan_user_id   uuid NOT NULL,
            created_at          timestamptz NOT NULL DEFAULT now(),
            updated_at          timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_site_kurali_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_site_kurali_sira CHECK (sira >= 0),
            CONSTRAINT fk_site_kurali_olusturan
                FOREIGN KEY (olusturan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT
        );
        """
    )
    op.execute("CREATE INDEX ix_site_kurali_tenant ON site_kurali (tenant_id);")
    op.execute(
        "CREATE INDEX ix_site_kurali_tenant_sira ON site_kurali (tenant_id, sira);"
    )

    # ------------------------------------------------------------------ #
    # 9z9. integration  (C1b — dis sistem entegrasyon konfigurasyonu:
    #     admin/yonetici bir dis ucu (megafon/akilli-ev/generic webhook)
    #     tanimlar; tetiklenince SSRF-korumali HTTP istegi gonderilir.
    #     auth_secret KEK ile sifreli saklanir; GET'te ASLA donmez (write-only).
    #     tenant izole (RLS). channel_type C1a kanal soyutlamasini genisletir.)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE integration (
            id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad               text NOT NULL,
            channel_type     integration_channel NOT NULL DEFAULT 'webhook',
            endpoint_url     text NOT NULL,       -- YALNIZ public http(s); SSRF kapisi tetikte
            http_method      text NOT NULL DEFAULT 'POST',
            headers_json     jsonb NOT NULL DEFAULT '{}'::jsonb,  -- gizli OLMAYAN ek header'lar
            auth_type        text NOT NULL DEFAULT 'none',        -- none | bearer | api_key
            auth_secret_enc  text,                -- KEK ile sifreli; GET'te donmez (write-only)
            payload_template text NOT NULL DEFAULT '',            -- {{message}}/{{title}} placeholder
            aktif            boolean NOT NULL DEFAULT true,
            created_at       timestamptz NOT NULL DEFAULT now(),
            updated_at       timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_integration_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT ck_integration_method
                CHECK (http_method IN ('GET', 'POST', 'PUT', 'PATCH')),
            CONSTRAINT ck_integration_auth
                CHECK (auth_type IN ('none', 'bearer', 'api_key'))
        );
        """
    )
    op.execute("CREATE INDEX ix_integration_tenant ON integration (tenant_id);")
    op.execute(
        "CREATE INDEX ix_integration_tenant_aktif ON integration (tenant_id, aktif);"
    )

    # ------------------------------------------------------------------ #
    # 9z10. unit_complaint  (D1 — sakin -> HEDEF DAIRE sikayeti; yonetime
    #     degil, daireye. TAM ANONIM: complainant_user_id YALNIZ ic spam
    #     korumasi icin saklanir, HICBIR uctan/serializer'dan donmez. Yonetici/
    #     admin dahil kimse SIKAYET EDENI goremez — herkes yalniz daire-basi
    #     sayilari + renk gorur. Yonetimin var olan 'complaint' modulunden
    #     AYRIDIR. tenant izole (RLS).)
    # ------------------------------------------------------------------ #
    op.execute(
        """
        CREATE TABLE unit_complaint (
            id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id             uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            target_unit_id        uuid NOT NULL,
            -- IC ALAN: yalniz spam korumasi + RLS; ASLA serialize edilmez.
            complainant_user_id   uuid NOT NULL,
            kategori              unit_complaint_kategori NOT NULL DEFAULT 'diger',
            notlar                text,
            durum                 unit_complaint_durum NOT NULL DEFAULT 'acik',
            created_at            timestamptz NOT NULL DEFAULT now(),
            updated_at            timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_unit_complaint_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT fk_unit_complaint_target
                FOREIGN KEY (target_unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_unit_complaint_complainant
                FOREIGN KEY (complainant_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_unit_complaint_tenant ON unit_complaint (tenant_id);"
    )
    # Yogunluk/renk sorgusu: (tenant, hedef daire, durum) — ACIK sayimi hizli.
    op.execute(
        "CREATE INDEX ix_unit_complaint_target "
        "ON unit_complaint (tenant_id, target_unit_id, durum);"
    )
    # SPAM KORUMASI (DB-zorlamali, yarissiz): ayni sikayetci ayni hedef daireye
    # AYNI ANDA yalniz BIR ACIK sikayet acabilir. Kapatilinca yeniden acilabilir.
    op.execute(
        "CREATE UNIQUE INDEX uq_unit_complaint_open "
        "ON unit_complaint (tenant_id, target_unit_id, complainant_user_id) "
        "WHERE durum = 'acik';"
    )

    # ------------------------------------------------------------------ #
    # 10. Row-Level Security
    # ------------------------------------------------------------------ #
    # Politika: satir, oturumdaki app.current_tenant_id ile eslesirse gorunur.
    # current_setting(..., true) => degisken set degilse NULL doner (hata atmaz),
    # NULL karsilastirmasi false uretir => hicbir satir gorunmez (guvenli varsayilan).
    _enable_rls_tenant_table()
    for table in (
        "app_user",
        "shift",
        "checkpoint",
        "patrol_plan",
        "patrol_plan_checkpoint",
        "patrol_window",
        "scan_event",
        "notification",
        "task_category",
        "task",
        "task_completion",
        "asset",
        "asset_checkout",
        "emergency_alert",
        "unit",
        "unit_resident",
        "dues_assessment",
        "dues_payment",
        "payment_webhook_event",
        "budget_category",
        "budget_entry",
        "user_device",
        "announcement",
        "complaint",
        "visitor",
        "kargo",
        "unit_access_permission",
        "ortak_alan",
        "rezervasyon",
        "etkinlik",
        "etkinlik_katilim",
        "site_kurali",
        "integration",
        "unit_complaint",
    ):
        _enable_rls(table)

    # Backend rolune tablo ayricaliklari:
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO {APP_ROLE};"
    )


def _enable_rls_tenant_table() -> None:
    # tenant tablosunda tenant_id yok; izolasyon id uzerinden.
    op.execute("ALTER TABLE tenant ENABLE ROW LEVEL SECURITY;")
    op.execute("ALTER TABLE tenant FORCE ROW LEVEL SECURITY;")
    op.execute(
        f"""
        CREATE POLICY tenant_isolation ON tenant
            USING (id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )


def _enable_rls(table: str) -> None:
    op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;")
    op.execute(f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY;")
    op.execute(
        f"""
        CREATE POLICY {table}_isolation ON {table}
            USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
            WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
        """
    )


def downgrade() -> None:
    op.execute("DROP FUNCTION IF EXISTS public.tenant_id_by_slug(text);")
    op.execute("DROP FUNCTION IF EXISTS public.payment_tenant_by_ref(text, text);")
    for table in (
        "unit_complaint",
        "integration",
        "site_kurali",
        "etkinlik_katilim",
        "etkinlik",
        "rezervasyon",
        "ortak_alan",
        "unit_access_permission",
        "kargo",
        "visitor",
        "complaint",
        "announcement",
        "user_device",
        "budget_entry",
        "budget_category",
        "payment_webhook_event",
        "dues_payment",
        "dues_assessment",
        "unit_resident",
        "unit",
        "emergency_alert",
        "asset_checkout",
        "asset",
        "task_completion",
        "task",
        "task_category",
        "notification",
        "scan_event",
        "patrol_window",
        "patrol_plan_checkpoint",
        "patrol_plan",
        "checkpoint",
        "shift",
        "app_user",
        "tenant",
    ):
        op.execute(f"DROP TABLE IF EXISTS {table} CASCADE;")

    op.execute("DROP TYPE IF EXISTS unit_complaint_durum;")
    op.execute("DROP TYPE IF EXISTS unit_complaint_kategori;")
    op.execute("DROP TYPE IF EXISTS integration_channel;")
    op.execute("DROP TYPE IF EXISTS katilim_durum;")
    op.execute("DROP TYPE IF EXISTS rezervasyon_durum;")
    op.execute("DROP TYPE IF EXISTS access_request_durum;")
    op.execute("DROP TYPE IF EXISTS kargo_durum;")
    # (visitor_durum kaldirildi — ziyaretci artik LOG-ONLY, enum yok.)
    op.execute("DROP TYPE IF EXISTS device_platform;")
    op.execute("DROP TYPE IF EXISTS budget_kaynak;")
    op.execute("DROP TYPE IF EXISTS budget_tip;")
    op.execute("DROP TYPE IF EXISTS dues_durum;")
    op.execute("DROP TYPE IF EXISTS dues_yontem;")
    op.execute("DROP TYPE IF EXISTS resident_rol;")
    op.execute("DROP TYPE IF EXISTS emergency_durum;")
    op.execute("DROP TYPE IF EXISTS complaint_durum;")
    op.execute("DROP TYPE IF EXISTS complaint_kategori;")
    op.execute("DROP TYPE IF EXISTS asset_durum;")
    op.execute("DROP TYPE IF EXISTS asset_kategori;")
    op.execute("DROP TYPE IF EXISTS task_tip;")
    op.execute("DROP TYPE IF EXISTS notification_tip;")
    op.execute("DROP TYPE IF EXISTS patrol_window_durum;")
    op.execute("DROP TYPE IF EXISTS gun_tipi;")
    op.execute("DROP TYPE IF EXISTS user_role;")
    # app_rw rolu ve pgcrypto eklentisi paylasimli olabilecegi icin birakilir.
