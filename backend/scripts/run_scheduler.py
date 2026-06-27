"""Scheduler'i ELLE (senkron) calistir — beat'i beklemeden test/operasyon icin.

    docker compose exec api python -m scripts.run_scheduler --once
    docker compose exec api python -m scripts.run_scheduler --generate
    docker compose exec api python -m scripts.run_scheduler --detect --now 2026-06-27T07:00:00Z
    docker compose exec api python -m scripts.run_scheduler --generate --horizon 1

--once: hem uretim hem tespit. --now: ISO8601 UTC (test icin sabit an).
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone

from app.scheduler.service import detect_missed, materialize_windows


def _parse_now(value: str | None) -> datetime | None:
    if not value:
        return None
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def main() -> int:
    p = argparse.ArgumentParser(description="Patrol scheduler manuel tetikleme")
    p.add_argument("--once", action="store_true", help="uretim + tespit")
    p.add_argument("--generate", action="store_true", help="pencere uretimi")
    p.add_argument("--detect", action="store_true", help="kacirilan tur tespiti")
    p.add_argument("--now", default=None, help="ISO8601 UTC sabit an (test)")
    p.add_argument("--horizon", type=int, default=None, help="kac gun ileri uret")
    args = p.parse_args()

    now = _parse_now(args.now)
    do_gen = args.once or args.generate or not (args.generate or args.detect)
    do_det = args.once or args.detect or not (args.generate or args.detect)

    if do_gen:
        created = materialize_windows(now=now, horizon_days=args.horizon)
        print(f"[scheduler] generate -> {created} yeni pencere")
    if do_det:
        summary = detect_missed(now=now)
        print(f"[scheduler] detect   -> {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
