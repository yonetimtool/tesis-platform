"""Kamera yonetimi — admin/yonetici CRUD + ROL BAZLI gorunurluk.

Akis (urun sahibi sabit):
  1. Yonetim kamera ekler: ad + opsiyonel konum + yayin URL'i + tur
     (hls|mp4|rtsp) + aktif + `sakin_gorebilir`.
  2. `sakin_gorebilir` TEK anahtardir: sakin/tesis gorevlisi YALNIZ
     `aktif=true AND sakin_gorebilir=true` kameralari gorur. Varsayilan
     KAPALI — kamera mahremiyet tasir (KVKK), gorunurluk acik karardir.
  3. Suzgec SUNUCUDA uygulanir: istemci "hangi kamerayi gorebilirim"
     hesabini yapmaz ve gizli kamera yaniti HIC terk etmez.

RBAC (auth.md §4): YAZMA admin+yonetici (duyuru/kamera deseni — panel ve
mobil yonetici ayni yetkiyi tasir). OKUMA:
  * admin + yonetici + security -> TUM kameralar (pasifler dahil; operasyon)
  * resident + tesis_gorevlisi   -> yalniz aktif + sakin_gorebilir

Not (onceki davranistan sapma): resident/tesis_gorevlisi eskiden /cameras'a
403 aliyordu. Artik 200 alir ama YALNIZ yonetimin acik ettigi kameralari
gorur — varsayilan `sakin_gorebilir=false` oldugu icin mevcut kayitlarin
gorunurlugu DEGISMEZ (kapali kalir).

Yayin turu: hls/mp4 istemcide oynar; rtsp SAKLANIR ama istemci natively
oynatamaz -> yanit `oynatilabilir=false` isaretler (ileride medya gecidi).
URL semasi tur ile tutarli olmali (hls/mp4 -> http(s), rtsp -> rtsp://).
Backend yayini HIC cekmez (istemci oynatir) => SSRF yuzeyi yok.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Camera
from ..schemas import (
    CameraCreate,
    CameraListResponse,
    CameraOut,
    CameraUpdate,
    dogrula_url_tur,
    oynatilabilir_mi,
)

router = APIRouter(prefix="/cameras", tags=["cameras"])

_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident"
)
_WRITER = require_role("admin", "yonetici")

# Tum kameralari (pasif/gizli dahil) goren roller — operasyon + yonetim.
_TAM_GORUS: frozenset[str] = frozenset({"admin", "yonetici", "security"})


def _out(obj: Camera) -> CameraOut:
    out = CameraOut.model_validate(obj)
    out.oynatilabilir = oynatilabilir_mi(obj.tur)
    return out


def _url_tur_dogrula(stream_url: str, tur: str) -> None:
    """Sema/tur tutarliligi — ValueError'i 422 API hatasina cevirir."""
    try:
        dogrula_url_tur(stream_url, tur)
    except ValueError as exc:
        raise APIError(422, "invalid_stream_url", str(exc))


@router.get("", response_model=CameraListResponse)
async def list_cameras(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    aktif: bool | None = Query(
        None,
        description=(
            "Yonetim/operasyon suzgeci. Sakin ve tesis gorevlisi icin YOK "
            "SAYILIR: o roller her durumda yalniz aktif+gorunur kameralari alir."
        ),
    ),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> CameraListResponse:
    stmt = select(Camera)
    sayim = select(func.count()).select_from(Camera)

    if user.role not in _TAM_GORUS:
        # KVKK kapisi: sakin/tesis gorevlisi icin suzgec ZORUNLU ve
        # istemciden gelen `aktif` parametresi bunu genisletemez.
        kosul = (Camera.aktif.is_(True)) & (Camera.sakin_gorebilir.is_(True))
        stmt = stmt.where(kosul)
        sayim = sayim.where(kosul)
    elif aktif is not None:
        stmt = stmt.where(Camera.aktif.is_(aktif))
        sayim = sayim.where(Camera.aktif.is_(aktif))

    total = (await db.execute(sayim)).scalar_one()
    rows = (
        await db.execute(stmt.order_by(Camera.ad).limit(limit).offset(offset))
    ).scalars().all()
    return CameraListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r) for r in rows],
    )


@router.post("", response_model=CameraOut, status_code=201)
async def create_camera(
    body: CameraCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> CameraOut:
    obj = Camera(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.CAMERA_CREATE, resource_type="camera",
                     resource_id=obj.id,
                     meta={"ad": obj.ad, "tur": obj.tur,
                           "sakin_gorebilir": obj.sakin_gorebilir})
    await db.refresh(obj)
    return _out(obj)


@router.patch("/{camera_id}", response_model=CameraOut)
async def update_camera(
    camera_id: uuid.UUID,
    body: CameraUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> CameraOut:
    obj = await get_or_404(db, Camera, camera_id)
    alanlar = body.model_dump(exclude_unset=True)
    # URL/tur tutarliligi MEVCUT kayitla birlestirilerek dogrulanir: yalniz
    # `tur` degistirilse bile eski URL'in semasi yeni ture uymak zorundadir.
    _url_tur_dogrula(
        alanlar.get("stream_url", obj.stream_url),
        alanlar.get("tur", obj.tur),
    )
    for key, value in alanlar.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.CAMERA_UPDATE, resource_type="camera",
                     resource_id=obj.id, meta={"alanlar": sorted(alanlar)})
    await db.refresh(obj)
    return _out(obj)


@router.delete("/{camera_id}", status_code=204)
async def delete_camera(
    camera_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Response:
    obj = await get_or_404(db, Camera, camera_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(db, user, Action.CAMERA_DELETE, resource_type="camera",
                     resource_id=camera_id)
    return Response(status_code=204)
