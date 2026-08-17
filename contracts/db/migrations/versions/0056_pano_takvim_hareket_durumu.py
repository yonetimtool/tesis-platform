"""(P167 Asama 2) Ozet sayfasi — pano tercihi + hatirlatma + hareket durumu.

Uc degisiklik TEK gocte cunku ucu de AYNI ekranin (Ozet) calismasi icin
gerekli ve ayri gocler, yarisi uygulanmis bir panoda "kolon yok" hatasi
verirdi.

===========================================================================
1. `app_user.pano_tercihi` (jsonb) — KULLANICI BASINA pano duzeni
===========================================================================
Brief: "yonetici hangi 6 sekmenin gorunecegini secebilir... Tercih
kullanici basina kalici" ve "Tum bolumler gizlenebilir/gosterilebilir ve
siralanabilir olacak. Tercih kullanici basina kalici."

NEDEN SUNUCUDA, `localStorage`TA DEGIL: tarayici deposu KULLANICI basina
degil TARAYICI basina calisir. Ofisteki bilgisayardan duzenlenen pano,
evdeki dizustunde ya da ayni bilgisayari paylasan ikinci yoneticide
varsayilana donerdi — brief'in acik sartinin tam tersi. Kabuk menusunun
acik/kapali durumu (`yonetio.menu.durum.v3`) BILINCLI olarak
`localStorage`ta kaliyor: o bir GEZINME aliskanligidir ve cihaz basina
farkli olmasi dogaldir; pano duzeni ise kisinin CALISMA duzenidir.

NEDEN JSONB, NEDEN AYRI TABLO DEGIL: kayit KULLANICIYA BIR-BIRE baglidir,
sorgulanmaz (yalnizca kendi sahibi okur) ve sekli arayuzle birlikte
degisir. Ayri bir tablo, her yeni bolum icin goc yazmak demekti. JSONB
serbestligi bir risk degil: uc semayla dogrular, tanimadigi anahtari ATAR.

`'{}'::jsonb` VARSAYILANI: "tercih yok" hâli NULL ile degil BOS NESNE ile
temsil ediliyor — okuyan kodun iki bos durumu (NULL / {}) ayirt etmesi
gerekmesin.

===========================================================================
2. `hatirlatma` — yoneticinin KENDI takvim kaydi
===========================================================================
Brief: "YONETICI KENDI HATIRLATMASINI EKLEYEBILECEK: baslik, tarih/saat,
aciklama, renk/kategori, tekrar (yok/gunluk/haftalik/aylik)."

NEDEN `event` TABLOSUNA EKLENMEDI: `event` SITE ETKINLIGIDIR — sakinlere
duyurulur, RSVP alir, ortak alan ayirtir. Hatirlatma ise KISISEL bir
nottur ve kimseye gorunmez. Ikisini tek tabloda tutup bir `gizli` bayragi
koymak, "duyuruyu yanlislikla herkese acmak" sinifindan bir hatayi bir
kutucuk mesafesine indirirdi.

`user_id` ZORUNLU ve kayit YALNIZ sahibinindir. `tenant_id` de tutulur
(RLS ve tesis silinince cascade icin) ama gorunurluk kapisi `user_id`dir:
ayni tesisteki baska bir yonetici bu satiri GORMEZ.

TEKRAR SAKLANIR, GENISLETILMEZ: "her hafta" bir KURALDIR; tekrar eden
kaydin her ornegini satir olarak yazmak, "kurali degistir" istegini
yuzlerce satir guncellemeye cevirirdi. Genisletme OKUMA aninda, takvim
penceresi kadar yapilir.

`bitis` NULL OLABILIR: "saat 14:00'te ara" gibi ANLIK bir hatirlatmanin
bitisi yoktur; zorunlu kilmak kullaniciyi uydurma bir sure girmeye
zorlardi.

===========================================================================
3. `finansal_hareket.durum` — odendi / bekliyor / onay_bekliyor
===========================================================================
Brief Asama 2, "Onay Bekleyen Hareketler" ve "Borclarim" kartlarini
istiyor; Asama 4 ise gelir/gider satirlarinda "Durumu (varsayilan
Odendi)" alanini istiyor. IKISI AYNI KOLONDUR ve iki ayri turda iki kez
acmak, arada kalan surumde karti besleyecek bir alan olmamasi demekti.

VARSAYILAN `odendi` VE BU SART: tablodaki mevcut satirlarin HEPSI
gerceklesmis para hareketleridir (kasa bakiyesi onlardan hesaplaniyor).
Varsayilani `bekliyor` yapmak, gecmis butun defteri bir gecede
"odenmemis" gostermek ve kasa mutabakatini bozmak olurdu.

KASA BAKIYESI HESABI BU GOCTE DEGISMEDI. Degistirilseydi (orn. yalniz
`odendi` satirlari sayilsaydi) mevcut bakiyeler AYNI kalirdi cunku her
satir `odendi` basliyor — ama kural degisikligi ayri bir karardir ve
onun yeri bu goc degil, bekleyen hareketlerin yazilmaya baslandigi
Asama 4'tur. Burada yalnizca ALAN aciliyor.
"""
from alembic import op

revision = "0056_pano_takvim_hareket_durumu"
down_revision = "0055_bildirim_tercihleri"
branch_labels = None
depends_on = None

#: RLS politikalarinin okudugu oturum degiskeni ve uygulama rolu — depodaki
#: butun goclerle AYNI (bkz. 0001, 0043). Farkli yazmak, politikanin HICBIR
#: satiri gecirmemesi (ya da hepsini gecirmesi) demekti.
APP_ROLE = "app_rw"
TENANT_AYARI = "app.current_tenant_id"


def upgrade() -> None:
    # ---------------------------------------------------------------- 1
    op.execute(
        """
        ALTER TABLE app_user
          ADD COLUMN pano_tercihi jsonb NOT NULL DEFAULT '{}'::jsonb
        """
    )

    # ---------------------------------------------------------------- 2
    op.execute(
        "CREATE TYPE hatirlatma_tekrar AS ENUM "
        "('yok', 'gunluk', 'haftalik', 'aylik')"
    )
    op.execute(
        """
        CREATE TABLE hatirlatma (
            id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            user_id     uuid NOT NULL,
            baslik      text NOT NULL,
            aciklama    text,
            baslangic   timestamptz NOT NULL,
            bitis       timestamptz,
            renk        text NOT NULL DEFAULT 'mavi',
            tekrar      hatirlatma_tekrar NOT NULL DEFAULT 'yok',
            created_at  timestamptz NOT NULL DEFAULT now(),
            updated_at  timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT fk_hatirlatma_user
              FOREIGN KEY (user_id, tenant_id)
              REFERENCES app_user (id, tenant_id) ON DELETE CASCADE,
            -- Bitis varsa BASLANGICTAN SONRA olmali. Kisit veritabaninda
            -- cunku ters aralik takvimi cizerken degil, cizim SIRASINDA
            -- patlatirdi ve sebebi ekranda hic gorunmezdi.
            CONSTRAINT ck_hatirlatma_aralik CHECK (bitis IS NULL OR bitis >= baslangic),
            CONSTRAINT ck_hatirlatma_baslik CHECK (length(btrim(baslik)) > 0)
        )
        """
    )
    # Takvim SORGUSU her zaman (sahip + pencere) ile gelir; indeks tam o
    # sirayla. `tenant_id` de icinde cunku RLS her sorguya onu ekler.
    op.execute(
        """
        CREATE INDEX ix_hatirlatma_sahip_pencere
          ON hatirlatma (tenant_id, user_id, baslangic)
        """
    )
    # RLS — 0001/0043 desenin aynisi. FORCE olmadan tablo SAHIBI
    # politikalari atlar ve `test_rls_kapsam` bunu (hakli olarak) kusur sayar.
    op.execute("ALTER TABLE public.hatirlatma ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE public.hatirlatma FORCE ROW LEVEL SECURITY")
    op.execute(
        """
        CREATE POLICY hatirlatma_tenant ON public.hatirlatma
          USING (tenant_id = current_setting('{TENANT_AYARI}', true)::uuid)
          WITH CHECK (tenant_id = current_setting('{TENANT_AYARI}', true)::uuid)
        """.replace("{TENANT_AYARI}", TENANT_AYARI)
    )
    op.execute(
        f"GRANT SELECT, INSERT, UPDATE, DELETE ON public.hatirlatma TO {APP_ROLE}"
    )

    # ---------------------------------------------------------------- 3
    op.execute(
        "CREATE TYPE hareket_durum AS ENUM "
        "('odendi', 'bekliyor', 'onay_bekliyor')"
    )
    op.execute(
        """
        ALTER TABLE finansal_hareket
          ADD COLUMN durum hareket_durum NOT NULL DEFAULT 'odendi'
        """
    )
    # "Onay bekleyen" ve "odenmemis" kartlari HER PANO ACILISINDA sayiliyor.
    # Kismi indeks: satirlarin ezici cogunlugu `odendi` olacak ve onlari
    # indekslemek yalniz yer kaplardi.
    op.execute(
        """
        CREATE INDEX ix_hareket_bekleyen
          ON finansal_hareket (tenant_id, durum)
          WHERE durum <> 'odendi'
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_hareket_bekleyen")
    op.execute("ALTER TABLE finansal_hareket DROP COLUMN IF EXISTS durum")
    op.execute("DROP TYPE IF EXISTS hareket_durum")
    op.execute("DROP POLICY IF EXISTS hatirlatma_tenant ON public.hatirlatma")
    op.execute("DROP TABLE IF EXISTS public.hatirlatma")
    # TIP TABLODAN SONRA: sutun hâlâ ona bagliyken `DROP TYPE` patlar.
    op.execute("DROP TYPE IF EXISTS hatirlatma_tekrar")
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS pano_tercihi")
