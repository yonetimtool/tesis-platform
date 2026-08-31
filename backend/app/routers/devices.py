"""Cihaz (FCM push token) kaydi — /contracts/openapi.yaml.

POST /devices     : kendi cihazini kaydet/guncelle (idempotent upsert; her rol).
DELETE /devices/{fcm_token}: kendi token'ini pasiflestir (logout/uninstall).
GET /devices      : tenant cihazlari (admin, debug).

tenant token'dan; RLS ile izole. UNIQUE(tenant_id, fcm_token) -> ayni token tek kayit.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_current_user, get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, UserDevice
from ..schemas import DeviceListResponse, DeviceOut, DeviceRegister, PageMetaOut

router = APIRouter(prefix="/devices", tags=["devices"])

_ADMIN = require_role("admin")


@router.post("", response_model=DeviceOut, status_code=201)
async def register_device(
    body: DeviceRegister,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> UserDevice:
    # (P191-ek §1) AYNI CIHAZ ICIN TEK SATIR.
    #
    # OLCULEN KUSUR: bir tesiste 18 kayitli cihaz vardi ve HEPSI tek
    # kullaniciya aitti. Uygulama her yeniden kurulumda FCM'den YENI jeton
    # alir; tekillik `(tenant, fcm_token)` oldugu icin her yeni jeton YENI
    # SATIR aciyor, eskisi "aktif" kaliyor ve her gonderimde bosuna
    # deneniyordu (FCM `UNREGISTERED`).
    #
    # Jeton bir CIHAZ KIMLIGI DEGILDIR — cihazin o anki adresidir. Istemci
    # kararli bir kurulum kimligi gonderiyorsa, AYNI cihazin onceki
    # jetonlari once pasiflestirilir. Kimlik gondermeyen eski surumlerde
    # eski davranis aynen surer (alan NULLABLE).
    if body.cihaz_kimligi:
        await db.execute(
            update(UserDevice)
            .where(
                UserDevice.user_id == user.id,
                UserDevice.cihaz_kimligi == body.cihaz_kimligi,
                UserDevice.fcm_token != body.fcm_token,
                UserDevice.aktif.is_(True),
            )
            .values(aktif=False, updated_at=func.now())
        )
    # Idempotent upsert: ayni (tenant, token) -> sahibi/platform guncellenir + aktiflesir.
    stmt = pg_insert(UserDevice).values(
        tenant_id=user.tenant_id,
        user_id=user.id,
        fcm_token=body.fcm_token,
        platform=body.platform,
        # Dil GONDERILMEZSE `tr` (kolon varsayilani ile ayni): eski istemciler
        # bugunku davranisi korur. Istemci dili degistirince YENIDEN kaydeder.
        dil=body.dil or "tr",
        cihaz_kimligi=body.cihaz_kimligi,
        aktif=True,
    )
    stmt = stmt.on_conflict_do_update(
        constraint="uq_user_device_tenant_token",
        set_={
            "user_id": stmt.excluded.user_id,
            "platform": stmt.excluded.platform,
            "dil": stmt.excluded.dil,
            # Kimlik GONDERILMEDIYSE mevcut deger KORUNUR: bir surum
            # yukseltmesinde alanin gecici olarak bos gelmesi, daha once
            # ogrenilmis kimligi silmemeli.
            "cihaz_kimligi": func.coalesce(
                stmt.excluded.cihaz_kimligi, UserDevice.cihaz_kimligi
            ),
            "aktif": True,
            "updated_at": func.now(),
        },
    )
    await db.execute(stmt)
    await db.flush()
    obj = (
        await db.execute(select(UserDevice).where(UserDevice.fcm_token == body.fcm_token))
    ).scalar_one()
    return obj


@router.delete("/{fcm_token}", status_code=204)
async def unregister_device(
    fcm_token: str,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> Response:
    # Kullanici yalniz KENDI cihazini pasiflestirir.
    obj = (
        await db.execute(
            select(UserDevice).where(
                UserDevice.fcm_token == fcm_token,
                UserDevice.user_id == user.id,
                UserDevice.aktif.is_(True),
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "aktif_cihaz_bulunamadi")
    obj.aktif = False
    obj.updated_at = func.now()
    await db.flush()
    return Response(status_code=204)


@router.get("", response_model=DeviceListResponse)
async def list_devices(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> DeviceListResponse:
    total = (
        await db.execute(select(func.count()).select_from(UserDevice))
    ).scalar_one()
    rows = (
        await db.execute(
            select(UserDevice).order_by(UserDevice.created_at.desc(), UserDevice.id.desc()).limit(limit).offset(offset)
        )
    ).scalars().all()
    return DeviceListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=total), items=list(rows)
    )
