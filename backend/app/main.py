"""FastAPI uygulamasi — iskelet + /health."""
from __future__ import annotations

from contextlib import asynccontextmanager

import redis.asyncio as aioredis
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from sqlalchemy import text

from .config import settings
from .db import engine
from .errors import install_error_handlers
from .routers import announcements as announcements_router
from .routers import assets as assets_router
from .routers import auth as auth_router
from .routers import budget as budget_router
from .routers import checkpoints as checkpoints_router
from .routers import complaints as complaints_router
from .routers import dashboard as dashboard_router
from .routers import devices as devices_router
from .routers import dues as dues_router
from .routers import patrol_windows as patrol_windows_router
from .routers import emergency as emergency_router
from .routers import landscape as landscape_router
from .routers import me as me_router
from .routers import me_patrol as me_patrol_router
from .routers import notifications as notifications_router
from .routers import patrol_plans as patrol_plans_router
from .routers import reports as reports_router
from .routers import residents as residents_router
from .routers import scans as scans_router
from .routers import shifts as shifts_router
from .routers import task_completions as task_completions_router
from .routers import tasks as tasks_router
from .routers import tenant as tenant_router
from .routers import units as units_router
from .routers import users as users_router
from .routers import uploads as uploads_router
from .routers import webhooks as webhooks_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.redis = aioredis.from_url(
        settings.redis_url, encoding="utf-8", decode_responses=True
    )
    try:
        yield
    finally:
        await app.state.redis.aclose()
        await engine.dispose()


app = FastAPI(
    title="Tesis Guvenlik & Operasyon API",
    version="0.1.0",
    lifespan=lifespan,
)

install_error_handlers(app)
app.include_router(auth_router.router)
app.include_router(residents_router.router)
app.include_router(me_router.router)
app.include_router(me_patrol_router.router)
app.include_router(shifts_router.router)
app.include_router(checkpoints_router.router)
app.include_router(patrol_plans_router.router)
app.include_router(scans_router.router)
app.include_router(dashboard_router.router)
app.include_router(devices_router.router)
app.include_router(patrol_windows_router.router)
app.include_router(notifications_router.router)
app.include_router(announcements_router.router)
app.include_router(complaints_router.router)
app.include_router(tasks_router.router)
app.include_router(task_completions_router.router)
app.include_router(uploads_router.router)
app.include_router(landscape_router.router)
app.include_router(assets_router.router)
app.include_router(emergency_router.router)
app.include_router(tenant_router.router)
app.include_router(units_router.router)
app.include_router(dues_router.router)
app.include_router(budget_router.router)
app.include_router(reports_router.router)
app.include_router(users_router.router)
app.include_router(webhooks_router.router)


@app.get("/health", tags=["health"])
async def health() -> JSONResponse:
    """DB (app_rw) + Redis erisimini kontrol eder."""
    db_ok = False
    redis_ok = False

    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    try:
        redis_ok = bool(await app.state.redis.ping())
    except Exception:
        redis_ok = False

    healthy = db_ok and redis_ok
    return JSONResponse(
        status_code=200 if healthy else 503,
        content={
            "status": "ok" if healthy else "degraded",
            "checks": {"database": db_ok, "redis": redis_ok},
        },
    )
