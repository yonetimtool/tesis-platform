"""Ortak alan tanimlari (havuz/teras/toplanti odasi) — rezervasyonun temeli.

RBAC (auth.md §4): OLUSTURMA/DUZENLEME yonetici + admin (site yonetimi alani
tanimlar). OKUMA TUM roller — sakin neyin rezerve edilebilir oldugunu gormeli;
yonetim pasif alanlari da gorur (duzenleme icin), diger roller YALNIZ aktif
alanlari gorur. Silme YOK: alan kaldirma = aktif=false (soft-delete) —
rezervasyon gecmisi korunur (FK RESTRICT hard-delete'i zaten engeller).
"""
from __future__ import annotations

import uuid
from datetime import date as date_type
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .. import reservations_timing as rtiming
from ..crud_helpers import is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, OrtakAlan, Rezervasyon, Tenant, Unit
from ..schemas import (
    AlanSlotResponse,
    OrtakAlanCreate,
    OrtakAlanListResponse,
    OrtakAlanOut,
    OrtakAlanUpdate,
    SlotOut,
)

router = APIRouter(prefix="/common-areas", tags=["rezervasyon"])

_MANAGER = require_role("admin", "yonetici")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")

# Alan yonetimi (pasifler dahil tum listeyi gorme) yonetim rolleri.
_MANAGEMENT_ROLES = ("admin", "yonetici")


@router.get("", response_model=OrtakAlanListResponse)
async def list_areas(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> OrtakAlanListResponse:
    stmt = select(OrtakAlan)
    # Yonetim pasif alanlari da gorur (duzenleme/yeniden aktive etme);
    # diger roller yalniz rezerve edilebilir (aktif) alanlari.
    if user.role not in _MANAGEMENT_ROLES:
        stmt = stmt.where(OrtakAlan.aktif.is_(True))
    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(stmt.order_by(OrtakAlan.ad).limit(limit).offset(offset))
    ).scalars().all()
    return OrtakAlanListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=list(rows),
    )


@router.post("", response_model=OrtakAlanOut, status_code=201)
async def create_area(
    body: OrtakAlanCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> OrtakAlan:
    obj = OrtakAlan(
        tenant_id=user.tenant_id,
        ad=body.ad,
        aciklama=body.aciklama,
        acilis=body.acilis,
        kapanis=body.kapanis,
        slot_dakika=body.slot_dakika,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Bu adla bir ortak alan zaten var.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{area_id}", response_model=OrtakAlanOut)
async def update_area(
    area_id: uuid.UUID,
    body: OrtakAlanUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> OrtakAlan:
    obj = (
        await db.execute(select(OrtakAlan).where(OrtakAlan.id == area_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    payload = body.model_dump(exclude_unset=True)
    for k, v in payload.items():
        setattr(obj, k, v)
    # Kismi saat guncellemesi (yalniz biri verildi) mevcut deger ile tutarli
    # olmali — DB CHECK son guvence, ama once anlamli 422 verelim.
    if obj.kapanis <= obj.acilis:
        raise APIError(
            422, "validation_error", "kapanis acilistan sonra olmali."
        )
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Bu adla bir ortak alan zaten var.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


# ------------------------------- slotlar ------------------------------------ #
@router.get("/{area_id}/slots", response_model=AlanSlotResponse)
async def area_slots(
    area_id: uuid.UUID,
    tarih: date_type = Query(..., alias="date", description="Gun (YYYY-MM-DD)"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> AlanSlotResponse:
    """Bir gunun slot izgarasi + dolu/bos (GIZLILIK: kim rezerve etmis YOK).

    Slotlar alanin musaitliginden uretilir: [acilis, kapanis) araligi,
    slot_dakika uzunlugunda TAM slotlar. Bir slot 'dolu' = o gun bu alanda o
    slotla kesisen ONAYLI bir rezervasyon var (yari-acik kesisim; bitisik slot
    dolu SAYILMAZ — EXCLUDE kisitiyla birebir). Bekleyen/reddedilen talepler
    slotu doldurmaz. Sakin bu ucu slot secmek icin kullanir; pasif alan
    sakine/sahaya gorunmez (rezerve edilemez -> 404, varlik sizdirilmaz)."""
    alan = (
        await db.execute(select(OrtakAlan).where(OrtakAlan.id == area_id))
    ).scalar_one_or_none()
    if alan is None or (not alan.aktif and user.role not in _MANAGEMENT_ROLES):
        raise APIError(404, "not_found", "Kayit bulunamadi")

    # O gunun ONAYLI rezervasyon araliklari. Daire no + kisi sayisi YALNIZ
    # yonetime aciklanir; talep_eden_user_id yalniz "benim mi" kararinda
    # kullanilir (resident'a kimlik SIZDIRILMAZ — asagidaki kapilar).
    onayli = (
        await db.execute(
            select(
                Rezervasyon.baslangic,
                Rezervasyon.bitis,
                Unit.no,
                Rezervasyon.kisi_sayisi,
                Rezervasyon.talep_eden_user_id,
            )
            .join(Unit, Unit.id == Rezervasyon.unit_id)
            .where(
                Rezervasyon.alan_id == area_id,
                Rezervasyon.tarih == tarih,
                Rezervasyon.durum == "onaylandi",
            )
        )
    ).all()

    is_resident = user.role == "resident"
    is_mgmt = user.role in _MANAGEMENT_ROLES
    tzname = (
        await db.execute(select(Tenant.timezone).where(Tenant.id == user.tenant_id))
    ).scalar_one_or_none() or "Europe/Istanbul"
    # GUNLUK KOTA — SLOT-GUNUNE gore (tarih = goruntulenen slot-gunu; DEGIL
    # rezervasyon/bugun gunu). Sakinin bu gune denk AKTIF rezervasyonu var mi.
    kota_dolu = False
    if is_resident:
        kota_dolu = (
            await db.execute(
                select(Rezervasyon.id).where(
                    Rezervasyon.talep_eden_user_id == user.id,
                    Rezervasyon.tarih == tarih,
                    Rezervasyon.durum == "onaylandi",
                ).limit(1)
            )
        ).scalar_one_or_none() is not None
    now = rtiming.now_utc()

    items: list[SlotOut] = []
    step = timedelta(minutes=alan.slot_dakika)
    cur = datetime.combine(tarih, alan.acilis)
    kapanis_dt = datetime.combine(tarih, alan.kapanis)
    while cur + step <= kapanis_dt:
        s, e = cur.time(), (cur + step).time()
        # Bu slotla kesisen ONAYLI rezervasyon (yari-acik kesisim); onayli'lar
        # cakismadigindan en cok biri esler.
        match = next(
            (r for r in onayli if s < r.bitis and e > r.baslangic), None
        )
        dolu = match is not None
        # Sakin icin rezerve edilebilirlik (24s/gunluk/son-dakika); yonetimde False.
        sebep: str | None = None
        rezerve = False
        if is_resident:
            sebep = rtiming.booking_reason(
                tzname, tarih, s, dolu=dolu, kota_dolu=kota_dolu, now=now
            )
            rezerve = sebep is None
        elif dolu:
            sebep = "dolu"
        # benim: YALNIZ resident + dolu slot KENDI rezervasyonu (yesil/kirmizi
        # rengi istemci baslangic/bitis + simdi ile secer). Baskasinin dolu
        # slotu benim=False + kimlik/kisi None (gizlilik — kimlik SIZMAZ).
        benim = bool(is_resident and match and match.talep_eden_user_id == user.id)
        items.append(
            SlotOut(
                baslangic=s.strftime("%H:%M"),
                bitis=e.strftime("%H:%M"),
                dolu=dolu,
                rezerve_edilebilir=rezerve,
                sebep=sebep,
                # Kimlik + kisi sayisi YALNIZ yonetime + dolu slotta (denetim);
                # resident/saha icin DAIMA None (gizlilik).
                unit_no=match.no if (is_mgmt and match) else None,
                kisi_sayisi=match.kisi_sayisi if (is_mgmt and match) else None,
                benim=benim,
            )
        )
        cur += step
    return AlanSlotResponse(
        alan_id=area_id, tarih=tarih, slot_dakika=alan.slot_dakika, items=items
    )
