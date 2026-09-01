"""(P192 §5.1) BORC YASLANDIRMA — kim ne kadar suredir borclu.

===========================================================================
NEDEN AYRI BIR MODUL
===========================================================================
Yaslandirma UC YERDE lazim: panel karti (`/finans/yaslandirma`), rapor
kataloğu (Excel/PDF) ve "borclulara toplu islem" ekraninin aday listesi.
Hesabi ucunde ayri yazmak, uc farkli "90+ gun" tanimi demekti — ve fark
ancak biri otekiyle karsilastirilinca gorulurdu.

===========================================================================
KOVA SINIRLARI
===========================================================================
0-30 / 31-60 / 61-90 / 90+ — kullanicinin verdigi kume. Gun sayisi
VADEDEN BUGUNE gecen gundur; vadesi GELMEMIS borc yaslandirmaya GIRMEZ
(o bir gecikme degil, henuz odenmemis bir yukumluluktur).

VADESIZ BORC DA GIRMEZ: `son_odeme_tarihi` NULL ise gecikme tanimsizdir
(bkz. `borclandirma.gecikme_kurus` ile ayni kural).

===========================================================================
KALAN, TUTAR DEGIL
===========================================================================
Kova tutarlari KALAN borctur (tahakkuk - odenen), tahakkuk tutari degil.
Kismi odenmis bir borcu tam tutariyla yaslandirmak, tahsil edilmis parayi
"90 gundur odenmiyor" diye gostermek olurdu.
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from . import defter
from .models import AppUser, DuesAssessment, Unit, UnitResident

#: (etiket, alt sinir gun, ust sinir gun | None). SIRA ONEMLI: ilk uyan
#: kova secilir.
KOVALAR: tuple[tuple[str, int, int | None], ...] = (
    ("0-30", 1, 30),
    ("31-60", 31, 60),
    ("61-90", 61, 90),
    ("90+", 91, None),
)


def kova_bul(gun: int) -> str | None:
    """Gecikme gununu kovaya esler; vadesi gelmemisse `None`."""
    for etiket, alt, ust in KOVALAR:
        if gun >= alt and (ust is None or gun <= ust):
            return etiket
    return None


@dataclass
class DaireYaslandirma:
    unit_id: uuid.UUID
    unit_no: str
    #: Dairenin en ESKI acik borcunun gecikme gunu — kovasi budur.
    en_eski_gun: int
    kova: str
    kalan_kurus: int
    borclu_ad: str | None = None
    borclu_user_id: uuid.UUID | None = None


@dataclass
class KovaOzeti:
    kova: str
    daire: int = 0
    kalan_kurus: int = 0
    #: Tiklaninca listelenecek daireler.
    daireler: list[DaireYaslandirma] = field(default_factory=list)


async def hesapla(
    db: AsyncSession, *, bugun: date | None = None
) -> list[KovaOzeti]:
    """Kova bazinda yaslandirma; her kova kendi dairelerini tasir.

    DAIRE BASINA TEK KOVA: bir dairenin uc ayri gecikmis borcu varsa
    uc kovaya birden dagitmak, "kac daire 90+ gundur borclu" sorusunu
    toplami daire sayisini asan bir sayiyla yanitlardi. Daire EN ESKI
    borcunun kovasina girer ve TUM kalan borcu orada sayilir — yonetici
    icin anlamli olan "bu daire ne kadar suredir borclu"dur.
    """
    bugun = bugun or date.today()
    borclar = (
        await db.execute(
            select(DuesAssessment, Unit.no)
            .join(Unit, Unit.id == DuesAssessment.unit_id)
            .where(
                DuesAssessment.son_odeme_tarihi.isnot(None),
                DuesAssessment.son_odeme_tarihi < bugun,
                *defter.gecerli_tahakkuk(),
            )
        )
    ).all()
    if not borclar:
        return [KovaOzeti(kova=e) for e, _, _ in KOVALAR]

    odenen = await defter.tahakkuk_odenen(
        db, [b.DuesAssessment.id for b in borclar]
    )
    daireler: dict[uuid.UUID, DaireYaslandirma] = {}
    hedefler: dict[uuid.UUID, uuid.UUID] = {}
    for satir in borclar:
        borc: DuesAssessment = satir.DuesAssessment
        kalan = borc.tutar_kurus - odenen.get(borc.id, 0)
        if kalan <= 0:
            continue
        gun = (bugun - borc.son_odeme_tarihi).days
        kova = kova_bul(gun)
        if kova is None:
            continue
        mevcut = daireler.get(borc.unit_id)
        if mevcut is None:
            daireler[borc.unit_id] = DaireYaslandirma(
                unit_id=borc.unit_id, unit_no=satir.no,
                en_eski_gun=gun, kova=kova, kalan_kurus=kalan,
            )
        else:
            mevcut.kalan_kurus += kalan
            if gun > mevcut.en_eski_gun:
                mevcut.en_eski_gun = gun
                mevcut.kova = kova
        if borc.hedef_user_id is not None:
            hedefler.setdefault(borc.unit_id, borc.hedef_user_id)

    # BORCLUNUN ADI: hedefli borcta hedef kisi, degilse dairenin AKTIF
    # sakini. Ad, toplu islem ekraninin "kime gidiyor" sorusunu yanitlar.
    eksik = [u for u in daireler if u not in hedefler]
    if eksik:
        rows = (
            await db.execute(
                select(UnitResident.unit_id, UnitResident.user_id).where(
                    UnitResident.unit_id.in_(eksik),
                    UnitResident.bitis.is_(None),
                )
            )
        ).all()
        for unit_id, user_id in rows:
            hedefler.setdefault(unit_id, user_id)
    adlar: dict[uuid.UUID, str] = {}
    if hedefler:
        adlar = dict(
            (
                await db.execute(
                    select(AppUser.id, AppUser.ad).where(
                        AppUser.id.in_(set(hedefler.values()))
                    )
                )
            ).all()
        )
    for unit_id, kayit in daireler.items():
        kayit.borclu_user_id = hedefler.get(unit_id)
        kayit.borclu_ad = adlar.get(kayit.borclu_user_id) if kayit.borclu_user_id else None

    ozet = {e: KovaOzeti(kova=e) for e, _, _ in KOVALAR}
    for kayit in daireler.values():
        kova = ozet[kayit.kova]
        kova.daire += 1
        kova.kalan_kurus += kayit.kalan_kurus
        kova.daireler.append(kayit)
    for kova in ozet.values():
        # En eskiden yeniye: yoneticinin once bakmasi gereken satir ustte.
        kova.daireler.sort(key=lambda d: (-d.en_eski_gun, d.unit_no))
    return [ozet[e] for e, _, _ in KOVALAR]
