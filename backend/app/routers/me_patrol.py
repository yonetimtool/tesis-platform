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

from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..models import AppUser
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
    WHERE w.pencere_baslangic <= :now AND w.pencere_bitis > :now
    ORDER BY w.pencere_bitis, w.id, ppc.sira
    """
)


@router.get("/me/patrol-window", response_model=MePatrolWindowResponse)
async def my_patrol_window(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_VIEWER),
) -> MePatrolWindowResponse:
    now = datetime.now(tz=timezone.utc)
    rows = (
        await db.execute(_AKTIF_PENCERE_SQL, {"now": now})
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

    # window/checkpoints = bitisi en yakin aktif pencere (siralama SQL'de)
    ilk = windows[0] if windows else None
    return MePatrolWindowResponse(
        generated_at=now,
        window=MePatrolWindowInfo.model_validate(ilk, from_attributes=True) if ilk else None,
        checkpoints=ilk.checkpoints if ilk else [],
        windows=windows,
    )
