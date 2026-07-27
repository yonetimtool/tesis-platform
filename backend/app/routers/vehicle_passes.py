"""Arac gecisi (G1) + otopark dolulugu (G4).

Model (tek tablo, tek dogruluk kaynagi):
  * Bir GECIS = bir `vehicle_pass` satiri. Giris kaydinda `giris_zamani` dolu,
    `cikis_zamani` NULL'dur => arac ICERIDEDIR.
  * Cikista ayni satir damgalanir (`POST /vehicle-passes/{id}/checkout`);
    zaten damgaliysa 409 (ilk cikis zamani DEGISMEZ).
  * OTOPARK DOLULUGU = acik (cikis_zamani IS NULL) satirlarin sayisi. Ayri
    sayac/tetikleyici yok — sayim ile kayit ASLA ayrisamaz.

Neden "yon: giris|cikis" iki ayri satir DEGIL (mobil README G1 taslagindan
bilincli sapma): iki-satir modelinde doluluk "eslesmemis girisleri bul"
sorgusuna doner (plaka basina son-olay penceresi; yaris-acik, indekslemesi
pahali). Tek-satir modelinde doluluk kismi indeksli tek COUNT'tur ve "ayni
plakadan ayni anda tek acik gecis" DB kisitiyla garanti edilir.

RBAC (auth.md §4): YAZMA + OKUMA admin + security. Plaka kisisel veriye
baglanabilir (KVKK) — yonetici/resident gecis LISTESINI gormez; yonetim
ihtiyaci olan sey AGREGAT dolulugudur, o da /parking/occupancy ile tum
kimlikli rollere aciktir (plaka/daire icermez). tesis_gorevlisi ERISMEZ.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..audit import Action, audit_user
from ..crud_helpers import is_unique_violation, norm_plaka, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Tenant, Unit, VehiclePass
from ..schemas import (
    ParkingOccupancyOut,
    VehiclePassCreate,
    VehiclePassListResponse,
    VehiclePassOut,
)

router = APIRouter(prefix="/vehicle-passes", tags=["vehicle-passes"])
# Doluluk AYRI prefix ile sunulur (ayni dosya — ayni veri modeli).
parking_router = APIRouter(prefix="/parking", tags=["vehicle-passes"])

# Kapi operasyonu: guvenlik kaydeder, admin duzeltir/denetler.
_OPERATOR = require_role("admin", "security")
_READER = require_role("admin", "security")
# Agregat doluluk: plaka/daire icermez -> tum kimlikli roller (ana ekran karti).
_OCCUPANCY_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident"
)

# Geriye donuk giris damgasina tolerans (saat ileri/geri kaymalari icin).
_GELECEK_TOLERANS = timedelta(minutes=5)

_KAYDEDEN = aliased(AppUser)


def _out(row) -> VehiclePassOut:
    obj, unit_no, kaydeden_ad = row
    out = VehiclePassOut.model_validate(obj)
    out.unit_no = unit_no
    out.kaydeden_ad = kaydeden_ad
    return out


def _base_stmt():
    """Liste/detay ortak SELECT'i: daire no (varsa) + kaydeden adi."""
    return (
        select(VehiclePass, Unit.no, _KAYDEDEN.ad)
        .outerjoin(Unit, Unit.id == VehiclePass.unit_id)
        .join(_KAYDEDEN, _KAYDEDEN.id == VehiclePass.kaydeden_user_id)
    )


# ------------------------------- giris -------------------------------------- #
@router.post("", response_model=VehiclePassOut, status_code=201)
async def create_vehicle_pass(
    body: VehiclePassCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OPERATOR),
) -> VehiclePassOut:
    """Arac GIRISI. plaka normalize edilir; ayni plakadan ACIK gecis varsa 409
    (arac zaten iceride — cift sayim otoparki sisirmez)."""
    plaka = norm_plaka(body.plaka)

    # Daire opsiyonel: unit_id veya unit_no ile cozulur (RLS ile kendi
    # tenant'inda). Verilip de bulunamazsa 422 (sessizce ziyaretci yapmayiz).
    unit_id: uuid.UUID | None = None
    unit_no: str | None = None
    if body.unit_id is not None or body.unit_no is not None:
        col = Unit.id if body.unit_id is not None else Unit.no
        val = body.unit_id if body.unit_id is not None else body.unit_no
        unit = (
            await db.execute(select(Unit).where(col == val))
        ).scalar_one_or_none()
        if unit is None:
            raise APIError(422, "invalid_reference", "daire_bulunamadi")
        unit_id, unit_no = unit.id, unit.no

    giris = body.giris_zamani
    if giris is not None:
        if giris.tzinfo is None:
            giris = giris.replace(tzinfo=timezone.utc)
        if giris > datetime.now(tz=timezone.utc) + _GELECEK_TOLERANS:
            raise APIError(422, "validation_error", "giris_zamani_gelecekte")

    obj = VehiclePass(
        tenant_id=user.tenant_id,
        plaka=plaka,
        arac_tanim=body.arac_tanim,
        unit_id=unit_id,
        ziyaretci_mi=body.ziyaretci_mi,
        kaydeden_user_id=user.id,
    )
    if giris is not None:
        obj.giris_zamani = giris
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            # uq_vehicle_pass_acik_plaka: bu plakanin acik gecisi zaten var.
            raise APIError(
                409, "conflict",
                "arac_acik_gecisi_var",
                plaka=plaka,
            )
        raise translate_integrity(exc)
    await db.refresh(obj)

    await audit_user(
        db, user, Action.VEHICLE_PASS_CREATE, resource_type="vehicle_pass",
        resource_id=obj.id, meta={"unit_id": str(unit_id) if unit_id else None},
    )
    return _out((obj, unit_no, user.ad))


# ------------------------------- cikis -------------------------------------- #
@router.post("/{pass_id}/checkout", response_model=VehiclePassOut)
async def checkout_vehicle_pass(
    pass_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OPERATOR),
) -> VehiclePassOut:
    """Arac CIKISI — `cikis_zamani` damgalanir. Zaten cikmissa 409 (ilk cikis
    zamani degismez; kargo teslim deseniyle ayni atomik kosullu UPDATE)."""
    exists = (
        await db.execute(select(VehiclePass.id).where(VehiclePass.id == pass_id))
    ).scalar_one_or_none()
    if exists is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")

    res = await db.execute(
        update(VehiclePass)
        .where(VehiclePass.id == pass_id, VehiclePass.cikis_zamani.is_(None))
        .values(cikis_zamani=func.now())
    )
    if res.rowcount == 0:
        raise APIError(409, "conflict", "arac_gecisi_zaten_kapali")

    await audit_user(
        db, user, Action.VEHICLE_PASS_CHECKOUT, resource_type="vehicle_pass",
        resource_id=pass_id,
    )
    row = (await db.execute(_base_stmt().where(VehiclePass.id == pass_id))).first()
    return _out(row)


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=VehiclePassListResponse)
async def list_vehicle_passes(
    acik: bool | None = Query(
        None, description="true: yalniz ACIK gecisler (cikis_zamani IS NULL); "
                          "false: yalniz kapanmislar"
    ),
    plaka: str | None = Query(
        None, min_length=1, max_length=32,
        description="Plaka ONEK eslesmesi (normalize edilir — '34 abc' = '34ABC')",
    ),
    baslangic: datetime | None = Query(
        None, description="giris_zamani >= (tarih filtresi)"
    ),
    bitis: datetime | None = Query(
        None, description="giris_zamani < (tarih filtresi)"
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> VehiclePassListResponse:
    stmt = _base_stmt()
    if acik is True:
        stmt = stmt.where(VehiclePass.cikis_zamani.is_(None))
    elif acik is False:
        stmt = stmt.where(VehiclePass.cikis_zamani.is_not(None))
    if plaka is not None:
        # Aramada da NORMALIZE: kullanici "34 abc" yazsa da eslesir. Kisa/bos
        # aramada 422 uretmemek icin normalize burada TOLERANSLI yapilir.
        aranan = "".join(ch for ch in plaka if ch.isalnum()).upper()
        if aranan:
            stmt = stmt.where(VehiclePass.plaka.startswith(aranan))
    # "Bugun N giris" sayaci: ?baslangic=<gun basi>&limit=1 -> meta.total
    # (/visitors ile ayni tarih-suzgeci deseni; giris_zamani uzerinden).
    if baslangic is not None:
        stmt = stmt.where(VehiclePass.giris_zamani >= baslangic)
    if bitis is not None:
        stmt = stmt.where(VehiclePass.giris_zamani < bitis)

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            stmt.order_by(VehiclePass.giris_zamani.desc(), VehiclePass.id.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return VehiclePassListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r) for r in rows],
    )


@router.get("/{pass_id}", response_model=VehiclePassOut)
async def get_vehicle_pass(
    pass_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> VehiclePassOut:
    row = (await db.execute(_base_stmt().where(VehiclePass.id == pass_id))).first()
    if row is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    return _out(row)


# --------------------------- otopark dolulugu (G4) -------------------------- #
@parking_router.get("/occupancy", response_model=ParkingOccupancyOut)
async def parking_occupancy(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OCCUPANCY_READER),
) -> ParkingOccupancyOut:
    """`dolu` = ACIK arac gecisi sayisi; `kapasite` tenant ayarindan.

    Kapasite tanimsiz (null) veya 0 ise `oran` da NULL doner — istemci "—"
    gosterir. `dolu` her zaman gercek sayidir (kapasite bilinmese de)."""
    dolu = (
        await db.execute(
            select(func.count())
            .select_from(VehiclePass)
            .where(VehiclePass.cikis_zamani.is_(None))
        )
    ).scalar_one()
    # RLS: yalnizca kendi tenant satiri gorunur.
    kapasite = (await db.execute(select(Tenant.otopark_kapasite))).scalar_one_or_none()

    oran = round(100 * dolu / kapasite) if kapasite else None
    return ParkingOccupancyOut(kapasite=kapasite, dolu=int(dolu), oran=oran)
