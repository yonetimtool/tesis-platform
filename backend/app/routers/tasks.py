"""Task CRUD + tamamlama (completion) — /contracts/openapi.yaml.

RBAC (auth.md §4): GET admin/yonetici/security/tesis_gorevlisi — saha rolleri
kendi ROL GRUBUNA (security + tesis_gorevlisi) atanan + atanmamis gorevleri okur;
Task yazma (POST/PATCH/DELETE) admin/yonetici — yonetici yalniz
security/tesis_gorevlisi'ne atar; completion gonderme (POST)
admin/security/tesis_gorevlisi — saha rolu yalniz KENDINE atanan veya atanmamis
gorevi tamamlar (aksi 403). tenant token'dan; RLS izole.
Completion idempotency scan desenini yeniden kullanir (SAVEPOINT).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, Query, Response
from fastapi.responses import JSONResponse
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import coord_eq, get_or_404, is_unique_violation, nfc_eq, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Checkpoint, Task, TaskCategory, TaskCompletion
from ..schemas import (
    TaskCompletionCreate,
    TaskCompletionListResponse,
    TaskCompletionOut,
    TaskCreate,
    TaskListResponse,
    TaskOut,
    TaskUpdate,
)

router = APIRouter(prefix="/tasks", tags=["tasks"])

_WRITER = require_role("admin", "yonetici")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")
_COMPLETER = require_role("admin", "security", "tesis_gorevlisi")

# yonetici gorevleri yalniz saha rollerine atayabilir (auth.md §4).
_YONETICI_ATANABILIR = {"security", "tesis_gorevlisi"}

# Saha rolleri: 'Gorevlerim' kendi ROL GRUBUNA (guvenlik + tesis gorevlisi)
# atanan tum gorevleri OKUR; saha-disi kisiye (orn. admin) atanmis gorevler
# gorunmez. Tamamlama ayrica kisiye baglidir (bkz. create_completion).
_SAHA_ROLLERI = {"security", "tesis_gorevlisi"}


def _saha_atananlar_subq():
    """Ayni tenant'taki (RLS) saha rolu kullanici id'leri — grup gorunurlugu."""
    return select(AppUser.id).where(AppUser.role.in_(_SAHA_ROLLERI)).scalar_subquery()


def _assignee_visibility(user: AppUser):
    """Saha kullanicisi icin gorunurluk kosulu: atanmamis ('Herkes') VEYA
    rol grubundan birine (security/tesis_gorevlisi) atanmis. Yonetim
    (admin/yonetici) kisitsiz (None doner)."""
    if user.role in _SAHA_ROLLERI:
        return or_(
            Task.atanan_user_id.is_(None),
            Task.atanan_user_id.in_(_saha_atananlar_subq()),
        )
    return None


async def _visible_task_or_404(db: AsyncSession, task_id: uuid.UUID, user: AppUser) -> Task:
    """Task'i atanan-gorunurluk kurali altinda yukle; gorunmuyorsa 404
    (grup disina atanmis gorevin VARLIGI da sizdirilmaz)."""
    task = await get_or_404(db, Task, task_id)
    if (
        user.role in _SAHA_ROLLERI
        and task.atanan_user_id not in (None, user.id)
    ):
        atanan_rol = (
            await db.execute(
                select(AppUser.role).where(AppUser.id == task.atanan_user_id)
            )
        ).scalar_one_or_none()
        if atanan_rol not in _SAHA_ROLLERI:
            raise APIError(404, "not_found", "Kayit bulunamadi")
    return task


async def _ensure_user_in_tenant(
    db: AsyncSession, user_id: uuid.UUID | None, actor: AppUser
) -> None:
    if user_id is None:
        return
    target_role = (
        await db.execute(select(AppUser.role).where(AppUser.id == user_id))
    ).scalar_one_or_none()
    if target_role is None:
        raise APIError(422, "invalid_reference", "atanan_user_id bu tenant'ta bulunamadi.")
    if actor.role == "yonetici" and target_role not in _YONETICI_ATANABILIR:
        raise APIError(
            422, "invalid_reference",
            "yonetici gorevi yalniz security/tesis_gorevlisi kullanicilara atayabilir.",
        )


async def _ensure_kategori_in_tenant(db: AsyncSession, kategori_id: uuid.UUID | None) -> None:
    """Kategori ayni tenant'ta (RLS) ve AKTIF olmali; pasif kategoriye yeni
    gorev yazilamaz (soft-delete sozlesmesi, A6)."""
    if kategori_id is None:
        return
    aktif = (
        await db.execute(select(TaskCategory.aktif).where(TaskCategory.id == kategori_id))
    ).scalar_one_or_none()
    if aktif is None:
        raise APIError(422, "invalid_reference", "kategori_id bu tenant'ta bulunamadi.")
    if not aktif:
        raise APIError(
            422, "invalid_reference",
            "Pasif kategoriye gorev yazilamaz (kategori silinmis).",
        )


async def _ensure_checkpoint_in_tenant(db: AsyncSession, checkpoint_id: uuid.UUID | None) -> None:
    if checkpoint_id is None:
        return
    found = (
        await db.execute(select(Checkpoint.id).where(Checkpoint.id == checkpoint_id))
    ).scalar_one_or_none()
    if found is None:
        raise APIError(422, "invalid_reference", "checkpoint_id bu tenant'ta bulunamadi.")


# -------------------------------- CRUD ------------------------------------- #
@router.get("", response_model=TaskListResponse)
async def list_tasks(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    kategori_id: str | None = Query(
        None, description="kategori UUID veya 'diger' (kategorisiz/Diğer)"
    ),
    aktif: bool | None = Query(None),
    atanan_user_id: str | None = Query(
        None, description="'me' (token kullanicisi) veya user UUID — atanan filtresi (mobil §11)"
    ),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> TaskListResponse:
    where = []
    # Saha rolu: baskasina atanmis gorevler listede HIC gorunmez; sonraki
    # atanan_user_id filtresi bu kosulla KESISIR (bypass edilemez).
    visibility = _assignee_visibility(user)
    if visibility is not None:
        where.append(visibility)
    if kategori_id is not None:
        if kategori_id == "diger":
            where.append(Task.kategori_id.is_(None))
        else:
            try:
                where.append(Task.kategori_id == uuid.UUID(kategori_id))
            except ValueError:
                raise APIError(
                    422, "validation_error", "kategori_id UUID veya 'diger' olmali."
                )
    if aktif is not None:
        where.append(Task.aktif == aktif)
    if atanan_user_id is not None:
        if atanan_user_id == "me":
            target = user.id
        else:
            try:
                target = uuid.UUID(atanan_user_id)
            except ValueError:
                raise APIError(422, "validation_error", "atanan_user_id 'me' veya UUID olmali.")
        where.append(Task.atanan_user_id == target)
    total = (await db.execute(select(func.count()).select_from(Task).where(*where))).scalar_one()
    rows = (
        await db.execute(
            select(Task).where(*where).order_by(Task.created_at).limit(limit).offset(offset)
        )
    ).scalars().all()
    return TaskListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=list(rows))


@router.get("/{task_id}", response_model=TaskOut)
async def get_task(
    task_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> Task:
    return await _visible_task_or_404(db, task_id, user)


@router.post("", response_model=TaskOut, status_code=201)
async def create_task(
    body: TaskCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Task:
    await _ensure_user_in_tenant(db, body.atanan_user_id, user)
    await _ensure_checkpoint_in_tenant(db, body.checkpoint_id)
    await _ensure_kategori_in_tenant(db, body.kategori_id)
    obj = Task(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.patch("/{task_id}", response_model=TaskOut)
async def update_task(
    task_id: uuid.UUID,
    body: TaskUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Task:
    obj = await get_or_404(db, Task, task_id)
    data = body.model_dump(exclude_unset=True)
    if "atanan_user_id" in data:
        await _ensure_user_in_tenant(db, data["atanan_user_id"], user)
    if "checkpoint_id" in data:
        await _ensure_checkpoint_in_tenant(db, data["checkpoint_id"])
    if "kategori_id" in data:
        await _ensure_kategori_in_tenant(db, data["kategori_id"])
    for key, value in data.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.delete("/{task_id}", status_code=204)
async def delete_task(
    task_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_WRITER),
) -> Response:
    obj = await get_or_404(db, Task, task_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)


# ----------------------------- completions --------------------------------- #
@router.get("/{task_id}/completions", response_model=TaskCompletionListResponse)
async def list_completions(
    task_id: uuid.UUID,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> TaskCompletionListResponse:
    # 404: yoksa / baska tenant / baskasina atanmis (saha rolu icin).
    await _visible_task_or_404(db, task_id, user)
    base = TaskCompletion.task_id == task_id
    total = (
        await db.execute(select(func.count()).select_from(TaskCompletion).where(base))
    ).scalar_one()
    rows = (
        await db.execute(
            select(TaskCompletion)
            .where(base)
            .order_by(TaskCompletion.tamamlanma_zamani.desc())
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    return TaskCompletionListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=list(rows)
    )


def _same_completion(existing: TaskCompletion, **v) -> bool:
    return (
        existing.task_id == v["task_id"]
        and existing.tamamlayan_user_id == v["tamamlayan_user_id"]
        and existing.tamamlanma_zamani == v["tamamlanma_zamani"]
        and existing.nfc_tag_uid == v["nfc_tag_uid"]
        and coord_eq(existing.gps_lat, v["gps_lat"])
        and coord_eq(existing.gps_lng, v["gps_lng"])
        and existing.foto_key == v["foto_key"]
        and existing.notlar == v["notlar"]
    )


@router.post("/{task_id}/completions")
async def create_completion(
    task_id: uuid.UUID,
    body: TaskCompletionCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_COMPLETER),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "Idempotency-Key header zorunlu.")

    # Gorunurluk: grup disi / baska tenant -> 404 (varlik sizdirilmaz).
    task = await _visible_task_or_404(db, task_id, user)

    # Tamamlama BYPASS-PROOF: saha kullanicisi yalniz KENDINE atanan veya
    # atanmamis (havuz) gorevi tamamlar; grubun baska uyesine atanmis gorev
    # okunur ama tamamlanamaz -> 403.
    if user.role in _SAHA_ROLLERI and task.atanan_user_id not in (None, user.id):
        raise APIError(
            403, "forbidden", "Bu gorevi yalniz atanan kullanici tamamlayabilir."
        )

    # Foto kaniti: gorev foto_zorunlu ise foto_key olmadan tamamlanamaz (mobil §11 #2).
    if task.foto_zorunlu and body.foto_key is None:
        raise APIError(
            422, "validation_error",
            "Bu gorev icin foto kaniti zorunlu — once /uploads/presign ile yukleyip foto_key gonderin.",
        )

    # NFC kaniti: task'in checkpoint'i varsa ve nfc gonderildiyse eslesmeli
    # (normalize karsilastirma — mobil §11 #3).
    if body.nfc_tag_uid is not None and task.checkpoint_id is not None:
        cp = (
            await db.execute(select(Checkpoint).where(Checkpoint.id == task.checkpoint_id))
        ).scalar_one_or_none()
        if cp is None or not nfc_eq(cp.nfc_tag_uid, body.nfc_tag_uid):
            raise APIError(422, "invalid_reference", "nfc_tag_uid gorevin checkpoint'i ile eslesmiyor.")

    zaman = body.tamamlanma_zamani
    if zaman.tzinfo is None:
        zaman = zaman.replace(tzinfo=timezone.utc)

    fields = dict(
        task_id=task_id,
        tamamlayan_user_id=user.id,
        tamamlanma_zamani=zaman,
        nfc_tag_uid=body.nfc_tag_uid,
        gps_lat=body.gps_lat,
        gps_lng=body.gps_lng,
        foto_key=body.foto_key,
        notlar=body.notlar,
    )
    obj = TaskCompletion(tenant_id=user.tenant_id, idempotency_key=idempotency_key, **fields)

    created = True
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        if not is_unique_violation(exc):
            raise translate_integrity(exc)
        created = False
        try:
            db.expunge(obj)
        except Exception:
            pass

    if created:
        # Periyodik gorev (peyzaj dahil) tamamlaninca bir sonraki planlanan tarihi ilerlet.
        if task.periyot_dakika and task.sonraki_planlanan is not None:
            task.sonraki_planlanan = task.sonraki_planlanan + timedelta(
                minutes=task.periyot_dakika
            )
            await db.flush()
        await db.refresh(obj)
        return JSONResponse(
            status_code=201, content=TaskCompletionOut.model_validate(obj).model_dump(mode="json")
        )

    existing = (
        await db.execute(
            select(TaskCompletion).where(TaskCompletion.idempotency_key == idempotency_key)
        )
    ).scalar_one()
    if _same_completion(existing, **fields):
        return JSONResponse(
            status_code=200, content=TaskCompletionOut.model_validate(existing).model_dump(mode="json")
        )
    raise APIError(409, "conflict", "Ayni Idempotency-Key farkli govde ile gonderildi.")
