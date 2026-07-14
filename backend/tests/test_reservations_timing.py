"""Rezervasyon zamanlama kurallari — SAF birim testler (DB'siz).

Slot baslangici tenant-yerel (Europe/Istanbul) yorumlanir; UTC now'a gore
24s penceresi + gunluk kota + son-dakika istisnasi.
"""
from __future__ import annotations

from datetime import date, datetime, time, timezone

from app.reservations_timing import booking_reason, slot_start_utc

# Sabit now: 2026-07-14 09:00 UTC = 12:00 Istanbul.
NOW = datetime(2026, 7, 14, 9, 0, 0, tzinfo=timezone.utc)
TZ = "Europe/Istanbul"
TODAY = date(2026, 7, 14)
TOMORROW = date(2026, 7, 15)


def _reason(tarih, bas, *, dolu=False, kota=False):
    return booking_reason(TZ, tarih, bas, dolu=dolu, kota_dolu=kota, now=NOW)


def test_slot_start_utc_istanbul_ofseti():
    # 13:00 Istanbul = 10:00 UTC (yaz, +03).
    assert slot_start_utc(TZ, TODAY, time(13, 0)) == datetime(
        2026, 7, 14, 10, 0, tzinfo=timezone.utc
    )


def test_dolu_her_seyin_onunde():
    assert _reason(TODAY, time(13, 0), dolu=True) == "dolu"
    # dolu + gecmis olsa bile 'dolu' doner (oncelik).
    assert _reason(TODAY, time(11, 0), dolu=True, kota=True) == "dolu"


def test_gecmis_slot():
    # 11:00 Istanbul < simdi 12:00 -> gecti.
    assert _reason(TODAY, time(11, 0)) == "gecti"


def test_24_saat_penceresi():
    # bugun 13:00 (delta 1s) -> edilebilir (None).
    assert _reason(TODAY, time(13, 0)) is None
    # yarin 13:00 (delta 25s >= 24s) -> cok_erken.
    assert _reason(TOMORROW, time(13, 0)) == "cok_erken"
    # yarin 10:00 (delta 22s < 24s) -> edilebilir.
    assert _reason(TOMORROW, time(10, 0)) is None
    # tam 24s sinir (yarin 12:00) -> cok_erken (delta == 24s, "az" degil).
    assert _reason(TOMORROW, time(12, 0)) == "cok_erken"


def test_gunluk_kota_ve_son_dakika():
    # kota dolu + slot >10dk sonra -> gunluk.
    assert _reason(TODAY, time(13, 0), kota=True) == "gunluk"
    # kota dolu + slot <10dk kala (12:05, delta 5dk) -> baypas (None).
    assert _reason(TODAY, time(12, 5), kota=True) is None
    # kota dolu + tam 10dk (12:10) -> "az" degil -> gunluk.
    assert _reason(TODAY, time(12, 10), kota=True) == "gunluk"
    # kota bos + normal slot -> edilebilir.
    assert _reason(TODAY, time(13, 0), kota=False) is None
