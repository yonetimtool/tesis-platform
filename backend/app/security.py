"""Parola hash'leme + JWT uretimi/dogrulamasi.

/contracts/auth.md'ye uyar:
  * access claim'leri: sub (user_id), tenant_id, role, exp (+ iat, jti, type).
  * refresh claim'leri: sub, tenant_id, type=refresh, iat, exp, jti (+ fam: rotation
    ailesi — reuse tespiti/iptal icin).
  * access ~15 dk, refresh ~30 gun (config'ten).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import bcrypt
import jwt

from .config import settings


# --------------------------------------------------------------------------- #
# Parola
# --------------------------------------------------------------------------- #
def hash_password(plain: str) -> str:
    """bcrypt ile parola hash'le (app_user.password_hash icin)."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, password_hash: str) -> bool:
    """Parolayi hash ile karsilastir (sabit-zaman, bcrypt)."""
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), password_hash.encode("utf-8"))
    except (ValueError, TypeError):
        return False


# --------------------------------------------------------------------------- #
# JWT
# --------------------------------------------------------------------------- #
def _now() -> datetime:
    return datetime.now(tz=timezone.utc)


def _encode(claims: dict[str, Any]) -> str:
    return jwt.encode(claims, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(*, user_id: uuid.UUID | str, tenant_id: uuid.UUID | str, role: str) -> str:
    now = _now()
    claims = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "role": role,
        "type": "access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.access_token_expire_minutes)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return _encode(claims)


def create_refresh_token(
    *,
    user_id: uuid.UUID | str,
    tenant_id: uuid.UUID | str,
    family_id: str | None = None,
) -> tuple[str, str, str]:
    """Refresh token uret. Donus: (token, jti, family_id).

    family_id verilmezse yeni bir aile baslatilir (login). Rotation'da ayni
    family_id tekrar kullanilir; boylece reuse tespitinde tum aile iptal edilir.
    """
    now = _now()
    jti = str(uuid.uuid4())
    fam = family_id or str(uuid.uuid4())
    claims = {
        "sub": str(user_id),
        "tenant_id": str(tenant_id),
        "type": "refresh",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=settings.refresh_token_expire_days)).timestamp()),
        "jti": jti,
        "fam": fam,
    }
    return _encode(claims), jti, fam


def decode_token(token: str, *, expected_type: str) -> dict[str, Any]:
    """Token'i dogrula ve claim'leri don. Hatada jwt.PyJWTError firlatir.

    expected_type ('access'|'refresh') ile token tipi eslesmezse hata verir.
    """
    claims = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if claims.get("type") != expected_type:
        raise jwt.InvalidTokenError(f"beklenen token tipi '{expected_type}'")
    return claims


def access_token_ttl_seconds() -> int:
    return settings.access_token_expire_minutes * 60
