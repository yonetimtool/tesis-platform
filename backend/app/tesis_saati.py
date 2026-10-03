"""(P253 §E) TESISIN "BUGUN"U — saat dilimi tesisten okunur.

NEDEN: uygulama saati UTC. Istanbul (UTC+3) gece 00:00–03:00 arasinda
UTC hala DUNKU tarihtir. "Simdi calistir" ile elle tetiklenen maas,
gecikme faizi ya da tahakkuk onizlemesi o saatlerde bir onceki gunu —
ayin 1'i gecesi bir onceki AYI — gorurdu (P252 dogrulamasinda olculdu).

KURAL: istek yolundaki ve elle tetiklenen her "bugun" hesabi
`tesis_bugun(db)` uzerinden gelir; saf islevler `bugun` parametresi
alir ve kendi `date.today()`ini UYDURMAZ. Kilit:
`tests/test_p253_saat_dilimi.py` routers altinda UTC-bugun kullanimini
tarar.

Tesis satiri RLS ile oturumun tesisine daraltilmistir: `select(Tenant
.timezone)` yalniz kendi satirini dondurur (`dues.py` ayni deseni
kullanir). Saat dilimi gecersizse varsayilan Europe/Istanbul — gecersiz
bir dize yuzunden finans islemi dusurmek, yanlis bir gun kadar kotudur.
"""
from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

VARSAYILAN_SAAT_DILIMI = "Europe/Istanbul"


def bolge(ad: str | None) -> ZoneInfo:
    try:
        return ZoneInfo(ad or VARSAYILAN_SAAT_DILIMI)
    except (ZoneInfoNotFoundError, ValueError):
        return ZoneInfo(VARSAYILAN_SAAT_DILIMI)


def yerel_bugun(saat_dilimi: str | None, simdi: datetime | None = None) -> date:
    """`simdi` (UTC ya da saat dilimli) anindaki tesis takvim gunu."""
    an = simdi or datetime.now(timezone.utc)
    if an.tzinfo is None:
        an = an.replace(tzinfo=timezone.utc)
    return an.astimezone(bolge(saat_dilimi)).date()


async def tesis_saat_dilimi(db: AsyncSession, tenant_id: uuid.UUID | None = None) -> str:
    from .models import Tenant

    q = select(Tenant.timezone)
    if tenant_id is not None:
        q = q.where(Tenant.id == tenant_id)
    ad = (await db.execute(q.limit(1))).scalar_one_or_none()
    return ad or VARSAYILAN_SAAT_DILIMI


async def tesis_bugun(db: AsyncSession, tenant_id: uuid.UUID | None = None) -> date:
    """Oturumun (ya da verilen) tesisinin bugunku takvim gunu."""
    return yerel_bugun(await tesis_saat_dilimi(db, tenant_id))


def yerel_gun_basi(saat_dilimi: str | None, simdi: datetime | None = None) -> datetime:
    """Tesisin bugununun 00:00'i, UTC olarak (sorgu siniri icin)."""
    from datetime import time

    gun = yerel_bugun(saat_dilimi, simdi)
    return datetime.combine(gun, time.min, tzinfo=bolge(saat_dilimi)).astimezone(timezone.utc)


async def tesis_gun_basi(db: AsyncSession, tenant_id: uuid.UUID | None = None) -> datetime:
    return yerel_gun_basi(await tesis_saat_dilimi(db, tenant_id))
