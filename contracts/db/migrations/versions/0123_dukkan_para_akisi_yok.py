"""(DUKKAN F8a) PARA AKISI YOK — `anlasmazlik` durumu KALDIRILIYOR.

===========================================================================
GELIR MODELI DEGISTI
===========================================================================
Platform hizmet bedeline HIC DOKUNMUYOR. Sakin ustayla dogrudan iletisime
geciyor, parayi dogrudan oduyor. Siparis, satin alma, komisyon YOK. Tek
gelir: isletmelerin gorunurluk (reklam) icin odedigi bedel — o da
DOGRUDAN SATIS, aracilik degil.

Bu, "V1'de odeme yok, V2'de gelir" ertelemesinden FARKLI bir sey:
hizmet bedeli akisi artik ASLA gelmiyor.

===========================================================================
`anlasmazlik` NEDEN CIKIYOR
===========================================================================
`is_kaydi.durum` icinde bir `anlasmazlik` degeri vardi. Hicbir uc onu
yazmiyordu; yalniz `is_tamamlandi` ucu "kapali" sayiyordu. Yani OLU bir
deger — ama olu olmasi zararsiz oldugu anlamina gelmiyor:

  * Bir anlasmazlik DURUMU tutmak, platformun taraflar arasinda HAKEMLIK
    ettigini ima eder. Platform sozlesmenin tarafi degil.
  * Kullanicida "platform cozer" beklentisi yaratir. O beklenti
    karsilanmayinca sikayet, karsilanirsa da ustlenilmemis bir
    sorumluluk dogar.
  * Hukuki olarak aleyhe yorumlanabilir: bir uyusmazlik surecini
    isleten platform, ilan/eslestirme hizmetinden fazlasini yapiyor
    gorunur.

Memnun olmayan kullanicinin yolu ZATEN VAR ve ayri: yorum yazar ya da
sikayet acar (`sikayet` tablosu, F5). Mekanizma o.

===========================================================================
VERI KAYBI YOK — OLCULDU
===========================================================================
`upgrade` once bu durumda satir olup olmadigina bakiyor; VARSA GOC
DURUYOR (hata firlatir). Sessizce 'iptal'e cevirmek, bir kullanicinin
acik sorununu kayit disi birakirdi. Bugun prod'da sifir satir bekleniyor
(hicbir uc yazmiyor) ama "beklenen" ile "olculen" ayni sey degildir.

GERI ALINABILIR: downgrade degeri CHECK'e geri ekler.
"""
from alembic import op
import sqlalchemy as sa

revision = "0123_dukkan_para_akisi_yok"
down_revision = "0122_dukkan_davet_gonderim_izi"
branch_labels = None
depends_on = None

SEMA = "dukkan"


def upgrade() -> None:
    baglanti = op.get_bind()
    kalan = baglanti.execute(
        sa.text(f"SELECT count(*) FROM {SEMA}.is_kaydi "
                "WHERE durum = 'anlasmazlik'")
    ).scalar_one()
    if kalan:
        raise RuntimeError(
            f"{kalan} is kaydi 'anlasmazlik' durumunda. Goc DURDU: bu "
            "satirlarin ne yapilacagi bir URUN karari, goc karari degil. "
            "Elle inceleyip 'iptal' ya da 'tamamlandi'ya cevirin."
        )

    op.execute(
        f"ALTER TABLE {SEMA}.is_kaydi DROP CONSTRAINT IF EXISTS is_kaydi_durum_check;"
    )
    op.execute(
        f"ALTER TABLE {SEMA}.is_kaydi ADD CONSTRAINT is_kaydi_durum_check "
        "CHECK (durum IN ('kabul','devam','tamamlandi','iptal'));"
    )
    # KISITIN GEREKCESI VERITABANINDA DA DURSUN: bu tabloya bakan bir
    # gelistirici, kodu okumadan da neyin YASAK oldugunu gorsun.
    op.execute(
        f"COMMENT ON TABLE {SEMA}.is_kaydi IS "
        "'Eslesme kaydi — SOZLESME DEGIL. Platform hizmet bedeline "
        "dokunmaz; odeme, fatura, iade ve hakemlik YOKTUR. Bu tabloya "
        "tahsilat/komisyon alani eklemek platformu 6563 anlaminda araci "
        "hizmet saglayici konumuna tasir; hukuki gorus almadan eklemeyin. "
        "Bkz. docs/dukkan/00-mimari.md';"
    )
    op.execute(
        f"COMMENT ON COLUMN {SEMA}.teklif.tutar_kurus IS "
        "'BEYAN — odeme degil. Isletmenin bildirdigi fiyat bilgisi; "
        "platform tahsil etmez. NULL = yerinde gorulmesi gerekiyor.';"
    )


def downgrade() -> None:
    op.execute(
        f"ALTER TABLE {SEMA}.is_kaydi DROP CONSTRAINT IF EXISTS is_kaydi_durum_check;"
    )
    op.execute(
        f"ALTER TABLE {SEMA}.is_kaydi ADD CONSTRAINT is_kaydi_durum_check "
        "CHECK (durum IN ('kabul','devam','tamamlandi','iptal','anlasmazlik'));"
    )
