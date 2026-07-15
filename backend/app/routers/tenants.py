"""POST/GET /tenants — admin (platform) cross-tenant tesis olusturma/listeleme.

Onboarding Model A: admin bir tenant (isimsiz, kurulum_tamamlandi=false) +
yonetici hesabini birlikte acar; yonetici ILK GIRISTE POST /tenant/setup ile
adlandirir. tenant RLS FORCE oldugundan cross-tenant islem owner-sahipli
SECURITY DEFINER fonksiyonlarla yapilir (create_tenant_with_yonetici /
list_all_tenants); YALNIZ admin'e acilir (RBAC). tenant_id GIZLI kimliktir.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from ..db import SessionLocal
from ..deps import require_role
from ..errors import APIError
from ..models import AppUser
from ..schemas import (
    TenantAdminCreate,
    TenantAdminCreatedOut,
    TenantAdminListItem,
    TenantAdminListResponse,
)
from ..security import (
    generate_temp_code,
    hash_password,
    normalize_phone,
    slugify_tenant,
)

router = APIRouter(prefix="/tenants", tags=["tenant"])

_ADMIN = require_role("admin")

# Yonetici tesisi adlandirana kadar gorunecek yer tutucu ad.
_PLACEHOLDER_AD = "(Kurulum bekliyor)"


@router.post("", response_model=TenantAdminCreatedOut, status_code=201)
async def create_tenant(
    body: TenantAdminCreate,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminCreatedOut:
    """Admin: yeni tenant (isimsiz, kurulum_tamamlandi=false) + yonetici acar.
    Parola verilirse dogrudan belirlenir; verilmezse gecici kod uretilir (bir
    kez doner). Telefon global benzersiz -> cakisma 409."""
    try:
        phone = normalize_phone(body.phone)
    except ValueError:
        raise APIError(422, "validation_error", "Gecersiz telefon numarasi.")

    temp_code: str | None = None
    if body.password is not None:
        password_hash = hash_password(body.password)
        password_set = True
        temp_code_hash = None
    else:
        temp_code = generate_temp_code()
        password_hash = None
        password_set = False
        temp_code_hash = hash_password(temp_code)

    async with SessionLocal() as session:
        async with session.begin():
            try:
                row = (
                    await session.execute(
                        text(
                            "SELECT tenant_id, user_id FROM "
                            "public.create_tenant_with_yonetici("
                            ":ad, :slug, :tz, :yad, :tel, :ph, :pset, :tch, :kur)"
                        ),
                        {
                            "ad": _PLACEHOLDER_AD,
                            "slug": slugify_tenant(_PLACEHOLDER_AD),
                            "tz": "Europe/Istanbul",
                            "yad": body.yonetici_ad,
                            "tel": phone,
                            "ph": password_hash,
                            "pset": password_set,
                            "tch": temp_code_hash,
                            "kur": False,
                        },
                    )
                ).one()
            except IntegrityError:
                raise APIError(409, "conflict", "Bu telefon zaten kayitli.")

    return TenantAdminCreatedOut(
        tenant_id=row.tenant_id,
        yonetici_user_id=row.user_id,
        temp_code=temp_code,
    )


@router.get("", response_model=TenantAdminListResponse)
async def list_tenants(
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminListResponse:
    """Admin: TUM tesisler (id + ad + kurulum durumu + tarih). Baska tenant
    verisi (kullanici vb.) donmez."""
    async with SessionLocal() as session:
        async with session.begin():
            rows = (
                await session.execute(
                    text(
                        "SELECT id, ad, kurulum_tamamlandi, created_at "
                        "FROM public.list_all_tenants()"
                    )
                )
            ).all()
    return TenantAdminListResponse(
        items=[
            TenantAdminListItem(
                id=r.id,
                ad=r.ad,
                kurulum_tamamlandi=r.kurulum_tamamlandi,
                created_at=r.created_at,
            )
            for r in rows
        ]
    )
