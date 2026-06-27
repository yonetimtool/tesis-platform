"""Scheduler DB islemleri — pencere uretimi + kacirilan tur tespiti.

RLS (KRITIK):
  * Tenant LISTESI app_rw ile okunamaz (tenant tablosunda RLS; baglam yokken
    hicbir satir gorunmez). Bu yuzden tenant enumerasyonu OWNER baglantisiyla
    (salt-okuma: id, timezone) yapilir — gerekce: RLS bootstrap.
  * Asil is (plan/checkpoint/scan okuma, patrol_window yazma) her tenant icin
    APP_RW + `SET LOCAL app.current_tenant_id` ile, RLS altinda yapilir. Boylece
    bir tenant'in verisi digerine sizmaz (izolasyon DB'de zorlanir).

Idempotency:
  * Uretim: INSERT ... ON CONFLICT (patrol_plan_id, pencere_baslangic) DO NOTHING
    (sozlesmedeki uq_patrol_window_plan_baslangic dogal anahtari).
  * Tespit: yalnizca durum='bekliyor' pencereler islenir; tamamlandi/kacirildi
    olanlara dokunulmaz (tekrar notify yok).

"tamamlandi" tanimi (v0): Pencere bitmis (pencere_bitis <= now) ve plana atanmis
TUM AKTIF checkpoint'ler icin, okutma_zamani pencere araliginda [baslangic, bitis)
en az bir scan_event varsa => 'tamamlandi'. En az biri eksikse => 'kacirildi'.
Plana atanmis aktif checkpoint yoksa (bos plan) => vacuously 'tamamlandi'.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

import psycopg

from ..config import settings
from .notify import notify_missed_tour
from .windows import plan_windows


def _now(now: datetime | None) -> datetime:
    return now or datetime.now(tz=timezone.utc)


def _list_tenants(owner_dsn: str) -> list[tuple[uuid.UUID, str]]:
    """Tum tenant (id, timezone) — OWNER ile (RLS bootstrap, salt-okuma)."""
    with psycopg.connect(owner_dsn, autocommit=True, connect_timeout=10) as conn:
        return [
            (row[0], row[1])
            for row in conn.execute("SELECT id, timezone FROM tenant").fetchall()
        ]


def materialize_windows(
    *,
    now: datetime | None = None,
    horizon_days: int | None = None,
    owner_dsn: str | None = None,
    app_dsn: str | None = None,
) -> int:
    """Aktif planlar icin pencereleri 'bekliyor' olarak onceden uretir.

    Donus: yeni eklenen pencere sayisi (idempotent; tekrarlar 0 ekler).
    """
    now = _now(now)
    horizon_days = horizon_days if horizon_days is not None else settings.scheduler_horizon_days
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn

    created = 0
    tenants = _list_tenants(owner_dsn)
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id, tzname in tenants:
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
                )
                plans = conn.execute(
                    "SELECT id, baslangic_saat, bitis_saat, periyot_dakika "
                    "FROM patrol_plan WHERE aktif = true"
                ).fetchall()
                for plan_id, baslangic, bitis, periyot in plans:
                    for w_start, w_end in plan_windows(
                        tzname, now, horizon_days, baslangic, bitis, periyot
                    ):
                        cur = conn.execute(
                            "INSERT INTO patrol_window "
                            "(tenant_id, patrol_plan_id, pencere_baslangic, pencere_bitis, durum) "
                            "VALUES (%s, %s, %s, %s, 'bekliyor') "
                            "ON CONFLICT (patrol_plan_id, pencere_baslangic) DO NOTHING",
                            (tenant_id, plan_id, w_start, w_end),
                        )
                        created += cur.rowcount  # 1 eklendi, 0 zaten vardi
    return created


def detect_missed(
    *,
    now: datetime | None = None,
    owner_dsn: str | None = None,
    app_dsn: str | None = None,
) -> dict[str, int]:
    """Bitmis 'bekliyor' pencereleri tamamlandi/kacirildi olarak isaretler.

    Donus: {"tamamlandi": n, "kacirildi": m}. Kacirildi'da notify_missed_tour cagrilir.
    """
    now = _now(now)
    owner_dsn = owner_dsn or settings.owner_dsn
    app_dsn = app_dsn or settings.app_dsn

    summary = {"tamamlandi": 0, "kacirildi": 0}
    tenants = _list_tenants(owner_dsn)
    with psycopg.connect(app_dsn, connect_timeout=10) as conn:
        for tenant_id, _tz in tenants:
            with conn.transaction():
                conn.execute(
                    "SELECT set_config('app.current_tenant_id', %s, true)", (str(tenant_id),)
                )
                windows = conn.execute(
                    "SELECT id, patrol_plan_id, pencere_baslangic, pencere_bitis "
                    "FROM patrol_window "
                    "WHERE durum = 'bekliyor' AND pencere_bitis <= %s",
                    (now,),
                ).fetchall()

                for window_id, plan_id, w_start, w_end in windows:
                    expected = [
                        r[0]
                        for r in conn.execute(
                            "SELECT c.id FROM patrol_plan_checkpoint ppc "
                            "JOIN checkpoint c ON c.id = ppc.checkpoint_id "
                            "WHERE ppc.patrol_plan_id = %s AND c.aktif = true",
                            (plan_id,),
                        ).fetchall()
                    ]
                    missing = [
                        cid
                        for cid in expected
                        if conn.execute(
                            "SELECT 1 FROM scan_event "
                            "WHERE checkpoint_id = %s "
                            "AND okutma_zamani >= %s AND okutma_zamani < %s LIMIT 1",
                            (cid, w_start, w_end),
                        ).fetchone()
                        is None
                    ]

                    if missing:
                        conn.execute(
                            "UPDATE patrol_window SET durum = 'kacirildi', updated_at = now() "
                            "WHERE id = %s",
                            (window_id,),
                        )
                        notify_missed_tour(
                            tenant_id=tenant_id,
                            plan_id=plan_id,
                            window_id=window_id,
                            pencere_baslangic=w_start,
                            pencere_bitis=w_end,
                            missing_checkpoints=missing,
                        )
                        summary["kacirildi"] += 1
                    else:
                        conn.execute(
                            "UPDATE patrol_window SET durum = 'tamamlandi', updated_at = now() "
                            "WHERE id = %s",
                            (window_id,),
                        )
                        summary["tamamlandi"] += 1
    return summary
