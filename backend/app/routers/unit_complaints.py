"""Daire sikayeti (D1 + D-viz Rev-1) — sakin -> HEDEF DAIRE.

GIZLILIK KADEMESI (Rev-1, auth.md §4):
  * yonetici/admin (YONETIM): denetim gorunumu — daire-basi ACIK sayi + renk
    (harita) + daire detayinda SIKAYET EDEN kimligi (complainant) + not gorur.
  * resident: bina yerlesimini gorur ama SAYI/RENK GORMEZ (hangi dairenin kac
    sikayeti oldugunu bilemez). Yalniz KENDI BLOGUNDAKI daireleri secip sikayet
    eder (blok disi -> 403). Sikayet eden kimligi resident'a ASLA gosterilmez.
  * security/tesis_gorevlisi: YALNIZ blok/kat yapisi (sayi/renk/sikayet yok).
  * resident KENDI sikayetlerini GET /mine ile gorur (gitti mi geri bildirimi;
    yogunluk/renk/complainant YOK, yalniz kendi kayitlari).

Spam korumasi (Rev-1.1 — HAFTALIK + KATEGORI-BAZLI): ayni sakin ayni daireye
ayni KATEGORIDE 7 gunde en fazla 1 sikayet (farkli kategori serbest; durumdan
bagimsiz). advisory xact-lock + sliding 7-gun penceresi ile YARISSIZ -> 409.
Renk (ACIK sikayet sayisi): 0-2 yesil, 3-4 sari, 5+ kirmizi.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitComplaint, UnitResident
from ..schemas import (
    BuildingMapBlok,
    BuildingMapKat,
    BuildingMapResponse,
    BuildingMapUnit,
    UnitComplaintCreate,
    UnitComplaintDecision,
    UnitComplaintDurum,
    UnitComplaintListResponse,
    UnitComplaintOut,
    UnitDensityItem,
    UnitDensityResponse,
)

router = APIRouter(prefix="/unit-complaints", tags=["unit-complaints"])

# Sikayet ACMA yalniz sakin (kendi blogundaki daireyi bildirir).
_FILER = require_role("resident")
# Bina yapisi (harita) OKUMA — tum roller (yapi herkese; sayi/renk yalniz yonetim).
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
# Yogunluk/liste/kapatma — YONETIM (sayi/renk/complainant denetim gorunumu).
_MANAGER = require_role("admin", "yonetici")
# Yonetim rolleri: sayi + renk + complainant + not gorur.
_MANAGEMENT = {"admin", "yonetici"}


def _color(count: int) -> str:
    if count <= 2:
        return "yesil"
    if count <= 4:
        return "sari"
    return "kirmizi"


async def _resident_blocks(db: AsyncSession, user: AppUser) -> set[str | None]:
    """Sakinin AKTIF dairelerinin blok etiketleri (None dahil — blok-suz site).
    Own-block kurali: sakin yalniz bu bloklardaki daireleri gorebilir/sikayet
    edebilir. Aktif dairesi yoksa bos kume (hicbir yere sikayet edemez)."""
    rows = await db.execute(
        select(Unit.blok)
        .join(
            UnitResident,
            and_(
                UnitResident.unit_id == Unit.id,
                UnitResident.user_id == user.id,
                UnitResident.bitis.is_(None),
            ),
        )
    )
    return set(rows.scalars().all())


# ------------------------------- kayit -------------------------------------- #
@router.post("", response_model=UnitComplaintOut, status_code=201)
async def file_unit_complaint(
    body: UnitComplaintCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FILER),
) -> UnitComplaintOut:
    # Hedef daire ayni tenant'ta olmali (RLS + kontrol). Baska tenant/olmayan -> 422.
    unit = (
        await db.execute(select(Unit).where(Unit.id == body.target_unit_id))
    ).scalar_one_or_none()
    if unit is None:
        raise APIError(422, "invalid_reference", "Hedef daire bu tenant'ta bulunamadi.")

    # OWN-BLOCK (Rev-1): sakin yalniz KENDI blogundaki daireyi sikayet edebilir.
    my_blocks = await _resident_blocks(db, user)
    if unit.blok not in my_blocks:
        raise APIError(
            403, "forbidden",
            "Yalnizca kendi blogunuzdaki daireleri sikayet edebilirsiniz.",
        )

    # SPAM KORUMASI (Rev-1.1 — HAFTALIK + KATEGORI-BAZLI, YARISSIZ):
    # ayni sikayetci ayni daireye ayni KATEGORIDE 7 gunde en fazla 1 (farkli
    # kategori serbest; durumdan bagimsiz). Es zamanli iki istek yarissa
    # cift kayit olusmasin diye (complainant,unit,kategori) icin transaction-
    # kapsamli advisory lock alinir; ardindan sliding 7-gun penceresi kontrol
    # edilir. Kilit transaction bitince (commit/rollback) otomatik birakilir.
    await db.execute(
        text("SELECT pg_advisory_xact_lock(hashtext(:k)::bigint)"),
        {"k": f"uc:{user.id}:{unit.id}:{body.kategori}"},
    )
    son = (
        await db.execute(
            select(UnitComplaint.id).where(
                UnitComplaint.complainant_user_id == user.id,
                UnitComplaint.target_unit_id == unit.id,
                UnitComplaint.kategori == body.kategori,
                UnitComplaint.created_at >= text("now() - interval '7 days'"),
            ).limit(1)
        )
    ).scalar_one_or_none()
    if son is not None:
        raise APIError(
            409, "conflict",
            "Bu daire icin bu konuda haftada en fazla 1 sikayet acabilirsiniz.",
        )

    obj = UnitComplaint(
        tenant_id=user.tenant_id,
        target_unit_id=unit.id,
        complainant_user_id=user.id,  # IC — resident'a donmez
        kategori=body.kategori,
        notlar=body.notlar,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # Sikayet acan kendi kaydini gorur (kendi notu) — complainant kimligini
    # tekrar donmeye gerek yok (kendisi zaten biliyor; residentta hep None).
    return UnitComplaintOut.from_model(obj, unit_no=unit.no, include_note=True)


# ------------------------------ yogunluk ------------------------------------ #
@router.get("/density", response_model=UnitDensityResponse)
async def unit_density(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> UnitDensityResponse:
    """Daire-basi ACIK sikayet sayisi + renk — YALNIZ YONETIM (denetim).
    residentlar sayilari GOREMEZ (Rev-1); bkz. /building-map (rol-farkinda)."""
    rows = (
        await db.execute(
            select(
                Unit.id,
                Unit.no,
                Unit.blok,
                func.count(UnitComplaint.id),
            )
            .select_from(Unit)
            .outerjoin(
                UnitComplaint,
                and_(
                    UnitComplaint.target_unit_id == Unit.id,
                    UnitComplaint.durum == "acik",
                ),
            )
            .group_by(Unit.id, Unit.no, Unit.blok)
            .order_by(Unit.no)
        )
    ).all()
    items = [
        UnitDensityItem(
            target_unit_id=r[0],
            unit_no=r[1],
            blok=r[2],
            acik_sayisi=r[3],
            renk=_color(r[3]),
        )
        for r in rows
    ]
    return UnitDensityResponse(items=items)


# --------------------------- sikayetlerim (resident) ------------------------ #
@router.get("/mine", response_model=UnitComplaintListResponse)
async def my_unit_complaints(
    durum: UnitComplaintDurum | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FILER),
) -> UnitComplaintListResponse:
    """Sakinin KENDI actigi sikayetler (sikayet gitti mi geri bildirimi) —
    YALNIZ resident. Alanlar: hedef unit_no + kategori + tarih + durum. Baska
    sakinlerin kayitlari YOK; yogunluk/renk YOK; complainant (kendisi) OMITTED.
    Kendi notunu gorur."""
    base = (
        select(UnitComplaint, Unit.no)
        .join(Unit, Unit.id == UnitComplaint.target_unit_id)
        .where(UnitComplaint.complainant_user_id == user.id)
    )
    if durum is not None:
        base = base.where(UnitComplaint.durum == durum)

    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            base.order_by(UnitComplaint.created_at.desc()).limit(limit).offset(offset)
        )
    ).all()
    return UnitComplaintListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            # complainant OMITTED (kendisi) — include_complainant=False.
            UnitComplaintOut.from_model(obj, unit_no=no, include_note=True)
            for obj, no in rows
        ],
    )


# ------------------------------ bina haritasi ------------------------------- #
@router.get("/building-map", response_model=BuildingMapResponse)
async def building_map(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> BuildingMapResponse:
    """ROL-FARKINDA bina semasi (blok -> kat -> daire):
      * yonetici/admin: sayim + renk dolu (shows_density=True).
      * resident: YALNIZ KENDI blogundaki daireler; genel sayim/renk NULL (yapi —
        sikayet secici). AYRICA KENDI sikayet ettigi daireler isaretlenir
        (benim_sikayetim + benim_acik_sayisi — YALNIZ kendi kayitlarindan turer).
      * security/tesis_gorevlisi: TUM yapi; sayim/renk NULL.
    Sikayet eden verisi (baskalarinin) bu uctan ASLA donmez; genel yogunluk
    residenta sizmaz."""
    is_mgmt = user.role in _MANAGEMENT
    is_resident = user.role == "resident"
    resident_blocks: set[str | None] | None = None
    # resident: KENDI acik sikayetlerinin daire-basi sayisi (yalniz kendi
    # kayitlarindan; complainant == kendisi). Baskalarinin verisi ASLA girmez.
    own_open: dict[uuid.UUID, int] = {}
    if is_resident:
        resident_blocks = await _resident_blocks(db, user)
        own_rows = (
            await db.execute(
                select(
                    UnitComplaint.target_unit_id,
                    func.count(UnitComplaint.id),
                )
                .where(
                    UnitComplaint.complainant_user_id == user.id,
                    UnitComplaint.durum == "acik",
                )
                .group_by(UnitComplaint.target_unit_id)
            )
        ).all()
        own_open = {uid: n for uid, n in own_rows}

    rows = (
        await db.execute(
            select(
                Unit.id,
                Unit.no,
                Unit.blok,
                Unit.kat,
                Unit.sira,
                func.count(UnitComplaint.id),
            )
            .select_from(Unit)
            .outerjoin(
                UnitComplaint,
                and_(
                    UnitComplaint.target_unit_id == Unit.id,
                    UnitComplaint.durum == "acik",
                ),
            )
            .group_by(Unit.id, Unit.no, Unit.blok, Unit.kat, Unit.sira)
            .order_by(Unit.no)
        )
    ).all()

    unplaced: list[BuildingMapUnit] = []
    grouped: dict[str, dict[int, list[BuildingMapUnit]]] = {}
    for uid, no, blok, kat, sira, count in rows:
        # resident: yalniz kendi blogu (own-block picker kapsami).
        if resident_blocks is not None and blok not in resident_blocks:
            continue
        # resident: KENDI acik sikayet sayim (0 dahil); diger rollerde None.
        benim_acik = own_open.get(uid, 0) if is_resident else None
        item = BuildingMapUnit(
            unit_id=uid,
            unit_no=no,
            blok=blok,
            kat=kat,
            sira=sira,
            # Sayim + renk YALNIZ yonetime; digerinde None (yapi gorunumu).
            complaint_count=count if is_mgmt else None,
            color=_color(count) if is_mgmt else None,
            # KENDI sikayet isareti — yalniz resident icin (kendi kayitlarindan).
            benim_sikayetim=bool(benim_acik) if is_resident else False,
            benim_acik_sayisi=benim_acik,
        )
        if blok is None or kat is None:
            unplaced.append(item)
        else:
            grouped.setdefault(blok, {}).setdefault(kat, []).append(item)

    bloklar = [
        BuildingMapBlok(
            blok=blok,
            katlar=[
                BuildingMapKat(
                    kat=kat,
                    units=sorted(
                        units,
                        key=lambda u: (u.sira is None, u.sira or 0, u.unit_no),
                    ),
                )
                for kat, units in sorted(katlar.items())
            ],
        )
        for blok, katlar in sorted(grouped.items())
    ]
    return BuildingMapResponse(shows_density=is_mgmt, bloklar=bloklar, unplaced=unplaced)


# ------------------------------- liste -------------------------------------- #
@router.get("", response_model=UnitComplaintListResponse)
async def list_unit_complaints(
    target_unit_id: uuid.UUID | None = Query(None),
    durum: UnitComplaintDurum | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> UnitComplaintListResponse:
    """Daire sikayetleri — YALNIZ YONETIM (denetim). kategori + tarih + durum +
    SIKAYET EDEN kimligi (complainant) + not. residentlar bu uca ERISEMEZ (403);
    kimlik yalnizca yonetime, denetim amaciyla acilir (Rev-1)."""
    _COMPLAINANT = aliased(AppUser)
    base = (
        select(UnitComplaint, Unit.no, _COMPLAINANT.ad)
        .join(Unit, Unit.id == UnitComplaint.target_unit_id)
        .join(_COMPLAINANT, _COMPLAINANT.id == UnitComplaint.complainant_user_id)
    )
    if target_unit_id is not None:
        base = base.where(UnitComplaint.target_unit_id == target_unit_id)
    if durum is not None:
        base = base.where(UnitComplaint.durum == durum)

    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            base.order_by(UnitComplaint.created_at.desc()).limit(limit).offset(offset)
        )
    ).all()
    return UnitComplaintListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            UnitComplaintOut.from_model(
                obj,
                unit_no=no,
                include_note=True,
                include_complainant=True,
                complainant_ad=cad,
            )
            for obj, no, cad in rows
        ],
    )


# ------------------------------- kapatma ------------------------------------ #
@router.patch("/{complaint_id}", response_model=UnitComplaintOut)
async def close_unit_complaint(
    complaint_id: uuid.UUID,
    body: UnitComplaintDecision,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> UnitComplaintOut:
    """Yonetim durumu degistirir (kapali). Kapatma ACIK sayimi dusurur (renk
    feedback). Denetim: complainant + not doner (yonetime)."""
    obj = await get_or_404(db, UnitComplaint, complaint_id)
    obj.durum = body.durum
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    row = (
        await db.execute(
            select(Unit.no, AppUser.ad)
            .select_from(UnitComplaint)
            .join(Unit, Unit.id == UnitComplaint.target_unit_id)
            .join(AppUser, AppUser.id == UnitComplaint.complainant_user_id)
            .where(UnitComplaint.id == obj.id)
        )
    ).first()
    unit_no = row[0] if row else None
    complainant_ad = row[1] if row else None
    return UnitComplaintOut.from_model(
        obj,
        unit_no=unit_no,
        include_note=True,
        include_complainant=True,
        complainant_ad=complainant_ad,
    )
