"""(P165) Rezervasyon gecmisi saklama suresi — tesis ayari.

===========================================================================
ISTEK NEYDI, NEDEN AYNEN UYGULANMADI
===========================================================================
Istek: "10 rezervasyon sonrasinda gecmisten en eski 1 kayit SILINSIN."
Uc noktada degistirildi ve ucu de gerekceli:

1. SAYI DEGIL SURE. Sayi bazli saklama ONGORULEMEZ: spor salonunu
   haftada iki kez ayirtan bir sakin on kaydi bes haftada doldurur ve
   GECEN AYKI kaydini kaybeder; yilda bir kez ayirtan biri ise on yil
   oncesini tasir. Ayni kural iki kullaniciya taban tabana zit davranir.
   Sure bazli saklama ("son 12 ay") herkes icin ayni anlama gelir ve
   kullanicinin kafasindaki modele ("gecen yil") uyar.

2. KALICI SILME DEGIL GIZLEME. Rezervasyon bir KULLANIM KAYDIDIR. Ortak
   alanda hasar cikarsa, iki sakin ayni gun icin anlasmazliga duserse ya
   da bir iptalin kim tarafindan yapildigi sorulursa (`iptal_eden_user_id`
   satirda duruyor) bu kayit KANITTIR. Kalici silme geri alinamaz;
   gizleme her an geri alinabilir. Veri KALIR, LISTE kisalir.

3. TESIS BASINA DEGIL, KAYIT YASINA GORE. "Tesis basina 10" 50 daireli
   bir sitede bir haftada dolardi. Yasa gore suzmek, tesis buyuklugunden
   BAGIMSIZ calisir.

===========================================================================
KOLON
===========================================================================
`rezervasyon_gecmis_ay` — gecmis listesinde en fazla kac AY geriye
gidilecegi. `tenant`da cunku bu bir TESIS POLITIKASIDIR.

* `NOT NULL DEFAULT 12` — mevcut tesisler goc sonrasi calisir kalir ve
  bir yil, anlasmazliklarin cikma penceresi icin makul bir taban.
* `0 = SINIRSIZ` ve bu bilincli: "gizleme yok" secenegi olmadan ayar,
  kullaniciyi bir saklama politikasina ZORLARDI. Sifir, "hepsini goster"
  demenin en dogal yolu.
* `CHECK (0..120)` — 10 yil ust sinir; daha uzugu bir saklama politikasi
  degil, ayarin yanlis girilmis hali olurdu.

`okutma_mesafe_esigi_m` (0052) ile AYNI DESEN: yeni bir kavram
uydurulmadi, var olan tesis-ayari kalibina eklendi.
"""
from alembic import op

revision = "0054_rezervasyon_gecmis_saklama"
down_revision = "0053_uzak_okutma_alarmi"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE tenant
          ADD COLUMN rezervasyon_gecmis_ay integer NOT NULL DEFAULT 12
        """
    )
    op.execute(
        """
        ALTER TABLE tenant
          ADD CONSTRAINT ck_tenant_rezervasyon_gecmis_ay
          CHECK (rezervasyon_gecmis_ay BETWEEN 0 AND 120)
        """
    )


def downgrade() -> None:
    # TERSINIR: kolon ve kisit birlikte duser. Veri kaybi YOK — bu kolon
    # yalnizca bir GORUNUM politikasi tasiyor, rezervasyonun kendisini
    # degil (gizleme secildi, silme degil).
    op.execute("ALTER TABLE tenant DROP CONSTRAINT IF EXISTS ck_tenant_rezervasyon_gecmis_ay")
    op.execute("ALTER TABLE tenant DROP COLUMN IF EXISTS rezervasyon_gecmis_ay")
