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
from sqlalchemy import and_, delete as sa_delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitResident, UserDevice

# KVKK anonimlestirme yer tutucusu (ad NOT NULL — NULL yerine sabit metin).
ANONYMIZED_NAME = "Silinmiş Kullanıcı"
from ..schemas import (
    ResidentCreate,
    ResidentCreatedOut,
    ResidentDeleteOut,
    ResidentListItem,
    ResidentListResponse,
    ResidentResetPasswordOut,
    ResidentUpdate,
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

    # 2) sakin hesabi. Parola VERILDIYSE dogrudan belirlenir (gecici kod YOK);
    #    verilmediyse tek seferlik gecici kod uretilir.
    if body.password is not None:
        temp_code = None
        password_hash = hash_password(body.password)
        password_set = True
        temp_code_hash = None
    else:
        temp_code = generate_temp_code()
        password_hash = None
        password_set = False
        temp_code_hash = hash_password(temp_code)
    resident = AppUser(
        tenant_id=user.tenant_id,
        ad=body.ad,
        email=str(body.email) if body.email else None,
        telefon=body.telefon,
        role="resident",
        password_hash=password_hash,
        temp_code_hash=temp_code_hash,
        password_set=password_set,
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

    await audit_user(
        db, user, Action.RESIDENT_CREATE, resource_type="app_user",
        resource_id=resident.id, meta={"unit_id": str(unit.id)},
    )
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


async def _resident_or_404(db: AsyncSession, user_id: uuid.UUID) -> AppUser:
    resident = (
        await db.execute(
            select(AppUser).where(
                AppUser.id == user_id, AppUser.role == "resident"
            )
        )
    ).scalar_one_or_none()
    if resident is None:
        raise APIError(404, "not_found", "Sakin bulunamadi.")
    return resident


@router.patch("/{user_id}", status_code=204)
async def update_resident(
    user_id: uuid.UUID,
    body: ResidentUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> Response:
    """Sakini duzenle (yonetici/admin): ad ve/veya cep telefonu. telefon global
    benzersiz (cakisma 409). Numarayi bos birakmak = degismez."""
    resident = await _resident_or_404(db, user_id)
    fields = list(body.model_dump(exclude_unset=True).keys())
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(resident, key, value)
    resident.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Bu telefon zaten kayitli.")
        raise translate_integrity(exc)
    # meta: yalniz DEGISEN ALAN ADLARI (deger YOK — KVKK).
    await audit_user(
        db, user, Action.RESIDENT_UPDATE, resource_type="app_user",
        resource_id=user_id, meta={"fields": fields},
    )
    return Response(status_code=204)


@router.post("/{user_id}/reset-password", response_model=ResidentResetPasswordOut)
async def reset_resident_password(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> ResidentResetPasswordOut:
    """Sakin parolasini sifirla (yonetici/admin): yeni TEK SEFERLIK gecici kod
    uretir. Sakin telefon + bu kodla girip yeni parolasini belirler (§1.3).
    Kod YALNIZ bu yanitta duz metin doner."""
    resident = await _resident_or_404(db, user_id)
    temp_code = generate_temp_code()
    resident.password_hash = None
    resident.password_set = False
    resident.temp_code_hash = hash_password(temp_code)
    resident.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.RESIDENT_RESET_PASSWORD, resource_type="app_user",
        resource_id=user_id,
    )
    return ResidentResetPasswordOut(temp_code=temp_code)


@router.delete("/{user_id}", response_model=ResidentDeleteOut)
async def remove_resident_from_site(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> ResidentDeleteOut:
    """Sakini SIL / ANONIMLESTIR (KVKK silme hakki; yonetici/admin).

    Gecmissiz sakin (yeni/hatali kayit) TAMAMEN silinir (unit_resident/rsvp/
    device CASCADE ile gider) -> deleted=true (audit: resident_delete). Gecmisi
    olan sakin (FK RESTRICT: aidat/sikayet/rezervasyon vb.) silinemez; SAVEPOINT
    geri alinir ve ANONIMLESTIRILIR -> deleted=false (audit: resident_erasure):
      * ad -> 'Silinmiş Kullanıcı', email/telefon -> NULL, parola/gecici-kod
        hash'leri temizlenir (kimlik dogrulama gecersizlesir),
      * FCM/cihaz token'lari (user_device) SILINIR (push kesilir),
      * aktif daire-sakin baglantilari kapatilir, is_active=false.
    FINANSAL/denetim satirlari (dues_payment kaydeden, complaint acan vb.) DEFTER
    butunlugu icin KALIR — yazari anonim kullaniciya isaret eder. Yuklenen
    sikayet fotograflari KALIR (kisiyi degil, tesis sorununu belgeler). role=
    resident degilse 404."""
    resident = await _resident_or_404(db, user_id)

    try:
        async with db.begin_nested():
            await db.execute(sa_delete(AppUser).where(AppUser.id == user_id))
        await audit_user(
            db, user, Action.RESIDENT_DELETE, resource_type="app_user",
            resource_id=user_id, meta={"mode": "hard_delete"},
        )
        return ResidentDeleteOut(deleted=True)
    except IntegrityError:
        # Gecmis kayitlari var (RESTRICT) -> savepoint geri alindi; ANONIMLESTIR.
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
        # Cihaz/push token'larini sil (kisisel + artik gecersiz).
        await db.execute(sa_delete(UserDevice).where(UserDevice.user_id == user_id))
        # Kimlik alanlarini anonimlestir.
        resident.ad = ANONYMIZED_NAME
        resident.email = None
        resident.telefon = None
        resident.password_hash = None
        resident.temp_code_hash = None
        resident.password_set = False
        resident.aranabilir = False
        resident.is_active = False
        resident.updated_at = func.now()
        await db.flush()
        await audit_user(
            db, user, Action.RESIDENT_ERASURE, resource_type="app_user",
            resource_id=user_id, meta={"mode": "anonymize"},
        )
        return ResidentDeleteOut(deleted=False)
