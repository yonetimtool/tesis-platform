"""(P251 §10) GET /platform/gonderim-gunlugu — e-posta, SMS, push; tum tesisler.

YALNIZ admin (platform). Tesis yoneticisi bu teknik gunlugu gormez: ham
saglayici hatalari (535, 5.7.8, gecersiz jeton) yoneticiye ait degildir;
onun ekraninda yalniz BAGLAM ICINDEKI sade durum kalir (or. odeme kodu
satirinda "iletildi / ulasmadi").

RLS FORCE: capraz-tesis okuma sahip yetkili `gonderim_gunlugu_list`
fonksiyonuyla (`audit_log_list` deseni). Bare oturum (set_tenant YOK).
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text

from .. import girdi_siniri as _G
from ..db import SessionLocal
from ..deps import require_role
from ..models import AppUser
from ..schemas import GonderimGunluguListesi, GonderimGunluguSatiri

router = APIRouter(prefix="/platform", tags=["platform"])

_ADMIN = require_role("admin")

_SORGU = text(
    "SELECT * FROM public.gonderim_gunlugu_list("
    ":kanal, :tid, :durum, :ara, :dfrom, :dto, :basarisiz, :lim, :off)"
)


@router.get("/gonderim-gunlugu", response_model=GonderimGunluguListesi)
async def gonderim_gunlugu(
    kanal: Literal["eposta", "sms", "push"] | None = Query(None),
    tenant_id: uuid.UUID | None = Query(None),
    durum: str | None = Query(None, max_length=_G.KOD),
    ara: str | None = Query(None, max_length=_G.ARAMA),
    date_from: datetime | None = Query(None, alias="from"),
    date_to: datetime | None = Query(None, alias="to"),
    basarisiz: bool = Query(False, description="Yalniz basarisiz gonderimler"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    _: AppUser = Depends(_ADMIN),
) -> GonderimGunluguListesi:
    async with SessionLocal() as session:
        async with session.begin():
            rows = (
                await session.execute(
                    _SORGU,
                    {
                        "kanal": kanal,
                        "tid": tenant_id,
                        "durum": durum,
                        "ara": (ara or "").strip() or None,
                        "dfrom": date_from,
                        "dto": date_to,
                        "basarisiz": basarisiz,
                        "lim": limit,
                        "off": offset,
                    },
                )
            ).mappings().all()
    total = int(rows[0]["total"]) if rows else 0
    return GonderimGunluguListesi(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            GonderimGunluguSatiri(**{k: r[k] for k in GonderimGunluguSatiri.model_fields})
            for r in rows
        ],
    )
