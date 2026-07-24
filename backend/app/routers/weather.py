"""GET /weather — tenant konumu icin Open-Meteo proxy'si (WP-C).

RBAC: TUM kimlikli roller (ana ekran basligi). Dis istek YALNIZ cache
kacirilinca atilir (30dk TTL); kisa timeout (3sn) — baslik ana ekrani
bekletmez. Dis servis dusukse bayat cache donulur; hic veri yoksa 503.
"""
from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Tenant
from ..schemas import WeatherOut
from ..weather import cache_get, cache_get_stale, cache_put, kod_durum

router = APIRouter(prefix="/weather", tags=["weather"])

_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")


@router.get("", response_model=WeatherOut)
async def get_weather(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> WeatherOut:
    t = (await db.execute(select(Tenant))).scalar_one_or_none()
    if t is None:
        raise APIError(404, "not_found", "Tenant bulunamadi.")
    lat, lon = float(t.konum_lat), float(t.konum_lon)

    payload = cache_get(lat, lon, settings.weather_cache_ttl)
    if payload is None:
        try:
            async with httpx.AsyncClient(timeout=3.0) as http:
                r = await http.get(
                    f"{settings.weather_base_url}/v1/forecast",
                    params={
                        "latitude": lat,
                        "longitude": lon,
                        "current": "temperature_2m,weather_code",
                    },
                )
                r.raise_for_status()
                cur = r.json()["current"]
                payload = {
                    "sicaklik_c": float(cur["temperature_2m"]),
                    "durum": kod_durum(int(cur["weather_code"])),
                }
                cache_put(lat, lon, payload)
        except Exception:
            payload = cache_get_stale(lat, lon)  # bayat-veri toleransi
    if payload is None:
        raise APIError(503, "weather_unavailable", "Hava durumu su an alinamiyor.")
    return WeatherOut(**payload, konum_ad=t.konum_ad)
