"""(P247 §1) VARDIYA DONGUSU — kayan ufuk beat isi (gunde bir).

Dongu atamasi SURESIZDIR; satirlar `bugun + DONGU_UFUK_GUN`e kadar
uretilir. Bu is her gece ufku bir gun ileri tasir. Gerekce ve kurallar
`routers/vardiya_plani.py` "(P247 §1) VARDIYA ROTASYONU" basliginda.

`otomasyon.tum_tenantlar_icin` ile AYNI desen: tesis listesi OWNER ile
(RLS bootstrap), IS her tesis icin app_rw + tenant baglami altinda; bir
tesisin hatasi digerlerini dusurmez.
"""
from __future__ import annotations

import datetime as dt
import logging

import psycopg
from sqlalchemy import text

from .config import settings
from .db import SessionLocal

log = logging.getLogger(__name__)


def _tenant_idler() -> list:
    with psycopg.connect(settings.owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [r[0] for r in conn.execute("SELECT id FROM tenant").fetchall()]


async def tum_tenantlar_icin(bugun: dt.date | None = None) -> dict:
    from .routers.vardiya_plani import dongu_ufkunu_doldur

    ozet = {"tesis": 0, "atama": 0, "eklenen": 0, "atlanan": 0}
    for tenant_id in _tenant_idler():
        try:
            async with SessionLocal() as db:
                await db.execute(
                    text("SELECT set_config('app.current_tenant_id', :t, true)"),
                    {"t": str(tenant_id)},
                )
                sonuc = await dongu_ufkunu_doldur(db, tenant_id, bugun)
                await db.commit()
            ozet["tesis"] += 1
            for k in ("atama", "eklenen", "atlanan"):
                ozet[k] += sonuc[k]
        except Exception as exc:  # noqa: BLE001
            log.warning("[vardiya-dongu] tesis %s atlandi: %s", tenant_id, exc)
    return ozet
