"""Dis sistem entegrasyonlari (C1b) — konfigurasyon CRUD + SSRF-korumali tetik.

RBAC (auth.md §4): YALNIZ admin + yonetici yonetir/tetikler; digerleri 403.
Sir (auth_secret) KEK ile sifreli saklanir, GET'te ASLA donmez (write-only;
`auth_secret_set` bool). Tetik SSRF kapisindan gecer (bkz. app.safe_http) —
ic/ozel hedefler REDDEDILIR. channel_type C1a kanal soyutlamasini genisletir.
tenant token'dan; RLS izole.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from fastapi.concurrency import run_in_threadpool
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404, translate_integrity
from ..crypto import decrypt_secret, encrypt_secret
from ..deps import get_tenant_db, require_role
from ..integrations_presets import PRESETS, render_template
from ..models import AppUser, Integration
from ..safe_http import SSRFBlocked, send_webhook
from ..schemas import (
    IntegrationCreate,
    IntegrationListResponse,
    IntegrationOut,
    IntegrationPresetOut,
    IntegrationTriggerIn,
    IntegrationTriggerOut,
    IntegrationUpdate,
)

router = APIRouter(prefix="/integrations", tags=["integrations"])

# YALNIZ yonetim (admin + yonetici) — dis sistem tanimi/tetigi hassastir.
_MANAGER = require_role("admin", "yonetici")


def _apply_auth(headers: dict[str, str], auth_type: str, secret: str | None) -> None:
    """Sifresi cozulmus siri auth turune gore header'a ekle (istek aninda)."""
    if not secret:
        return
    if auth_type == "bearer":
        headers["Authorization"] = f"Bearer {secret}"
    elif auth_type == "api_key":
        headers["X-API-Key"] = secret


# ------------------------------- presetler ---------------------------------- #
@router.get("/presets", response_model=list[IntegrationPresetOut])
async def list_presets(_: AppUser = Depends(_MANAGER)) -> list[IntegrationPresetOut]:
    """Form on-doldurma icin PRESET sablonlari (generic webhook uzerinde)."""
    return [
        IntegrationPresetOut(
            key=key,
            channel_type=p["channel_type"],
            http_method=p["http_method"],
            headers_json=p["headers_json"],
            payload_template=p["payload_template"],
        )
        for key, p in PRESETS.items()
    ]


# -------------------------------- CRUD -------------------------------------- #
@router.post("", response_model=IntegrationOut, status_code=201)
async def create_integration(
    body: IntegrationCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> IntegrationOut:
    obj = Integration(
        tenant_id=user.tenant_id,
        ad=body.ad,
        channel_type=body.channel_type,
        endpoint_url=body.endpoint_url,
        http_method=body.http_method,
        headers_json=body.headers_json,
        auth_type=body.auth_type,
        auth_secret_enc=(
            encrypt_secret(body.auth_secret) if body.auth_secret else None
        ),
        payload_template=body.payload_template,
        aktif=body.aktif,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return IntegrationOut.from_model(obj)


@router.get("", response_model=IntegrationListResponse)
async def list_integrations(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    aktif: bool | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> IntegrationListResponse:
    where = []
    if aktif is not None:
        where.append(Integration.aktif == aktif)
    total = (
        await db.execute(select(func.count()).select_from(Integration).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(Integration).where(*where).order_by(Integration.ad).limit(limit).offset(offset)
        )
    ).scalars().all()
    return IntegrationListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[IntegrationOut.from_model(r) for r in rows],
    )


@router.get("/{integration_id}", response_model=IntegrationOut)
async def get_integration(
    integration_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> IntegrationOut:
    obj = await get_or_404(db, Integration, integration_id)
    return IntegrationOut.from_model(obj)


@router.patch("/{integration_id}", response_model=IntegrationOut)
async def update_integration(
    integration_id: uuid.UUID,
    body: IntegrationUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> IntegrationOut:
    obj = await get_or_404(db, Integration, integration_id)
    data = body.model_dump(exclude_unset=True)
    # Sir ozel islenir (write-only): verildiyse yeniden sifrele; bos ise temizle.
    if "auth_secret" in data:
        secret = data.pop("auth_secret")
        obj.auth_secret_enc = encrypt_secret(secret) if secret else None
    for key, value in data.items():
        setattr(obj, key, value)
    # auth_type 'none' yapildiysa sir anlamsiz — temizle.
    if obj.auth_type == "none":
        obj.auth_secret_enc = None
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return IntegrationOut.from_model(obj)


@router.delete("/{integration_id}", status_code=204)
async def delete_integration(
    integration_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> Response:
    obj = await get_or_404(db, Integration, integration_id)
    await db.delete(obj)
    await db.flush()
    return Response(status_code=204)


# -------------------------------- tetik ------------------------------------- #
@router.post("/{integration_id}/trigger", response_model=IntegrationTriggerOut)
async def trigger_integration(
    integration_id: uuid.UUID,
    body: IntegrationTriggerIn,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> IntegrationTriggerOut:
    """Entegrasyonu tetikle: payload_template render + SSRF-korumali HTTP gonder.

    Donen {ok, status, error}: 2xx -> ok=true. SSRF engeli / ag / HTTP hatasi ->
    ok=false + error (ic ayrinti sizmadan). Panel "Test" butonu bunu gosterir.
    """
    obj = await get_or_404(db, Integration, integration_id)

    payload = render_template(
        obj.payload_template, message=body.message, title=body.title
    )
    headers = dict(obj.headers_json or {})
    if obj.auth_secret_enc:
        _apply_auth(headers, obj.auth_type, decrypt_secret(obj.auth_secret_enc))
    content = payload.encode("utf-8") if payload else None

    try:
        result = await run_in_threadpool(
            send_webhook,
            obj.http_method,
            obj.endpoint_url,
            headers=headers,
            content=content,
        )
    except SSRFBlocked as exc:
        return IntegrationTriggerOut(ok=False, status=None, error=str(exc))
    return IntegrationTriggerOut(
        ok=result.ok, status=result.status, error=result.error
    )
