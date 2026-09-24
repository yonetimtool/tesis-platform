"""Kargo/paket takibi — guvenlik kaydeder, dairenin sakini teslim alir.

Akis (urun sahibi sabit):
  1. Guvenlik gelen paketi kaydeder (daire + firma + opsiyonel foto/not)
     -> durum=bekliyor. Foto MEVCUT presign akisiyla yuklenir (yeni upload yok).
  2. Dairenin TUM aktif sakinlerine push denenir ("Kargonuz geldi — <firma>").
  3. Sakin "teslim aldim" isaretler YA DA guvenlik "teslim ettim" isaretler
     (P247 §3): bekliyor -> teslim_alindi (atomik; zaten teslim alinmis kayda
     ikinci isaret 409 — kimin aldigi/verdigi degismez).
  4. Tam gecmis: daire, firma, foto, durum, kaydeden, teslim alan, zamanlar.

RBAC (auth.md §4, visitor ile ayni desen): KAYIT yalniz security (kapi
operasyonu). TESLIM: O dairenin AKTIF sakini (baska dairenin sakinine 404 —
varlik sizdirilmaz) VEYA security (P247 §3 — paketi kapida fiilen veren o). OKUMA admin/yonetici/security tenant'in tum gecmisi;
resident YALNIZ kendi dairelerinin paketleri; tesis_gorevlisi ERISMEZ (403).

Push kayitta; teslimde YALNIZ guvenlik teslim ettiginde (P247 §3 —
sakin kendi isaretlediginde geri-push yok, zaten biliyor). EK gonderimdir —
hatasi kargo kaydini KIRMAZ. Foto okumada kisa omurlu presigned GET foto_url
doner; foto_key tenant-namespace dogrulanir (IDOR korumasi, complaints deseni).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..sakin_bildirimi import sakin_bildirimi_yaz
from ..audit import Action, audit_user
from ..config import settings
from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Kargo, Unit, UnitResident
from ..permissions import try_consume_unit_permission
from ..scheduler.notify import dispatch_external
from ..schemas import (
    KargoCreate,
    KargoDurum,
    KargoListResponse,
    KargoOut,
    KargoUpdate,
)
from ..storage import presign_get

router = APIRouter(prefix="/kargo", tags=["kargo"])

# KAYIT yalniz guvenlik: paket kapida teslim alinir (visitor ile ayni karar —
# yonetici/admin gecmisi okur ama kayit acmaz; auth.md §4).
_REGISTRAR = require_role("security")
# OKUMA rol kapisi: security TUM gecmis; sakin kendi dairesi (asagida daralir);
# admin VE yonetici VARSAYILAN KAPALI — yalniz tek-seferlik izinli daire
# (handler'da 403/izin tuketimi; ziyaretci ile ayni gizlilik/KVKK).
# tesis_gorevlisi ERISMEZ (403).
_READER = require_role("admin", "yonetici", "security", "resident")
# Varsayilan kapali roller (izinle acilir): admin + yonetici.
_IZIN_GEREKEN = {"admin", "yonetici"}
# (P247 §3) TESLIM: sakin (o dairenin aktif sakini oldugu ayrica dogrulanir)
# VEYA guvenlik. Once yalniz sakindi ve olculen kusur buydu: paketi kapida
# fiilen sakine VEREN guvenlik isaretleyemiyordu (403); sakin uygulamada
# "teslim aldim"a basmazsa (ya da uygulamasi yoksa) kayit sonsuza dek
# `bekliyor` kaliyordu. Amir/yonetim teslim ISARETLEMEZ: paketi elinde
# tutan kapidaki gorevlidir.
_TESLIM = require_role("resident", "security")

_KAYDEDEN = aliased(AppUser)
_TESLIM_ALAN = aliased(AppUser)
_TESLIM_EDEN = aliased(AppUser)


def _gecikme_esigi() -> datetime:
    """(P247 §3) Bu andan ONCE kaydedilmis ve hala `bekliyor` olan kargo
    "gecikmis"tir. Durum DEGISTIRILMEZ — paket fiziksel olarak kapida
    duruyor; otomatik "teslim edildi" yazmak yalan olurdu. Yalniz listede
    isaretlenir ki guvenlik sakini arasin."""
    return datetime.now(timezone.utc) - timedelta(days=settings.kargo_gecikme_gun)


def _validate_foto_key(foto_key: str | None, tenant_id: uuid.UUID) -> None:
    """foto_key kendi tenant namespace'inde olmali (complaints ile ayni IDOR
    korumasi) — dogrulanmazsa baska tenant'in objesine presigned GET
    imzalanabilirdi."""
    if foto_key is not None and not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key_alan_disi")


def _out(row) -> KargoOut:
    obj, unit_no, kaydeden_ad, teslim_alan_ad, teslim_eden_ad = row
    out = KargoOut.model_validate(obj)
    out.unit_no = unit_no
    out.kaydeden_ad = kaydeden_ad
    out.teslim_alan_ad = teslim_alan_ad
    out.teslim_eden_ad = teslim_eden_ad
    out.gecikmis = obj.durum == "bekliyor" and obj.created_at < _gecikme_esigi()
    if obj.foto_key:
        try:
            out.foto_url = presign_get(obj.foto_key)
        except APIError:
            # Depo yapilandirilmamissa okuma akisi kirilmasin; foto_url bos kalir.
            out.foto_url = None
    return out


def _base_stmt():
    """Liste/detay ortak SELECT'i: daire no + kaydeden/teslim alan adlari join'li."""
    return (
        select(Kargo, Unit.no, _KAYDEDEN.ad, _TESLIM_ALAN.ad, _TESLIM_EDEN.ad)
        .join(Unit, Unit.id == Kargo.unit_id)
        .join(_KAYDEDEN, _KAYDEDEN.id == Kargo.kaydeden_user_id)
        .outerjoin(_TESLIM_ALAN, _TESLIM_ALAN.id == Kargo.teslim_alan_user_id)
        .outerjoin(_TESLIM_EDEN, _TESLIM_EDEN.id == Kargo.teslim_eden_user_id)
    )


async def _aktif_daire_ids(db: AsyncSession, user: AppUser) -> list[uuid.UUID]:
    """Sakinin AKTIF (bitis IS NULL) daire baglantilari."""
    return list(
        (
            await db.execute(
                select(UnitResident.unit_id).where(
                    UnitResident.user_id == user.id, UnitResident.bitis.is_(None)
                )
            )
        ).scalars().all()
    )


def _scope(stmt, user: AppUser, unit_ids: list[uuid.UUID] | None):
    """resident yalniz KENDI dairelerinin paketlerini gorur; yonetim + guvenlik
    tenant'in tumunu (RLS zaten tenant'i daraltir)."""
    if user.role == "resident":
        # Aktif dairesi olmayan sakin hicbir kayit gormez (bos liste/404).
        return stmt.where(Kargo.unit_id.in_(unit_ids or []))
    return stmt


# ------------------------------- kayit -------------------------------------- #
@router.post("", response_model=KargoOut, status_code=201)
async def create_kargo(
    body: KargoCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_REGISTRAR),
) -> KargoOut:
    _validate_foto_key(body.foto_key, user.tenant_id)
    # Daireyi coz: unit_id veya unit_no (tam biri — sema dogrular). RLS ile
    # sorgu kendi tenant'inda kalir; bulunamazsa 422 invalid_reference.
    if body.unit_id is not None:
        unit = (
            await db.execute(select(Unit).where(Unit.id == body.unit_id))
        ).scalar_one_or_none()
    else:
        unit = (
            await db.execute(select(Unit).where(Unit.no == body.unit_no))
        ).scalar_one_or_none()
    if unit is None:
        raise APIError(422, "invalid_reference", "daire_bulunamadi")

    obj = Kargo(
        tenant_id=user.tenant_id,
        unit_id=unit.id,
        firma=body.firma,
        foto_key=body.foto_key,
        notlar=body.notlar,
        kaydeden_user_id=user.id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)

    # EK push: dairenin TUM aktif sakinlerine ayni anda (esler dahil, kisi
    # hedefli — tenant'taki diger sakinlere sizmaz); hatasi kaydi kirmaz.
    sakinler = (
        await db.execute(
            select(UnitResident.user_id).where(
                UnitResident.unit_id == unit.id, UnitResident.bitis.is_(None)
            )
        )
    ).scalars().all()
    if sakinler:
        dispatch_external(
            "kargo",
            tenant_id=user.tenant_id,
            target_user_ids=tuple(dict.fromkeys(sakinler)),
            params={"firma": body.firma, "daire": unit.no},
            data={"tip": "kargo", "kargo_id": str(obj.id)},
        )
        # (P147) Anlik push'un KALICI ikizi: bildirimi kaciran sakin olayi
        # Bildirimler sayfasinda bulur.
        sakin_bildirimi_yaz(
            db,
            tenant_id=user.tenant_id,
            tip="kargo",
            user_ids=sakinler,
            veri={"firma": body.firma, "daire": unit.no},
        )
    await audit_user(
        db, user, Action.KARGO_CREATE, resource_type="kargo",
        resource_id=obj.id, meta={"unit_id": str(obj.unit_id), "has_photo": bool(obj.foto_key)},
    )
    return _out((obj, unit.no, user.ad, None, None))


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=KargoListResponse)
async def list_kargo(
    durum: KargoDurum | None = Query(None),
    gecikmis: bool | None = Query(
        None,
        description="(P247 §3) true: bekliyor ve KARGO_GECIKME_GUN'den eski",
    ),
    unit_id: uuid.UUID | None = Query(None),
    baslangic: datetime | None = Query(None, description="created_at >= (tarih filtresi)"),
    bitis: datetime | None = Query(None, description="created_at < (tarih filtresi)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> KargoListResponse:
    # admin + yonetici VARSAYILAN KAPALI: unit_id + tek-seferlik izin gerekir
    # (one-shot tuketim), yoksa 403. Ziyaretci ile ayni gizlilik deseni.
    if user.role in _IZIN_GEREKEN:
        if unit_id is None:
            raise APIError(403, "forbidden", "kargo_yonetime_kapali")
        if not await try_consume_unit_permission(db, unit_id, user.id):
            raise APIError(403, "forbidden", "goruntuleme_izni_yok")

    stmt = _base_stmt()
    if durum is not None:
        stmt = stmt.where(Kargo.durum == durum)
    if gecikmis is True:
        stmt = stmt.where(
            Kargo.durum == "bekliyor", Kargo.created_at < _gecikme_esigi()
        )
    if unit_id is not None:
        stmt = stmt.where(Kargo.unit_id == unit_id)
    if baslangic is not None:
        stmt = stmt.where(Kargo.created_at >= baslangic)
    if bitis is not None:
        stmt = stmt.where(Kargo.created_at < bitis)
    unit_ids = await _aktif_daire_ids(db, user) if user.role == "resident" else None
    stmt = _scope(stmt, user, unit_ids)

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            stmt.order_by(Kargo.created_at.desc(), Kargo.id.desc()).limit(limit).offset(offset)
        )
    ).all()
    return KargoListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r) for r in rows],
    )


@router.get("/{kargo_id}", response_model=KargoOut)
async def get_kargo(
    kargo_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> KargoOut:
    # admin + yonetici: kaydin dairesine tek-seferlik izin gerektirir
    # (varsayilan kapali). Izin yoksa/tukendiyse 403 — varligini da sizdirmaz.
    if user.role in _IZIN_GEREKEN:
        k_unit = (
            await db.execute(select(Kargo.unit_id).where(Kargo.id == kargo_id))
        ).scalar_one_or_none()
        if k_unit is None or not await try_consume_unit_permission(
            db, k_unit, user.id
        ):
            raise APIError(403, "forbidden", "kayit_yonetime_kapali")

    unit_ids = await _aktif_daire_ids(db, user) if user.role == "resident" else None
    row = (
        await db.execute(
            _scope(_base_stmt().where(Kargo.id == kargo_id), user, unit_ids)
        )
    ).first()
    if row is None:
        # Baska dairenin/tenant'in kaydi 404 — varligi da sizdirilmaz.
        raise APIError(404, "not_found", "kayit_bulunamadi")
    # KVKK: foto presign-GET ifsasi — YALNIZ tekil detayda (liste degil), fotolu ise.
    if row[0].foto_key:
        await audit_user(
            db, user, Action.KARGO_PHOTO_VIEW, resource_type="kargo",
            resource_id=row[0].id, meta={"unit_id": str(row[0].unit_id)},
        )
    return _out(row)


# ------------------------------- teslim ------------------------------------- #
@router.patch("/{kargo_id}", response_model=KargoOut)
async def receive_kargo(
    kargo_id: uuid.UUID,
    body: KargoUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_TESLIM),
) -> KargoOut:
    row = (
        await db.execute(
            select(Kargo, Unit.no)
            .join(Unit, Unit.id == Kargo.unit_id)
            .where(Kargo.id == kargo_id)
        )
    ).first()
    if row is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    obj, unit_no = row

    guvenlik = user.role == "security"
    if guvenlik:
        # (P247 §3) Guvenlik "teslim ettim": paketi KIME verdigini
        # istege bagli belirtir; belirtirse o kisi dairenin AKTIF sakini
        # olmali (baska daireye/role imza atilmaz — ziyaretci hedefiyle ayni
        # kural). Belirtmezse teslim alan bos kalir; teslim EDEN damgalanir.
        teslim_alan = body.teslim_alan_user_id
        if teslim_alan is not None:
            ok = (
                await db.execute(
                    select(UnitResident.user_id).where(
                        UnitResident.unit_id == obj.unit_id,
                        UnitResident.user_id == teslim_alan,
                        UnitResident.bitis.is_(None),
                    )
                )
            ).first()
            if ok is None:
                raise APIError(422, "invalid_reference", "hedef_sakin_daire_disi")
        teslim_eden = user.id
    else:
        # Yalniz O dairenin AKTIF sakini teslim alir; digerine 404 (varlik
        # sizdirilmaz — sunucu tarafinda zorlanir, bypass yolu yok).
        if obj.unit_id not in await _aktif_daire_ids(db, user):
            raise APIError(404, "not_found", "kayit_bulunamadi")
        # Sakin baskasi adina imza atamaz: alan verilir ve kendisi degilse 422.
        if body.teslim_alan_user_id not in (None, user.id):
            raise APIError(422, "invalid_reference", "hedef_sakin_daire_disi")
        teslim_alan = user.id
        teslim_eden = None

    # Atomik teslim: durum='bekliyor' kosullu UPDATE — es zamanli ikinci
    # isaret (esler ayni anda bassa, ya da guvenlik ile sakin ayni anda
    # bassa bile) satiri bulamaz ve 409 alir; KIMIN teslim aldigi degismez.
    res = await db.execute(
        update(Kargo)
        .where(Kargo.id == kargo_id, Kargo.durum == "bekliyor")
        .values(
            durum=body.durum,
            teslim_alan_user_id=teslim_alan,
            teslim_eden_user_id=teslim_eden,
            teslim_zamani=func.now(),
        )
    )
    if res.rowcount == 0:
        raise APIError(409, "conflict", "kargo_zaten_teslim_alinmis")
    await db.refresh(obj)

    if guvenlik:
        # (P247 §3) Guvenlik teslim ettiyse dairenin TUM aktif sakinleri
        # bilgilenir: paketi kimin aldigini (es mi, komsu mu) ve "benim
        # paketim neden teslim edildi gorunuyor" sorusunu sakin kendisi
        # gorebilsin. Sakin KENDISI isaretlediginde push yok (zaten biliyor).
        sakinler = (
            await db.execute(
                select(UnitResident.user_id).where(
                    UnitResident.unit_id == obj.unit_id, UnitResident.bitis.is_(None)
                )
            )
        ).scalars().all()
        if sakinler:
            veri = {"firma": obj.firma, "daire": unit_no}
            dispatch_external(
                "kargo_teslim",
                tenant_id=user.tenant_id,
                target_user_ids=tuple(dict.fromkeys(sakinler)),
                params=veri,
                data={"tip": "kargo_teslim", "kargo_id": str(obj.id)},
            )
            sakin_bildirimi_yaz(
                db, tenant_id=user.tenant_id, tip="kargo_teslim",
                user_ids=sakinler, veri=veri,
            )

    row = (await db.execute(_base_stmt().where(Kargo.id == kargo_id))).first()
    await audit_user(
        db, user, Action.KARGO_RECEIVE, resource_type="kargo",
        resource_id=obj.id,
        meta={"unit_id": str(obj.unit_id), "guvenlik_teslim": guvenlik},
    )
    return _out(row)
