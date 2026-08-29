"""(P155 / §7) DAVET — jeton uretimi, bag kurma, gonderim.

Yonetici bir sakin/personel eklediginde bu modul devreye girer:
  1. o (parolasiz) hesap icin tek-kullanimlik bir jeton uretir,
  2. `davet` satirini olusturur/tazeler (jeton_hash saklanir, duz jeton
     yalniz bagda gecer),
  3. jetonlu bagi SMS (+varsa e-posta) ile gonderir ve sonucu hem
     `mesaj_gonderim`e (ayrintili gecmis) hem `davet.son_*`a (panel ozeti)
     yazar.

=== SAGLAYICI YOKKEN SESSIZ BASARISIZLIK YOK ===
Gonderim katmani (`gonderim.saglayici`) yapilandirilmamis saglayicida
`YapilandirilmamisSaglayici` doner ve `durum='basarisiz'` verir — bir
istisna FIRLATMAZ ama BASARILI da DONMEZ. Cagiran (residents/users/
ice_aktarim) bu sonucu sayar ve yoneticiye "N kisiye davet gonderilemedi"
bilgisini verir; yonetici tesis kodunu kopyalayip elle iletebilir.
Saglayici baglaninca KOD DEGISMEZ, yalniz ortam degiskeni.

=== I18N SINIRI ===
Davet SMS/e-posta metni TURKCEDIR (sartname §7 metni Turkce verdi ve
alicinin henuz secilmis bir uygulama dili YOKTUR — hesabi yeni aciliyor).
Bagin ACTIGI yuzeyler (web /davet sayfasi, mobil cozumleme ekrani) tam
i18n'dir; kullanici orada kendi dilini gorur.

=== SMS UZUNLUGU ===
Turkce karakter SMS'i 70 karaktere dusurur (`mesajlasma.sms_olc`). Davet
metni + ~68 karakterlik bag cogu durumda 2-3 parcaya bolunur; bu beklenen
ve kabul edilen bir maliyettir (bag kisaltilamaz — jeton tahmin edilemez
olmali). Olcum `mesaj_gonderim`e degil, yalniz gunluge yazilir.

(P155r2) Metne TESIS KODU ve MAGAZA BAGLANTILARI eklendi (sartname §4);
parca sayisi 3-5'e cikti. Takas ve neden kabul edildigi `davet_mesaji`
govdesinde yazili.
"""
from __future__ import annotations

import hashlib
import logging
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from .config import settings
from .davet_eposta import davet_eposta
from .gonderim import saglayici as kanal_saglayicisi, tenant_ayari
from .mesajlasma import sms_olc
from .models import AppUser, Davet, MesajGonderim

logger = logging.getLogger(__name__)

#: Jeton omru. 30 gun: ilk SMS'i haftalarca goz ardi eden bir sakinin bagi
#: hâlâ calissin diye uzun; sizmis bir bag sonsuza kadar yasamasin diye
#: sinirli. Yonetici yeniden gonderirse TAZE bir jeton uretilir (eski hash
#: uzerine yazilir, eski bag calismaz).
DAVET_OMRU_GUN = 30


def _jeton_uret() -> tuple[str, str]:
    """(duz_jeton, sha256_hex) — duz jeton yalniz bagda, hash veritabaninda."""
    duz = secrets.token_urlsafe(32)  # ~43 karakter, tahmin edilemez
    return duz, hashlib.sha256(duz.encode()).hexdigest()


def jeton_hashle(duz: str) -> str:
    """Cozme yolunda: gelen duz jetonu ayni bicimde hash'ler."""
    return hashlib.sha256(duz.encode()).hexdigest()


def davet_bagi(duz_jeton: str) -> str:
    """`https://<portal>/davet/<jeton>` — taban ortam degiskeninden.

    Taban `PORTAL_BASE_URL` ile ayarlanir (kod degismez); kanonik deger
    `https://yonetiyor.com`."""
    taban = settings.portal_base_url.rstrip("/")
    return f"{taban}/davet/{duz_jeton}"


def davet_mesaji(tenant_ad: str, bag: str, tesis_kodu: str | None = None) -> str:
    """Davet SMS/e-posta govdesi. Marka adi 'Yönetiyor' cevrilmez.

    (P155r2 / §4) UC SEY EKLENDI: TESIS KODU ve iki MAGAZA BAGLANTISI.
    Sartname bunlari acikca istiyor ("Eklenen kişilere SMS gitmeli:
    uygulama indirme bağlantıları (Android + iOS), TESİS KODU").

    NEDEN KOD DA GIDIYOR — bag zaten her seyi tasirken:
    bag TEK KULLANIMLIK ve SURELIDIR (30 gun). Suresi dolarsa, ya da
    kullanici mesaji baskasina iletip bag tuketilirse, elinde kalan tek
    sey koddur ve onunla elle kayit yolundan (`/auth/kayit/rol-basla`)
    devam edebilir. Kod ayrica yoneticinin telefonda okuyabilecegi
    seydir; bag degil.

    MAGAZA BAGLANTILARI KOSULLU: yalniz YAPILANDIRILMIS olan eklenir
    (bkz. `settings.app_store_url`). App Store id'si henuz yok; bos bir
    id ile kirik baglanti gondermek, hic gondermemekten kotudur.

    SMS UZUNLUGU — DURUSTCE: Turkce karakter SMS'i 70 karaktere dusurur.
    Bu metin kod + bag + bir/iki magaza baglantisiyla 3-5 parcaya boluner
    ve bu GERCEK bir maliyettir. Kabul edildi cunku alternatif (kodu ya
    da magazayi cikarmak) sartnamenin acik maddesini bosa dusururdu.
    Maliyeti dusurmenin dogru yolu bag KISALTMAKTIR (kendi alanimizda bir
    yonlendirici) ve bu ayri bir istir — burada yapilirsa jeton uzunlugu
    ile guvenlik arasinda aceleci bir takas yapilmis olurdu.
    """
    parcalar = [f"{tenant_ad} sizi Yönetiyor'a davet etti."]
    if tesis_kodu:
        parcalar.append(f"Tesis kodu: {tesis_kodu}")
    parcalar.append(f"Kaydolmak için: {bag}")
    if settings.play_store_url:
        parcalar.append(f"Android: {settings.play_store_url}")
    if settings.app_store_url:
        parcalar.append(f"iOS: {settings.app_store_url}")
    return " ".join(parcalar)


async def davet_olustur_veya_tazele(
    session: AsyncSession,
    *,
    user: AppUser,
    olusturan_id: uuid.UUID | None,
) -> tuple[Davet, str]:
    """Kullanicinin davetini olusturur ya da TAZELER; (davet, duz_jeton).

    KULLANICI BASINA TEK satir (`uq_davet_user`): yeniden gonderimde ayni
    satir yeni jeton_hash + yeni son_gecerlilik alir. Boylece eski bag
    gecersizlesir ve panel guncel durumu gosterir.
    """
    duz, jhash = _jeton_uret()
    son_gecerlilik = datetime.now(timezone.utc) + timedelta(days=DAVET_OMRU_GUN)

    davet = (
        await session.execute(select(Davet).where(Davet.user_id == user.id))
    ).scalar_one_or_none()
    if davet is None:
        davet = Davet(
            tenant_id=user.tenant_id,
            user_id=user.id,
            jeton_hash=jhash,
            son_gecerlilik=son_gecerlilik,
            olusturan_id=olusturan_id,
        )
        session.add(davet)
    else:
        davet.jeton_hash = jhash
        davet.son_gecerlilik = son_gecerlilik
        davet.used_at = None  # tazeleme => yeniden kullanilabilir
        davet.olusturan_id = olusturan_id
        davet.updated_at = datetime.now(timezone.utc)
    await session.flush()
    return davet, duz


async def davet_gonder(
    session: AsyncSession,
    *,
    davet: Davet,
    duz_jeton: str,
    user: AppUser,
    tenant_ad: str,
    gonderen_id: uuid.UUID | None,
    dil: str = "tr",
) -> bool:
    """Daveti E-POSTA (BIRINCIL) ile gonderir; SMS yalniz ETKINSE ek kanaldir.

    (P188) KANAL SIRASI DUZELTILDI. Kayit akisi E-POSTA TABANLIDIR: kisi Tesis
    ID'yi davet E-POSTASINDAN ogrenir. Onceden bu fonksiyon "SMS asil kanal"
    varsayiyor, SMS'i ONCE deniyor ve panel ozetini SMS sonucundan yaziyordu.
    `settings.sms_aktif=false` (prod) iken SMS saglayicisi `KapaliSms`tir ve
    "sms_kanali_kapali" doner; ozet SMS'e sabitlendigi icin davet e-postayla
    ULASMISKEN bile "basarisiz/kapali" gorunuyor, e-posta ise —bu kod HER ZAMAN
    e-posta da denese de— panelde GORUNMUYORDU. Sonuc: Tesis ID kimseye
    ulasmiyor, kimse kaydolamiyordu.

    Yeni kural:
      * E-POSTA BIRINCIL: hedef e-posta varsa DAIMA denenir; ozet ondan yazilir.
      * SMS yalniz `settings.sms_aktif` ISE denenir — kapaliyken HIC denenmez
        (kapali kanaldan denemek daveti yaniltici sekilde 'basarisiz' gosterir).
      * Birincil kanal (e-posta) yapilandirilmamis/basarisizsa ACIK WARNING
        loglanir (sessizce kaybolmasin) — davet ozeti zaten kaydedilir.

    (P155r2) TESIS KODU BURADA OKUNUYOR, cagirandan ISTENMIYOR: uc ayri
    cagiran (residents / users / davet-yeniden) var ve her birine bir
    parametre daha eklemek, birinde unutuldugunda SESSIZCE kodsuz gonderim
    yapardi. Tek okuma, tek kural.
    """
    bag = davet_bagi(duz_jeton)
    tesis_kodu = (
        await session.execute(
            text("SELECT kayit_kodu FROM tenant WHERE id = :t"),
            {"t": str(user.tenant_id)},
        )
    ).scalar_one_or_none()
    # SMS: KISA duz metin (SMS uzunlugu onemli). E-posta: ZENGIN HTML + duz
    # metin cifti (davet_eposta, 7 dil). Ikisi ayri govde uretir; kanal basina
    # dogru bicim gider.
    sms_govde = davet_mesaji(tenant_ad, bag, tesis_kodu)
    eposta_konu, eposta_metin, eposta_html = davet_eposta(
        dil=dil,
        tenant_ad=tenant_ad,
        tesis_kodu=tesis_kodu,
        bag=bag,
        play_store_url=settings.play_store_url,
        app_store_url=settings.app_store_url,
        yil=datetime.now(timezone.utc).year,
    )

    # (P172 §6) TESIS AYARI OKUNUYOR — ONCEDEN OKUNMUYORDU.
    #
    # Cagrilar `kanal_saglayicisi("sms")` seklindeydi, yani AYARSIZ: kendi
    # SMTP/SMS'ini arayuzden girmis bir tesisin DAVETLERI ENV'deki GENEL
    # saglayicidan gidiyordu. Tesis "ayarlarimi girdim" diyor, davetler
    # baskasinin hesabindan cikiyordu — ve hicbir yerde gorunmuyordu.
    ayar = await tenant_ayari(session, user.tenant_id)

    # --- E-POSTA (BIRINCIL — hedef varsa DAIMA) ---
    #
    # HTML govde ALTERNATIF olarak gecer; `eposta_metin` text/plain kokudur.
    # Gecmise (MesajGonderim) DUZ METIN yazilir: panel ozeti okunabilir kalsin
    # ve HTML iskeleti gecmis tablosunu sismesin.
    eposta = None
    if user.email:
        eposta = kanal_saglayicisi("eposta", ayar).gonder(
            user.email, eposta_konu, eposta_metin, html=eposta_html
        )
        session.add(MesajGonderim(
            tenant_id=user.tenant_id, sablon_id=None, kanal="eposta",
            amac="operasyonel", user_id=user.id, hedef=user.email, konu=eposta_konu,
            govde=eposta_metin, durum=eposta.durum, hata=eposta.hata,
            saglayici=eposta.saglayici, gonderen_user_id=gonderen_id,
            deneme=1,
        ))

    # --- SMS (YALNIZ SMS ETKINSE) ---
    #
    # `settings.sms_aktif=false` iken HIC DENENMEZ: kapali kanaldan denemek
    # yalnizca "sms_kanali_kapali" gurultusu uretir ve (eski kodda) daveti
    # basarisiz gosterirdi. SMS acilinca (tek satir SMS_AKTIF=true) burasi
    # ek kanal olarak devreye girer.
    sms = None
    if user.telefon and settings.sms_aktif:
        sms = kanal_saglayicisi("sms", ayar).gonder(user.telefon, None, sms_govde)
        session.add(MesajGonderim(
            tenant_id=user.tenant_id, sablon_id=None, kanal="sms",
            amac="operasyonel", user_id=user.id, hedef=user.telefon, konu=None,
            govde=sms_govde, durum=sms.durum, hata=sms.hata,
            saglayici=sms.saglayici, gonderen_user_id=gonderen_id,
            deneme=1,
        ))

    # --- Panel ozeti: BIRINCIL kanal E-POSTA ---
    #
    # BASARILI olan kanal yazilir; hicbiri basarili degilse BIRINCIL (e-posta)
    # sebebi yazilir ki "neden ulasmadi" panelde dogru kanaldan gorunsun —
    # e-posta hedefi yoksa (yalniz SMS'li eski kayit) SMS'e duser.
    ozet = next(
        (s for s in (eposta, sms) if s is not None and s.durum == "gonderildi"),
        None,
    ) or eposta or sms
    davet.son_kanal = "eposta" if ozet is eposta else "sms"
    davet.son_durum = ozet.durum if ozet else "basarisiz"
    davet.son_hata = ozet.hata if ozet else "hedef_yok"
    davet.son_gonderim_at = datetime.now(timezone.utc)

    # (P188) YAPILANDIRILMAMIS/BASARISIZ BIRINCIL KANAL SESSIZ KAYBOLMASIN.
    # Davet ozeti tabloya yaziliyor ama "kimse bakmiyordu"; birincil kanal
    # (e-posta) ulasmadiginda ACIK bir WARNING de duser (INFO log gorunur,
    # P134) — operator SMTP yapilandirmasini kontrol etsin.
    if eposta is not None and eposta.durum != "gonderildi":
        logger.warning(
            "[davet] E-POSTA ULASMADI tenant=%s user=%s durum=%s hata=%s "
            "— SMTP yapilandirmasini kontrol edin (davet gitmedi)",
            user.tenant_id, user.id, eposta.durum, eposta.hata,
        )
    elif eposta is None and sms is None:
        logger.warning(
            "[davet] HEDEF KANAL YOK tenant=%s user=%s — e-posta bos ve SMS "
            "kapali; davet gonderilemedi", user.tenant_id, user.id,
        )
    await session.flush()
    # DONUS: HERHANGI BIR kanaldan ulasti mi. Cagiranlar bunu "davet
    # gitti mi" diye okuyor; SMS'e sabitlemek, e-postayla ulasan daveti
    # basarisiz saymak olurdu.
    return ozet is not None and ozet.durum == "gonderildi"


async def davet_olustur_ve_gonder(
    session: AsyncSession,
    *,
    user: AppUser,
    tenant_ad: str,
    gonderen_id: uuid.UUID | None,
    dil: str = "tr",
) -> bool:
    """Kolaylik: olustur/tazele + gonder. Donus: davet ULASTI mi (birincil
    kanal E-POSTA; SMS yalniz etkinse ek kanal — bkz. davet_gonder).

    HESAP PAROLASIZ OLMALI: davet, hesabi SAHIPLENDIRME bagidir. Parolasi
    olan hesaba davet gondermek anlamsiz (zaten girebiliyor); cagiran bu
    kosulu saglar.

    `dil`: davet E-POSTASININ dili (alicinin secilmis dili yok; ekleyen
    yoneticinin istek dili en iyi sinyal, varsayilan tr). SMS her zaman kisa
    Turkce metindir (uzunluk).
    """
    davet, duz = await davet_olustur_veya_tazele(
        session, user=user, olusturan_id=gonderen_id
    )
    return await davet_gonder(
        session, davet=davet, duz_jeton=duz, user=user,
        tenant_ad=tenant_ad, gonderen_id=gonderen_id, dil=dil,
    )
