"""Ziyaretci LOG kaydi — guvenlik kaydeder, hedef sakine BILGILENDIRME push'u.

Akis (LOG-ONLY — onay/red YOKTUR):
  1. Guvenlik ziyaretciyi kaydeder (ad + daire + opsiyonel not + HEDEF sakin).
  2. Secilen hedef sakine tek bir BILGILENDIRME push'u denenir
     ("Ziyaretciniz kaydedildi: X"). Sakin bir sey ONAYLAMAZ.
  3. Kayit bir gunluk (log) girisi olarak kalir; tam gecmis bu tabloda tutulur.

RBAC (auth.md §4): KAYIT yalniz security (kapi operasyonu — yonetici/admin
kaydetmez, izinle okur). OKUMA admin/yonetici/security tenant'in tum gecmisi
(yonetim VARSAYILAN KAPALI — tek-seferlik izinle acilir); resident YALNIZ
kendine HEDEFLENEN kayitlar; tesis_gorevlisi ERISMEZ (403). Tenant token'dan;
RLS izole.

Push EK gonderimdir — hatasi ziyaretci kaydini KIRMAZ (duyuru/talep deseni).

GSM'E HAZIR (simdi degil): hedef sakinin telefonu app_user.telefon'da; gercek
arama (Twilio/Netgsm) eklenirken ayri kolon/tablo yeter — bu modelde yeniden
tasarim gerekmez (bkz. migration notu).
"""
from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitResident, Visitor
from ..permissions import try_consume_unit_permission
from ..scheduler.notify import dispatch_external
from ..schemas import (
    VisitorCreate,
    VisitorListResponse,
    VisitorOut,
    VisitorUpdate,
)

router = APIRouter(prefix="/visitors", tags=["visitors"])

# KAYIT yalniz guvenlik: ziyaretci kapida karsilanir (yonetici/admin gecmisi
# okur ama kayit acmaz — kapi operasyonu; auth.md §4).
_REGISTRAR = require_role("security")
# OKUMA rol kapisi: security TUM gecmis (kapi ops/vardiya devri); resident
# kendi HEDEFLENEN kayitlari; admin VE yonetici VARSAYILAN KAPALI — yalniz
# tek-seferlik izinli daire (handler'da 403/izin tuketimi; KVKK — platform
# operatoru dahil kimse varsayilan olarak sakinin ozel verisini gormez).
# tesis_gorevlisi ERISMEZ (403).
_READER = require_role("admin", "yonetici", "security", "resident")
# Varsayilan kapali roller (izinle acilir): admin + yonetici.
_IZIN_GEREKEN = {"admin", "yonetici"}

_KAYDEDEN = aliased(AppUser)
_TARGET = aliased(AppUser)


def _out(row) -> VisitorOut:
    obj, unit_no, kaydeden_ad, target_ad = row
    out = VisitorOut.model_validate(obj)
    out.unit_no = unit_no
    out.kaydeden_ad = kaydeden_ad
    out.target_resident_ad = target_ad
    return out


def _base_stmt():
    """Liste/detay ortak SELECT'i: daire no + kaydeden/hedef adlari."""
    return (
        select(Visitor, Unit.no, _KAYDEDEN.ad, _TARGET.ad)
        .join(Unit, Unit.id == Visitor.unit_id)
        .join(_KAYDEDEN, _KAYDEDEN.id == Visitor.kaydeden_user_id)
        .join(_TARGET, _TARGET.id == Visitor.target_resident_user_id)
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
    """resident YALNIZ KENDINE HEDEFLENEN kayitlari gorur (tek hedef modeli, A);
    aktif dairesi olmayan/hedefsiz hicbirini gormez. admin + security tenant'in
    tumunu (RLS zaten tenant'i daraltir); yonetici bu fonksiyona ulasmadan once
    handler'da izinle daraltilir."""
    if user.role == "resident":
        return stmt.where(
            Visitor.target_resident_user_id == user.id,
            Visitor.unit_id.in_(unit_ids or []),
        )
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

    # Hedef sakin O dairenin AKTIF sakini olmali (guvenlik hangi sakine
    # bildirilecegini secer; degilse 422 — baska daireye/role sizmaz).
    target_ad = (
        await db.execute(
            select(AppUser.ad)
            .join(
                UnitResident,
                (UnitResident.user_id == AppUser.id)
                & (UnitResident.unit_id == unit.id)
                & (UnitResident.bitis.is_(None)),
            )
            .where(AppUser.id == body.target_resident_user_id)
        )
    ).scalar_one_or_none()
    if target_ad is None:
        raise APIError(
            422, "invalid_reference",
            "target_resident_user_id bu dairenin aktif sakini degil.",
        )

    obj = Visitor(
        tenant_id=user.tenant_id,
        unit_id=unit.id,
        ziyaretci_ad=body.ziyaretci_ad,
        notlar=body.notlar,
        kaydeden_user_id=user.id,
        target_resident_user_id=body.target_resident_user_id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)

    # EK push: BILGILENDIRME — YALNIZ secilen hedef sakine (kisi hedefli;
    # dairenin diger sakinlerine/tenant'a sizmaz). Onay/red istenmez; hatasi
    # kaydi kirmaz.
    dispatch_external(
        f"Ziyaretciniz kaydedildi: {body.ziyaretci_ad} — {unit.no}",
        tenant_id=user.tenant_id,
        target_user_ids=(body.target_resident_user_id,),
        title="Ziyaretci",
        data={"tip": "ziyaretci", "visitor_id": str(obj.id)},
    )
    return _out((obj, unit.no, user.ad, target_ad))


# ------------------------------- duzenleme ---------------------------------- #
@router.patch("/{visitor_id}", response_model=VisitorOut)
async def update_visitor(
    visitor_id: uuid.UUID,
    body: VisitorUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_REGISTRAR),
) -> VisitorOut:
    """Guvenlik ziyaretci kaydini duzenler (ad/not/hedef sakin/daire). Yalniz
    guvenlik (kapida karsilar, vardiya devrinde de duzeltir). RLS ile kendi
    tenant'inda; kayit yoksa 404. Daire VEYA hedef degisirse hedef, (nihai)
    dairenin AKTIF sakini olarak yeniden dogrulanir (degilse 422)."""
    obj = (
        await db.execute(select(Visitor).where(Visitor.id == visitor_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")

    fields = body.model_fields_set

    # Nihai daireyi coz: yeni referans verildiyse (unit_id|unit_no), yoksa mevcut.
    unit_id = obj.unit_id
    if "unit_id" in fields or "unit_no" in fields:
        if body.unit_id is not None:
            unit = (
                await db.execute(select(Unit).where(Unit.id == body.unit_id))
            ).scalar_one_or_none()
        elif body.unit_no is not None:
            unit = (
                await db.execute(select(Unit).where(Unit.no == body.unit_no))
            ).scalar_one_or_none()
        else:
            unit = None
        if unit is None:
            raise APIError(422, "invalid_reference", "Daire bu tenant'ta bulunamadi.")
        unit_id = unit.id

    # Nihai hedef sakin: yeni verildiyse o, yoksa mevcut.
    target_id = (
        body.target_resident_user_id
        if "target_resident_user_id" in fields
        else obj.target_resident_user_id
    )

    # Daire VEYA hedef degistiyse hedefi (nihai) dairenin AKTIF sakini olarak
    # yeniden dogrula — baska daireye/role sizmasin (create ile ayni kural).
    if unit_id != obj.unit_id or target_id != obj.target_resident_user_id:
        ok = (
            await db.execute(
                select(AppUser.id)
                .join(
                    UnitResident,
                    (UnitResident.user_id == AppUser.id)
                    & (UnitResident.unit_id == unit_id)
                    & (UnitResident.bitis.is_(None)),
                )
                .where(AppUser.id == target_id)
            )
        ).scalar_one_or_none()
        if ok is None:
            raise APIError(
                422, "invalid_reference",
                "target_resident_user_id bu dairenin aktif sakini degil.",
            )

    obj.unit_id = unit_id
    obj.target_resident_user_id = target_id
    if "ziyaretci_ad" in fields and body.ziyaretci_ad is not None:
        obj.ziyaretci_ad = body.ziyaretci_ad
    if "notlar" in fields:  # acikca null -> temizle
        obj.notlar = body.notlar
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)

    row = (
        await db.execute(_base_stmt().where(Visitor.id == visitor_id))
    ).first()
    return _out(row)


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=VisitorListResponse)
async def list_visitors(
    unit_id: uuid.UUID | None = Query(None),
    baslangic: datetime | None = Query(None, description="created_at >= (tarih filtresi)"),
    bitis: datetime | None = Query(None, description="created_at < (tarih filtresi)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> VisitorListResponse:
    # admin + yonetici VARSAYILAN KAPALI: yalniz tek-seferlik izinli daireyi
    # gorur. unit_id zorunlu; gecerli kullanilmamis izin TUKETILIR (one-shot),
    # yoksa 403. Gizlilik (KVKK): kayit yalniz hedef sakin + izinli yonetim +
    # kaydeden guvenlik.
    if user.role in _IZIN_GEREKEN:
        if unit_id is None:
            raise APIError(
                403, "forbidden",
                "Ziyaretci kayitlari yonetime kapali; bir daire icin "
                "tek-seferlik izin alin (unit_id gerekli).",
            )
        if not await try_consume_unit_permission(db, unit_id, user.id):
            raise APIError(
                403, "forbidden",
                "Bu daire icin gecerli (kullanilmamis) goruntuleme izniniz yok.",
            )

    stmt = _base_stmt()
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
    # admin + yonetici: kaydin dairesine tek-seferlik izin gerektirir
    # (varsayilan kapali). Izin yoksa/tukendiyse 403 — kaydin varligini da
    # sizdirmaz.
    if user.role in _IZIN_GEREKEN:
        v_unit = (
            await db.execute(select(Visitor.unit_id).where(Visitor.id == visitor_id))
        ).scalar_one_or_none()
        if v_unit is None or not await try_consume_unit_permission(
            db, v_unit, user.id
        ):
            raise APIError(
                403, "forbidden",
                "Bu kayit yonetime kapali; daire icin tek-seferlik izin alin.",
            )

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
