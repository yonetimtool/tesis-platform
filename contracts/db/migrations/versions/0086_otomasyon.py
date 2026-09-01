"""(P192 §4) OTOMASYON — aidat planı, hatırlatma ayarı, düzenli gider, günlük

===========================================================================
NEDEN
===========================================================================
`docs/finans-analiz.md`: `beat_schedule`da aidat görevi YOKTU. Yönetici her
ay tahakkuku ELLE çalıştırıyordu; unutursa o ay borç oluşmuyordu. Borç
hatırlatması da yoktu; düzenli giderler (kapıcı maaşı, asansör bakımı)
her ay elle giriliyordu.

===========================================================================
ORTAK İLKE: HER OTOMASYON AÇILIP KAPATILABİLİR VE İZ BIRAKIR
===========================================================================
Dört tablonun ortak tasarımı:

  * `aktif` bayrağı — otomasyon KAPATILABİLİR olmalı. Kullanıcının açık
    isteği; ayrıca bir hatayı durdurmanın tek yolu görevi silmek olmamalı.
  * `otomasyon_gunlugu` — "ne zaman ne yaptığı görünsün". Bir otomasyonun
    çalıştığı ancak ürettiği kayda bakılarak anlaşılabilseydi, HİÇBİR ŞEY
    ÜRETMEDİĞİ durum (ki asıl merak edilen odur) görünmez kalırdı.

===========================================================================
1) aidat_plani — OTOMATİK AYLIK TAHAKKUK
===========================================================================
Yönetici bir kez tanımlar: tutar/dağıtım, ayın kaçında tahakkuk, vade kaç
gün sonra. Görev her gün bakar; günü gelen planı işler.

`son_donem` İDEMPOTENCY'NİN KENDİSİDİR: bir plan bir dönemi bir kez işler.
Görev günde on kez koşsa da ikinci koşum aynı dönemi görür ve durur.
Tarihe bakıp "bugün ayın 5'i mi" demek YETMEZDİ: görev gün içinde birden
çok kez koşar ve saatlik bir pencere uydurmak, kaçırılan bir koşumu
telafi edilemez kılardı.

`ertelenen_donem` — yöneticinin "bu ay atla" demesi. Planı pasife almak
gelecek ayları da kapatırdı; bu alan YALNIZ bir dönemi atlar.

`onizleme_gun` + `onizleme_donem`: tahakkuktan N gün önce yöneticiye
"3 gün sonra 26 daireye toplam X TL tahakkuk edilecek" bildirimi gider.
`onizleme_donem` aynı dönem için ikinci bildirimi engeller.

===========================================================================
2) hatirlatma_ayari — TESİS BAŞINA TEK SATIR
===========================================================================
`tenant_id` BİRİNCİL ANAHTAR: ayar tesise aittir, listesi yoktur. Ayrı bir
`id` sütunu, "hangi ayar geçerli" sorusunu doğururdu.

`kademeler` bir INT DİZİSİ (3, 10, 30 gün): kademe sayısını sütunlara
sabitlemek (gun1/gun2/gun3), dördüncü kademeyi şema değişikliğine
bağlardı.

===========================================================================
3) duzenli_gider — TEKRAR EDEN GİDER
===========================================================================
Tekrar SAKLANIR, GENİŞLETİLMEZ: "her ay" bir KURALDIR ve her örneğini
satır olarak yazmak, kuralı değiştirmeyi yüzlerce satır güncellemeye
çevirirdi (P167'nin hatırlatma tekrarıyla aynı ilke).

`otomatik_onay=false` VARSAYILAN: vadesi gelen gider ONAY BEKLEYEN olarak
yazılır ve yöneticinin önüne düşer. Otomatik "ödendi" yazmak, sistemin
kimseye sormadan kasadan para çıkarması olurdu.

===========================================================================
4) otomasyon_gunlugu — APPEND-ONLY İZ
===========================================================================
`sonuc` JSONB: her otomasyonun ürettiği özet farklıdır (kaç tahakkuk, kaç
hatırlatma, kaç gider). Türe özel sütunlar açmak, beşinci otomasyonda
tabloyu yeniden şekillendirmek demekti.

Revision ID: 0086_otomasyon
Revises: 0085_tahakkuk_kalemleri
Create Date: 2026-08-31
"""
from alembic import op

revision = "0086_otomasyon"
down_revision = "0085_tahakkuk_kalemleri"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"

#: RLS + GRANT deseni: her yeni tabloda AYNI dort adim (bkz. 0079).
_TABLOLAR = ("aidat_plani", "hatirlatma_ayari", "duzenli_gider", "otomasyon_gunlugu")


def upgrade() -> None:
    # (P192 §4) YENI BILDIRIM TIPLERI. Bu gocte KULLANILMAZLAR (Postgres
    # ayni islemde eklenen bir enum degerini kullandirmaz); calisma
    # aninda kullanilirlar.
    for deger in (
        # Vade yaklasti / gecti hatirlatmasi (sakine).
        "aidat_hatirlatma",
        # "3 gun sonra 26 daireye toplam X TL tahakkuk edilecek" (yoneticiye).
        "aidat_onizleme",
        # Ay basi ozeti (yoneticiye) + seffaflik ozeti.
        "aylik_ozet",
        # Vadesi gelen duzenli gider onay bekliyor (yoneticiye).
        "gider_onay",
    ):
        op.execute(
            f"ALTER TYPE notification_tip ADD VALUE IF NOT EXISTS '{deger}';"
        )
    op.execute(
        "CREATE TYPE gider_periyot AS ENUM "
        "('aylik', 'uc_aylik', 'alti_aylik', 'yillik');"
    )
    op.execute(
        "CREATE TYPE otomasyon_turu AS ENUM "
        "('aidat_tahakkuk', 'aidat_onizleme', 'borc_hatirlatma', "
        "'duzenli_gider', 'gecikme_faizi', 'aylik_ozet');"
    )

    # ------------------------------ 1) plan ------------------------------ #
    op.execute(
        """
        CREATE TABLE aidat_plani (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad text NOT NULL,
            gelir_gider_tanim_id uuid,
            kalem_tipi dues_kalem_tipi NOT NULL DEFAULT 'aidat',
            dagitim text NOT NULL DEFAULT 'daire_basina',
            tutar_kurus bigint,
            toplam_tutar_kurus bigint,
            -- 1..28: 29/30/31 her ayda YOKTUR ve "ayin 31'i" kurali Subat'ta
            -- sessizce hic calismazdi.
            tahakkuk_gunu smallint NOT NULL DEFAULT 1
                CHECK (tahakkuk_gunu BETWEEN 1 AND 28),
            vade_gun smallint NOT NULL DEFAULT 15 CHECK (vade_gun BETWEEN 0 AND 90),
            onizleme_gun smallint NOT NULL DEFAULT 3
                CHECK (onizleme_gun BETWEEN 0 AND 28),
            aktif boolean NOT NULL DEFAULT true,
            son_donem text,
            onizleme_donem text,
            ertelenen_donem text,
            aciklama text,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_aidat_plani_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_aidat_plani_ad UNIQUE (tenant_id, ad),
            CONSTRAINT fk_aidat_plani_tanim
                FOREIGN KEY (gelir_gider_tanim_id, tenant_id)
                REFERENCES gelir_gider_tanim (id, tenant_id) ON DELETE SET NULL
                    (gelir_gider_tanim_id),
            -- TUTAR YA DA TOPLAM: `daire_basina` daire basina tutar ister,
            -- oteki dagitimlar TOPLAM ister. Ikisini de bos birakan bir plan
            -- her ay sessizce hicbir sey yazmazdi.
            CONSTRAINT ck_aidat_plani_tutar CHECK (
                (dagitim = 'daire_basina' AND tutar_kurus IS NOT NULL)
                OR (dagitim <> 'daire_basina' AND toplam_tutar_kurus IS NOT NULL)
            )
        );
        """
    )
    op.execute("CREATE INDEX ix_aidat_plani_tenant ON aidat_plani (tenant_id, aktif);")
    op.execute(
        "CREATE INDEX ix_aidat_plani_tanim ON aidat_plani "
        "(gelir_gider_tanim_id, tenant_id) WHERE gelir_gider_tanim_id IS NOT NULL;"
    )

    # --------------------------- 2) hatirlatma --------------------------- #
    op.execute(
        """
        CREATE TABLE hatirlatma_ayari (
            tenant_id uuid PRIMARY KEY REFERENCES tenant(id) ON DELETE CASCADE,
            aktif boolean NOT NULL DEFAULT false,
            -- Vade YAKLASIRKEN: kac gun once. 0 = vade oncesi hatirlatma yok.
            vade_oncesi_gun smallint NOT NULL DEFAULT 3
                CHECK (vade_oncesi_gun BETWEEN 0 AND 30),
            -- Vade GECTIKTEN sonra kademeli: gun listesi.
            kademeler smallint[] NOT NULL DEFAULT ARRAY[3, 10, 30]::smallint[],
            -- Yoneticinin duzenledigi metin. NULL = urun varsayilani
            -- (cok dilli); metin girilirse O KULLANILIR ve cevrilmez —
            -- yoneticinin yazdigi cumleyi makineyle degistirmek, onun
            -- soylemedigi bir seyi ona soyletmek olurdu.
            metin text,
            son_calisma date,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now()
        );
        """
    )

    # -------------------------- 3) duzenli gider ------------------------- #
    op.execute(
        """
        CREATE TABLE duzenli_gider (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            ad text NOT NULL,
            tutar_kurus bigint NOT NULL CHECK (tutar_kurus > 0),
            periyot gider_periyot NOT NULL DEFAULT 'aylik',
            sonraki_tarih date NOT NULL,
            kasa_id uuid,
            firma_id uuid,
            gelir_gider_tanim_id uuid,
            -- VARSAYILAN false: vadesi gelen gider ONAY BEKLEYEN yazilir.
            -- Otomatik "odendi" yazmak, sistemin kimseye sormadan kasadan
            -- para cikarmasi olurdu.
            otomatik_onay boolean NOT NULL DEFAULT false,
            aktif boolean NOT NULL DEFAULT true,
            aciklama text,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_duzenli_gider_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT uq_duzenli_gider_ad UNIQUE (tenant_id, ad),
            CONSTRAINT fk_duzenli_gider_kasa
                FOREIGN KEY (kasa_id, tenant_id)
                REFERENCES kasa (id, tenant_id) ON DELETE SET NULL (kasa_id),
            CONSTRAINT fk_duzenli_gider_firma
                FOREIGN KEY (firma_id, tenant_id)
                REFERENCES firma (id, tenant_id) ON DELETE SET NULL (firma_id),
            CONSTRAINT fk_duzenli_gider_tanim
                FOREIGN KEY (gelir_gider_tanim_id, tenant_id)
                REFERENCES gelir_gider_tanim (id, tenant_id) ON DELETE SET NULL
                    (gelir_gider_tanim_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_duzenli_gider_tenant ON duzenli_gider "
        "(tenant_id, aktif, sonraki_tarih);"
    )
    for sutun in ("kasa_id", "firma_id", "gelir_gider_tanim_id"):
        op.execute(
            f"CREATE INDEX ix_duzenli_gider_{sutun} ON duzenli_gider "
            f"({sutun}, tenant_id) WHERE {sutun} IS NOT NULL;"
        )

    # ---------------------------- 4) gunluk ------------------------------ #
    op.execute(
        """
        CREATE TABLE otomasyon_gunlugu (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            tur otomasyon_turu NOT NULL,
            calisma_zamani timestamptz NOT NULL DEFAULT now(),
            donem text,
            adet integer NOT NULL DEFAULT 0,
            tutar_kurus bigint NOT NULL DEFAULT 0,
            sonuc jsonb NOT NULL DEFAULT '{}'::jsonb,
            CONSTRAINT uq_otomasyon_gunlugu_id_tenant UNIQUE (id, tenant_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_otomasyon_gunlugu_tenant ON otomasyon_gunlugu "
        "(tenant_id, calisma_zamani DESC, id DESC);"
    )

    for tablo in _TABLOLAR:
        op.execute(f"ALTER TABLE {tablo} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {tablo} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {tablo}_tenant ON {tablo}
                USING (tenant_id = current_setting('app.current_tenant_id')::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id')::uuid);
            """
        )
        op.execute(
            f"GRANT SELECT, INSERT, UPDATE, DELETE ON {tablo} TO {APP_ROLE};"
        )
    # GUNLUK APPEND-ONLY: bir otomasyonun ne yaptigi sonradan
    # duzeltilemez. Iz, duzeltilebilir oldugu anda iz olmaktan cikar.
    op.execute(
        f"REVOKE UPDATE, DELETE ON otomasyon_gunlugu FROM {APP_ROLE};"
    )


def downgrade() -> None:
    # ENUM DEGERLERI DUSURULEMEZ (Postgres). Kullanan satir kalmadigi
    # icin zararsizdirlar: `notification` satirlari tablolarla birlikte
    # gitmez ama bu tipler yalnizca bu gocteki otomasyonlarca yazilir.
    for tablo in reversed(_TABLOLAR):
        op.execute(f"DROP TABLE IF EXISTS {tablo} CASCADE;")
    op.execute("DROP TYPE IF EXISTS otomasyon_turu;")
    op.execute("DROP TYPE IF EXISTS gider_periyot;")
