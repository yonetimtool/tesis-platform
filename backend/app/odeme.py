"""(DUKKAN F8c) ODEME SAGLAYICI SOYUTLAMASI — sanal POS.

===========================================================================
NEDEN BU DOSYA SAGLAYICIYI BILMIYOR
===========================================================================
Sanal POS saglayicisi HENUZ SECILMEDI ve basvuru sirket kurulumuna bagli;
onay haftalar surebilir. Kod o gune kadar beklerse, gelir modelinin
tamami tek bir dis bagimliliga kilitlenir.

Bu yuzden `mesajlasma.py`deki SMS kalibi BIREBIR izleniyor:
  * soyut taban sinif + saglayici basina bir alt sinif,
  * TEK SECIM NOKTASI (`odeme_saglayicisi()`),
  * taninmayan/eksik yapilandirmada "KAPALI" saglayici — cokmez ama
    "odendi" DE DEMEZ.

Saglayici secildiginde yapilacak is BIR SINIF (bkz.
docs/dukkan/08-odeme-saglayici-karsilastirma.md §5).

===========================================================================
"SESSIZCE ODENDI DEME" — P191/SMS DERSININ ODEMEDEKI KARSILIGI
===========================================================================
SMS turunde olculen kusur suydu: yanit `{"gonderildi": true, "gonderim":
"saglayici_bagli_degil"}` donuyordu ve iki alan CELISIYORDU.

Odemede ayni kusurun bedeli cok daha agir: "odendi" diyen bir yanit,
reklami YAYINA ALIR ve platform parasini hic almadan hizmet verir. Daha
kotusu, isletme odedigini sanir.

Bu yuzden:
  * `OdemeSonucu.basarili` YALNIZCA saglayici islemi KABUL ettiginde True.
  * Saglayici bagli degilse `durum='yapilandirilmadi'` ve uc **503** doner
    (200 + `basarili: false` DEGIL — istemci basarili yanit dalina girip
    "odeme alindi" ekrani gosterirdi).
  * Hicbir kod yolu, saglayiciya SORMADAN reklam acmaz.

===========================================================================
KART BILGISI HICBIR KOSULDA BIZDE TUTULMAZ
===========================================================================
Bu dosyada kart numarasi, CVV ya da son kullanma tarihi TASIYAN hicbir
alan YOK — ve olmamali. Akis:

  1. Kullanici kart bilgisini SAGLAYICININ sayfasinda/alanlarinda girer.
  2. Saglayici bize bir TOKEN doner.
  3. Biz yalniz token'i saklariz (`dukkan.odeme_yontemi`).

Tekrarlayan cekim o token ile yapilir. Token calinsa bile baska bir
uye isyerinde kullanilamaz — kart numarasinin aksine.

Kilit: `test_dukkan_odeme.py::test_KART_ALANI_HICBIR_TABLODA_YOK`.

===========================================================================
TEKRARLAYAN ODEME (RECURRING) ALTYAPIDA VAR — URUNDE VARSAYILAN DEGIL
===========================================================================
Iki ayri karar, karistirilmamali:

  * ALTYAPI tekrarlayan cekimi DESTEKLER (`sakli_kartla_cek`). Abonelik
    ve reklam ayni altyapiyi kullanir — istegin sarti.
  * REKLAM URUNU varsayilan olarak TEK SEFERLIKTIR ve otomatik yenileme
    KAPALIDIR (F8b karari: sessizce kart cekmek en cok sikayet ureten
    seydir). Isletme isterse yenileme acabilir; acmadikca cekilmez.

Yani "recurring destegi yok" degil; "recurring VARSAYILAN degil".
"""
from __future__ import annotations

import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

#: Saglayiciya HIC SORULMADI durumu — "basarili" da "basarisiz" da degil.
#: `mesajlasma.DURUM_YAPILANDIRILMADI` ile ayni kavram, ayni ad.
DURUM_YAPILANDIRILMADI = "yapilandirilmadi"

#: Kurus ust siniri — Yonetiyor'da para alanlarinda kullanilan sinirla
#: ayni fikir: bir yazim hatasi (fazladan sifir) veritabanina girmeden
#: once yakalansin.
KURUS_UST_SINIRI = 100_000_000_00  # 100 milyon TL


@dataclass(frozen=True)
class OdemeSonucu:
    """Bir cekim denemesinin sonucu.

    `basarili` ve `durum` ASLA CELISMEZ: `basarili=True` yalnizca
    `durum='basarili'` iken. Ikisini ayri tutmanin sebebi, basarisizligin
    SEBEBININ istemci icin farkli anlamlar tasimasi:

      'basarili'          -> tahsil edildi
      'yapilandirilmadi'  -> saglayici bagli degil (503; tekrar denemek
                             ise yaramaz, operator ilgilenmeli)
      'reddedildi'        -> banka/kart reddetti (kullanici baska kart
                             deneyebilir)
      'dogrulama_gerekli' -> 3DS; `yonlendirme_url` dolu
      'hata'              -> ag/saglayici hatasi (tekrar denenebilir)
    """
    durum: str
    saglayici: str
    #: Saglayicidaki islem kimligi — iade ve mutabakat icin ZORUNLU iz.
    islem_id: str | None = None
    #: 3DS yonlendirmesi gerekiyorsa doldurulur.
    yonlendirme_url: str | None = None
    hata: str | None = None
    #: Saglayicinin ham hata kodu (destek yazismasinda gerekiyor).
    saglayici_kodu: str | None = None

    @property
    def basarili(self) -> bool:
        return self.durum == "basarili"


@dataclass(frozen=True)
class KartSonucu:
    """Kart saklama denemesinin sonucu.

    KART NUMARASI YOK — bilerek. Yalniz token ve GOSTERIM icin son dort
    hane + marka. Son dort hane PCI kapsaminda saklanabilir ve kullanici
    "hangi kart" sorusunu ancak onunla yanitlar.
    """
    durum: str
    saglayici: str
    kart_token: str | None = None
    kullanici_token: str | None = None
    son_dort: str | None = None
    marka: str | None = None
    hata: str | None = None

    @property
    def basarili(self) -> bool:
        return self.durum == "basarili"


class OdemeSaglayici(ABC):
    ad: str

    @abstractmethod
    def odeme_baslat(
        self,
        *,
        tutar_kurus: int,
        aciklama: str,
        siparis_no: str,
        donus_url: str,
        alici: dict[str, str],
    ) -> OdemeSonucu:
        """Tek seferlik odeme baslatir.

        `alici`: fatura icin gereken bilgiler (unvan, vkn, adres...).
        Kart bilgisi ICERMEZ — kullanici onu saglayicinin sayfasinda
        girer.
        """

    @abstractmethod
    def kart_sakla(
        self, *, kullanici_token: str | None, kart_takma_ad: str,
        donus_url: str,
    ) -> KartSonucu:
        """Kart saklama akisini baslatir. Doner: token(lar).

        Kart alanlari PARAMETRE DEGIL: bu imza, kart bilgisinin bizim
        surecimizden GECMEDIGINI tip duzeyinde soyluyor.
        """

    @abstractmethod
    def sakli_kartla_cek(
        self,
        *,
        kart_token: str,
        kullanici_token: str,
        tutar_kurus: int,
        aciklama: str,
        siparis_no: str,
    ) -> OdemeSonucu:
        """Saklanmis kartla cekim — TEKRARLAYAN ODEMENIN temeli."""

    @abstractmethod
    def iade(self, *, islem_id: str, tutar_kurus: int) -> OdemeSonucu:
        """Kismi ya da tam iade."""

    def yapilandirildi_mi(self) -> bool:
        """Saglayici gercekten cekim yapabilir durumda mi?

        Varsayilan `True`; `KapaliOdemeSaglayici` `False` doner. Uclar
        buna bakip 503 donuyor — kullanici odeme formunu ACMADAN once
        durumu ogrensin diye.
        """
        return True


class KapaliOdemeSaglayici(OdemeSaglayici):
    """SAGLAYICI YOK — hicbir sey tahsil etmez ve BUNU SOYLER.

    Varsayilan budur. Sanal POS basvurusu onaylanana kadar prod'da bu
    calisir; reklam satin alma ucu 503 `odeme_yapilandirilmadi` doner ve
    arayuz "odeme henuz acilmadi" der.

    NEDEN "BASARILI" DONMUYOR (dev'de bile): dev'de basarili donen bir
    sahte saglayici, akisi test etmeyi kolaylastirirdi — ama ayni sinif
    prod'a bir yapilandirma hatasiyla dusebilirdi ve platform parasini
    hic almadan reklam yayinlardi. Dev icin AYRI ve ADI ACIKCA SAHTE olan
    bir saglayici var (`SahteOdemeSaglayici`), varsayilan DEGIL.
    """
    ad = "odeme-kapali"

    def yapilandirildi_mi(self) -> bool:
        return False

    def _sonuc(self) -> OdemeSonucu:
        logger.warning(
            "ODEME saglayici YOK -> hicbir tahsilat yapilmadi | "
            "ODEME_SAGLAYICI bos: reklam satin alma 503 doner"
        )
        return OdemeSonucu(
            durum=DURUM_YAPILANDIRILMADI, saglayici=self.ad,
            hata="saglayici_yok",
        )

    def odeme_baslat(self, **_kw) -> OdemeSonucu:
        return self._sonuc()

    def kart_sakla(self, **_kw) -> KartSonucu:
        return KartSonucu(durum=DURUM_YAPILANDIRILMADI, saglayici=self.ad,
                          hata="saglayici_yok")

    def sakli_kartla_cek(self, **_kw) -> OdemeSonucu:
        return self._sonuc()

    def iade(self, **_kw) -> OdemeSonucu:
        return self._sonuc()


@dataclass
class SahteOdemeSaglayici(OdemeSaglayici):
    """DEV/TEST — gercekten cekmez ama akisi SURULEBILIR kilar.

    ADI ACIKCA SAHTE ve varsayilan DEGIL: `ODEME_SAGLAYICI=sahte`
    yazilmadikca devreye girmez. Prod'da bu deger yazilirsa loglar her
    islemde uyarir.

    `reddet_tutari`: belirli bir tutarda REDDEDER — basarisiz odeme
    dalinin da surulebilmesi icin. Basarisizlik yolunu test edememek,
    onu ilk gercek hatada ogrenmek demektir.
    """
    ad: str = "sahte"
    reddet_tutari: int | None = None
    cagrilar: list[dict] = field(default_factory=list)

    def _kayit(self, tur: str, **kw) -> None:
        self.cagrilar.append({"tur": tur, **kw})

    def odeme_baslat(self, *, tutar_kurus, aciklama, siparis_no,
                     donus_url, alici) -> OdemeSonucu:
        logger.warning("ODEME SAHTE saglayici: %s kurus (siparis=%s) — "
                       "GERCEK TAHSILAT YOK", tutar_kurus, siparis_no)
        self._kayit("odeme_baslat", tutar_kurus=tutar_kurus,
                    siparis_no=siparis_no)
        if self.reddet_tutari is not None and tutar_kurus == self.reddet_tutari:
            return OdemeSonucu(durum="reddedildi", saglayici=self.ad,
                               hata="yetersiz_bakiye",
                               saglayici_kodu="TEST-51")
        return OdemeSonucu(durum="basarili", saglayici=self.ad,
                           islem_id=f"sahte-{siparis_no}")

    def kart_sakla(self, *, kullanici_token, kart_takma_ad,
                   donus_url) -> KartSonucu:
        self._kayit("kart_sakla", takma_ad=kart_takma_ad)
        return KartSonucu(
            durum="basarili", saglayici=self.ad,
            kart_token=f"sahte-kart-{kart_takma_ad}",
            kullanici_token=kullanici_token or "sahte-kullanici",
            son_dort="4242", marka="visa",
        )

    def sakli_kartla_cek(self, *, kart_token, kullanici_token, tutar_kurus,
                         aciklama, siparis_no) -> OdemeSonucu:
        self._kayit("sakli_kartla_cek", tutar_kurus=tutar_kurus,
                    kart_token=kart_token, siparis_no=siparis_no)
        if self.reddet_tutari is not None and tutar_kurus == self.reddet_tutari:
            return OdemeSonucu(durum="reddedildi", saglayici=self.ad,
                               hata="yetersiz_bakiye",
                               saglayici_kodu="TEST-51")
        return OdemeSonucu(durum="basarili", saglayici=self.ad,
                           islem_id=f"sahte-{siparis_no}")

    def iade(self, *, islem_id, tutar_kurus) -> OdemeSonucu:
        self._kayit("iade", islem_id=islem_id, tutar_kurus=tutar_kurus)
        return OdemeSonucu(durum="basarili", saglayici=self.ad,
                           islem_id=f"iade-{islem_id}")


def odeme_saglayicisi() -> OdemeSaglayici:
    """Odeme saglayicisi — TEK SECIM NOKTASI.

    Doner: `OdemeSaglayici` ornegi.

    Taninmayan ya da bos ad `KapaliOdemeSaglayici`ya duser: cokmez, ama
    "odendi" DE DEMEZ. Bu, `mesajlasma.dukkan_sms_saglayicisi()` ile ayni
    kalip ve ayni gerekce.

    SAGLAYICI SECILDIGINDE: buraya bir `if ad == "iyzico"` dali ve
    `app/odeme_iyzico.py` eklenecek. Baska hicbir yer degismeyecek —
    reklam, abonelik, fatura ve bildirim kodu saglayicidan habersiz.
    """
    from .config import settings

    ad = (getattr(settings, "odeme_saglayici", "") or "").strip().lower()
    if ad == "sahte":
        return SahteOdemeSaglayici()
    if ad:
        # TANINMAYAN AD SESSIZ GECMEZ: yapilandirma hatasi, gelir
        # kaybina donusmeden once loglanir.
        logger.error(
            "ODEME_SAGLAYICI='%s' TANINMIYOR -> odeme KAPALI. "
            "Gecerli degerler: (bos), 'sahte'. Saglayici entegrasyonu "
            "docs/dukkan/08-odeme-saglayici-karsilastirma.md §5'te.", ad,
        )
    return KapaliOdemeSaglayici()
