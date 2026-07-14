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

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitResident
from ..schemas import ResidentCreate, ResidentCreatedOut
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
