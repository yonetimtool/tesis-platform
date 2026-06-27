"""Async SQLAlchemy engine + session + tenant baglami.

Tenant izolasyonu DB seviyesinde RLS ile zorlanir (bkz. /contracts/db/README.md).
Her istek/is, transaction kapsaminda `app.current_tenant_id` oturum degiskenini
set eder. `set_config(..., is_local=true)` => `SET LOCAL` ile esdegerdir; deger
sadece icinde bulunulan transaction boyunca gecerlidir, dolayisiyla connection
pool'da baska tenant'a SIZMAZ.

Guvenli varsayilan: degisken set EDILMEZSE `current_setting('app.current_tenant_id', true)`
NULL doner => RLS politikalari hicbir satir dondurmez.
"""
from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from .config import settings

engine = create_async_engine(
    settings.database_url,
    echo=settings.sql_echo,
    pool_pre_ping=True,
)

SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)

_SET_TENANT_SQL = text("SELECT set_config('app.current_tenant_id', :tenant_id, true)")


async def set_tenant(session: AsyncSession, tenant_id: UUID | str) -> None:
    """Oturum degiskenini transaction-yerel olarak ayarla (SET LOCAL esdegeri).

    UUID degeri parametre olarak gecirilir (SQL injection'a kapali).
    Mutlaka aktif bir transaction icinde cagrilmali (aksi halde deger anlik
    olarak gecersiz olur).
    """
    await session.execute(_SET_TENANT_SQL, {"tenant_id": str(tenant_id)})


async def get_session() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency — tenant baglami OLMADAN transaction'li session.

    Tenant gerektirmeyen islemler icin (orn. /health, auth). Tenant-kapsamli
    tablolara erisirse RLS hicbir satir dondurmez (guvenli varsayilan).
    """
    async with SessionLocal() as session:
        async with session.begin():
            yield session


def get_tenant_session_dep(tenant_id: UUID | str):
    """Tenant-kapsamli FastAPI dependency uretici.

    Prompt 2'de tenant_id token'dan cikarilacak; simdilik parametreyle verilebilir.
    Kullanim (ornek):
        async def endpoint(session = Depends(get_tenant_session_dep(tid))): ...
    """

    async def _dep() -> AsyncIterator[AsyncSession]:
        async with SessionLocal() as session:
            async with session.begin():
                await set_tenant(session, tenant_id)
                yield session

    return _dep


@asynccontextmanager
async def tenant_session(tenant_id: UUID | str) -> AsyncIterator[AsyncSession]:
    """Worker/servis kodu icin tenant-kapsamli session context manager."""
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, tenant_id)
            yield session
