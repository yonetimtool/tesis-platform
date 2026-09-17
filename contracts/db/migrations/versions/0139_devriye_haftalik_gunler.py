"""(P239 §4) DEVRIYE PLANINA HAFTALIK GUN SECIMI + BIR KERELIK EK TARIHLER.

===========================================================================
OLCULEN KUSUR
===========================================================================
`patrol_plan` bir GUN-ICI pencere tanimiydi (baslangic/bitis/periyot) ve
HANGI GUNLER yurunecegini HIC tasimiyordu: plan aktifse HER GUN pencere
uretiliyordu (`scheduler/service.materialize_windows`). "Her pazartesi ve
persembe gece devriyesi" ifade edilemiyordu; tek yol her gun yurumek ya
da plani elle acip kapatmakti.

===========================================================================
NEDEN HAFTANIN GUNLERI, SOMUT TARIH DEGIL
===========================================================================
Devriye plani TEKRAR EDEN bir seydir. Somut tarih listesi tutmak plani
tekrarsizlastirir ve ufuk (horizon) doldugunda listenin yeniden
doldurulmasi gerekirdi — yani plan, bakim isteyen bir takvime donusurdu.
Somut tarih secimi VARDIYA planinin isidir (`vardiya_plani.gunler`),
devriyeninki degil.

===========================================================================
AMA BIR KERELIK EK DEVRIYE GERCEK BIR IHTIYAC
===========================================================================
Bayram, ozel etkinlik, misafir akini. Bugun tek care YENI BIR PLAN acip
sonra silmekti — ve o plan silinmezse sessizce her hafta yurumeye devam
ederdi. `ek_tarihler` bu ihtiyaci plana BAGLI tutar: ayni noktalar, ayni
saat, ayni periyot; yalniz FAZLADAN bir gun.

Pencere uretimi UNION'dur: `haftanin gunu gunler'de` VEYA
`yerel tarih ek_tarihler'de`.

===========================================================================
NULL = HER GUN (GERIYE UYUMLULUK)
===========================================================================
Mevcut planlar her gun yuruyor. Kolonu NOT NULL + varsayilan
ARRAY[1..7] yapmak AYNI davranisi verirdi ama bir ayrimi kaybederdik:
"her gun yurusun DEDIM" ile "gun secimi HIC sorulmadi" ayni sey degil;
ikincisi eski kayittir ve ileride bir gocun/raporun ayirt etmesi
gerekebilir. NULL bu ayrimi ucretsiz tasiyor.

BOS DIZI YASAK (CHECK): `{}` "hicbir gun" demek olurdu ve plan aktif
gorunurken hicbir pencere uretmezdi — kullanicinin goremeyecegi bir
sessiz kapali hal. Gun secmemek istiyorsan kolon NULL kalir.

===========================================================================
GUN NUMARALARI ISO-8601 (1=Pazartesi ... 7=Pazar)
===========================================================================
PostgreSQL `EXTRACT(ISODOW)` ve Python `date.isoweekday()` AYNI sayiyi
verir; JavaScript `getDay()` ise 0=Pazar der. Tek bir kaynak secmek
zorundayiz ve veritabaniyla Python'un uyustugu numara ISO'dur — istemci
tarafi cevirir (tek yerde, `gun-numaralari` yardimcisinda).

===========================================================================
INDEKS YOK
===========================================================================
Bu kolonlar SUZGEC DEGIL: zamanlayici zaten `aktif = true` olan TUM
planlari cekip gunleri Python'da eliyor (tenant basina bir avuc satir).
GIN indeksi kullanilmayan bir yapiyi her yazmada guncellemek olurdu.
"""
from alembic import op

revision = "0139_devriye_haftalik_gunler"
down_revision = "0138_cihaz_uygulama_surumu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE patrol_plan ADD COLUMN gunler smallint[];")
    op.execute("ALTER TABLE patrol_plan ADD COLUMN ek_tarihler date[];")
    # BOS DIZI YASAK + gun numaralari 1..7 (ISO). Tekrar eden gun de
    # yasak degil ama zararsiz: pencere uretimi kume mantigiyla calisir.
    op.execute(
        """
        ALTER TABLE patrol_plan ADD CONSTRAINT ck_patrol_plan_gunler
        CHECK (
            gunler IS NULL
            OR (array_length(gunler, 1) BETWEEN 1 AND 7
                AND gunler <@ ARRAY[1,2,3,4,5,6,7]::smallint[])
        );
        """
    )
    # UST SINIR 60: "bir kerelik ek gun" bir takvim degildir. Sinirsiz
    # birakmak, plani somut tarih listesine cevirmenin arka kapisi olurdu.
    op.execute(
        """
        ALTER TABLE patrol_plan ADD CONSTRAINT ck_patrol_plan_ek_tarihler
        CHECK (ek_tarihler IS NULL OR array_length(ek_tarihler, 1) BETWEEN 1 AND 60);
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE patrol_plan DROP CONSTRAINT IF EXISTS ck_patrol_plan_ek_tarihler;")
    op.execute("ALTER TABLE patrol_plan DROP CONSTRAINT IF EXISTS ck_patrol_plan_gunler;")
    op.execute("ALTER TABLE patrol_plan DROP COLUMN IF EXISTS ek_tarihler;")
    op.execute("ALTER TABLE patrol_plan DROP COLUMN IF EXISTS gunler;")
