"""Asset (demirbas) CRUD + zimmet (checkout/checkin/history) — /contracts/openapi.yaml.

RBAC: Asset CRUD admin; checkout/checkin/history + GET admin/security/cleaning.
Checkin SAHIPLIK kontrollu (mobil §13 #6): acik zimmeti yalniz SAHIBI veya admin
kapatabilir; baskasi 403. Idempotency scan desenini (SAVEPOINT) yeniden kullanir.
Tek aktif zimmet DB'de partial unique ile garanti; uygulama da onceden kontrol
eder (anlamli 409). Mobil §13 eklemeleri: ?nfc_tag_uid ve ?checked_out_by
filtreleri, acik_zimmet ozeti, history'de alan_user_ad + order (varsayilan desc).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Header, Query, Response
from fastapi.responses import JSONResponse
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..crud_helpers import coord_eq, get_or_404, is_unique_violation, nfc_eq, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import Asset, AssetCheckout, AppUser
from ..schemas import (
    AcikZimmetOut,
    AssetCheckoutListResponse,
    AssetCheckoutOut,
    AssetCreate,
    AssetDurum,
    AssetKategori,
    AssetListResponse,
    AssetOut,
    AssetUpdate,
    CheckinRequest,
    CheckoutRequest,
)

router = APIRouter(prefix="/assets", tags=["assets"])

_ADMIN = require_role("admin")
_FIELD = require_role("admin", "security", "cleaning")


def _constraint(exc: IntegrityError) -> str | None:
    return getattr(getattr(exc, "orig", None), "constraint_name", None)


def _check_nfc(asset: Asset, nfc: str | None) -> None:
    # Normalize karsilastirma (strip+upper) — scan/task completion ile ayni davranis.
    if nfc is not None and asset.nfc_tag_uid is not None and not nfc_eq(nfc, asset.nfc_tag_uid):
        raise APIError(422, "invalid_reference", "nfc_tag_uid demirbas ile eslesmiyor.")


async def _acik_zimmetler(
    db: AsyncSession, asset_ids: list[uuid.UUID]
) -> dict[uuid.UUID, AcikZimmetOut]:
    """asset_id -> acik zimmet ozeti (alan kullanicinin adiyla)."""
    if not asset_ids:
        return {}
    rows = (
        await db.execute(
            select(AssetCheckout.asset_id, AssetCheckout.alan_user_id, AssetCheckout.alma_zamani, AppUser.ad)
            .join(AppUser, AppUser.id == AssetCheckout.alan_user_id)
            .where(
                AssetCheckout.asset_id.in_(asset_ids),
                AssetCheckout.birakma_zamani.is_(None),
            )
        )
    ).all()
    return {
        r.asset_id: AcikZimmetOut(
            alan_user_id=r.alan_user_id, alan_user_ad=r.ad, alinma_zamani=r.alma_zamani
        )
        for r in rows
    }


# -------------------------------- CRUD ------------------------------------- #
@router.get("", response_model=AssetListResponse)
async def list_assets(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    kategori: AssetKategori | None = Query(None),
    durum: AssetDurum | None = Query(None),
    aktif: bool | None = Query(None),
    nfc_tag_uid: str | None = Query(None, description="Tam eslesme (UID -> asset cozumu)"),
    checked_out_by: str | None = Query(
        None, description="'me' veya user UUID (UUID yalniz admin) — acik zimmet filtresi"
    ),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FIELD),
) -> AssetListResponse:
    where = []
    if kategori is not None:
        where.append(Asset.kategori == kategori)
    if durum is not None:
        where.append(Asset.durum == durum)
    if aktif is not None:
        where.append(Asset.aktif == aktif)
    if nfc_tag_uid is not None:
        where.append(Asset.nfc_tag_uid == nfc_tag_uid)
    if checked_out_by is not None:
        if checked_out_by == "me":
            target = user.id
        else:
            try:
                target = uuid.UUID(checked_out_by)
            except ValueError:
                raise APIError(422, "validation_error", "checked_out_by 'me' veya UUID olmali.")
            if user.role != "admin":
                raise APIError(403, "forbidden", "checked_out_by=<uuid> yalniz admin; 'me' kullanin.")
        where.append(
            Asset.id.in_(
                select(AssetCheckout.asset_id).where(
                    AssetCheckout.alan_user_id == target,
                    AssetCheckout.birakma_zamani.is_(None),
                )
            )
        )
    total = (await db.execute(select(func.count()).select_from(Asset).where(*where))).scalar_one()
    rows = (
        await db.execute(
            select(Asset).where(*where).order_by(Asset.created_at).limit(limit).offset(offset)
        )
    ).scalars().all()
    acik = await _acik_zimmetler(db, [a.id for a in rows])
    items = []
    for a in rows:
        out = AssetOut.model_validate(a)
        out.acik_zimmet = acik.get(a.id)
        items.append(out)
    return AssetListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=items)


@router.get("/{asset_id}", response_model=AssetOut)
async def get_asset(
    asset_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_FIELD),
) -> AssetOut:
    asset = await get_or_404(db, Asset, asset_id)
    out = AssetOut.model_validate(asset)
    out.acik_zimmet = (await _acik_zimmetler(db, [asset.id])).get(asset.id)
    return out


@router.post("", response_model=AssetOut, status_code=201)
async def create_asset(
    body: AssetCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> Asset:
    obj = Asset(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "nfc_tag_uid bu tenant'ta zaten kayitli.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{asset_id}", response_model=AssetOut)
async def update_asset(
    asset_id: uuid.UUID,
    body: AssetUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Asset:
    obj = await get_or_404(db, Asset, asset_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "nfc_tag_uid bu tenant'ta zaten kayitli.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.delete("/{asset_id}", status_code=204)
async def delete_asset(
    asset_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> Response:
    obj = await get_or_404(db, Asset, asset_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)


# ------------------------------ zimmet ------------------------------------- #
def _same_checkout(existing: AssetCheckout, *, asset_id, alan_user_id, nfc, gps_lat, gps_lng, notlar) -> bool:
    return (
        existing.asset_id == asset_id
        and existing.alan_user_id == alan_user_id
        and existing.alma_nfc_tag_uid == nfc
        and coord_eq(existing.alma_gps_lat, gps_lat)
        and coord_eq(existing.alma_gps_lng, gps_lng)
        and existing.notlar == notlar
    )


async def _open_checkout(db: AsyncSession, asset_id: uuid.UUID) -> AssetCheckout | None:
    return (
        await db.execute(
            select(AssetCheckout).where(
                AssetCheckout.asset_id == asset_id,
                AssetCheckout.birakma_zamani.is_(None),
            )
        )
    ).scalar_one_or_none()


async def _user_ad(db: AsyncSession, user_id: uuid.UUID) -> str | None:
    return (await db.execute(select(AppUser.ad).where(AppUser.id == user_id))).scalar_one_or_none()


async def _co_payload(db: AsyncSession, co: AssetCheckout, alan_user_ad: str | None = None) -> dict:
    out = AssetCheckoutOut.model_validate(co)
    out.alan_user_ad = alan_user_ad if alan_user_ad is not None else await _user_ad(db, co.alan_user_id)
    if co.birakan_user_id is not None:
        out.birakan_user_ad = await _user_ad(db, co.birakan_user_id)
    return out.model_dump(mode="json")


@router.post("/{asset_id}/checkout")
async def checkout(
    asset_id: uuid.UUID,
    body: CheckoutRequest,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FIELD),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "Idempotency-Key header zorunlu.")
    asset = await get_or_404(db, Asset, asset_id)
    _check_nfc(asset, body.nfc_tag_uid)

    # 1) idempotent tekrar
    existing = (
        await db.execute(
            select(AssetCheckout).where(AssetCheckout.idempotency_key == idempotency_key)
        )
    ).scalar_one_or_none()
    if existing is not None:
        if _same_checkout(
            existing, asset_id=asset_id, alan_user_id=user.id, nfc=body.nfc_tag_uid,
            gps_lat=body.gps_lat, gps_lng=body.gps_lng, notlar=body.notlar,
        ):
            return JSONResponse(status_code=200, content=await _co_payload(db, existing))
        raise APIError(409, "conflict", "Ayni Idempotency-Key farkli govde ile gonderildi.")

    # 2) zaten zimmetli mi?
    if await _open_checkout(db, asset_id) is not None:
        raise APIError(409, "conflict", "Demirbas zaten zimmetli.")

    # 3) yeni zimmet (race-safe SAVEPOINT)
    obj = AssetCheckout(
        tenant_id=user.tenant_id,
        asset_id=asset_id,
        alan_user_id=user.id,
        alma_nfc_tag_uid=body.nfc_tag_uid,
        alma_gps_lat=body.gps_lat,
        alma_gps_lng=body.gps_lng,
        notlar=body.notlar,
        idempotency_key=idempotency_key,
    )
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        try:
            db.expunge(obj)
        except Exception:
            pass
        if _constraint(exc) == "uq_asset_open_checkout":
            raise APIError(409, "conflict", "Demirbas zaten zimmetli.")
        if is_unique_violation(exc):  # idempotency yarisi
            again = (
                await db.execute(
                    select(AssetCheckout).where(AssetCheckout.idempotency_key == idempotency_key)
                )
            ).scalar_one()
            if _same_checkout(
                again, asset_id=asset_id, alan_user_id=user.id, nfc=body.nfc_tag_uid,
                gps_lat=body.gps_lat, gps_lng=body.gps_lng, notlar=body.notlar,
            ):
                return JSONResponse(status_code=200, content=await _co_payload(db, again))
            raise APIError(409, "conflict", "Ayni Idempotency-Key farkli govde ile gonderildi.")
        raise translate_integrity(exc)

    asset.durum = "zimmetli"
    await db.flush()
    await db.refresh(obj)
    return JSONResponse(status_code=201, content=await _co_payload(db, obj, alan_user_ad=user.ad))


@router.post("/{asset_id}/checkin")
async def checkin(
    asset_id: uuid.UUID,
    body: CheckinRequest,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FIELD),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "Idempotency-Key header zorunlu.")
    asset = await get_or_404(db, Asset, asset_id)
    _check_nfc(asset, body.nfc_tag_uid)

    # idempotent tekrar: bu key ile zaten birakilmis mi?
    prev = (
        await db.execute(
            select(AssetCheckout).where(AssetCheckout.birakma_idempotency_key == idempotency_key)
        )
    ).scalar_one_or_none()
    if prev is not None:
        return JSONResponse(status_code=200, content=await _co_payload(db, prev))

    open_co = await _open_checkout(db, asset_id)
    if open_co is None:
        raise APIError(409, "conflict", "Acik zimmet yok (demirbas zaten musait).")

    # SAHIPLIK (mobil §13 #6): yalniz zimmetin sahibi veya admin kapatabilir.
    if open_co.alan_user_id != user.id and user.role != "admin":
        raise APIError(403, "forbidden", "Zimmet baskasinin uzerinde; yalniz sahibi veya admin birakabilir.")

    open_co.birakan_user_id = user.id
    open_co.birakma_zamani = datetime.now(tz=timezone.utc)
    open_co.birakma_nfc_tag_uid = body.nfc_tag_uid
    open_co.birakma_gps_lat = body.gps_lat
    open_co.birakma_gps_lng = body.gps_lng
    if body.notlar is not None:
        open_co.notlar = body.notlar
    open_co.birakma_idempotency_key = idempotency_key
    asset.durum = "musait"
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):  # birakma idempotency yarisi
            again = (
                await db.execute(
                    select(AssetCheckout).where(
                        AssetCheckout.birakma_idempotency_key == idempotency_key
                    )
                )
            ).scalar_one()
            return JSONResponse(status_code=200, content=await _co_payload(db, again))
        raise translate_integrity(exc)
    await db.refresh(open_co)
    return JSONResponse(status_code=200, content=await _co_payload(db, open_co))


@router.get("/{asset_id}/history", response_model=AssetCheckoutListResponse)
async def asset_history(
    asset_id: uuid.UUID,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    order: Literal["asc", "desc"] = Query("desc", description="alma_zamani sirasi (varsayilan: en yeni ustte)"),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_FIELD),
) -> AssetCheckoutListResponse:
    await get_or_404(db, Asset, asset_id)
    base = AssetCheckout.asset_id == asset_id
    total = (await db.execute(select(func.count()).select_from(AssetCheckout).where(base))).scalar_one()
    sirala = AssetCheckout.alma_zamani.asc() if order == "asc" else AssetCheckout.alma_zamani.desc()
    birakan = aliased(AppUser)
    rows = (
        await db.execute(
            select(AssetCheckout, AppUser.ad, birakan.ad)
            .join(AppUser, AppUser.id == AssetCheckout.alan_user_id)
            .outerjoin(birakan, birakan.id == AssetCheckout.birakan_user_id)
            .where(base)
            .order_by(sirala)
            .limit(limit)
            .offset(offset)
        )
    ).all()
    items = []
    for co, alan_ad, birakan_ad in rows:
        out = AssetCheckoutOut.model_validate(co)
        out.alan_user_ad = alan_ad
        out.birakan_user_ad = birakan_ad
        items.append(out)
    return AssetCheckoutListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=items
    )
