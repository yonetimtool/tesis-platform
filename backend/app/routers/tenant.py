"""Tenant ayarlari — GET/PATCH /tenant/settings — /contracts/openapi.yaml.

Acil durumda mobilin arayacagi `acil_durum_telefon` buradan okunur. RLS sayesinde
yalnizca token'daki tenant'in satiri gorunur (id = current_tenant).
RBAC: okuma tum roller (herkes kendi sitesinin adini gorur — ana ekran basligi);
guncelleme admin; ilk-giris adlandirma (setup) yonetici.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Tenant
from ..schemas import TenantSettings, TenantSettingsUpdate, TenantSetupRequest

router = APIRouter(prefix="/tenant", tags=["tenant"])

_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident"
)
_ADMIN = require_role("admin")
_YONETICI = require_role("yonetici")


def _to_settings(t: Tenant) -> TenantSettings:
    return TenantSettings(
        tenant_id=t.id, ad=t.ad, slug=t.slug, timezone=t.timezone,
        acil_durum_telefon=t.acil_durum_telefon,
        kurulum_tamamlandi=t.kurulum_tamamlandi,
    )


async def _current_tenant(db: AsyncSession) -> Tenant:
    # RLS: yalnizca current tenant'in satiri gorunur.
    t = (await db.execute(select(Tenant))).scalar_one_or_none()
    if t is None:
        raise APIError(404, "not_found", "Tenant bulunamadi.")
    return t


@router.get("/settings", response_model=TenantSettings)
async def get_settings(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> TenantSettings:
    return _to_settings(await _current_tenant(db))


@router.patch("/settings", response_model=TenantSettings)
async def update_settings(
    body: TenantSettingsUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> TenantSettings:
    t = await _current_tenant(db)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(t, key, value)
    await db.flush()
    await db.refresh(t)
    return _to_settings(t)


@router.post("/setup", response_model=TenantSettings)
async def setup_tenant(
    body: TenantSetupRequest,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETICI),
) -> TenantSettings:
    """Yonetici ILK GIRISTE tesisini adlandirir (onboarding Model A):
    admin isimsiz tenant + yonetici acmisti; yonetici burada adi belirler ve
    kurulum_tamamlandi=true olur. Zaten kuruluysa 409."""
    t = await _current_tenant(db)
    if t.kurulum_tamamlandi:
        raise APIError(409, "conflict", "Tesis zaten kuruldu.")
    t.ad = body.ad
    t.kurulum_tamamlandi = True
    await db.flush()
    await db.refresh(t)
    return _to_settings(t)
