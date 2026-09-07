"""(DUKKAN F2-ek) SMS GONDERIM IZI — `telefon_dogrulama`ya iki sutun.

===========================================================================
NEDEN GEREKLI
===========================================================================
Ilk yazimda uc `{"gonderildi": true, "gonderim": "saglayici_bagli_degil"}`
donduruyordu. Bu ikisi BIRBIRIYLE CELISIYOR ve istemci hangisine bakacagini
bilemez — kullanicinin bildirdigi kusur.

Duzeltmenin sarti gonderimin GERCEK sonucunu BILMEK ve SAKLAMAK:
`gonderim_durumu` artik kaydin bir parcasi.

===========================================================================
BASARISIZ GONDERIM KOTAYI YEMEZ
===========================================================================
Asil sebep bu sutunun varlik nedeni. Saatlik kod siniri (numara basina 5)
SMS bombardimanina karsi. Ama sinir TUM kayitlari sayarsa, saglayici
kesintisi olan bir anda kullanici bes kez deneyip HICBIRINI ALAMADAN
bir saatligine KILITLENIR — kendi hatasi olmayan bir sey yuzunden.

Sinir artik yalnizca `gonderim_durumu = 'gonderildi'` satirlari sayiyor.
Basarisiz deneme kayitta DURUR (teshis icin) ama kotayi tuketmez.

Degerler:
  'gonderildi'      saglayici KABUL etti
  'saglayici_yok'   SMS saglayicisi yapilandirilmamis (noop)
  'baslik_yok'      saglayici var ama ONAYLI BASLIK tanimli degil
  'basarisiz'       saglayici REDDETTI ya da ulasilamadi

GERI ALINABILIR: downgrade sutunlari dusurur.
"""
from alembic import op

revision = "0116_dukkan_sms_gonderim_izi"
down_revision = "0115_dukkan_kimlik_ve_isletme"
branch_labels = None
depends_on = None

SEMA = "dukkan"


def upgrade() -> None:
    op.execute(
        f"""
        ALTER TABLE {SEMA}.telefon_dogrulama
          ADD COLUMN gonderim_durumu text NOT NULL DEFAULT 'saglayici_yok'
            CHECK (gonderim_durumu IN
                   ('gonderildi', 'saglayici_yok', 'baslik_yok', 'basarisiz')),
          ADD COLUMN gonderim_hatasi text,
          ADD COLUMN saglayici text;
        """
    )
    # Hiz siniri sorgusu YALNIZ 'gonderildi' satirlarini sayiyor; kismi
    # indeks tam o sorguya oturuyor ve basarisiz denemeler indekste yer
    # kaplamiyor.
    op.execute(
        f"CREATE INDEX ix_telefon_dogrulama_gonderilen "
        f"ON {SEMA}.telefon_dogrulama (telefon, amac, created_at DESC) "
        "WHERE gonderim_durumu = 'gonderildi';"
    )
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON "
               f"{SEMA}.telefon_dogrulama TO dukkan_app;")


def downgrade() -> None:
    op.execute(f"DROP INDEX IF EXISTS {SEMA}.ix_telefon_dogrulama_gonderilen;")
    op.execute(
        f"ALTER TABLE {SEMA}.telefon_dogrulama "
        "DROP COLUMN IF EXISTS gonderim_durumu, "
        "DROP COLUMN IF EXISTS gonderim_hatasi, "
        "DROP COLUMN IF EXISTS saglayici;"
    )
