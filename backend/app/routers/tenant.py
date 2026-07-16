"""Tenant ayarlari — GET/PATCH /tenant/settings + POST /tenant/setup.

RLS sayesinde yalnizca token'daki tenant'in satiri gorunur (id = current_tenant).

RBAC:
  - okuma: TUM roller (herkes kendi tesisinin adini gorur — ana ekran basligi)
  - guncelleme: admin (ad + timezone + yonetim_email) / yonetici (YALNIZ ad)
  - ilk-giris adlandirma (setup): YALNIZ BIRINCIL yonetici

`slug` ve tenant `id` bu uclarin HICBIRINDE degismez (yalniz `ad` yazilir);
login/slug akislari etkilenmez.
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
_YONETICI = require_role("yonetici")
_ADMIN_VEYA_YONETICI = require_role("admin", "yonetici")

# Yonetici YALNIZ tesis adini degistirebilir; yapilandirma admin'de kalir
# (yetki yukseltme yok).
_YONETICI_YAZABILIR = {"ad"}


def _to_settings(t: Tenant) -> TenantSettings:
    return TenantSettings(
        tenant_id=t.id, ad=t.ad, slug=t.slug, timezone=t.timezone,
        kurulum_tamamlandi=t.kurulum_tamamlandi,
        yonetim_email=t.yonetim_email,
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
    user: AppUser = Depends(_ADMIN_VEYA_YONETICI),
) -> TenantSettings:
    """admin: ad + timezone + yonetim_email. yonetici: YALNIZ ad (tesisini
    yeniden adlandirir); baska alan gonderirse 403. slug'a ASLA yazilmaz."""
    data = body.model_dump(exclude_unset=True)
    if user.role == "yonetici" and not set(data) <= _YONETICI_YAZABILIR:
        raise APIError(
            403, "forbidden", "Yonetici yalniz tesis adini degistirebilir."
        )
    t = await _current_tenant(db)
    for key, value in data.items():
        setattr(t, key, value)
    await db.flush()
    await db.refresh(t)
    return _to_settings(t)


@router.post("/setup", response_model=TenantSettings)
async def setup_tenant(
    body: TenantSetupRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETICI),
) -> TenantSettings:
    """BIRINCIL yonetici ILK GIRISTE tesisini adlandirir (onboarding Model A):
    admin tenant + yonetici(ler) acmisti; birincil burada adi belirler ve
    kurulum_tamamlandi=true olur.

    Birincil olmayan yonetici 403 — kapi mobilde yalniz birincile gosterilir,
    uc de eslesmelidir (aksi halde istemci tarafi bir kisit olarak kalirdi).
    Zaten kuruluysa 409."""
    if not user.birincil:
        raise APIError(
            403, "forbidden", "Tesisi yalniz birincil yonetici adlandirabilir."
        )
    t = await _current_tenant(db)
    if t.kurulum_tamamlandi:
        raise APIError(409, "conflict", "Tesis zaten kuruldu.")
    t.ad = body.ad
    t.kurulum_tamamlandi = True
    await db.flush()
    await db.refresh(t)
    return _to_settings(t)
