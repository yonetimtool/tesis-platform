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
from .models import AppUser

_bearer = HTTPBearer(auto_error=False)


def get_redis(request: Request) -> aioredis.Redis:
    return request.app.state.redis


def get_access_claims(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict[str, Any]:
    if creds is None or not creds.credentials:
        raise APIError(401, "unauthorized", "Kimlik dogrulama gerekli.")
    from .security import decode_token  # gec import (dairesel bagimlilik yok)

    try:
        return decode_token(creds.credentials, expected_type="access")
    except jwt.ExpiredSignatureError:
        raise APIError(401, "token_expired", "Access token suresi dolmus.")
    except jwt.PyJWTError:
        raise APIError(401, "invalid_token", "Gecersiz access token.")


async def get_tenant_db(
    claims: dict[str, Any] = Depends(get_access_claims),
) -> AsyncIterator[AsyncSession]:
    """Token'daki tenant_id ile baglam kurulmus, transaction'li session."""
    tenant_id = claims.get("tenant_id")
    if not tenant_id:
        raise APIError(401, "invalid_token", "Token tenant_id icermiyor.")
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
        raise APIError(401, "invalid_token", "Kullanici bulunamadi veya pasif.")
    return user


def require_role(*roles: str):
    """RBAC dependency uretici — /contracts/auth.md §4 matrisine gore."""
    allowed = set(roles)

    async def _dep(user: AppUser = Depends(get_current_user)) -> AppUser:
        if user.role not in allowed:
            raise APIError(
                403, "forbidden", "Bu islem icin yetkiniz yok."
            )
        return user

    return _dep
