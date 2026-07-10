"""POST /auth/login + POST /auth/refresh — /contracts/auth.md + openapi.yaml.

Refresh rotation/iptal durumu Redis'te tutulur (sema'da refresh tablosu yok;
auth.md §3 server-side iptal listesini onerir):
  refresh:valid:<jti> = <fam>   (TTL = refresh suresi)  -> jti gecerli mi
  refresh:fam:<fam>   = <jti>    (TTL = refresh suresi)  -> ailenin guncel jti'si
Rotation: eski jti silinir, yeni jti uretilir. Reuse (gecersiz/eski jti) gelince
tum aile iptal edilir.
"""
from __future__ import annotations

import jwt
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..db import SessionLocal, set_tenant
from ..deps import get_redis
from ..errors import APIError
from ..models import AppUser, Unit, UnitResident
from ..schemas import (
    LoginRequest,
    RefreshRequest,
    ResidentLoginRequest,
    ResidentLoginResponse,
    SetPasswordRequest,
    TokenPair,
)
from ..security import (
    access_token_ttl_seconds,
    create_access_token,
    create_refresh_token,
    create_setup_token,
    decode_token,
    hash_password,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])

_INVALID_CREDS = APIError(401, "invalid_credentials", "Email, parola veya tenant hatali.")
# Sakin girisinde de hangi adimin patladigi sizdirilmaz (daire var mi, kod mu
# parola mi yanlis vb. ayirt ettirilmez) — personel akisiyla ayni ilke.
_INVALID_RESIDENT_CREDS = APIError(
    401, "invalid_credentials", "Daire no, kod/parola veya tesis hatali."
)


def _refresh_ttl() -> int:
    return settings.refresh_token_expire_days * 24 * 3600


async def _store_refresh(redis: aioredis.Redis, jti: str, fam: str) -> None:
    ttl = _refresh_ttl()
    await redis.set(f"refresh:valid:{jti}", fam, ex=ttl)
    await redis.set(f"refresh:fam:{fam}", jti, ex=ttl)


async def _revoke_family(redis: aioredis.Redis, fam: str, jti: str | None = None) -> None:
    await redis.delete(f"refresh:fam:{fam}")
    if jti:
        await redis.delete(f"refresh:valid:{jti}")


@router.post("/login", response_model=TokenPair)
async def login(
    body: LoginRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    async with SessionLocal() as session:
        async with session.begin():
            # 1) slug -> tenant_id (RLS bootstrap: SECURITY DEFINER fonksiyon).
            tenant_id = (
                await session.execute(
                    text("SELECT public.tenant_id_by_slug(:slug)"),
                    {"slug": body.tenant_slug},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise _INVALID_CREDS

            # 2) tenant baglami + kullaniciyi RLS altinda yukle.
            await set_tenant(session, tenant_id)
            # email tenant-ici benzersiz (lower(email)); case-insensitive tam eslesme.
            user: AppUser | None = (
                await session.execute(
                    select(AppUser).where(
                        func.lower(AppUser.email) == body.email.lower()
                    )
                )
            ).scalar_one_or_none()

            # 3) dogrulama — basarisiz adimlari ayirt ettirmeden 401.
            if user is None or not verify_password(body.password, user.password_hash):
                raise _INVALID_CREDS
            if not user.is_active:
                raise _INVALID_CREDS

            access = create_access_token(
                user_id=user.id, tenant_id=user.tenant_id, role=user.role
            )
            refresh, jti, fam = create_refresh_token(
                user_id=user.id, tenant_id=user.tenant_id
            )

    await _store_refresh(redis, jti, fam)
    return TokenPair(
        access_token=access,
        refresh_token=refresh,
        token_type="Bearer",
        expires_in=access_token_ttl_seconds(),
    )


async def _issue_token_pair(redis: aioredis.Redis, user: AppUser) -> TokenPair:
    """Dogrulanmis kullanici icin access+refresh cifti uret ve refresh'i kaydet."""
    access = create_access_token(
        user_id=user.id, tenant_id=user.tenant_id, role=user.role
    )
    refresh_token, jti, fam = create_refresh_token(
        user_id=user.id, tenant_id=user.tenant_id
    )
    await _store_refresh(redis, jti, fam)
    return TokenPair(
        access_token=access,
        refresh_token=refresh_token,
        token_type="Bearer",
        expires_in=access_token_ttl_seconds(),
    )


async def _resolve_tenant_id(session: AsyncSession, slug: str):
    """slug -> tenant_id (RLS bootstrap: SECURITY DEFINER fonksiyon)."""
    return (
        await session.execute(
            text("SELECT public.tenant_id_by_slug(:slug)"), {"slug": slug}
        )
    ).scalar_one_or_none()


@router.post("/login-resident", response_model=ResidentLoginResponse)
async def login_resident(
    body: ResidentLoginRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> ResidentLoginResponse:
    """Sakin girisi: tenant_slug + unit_no + (gecici kod VEYA kalici parola).

    Ayni dairede birden fazla sakin olabilir; hesap, girilen parolanin/kodun
    HANGI sakinin hash'iyle eslestigine gore cozulur (her sakinin kendi
    parolasi + kendi tek seferlik kodu vardir — /contracts/auth.md §1.2).

    * Kalici parola eslesirse -> normal oturum (token cifti).
    * Gecici kod eslesirse (password_set=false) -> oturum YOK; kisa omurlu
      `setup_token` doner, sakin /auth/set-password ile parolasini belirlemek
      ZORUNDADIR (kod tek kullanimlik: parola belirlenince silinir).
    """
    async with SessionLocal() as session:
        async with session.begin():
            tenant_id = await _resolve_tenant_id(session, body.tenant_slug)
            if tenant_id is None:
                raise _INVALID_RESIDENT_CREDS

            await set_tenant(session, tenant_id)
            # Dairenin AKTIF sakinleri (bitis IS NULL) RLS altinda yuklenir.
            candidates = (
                await session.execute(
                    select(AppUser)
                    .join(UnitResident, UnitResident.user_id == AppUser.id)
                    .join(Unit, Unit.id == UnitResident.unit_id)
                    .where(
                        Unit.no == body.unit_no,
                        UnitResident.bitis.is_(None),
                        AppUser.role == "resident",
                        AppUser.is_active.is_(True),
                    )
                )
            ).scalars().unique().all()

            # Once kalici parolalar (normal giris), sonra gecici kodlar (ilk
            # giris). Yanlis girdide hangi asamanin patladigi sizdirilmaz.
            for candidate in candidates:
                if candidate.password_set and verify_password(
                    body.password, candidate.password_hash
                ):
                    user = candidate
                    break
            else:
                for candidate in candidates:
                    if not candidate.password_set and verify_password(
                        body.password, candidate.temp_code_hash
                    ):
                        # Gecici kod dogru -> parola kurulumu zorunlu; oturum
                        # token'i VERILMEZ (kod API erisimi saglamaz).
                        return ResidentLoginResponse(
                            password_setup_required=True,
                            setup_token=create_setup_token(
                                user_id=candidate.id, tenant_id=candidate.tenant_id
                            ),
                        )
                raise _INVALID_RESIDENT_CREDS

    tokens = await _issue_token_pair(redis, user)
    return ResidentLoginResponse(
        password_setup_required=False, **tokens.model_dump()
    )


@router.post("/set-password", response_model=TokenPair)
async def set_password(
    body: SetPasswordRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    """Ilk giristeki zorunlu parola belirleme (setup_token ile).

    Basarida: parola kaydedilir (bcrypt), gecici kod SILINIR (tek kullanimlik),
    password_set=true olur ve tam oturum (token cifti) doner.
    """
    try:
        claims = decode_token(body.setup_token, expected_type="pwd_setup")
    except jwt.PyJWTError:
        raise APIError(401, "invalid_token", "Gecersiz veya suresi dolmus kurulum token'i.")

    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, claims["tenant_id"])
            user: AppUser | None = (
                await session.execute(
                    select(AppUser).where(AppUser.id == claims.get("sub"))
                )
            ).scalar_one_or_none()
            # Token gecerli olsa da durum degismis olabilir (pasif, parola
            # zaten belirlenmis => token tek kullanimliktir).
            if (
                user is None
                or not user.is_active
                or user.password_set
                or user.temp_code_hash is None
            ):
                raise APIError(401, "invalid_token", "Kurulum token'i artik gecerli degil.")

            user.password_hash = hash_password(body.new_password)
            user.password_set = True
            user.temp_code_hash = None
            user.updated_at = func.now()

    return await _issue_token_pair(redis, user)


@router.post("/refresh", response_model=TokenPair)
async def refresh(
    body: RefreshRequest,
    redis: aioredis.Redis = Depends(get_redis),
) -> TokenPair:
    # 1) imza + tip + son kullanma.
    try:
        claims = decode_token(body.refresh_token, expected_type="refresh")
    except jwt.PyJWTError:
        raise APIError(401, "invalid_token", "Gecersiz veya suresi dolmus refresh token.")

    jti = claims.get("jti", "")
    fam = claims.get("fam", "")
    sub = claims.get("sub")
    tenant_id = claims.get("tenant_id")

    # 2) rotation/reuse kontrolu.
    current = await redis.get(f"refresh:fam:{fam}")
    valid_fam = await redis.get(f"refresh:valid:{jti}")
    if valid_fam is None or current != jti:
        # gecersiz/zaten donmus/eski jti => reuse suphesi: tum aileyi iptal et.
        await _revoke_family(redis, fam, jti)
        raise APIError(401, "invalid_token", "Refresh token gecersiz veya iptal edilmis.")

    # 3) kullaniciyi RLS altinda yeniden yukle (rol degismis olabilir).
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, tenant_id)
            user: AppUser | None = (
                await session.execute(select(AppUser).where(AppUser.id == sub))
            ).scalar_one_or_none()
            if user is None or not user.is_active:
                await _revoke_family(redis, fam, jti)
                raise APIError(401, "invalid_token", "Kullanici bulunamadi veya pasif.")

            access = create_access_token(
                user_id=user.id, tenant_id=user.tenant_id, role=user.role
            )
            new_refresh, new_jti, _ = create_refresh_token(
                user_id=user.id, tenant_id=user.tenant_id, family_id=fam
            )

    # 4) rotation: eski jti'yi sil, yeni jti'yi aile guncel'i yap.
    await redis.delete(f"refresh:valid:{jti}")
    await _store_refresh(redis, new_jti, fam)

    return TokenPair(
        access_token=access,
        refresh_token=new_refresh,
        token_type="Bearer",
        expires_in=access_token_ttl_seconds(),
    )
