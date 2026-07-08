"""GET /patrol-windows — tur penceresi gecmisi — /contracts/openapi.yaml.

/dashboard/live anlik bugunku durumu verir; bu uc GECMISE donuk sorgu icindir
("gecen hafta hangi turlar tamamlandi/kacirildi"). Mevcut patrol_window tablosu
uzerinde okuma — yeni tablo yok. okutulan/beklenen checkpoint sayilari dashboard
ile AYNI set-tabanli hesapla uretilir. RBAC: admin + security (dashboard ile
tutarli). tenant-izole (RLS). pencere_baslangic DESC sirali, sayfali.

Ozet sayilar (toplam/tamamlandi/kacirildi/bekliyor) FILTRELENMIS TUM kume
uzerinden response.ozet'te doner (sayfa ile sinirli degil) — panelin tum
sayfalari cekip saymasina gerek kalmasin.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..models import AppUser
from ..schemas import (
    PageMetaOut,
    PatrolWindowDurumLiteral,
    PatrolWindowListResponse,
    PatrolWindowOut,
    PatrolWindowOzet,
)

router = APIRouter(prefix="/patrol-windows", tags=["dashboard"])

_VIEWER = require_role("admin", "yonetici", "security")

# Pencere + beklenen (atanmis aktif checkpoint) ve okutulan (pencere araliginda
# okutulmus, beklenen) sayilari — dashboard/live ile ayni set-tabanli hesap.
# {where} runtime'da guvenli (sabit) kosul parcalarindan kurulur; degerler bound.
_LIST_SQL = """
    SELECT w.id, w.patrol_plan_id, p.ad AS plan_adi,
           w.pencere_baslangic, w.pencere_bitis, w.durum,
           count(DISTINCT c.id)            AS beklenen,
           count(DISTINCT s.checkpoint_id) AS okutulan
    FROM patrol_window w
    JOIN patrol_plan p ON p.id = w.patrol_plan_id
    LEFT JOIN patrol_plan_checkpoint ppc ON ppc.patrol_plan_id = w.patrol_plan_id
    LEFT JOIN checkpoint c ON c.id = ppc.checkpoint_id AND c.aktif = true
    LEFT JOIN scan_event s ON s.checkpoint_id = c.id
         AND s.okutma_zamani >= w.pencere_baslangic
         AND s.okutma_zamani <  w.pencere_bitis
    {where}
    GROUP BY w.id, w.patrol_plan_id, p.ad, w.pencere_baslangic, w.pencere_bitis, w.durum
    ORDER BY w.pencere_baslangic DESC
    LIMIT :limit OFFSET :offset
"""
_COUNT_SQL = "SELECT count(*) FROM patrol_window w {where}"
_OZET_SQL = "SELECT w.durum, count(*) AS n FROM patrol_window w {where} GROUP BY w.durum"


@router.get("", response_model=PatrolWindowListResponse)
async def list_patrol_windows(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    baslangic: datetime | None = Query(None, description="pencere_baslangic >= bu an"),
    bitis: datetime | None = Query(None, description="pencere_baslangic < bu an (yari-acik)"),
    durum: PatrolWindowDurumLiteral | None = Query(None),
    patrol_plan_id: uuid.UUID | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_VIEWER),
) -> PatrolWindowListResponse:
    conds: list[str] = []
    params: dict[str, object] = {}
    if baslangic is not None:
        conds.append("w.pencere_baslangic >= :baslangic")
        params["baslangic"] = baslangic
    if bitis is not None:
        conds.append("w.pencere_baslangic < :bitis")
        params["bitis"] = bitis
    if durum is not None:
        conds.append("w.durum = :durum")
        params["durum"] = durum
    if patrol_plan_id is not None:
        conds.append("w.patrol_plan_id = :plan_id")
        params["plan_id"] = patrol_plan_id
    where = ("WHERE " + " AND ".join(conds)) if conds else ""

    total = (
        await db.execute(text(_COUNT_SQL.format(where=where)), params)
    ).scalar_one()

    ozet_rows = (
        await db.execute(text(_OZET_SQL.format(where=where)), params)
    ).all()
    sayac = {r[0]: int(r[1]) for r in ozet_rows}
    ozet = PatrolWindowOzet(
        toplam=int(total),
        tamamlandi=sayac.get("tamamlandi", 0),
        kacirildi=sayac.get("kacirildi", 0),
        bekliyor=sayac.get("bekliyor", 0),
    )

    rows = (
        await db.execute(
            text(_LIST_SQL.format(where=where)),
            {**params, "limit": limit, "offset": offset},
        )
    ).mappings().all()
    items = [
        PatrolWindowOut(
            id=r["id"],
            patrol_plan_id=r["patrol_plan_id"],
            plan_adi=r["plan_adi"],
            pencere_baslangic=r["pencere_baslangic"],
            pencere_bitis=r["pencere_bitis"],
            durum=r["durum"],
            beklenen_checkpoint_sayisi=int(r["beklenen"]),
            okutulan_checkpoint_sayisi=int(r["okutulan"]),
        )
        for r in rows
    ]

    return PatrolWindowListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=int(total)),
        ozet=ozet,
        items=items,
    )
