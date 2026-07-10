"""Ziyaretci onay akisi — guvenlik kaydeder, daire sakinleri onaylar/reddeder.

Akis (urun sahibi sabit):
  1. Guvenlik ziyaretciyi kaydeder (ad + daire + opsiyonel not) -> durum=bekliyor.
  2. Dairenin TUM aktif sakinlerine ayni anda push denenir (esler dahil).
  3. O dairenin bir sakini onaylar/reddeder — ILK yanit gecerli, ikinci 409.
  4. Sonuc (kim, ne zaman, onay/red) kaydi yapan guvenlige push + ekranda.
  5. Tam gecmis bu tabloda tutulur (ziyaretci, daire, zaman, durum, yanitlayan).

RBAC (auth.md §4): KAYIT yalniz security (kapi operasyonu — yonetici/admin
kaydetmez, gecmisi okur). YANIT yalniz O dairenin AKTIF sakini; baska dairenin
sakinine 404 (varlik sizdirilmaz — complaints deseni). OKUMA admin/yonetici/
security tenant'in tum gecmisi; resident YALNIZ kendi dairelerinin kayitlari;
tesis_gorevlisi ERISMEZ (403). Tenant token'dan; RLS izole.

Push'lar EK gonderimdir — hatasi ziyaretci kaydini/yanitini KIRMAZ
(duyuru/talep/acil durum ile ayni desen).

GSM'E HAZIR (simdi degil): yanit alanlari (yanitlayan_user_id + yanit_zamani)
kanaldan bagimsizdir; sakin telefonu zaten app_user.telefon'da. Gercek arama
(Twilio/Netgsm) eklenirken visitor_durum'a deger (orn. 'araniyor') + arama
meta'si eklenir — bu modelde yeniden tasarim gerekmez (bkz. migration notu).
"""
from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitResident, Visitor
from ..scheduler.notify import dispatch_external
from ..schemas import (
    VisitorCreate,
    VisitorDurum,
    VisitorListResponse,
    VisitorOut,
    VisitorUpdate,
)

router = APIRouter(prefix="/visitors", tags=["visitors"])

# KAYIT yalniz guvenlik: ziyaretci kapida karsilanir (yonetici/admin gecmisi
# okur ama kayit acmaz — kapi operasyonu; karar auth.md §4'te belirtildi).
_REGISTRAR = require_role("security")
# OKUMA: yonetim + guvenlik tum gecmis; sakin kendi dairesi (asagida daralir).
# tesis_gorevlisi ERISMEZ (403) — kapi/ziyaretci akisinin tarafi degil.
_READER = require_role("admin", "yonetici", "security", "resident")
# YANIT yalniz sakin (o dairenin aktif sakini oldugu ayrica dogrulanir).
_RESIDENT = require_role("resident")

_KAYDEDEN = aliased(AppUser)
_YANITLAYAN = aliased(AppUser)


def _out(row) -> VisitorOut:
    obj, unit_no, kaydeden_ad, yanitlayan_ad = row
    out = VisitorOut.model_validate(obj)
    out.unit_no = unit_no
    out.kaydeden_ad = kaydeden_ad
    out.yanitlayan_ad = yanitlayan_ad
    return out


def _base_stmt():
    """Liste/detay ortak SELECT'i: daire no + kaydeden/yanitlayan adlari join'li."""
    return (
        select(Visitor, Unit.no, _KAYDEDEN.ad, _YANITLAYAN.ad)
        .join(Unit, Unit.id == Visitor.unit_id)
        .join(_KAYDEDEN, _KAYDEDEN.id == Visitor.kaydeden_user_id)
        .outerjoin(_YANITLAYAN, _YANITLAYAN.id == Visitor.yanitlayan_user_id)
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
    """resident yalniz KENDI dairelerinin kayitlarini gorur; yonetim + guvenlik
    tenant'in tumunu (RLS zaten tenant'i daraltir)."""
    if user.role == "resident":
        # Aktif dairesi olmayan sakin hicbir kayit gormez (bos liste/404).
        return stmt.where(Visitor.unit_id.in_(unit_ids or []))
    return stmt


# ------------------------------- kayit -------------------------------------- #
@router.post("", response_model=VisitorOut, status_code=201)
async def create_visitor(
    body: VisitorCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_REGISTRAR),
) -> VisitorOut:
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
        raise APIError(422, "invalid_reference", "Daire bu tenant'ta bulunamadi.")

    obj = Visitor(
        tenant_id=user.tenant_id,
        unit_id=unit.id,
        ziyaretci_ad=body.ziyaretci_ad,
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
            f"Ziyaretci: {body.ziyaretci_ad} — {unit.no} kapida. Onayla/Reddet",
            tenant_id=user.tenant_id,
            target_user_ids=tuple(dict.fromkeys(sakinler)),
            title="Ziyaretci",
            data={"tip": "ziyaretci", "visitor_id": str(obj.id)},
        )
    return _out((obj, unit.no, user.ad, None))


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=VisitorListResponse)
async def list_visitors(
    durum: VisitorDurum | None = Query(None),
    unit_id: uuid.UUID | None = Query(None),
    baslangic: datetime | None = Query(None, description="created_at >= (tarih filtresi)"),
    bitis: datetime | None = Query(None, description="created_at < (tarih filtresi)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> VisitorListResponse:
    stmt = _base_stmt()
    if durum is not None:
        stmt = stmt.where(Visitor.durum == durum)
    if unit_id is not None:
        stmt = stmt.where(Visitor.unit_id == unit_id)
    if baslangic is not None:
        stmt = stmt.where(Visitor.created_at >= baslangic)
    if bitis is not None:
        stmt = stmt.where(Visitor.created_at < bitis)
    unit_ids = await _aktif_daire_ids(db, user) if user.role == "resident" else None
    stmt = _scope(stmt, user, unit_ids)

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            stmt.order_by(Visitor.created_at.desc()).limit(limit).offset(offset)
        )
    ).all()
    return VisitorListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r) for r in rows],
    )


@router.get("/{visitor_id}", response_model=VisitorOut)
async def get_visitor(
    visitor_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> VisitorOut:
    unit_ids = await _aktif_daire_ids(db, user) if user.role == "resident" else None
    row = (
        await db.execute(
            _scope(_base_stmt().where(Visitor.id == visitor_id), user, unit_ids)
        )
    ).first()
    if row is None:
        # Baska dairenin/tenant'in kaydi 404 — varligi da sizdirilmaz.
        raise APIError(404, "not_found", "Kayit bulunamadi")
    return _out(row)


# ------------------------------- yanit -------------------------------------- #
@router.patch("/{visitor_id}", response_model=VisitorOut)
async def answer_visitor(
    visitor_id: uuid.UUID,
    body: VisitorUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RESIDENT),
) -> VisitorOut:
    row = (
        await db.execute(
            select(Visitor, Unit.no)
            .join(Unit, Unit.id == Visitor.unit_id)
            .where(Visitor.id == visitor_id)
        )
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    obj, unit_no = row

    # Yalniz O dairenin AKTIF sakini yanitlar; digerine 404 (varlik sizdirilmaz,
    # ?unit_id= benzeri bir bypass yolu yok — sunucu tarafinda zorlanir).
    if obj.unit_id not in await _aktif_daire_ids(db, user):
        raise APIError(404, "not_found", "Kayit bulunamadi")

    # ILK yanit kazanir: durum='bekliyor' kosullu atomik UPDATE — es zamanli
    # ikinci yanit (esler ayni anda basarsa) satiri bulamaz ve 409 alir.
    res = await db.execute(
        update(Visitor)
        .where(Visitor.id == visitor_id, Visitor.durum == "bekliyor")
        .values(
            durum=body.durum,
            yanitlayan_user_id=user.id,
            yanit_zamani=func.now(),
        )
    )
    if res.rowcount == 0:
        raise APIError(
            409, "conflict", "Ziyaretci kaydi zaten yanitlanmis (ilk yanit gecerli)."
        )
    await db.refresh(obj)

    # EK push: sonuc YALNIZ kaydi acan guvenlige gider (kisi hedefli);
    # hatasi yanit kaydini kirmaz.
    sonuc = "onaylandi" if body.durum == "onaylandi" else "reddedildi"
    dispatch_external(
        f"{unit_no}: ziyaretci {obj.ziyaretci_ad} {sonuc} ({user.ad})",
        tenant_id=user.tenant_id,
        target_user_ids=(obj.kaydeden_user_id,),
        title="Ziyaretci sonucu",
        data={"tip": "ziyaretci_sonuc", "visitor_id": str(obj.id)},
    )

    kaydeden_ad = (
        await db.execute(select(AppUser.ad).where(AppUser.id == obj.kaydeden_user_id))
    ).scalar_one_or_none()
    return _out((obj, unit_no, kaydeden_ad, user.ad))
