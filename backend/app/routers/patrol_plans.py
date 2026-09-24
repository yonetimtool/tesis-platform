"""PatrolPlan CRUD + checkpoint atama — /contracts/openapi.yaml (patrol-plans).

Endpoint'ler (sozlesmedeki gibi):
  GET    /patrol-plans                 liste (sayfali)
  POST   /patrol-plans                 olustur
  GET    /patrol-plans/{id}            detay (checkpoints dahil)
  PATCH  /patrol-plans/{id}            guncelle
  DELETE /patrol-plans/{id}            sil
  GET    /patrol-plans/{id}/checkpoints  atanmis noktalar (sirali)
  PUT    /patrol-plans/{id}/checkpoints  atamayi tamamen degistir (replace)

RBAC: GET admin/yonetici/security/tesis_gorevlisi; yazma (POST/PATCH/DELETE/PUT)
admin + yonetici (yonetici uygulamada devriye plani tanimlar). Capraz-tenant
shift/checkpoint referansi uygulama katmaninda 422 ile reddedilir.
"""
from __future__ import annotations

import datetime as dt
import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..celery_app import celery_app
from ..crud_helpers import ensure_checkpoints_in_tenant, get_or_404, translate_integrity
from ..deps import get_tenant_db, require_guvenlik_yazma, require_role
from ..errors import APIError
from ..models import AppUser, PatrolPlan, PatrolPlanCheckpoint, Shift
from ..schemas import (
    PatrolPlanCheckpointAssign,
    PatrolPlanCheckpointOut,
    PatrolPlanCreate,
    PatrolPlanDetailOut,
    PatrolPlanListResponse,
    PatrolPlanOut,
    PatrolPlanUpdate,
)

router = APIRouter(prefix="/patrol-plans", tags=["patrol-plans"])

# Devriye plani CRUD + checkpoint atama: admin + yonetici (yonetici uygulamada
# devriye plani tanimlar — checkpoint kumesi + saatler + tur sikligi). Saha
# rolleri yalniz OKUR.
# (P35) YAZMA SAHIBI MODA BAGLI: yonetim_ici -> yonetici, dis_sirket ->
# guvenlik_amiri. admin her iki modda yazar (tesis kilitli kalmasin).
_WRITER = require_guvenlik_yazma()
# OKUMA HERKESE ACIK KALIR: dis sirkete devretmek DENETIMI devretmek
# degildir — yonetici planlari gormeye devam eder.
_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "guvenlik_amiri"
)


def _regen_windows() -> None:
    """Plan/checkpoint degisikligi sonrasi patrol_window'lari HEMEN uret (saatlik
    beat'i beklemeden -> yonetici "Bugun"de + saha "Turlarim"da aninda gorsun).
    Kisa countdown ile: istek transaction'i commit'lenene kadar bekler (yarissiz).
    Best-effort: broker erisilemezse sessizce gec (beat fallback zaten var)."""
    try:
        celery_app.send_task("scheduler.generate_patrol_windows", countdown=3)
    except Exception:
        pass


async def _ensure_shift_in_tenant(db: AsyncSession, shift_id: uuid.UUID | None) -> None:
    if shift_id is None:
        return
    found = (
        await db.execute(select(Shift.id).where(Shift.id == shift_id))
    ).scalar_one_or_none()
    if found is None:
        raise APIError(422, "invalid_reference", "shift_bulunamadi")


async def _checkpoints_for(db: AsyncSession, plan_id: uuid.UUID) -> list[PatrolPlanCheckpoint]:
    return list(
        (
            await db.execute(
                select(PatrolPlanCheckpoint)
                .where(PatrolPlanCheckpoint.patrol_plan_id == plan_id)
                .order_by(PatrolPlanCheckpoint.sira)
            )
        ).scalars().all()
    )


# -------------------------------- CRUD ------------------------------------- #
@router.get("", response_model=PatrolPlanListResponse)
async def list_plans(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    aktif: bool | None = Query(None),
    shift_id: uuid.UUID | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> PatrolPlanListResponse:
    where = []
    if aktif is not None:
        where.append(PatrolPlan.aktif == aktif)
    if shift_id is not None:
        where.append(PatrolPlan.shift_id == shift_id)
    total = (
        await db.execute(select(func.count()).select_from(PatrolPlan).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(PatrolPlan).where(*where).order_by(PatrolPlan.created_at, PatrolPlan.id).limit(limit).offset(offset)
        )
    ).scalars().all()
    return PatrolPlanListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=list(rows),
    )


@router.get("/{plan_id}", response_model=PatrolPlanDetailOut)
async def get_plan(
    plan_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> PatrolPlanDetailOut:
    plan = await get_or_404(db, PatrolPlan, plan_id)
    checkpoints = await _checkpoints_for(db, plan_id)
    base = PatrolPlanOut.model_validate(plan).model_dump()
    return PatrolPlanDetailOut(
        **base,
        checkpoints=[PatrolPlanCheckpointOut.model_validate(c) for c in checkpoints],
    )


def _ek_tarih_dogrula(
    ek_tarihler: list[dt.date] | None,
    onceki_ek: list[dt.date] | None = None,
) -> None:
    """(E2E 2026-09 / GUVENLIK-17) GECMIS EK GUN REDDEDILIR.

    OLCULEN: `2020-01-01` gibi gecmis bir ek gun 201 ile kabul ediliyordu
    — hicbir zaman yurumeyecek bir gun, yonetici ise plani "o gun de
    calisiyor" sanir.

    YAPILMAYAN (bilincli): `periyot_dakika` > plan suresi ("hic pencere
    uretmeyen sessiz plan") burada REDDEDILMEDI. `tests/test_me_patrol.py`
    bu bosluga BILEREK yaslaniyor (pencereleri elle ekleyebilmek icin
    1440 dk periyotlu 6 saatlik plan) ve alternatifi (pasif plan) ayni
    turda degisen pasif-plan temizligine (scheduler/service.py) takilir.
    Karar scheduler sahibinde.

    GECMIS = UTC bugunden ONCEKI gun (1 gun pay): tenant saat dilimini
    okumak icin ek sorgu yerine; Turkiye (UTC+3) gece yarisindan sonraki
    uc saatte "bugun"u yanlislikla reddetmemek icin pay birakildi.
    Guncellemede YALNIZ YENI eklenen tarihler olculur: istemci listeyi
    butun olarak geri gonderir ve dun gecerli olan bir tarih bugun
    gecmistir — onu reddetmek plani duzenlenemez kilardi.
    """
    if ek_tarihler:
        esik = dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=1)
        eski = set(onceki_ek or [])
        for gun in ek_tarihler:
            if gun < esik and gun not in eski:
                raise APIError(
                    422, "validation_error", "devriye_ek_tarih_gecmis",
                    tarih=gun.isoformat(),
                )


@router.post("", response_model=PatrolPlanOut, status_code=201)
async def create_plan(
    body: PatrolPlanCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> PatrolPlan:
    await _ensure_shift_in_tenant(db, body.shift_id)
    _ek_tarih_dogrula(body.ek_tarihler)
    obj = PatrolPlan(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    _regen_windows()
    return obj


@router.patch("/{plan_id}", response_model=PatrolPlanOut)
async def update_plan(
    plan_id: uuid.UUID,
    body: PatrolPlanUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_WRITER),
) -> PatrolPlan:
    obj = await get_or_404(db, PatrolPlan, plan_id)
    data = body.model_dump(exclude_unset=True)
    if "shift_id" in data:
        await _ensure_shift_in_tenant(db, data["shift_id"])
    # (E2E 2026-09 / GUVENLIK-17) Yalniz YENI eklenen ek gunler olculur.
    if data.get("ek_tarihler"):
        _ek_tarih_dogrula(data["ek_tarihler"], list(obj.ek_tarihler or []))
    for key, value in data.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    _regen_windows()
    return obj


@router.delete("/{plan_id}", status_code=204)
async def delete_plan(
    plan_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_WRITER),
) -> Response:
    obj = await get_or_404(db, PatrolPlan, plan_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)


# ------------------------- checkpoint atama -------------------------------- #
@router.get("/{plan_id}/checkpoints", response_model=list[PatrolPlanCheckpointOut])
async def list_plan_checkpoints(
    plan_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> list[PatrolPlanCheckpoint]:
    await get_or_404(db, PatrolPlan, plan_id)  # 404 (yoksa / baska tenant)
    return await _checkpoints_for(db, plan_id)


@router.put("/{plan_id}/checkpoints", response_model=list[PatrolPlanCheckpointOut])
async def assign_plan_checkpoints(
    plan_id: uuid.UUID,
    body: PatrolPlanCheckpointAssign,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> list[PatrolPlanCheckpoint]:
    await get_or_404(db, PatrolPlan, plan_id)

    # 1) tum checkpoint'ler bu tenant'ta mi? (capraz-tenant -> 422)
    await ensure_checkpoints_in_tenant(db, [it.checkpoint_id for it in body.items])

    # 2) sira ata (verilmeyen -> dizi index'i) ve benzersizligi dogrula
    rows = []
    seen_sira: set[int] = set()
    seen_cp: set[uuid.UUID] = set()
    for idx, item in enumerate(body.items):
        sira = item.sira if item.sira is not None else idx
        if sira in seen_sira:
            raise APIError(
                422, "validation_error", "plan_tekrar_eden_sira", sira=sira
            )
        if item.checkpoint_id in seen_cp:
            raise APIError(
                422,
                "validation_error",
                "plan_tekrar_eden_checkpoint",
                checkpoint=item.checkpoint_id,
            )
        seen_sira.add(sira)
        seen_cp.add(item.checkpoint_id)
        rows.append((item.checkpoint_id, sira))

    # 3) replace: mevcut atamalari sil, yenilerini ekle
    await db.execute(
        delete(PatrolPlanCheckpoint).where(PatrolPlanCheckpoint.patrol_plan_id == plan_id)
    )
    await db.flush()
    for checkpoint_id, sira in rows:
        db.add(
            PatrolPlanCheckpoint(
                tenant_id=user.tenant_id,
                patrol_plan_id=plan_id,
                checkpoint_id=checkpoint_id,
                sira=sira,
            )
        )
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)

    _regen_windows()
    return await _checkpoints_for(db, plan_id)
