"""Yonetici tek-seferlik daire erisim izni — talep + sakin karari.

Akis (gizlilik modeli, auth.md §4 — KVKK):
  1. Ziyaretci/kargo kayitlari hem yonetici'ye hem admin'e VARSAYILAN KAPALI
     (yalniz kaydeden guvenlik + hedef sakin gorur).
  2. Yonetici VEYA admin bir daireye `POST /unit-access-request` ile izin
     TALEBI acar (durum=bekliyor) -> o dairenin AKTIF sakinlerine push.
  3. Dairenin bir sakini `PATCH /unit-access-request/{id}` ile onaylar/reddeder
     (ILK yanit gecerli; ikinci 409). Onay -> tek-kullanimlik izin (used=false).
  4. Talebi acan (yonetici/admin) o dairenin ziyaretci/kargo kaydini ILK
     okudugunda izin tuketilir (used=true; bkz. app.permissions). Tekrar gormek
     yeni talep ister.

RBAC: TALEP acma admin VEYA yonetici. KARAR yalniz o dairenin AKTIF sakini
(baska daire 404). OKUMA: yonetici kendi taleplerini; resident kendi dairelerine
gelen talepleri; admin tenant'in tumunu (erisim-kontrol metaverisi — sakinin
ozel ziyaretci/kargo verisi degil). Tenant token'dan; RLS izole. Push EK
gonderimdir — hatasi talebi KIRMAZ.

Not: `granted_to_yonetici_user_id` kolonu talebi acan YONETICI VEYA ADMIN'in
id'sini tutar (isim tarihsel; admin de erisim talebi acabilir).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitAccessPermission, UnitResident
from ..scheduler.notify import dispatch_external
from ..schemas import (
    BulkAccessRequestResult,
    GrantedUnitOut,
    GrantedUnitsResponse,
    UnitAccessRequestCreate,
    UnitAccessRequestDecision,
    UnitAccessRequestListResponse,
    UnitAccessRequestOut,
)

router = APIRouter(prefix="/unit-access-request", tags=["unit-access"])

# TALEP acma yonetici VEYA admin (ikisi de ziyaretci/kargo icin varsayilan
# KAPALI; scoped, sakin-onayli erisim icin talep acar). KARAR yalniz sakin.
# OKUMA admin/yonetici/resident (asagida daralir).
_REQUESTER = require_role("admin", "yonetici")
_DECIDER = require_role("resident")
_READER = require_role("admin", "yonetici", "resident")

_YONETICI = aliased(AppUser)
_RESIDENT = aliased(AppUser)


def _out(row) -> UnitAccessRequestOut:
    obj, unit_no, yonetici_ad, resident_ad = row
    out = UnitAccessRequestOut.model_validate(obj)
    out.unit_no = unit_no
    out.yonetici_ad = yonetici_ad
    out.resident_ad = resident_ad
    return out


def _base_stmt():
    return (
        select(UnitAccessPermission, Unit.no, _YONETICI.ad, _RESIDENT.ad)
        .join(Unit, Unit.id == UnitAccessPermission.unit_id)
        .join(
            _YONETICI,
            _YONETICI.id == UnitAccessPermission.granted_to_yonetici_user_id,
        )
        .outerjoin(
            _RESIDENT,
            _RESIDENT.id == UnitAccessPermission.granted_by_resident_user_id,
        )
    )


async def _aktif_daire_ids(db: AsyncSession, user: AppUser) -> list[uuid.UUID]:
    return list(
        (
            await db.execute(
                select(UnitResident.unit_id).where(
                    UnitResident.user_id == user.id, UnitResident.bitis.is_(None)
                )
            )
        ).scalars().all()
    )


# ------------------------------- talep -------------------------------------- #
@router.post("", response_model=UnitAccessRequestOut, status_code=201)
async def create_request(
    body: UnitAccessRequestCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_REQUESTER),
) -> UnitAccessRequestOut:
    if body.unit_id is not None:
        unit = (
            await db.execute(select(Unit).where(Unit.id == body.unit_id))
        ).scalar_one_or_none()
    else:
        unit = (
            await db.execute(select(Unit).where(Unit.no == body.unit_no))
        ).scalar_one_or_none()
    if unit is None:
        raise APIError(422, "invalid_reference", "Daire bu tenant'ta bulunamadi.")

    obj = UnitAccessPermission(
        tenant_id=user.tenant_id,
        unit_id=unit.id,
        granted_to_yonetici_user_id=user.id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)

    # EK push: dairenin TUM aktif sakinlerine (karar onlarda); hatasi talebi
    # kirmaz. (Ziyaretcinin aksine burada belirli bir hedef yok — dairenin
    # herhangi bir sakini karar verebilir.)
    sakinler = (
        await db.execute(
            select(UnitResident.user_id).where(
                UnitResident.unit_id == unit.id, UnitResident.bitis.is_(None)
            )
        )
    ).scalars().all()
    if sakinler:
        dispatch_external(
            f"{user.ad} {unit.no} ziyaretci/kargo kayitlarini gormek istiyor. "
            "Onayla/Reddet",
            tenant_id=user.tenant_id,
            target_user_ids=tuple(dict.fromkeys(sakinler)),
            title="Goruntuleme izni talebi",
            data={"tip": "erisim_talebi", "request_id": str(obj.id)},
        )
    return _out((obj, unit.no, user.ad, None))


# ---------------------------- toplu talep (bulk) ---------------------------- #
@router.post("/bulk", response_model=BulkAccessRequestResult, status_code=201)
async def create_bulk_request(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_REQUESTER),
) -> BulkAccessRequestResult:
    """Tenant'taki SAKINLI TUM daireler icin ayni anda bekleyen izin talebi
    acar -> her dairenin AKTIF sakinlerine push. Per-daire karar sakinde kalir:
    toplu talep hicbir onayi BAYPAS ETMEZ (yonetici yalniz ONAYLAYAN dairelerin
    kayitlarini gorur; one-shot tuketim tek-daire ile ayni).

    Mukerrer bildirim spam'ini onlemek icin: bu talebi acanin zaten ACIK
    (bekleyen) ya da KULLANILMAMIS ONAYLI izni olan daireler ATLANIR. RBAC:
    admin + yonetici (tek-daire talep ile ayni). Push EK gonderim — hatasi
    talebi kirmaz."""
    # 1) Aktif sakinleri olan daireler + sakin id'leri (unit_id -> [user_id]).
    res_rows = (
        await db.execute(
            select(UnitResident.unit_id, UnitResident.user_id).where(
                UnitResident.bitis.is_(None)
            )
        )
    ).all()
    sakinler: dict[uuid.UUID, list[uuid.UUID]] = {}
    for unit_id, user_id in res_rows:
        sakinler.setdefault(unit_id, []).append(user_id)

    if not sakinler:
        return BulkAccessRequestResult(created=0, skipped=0, items=[])

    # 2) Daire numaralari (yaniti zenginlestirir).
    unit_nos = dict(
        (
            await db.execute(
                select(Unit.id, Unit.no).where(Unit.id.in_(list(sakinler.keys())))
            )
        ).all()
    )

    # 3) Bu talebi acanin ZATEN acik (bekleyen) veya kullanilmamis onayli izni
    #    olan daireleri atla (mukerrer talep/push olusturma).
    aktif_ids = set(
        (
            await db.execute(
                select(UnitAccessPermission.unit_id).where(
                    UnitAccessPermission.granted_to_yonetici_user_id == user.id,
                    or_(
                        UnitAccessPermission.durum == "bekliyor",
                        and_(
                            UnitAccessPermission.durum == "onaylandi",
                            UnitAccessPermission.used.is_(False),
                        ),
                    ),
                )
            )
        ).scalars().all()
    )

    created: list[UnitAccessRequestOut] = []
    skipped = 0
    for unit_id in sorted(sakinler, key=lambda u: unit_nos.get(u, "")):
        if unit_id in aktif_ids:
            skipped += 1
            continue
        obj = UnitAccessPermission(
            tenant_id=user.tenant_id,
            unit_id=unit_id,
            granted_to_yonetici_user_id=user.id,
        )
        db.add(obj)
        try:
            await db.flush()
        except IntegrityError as exc:
            raise translate_integrity(exc)
        await db.refresh(obj)
        created.append(_out((obj, unit_nos.get(unit_id), user.ad, None)))

        # EK push: dairenin aktif sakinlerine (karar onlarda); hatasi kirmaz.
        hedefler = tuple(dict.fromkeys(sakinler[unit_id]))
        dispatch_external(
            f"{user.ad} {unit_nos.get(unit_id)} ziyaretci/kargo kayitlarini gormek "
            "istiyor. Onayla/Reddet",
            tenant_id=user.tenant_id,
            target_user_ids=hedefler,
            title="Goruntuleme izni talebi",
            data={"tip": "erisim_talebi", "request_id": str(obj.id)},
        )

    return BulkAccessRequestResult(created=len(created), skipped=skipped, items=created)


# ------------------------- verilen (onayli) daireler ------------------------ #
@router.get("/granted-units", response_model=GrantedUnitsResponse)
async def list_granted_units(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_REQUESTER),
) -> GrantedUnitsResponse:
    """Talebi acanin (admin/yonetici) SU AN goruntuleyebilecegi daireler:
    onaylandi + kullanilmamis izinler. Ilk okumada tuketilecek (one-shot)
    dairelerin listesi — 'hangi daireler acildi' gorunumu (bulk sonrasi
    yonetici bunu izler; bekleyen/reddedilenler burada YOKTUR)."""
    rows = (
        await db.execute(
            select(
                UnitAccessPermission.id,
                UnitAccessPermission.unit_id,
                Unit.no,
                UnitAccessPermission.decided_at,
            )
            .join(Unit, Unit.id == UnitAccessPermission.unit_id)
            .where(
                UnitAccessPermission.granted_to_yonetici_user_id == user.id,
                UnitAccessPermission.durum == "onaylandi",
                UnitAccessPermission.used.is_(False),
            )
            .order_by(UnitAccessPermission.decided_at.desc())
        )
    ).all()
    return GrantedUnitsResponse(
        items=[
            GrantedUnitOut(
                request_id=r[0], unit_id=r[1], unit_no=r[2], decided_at=r[3]
            )
            for r in rows
        ]
    )


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=UnitAccessRequestListResponse)
async def list_requests(
    durum: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> UnitAccessRequestListResponse:
    stmt = _base_stmt()
    if durum is not None:
        stmt = stmt.where(UnitAccessPermission.durum == durum)
    # Kapsam: yonetici kendi talepleri; resident kendi dairelerine gelenler;
    # admin tenant'in tumu.
    if user.role == "yonetici":
        stmt = stmt.where(
            UnitAccessPermission.granted_to_yonetici_user_id == user.id
        )
    elif user.role == "resident":
        unit_ids = await _aktif_daire_ids(db, user)
        stmt = stmt.where(UnitAccessPermission.unit_id.in_(unit_ids or []))

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            stmt.order_by(UnitAccessPermission.requested_at.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return UnitAccessRequestListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r) for r in rows],
    )


# ------------------------------- karar -------------------------------------- #
@router.patch("/{request_id}", response_model=UnitAccessRequestOut)
async def decide_request(
    request_id: uuid.UUID,
    body: UnitAccessRequestDecision,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_DECIDER),
) -> UnitAccessRequestOut:
    row = (
        await db.execute(
            select(UnitAccessPermission, Unit.no)
            .join(Unit, Unit.id == UnitAccessPermission.unit_id)
            .where(UnitAccessPermission.id == request_id)
        )
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    obj, unit_no = row

    # Yalniz talebin AIT OLDUGU dairenin AKTIF sakini karar verir; digerine 404
    # (varlik sizdirilmaz — bypass yok, sunucu tarafinda zorlanir).
    if obj.unit_id not in await _aktif_daire_ids(db, user):
        raise APIError(404, "not_found", "Kayit bulunamadi")

    # ILK karar kazanir: durum='bekliyor' kosullu atomik UPDATE.
    res = await db.execute(
        update(UnitAccessPermission)
        .where(
            UnitAccessPermission.id == request_id,
            UnitAccessPermission.durum == "bekliyor",
        )
        .values(
            durum=body.durum,
            granted_by_resident_user_id=user.id,
            decided_at=func.now(),
        )
    )
    if res.rowcount == 0:
        raise APIError(
            409, "conflict", "Talep zaten yanitlanmis (ilk karar gecerli)."
        )
    await db.refresh(obj)

    # EK push: sonuc talebi acan yonetici'ye; hatasi karari kirmaz.
    sonuc = "onaylandi" if body.durum == "onaylandi" else "reddedildi"
    dispatch_external(
        f"{unit_no} goruntuleme izni {sonuc} ({user.ad})",
        tenant_id=user.tenant_id,
        target_user_ids=(obj.granted_to_yonetici_user_id,),
        title="Goruntuleme izni sonucu",
        data={"tip": "erisim_sonuc", "request_id": str(obj.id)},
    )
    yonetici_ad = (
        await db.execute(
            select(AppUser.ad).where(
                AppUser.id == obj.granted_to_yonetici_user_id
            )
        )
    ).scalar_one_or_none()
    return _out((obj, unit_no, yonetici_ad, user.ad))
