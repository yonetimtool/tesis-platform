"""(P252) PERSONEL — kendi calisma bilgisi (§1) ve kisi detayi (§3).

YETKI SUNUCUDA: ucret, odeme gunu ve odeme gecmisi YALNIZ yonetim
(admin/yonetici) ucunda ve kisinin KENDI ucunda (`/me/calisma`) doner.
Guvenlik amiri `/users` listesini gorur (P231) ama bu uclara erisemez —
alan gizlenmez, YANIT HIC URETILMEZ.
"""
from __future__ import annotations

import uuid
from datetime import date

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_current_user, get_tenant_db, require_role
from ..models import AppUser, FinansalHareket, GelirGiderTanim, PersonelKayit

router = APIRouter(tags=["personel"])


class OdemeSatiri(BaseModel):
    id: uuid.UUID
    tarih: date
    donem: str | None = None
    tutar_kurus: int
    #: "maas" | "mesai" | "diger" (karta elle yazilmis gider)
    tur: str
    durum: str


class MeCalismaOut(BaseModel):
    """Kisinin KENDI calisma bilgisi — TC, IBAN ve kasa YOK (yonetim defteri)."""

    giris_tarihi: date | None = None
    gorev: str | None = None
    maas_kurus: int | None = None
    odeme_gunu: int | None = None
    odemeler: list[OdemeSatiri] = []


class MeCalismaYanit(BaseModel):
    #: Kisinin maas karti yoksa `null` (sozlesmeli / dis firma).
    calisma: MeCalismaOut | None = None


async def _odeme_satirlari(
    db: AsyncSession, kart: PersonelKayit, *, limit: int | None = None
) -> list[tuple[FinansalHareket, str]]:
    """Karta (ya da bagli hesaba) yazilmis maas ve fazla mesai giderleri.

    Mesai gideri P203'ten beri `user_id` ile kisiye bagli; P252 maasi
    `personel_kayit_id` ile bagliyor. Ikisi birlikte okunur. Iptal edilen
    (ters kaydi olan) satir ve ters satirin kendisi listelenmez.
    """
    from sqlalchemy import and_, or_

    from .. import defter
    from ..maas import KOD_MAAS, KOD_MESAI, PERSONEL_KODLARI
    from .mesai import ACIKLAMA_ONEKI

    # Karta bagli her gider (P252 maas + mesai) VE hesaba bagli eski
    # (P252 oncesi, kartsiz) mesai giderleri. Hesaba bagli BASKA bir gider
    # (orn. personele elle yazilmis avans) odeme gecmisine girmez.
    kosul = [FinansalHareket.personel_kayit_id == kart.id]
    if kart.app_user_id is not None:
        kosul.append(
            and_(
                FinansalHareket.user_id == kart.app_user_id,
                FinansalHareket.personel_kayit_id.is_(None),
                or_(
                    GelirGiderTanim.sistem_kodu.in_(PERSONEL_KODLARI),
                    FinansalHareket.aciklama.startswith(ACIKLAMA_ONEKI),
                ),
            )
        )
    q = (
        select(FinansalHareket, GelirGiderTanim.sistem_kodu)
        .outerjoin(GelirGiderTanim, GelirGiderTanim.id == FinansalHareket.gelir_gider_tanim_id)
        .where(
            FinansalHareket.tip == "gider",
            FinansalHareket.ters_kayit_id.is_(None),
            FinansalHareket.id.notin_(defter.iptal_edilmis()),
            or_(*kosul),
        )
        .order_by(FinansalHareket.tarih.desc(), FinansalHareket.id.desc())
    )
    if limit:
        q = q.limit(limit)
    satirlar = (await db.execute(q)).all()

    def tur(h: FinansalHareket, kod: str | None) -> str:
        if kod == KOD_MAAS or (h.idempotency_key or "").startswith("maas:"):
            return "maas"
        if kod == KOD_MESAI or (h.aciklama or "").startswith(ACIKLAMA_ONEKI):
            return "mesai"
        return "diger"

    return [(h, tur(h, kod)) for h, kod in satirlar]


async def odeme_gecmisi(
    db: AsyncSession, kart: PersonelKayit, *, limit: int | None = None
) -> list[OdemeSatiri]:
    return [
        OdemeSatiri(
            id=h.id, tarih=h.tarih, donem=h.donem, tutar_kurus=h.tutar_kurus,
            tur=tur, durum=h.durum,
        )
        for h, tur in await _odeme_satirlari(db, kart, limit=limit)
    ]


@router.get("/me/calisma", response_model=MeCalismaYanit)
async def kendi_calismam(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> MeCalismaYanit:
    """(P252 §1) Personel KENDI ucretini ve son odemelerini gorur (KVKK md. 11)."""
    kart = (
        await db.execute(select(PersonelKayit).where(PersonelKayit.app_user_id == user.id))
    ).scalar_one_or_none()
    if kart is None:
        return MeCalismaYanit(calisma=None)
    return MeCalismaYanit(
        calisma=MeCalismaOut(
            giris_tarihi=kart.giris_tarihi, gorev=kart.gorev,
            maas_kurus=kart.maas_kurus, odeme_gunu=kart.odeme_gunu,
            odemeler=await odeme_gecmisi(db, kart, limit=6),
        )
    )


# =========================== (P252 §3) KISI DETAYI ========================== #
_YONETIM = require_role("admin", "yonetici")


class OdemeDetay(OdemeSatiri):
    kasa_id: uuid.UUID | None = None
    kasa_ad: str | None = None


class CalismaDetay(BaseModel):
    giris_tarihi: date | None = None
    cikis_tarihi: date | None = None
    gorev: str | None = None
    maas_kurus: int | None = None
    odeme_gunu: int | None = None
    kasa_id: uuid.UUID | None = None
    kasa_ad: str | None = None
    iban: str | None = None
    notlar: str | None = None
    aktif: bool = True


class BuAyOzeti(BaseModel):
    """Bu ayin (takvim ayi) vardiya ve devriye ozeti."""

    vardiya_sayisi: int = 0
    vardiya_saat: float = 0
    devriye_tur: int = 0
    okutma_sayisi: int = 0


class PersonelDetay(BaseModel):
    kart_id: uuid.UUID | None = None
    user_id: uuid.UUID | None = None
    ad: str
    rol: str | None = None
    #: Maas karti yoksa `null` (yalniz hesap).
    calisma: CalismaDetay | None = None
    odemeler: list[OdemeDetay] = []
    bu_ay: BuAyOzeti
    #: Bu takvim yilinda ODENMIS (onay bekleyen haric) maas + mesai.
    yil_odenen_kurus: int = 0


async def _bu_ay(db: AsyncSession, user_id: uuid.UUID | None, bugun: date) -> BuAyOzeti:
    if user_id is None:
        return BuAyOzeti()
    import calendar
    import datetime as dt

    from sqlalchemy import func

    from ..models import ScanEvent, Shift, VardiyaPlani
    from ..vardiya import plan_araligi, saat_farki

    bas = bugun.replace(day=1)
    son = bugun.replace(day=calendar.monthrange(bugun.year, bugun.month)[1])
    planlar = (
        await db.execute(
            select(VardiyaPlani, Shift)
            .outerjoin(Shift, Shift.id == VardiyaPlani.shift_id)
            .where(
                VardiyaPlani.user_id == user_id,
                VardiyaPlani.tarih >= bas,
                VardiyaPlani.tarih <= son,
            )
        )
    ).all()
    saat = 0.0
    for plan, shift in planlar:
        try:
            a, b = plan_araligi(plan, shift)
        except ValueError:
            continue
        saat += saat_farki(a, b)
    bas_an = dt.datetime.combine(bas, dt.time.min, tzinfo=dt.timezone.utc)
    son_an = dt.datetime.combine(son + dt.timedelta(days=1), dt.time.min, tzinfo=dt.timezone.utc)
    tur, okutma = (
        await db.execute(
            select(func.count(func.distinct(ScanEvent.patrol_window_id)), func.count())
            .where(
                ScanEvent.guard_id == user_id,
                ScanEvent.okutma_zamani >= bas_an,
                ScanEvent.okutma_zamani < son_an,
            )
        )
    ).one()
    return BuAyOzeti(
        vardiya_sayisi=len(planlar), vardiya_saat=round(saat, 1),
        devriye_tur=int(tur or 0), okutma_sayisi=int(okutma or 0),
    )


@router.get("/personel/detay", response_model=PersonelDetay)
async def personel_detayi(
    user_id: uuid.UUID | None = None,
    kart_id: uuid.UUID | None = None,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> PersonelDetay:
    """(P252 §3) Kisi detayi — calisma bilgileri, odeme gecmisi, bu ay
    vardiya/devriye ozeti, bu yil odenen.

    `user_id` (Kisiler › Personel satiri) ya da `kart_id` (Maas kartlari,
    hesapsiz personel). YALNIZ yonetim: amir 403 alir — ucret ve odeme
    gecmisi bu yanitin parcasi.
    """
    from ..errors import APIError
    from ..models import Kasa

    if user_id is None and kart_id is None:
        raise APIError(422, "validation_error", "personel_detay_kimlik")
    q = select(PersonelKayit)
    q = q.where(PersonelKayit.id == kart_id) if kart_id else q.where(PersonelKayit.app_user_id == user_id)
    kart = (await db.execute(q)).scalar_one_or_none()
    hesap = None
    uid = user_id or (kart.app_user_id if kart else None)
    if uid is not None:
        hesap = (await db.execute(select(AppUser).where(AppUser.id == uid))).scalar_one_or_none()
    if kart is None and hesap is None:
        raise APIError(404, "not_found", "personel_bulunamadi")

    kasalar = dict((await db.execute(select(Kasa.id, Kasa.ad))).all())
    from ..tesis_saati import tesis_bugun

    bugun = await tesis_bugun(db)
    odemeler: list[OdemeDetay] = []
    yil = 0
    calisma = None
    if kart is not None:
        for h, tur in await _odeme_satirlari(db, kart):
            odemeler.append(OdemeDetay(
                id=h.id, tarih=h.tarih, donem=h.donem, tutar_kurus=h.tutar_kurus,
                tur=tur, durum=h.durum, kasa_id=h.kasa_id, kasa_ad=kasalar.get(h.kasa_id),
            ))
            if h.tarih.year == bugun.year and h.durum == "odendi":
                yil += h.tutar_kurus
        calisma = CalismaDetay(
            giris_tarihi=kart.giris_tarihi, cikis_tarihi=kart.cikis_tarihi, gorev=kart.gorev,
            maas_kurus=kart.maas_kurus, odeme_gunu=kart.odeme_gunu, kasa_id=kart.kasa_id,
            kasa_ad=kasalar.get(kart.kasa_id), iban=kart.iban, notlar=kart.notlar,
            aktif=kart.aktif,
        )
    # `app_user.ad` ZATEN tam gorunen addir (P250: `tam_ad` kayitta
    # uygulanir); yeniden birlestirmek soyadi iki kez yazardi.
    ad = hesap.ad if hesap is not None else kart.ad
    return PersonelDetay(
        kart_id=kart.id if kart else None,
        user_id=uid,
        ad=ad,
        rol=hesap.role if hesap is not None else None,
        calisma=calisma,
        odemeler=odemeler,
        bu_ay=await _bu_ay(db, uid, bugun),
        yil_odenen_kurus=yil,
    )
