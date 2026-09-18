"""(P240 §3) AKILLI EV — kopru, cihaz, bolum anahtarlari, senaryolar.

===========================================================================
MIMARI KARAR: MATTER/ZIGBEE/Z-WAVE'E DOGRUDAN BAGLANMIYORUZ
===========================================================================
Istekte bes protokol geciyor: Matter, Zigbee, Z-Wave, MQTT, Home
Assistant. Ilk ucu RADYO protokolleridir: Zigbee ve Z-Wave kendi
frekanslarinda (2.4 GHz / 868 MHz) konusur ve bir USB ANTEN ister;
Matter ise Thread/Wi-Fi uzerinde calisir ve komisyonlama (pairing)
sertifika zinciri gerektirir. Bir SUNUCU uygulamasinin bunlara
DOGRUDAN baglanmasi fiziksel olarak mumkun degildir — radyo sitededir,
sunucu veri merkezinde.

Sektorun cozumu KOPRUDUR: sitede bir hub (Home Assistant, Zigbee2MQTT,
Homey, SmartThings) radyoyu dinler ve HTTP/MQTT konusur. Bu yuzden
`akilli_ev_kopru.tur` uc deger tasir:

  * `home_assistant` — REST API (HTTP+JSON). BU TURDA UYGULANDI.
  * `mqtt`           — broker abonesi. BU TURDA UYGULANMADI (docs §3).
  * `http`           — genel webhook/role (kendi kapisi olan cihazlar).

Yani "Zigbee destegi" bir kutu isaretleme meselesi degil: Zigbee cihaz
kopru araciligiyla GORUNUR ve komut ALIR. Bunu semada `zigbee` diye bir
tur acarak gizlemek, olmayan bir dogrudan baglantiyi vaat etmek olurdu.

===========================================================================
BOLUM ANAHTARLARI: DOKUZ BOLUM, HER BIRI AYRI
===========================================================================
Istegin kurali: "Site yalniz sayac kullaniyorsa digerleri gorunmesin."
Anahtarlar TENANT BASINADIR ve bir satir bir bolumun acik/kapali
halidir. Tek bir JSONB alan yerine satir-basina-bolum secildi: yeni bir
bolum eklendiginde eski tenant'larin JSONB'sini GOCLE guncellemek
gerekmez, varsayilan KAPALI olur (yokluk = kapali).

===========================================================================
SENARYOLAR: EYLEM KODDA SABIT DEGIL
===========================================================================
Istegin acik maddesi: "Hangi eylemin hangi senaryoda tetiklenecegi
YAPILANDIRILABILIR olsun, kodda sabit olmasin."

`akilli_ev_senaryo` bir OLAY (panik tipi, su kacagi, yangin...) ile bir
CIHAZ + EYLEM eslestirir. Panik tetiklenince kod "isiklari yak" demez;
"bu olaya bagli senaryolari calistir" der. Bir tesis kapiyi acmak
isterken otekinin acmamasi tamamen bir VERI farkidir.

===========================================================================
CIHAZ SAHIPLIGI: DAIRE mi ORTAK ALAN mi
===========================================================================
`unit_id` NULL ise cihaz ORTAK ALANDADIR. Bu ayrim bir GUVENLIK
SINIRIDIR: sakin YALNIZ kendi dairesinin cihazlarini gorur ve komut
verir (sunucuda zorlanir, IDOR testi var). Ortak alan cihazlari yalniz
yonetim/guvenlik icindir.
"""
from alembic import op

APP_ROLE = "app_rw"

revision = "0143_akilli_ev"
down_revision = "0142_diyafon"
branch_labels = None
depends_on = None

#: Dokuz bolum — istegin basliklari.
BOLUMLER = (
    "protokol",      # 1. Protokoller ve baglanti
    "panik",         # 2. Panik / acil durum
    "ziyaretci",     # 3. Ziyaretci bildirimi
    "kacak",         # 4. Su ve gaz kacagi
    "enerji",        # 5. Enerji ve sayac
    "ortak_alan",    # 6. Ortak alan kontrolu
    "isitma",        # 7. Isitma sistemi
    "kapi",          # 8. Kapi ve turnike
    "yangin",        # 9. Yangin ve duman
)


def upgrade() -> None:
    op.execute(
        "CREATE TYPE akilli_ev_kopru_tur AS ENUM "
        "('home_assistant', 'mqtt', 'http');"
    )
    op.execute(
        "CREATE TYPE akilli_ev_cihaz_tip AS ENUM ("
        "'isik', 'kilit', 'vana', 'termostat', 'sayac', 'role', "
        "'sensor_su', 'sensor_gaz', 'sensor_duman', 'sensor_hareket', "
        "'asansor', 'sulama');"
    )
    op.execute(
        "CREATE TYPE akilli_ev_bolum AS ENUM ("
        + ", ".join(f"'{b}'" for b in BOLUMLER)
        + ");"
    )
    op.execute(
        "CREATE TYPE akilli_ev_olay AS ENUM ("
        "'panik_sakin', 'panik_guvenlik', 'panik_anons', "
        "'su_kacagi', 'gaz_kacagi', 'yangin');"
    )

    # --------------------------- KOPRU --------------------------------- #
    op.execute(
        """
        CREATE TABLE akilli_ev_kopru (
            id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id      uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad             text NOT NULL,
            tur            akilli_ev_kopru_tur NOT NULL,
            host           text NOT NULL,
            port           integer,
            -- KEK ile sifreli erisim jetonu (HA uzun-omurlu token).
            token_enc      text,
            aktif          boolean NOT NULL DEFAULT true,
            -- OLAY JETONU: cihazlarin bize olay GONDERMESI icin
            -- (`POST /akilli-ev/olay`). Hub'in kimligini dogrular; ayni
            -- jetonla baska bir tesise olay yazilamaz.
            olay_jetonu_hash text,
            saglik              entegrasyon_saglik NOT NULL DEFAULT 'bilinmiyor',
            son_kontrol_at      timestamptz,
            son_basarili_at     timestamptz,
            son_hata_kod        text,
            son_hata_ayrinti    text,
            kopus_bildirildi_at timestamptz,
            created_at     timestamptz NOT NULL DEFAULT now(),
            updated_at     timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            CONSTRAINT ck_akilli_kopru_port CHECK (
                port IS NULL OR (port BETWEEN 1 AND 65535)
            )
        );
        """
    )
    op.execute("CREATE INDEX ix_akilli_kopru_tenant ON akilli_ev_kopru (tenant_id);")

    # --------------------------- CIHAZ --------------------------------- #
    op.execute(
        """
        CREATE TABLE akilli_ev_cihaz (
            id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            kopru_id     uuid NOT NULL,
            ad           text NOT NULL,
            tip          akilli_ev_cihaz_tip NOT NULL,
            -- DAIRE mi ORTAK ALAN mi: NULL = ortak alan. GUVENLIK SINIRI.
            unit_id      uuid,
            -- Ortak alanin adi ("Kazan dairesi", "B blok otopark").
            alan         text,
            -- Hub'daki kimlik (HA `entity_id`, MQTT konu adi...).
            dis_kimlik   text NOT NULL,
            -- Son bilinen durum — hub'dan gelen ham JSON.
            son_durum    jsonb,
            son_veri_at  timestamptz,
            aktif        boolean NOT NULL DEFAULT true,
            created_at   timestamptz NOT NULL DEFAULT now(),
            updated_at   timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            -- AYNI HUB'DA AYNI KIMLIK IKI KEZ TANIMLANAMAZ: ayni cihazi
            -- iki kez eklemek, komutu iki kez gondermek ve durumu iki
            -- satirda ayri tutmak demekti.
            UNIQUE (kopru_id, dis_kimlik),
            CONSTRAINT fk_akilli_cihaz_kopru
                FOREIGN KEY (kopru_id, tenant_id)
                REFERENCES akilli_ev_kopru (id, tenant_id) ON DELETE CASCADE,
            CONSTRAINT fk_akilli_cihaz_unit
                FOREIGN KEY (unit_id, tenant_id)
                REFERENCES unit (id, tenant_id) ON DELETE SET NULL (unit_id)
        );
        """
    )
    op.execute("CREATE INDEX ix_akilli_cihaz_tenant ON akilli_ev_cihaz (tenant_id);")
    op.execute("CREATE INDEX ix_akilli_cihaz_kopru ON akilli_ev_cihaz (kopru_id);")
    # DAIRE SUZGECI EN SIK SORGUDUR: sakin her acilista kendi
    # dairesinin cihazlarini ister.
    op.execute(
        "CREATE INDEX ix_akilli_cihaz_unit ON akilli_ev_cihaz (tenant_id, unit_id);"
    )

    # ------------------------ BOLUM ANAHTARI ---------------------------- #
    op.execute(
        """
        CREATE TABLE akilli_ev_bolum_ayari (
            tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            bolum      akilli_ev_bolum NOT NULL,
            acik       boolean NOT NULL DEFAULT false,
            updated_at timestamptz NOT NULL DEFAULT now(),
            PRIMARY KEY (tenant_id, bolum)
        );
        """
    )

    # --------------------------- SENARYO -------------------------------- #
    op.execute(
        """
        CREATE TABLE akilli_ev_senaryo (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            olay       akilli_ev_olay NOT NULL,
            cihaz_id   uuid NOT NULL,
            -- Eylem KIMLIGI: 'ac' | 'kapat' | 'kilit_ac' | 'vana_kapat'.
            -- Serbest metin DEGIL, kodun tanidigi bir kume (uygulama
            -- katmaninda dogrulanir) — yoksa yazim hatasi sessizce
            -- calismayan bir senaryo uretirdi.
            eylem      text NOT NULL,
            aktif      boolean NOT NULL DEFAULT true,
            created_at timestamptz NOT NULL DEFAULT now(),
            UNIQUE (id, tenant_id),
            UNIQUE (olay, cihaz_id, eylem),
            CONSTRAINT fk_akilli_senaryo_cihaz
                FOREIGN KEY (cihaz_id, tenant_id)
                REFERENCES akilli_ev_cihaz (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_akilli_senaryo_tenant ON akilli_ev_senaryo (tenant_id);"
    )
    op.execute("CREATE INDEX ix_akilli_senaryo_olay ON akilli_ev_senaryo (olay);")
    op.execute("CREATE INDEX ix_akilli_senaryo_cihaz ON akilli_ev_senaryo (cihaz_id);")

    for tablo in (
        "akilli_ev_kopru",
        "akilli_ev_cihaz",
        "akilli_ev_bolum_ayari",
        "akilli_ev_senaryo",
    ):
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

    # OLAY JETONUNDAN TENANT COZUCU — `gonderim_tenant_by_saglayici_id`
    # ve `payment_tenant_by_ref` ile AYNI desen ve ayni gerekce:
    #
    # Hub bize olay gonderirken JWT tasiyamaz (bir kullanici degil, bir
    # cihazdir) ve RLS baglami ancak SATIRI BULARAK kurulabilir —
    # baglamsiz sorgu hicbir satir gormez. Fonksiyon TEK SUTUN doner
    # (tenant_id): kopru adresini, jetonu ya da cihaz listesini
    # DONDURMEZ, yani gecersiz bir cagri veri sizdiramaz.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION public.akilli_ev_tenant_by_olay_jetonu(
            p_hash text
        )
        RETURNS uuid
        LANGUAGE sql
        SECURITY DEFINER
        SET search_path TO 'public', 'pg_temp'
        AS $$
            SELECT tenant_id FROM public.akilli_ev_kopru
             WHERE olay_jetonu_hash = p_hash
             LIMIT 1;
        $$;
        """
    )
    # PUBLIC'TEN ALINIR: SECURITY DEFINER fonksiyonu RLS'i bypass eder;
    # yalniz uygulama rolu calistirabilmeli.
    op.execute(
        "REVOKE ALL ON FUNCTION public.akilli_ev_tenant_by_olay_jetonu(text) "
        "FROM PUBLIC;"
    )
    op.execute(
        "GRANT EXECUTE ON FUNCTION public.akilli_ev_tenant_by_olay_jetonu(text) "
        f"TO {APP_ROLE};"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'akilli_ev_kacak';"
    )
    op.execute(
        "ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS 'akilli_ev_yangin';"
    )


def downgrade() -> None:
    # notification_tip degerleri GERI ALINMAZ (goc 0131/0140/0141 emsali).
    op.execute(
        "DROP FUNCTION IF EXISTS public.akilli_ev_tenant_by_olay_jetonu(text);"
    )
    op.execute("DROP TABLE IF EXISTS akilli_ev_senaryo;")
    op.execute("DROP TABLE IF EXISTS akilli_ev_bolum_ayari;")
    op.execute("DROP TABLE IF EXISTS akilli_ev_cihaz;")
    op.execute("DROP TABLE IF EXISTS akilli_ev_kopru;")
    op.execute("DROP TYPE IF EXISTS akilli_ev_olay;")
    op.execute("DROP TYPE IF EXISTS akilli_ev_bolum;")
    op.execute("DROP TYPE IF EXISTS akilli_ev_cihaz_tip;")
    op.execute("DROP TYPE IF EXISTS akilli_ev_kopru_tur;")
