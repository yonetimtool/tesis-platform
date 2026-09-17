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


def gun_yuruyor(
    local_date: date,
    gunler: list[int] | None,
    ek_tarihler: list[date] | None,
) -> bool:
    """(P239 §4) Bu YEREL TARIHTE plan yuruyor mu?

    `gunler` None ise HER GUN yurur (eski kayitlar; goc 0139 notu).
    Aksi halde ISO haftagunu (1=Pzt ... 7=Paz) listede olmali.

    `ek_tarihler` BIRLESIMDIR, kesisim degil: bayram/ozel etkinlik gunu
    haftalik secimin DISINDA kaldigi icin eklenir — "hem persembe hem de
    30 Agustos" demenin baska yolu yok.

    GECE PLANI: pencere BASLADIGI gunun haftagunune aittir. "Her
    pazartesi gece devriyesi" 22:00'de pazartesi baslar, salı 06:00'da
    biter; salı gunu secilmemis olmasi bu pencereyi dusurmemeli.
    """
    if ek_tarihler and local_date in ek_tarihler:
        return True
    if gunler is None:
        return True
    return local_date.isoweekday() in gunler


def plan_windows(
    tzname: str,
    now_utc: datetime,
    horizon_days: int,
    baslangic: time,
    bitis: time,
    periyot_dakika: int,
    gunler: list[int] | None = None,
    ek_tarihler: list[date] | None = None,
) -> list[Window]:
    """now_utc'nin tenant-yerel gununden baslayarak horizon_days gun pencere uret.

    Gece vardiyasi (baslangic > bitis) DUN baslamis pencere BUGUNE sarkar: or.
    22:00->06:00 planinda 02:00'de aktif olan pencere DUNKU yerel tarihe aittir.
    Yalniz "bugunden ileri" uretilirse bu pencere hic olusmaz -> gece devriyesi
    okutmasi hicbir pencereye sayilmaz. Bu yuzden wrap planlar icin DUNU de uret;
    ama yalniz hala aktif/gelecek (pencere_bitis > now) olanlari ekle ki plan
    olusmadan onceki zamana sahte 'kacirildi' yazilmasin (gecmis atlanir)."""
    tz = ZoneInfo(tzname)
    today_local = now_utc.astimezone(tz).date()
    out: list[Window] = []
    if baslangic > bitis:
        dun = today_local - timedelta(days=1)
        if gun_yuruyor(dun, gunler, ek_tarihler):
            for w_start, w_end in windows_for_local_date(
                tzname, dun, baslangic, bitis, periyot_dakika
            ):
                if w_end > now_utc:
                    out.append((w_start, w_end))
    for i in range(max(horizon_days, 0)):
        gun = today_local + timedelta(days=i)
        if not gun_yuruyor(gun, gunler, ek_tarihler):
            continue
        out.extend(
            windows_for_local_date(
                tzname, gun, baslangic, bitis, periyot_dakika
            )
        )
    return out
