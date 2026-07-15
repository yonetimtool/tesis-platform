"""Dis Hizmetler — /external-services.

Site yoneticisinin girdigi guvenilir esnaf/hizmet kisileri (cilingir/elektrik/
tesisat...) + bir bolum notu (yonetici serbest metni). Gorunurluk: TUM mobil
roller (yonetici/guvenlik/sakin) OKUR; yazma admin + yonetici. RLS ile tenant
izole. Not tenant.dis_hizmet_notu'nda tutulur.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..models import AppUser, DisHizmet, Tenant
from ..schemas import (
    DisHizmetCreate,
    DisHizmetListResponse,
    DisHizmetNoteUpdate,
    DisHizmetOut,
    DisHizmetUpdate,
)

router = APIRouter(prefix="/external-services", tags=["external-services"])

# Okuma: tum mobil roller (guvenilir esnafi herkes gorur/arayabilir).
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
# Yazma (kisi + not): admin + yonetici.
_WRITER = require_role("admin", "yonetici")


@router.get("", response_model=DisHizmetListResponse)
async def list_external_services(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> DisHizmetListResponse:
    """Bolum notu + kisiler (ture, sonra ada gore sirali). RLS ile tenant-ici."""
    note = (await db.execute(select(Tenant.dis_hizmet_notu))).scalar_one_or_none()
    rows = (
        await db.execute(
            select(DisHizmet).order_by(DisHizmet.tur, DisHizmet.ad, DisHizmet.soyad)
        )
    ).scalars().all()
    return DisHizmetListResponse(
        note=note,
        items=[DisHizmetOut.model_validate(r) for r in rows],
    )


@router.post("", response_model=DisHizmetOut, status_code=201)
async def create_external_service(
    body: DisHizmetCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> DisHizmet:
    obj = DisHizmet(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    await db.flush()
    await db.refresh(obj)
    return obj


@router.patch("/{service_id}", response_model=DisHizmetOut)
async def update_external_service(
    service_id: uuid.UUID,
    body: DisHizmetUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_WRITER),
) -> DisHizmet:
    obj = await get_or_404(db, DisHizmet, service_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    await db.flush()
    await db.refresh(obj)
    return obj


@router.delete("/{service_id}", status_code=204)
async def delete_external_service(
    service_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_WRITER),
) -> Response:
    obj = await get_or_404(db, DisHizmet, service_id)
    await db.delete(obj)
    await db.flush()
    return Response(status_code=204)


@router.put("/note", response_model=DisHizmetListResponse)
async def set_note(
    body: DisHizmetNoteUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_WRITER),
) -> DisHizmetListResponse:
    """Bolum notunu ayarla (yonetici). Guncel liste + not doner."""
    tenant = (await db.execute(select(Tenant))).scalar_one_or_none()
    if tenant is not None:
        tenant.dis_hizmet_notu = body.note
        await db.flush()
    rows = (
        await db.execute(
            select(DisHizmet).order_by(DisHizmet.tur, DisHizmet.ad, DisHizmet.soyad)
        )
    ).scalars().all()
    return DisHizmetListResponse(
        note=body.note,
        items=[DisHizmetOut.model_validate(r) for r in rows],
    )
