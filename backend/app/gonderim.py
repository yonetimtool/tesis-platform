"""(P154 / Asama 9) ORTAK GONDERIM KATMANI — kanal secimi TEK YERDE.

===========================================================================
NEDEN BU MODUL — olculen kusur
===========================================================================
Gonderim yollari BIRBIRINDEN HABERSIZ buyumustu:

  * SMS'in secimi `mesajlasma.sms_saglayicisi()` ile TEK YERDEYDI (P150),
  * E-POSTA'nin secimi `routers/mesajlar.py::_saglayici()` icine GOMULUYDU
    — yani ikinci bir yol e-posta gondermek isteseydi SMTP yapilandirmasini
    ORADAN kopyalamak zorunda kalirdi,
  * PUSH tamamen ayri bir yoldu (`push.py` + `user_device`),
  * WHATSAPP hic yoktu.

Sonuc: brief'in "ortak gonderim arayuzu (kanal: sms | whatsapp | email |
push), saglayici eklentisi takilabilir olsun" maddesi kismen vardi ama
GIRIS NOKTASI yoktu. Bu modul o giris noktasidir.

===========================================================================
KOD KATMANINDA DORT KANAL, VERI KATMANINDA BUGUN IKI — bilincli sinir
===========================================================================
`mesaj_kanal` enum'u bugun `sms, eposta` tasiyor. `whatsapp` ve `push`
enum'a EKLENMEDI ve bu bir eksiklik degil, bir karar:

  * WHATSAPP saglayicisi HENUZ SECILMEDI (brief'in kendi notu). Enum'a
    deger eklemek kolaydir; GERI ALMAK degildir — `goc-tersinirlik.sh`
    downgrade sonrasi semayi karsilastiriyor ve artik kalan bir enum
    degeri o kapiyi kirar. Gonderemedigimiz bir kanal icin geri
    alinamayan bir sema degisikligi yapmak, borcu pesin odemek olurdu.
  * PUSH'un adresleme modeli FARKLI (cihaz jetonu, tek bir `hedef` dizesi
    degil) ve kendi tablosu var. Buradaki adaptor onu ayni ARAYUZE
    baglar; `mesaj_gonderim` tablosuna yazmak ayri bir istir.

Yani: `saglayici("whatsapp")` BUGUN de cagrilabilir ve NET bir
"yapilandirilmadi" sonucu doner — sessizce basarili DONMEZ. Kanal
acildiginda yapilacak tek is bir saglayici sinifi + bir goc.

===========================================================================
GUNLUK KOTA — neden veritabanindan sayiliyor
===========================================================================
Brief: "tesis basina gunluk kota". Sayac Redis'te tutulabilirdi (hiz
siniri oyle yapiyor) ama kota FATURA ile ilgilidir: Redis dustugunde
sayac sifirlanir ve o gun kota SINIRSIZ olurdu. `mesaj_gonderim` zaten
her gonderimi yaziyor; dogru sayi ORADA. Hiz siniri ile kota farkli
seylerdir ve farkli kaynaklardan beslenmeleri dogrudur:
  * hiz siniri  -> kotu niyetli/kacak trafigi keser, hizli olmali,
  * gunluk kota -> maliyeti sinirlar, DOGRU olmali.
"""
from __future__ import annotations

import logging
import uuid
from datetime import date, datetime, time, timezone
from typing import Literal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .config import settings
from .errors import APIError
from .mesajlasma import (
    GonderimSonucu,
    LogEpostaSaglayici,
    MesajSaglayici,
    SmtpEpostaSaglayici,
    DURUM_YAPILANDIRILMADI,
    SaglayiciAyari,
    _ayardan_veya_env,
    sms_saglayicisi,
)

logger = logging.getLogger(__name__)

#: Brief'in kanal kumesi. `eposta` (Turkce) kullaniliyor cunku veritabani
#: enum'u ve mevcut sablonlar bu adi tasiyor; ingilizce `email` ile iki ad
#: tasimak, hangisinin dogru oldugunu her cagrida sorduran bir belirsizlik
#: uretirdi.
Kanal = Literal["sms", "eposta", "whatsapp", "push"]

KANALLAR: tuple[Kanal, ...] = ("sms", "eposta", "whatsapp", "push")

#: Bugun GERCEKTEN gonderebildigimiz kanallar. `mesaj_kanal` enum'uyla
#: AYNI kume olmali; ayrisirsa `test_gonderim_katmani` duser.
ETKIN_KANALLAR: tuple[Kanal, ...] = ("sms", "eposta")

#: Tesis basina GUNLUK gonderim ust siniri (tum kanallar toplami).
#: Yapilandirmadan ezilebilir; varsayilan bir SITE'nin makul gunluk
#: hacminden (birkac yuz daire x birkac bildirim) belirgin sekilde yuksek
#: secildi — kota bir GUVENLIK AGIDIR, gunluk isi engellememeli.
GUNLUK_KOTA = 2000

KOTA_ASILDI = APIError(429, "rate_limited", "gunluk_mesaj_kotasi_doldu")


class YapilandirilmamisSaglayici(MesajSaglayici):
    """Kanal TANIMLI ama saglayicisi YOK.

    SESSIZCE BASARILI DONMEZ — bu sinifin tum varlik sebebi budur.
    "gonderildi" demek, panelde gonderilmemis bir mesaji gonderilmis gibi
    gostermek ve kullaniciyi "neden ulasmadi" diye aramaya birakmak olurdu.
    """

    def __init__(self, kanal: str) -> None:
        self.ad = f"{kanal}-yapilandirilmadi"
        self._kanal = kanal

    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None) -> GonderimSonucu:
        logger.warning(
            "[%s] saglayici yapilandirilmadi — gonderim YAPILMADI", self._kanal
        )
        # (P168 §4) `basarisiz` DEGIL `yapilandirilmadi`: basarisizlik
        # "denedik, olmadi" der ve kullaniciyi "tekrar dene"ye iter.
        # Burada HIC DENENMEDI; yapilmasi gereken AYARLARI doldurmaktir.
        return GonderimSonucu(
            DURUM_YAPILANDIRILMADI, self.ad, hata="saglayici_yok"
        )


def eposta_saglayicisi(ayar: SaglayiciAyari | None = None) -> MesajSaglayici:
    """E-POSTA saglayicisi — TEK SECIM NOKTASI (SMS'teki desenin aynisi).

    Secim `routers/mesajlar.py` icinden BURAYA tasindi: orada kaldigi
    surece e-posta gondermek isteyen ikinci bir yol (orn. gecici kod)
    SMTP yapilandirmasini kopyalamak zorundaydi ve biri guncellenip oteki
    unutulurdu.
    """
    # (P168 §4) TESIS AYARI ONCE, ENV YEDEK.
    a = _ayardan_veya_env(ayar)
    if not a.smtp_host:
        return LogEpostaSaglayici()
    return SmtpEpostaSaglayici(
        a.smtp_host,
        int(a.smtp_port or 587),
        a.smtp_kullanici,
        a.smtp_parola,
        a.smtp_gonderen or "no-reply@localhost",
    )


async def tenant_ayari(
    db: AsyncSession, tenant_id: uuid.UUID
) -> SaglayiciAyari | None:
    """Tesisin saglayici ayarini `SaglayiciAyari`ya cevirir.

    Kayit yoksa `None` doner ve cagiran ENV'e duser — gonderim yolunun
    TEK bilmesi gereken sey bu.

    =======================================================================
    (P172 §1) BURAYA TASINDI — ONCEDEN `routers/mesajlar.py` ICINDEYDI
    =======================================================================
    Orada kaldigi surece gonderim yapan OTEKI yollar (davet, mesaj
    kuyrugu, dogrulama kodu) onu cagiramiyordu: cekirdek bir modulun bir
    router'i ithal etmesi ters bagimliliktir. Sonucu OLCULDU ve ciddiydi —
    o uc yol `kanal_saglayicisi(...)`yi AYARSIZ cagiriyordu, yani kendi
    SMTP/SMS'ini girmis bir tesisin davetleri ve yeniden denemeleri
    ENV'deki GENEL saglayicidan gidiyordu. Tesis "ayarlarimi girdim"
    diyor, mesajlar baskasinin hesabindan cikiyordu.
    """
    from .models import MesajYapilandirma

    y = await db.get(MesajYapilandirma, tenant_id)
    if y is None:
        return None
    return SaglayiciAyari(
        sms_saglayici=y.sms_saglayici,
        sms_kullanici=y.sms_kullanici,
        sms_parola=y.sms_parola,
        sms_baslik=y.sms_baslik,
        smtp_host=y.smtp_host,
        smtp_port=y.smtp_port,
        smtp_kullanici=y.smtp_kullanici,
        smtp_parola=y.smtp_parola,
        smtp_gonderen=y.smtp_gonderen,
    )


def saglayici(kanal: str, ayar: SaglayiciAyari | None = None) -> MesajSaglayici:
    """Kanal -> saglayici. TEK giris noktasi.

    Bilinmeyen kanal da `YapilandirilmamisSaglayici` doner (istisna
    firlatmaz): cagiran genelde bir DONGU icindedir ve tek bir bozuk
    satirin kalan 200 aliciyi dusurmemesi gerekir. Sonuc `basarisiz`
    yazilir, yani kusur GECMISTE gorunur.
    """
    if kanal == "sms":
        return sms_saglayicisi(ayar)
    if kanal == "eposta":
        return eposta_saglayicisi(ayar)
    if kanal == "push":
        return _PushAdaptor()
    return YapilandirilmamisSaglayici(kanal)


class _PushAdaptor(MesajSaglayici):
    """PUSH'u ortak arayuze baglar.

    `hedef` burada bir ADRES DEGIL, `app_user.id`dir: push'un adresi
    kullanicinin CIHAZLARIDIR ve onlar `user_device` tablosunda durur.
    Arayuzu bozmadan bunu ifade etmenin yolu, hedefi kimlik olarak
    yorumlamaktir; bu yuzden burada acikca yaziyor.

    Gonderim `push.py`deki mevcut yola devreder — ikinci bir FCM istemcisi
    YAZILMAZ.
    """

    ad = "push"

    def gonder(self, hedef: str, konu: str | None, govde: str, html: str | None = None) -> GonderimSonucu:
        # Senkron arayuz, asenkron push: `mesajlasma.MesajSaglayici`
        # senkrondur (SMS/SMTP oyle). Push'u buradan senkron cagirmak
        # olay dongusunu bloklardi. Bu yuzden ADAPTOR BUGUN KUYRUGA
        # YAZMAZ, cagirana "bu kanal ayri yoldan gonderilir" der.
        # Kanali ARAYUZE baglamak, onu bugun bu arayuzden GONDERMEK
        # demek degil; ayrimi gizlemek yerine yaziyoruz.
        logger.info("[push] ortak arayuzden cagrildi; asil yol push.py")
        return GonderimSonucu("basarisiz", self.ad, hata="ayri_yol")


async def gunluk_kalan(session: AsyncSession, tenant_id: uuid.UUID) -> int:
    """Tesisin BUGUN kac gonderim hakki kaldi.

    Gun siniri UTC degil YEREL GUN olmali — kota "bugun" derken
    kullanicinin gununu kastediyor. `tenant.timezone` var ama saat dilimi
    cozumlemesini buraya tasimak bu turun isi degil; bugunluk UTC gun
    basi kullaniliyor ve bu SINIR YAZILI (bkz. dosya sonu notu).
    """
    from .models import MesajGonderim, MesajYapilandirma

    # (P168 §4.4) KOTA ARTIK TESIS BASINA AYARLANABILIR. Kayit yoksa ya da
    # bos birakilmissa ENV varsayilani gecerli — ayar sayfasi doldurulmamis
    # bir tesiste kotanin SIFIRA dusmesi, hicbir mesaj gonderilememesi
    # demekti.
    ayarli = (
        await session.execute(
            select(MesajYapilandirma.gunluk_kota).where(
                MesajYapilandirma.tenant_id == tenant_id
            )
        )
    ).scalar_one_or_none()
    sinir = ayarli or GUNLUK_KOTA

    gun_basi = datetime.combine(date.today(), time.min, tzinfo=timezone.utc)
    # `yapilandirilmadi` SAYILMAZ: hicbir sey gonderilmediyse kotadan da
    # dusmemeli — yoksa ayarlari doldurmamis bir tesis, hic mesaj
    # gondermeden kotasini tuketirdi.
    sayi = (
        await session.execute(
            select(func.count())
            .select_from(MesajGonderim)
            .where(
                MesajGonderim.tenant_id == tenant_id,
                MesajGonderim.created_at >= gun_basi,
                MesajGonderim.durum != "yapilandirilmadi",
            )
        )
    ).scalar_one()
    return max(0, sinir - int(sayi))


async def kota_kontrol(
    session: AsyncSession, tenant_id: uuid.UUID, istenen: int
) -> None:
    """Kota yetmiyorsa 429 — gonderim BASLAMADAN.

    YARIM GONDERIM YERINE HIC: 300 kisilik bir listede 50. alicida kotaya
    takilmak, kime gidip kime gitmedigini kullaniciya aciklamasi zor bir
    durum birakirdi. Kontrol basta yapilir ve istek TUMDEN reddedilir.
    """
    if istenen <= 0:
        return
    if await gunluk_kalan(session, tenant_id) < istenen:
        raise KOTA_ASILDI


# ---------------------------------------------------------------------------
# BILINEN SINIRLAR (bilerek acik birakildi, gizlenmedi)
#
# 1. Kota gunu UTC gun basindan sayiyor; `tenant.timezone` dikkate
#    alinmiyor. Turkiye icin fark UTC+3'tur, yani gece 00:00-03:00 arasi
#    gonderimler "dunun" kotasina yazilir. Duzeltmek tenant saat dilimini
#    bu katmana tasimayi gerektirir.
# 2. KUYRUK + YENIDEN DENEME YOK. `mesaj_durum` enum'unda `kuyrukta`
#    degeri VAR ama bugun hicbir yol onu yazmiyor: gonderim ISTEK ICINDE
#    senkron yapiliyor. Kuyruga gecmek Celery isi ekler ve gonderim
#    kaydinin durum gecislerini (kuyrukta -> gonderildi/basarisiz)
#    degistirir; ayri bir adim olarak birakildi.
# 3. WhatsApp ve push `mesaj_kanal` enum'unda YOK (bkz. modul basligi).
# ---------------------------------------------------------------------------
