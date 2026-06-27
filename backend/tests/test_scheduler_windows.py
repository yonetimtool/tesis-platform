"""Pencere zaman hesabi — saf birim testler (DB yok). Yerel->UTC + DST."""
from __future__ import annotations

from datetime import date, datetime, time, timezone

from app.scheduler.windows import plan_windows, windows_for_local_date

UTC = timezone.utc


def test_istanbul_night_six_windows():
    # Istanbul +03 (DST yok): 00:00 yerel = 21:00Z onceki gun.
    w = windows_for_local_date("Europe/Istanbul", date(2026, 1, 15), time(0, 0), time(6, 0), 60)
    assert len(w) == 6
    assert w[0][0] == datetime(2026, 1, 14, 21, 0, tzinfo=UTC)
    assert w[0][1] == datetime(2026, 1, 14, 22, 0, tzinfo=UTC)
    assert w[-1][1] == datetime(2026, 1, 15, 3, 0, tzinfo=UTC)


def test_overnight_shift_crosses_midnight():
    # baslangic > bitis => ertesi gune sarkar (gece vardiyasi).
    w = windows_for_local_date("Europe/Istanbul", date(2026, 1, 15), time(23, 0), time(7, 0), 60)
    assert len(w) == 8
    assert w[0][0] == datetime(2026, 1, 15, 20, 0, tzinfo=UTC)   # 23:00 +03
    assert w[-1][1] == datetime(2026, 1, 16, 4, 0, tzinfo=UTC)   # ertesi gun 07:00 +03


def test_berlin_dst_offset_changes():
    # zoneinfo DST-farkindaligi: kis +01, yaz +02 => UTC karsiligi farkli.
    winter = windows_for_local_date("Europe/Berlin", date(2026, 1, 15), time(0, 0), time(1, 0), 60)
    summer = windows_for_local_date("Europe/Berlin", date(2026, 7, 15), time(0, 0), time(1, 0), 60)
    assert winter[0][0] == datetime(2026, 1, 14, 23, 0, tzinfo=UTC)  # +01
    assert summer[0][0] == datetime(2026, 7, 14, 22, 0, tzinfo=UTC)  # +02 (yaz saati)


def test_plan_windows_horizon():
    now = datetime(2026, 1, 15, 12, 0, tzinfo=UTC)  # Istanbul yerel 15:00 -> 15 Ocak
    assert len(plan_windows("Europe/Istanbul", now, 1, time(0, 0), time(6, 0), 60)) == 6
    assert len(plan_windows("Europe/Istanbul", now, 2, time(0, 0), time(6, 0), 60)) == 12


def test_equal_times_zero_windows():
    # baslangic == bitis => sifir uzunluk => pencere yok.
    assert windows_for_local_date("Europe/Istanbul", date(2026, 1, 15), time(8, 0), time(8, 0), 60) == []
