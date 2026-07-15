"""POST /residents — yonetici daire + sakin hesabini tek adimda acar.

Sakin kimlik modeli (bkz. /contracts/auth.md §1.2): sakin email ile DEGIL,
daire no + parola ile girer. Yonetici sakini olustururken TEK SEFERLIK gecici
kod uretilir; kod yalniz bu yanitta duz metin doner (yonetici sakine iletir),
DB'de bcrypt hash'i saklanir. Sakin ilk giriste kodu kullanir ve kalici
parolasini belirlemek zorundadir (/auth/set-password).

RBAC: yonetici + admin (unit CRUD'un admin-only olmasi bundan ayridir; bu uc
yoneticinin sakin acma akisidir ve unit'i gerekirse ortulu olusturur).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Response
from sqlalchemy import and_, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitResident
from ..schemas import (
    ResidentCreate,
    ResidentCreatedOut,
    ResidentListItem,
    ResidentListResponse,
)
from ..security import generate_temp_code, hash_password

router = APIRouter(prefix="/residents", tags=["auth"])

_YONETIM = require_role("admin", "yonetici")


@router.post("", response_model=ResidentCreatedOut, status_code=201)
async def create_resident(
    body: ResidentCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> ResidentCreatedOut:
    # 1) unit: ayni no varsa mevcut kullanilir (ayni dairede coklu sakin),
    #    yoksa ortulu olusturulur.
    unit: Unit | None = (
        await db.execute(select(Unit).where(Unit.no == body.unit_no))
    ).scalar_one_or_none()
    if unit is None:
        unit = Unit(tenant_id=user.tenant_id, no=body.unit_no, blok=body.blok)
        db.add(unit)
        try:
            await db.flush()
        except IntegrityError as exc:
            raise translate_integrity(exc)

    # 2) sakin hesabi: parolasiz, tek seferlik gecici kod hash'i ile.
    temp_code = generate_temp_code()
    resident = AppUser(
        tenant_id=user.tenant_id,
        ad=body.ad,
        email=str(body.email) if body.email else None,
        telefon=body.telefon,
        role="resident",
        password_hash=None,
        temp_code_hash=hash_password(temp_code),
        password_set=False,
    )
    db.add(resident)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            # telefon global benzersiz; email tenant-ici benzersiz — hangisi
            # oldugu ayirt edilmeden tek mesaj (numara/e-posta cakismasi).
            raise APIError(409, "conflict", "Bu telefon veya e-posta zaten kayitli.")
        raise translate_integrity(exc)

    # 3) aktif daire-sakin baglantisi.
    db.add(
        UnitResident(
            tenant_id=user.tenant_id,
            unit_id=unit.id,
            user_id=resident.id,
            rol_tipi=body.rol_tipi,
        )
    )
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)

    return ResidentCreatedOut(
        user_id=resident.id,
        unit_id=unit.id,
        unit_no=unit.no,
        ad=resident.ad,
        email=resident.email,
        temp_code=temp_code,
    )


@router.get("", response_model=ResidentListResponse)
async def list_residents(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> ResidentListResponse:
    """Site sakinleri (yonetici/admin) — ad + aktif daire no + durum.

    Telefon KVKK geregi DONMEZ. unit_no aktif (bitis IS NULL) daire baglarindan
    turer; coklu daire virgulle birlesir, yoksa null. RLS ile tenant-kapsamli.
    """
    rows = (
        await db.execute(
            select(
                AppUser.id,
                AppUser.ad,
                AppUser.is_active,
                func.string_agg(Unit.no, ", ").label("unit_no"),
            )
            .outerjoin(
                UnitResident,
                and_(
                    UnitResident.user_id == AppUser.id,
                    UnitResident.bitis.is_(None),
                ),
            )
            .outerjoin(Unit, Unit.id == UnitResident.unit_id)
            .where(AppUser.role == "resident")
            .group_by(AppUser.id, AppUser.ad, AppUser.is_active)
            .order_by(AppUser.ad)
        )
    ).all()
    return ResidentListResponse(
        items=[
            ResidentListItem(
                user_id=r.id, ad=r.ad, unit_no=r.unit_no, is_active=r.is_active
            )
            for r in rows
        ]
    )


@router.delete("/{user_id}", status_code=204)
async def remove_resident_from_site(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> Response:
    """Sakini SITEDEN CIKAR (yonetici/admin): aktif daire baglarini bitirir
    (bitis=now) + hesabi pasiflestirir (is_active=false -> giris yapamaz).

    Idempotent (zaten pasif sakin tekrar cikarilinca yine 204). Tenant'ta
    role=resident degilse -> 404 (varlik sizmaz)."""
    resident = (
        await db.execute(
            select(AppUser).where(
                AppUser.id == user_id, AppUser.role == "resident"
            )
        )
    ).scalar_one_or_none()
    if resident is None:
        raise APIError(404, "not_found", "Sakin bulunamadi.")

    now = datetime.now(tz=timezone.utc)
    bindings = (
        await db.execute(
            select(UnitResident).where(
                UnitResident.user_id == user_id,
                UnitResident.bitis.is_(None),
            )
        )
    ).scalars().all()
    for binding in bindings:
        binding.bitis = now
    resident.is_active = False
    resident.updated_at = func.now()
    await db.flush()
    return Response(status_code=204)
