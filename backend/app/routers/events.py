"""Etkinlik + RSVP — yonetici duyurur, sakinler katilim beyan eder.

Akis (urun sahibi sabit):
  1. Yonetici etkinlik olusturur (baslik + aciklama + tarih + opsiyonel konum;
     orn. cenaze, mac izleme).
  2. TUM SAKINLERE push denenir ("Yeni etkinlik: ...") — hedef kitle sakinler
     (etkinlik site topluluguna yonelik; personel push almaz ama OKUR — karar
     auth.md §4'te belirtildi).
  3. Sakin RSVP verir: katiliyorum | katilmiyorum. Kullanici basina TEK kayit
     (UNIQUE) — tekrar PUT ile DEGISTIRILIR (ON CONFLICT upsert; cift kayit
     imkansiz, es zamanli PUT'lar da guvenli).
  4. SAYILAR SEFFAF: katiliyorum/katilmiyorum sayilarini TUM roller gorur.
     Kim-katiliyor listesi URUN GEREGI paylasilmaz — kimlik degil yalniz sayi
     (benim_durumum yalniz istekteki kullanicinin KENDI beyanidir).

RBAC (auth.md §4): OLUSTUR/DUZENLE/SIL admin+yonetici (duyuru deseni).
OKUMA TUM roller (sayilar dahil — seffaflik). RSVP YALNIZ resident —
etkinligin muhatabi sakinlerdir; personel katilim beyani vermez (karar).
Tenant token'dan; RLS izole. Push EK gonderimdir — hatasi kaydi kirmaz.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import case, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Etkinlik, EtkinlikKatilim
from ..scheduler.notify import dispatch_external
from ..schemas import (
    EtkinlikCreate,
    EtkinlikListResponse,
    EtkinlikOut,
    EtkinlikRsvp,
    EtkinlikUpdate,
)

router = APIRouter(prefix="/events", tags=["etkinlik"])

# Etkinligi site yonetimi duyurur (duyuru/announcement deseni).
_MANAGER = require_role("admin", "yonetici")
# Okuma + seffaf sayilar TUM roller.
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
# RSVP yalniz sakin: etkinligin muhatabi site sakinleri (karar auth.md §4).
_RSVP = require_role("resident")

# Yeni etkinlik push'u SAKINLERE gider (hedef kitle).
_AUDIENCE_ROLES: tuple[str, ...] = ("resident",)


def _out(obj: Etkinlik, olusturan_ad, katiliyor, katilmiyor, benim) -> EtkinlikOut:
    out = EtkinlikOut.model_validate(obj)
    out.olusturan_ad = olusturan_ad
    out.katiliyorum_sayisi = int(katiliyor or 0)
    out.katilmiyorum_sayisi = int(katilmiyor or 0)
    out.benim_durumum = benim
    return out


def _base_stmt(user: AppUser):
    """Liste/detay ortak SELECT'i: olusturan adi + SEFFAF sayilar (agregat) +
    istekteki kullanicinin kendi RSVP'si. Kimlikler donmez — yalniz sayi."""
    sayilar = (
        select(
            EtkinlikKatilim.etkinlik_id.label("eid"),
            func.count(
                case((EtkinlikKatilim.durum == "katiliyorum", 1))
            ).label("katiliyor"),
            func.count(
                case((EtkinlikKatilim.durum == "katilmiyorum", 1))
            ).label("katilmiyor"),
        )
        .group_by(EtkinlikKatilim.etkinlik_id)
        .subquery()
    )
    benim = (
        select(
            EtkinlikKatilim.etkinlik_id.label("eid"),
            EtkinlikKatilim.durum.label("durum"),
        )
        .where(EtkinlikKatilim.user_id == user.id)
        .subquery()
    )
    return (
        select(
            Etkinlik,
            AppUser.ad,
            sayilar.c.katiliyor,
            sayilar.c.katilmiyor,
            benim.c.durum,
        )
        .join(AppUser, AppUser.id == Etkinlik.olusturan_user_id)
        .outerjoin(sayilar, sayilar.c.eid == Etkinlik.id)
        .outerjoin(benim, benim.c.eid == Etkinlik.id)
    )


async def _load_out(db: AsyncSession, user: AppUser, etkinlik_id: uuid.UUID) -> EtkinlikOut:
    row = (
        await db.execute(_base_stmt(user).where(Etkinlik.id == etkinlik_id))
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    return _out(*row)


# ------------------------------- yonetim ------------------------------------ #
@router.post("", response_model=EtkinlikOut, status_code=201)
async def create_event(
    body: EtkinlikCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> EtkinlikOut:
    obj = Etkinlik(
        tenant_id=user.tenant_id,
        baslik=body.baslik,
        aciklama=body.aciklama,
        tarih=body.tarih,
        konum=body.konum,
        olusturan_user_id=user.id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # EK push: tum sakinlerin cihazlarina duyurulur (hatasi kaydi kirmaz).
    dispatch_external(
        f"Yeni etkinlik: {body.baslik} — {body.tarih.strftime('%d.%m.%Y %H:%M')}",
        tenant_id=user.tenant_id,
        target_roles=_AUDIENCE_ROLES,
        title="Etkinlik",
        data={"tip": "etkinlik", "etkinlik_id": str(obj.id)},
    )
    return _out(obj, user.ad, 0, 0, None)


@router.patch("/{event_id}", response_model=EtkinlikOut)
async def update_event(
    event_id: uuid.UUID,
    body: EtkinlikUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> EtkinlikOut:
    obj = (
        await db.execute(select(Etkinlik).where(Etkinlik.id == event_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return await _load_out(db, user, event_id)


@router.delete("/{event_id}", status_code=204)
async def delete_event(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    obj = (
        await db.execute(select(Etkinlik).where(Etkinlik.id == event_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    # RSVP'ler FK CASCADE ile silinir.
    await db.delete(obj)
    await db.flush()
    return Response(status_code=204)


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=EtkinlikListResponse)
async def list_events(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> EtkinlikListResponse:
    total = (
        await db.execute(select(func.count()).select_from(Etkinlik))
    ).scalar_one()
    rows = (
        await db.execute(
            # Etkinlik zamanina gore DESC: en yeni/yaklasan onde; istemci
            # yaklasan/gecmis ayrimini tarih'e gore yapar.
            _base_stmt(user).order_by(Etkinlik.tarih.desc()).limit(limit).offset(offset)
        )
    ).all()
    return EtkinlikListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(*r) for r in rows],
    )


@router.get("/{event_id}", response_model=EtkinlikOut)
async def get_event(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> EtkinlikOut:
    return await _load_out(db, user, event_id)


# -------------------------------- RSVP -------------------------------------- #
@router.put("/{event_id}/rsvp", response_model=EtkinlikOut)
async def rsvp_event(
    event_id: uuid.UUID,
    body: EtkinlikRsvp,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RSVP),
) -> EtkinlikOut:
    exists = (
        await db.execute(select(Etkinlik.id).where(Etkinlik.id == event_id))
    ).scalar_one_or_none()
    if exists is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")

    # Upsert: kullanici basina TEK kayit — ON CONFLICT ile atomik; es zamanli
    # iki PUT'ta da cift kayit olusamaz, son beyan gecerli olur.
    stmt = pg_insert(EtkinlikKatilim).values(
        tenant_id=user.tenant_id,
        etkinlik_id=event_id,
        user_id=user.id,
        durum=body.durum,
    ).on_conflict_do_update(
        constraint="uq_katilim_tenant_etkinlik_user",
        set_={"durum": body.durum, "updated_at": func.now()},
    )
    try:
        await db.execute(stmt)
    except IntegrityError as exc:
        raise translate_integrity(exc)
    # Guncel seffaf sayilar + kendi beyaniyla etkinligi don (UI aninda gorur).
    return await _load_out(db, user, event_id)
