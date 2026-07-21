"""Talep/Ariza — sakin/saha -> yonetim, uctan uca is-emri kanali (auth.md §4).

Durum makinesi: acik -> is_emri (donustur) -> cozuldu (+ reddedildi). ASCII
wire, TR etiket UI'da. Her gecis history satiri + acana push. Talepler her
zaman kimlikli (anonimlik /unit-complaints'te). Kategori = dinamik task_category.

RBAC: ACMA security + tesis_gorevlisi + resident; OKUMA bes rol ama acan roller
YALNIZ kendi actiklarini; convert/resolve/decline yalniz admin+yonetici.

Gorseller: /uploads/presign ile alinan foto_key'ler (<=3), tenant-namespace
dogrulamali; okumada kisa omurlu presigned GET doner.
"""
from __future__ import annotations

import uuid
from collections.abc import Sequence

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    Complaint,
    ComplaintPhoto,
    ComplaintStatusHistory,
    Task,
    TaskCategory,
    TaskCompletion,
)
from ..scheduler.notify import dispatch_external
from ..schemas import (
    ComplaintConvertRequest,
    ComplaintCreate,
    ComplaintDeclineRequest,
    ComplaintDurum,
    ComplaintListResponse,
    ComplaintOut,
    ComplaintPhotoOut,
    ComplaintResolveRequest,
    ComplaintStatusHistoryOut,
)
from ..storage import presign_get
from ..ticketing import add_history, assert_transition, notify_opener

router = APIRouter(prefix="/complaints", tags=["complaints"])

# ACMA: saha rolleri + sakin (talebi YASAYAN acar). yonetici ACAMAZ —
# kanalin cevaplayan tarafi; admin de acmaz (platform operatoru).
_OPENER = require_role("security", "tesis_gorevlisi", "resident")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
_MANAGER = require_role("admin", "yonetici")

# Kendi-kaydi kapsamindaki roller (yonetim DISI): yalniz actiklarini gorur.
_OWN_SCOPED_ROLES = ("security", "tesis_gorevlisi", "resident")
# Yeni talep push'u YONETIME gider (kanal sakin/saha->yonetim).
_MANAGEMENT_ROLES: tuple[str, ...] = ("admin", "yonetici")
# Is emri yalniz sahaya atanir.
_ATANABILIR_ROLLER = {"security", "tesis_gorevlisi"}

_PUSH_TITLE = "Talep/Ariza"


def _validate_foto_key(foto_key: str, tenant_id: uuid.UUID) -> None:
    """foto_key kendi tenant namespace'inde olmali (make_foto_key oneki).

    Okumada bu anahtara presigned GET imzalanir — dogrulanmazsa baska
    tenant'in objesi talep gorseli diye sizdirilabilir (IDOR).
    """
    if not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key tenant alani disinda")


def _sign(key: str) -> str | None:
    try:
        return presign_get(key)
    except APIError:
        # Depo yapilandirilmamissa okuma akisi kirilmasin; foto_url bos kalir.
        return None


async def _build_outs(
    db: AsyncSession, rows: Sequence[tuple[Complaint, str | None]]
) -> list[ComplaintOut]:
    """(Complaint, acan_ad) satirlarini fotolar + timeline + is emri ile serialize eder.

    Satir basina degil, TOPLU sorgu (id IN (...)) — liste ucunda N+1 olmasin.
    """
    outs: list[ComplaintOut] = []
    by_id: dict[uuid.UUID, ComplaintOut] = {}
    for obj, acan_ad in rows:
        out = ComplaintOut.model_validate(obj)
        out.acan_ad = acan_ad
        outs.append(out)
        by_id[obj.id] = out
    if not outs:
        return outs
    ids = list(by_id)

    # kategori adlari
    kategori_ids = {o.kategori_id for o in outs if o.kategori_id is not None}
    if kategori_ids:
        adlar = dict(
            (
                await db.execute(
                    select(TaskCategory.id, TaskCategory.ad).where(
                        TaskCategory.id.in_(kategori_ids)
                    )
                )
            ).all()
        )
        for out in outs:
            if out.kategori_id is not None:
                out.kategori_ad = adlar.get(out.kategori_id)

    # fotolar
    photos = (
        await db.execute(
            select(ComplaintPhoto)
            .where(ComplaintPhoto.complaint_id.in_(ids))
            .order_by(ComplaintPhoto.sira)
        )
    ).scalars().all()
    for p in photos:
        by_id[p.complaint_id].fotograflar.append(
            ComplaintPhotoOut(
                id=p.id, foto_key=p.foto_key, sira=p.sira, foto_url=_sign(p.foto_key)
            )
        )

    # gecmis (timeline)
    hist = (
        await db.execute(
            select(ComplaintStatusHistory)
            .where(ComplaintStatusHistory.complaint_id.in_(ids))
            .order_by(ComplaintStatusHistory.created_at)
        )
    ).scalars().all()
    for h in hist:
        by_id[h.complaint_id].gecmis.append(
            ComplaintStatusHistoryOut.model_validate(h)
        )

    # bagli is emri + tamamlanma durumu
    tasks = (
        await db.execute(
            select(Task.id, Task.ticket_id)
            .where(Task.ticket_id.in_(ids))
            .order_by(Task.created_at)
        )
    ).all()
    if tasks:
        tamamlanan = set(
            (
                await db.execute(
                    select(TaskCompletion.task_id)
                    .where(TaskCompletion.task_id.in_([t_id for t_id, _ in tasks]))
                    .distinct()
                )
            ).scalars().all()
        )
        for task_id, ticket_id in tasks:
            out = by_id[ticket_id]
            if out.is_emri_id is not None:
                continue  # ilk (en eski) is emri ozeti
            out.is_emri_id = task_id
            out.is_emri_durum = "tamamlandi" if task_id in tamamlanan else "acik"
    return outs


async def _load_out(
    db: AsyncSession, obj: Complaint, acan_ad: str | None
) -> ComplaintOut:
    return (await _build_outs(db, [(obj, acan_ad)]))[0]


def _own_scope(stmt, user: AppUser):
    """Acan roller (saha + sakin) yalniz KENDI actiklarini gorur;
    yonetim (admin+yonetici) tum tenant'i."""
    if user.role in _OWN_SCOPED_ROLES:
        return stmt.where(Complaint.acan_user_id == user.id)
    return stmt


async def _get_or_404(
    db: AsyncSession, complaint_id: uuid.UUID, user: AppUser
) -> tuple[Complaint, str | None]:
    row = (
        await db.execute(
            _own_scope(
                select(Complaint, AppUser.ad)
                .join(AppUser, AppUser.id == Complaint.acan_user_id)
                .where(Complaint.id == complaint_id),
                user,
            )
        )
    ).first()
    if row is None:
        # Baskasinin talebi acan role 404 — varligi da sizdirilmaz.
        raise APIError(404, "not_found", "Kayit bulunamadi")
    return row[0], row[1]


@router.get("", response_model=ComplaintListResponse)
async def list_complaints(
    durum: ComplaintDurum | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> ComplaintListResponse:
    stmt = select(Complaint, AppUser.ad).join(
        AppUser, AppUser.id == Complaint.acan_user_id
    )
    if durum is not None:
        stmt = stmt.where(Complaint.durum == durum)
    stmt = _own_scope(stmt, user)

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            stmt.order_by(Complaint.created_at.desc()).limit(limit).offset(offset)
        )
    ).all()
    items = await _build_outs(db, [(c, ad) for c, ad in rows])
    return ComplaintListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=items
    )


@router.get("/{complaint_id}", response_model=ComplaintOut)
async def get_complaint(
    complaint_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> ComplaintOut:
    obj, acan_ad = await _get_or_404(db, complaint_id, user)
    return await _load_out(db, obj, acan_ad)


@router.post("", response_model=ComplaintOut, status_code=201)
async def create_complaint(
    body: ComplaintCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OPENER),
) -> ComplaintOut:
    for k in body.foto_keys:
        _validate_foto_key(k, user.tenant_id)
    obj = Complaint(
        tenant_id=user.tenant_id,
        acan_user_id=user.id,
        baslik=body.baslik,
        mesaj=body.mesaj,
        kategori_id=body.kategori_id,
    )
    db.add(obj)
    try:
        await db.flush()
        for i, k in enumerate(body.foto_keys):
            db.add(
                ComplaintPhoto(
                    tenant_id=user.tenant_id, complaint_id=obj.id, foto_key=k, sira=i
                )
            )
        add_history(db, complaint=obj, durum="acik", actor_role=user.role, sebep=None)
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # EK push: yeni talep yonetime bildirilir (hatasi talep kaydini kirmaz).
    dispatch_external(
        f"Yeni talep: {body.baslik}",
        tenant_id=user.tenant_id,
        target_roles=_MANAGEMENT_ROLES,
        title=_PUSH_TITLE,
        data={"tip": "talep", "complaint_id": str(obj.id)},
    )
    return await _load_out(db, obj, user.ad)


@router.post("/{complaint_id}/convert", response_model=ComplaintOut)
async def convert_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintConvertRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> ComplaintOut:
    obj, acan_ad = await _get_or_404(db, complaint_id, user)
    assert_transition(obj.durum, "is_emri")
    # Atanan ayni tenant (RLS) + saha rolu olmali.
    atanan = (
        await db.execute(select(AppUser).where(AppUser.id == body.atanan_user_id))
    ).scalar_one_or_none()
    if atanan is None or atanan.role not in _ATANABILIR_ROLLER:
        raise APIError(422, "invalid_assignee", "atanan security/tesis_gorevlisi olmali")
    task = Task(
        tenant_id=user.tenant_id,
        ad=obj.baslik,
        aciklama=obj.mesaj,
        atanan_user_id=body.atanan_user_id,
        kategori_id=body.kategori_id if body.kategori_id is not None else obj.kategori_id,
        oncelik=body.oncelik,
        ticket_id=obj.id,
        foto_zorunlu=False,
    )
    db.add(task)
    obj.durum = "is_emri"
    obj.updated_at = func.now()
    add_history(
        db, complaint=obj, durum="is_emri", actor_role=user.role, sebep=body.not_
    )
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    notify_opener(
        complaint=obj,
        tenant_id=user.tenant_id,
        tip="talep_is_emri",
        mesaj=f"Talebiniz is emrine donusturuldu: {obj.baslik}",
    )
    # EK push: is emri atanan saha personeline.
    dispatch_external(
        f"Yeni is emri: {obj.baslik}",
        tenant_id=user.tenant_id,
        target_user_ids=(body.atanan_user_id,),
        title="Is Emri",
        data={
            "tip": "is_emri_atandi",
            "task_id": str(task.id),
            "complaint_id": str(obj.id),
        },
    )
    return await _load_out(db, obj, acan_ad)


async def _close(
    db: AsyncSession,
    user: AppUser,
    obj: Complaint,
    *,
    durum: str,
    sebep: str | None,
) -> None:
    """cozuldu/reddedildi ortak kapanis: gecis kontrolu + history + flush."""
    assert_transition(obj.durum, durum)
    obj.durum = durum
    obj.updated_at = func.now()
    add_history(db, complaint=obj, durum=durum, actor_role=user.role, sebep=sebep)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)


@router.post("/{complaint_id}/resolve", response_model=ComplaintOut)
async def resolve_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintResolveRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> ComplaintOut:
    obj, acan_ad = await _get_or_404(db, complaint_id, user)
    await _close(db, user, obj, durum="cozuldu", sebep=body.cozum_notu)
    notify_opener(
        complaint=obj,
        tenant_id=user.tenant_id,
        tip="talep_cozuldu",
        mesaj=f"Talebiniz cozuldu: {obj.baslik}",
    )
    return await _load_out(db, obj, acan_ad)


@router.post("/{complaint_id}/decline", response_model=ComplaintOut)
async def decline_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintDeclineRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> ComplaintOut:
    obj, acan_ad = await _get_or_404(db, complaint_id, user)
    await _close(db, user, obj, durum="reddedildi", sebep=body.sebep)
    notify_opener(
        complaint=obj,
        tenant_id=user.tenant_id,
        tip="talep_reddedildi",
        mesaj=f"Talebiniz reddedildi: {obj.baslik}",
    )
    return await _load_out(db, obj, acan_ad)
