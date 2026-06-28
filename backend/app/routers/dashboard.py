"""GET /dashboard/live — canli panel ozeti — /contracts/openapi.yaml.

RBAC (auth.md §4): admin + security (cleaning/resident degil).
tenant token'dan; RLS ile izole. N+1'den kacinmak icin set-tabanli 3 sorgu:
  1) tenant.timezone (bugunun yerel sinirlarini UTC'ye cevirmek icin)
  2) aktif_turlar: bugunku patrol_window'lar + beklenen/okutulan checkpoint sayilari
  3) son_alarmlar: son 'kacirildi' pencerelerden turetilir (Notification tablosu
     sozlesmede YOK — bkz. README/flag)
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..models import AppUser
from ..schemas import AktifTurOut, AlarmOut, DashboardLiveOut

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

_VIEWER = require_role("admin", "security")

# Bugunku pencereler + beklenen (atanmis aktif checkpoint) ve okutulan
# (pencere araliginda okutulmus, beklenen) sayilari — tek set-tabanli sorgu.
_AKTIF_TURLAR_SQL = text(
    """
    SELECT w.id              AS patrol_window_id,
           w.patrol_plan_id  AS patrol_plan_id,
           p.ad              AS patrol_plan_ad,
           w.pencere_baslangic,
           w.pencere_bitis,
           w.durum,
           count(DISTINCT c.id)           AS beklenen,
           count(DISTINCT s.checkpoint_id) AS okutulan
    FROM patrol_window w
    JOIN patrol_plan p ON p.id = w.patrol_plan_id
    LEFT JOIN patrol_plan_checkpoint ppc ON ppc.patrol_plan_id = w.patrol_plan_id
    LEFT JOIN checkpoint c ON c.id = ppc.checkpoint_id AND c.aktif = true
    LEFT JOIN scan_event s ON s.checkpoint_id = c.id
         AND s.okutma_zamani >= w.pencere_baslangic
         AND s.okutma_zamani <  w.pencere_bitis
    WHERE w.pencere_baslangic >= :day_start AND w.pencere_baslangic < :day_end
    GROUP BY w.id, w.patrol_plan_id, p.ad, w.pencere_baslangic, w.pencere_bitis, w.durum
    ORDER BY w.pencere_baslangic
    """
)

# son_alarmlar KALICI notification tablosundan okunur (response semasi ayni).
# Yalniz sozlesmedeki Alarm.tip degerleri; peyzaj_* hatirlatmalari panele alarm
# olarak DUSMEZ (onlar /notifications altinda gorulur).
_ALARMLAR_SQL = text(
    """
    SELECT tip, patrol_window_id, checkpoint_id, mesaj, created_at
    FROM notification
    WHERE tip IN ('kacirilan_tur', 'eksik_checkpoint', 'gecikmis_okutma')
    ORDER BY created_at DESC
    LIMIT :alarm_limit
    """
)


@router.get("/live", response_model=DashboardLiveOut)
async def dashboard_live(
    alarm_limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_VIEWER),
) -> DashboardLiveOut:
    now = datetime.now(tz=timezone.utc)

    # tenant.timezone (RLS: kendi tenant satiri gorunur) -> bugunun yerel siniri
    tzname = (
        await db.execute(text("SELECT timezone FROM tenant"))
    ).scalar_one_or_none() or "UTC"
    tz = ZoneInfo(tzname)
    now_local = now.astimezone(tz)
    day_start_local = datetime(now_local.year, now_local.month, now_local.day, tzinfo=tz)
    day_start = day_start_local.astimezone(timezone.utc)
    day_end = (day_start_local + timedelta(days=1)).astimezone(timezone.utc)

    tur_rows = (
        await db.execute(_AKTIF_TURLAR_SQL, {"day_start": day_start, "day_end": day_end})
    ).mappings().all()
    aktif_turlar = [
        AktifTurOut(
            patrol_window_id=r["patrol_window_id"],
            patrol_plan_id=r["patrol_plan_id"],
            patrol_plan_ad=r["patrol_plan_ad"],
            pencere_baslangic=r["pencere_baslangic"],
            pencere_bitis=r["pencere_bitis"],
            durum=r["durum"],
            beklenen_checkpoint_sayisi=int(r["beklenen"]),
            okutulan_checkpoint_sayisi=int(r["okutulan"]),
        )
        for r in tur_rows
    ]

    alarm_rows = (
        await db.execute(_ALARMLAR_SQL, {"alarm_limit": alarm_limit})
    ).mappings().all()
    son_alarmlar = [
        AlarmOut(
            tip=r["tip"],
            olusma_zamani=r["created_at"],
            mesaj=r["mesaj"],
            patrol_window_id=r["patrol_window_id"],
            checkpoint_id=r["checkpoint_id"],
        )
        for r in alarm_rows
    ]

    return DashboardLiveOut(
        generated_at=now, aktif_turlar=aktif_turlar, son_alarmlar=son_alarmlar
    )
