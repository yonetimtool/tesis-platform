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

from ..deps import get_current_user, get_tenant_db
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


async def odeme_gecmisi(
    db: AsyncSession, kart: PersonelKayit, *, limit: int | None = None
) -> list[OdemeSatiri]:
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

    return [
        OdemeSatiri(
            id=h.id, tarih=h.tarih, donem=h.donem, tutar_kurus=h.tutar_kurus,
            tur=tur(h, kod), durum=h.durum,
        )
        for h, kod in satirlar
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
