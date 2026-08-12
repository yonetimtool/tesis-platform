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
"""
from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .config import settings
from .gonderim import saglayici as kanal_saglayicisi
from .mesajlasma import sms_olc
from .models import AppUser, Davet, MesajGonderim

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

    Test → `test.yonetio.site`, prod → `yonetiyor.com`; ikisi de
    `PORTAL_BASE_URL` ile ayarlanir (kod degismez)."""
    taban = settings.portal_base_url.rstrip("/")
    return f"{taban}/davet/{duz_jeton}"


def davet_mesaji(tenant_ad: str, bag: str) -> str:
    """Sartname §7 metni. Marka adi 'Yönetio' cevrilmez."""
    return f"{tenant_ad} sizi Yönetio'ya davet etti. Kaydolmak için: {bag}"


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
) -> bool:
    """Bagi SMS (+varsa e-posta) ile gonderir; kayitlari yazar.

    SMS ASIL KANAL (telefon her zaman var); e-posta VARSA ek olarak gider.
    Donus: SMS gonderildi mi (panel "gitmeyen davetler" bunu kullanir —
    e-posta bonustur, SMS asildir).
    """
    bag = davet_bagi(duz_jeton)
    govde = davet_mesaji(tenant_ad, bag)
    konu = f"{tenant_ad} sizi Yönetio'ya davet etti"

    # --- SMS (asil) ---
    sms = kanal_saglayicisi("sms").gonder(user.telefon, None, govde)
    session.add(MesajGonderim(
        tenant_id=user.tenant_id, sablon_id=None, kanal="sms",
        amac="operasyonel", user_id=user.id, hedef=user.telefon, konu=None,
        govde=govde, durum=sms.durum, hata=sms.hata,
        saglayici=sms.saglayici, gonderen_user_id=gonderen_id,
        deneme=1,
    ))

    # --- E-POSTA (varsa, ek) ---
    if user.email:
        eposta = kanal_saglayicisi("eposta").gonder(user.email, konu, govde)
        session.add(MesajGonderim(
            tenant_id=user.tenant_id, sablon_id=None, kanal="eposta",
            amac="operasyonel", user_id=user.id, hedef=user.email, konu=konu,
            govde=govde, durum=eposta.durum, hata=eposta.hata,
            saglayici=eposta.saglayici, gonderen_user_id=gonderen_id,
            deneme=1,
        ))

    # --- Panel ozeti: SMS sonucu (asil kanal) ---
    davet.son_kanal = "sms"
    davet.son_durum = sms.durum
    davet.son_hata = sms.hata
    davet.son_gonderim_at = datetime.now(timezone.utc)
    await session.flush()
    return sms.durum != "basarisiz"


async def davet_olustur_ve_gonder(
    session: AsyncSession,
    *,
    user: AppUser,
    tenant_ad: str,
    gonderen_id: uuid.UUID | None,
) -> bool:
    """Kolaylik: olustur/tazele + gonder. Donus: SMS gonderildi mi.

    HESAP PAROLASIZ OLMALI: davet, hesabi SAHIPLENDIRME bagidir. Parolasi
    olan hesaba davet gondermek anlamsiz (zaten girebiliyor); cagiran bu
    kosulu saglar.
    """
    davet, duz = await davet_olustur_veya_tazele(
        session, user=user, olusturan_id=gonderen_id
    )
    return await davet_gonder(
        session, davet=davet, duz_jeton=duz, user=user,
        tenant_ad=tenant_ad, gonderen_id=gonderen_id,
    )
