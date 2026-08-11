"""FastAPI uygulamasi — iskelet + /health."""
from __future__ import annotations

from contextlib import asynccontextmanager

import redis.asyncio as aioredis
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from .config import settings
from .db import engine
from .gunlukleme import yapilandir as gunlukleri_yapilandir
from .errors import install_error_handlers
from .routers import activity as activity_router
from .routers import arama as arama_router
from .routers import ekler as ekler_router
from .routers import announcements as announcements_router
from .routers import assets as assets_router
from .routers import audit as audit_router
from .routers import auth as auth_router
from .routers import kayit_basvurulari
from .routers import budget as budget_router
from .routers import cameras as cameras_router
from .routers import checkpoints as checkpoints_router
from .routers import common_areas as common_areas_router
from .routers import complaints as complaints_router
from .routers import unit_complaints as unit_complaints_router
from .routers import unit_tanimlari as unit_tanimlari_router
from .routers import muhasebe_tanimlari as muhasebe_tanimlari_router
from .routers import borclandirma_uc as borclandirma_router
from .routers import finans as finans_router
from .routers import sakin_odeme as sakin_odeme_router
from .routers import rapor_motoru as rapor_motoru_router
from .routers import mesajlar as mesajlar_router
from .routers import gurultu_uc as gurultu_router
from .routers import anketler as anketler_router
from .routers import ice_aktarim as ice_aktarim_router
from .routers import kurulum as kurulum_router
from .routers import yetki_matrisi as yetki_router
from .routers import kvkk as kvkk_router
from .routers import yonetisim as yonetisim_router
from .routers import dashboard as dashboard_router
from .routers import devices as devices_router
from .routers import dues as dues_router
from .routers import patrol_windows as patrol_windows_router
from .routers import events as events_router
from .routers import external_services as external_services_router
from .routers import kargo as kargo_router
from .routers import me as me_router
from .routers import me_patrol as me_patrol_router
from .routers import notifications as notifications_router
from .routers import patrol_plans as patrol_plans_router
from .routers import reports as reports_router
from .routers import reservations as reservations_router
from .routers import residents as residents_router
from .routers import scans as scans_router
from .routers import shifts as shifts_router
from .routers import site_rules as site_rules_router
from .routers import task_completions as task_completions_router
from .routers import task_categories as task_categories_router
from .routers import tasks as tasks_router
from .routers import tenant as tenant_router
from .routers import support as support_router
from .routers import tanitim as tanitim_router
from .routers import transparency as transparency_router
from .routers import yonetici_iletisim as yonetici_iletisim_router
from .routers import tenants as tenants_router
from .routers import units as units_router
from .routers import blocks as blocks_router
from .routers import call_targets as call_targets_router
from .routers import integrations as integrations_router
from .routers import users as users_router
from .routers import uploads as uploads_router
from .routers import unit_access as unit_access_router
from .routers import anpr as anpr_router
from .routers import vehicle_passes as vehicle_passes_router
from .routers import violations as violations_router
from .routers import visitors as visitors_router
from .routers import weather as weather_router
from .routers import webhooks as webhooks_router

#: KODUN BEKLEDIGI Alembic revizyonu — goc dosyalarindan HESAPLANIR.
#:
#: ELLE YAZILMAZ: elle tutulan bir surum sabiti, goc eklendiginde
#: guncellenmeyi unutulur ve kontrol sessizce yalan soylemeye baslar.
#: `down_revision` zinciri, hicbir baska revizyonun `down_revision`i
#: OLMAYAN tek dugumu verir; o da HEAD'dir.
#:
#: Dosyalar imajda yoksa (yalniz `api` imaji, `contracts/` bagli degil)
#: bos doner ve kontrol KARAR VERMEZ — olcemedigimiz seyi "bozuk" ilan
#: etmek, calisan bir sistemi hatali gostermek olurdu.
def _goc_head() -> str:
    import pathlib
    import re

    for kok in ("/contracts/db/migrations/versions",
                "contracts/db/migrations/versions"):
        d = pathlib.Path(kok)
        if not d.is_dir():
            continue
        revizyonlar: set[str] = set()
        oncekiler: set[str] = set()
        for f in d.glob("*.py"):
            govde = f.read_text(encoding="utf-8")
            r = re.search(r'^revision = "([^"]+)"', govde, re.M)
            p = re.search(r'^down_revision = "([^"]+)"', govde, re.M)
            if r:
                revizyonlar.add(r.group(1))
            if p:
                oncekiler.add(p.group(1))
        uclar = revizyonlar - oncekiler
        if len(uclar) == 1:
            return uclar.pop()
    return ""


SEMA_BEKLENEN = _goc_head()


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


# (P134) GUNLUK YAPILANDIRMASI — uygulama KURULMADAN once.
#
# NEDEN LIFESPAN'DE DEGIL: `lifespan` sunucu ayaga kalkarken calisir; oysa
# router modulleri ICE AKTARILIRKEN de log yazabilir ve o satirlar
# kaybolurdu. Ayrica pytest gibi uvicorn'suz kosumlarda `lifespan` hic
# calismayabilir; yapilandirma modul yuklenirken uygulanmali.
gunlukleri_yapilandir()

app = FastAPI(
    title="Tesis Guvenlik & Operasyon API",
    version="0.1.0",
    lifespan=lifespan,
)

install_error_handlers(app)

# CORS — YALNIZ prod'da (CORS_ORIGINS set edilince) eklenir. Dev'de liste bos =>
# middleware yok => mevcut davranis (ve testler) degismez.
if settings.cors_origin_list:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(auth_router.router)
app.include_router(kayit_basvurulari.router)
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
app.include_router(unit_complaints_router.router)
app.include_router(unit_tanimlari_router.router)
app.include_router(muhasebe_tanimlari_router.router)
app.include_router(borclandirma_router.router)
app.include_router(finans_router.router)
app.include_router(sakin_odeme_router.router)
app.include_router(rapor_motoru_router.router)
app.include_router(mesajlar_router.router)
app.include_router(yonetisim_router.router)
app.include_router(kvkk_router.router)
app.include_router(gurultu_router.router)
app.include_router(anketler_router.router)
app.include_router(kurulum_router.router)
app.include_router(ice_aktarim_router.router)
app.include_router(yetki_router.router)
app.include_router(visitors_router.router)
app.include_router(kargo_router.router)
app.include_router(unit_access_router.router)
app.include_router(common_areas_router.router)
app.include_router(reservations_router.router)
app.include_router(events_router.router)
app.include_router(site_rules_router.router)
app.include_router(tasks_router.router)
app.include_router(task_categories_router.router)
app.include_router(task_completions_router.router)
app.include_router(uploads_router.router)
app.include_router(assets_router.router)
app.include_router(external_services_router.router)
app.include_router(tenant_router.router)
app.include_router(yonetici_iletisim_router.router)
app.include_router(tenants_router.router)
app.include_router(units_router.router)
app.include_router(blocks_router.router)
app.include_router(dues_router.router)
app.include_router(budget_router.router)
app.include_router(reports_router.router)
app.include_router(users_router.router)
app.include_router(call_targets_router.router)
app.include_router(integrations_router.router)
app.include_router(webhooks_router.router)
app.include_router(audit_router.router)
app.include_router(support_router.router)
# (P127.2) Tanitim sitesi iletisim formu — public gonderim + admin okuma.
app.include_router(tanitim_router.router)
app.include_router(transparency_router.router)
app.include_router(weather_router.router)
app.include_router(cameras_router.router)
# G1+G4: arac gecisi + otopark dolulugu (ayni modul, iki prefix).
app.include_router(vehicle_passes_router.router)
app.include_router(vehicle_passes_router.parking_router)
app.include_router(violations_router.router)
# P16: kaynaktan bagimsiz ANPR girisi (kamera kutusu API anahtariyla yazar).
app.include_router(anpr_router.router)
# G5: birlesik "Son Hareketler" akisi (istemci tarafi birlestirmeyi kaldirir).
app.include_router(activity_router.router)
app.include_router(arama_router.router)
app.include_router(ekler_router.router)


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

    # SEMA SURUMU (P124) — "kod yeni, sema eski" SESSIZ kalmasin.
    #
    # GERCEK OLAY: `snapshot_url` kolonu koda eklendi, prod'da `api` imaji
    # yeniden derlendi ama `migrate` KOSULMADI (dagitim belgesindeki sira
    # eksikti). SQLAlchemy her `SELECT camera` icin artik o kolonu istiyor;
    # Postgres "column does not exist" diyor ve `GET /cameras` 500 veriyor.
    # Belirti kamera modulunun TAMAMEN olmesiydi — liste bos, karo yok,
    # oynatilacak bir sey yok — ama `/health` "ok" demeye devam ediyordu.
    #
    # Bu kontrol, ayrismayi ILK istekte ve TEK YERDE gorunur kilar. Ayrica
    # `db_ok` gibi HAYATI sayilmaz: sema ileri/geri gitmis olsa da uygulama
    # birçok uçta calismaya devam eder; 503 dondurmek calisan bir sistemi
    # yuk dengeleyiciden dusururdu. Bu yuzden `status` DEGISMEZ, alan
    # yalnizca RAPOR EDER.
    sema = await _sema_surumu()
    healthy = db_ok and redis_ok
    return JSONResponse(
        status_code=200 if healthy else 503,
        content={
            "status": "ok" if healthy else "degraded",
            "checks": {"database": db_ok, "redis": redis_ok},
            "schema": sema,
        },
    )


async def _sema_surumu() -> dict[str, object]:
    """Veritabanindaki Alembic revizyonu ile KODUN bekledigi revizyon.

    `uyumlu` false ise: kod ile sema AYRISMIS demektir ve bazi uclar
    500 verecektir. Dogru tepki `migrate` kosmaktir.
    """
    try:
        async with engine.connect() as conn:
            row = await conn.execute(text("SELECT version_num FROM alembic_version"))
            veritabani = row.scalar_one_or_none()
    except Exception:
        return {"database": None, "beklenen": SEMA_BEKLENEN, "uyumlu": None}
    return {
        "database": veritabani,
        "beklenen": SEMA_BEKLENEN,
        # `beklenen` bos ise (goc dosyalari imajda yok) KARAR VERILMEZ:
        # `false` demek, olcemedigimiz bir seyi "bozuk" ilan etmek olurdu.
        "uyumlu": None if not SEMA_BEKLENEN else veritabani == SEMA_BEKLENEN,
    }
