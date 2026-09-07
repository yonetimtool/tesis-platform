"""(DUKKAN F7 §1) DAVET GONDERIM IZI — `yorum_daveti`ye uc sutun.

===========================================================================
OLCULEN KUSUR
===========================================================================
Davet kotasi `3 + 2xetkinlik` (30 gunluk pencere). `kullanilan` sayaci
`yorum_daveti` satirlarinin HEPSINI sayiyordu — SMS gitmis mi gitmemis mi
BAKMADAN.

Bugun prod'da onayli SMS basligi YOK; her davet `baslik_yok` ile
basarisiz oluyor. Yani basligin onaylandigi gun, ilk isletmeler
kotalarini HIC SMS GITMEDEN tuketmis olacak — ve bunu ancak isletme
"neden gonderemiyorum" diye sikayet edince fark edecegiz.

Ayni tuzak `telefon_dogrulama` icin goc 0116'da olculdu ve kapatildi.
Bu goc AYNI KALIBI davet tarafina tasiyor: kalibi ikinci kez yazmak
yerine birebir kopyalamak, iki sayacin ileride ayrisma ihtimalini de
ortadan kaldiriyor.

===========================================================================
90 GUNLUK TEKRAR ENGELI DE AYNI DERTTEN MUZDARIPTI
===========================================================================
"Ayni numaraya 90 gunde bir davet" kurali da TUM satirlari sayiyordu.
Gonderilemeyen bir davet, o numarayi UC AY boyunca kilitliyordu —
musteri hicbir sey almamisken. Bu goc onu da duzeltiyor (kismi indeks
ikinci sorguya da hizmet ediyor).

Degerler `telefon_dogrulama` ile BIREBIR AYNI:
  'gonderildi'      saglayici KABUL etti
  'saglayici_yok'   SMS saglayicisi yapilandirilmamis (noop)
  'baslik_yok'      saglayici var ama ONAYLI BASLIK tanimli degil
  'basarisiz'       saglayici REDDETTI ya da ulasilamadi

===========================================================================
GECMIS SATIRLAR: VARSAYILAN `saglayici_yok`
===========================================================================
Mevcut davetlerin gercekte gonderilip gonderilmedigi BILINMIYOR (kayit
tutulmuyordu). Varsayilani 'gonderildi' yapmak, gitmemis davetleri
gitmis SAYMAK olurdu — yani duzeltmenin tam tersi.

'saglayici_yok' secildi cunku dev/prod'da bugune kadar onayli baslik hic
olmadi: bu, elimizdeki EN DOGRU tahmin. Yan etkisi de dogru yonde —
gecmis davetler kotayi bosaltiyor, isletmeler basligin geldigi gun tam
kotayla basliyor.

GERI ALINABILIR: downgrade sutunlari ve indeksi dusurur.
"""
from alembic import op

revision = "0122_dukkan_davet_gonderim_izi"
down_revision = "0121_dukkan_bildirim_tercihi"
branch_labels = None
depends_on = None

SEMA = "dukkan"


def upgrade() -> None:
    op.execute(
        f"""
        ALTER TABLE {SEMA}.yorum_daveti
          ADD COLUMN gonderim_durumu text NOT NULL DEFAULT 'saglayici_yok'
            CHECK (gonderim_durumu IN
                   ('gonderildi', 'saglayici_yok', 'baslik_yok', 'basarisiz')),
          ADD COLUMN gonderim_hatasi text,
          ADD COLUMN saglayici text;
        """
    )
    # IKI SORGUYA BIRDEN hizmet ediyor:
    #   * kota:   (isletme_id, created_at) filtreli sayim
    #   * tekrar: (isletme_id, telefon, created_at) filtreli varlik
    # Kolon sirasi ikisini de karsiliyor; basarisiz denemeler indekste
    # yer kaplamiyor.
    op.execute(
        f"CREATE INDEX ix_yorum_daveti_gonderilen "
        f"ON {SEMA}.yorum_daveti (isletme_id, telefon, created_at DESC) "
        "WHERE gonderim_durumu = 'gonderildi';"
    )
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON "
               f"{SEMA}.yorum_daveti TO dukkan_app;")


def downgrade() -> None:
    op.execute(f"DROP INDEX IF EXISTS {SEMA}.ix_yorum_daveti_gonderilen;")
    op.execute(
        f"ALTER TABLE {SEMA}.yorum_daveti "
        "DROP COLUMN IF EXISTS gonderim_durumu, "
        "DROP COLUMN IF EXISTS gonderim_hatasi, "
        "DROP COLUMN IF EXISTS saglayici;"
    )
