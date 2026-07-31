"""Caydirici yeniden-deneme kuyrugunun TENANT DOLASIMI (P37).

`gurultu_akisi.kuyrugu_isle` tek bir tenant baglaminda calisir; burasi tum
tenantlari dolasir. Ayrimin nedeni RLS bootstrap'idir: tenant LISTESI
app_rw ile okunamaz (baglam yokken hicbir satir gorunmez), bu yuzden
enumerasyon OWNER baglantisiyla yapilir ve asil is her tenant icin
`SET LOCAL app.current_tenant_id` altinda — bir tenant'in kuyrugu digerine
sizmaz.
"""
from __future__ import annotations

import uuid

import psycopg
from sqlalchemy import text

from .config import settings
from .db import SessionLocal
from .gurultu_akisi import kuyrugu_isle


def _tenant_idler() -> list[uuid.UUID]:
    with psycopg.connect(settings.owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [r[0] for r in conn.execute("SELECT id FROM tenant").fetchall()]


async def tum_tenantlar_icin() -> int:
    toplam = 0
    for tenant_id in _tenant_idler():
        async with SessionLocal() as db:
            await db.execute(
                text("SELECT set_config('app.current_tenant_id', :t, true)"),
                {"t": str(tenant_id)},
            )
            toplam += await kuyrugu_isle(db)
            await db.commit()
    return toplam
