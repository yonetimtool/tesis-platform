"""Pencere zaman hesabi — saf (DB'siz), birim-test edilebilir.

Plan saatleri tenant.timezone'da GUN-ICI yerel saatlerdir; burada somut UTC
araliklara cevrilir. DST-guvenli: yerel saat zoneinfo ile olusturulup
.astimezone(UTC) ile cevrilir (her an icin dogru ofset uygulanir).

Kural (/contracts/README.md): baslangic_saat > bitis_saat => pencere ERTESI
gune sarkar (gece vardiyasi). Esitlikte ayni gun (sifir uzunluk => pencere yok).
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

Window = tuple[datetime, datetime]  # (utc_start, utc_end)


def _local_dt(tzname: str, d: date, t: time) -> datetime:
    return datetime(d.year, d.month, d.day, t.hour, t.minute, t.second, tzinfo=ZoneInfo(tzname))


def windows_for_local_date(
    tzname: str,
    local_date: date,
    baslangic: time,
    bitis: time,
    periyot_dakika: int,
) -> list[Window]:
    """Tek bir yerel tarih icin (baslangic->bitis, periyot) UTC pencereleri."""
    if periyot_dakika <= 0:
        return []
    start_local = _local_dt(tzname, local_date, baslangic)
    end_date = local_date + timedelta(days=1) if baslangic > bitis else local_date
    end_local = _local_dt(tzname, end_date, bitis)

    step = timedelta(minutes=periyot_dakika)
    out: list[Window] = []
    w = start_local
    # yalnizca TAM periyot pencereleri (kismi son pencere uretilmez)
    while w + step <= end_local:
        out.append((w.astimezone(timezone.utc), (w + step).astimezone(timezone.utc)))
        w += step
    return out


def plan_windows(
    tzname: str,
    now_utc: datetime,
    horizon_days: int,
    baslangic: time,
    bitis: time,
    periyot_dakika: int,
) -> list[Window]:
    """now_utc'nin tenant-yerel gununden baslayarak horizon_days gun pencere uret."""
    today_local = now_utc.astimezone(ZoneInfo(tzname)).date()
    out: list[Window] = []
    for i in range(max(horizon_days, 0)):
        out.extend(
            windows_for_local_date(
                tzname, today_local + timedelta(days=i), baslangic, bitis, periyot_dakika
            )
        )
    return out
