"""Korumali ornek endpoint'ler — auth + tenant context + RBAC uctan uca dogrulama.

NOT: /me/checkpoints ve /admin/overview Faz-0 dogrulama amacli iskelet
endpoint'lerdir (openapi sozlesmesinde degiller). Gercek Checkpoint CRUD ve
panel uclari Prompt 3+'te sozlesmeye gore eklenecek.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..deps import get_current_user, get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Checkpoint
from ..schemas import (
    AvatarUpdate,
    CheckpointBrief,
    MeProfileOut,
    PasswordChangeRequest,
    UserContactUpdate,
    UserOut,
)
from ..security import hash_password, verify_password
from ..storage import delete_objects, presign_get

router = APIRouter(tags=["me"])

# Profil fotografi YALNIZ personel rolleri (resident'a 403 — sakinler
# personeli tanisin diye tek yonlu).
_AVATAR_ROLLER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")


def _user_out(user: AppUser) -> UserOut:
    """AppUser -> UserOut; avatar_key varsa presigned GET URL doldurur."""
    return UserOut(
        id=user.id, tenant_id=user.tenant_id, ad=user.ad, email=user.email,
        role=user.role, is_active=user.is_active,
        avatar_url=presign_get(user.avatar_key) if user.avatar_key else None,
    )


@router.get("/me", response_model=UserOut)
async def me(user: AppUser = Depends(get_current_user)) -> UserOut:
    """Access token'daki kullaniciyi doner (tenant context token'dan)."""
    return _user_out(user)


@router.patch("/me/avatar", response_model=UserOut)
async def update_my_avatar(
    body: AvatarUpdate,
    user: AppUser = Depends(_AVATAR_ROLLER),
    db: AsyncSession = Depends(get_tenant_db),
) -> UserOut:
    """Self-servis profil fotografi — YALNIZ personel rolleri (resident 403).

    Anahtar kendi tenant namespace'inde olmali (announcement _validate_foto_key
    deseni — IDOR engeli). Degisen/kaldirilan eski obje MinIO'dan silinir
    (artik erisilemez cop)."""
    if body.avatar_key is not None and not body.avatar_key.startswith(
        f"{user.tenant_id}/"
    ):
        raise APIError(422, "invalid_foto_key", "avatar_key tenant alani disinda")
    eski = user.avatar_key
    user.avatar_key = body.avatar_key
    user.updated_at = func.now()
    if eski and eski != body.avatar_key:
        delete_objects([eski])
    await audit_user(
        db, user, Action.AVATAR_UPDATE, resource_type="app_user",
        resource_id=user.id, meta={"kaldirildi": body.avatar_key is None},
    )
    return _user_out(user)


@router.get("/me/profile", response_model=MeProfileOut)
async def my_profile(user: AppUser = Depends(get_current_user)) -> AppUser:
    """Self-servis profil: kullanicinin KENDI kimlik + iletisim alanlari.

    Tum roller kendi kaydini gorur (auth.md self-servis profil).
    """
    return user


@router.patch("/me/password", status_code=204)
async def change_my_password(
    body: PasswordChangeRequest,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> Response:
    """Self-servis parola degisimi — mevcut parola dogrulanir (auth.md).

    Mevcut parola hatali → 400 invalid_credentials (hangi alanin patladigi net;
    login'deki gizlilik ilkesi burada gerekmez — kullanici zaten kimlikli).
    Basarida yeni bcrypt hash yazilir; oturum (refresh) devam eder.
    """
    if not verify_password(body.current_password, user.password_hash):
        raise APIError(400, "invalid_credentials", "Mevcut parola hatali.")
    user.password_hash = hash_password(body.new_password)
    user.password_set = True
    user.updated_at = func.now()
    await audit_user(
        db, user, Action.PASSWORD_CHANGE, resource_type="app_user",
        resource_id=user.id,
    )
    # get_tenant_db transaction'i cikista commit eder (user ayni oturuma bagli).
    return Response(status_code=204)


@router.patch("/me/contact", response_model=MeProfileOut)
async def update_my_contact(
    body: UserContactUpdate,
    user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> AppUser:
    """Self-servis iletisim: kullanici KENDI telefon + aranabilir rizasini yonetir.

    Yonetim ucu (PATCH /users/{id}/contact, admin/yonetici -> baskasi) ayri kalir;
    bu onun kendi-kaydi karsiligidir. Numara OTP'siz dogrudan kaydedilir.
    """
    data = body.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(user, key, value)
    user.updated_at = func.now()
    await audit_user(
        db, user, Action.USER_CONTACT_UPDATE, resource_type="app_user",
        resource_id=user.id, meta={"self": True, "fields": list(data.keys())},
    )
    return user


@router.get("/me/checkpoints", response_model=list[CheckpointBrief])
async def my_checkpoints(
    _user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> list[Checkpoint]:
    """Token'daki tenant'in checkpoint'lerini doner (RLS ile izole).

    Tenant izolasyonunu token uzerinden uctan uca dogrulamak icin (Faz-0).
    """
    rows = (await db.execute(select(Checkpoint).order_by(Checkpoint.ad))).scalars().all()
    return list(rows)


@router.get("/admin/overview", tags=["admin"])
async def admin_overview(
    user: AppUser = Depends(require_role("admin")),
) -> dict:
    """Sadece admin — RBAC demo (matristen ornek: yonetim ucu)."""
    return {"status": "ok", "role": user.role}
