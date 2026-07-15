"""GET /me/patrol-window — aktif pencere + checkpoint bazinda okutma durumu — /contracts/openapi.yaml.

Mobil bulgusu: cihaz yerel kaydi yerine "aktif turumda hangi noktalar okutuldu"
sunucudan sorulabilmeli. Aktif pencere = SU AN icinde olunan pencere
(pencere_baslangic <= now < pencere_bitis). Birden cok plan ayni anda aktif
olabileceginden TUM aktif pencereler `windows[]` icinde doner; `window` +
`checkpoints` (mobilin onerdigi sade sekil) bunlardan bitisi en yakin olanidir.
Aktif pencere yoksa window=null + bos listeler (200, hata degil).

okutuldu PENCERE-GENELIDIR (herhangi bir elemanin okutmasi sayilir) ve scan
eslesmesi scheduler'in 'tamamlandi' hesabiyla AYNIDIR: checkpoint eslesir +
okutma_zamani pencere araliginda [baslangic, bitis). okutma_zamani/okutan_user_id
o checkpoint'in penceredeki ILK scan'inden gelir. RBAC (auth.md §4): admin +
security (dashboard ile tutarli). tenant token'dan; RLS ile izole.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..models import AppUser, Tenant
from ..schemas import (
    MePatrolCheckpointOut,
    MePatrolWindowInfo,
    MePatrolWindowItem,
    MePatrolWindowResponse,
)

router = APIRouter(tags=["me"])

_VIEWER = require_role("admin", "security")

# Aktif pencereler + plana atanmis aktif checkpoint'ler (sira ile) + her
# checkpoint icin penceredeki ILK scan (LATERAL) — tek set-tabanli sorgu.
# Checkpoint eslesmesi dashboard/scheduler ile ayni: zaman araligi + checkpoint.
_AKTIF_PENCERE_SQL = text(
    """
    SELECT w.id              AS window_id,
           w.patrol_plan_id,
           p.ad              AS plan_adi,
           w.pencere_baslangic,
           w.pencere_bitis,
           w.durum,
           ppc.sira,
           c.id              AS checkpoint_id,
           c.ad              AS checkpoint_ad,
           s.okutma_zamani,
           s.guard_id        AS okutan_user_id
    FROM patrol_window w
    JOIN patrol_plan p ON p.id = w.patrol_plan_id
    LEFT JOIN patrol_plan_checkpoint ppc ON ppc.patrol_plan_id = w.patrol_plan_id
    LEFT JOIN checkpoint c ON c.id = ppc.checkpoint_id AND c.aktif = true
    LEFT JOIN LATERAL (
        SELECT se.okutma_zamani, se.guard_id
        FROM scan_event se
        WHERE se.checkpoint_id = c.id
          AND se.okutma_zamani >= w.pencere_baslangic
          AND se.okutma_zamani <  w.pencere_bitis
        ORDER BY se.okutma_zamani
        LIMIT 1
    ) s ON true
    -- BUGUN'e ait (tenant tz gun sinirini asan) TUM pencereler; aktif olmayan
    -- (gecmis-bugun/yaklasan) dahil. Aktiflik istemcide saatle hesaplanir.
    WHERE w.pencere_bitis > :day_start AND w.pencere_baslangic < :day_end
    ORDER BY w.pencere_baslangic, w.id, ppc.sira
    """
)


@router.get("/me/patrol-window", response_model=MePatrolWindowResponse)
async def my_patrol_window(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_VIEWER),
) -> MePatrolWindowResponse:
    now = datetime.now(tz=timezone.utc)
    tz_name = (
        await db.execute(select(Tenant.timezone))
    ).scalar_one_or_none() or "Europe/Istanbul"
    try:
        tz = ZoneInfo(tz_name)
    except Exception:
        tz = ZoneInfo("Europe/Istanbul")
    today = now.astimezone(tz).date()
    day_start = datetime(today.year, today.month, today.day, tzinfo=tz)
    day_end = day_start + timedelta(days=1)
    rows = (
        await db.execute(
            _AKTIF_PENCERE_SQL, {"day_start": day_start, "day_end": day_end}
        )
    ).mappings().all()

    windows: list[MePatrolWindowItem] = []
    for r in rows:
        if not windows or windows[-1].id != r["window_id"]:
            windows.append(
                MePatrolWindowItem(
                    id=r["window_id"],
                    patrol_plan_id=r["patrol_plan_id"],
                    plan_adi=r["plan_adi"],
                    pencere_baslangic=r["pencere_baslangic"],
                    pencere_bitis=r["pencere_bitis"],
                    durum=r["durum"],
                    checkpoints=[],
                )
            )
        # LEFT JOIN: plana atanmis aktif checkpoint yoksa satir NULL gelir
        if r["checkpoint_id"] is not None:
            windows[-1].checkpoints.append(
                MePatrolCheckpointOut(
                    checkpoint_id=r["checkpoint_id"],
                    ad=r["checkpoint_ad"],
                    sira=r["sira"],
                    okutuldu=r["okutma_zamani"] is not None,
                    okutma_zamani=r["okutma_zamani"],
                    okutan_user_id=r["okutan_user_id"],
                )
            )

    # window/checkpoints (tarama ODAGI) = SU AN aktif pencere; yoksa null.
    # windows[] bugunun TUM pencerelerini tasir (istemci listede gosterir).
    odak = next(
        (w for w in windows if w.pencere_baslangic <= now < w.pencere_bitis),
        None,
    )
    return MePatrolWindowResponse(
        generated_at=now,
        window=MePatrolWindowInfo.model_validate(odak, from_attributes=True) if odak else None,
        checkpoints=odak.checkpoints if odak else [],
        windows=windows,
    )
