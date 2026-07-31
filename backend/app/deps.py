"""Auth + tenant-context FastAPI dependency'leri.

Akis (her korumali istek):
  1. Authorization: Bearer <access> -> dogrula (get_access_claims).
  2. Token'daki tenant_id ile DB oturumunda app.current_tenant_id SET LOCAL
     (get_tenant_db) -> bundan sonrasi RLS altinda.
  3. Kullaniciyi RLS altinda yukle (get_current_user).
  4. require_role(...) ile RBAC.

FastAPI ayni istek icinde dependency sonuclarini cache'ler; bu yuzden
get_current_user ve endpoint ayni get_tenant_db oturumunu paylasir.
"""
from __future__ import annotations

from collections.abc import AsyncIterator
from typing import Any

import jwt
import redis.asyncio as aioredis
from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .db import SessionLocal, set_tenant
from .errors import APIError
from .models import AppUser, Tenant

_bearer = HTTPBearer(auto_error=False)


def get_redis(request: Request) -> aioredis.Redis:
    return request.app.state.redis


def get_access_claims(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict[str, Any]:
    if creds is None or not creds.credentials:
        raise APIError(401, "unauthorized", "kimlik_dogrulama_gerekli")
    from .security import decode_token  # gec import (dairesel bagimlilik yok)

    try:
        return decode_token(creds.credentials, expected_type="access")
    except jwt.ExpiredSignatureError:
        raise APIError(401, "token_expired", "access_token_suresi_dolmus")
    except jwt.PyJWTError:
        raise APIError(401, "invalid_token", "access_token_gecersiz")


async def get_tenant_db(
    claims: dict[str, Any] = Depends(get_access_claims),
) -> AsyncIterator[AsyncSession]:
    """Token'daki tenant_id ile baglam kurulmus, transaction'li session."""
    tenant_id = claims.get("tenant_id")
    if not tenant_id:
        raise APIError(401, "invalid_token", "token_tenant_icermiyor")
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, tenant_id)
            yield session


async def get_current_user(
    claims: dict[str, Any] = Depends(get_access_claims),
    db: AsyncSession = Depends(get_tenant_db),
) -> AppUser:
    user_id = claims.get("sub")
    # RLS aktif: yalnizca token'daki tenant'a ait satir gorunur.
    user = (
        await db.execute(select(AppUser).where(AppUser.id == user_id))
    ).scalar_one_or_none()
    if user is None or not user.is_active:
        raise APIError(401, "invalid_token", "kullanici_bulunamadi_veya_pasif")
    return user


def require_role(*roles: str):
    """RBAC dependency uretici — /contracts/auth.md §4 matrisine gore."""
    allowed = set(roles)

    async def _dep(user: AppUser = Depends(get_current_user)) -> AppUser:
        if user.role not in allowed:
            raise APIError(403, "forbidden", "yetkiniz_yok")
        return user

    return _dep


# --------------------------- guvenlik sahipligi (P35) ----------------------- #
#: Guvenligi KIMIN yonettigi TENANT MODUNA baglidir; bir rol listesine
#: gomulemez cunku mod calisma aninda degisir.
#:
#:   yonetim_ici (VARSAYILAN) — bugunku davranis: YONETICI planlar,
#:   dis_sirket               — AMIR planlar, yonetici SALT-OKUR izler.
#:
#: admin HER IKI MODDA yazabilir: platform operatoru bir tesisi kilitli
#: birakamamali (mod yanlis ayarlandiginda kimse duzeltemezdi).
GUVENLIK_YAZAN = {
    "yonetim_ici": ("admin", "yonetici"),
    "dis_sirket": ("admin", "guvenlik_amiri"),
}


async def guvenlik_modu(db: AsyncSession) -> str:
    """Gecerli tenant'in guvenlik modu (RLS altinda tek satir)."""
    mod = (await db.execute(select(Tenant.guvenlik_modu))).scalar_one_or_none()
    return mod or "yonetim_ici"


def require_guvenlik_yazma():
    """(P35) Vardiya/tur PLANLAMA yetkisi — moda gore SAHIPLIK DEGISIR.

    Salt-okuma bundan AYRIDIR: `dis_sirket` modunda yonetici turleri ve
    vardiyalari GORMEYE devam eder; goremeseydi kendi sitesinin guvenlik
    hizmetini denetleyemezdi — dis sirkete devretmek denetimi devretmek
    DEGILDIR.
    """

    async def _dep(
        db: AsyncSession = Depends(get_tenant_db),
        user: AppUser = Depends(get_current_user),
    ) -> AppUser:
        mod = await guvenlik_modu(db)
        if user.role not in GUVENLIK_YAZAN[mod]:
            # Mesaj MODU soyler: "yetkiniz yok" demek, yoneticiye ayarin
            # degistigini hic anlatmazdi.
            raise APIError(
                403, "forbidden",
                "guvenlik_dis_sirkette" if mod == "dis_sirket"
                else "guvenlik_yonetimde",
            )
        return user

    return _dep
