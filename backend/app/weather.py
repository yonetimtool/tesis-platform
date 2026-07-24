"""Hava durumu yardimcilari (WP-C) — WMO weather_code -> basit durum + cache.

Cache surec-ici sozluk: {(lat, lon): (payload, monotonic_ts)}. TTL icinde
istemciler dis servise HIC cikmaz; dis servis dusukse SURESI GECMIS veri
donmeye devam eder (bayat-veri toleransi) — hic veri yoksa 503.
"""
from __future__ import annotations

import time as _time

# (payload, ts) — payload: {"sicaklik_c": float, "durum": str}
_CACHE: dict[tuple[float, float], tuple[dict, float]] = {}


def kod_durum(code: int) -> str:
    """WMO weather_code -> TR durum anahtari. Bilinmeyen kod 'kapali'
    (yanlis 'acik' gostermekten guvenli)."""
    if code == 0:
        return "acik"
    if code in (1, 2):
        return "parcali"
    if code in (45, 48):
        return "sis"
    if 51 <= code <= 67 or 80 <= code <= 82:
        return "yagmur"
    if 71 <= code <= 77 or code in (85, 86):
        return "kar"
    if 95 <= code <= 99:
        return "firtina"
    return "kapali"


def cache_get(lat: float, lon: float, ttl: int) -> dict | None:
    """TTL icindeyse payload; degilse None (bayat girdi SILINMEZ — 503
    yerine bayat veri donebilmek icin cache_get_stale kullanilir)."""
    hit = _CACHE.get((lat, lon))
    if hit and _time.monotonic() - hit[1] < ttl:
        return hit[0]
    return None


def cache_get_stale(lat: float, lon: float) -> dict | None:
    hit = _CACHE.get((lat, lon))
    return hit[0] if hit else None


def cache_put(lat: float, lon: float, payload: dict) -> None:
    _CACHE[(lat, lon)] = (payload, _time.monotonic())
