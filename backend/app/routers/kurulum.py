"""(P154 / Asama 7.3) KURULUM SIHIRBAZI — sekiz adimin durumu.

===========================================================================
TEK UC, SEKIZ SAYIM — istemcide sekiz istek DEGIL
===========================================================================
Brief: "Adim adim kurulum sihirbazi: Blok → Kat/daire → Daire tipleri →
Sakinler → Personel → Gorev alanlari → NFC noktalari → Aidat tanimi.
Ilerleme gostergesi, atlanabilir adimlar, yarim birakip devam edebilme,
tamamlananlarin kalici isaretlenmesi, bitince ayarlardan tekrar
acilabilme."

Sihirbaz her adim icin "yapildi mi" sorusunu yanitlamali. Istemci bunu
sekiz ayri liste ucuna giderek de cikarabilirdi ama:
  * sekiz gidis-donus olurdu (sihirbaz ilk acilista bekler),
  * uclarin yanit SEKILLERI ayni degil (kimi `meta.total` doner, kimi duz
    liste) — istemci sekiz farkli ayiklama yazardi,
  * ve en onemlisi "bu adim bitti mi" KARARI sekiz yere dagilirdi.

Bu yuzden karar SUNUCUDA ve TEK YERDE: asagidaki `ADIMLAR` tablosu.

===========================================================================
TAMAMLANMA SAYILIR, SAKLANMAZ
===========================================================================
Hicbir adim icin "tamamlandi" bayragi tutulmuyor. Her adimin ciktisi zaten
veritabaninda: blok satiri, daire, daire tipi, sakin, personel, gorev
kategorisi, NFC noktasi, aidat tahakkuku. Bayrak tutmak ayni gercegin
IKINCI kaynagini uretir ve ayrisir — yonetici tek blogunu silince bayrak
"tamamlandi" demeye devam ederdi.

ATLAMA ise veriden turetilemez ve `tenant.kurulum_atlanan`da durur
(goc 0044'un basligi bunu anlatiyor).

===========================================================================
YETKI: KURULUM YONETIM ISIDIR
===========================================================================
Okuma da yazma da admin + yonetici. Denetci SALT-OKUR bir roldur ve
kurulum onun isi degildir; saha ve sakin zaten bu ekranlari gormez.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select

from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    BuildingBlock,
    Checkpoint,
    DuesAssessment,
    PersonelKayit,
    TaskCategory,
    Tenant,
    Unit,
    UnitTip,
)
from ..schemas import KurulumAtlaIstek, KurulumDurumOut, KurulumAdimOut

router = APIRouter(prefix="/kurulum", tags=["kurulum"])

_YONETIM = require_role("admin", "yonetici")


@dataclass(frozen=True)
class _Adim:
    """Bir kurulum adimi.

    `sayim` bir SORGU URETICISIDIR, sorgu DEGIL: sorgular istek aninda
    kurulmali (oturum/tenant baglamı o zaman belli).
    """

    kod: str
    sayim: Callable[[], Select]


def _say(model, *kosullar) -> Callable[[], Select]:
    return lambda: select(func.count()).select_from(model).where(*kosullar)


#: SEKIZ ADIM — SIRA BRIEF'IN SIRASI ve anlamlidir: blok olmadan daire,
#: daire olmadan sakin, sakin olmadan aidat tanimlanamaz. Sihirbaz bu
#: sirayi cizer; kullanici yine de istedigi adima gidebilir (adimlar
#: KILITLI DEGIL — kilitlemek, yarim birakip devam edebilmeyi engellerdi).
ADIMLAR: tuple[_Adim, ...] = (
    _Adim("blok", _say(BuildingBlock)),
    _Adim("daire", _say(Unit)),
    _Adim("daire_tipi", _say(UnitTip)),
    # SAKIN ve PERSONEL ayni tabloda ama AYRI adimlar: brief ikisini ayri
    # sayiyor ve gercekten ayri isler (biri tasinanlari girer, oteki
    # calisanlari).
    _Adim("sakin", _say(AppUser, AppUser.role == "resident")),
    _Adim("personel", _say(PersonelKayit)),
    # "Gorev alanlari" = gorev KATEGORILERI (P153: sabit tip enum'u
    # kaldirildi, tip artik yonetici-tanimli kategoridir).
    _Adim("gorev_alani", _say(TaskCategory)),
    _Adim("nfc_noktasi", _say(Checkpoint)),
    # "Aidat tanimi": tahakkuk URETILMIS mi. Daire tipindeki varsayilan
    # tutar TEK BASINA yetmez — tanimli ama hic isletilmemis bir aidat,
    # kimseye borc yazmaz.
    _Adim("aidat", _say(DuesAssessment)),
)

_KODLAR = frozenset(a.kod for a in ADIMLAR)


async def _durum(db: AsyncSession, tenant: Tenant) -> KurulumDurumOut:
    atlanan = set(tenant.kurulum_atlanan or [])
    adimlar: list[KurulumAdimOut] = []
    for a in ADIMLAR:
        sayi = (await db.execute(a.sayim())).scalar_one()
        adimlar.append(
            KurulumAdimOut(
                kod=a.kod,
                sayi=sayi,
                tamam=sayi > 0,
                atlandi=a.kod in atlanan,
            )
        )
    # ILERLEME: atlanan adim da "gecilmis" sayilir. Aksi hâlde bilincli
    # atlayan bir tesis %100'e ASLA ulasamaz ve gosterge kalici bir
    # sitem hâline gelirdi.
    gecilen = sum(1 for a in adimlar if a.tamam or a.atlandi)
    return KurulumDurumOut(
        adimlar=adimlar, toplam=len(adimlar), gecilen=gecilen
    )


@router.get("", response_model=KurulumDurumOut)
async def durum(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> KurulumDurumOut:
    """Sekiz adimin durumu — sayim + atlanma."""
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    return await _durum(db, tenant)


@router.patch("", response_model=KurulumDurumOut)
async def atla(
    body: KurulumAtlaIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> KurulumDurumOut:
    """Bir adimi atla / atlamayi geri al.

    GERI ALINABILIR olmasi sart: "NFC yok" diyen bir tesis sonradan NFC
    kurabilir ve o zaman adimi geri getirebilmeli. Tek yonlu bir atlama,
    sihirbazi bir daha tam gosteremezdi.
    """
    if body.kod not in _KODLAR:
        raise APIError(422, "validation_error", "kurulum_adimi_gecersiz")
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    mevcut = set(tenant.kurulum_atlanan or [])
    if body.atla:
        mevcut.add(body.kod)
    else:
        mevcut.discard(body.kod)
    # SIRA KORUNUR: kumeyi oldugu gibi yazmak, her yazmada JSON dizisinin
    # sirasini degistirir ve `goc-uyum` disi bir gurultu uretirdi.
    tenant.kurulum_atlanan = [a.kod for a in ADIMLAR if a.kod in mevcut]
    await db.flush()
    return await _durum(db, tenant)
