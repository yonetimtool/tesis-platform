"""(P167 Asama 3) ONARIM — dairesi olup KAYDI OLMAYAN bloklar.

===========================================================================
BILDIRILEN KUSUR VE KOK NEDENI (olculdu, tahmin edilmedi)
===========================================================================
"Web'den toplu blok/daire olusturunca kayitlar 'kayitsiz (yalnizca
dairede)' ibaresiyle geliyor ve duzenlenemiyor/silinemiyor. Mobilden
duzgun calisiyor."

Iki istemci AYNI ucu AYNI govdeyle cagiriyor (`POST /units/bulk`). Fark
cagrinin kendisinde degil ONCESINDE:

  * MOBIL: toplu olusturma diyalogu bir blogun ICINDEN acilir
    (`blok: widget.blok`). O blok daha once `POST /blocks` ile
    kaydedilmistir — `building_block` satiri VARDIR.
  * WEB: diyalog blok adini SERBEST METIN olarak yazdirir ve dogrudan
    `/units/bulk`a gonderir. `building_block` satiri HIC ACILMAZ.

`unit.blok` ZAYIF bir metin bagidir (hard FK yok — bilincli: blok-suz ve
blok-tabanli siteler birlikte desteklenir, bkz. 0001). Blok kaydi
olmayinca editor `registeredFor(label)` icin false doner:
"kayitsiz (yalnizca dairede)" rozeti cizilir ve Duzenle/Sil dugmeleri HIC
cizilmez — ikisi de `block.id` ister.

DUZELTME ISTEMCIDE DEGIL SUNUCUDA yapildi (bkz. `routers/units.py`):
web'i mobile benzetmek ORNEGI duzeltir, SINIFI duzeltmez — ice aktarim,
API kullanicisi ya da ileride yazilacak bir ekran ayni delige duserdi.

===========================================================================
BU GOC NE YAPAR
===========================================================================
`unit.blok`ta gecip `building_block`ta karsiligi OLMAYAN her (tenant,
etiket) cifti icin bir `building_block` satiri EKLER.

VERI KAYBI RISKI YOK ve bu iddia somuttur:
  * Tek islem INSERT. Hicbir satir silinmez, hicbir sutun guncellenmez.
  * `unit` tablosuna DOKUNULMAZ — daireler zaten dogru, eksik olan
    yalnizca blogun KENDI kaydiydi.
  * `ON CONFLICT DO NOTHING`: es zamanli bir kayit ya da tekrar
    calistirma (idempotent) sorun cikarmaz.

`kat_sayisi` BILEREK NULL BIRAKILIYOR. Dairelerden turetmek cazip
gorunuyor (`max(kat)`) ama YANLIS olurdu: bodrumlu bir binada katlar
-2'den baslar, yani en yuksek kat numarasi kat SAYISI degildir. Alan
zaten opsiyonel ve editor NULL'i "girilmemis" diye gosteriyor. Uydurma
bir sayi yazmak, kullanicinin duzeltmesi gereken sessiz bir yanlis
birakirdi; bos birakmak ise ona hicbir sey soylemez ama YANLIS da
soylemez.

BOS/BOSLUKLU ETIKETLER ATLANIR: `unit.blok` NULL olabilir (blok-suz
siteler, bilincli) ve o daireler editorde ZATEN kendi kovasinda
("Blok atanmamis") gorunuyor. Onlara blok uydurmak, kullanicinin
gormedigi bir yapi degisikligi olurdu.

===========================================================================
NEDEN GOC, NEDEN TEK SEFERLIK BETIK DEGIL
===========================================================================
Kusur URUNDE olusmus veriyi etkiliyor ve her ortamda (dev, test, canli)
ayni. Betik, calistirilmasi UNUTULABILEN bir adimdir; goc, surumle
birlikte kendiliginden gider ve `alembic_version` onun uygulandiginin
kaydidir.
"""
from alembic import op

revision = "0057_kayitsiz_blok_onarimi"
down_revision = "0056_pano_takvim_hareket_durumu"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        INSERT INTO building_block (tenant_id, ad)
        SELECT DISTINCT u.tenant_id, btrim(u.blok)
          FROM unit u
         WHERE u.blok IS NOT NULL
           AND btrim(u.blok) <> ''
           AND NOT EXISTS (
                 SELECT 1
                   FROM building_block b
                  WHERE b.tenant_id = u.tenant_id
                    AND b.ad = btrim(u.blok)
               )
        ON CONFLICT (tenant_id, ad) DO NOTHING
        """
    )


def downgrade() -> None:
    # GERI ALINMAZ ve alinmamali.
    #
    # Bu goc EKSIK bir kaydi tamamladi; onu "geri almak", onarilan
    # bloklari yeniden kayitsiz hale getirmek olurdu. Ustelik hangi
    # satirin bu goc tarafindan, hangisinin kullanici tarafindan
    # acildigini ayirt etmenin bir yolu YOK — silmeye kalkmak, elle
    # olusturulmus bloklari da goturme riski demekti.
    #
    # Bos `downgrade` bir ihmal degil bir KARAR: alembic zinciri geri
    # sarilabilir kalir, veri ise korunur.
    pass
