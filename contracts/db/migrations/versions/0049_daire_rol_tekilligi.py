"""(P154 / Asama 5) BIR DAIREDE HER ROLDEN EN FAZLA BIR AKTIF HESAP.

===========================================================================
NEDEN BU BICIM — OLCULEREK SECILDI
===========================================================================
Kilitli kural 4 "bir daire icin en fazla 1 hesap" diyor. Kuralin HARFI
`(unit_id) WHERE bitis IS NULL` demekti; denendi ve tam takimda
**1 kirik + 104 hata** uretti (rapor §4.47).

Kirilan test tesadufi degildi: `test_hedefleme_KIRACI_VAR_YOK_IKISI_BIRDEN`.
`borclandirma.hedef_sec` (P28) bir dairede MALIK ve KIRACI birlikte
bulunabilsin diye yazilmis — `kiraci_oncelikli` = "kiraci varsa ona,
yoksa malike" — ve tek sakinli bir dairede o kuralin secece bir seyi
kalmaz. Ice aktarimin `rol_tipi` sutunu (Asama 8) da ayni varsayimi
tasiyor.

Kerem A secenegini onayladi: **daire basina her ROLDEN en fazla bir
aktif hesap**. Bu, kuralin cozmek istedigi somut sorunlari kapatir
(A-12'deki iki malik, Excel'de ayni role iki satir) ve calisan bir
ozelligi yok etmez.

===========================================================================
ESKI INDEKS KALIYOR — FARKLI BIR SEYI KORUYOR
===========================================================================
`uq_unitresident_aktif` = `(unit_id, user_id) WHERE bitis IS NULL`:
AYNI KISI ayni daireye iki kez baglanamaz.

Yeni indeks bunu KAPSAMAZ: ayni kisi bir kez `malik`, bir kez `kiraci`
olarak baglanabilirdi (`rol_tipi` farkli oldugu icin catismaz). Iki
indeks iki ayri soruyu yanitliyor; birini otekinin yerine koymak sessiz
bir bosluk acardi.

Ilk denemede eski indeks DUSURULMUSTU ve seed'in
`ON CONFLICT (unit_id, user_id)` yazimi "no unique or exclusion
constraint matching the ON CONFLICT specification" ile kirildi (§4.50) —
`ON CONFLICT` ESLESEN bir indeks arar, "semantik olarak kapsayan" degil.
Indeksi birakmak o sorunu da ortadan kaldiriyor.

===========================================================================
NULL `rol_tipi` BOSLUGU — BILINCLI VE BELGELI
===========================================================================
PostgreSQL'de birden fazla NULL ayni benzersiz indekste CATISMAZ. Yani
`rol_tipi` BILINMEYEN iki aktif sakin bu indeksten gecer.

Kapatmak DENENDI, iki yolu da elendi:
  * `(unit_id, COALESCE(rol_tipi::text,'-'))` -> "functions in index
    expression must be marked IMMUTABLE" (enum->text cast STABLE'dir).
  * Ek kismi indeks `(unit_id) WHERE bitis IS NULL AND rol_tipi IS NULL`
    -> olusuyor ama **37 test hatasi** verdi; ziyaretci fixture'lari bir
    daireye rolsuz coklu sakin bagliyor.

Bu yuzden bosluk UYGULAMA KATMANINDA kapatiliyor:
`units.daire_rolu_dolu_mu` NULL'u da BIR DEGER sayar ve ikinci rolsuz
sakini reddeder. Yani uctan gecen hicbir yazma boslugu kullanamaz;
dogrudan SQL yazan bir yol kullanabilir ve bu KABUL EDILEN sinirdir —
alternatifi calisan 37 testi ve arkasindaki kurulumu bozmakti.

===========================================================================
ONKOSUL SESSIZCE DEGIL, ANLASILIR SEKILDE PATLAR
===========================================================================
Ham `CREATE UNIQUE INDEX` hatasi operatore HANGI dairenin sorunlu
oldugunu soylemez. Bu goc uretimde de kosacak ve orasi gorulemiyor (dev
makineden prod'a erisim yok). Yayindan ONCE
`infra/scripts/daire_tek_hesap_onkontrol.py` calistirilmali.

KAPATMA = SILME DEGIL: fazla bag `bitis` yazilarak kapatilir; hesap ve
erisim OLDUGU GIBI KALIR (kilitli kural 1).
"""
from alembic import op

revision = "0049_daire_rol_tekilligi"
down_revision = "0048_oauth_kimlik"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        DECLARE
            ihlal text;
        BEGIN
            SELECT string_agg(x.satir, ', ' ORDER BY x.satir) INTO ihlal
              FROM (
                SELECT u.no || ' (' || COALESCE(ur.rol_tipi::text, 'rolsuz') || ')'
                       AS satir
                  FROM unit_resident ur
                  JOIN unit u ON u.id = ur.unit_id
                 WHERE ur.bitis IS NULL
                   AND ur.rol_tipi IS NOT NULL
                 GROUP BY u.id, u.no, ur.rol_tipi
                HAVING count(*) > 1
              ) x;
            IF ihlal IS NOT NULL THEN
                RAISE EXCEPTION
                  'Bir dairede ayni rolden birden fazla aktif hesap var. '
                  'Once fazla baglari KAPATIN '
                  '(unit_resident.bitis yazin; hesap SILINMEZ): %', ihlal
                  USING HINT =
                    'infra/scripts/daire_tek_hesap_onkontrol.py listeyi verir.';
            END IF;
        END $$;
        """
    )

    # `uq_unitresident_aktif` (unit_id, user_id) DOKUNULMADAN kalir —
    # gerekce modul basliginda.
    op.execute(
        """
        CREATE UNIQUE INDEX uq_unitresident_daire_rol
            ON unit_resident (unit_id, rol_tipi)
         WHERE bitis IS NULL;
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS uq_unitresident_daire_rol;")
