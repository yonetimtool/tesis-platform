"""Ortak alan rezervasyonu — sakin talep eder, yonetici onaylar/reddeder.

Akis (urun sahibi sabit):
  1. Yonetici ortak alanlari tanimlar (bkz. common_areas.py).
  2. Sakin talep acar: alan + tarih + saat araligi + kisi sayisi (+not);
     daire kimliginden turetilir. durum=bekliyor + yonetime push.
  3. CAKISMA ENGELI: ayni alanin ONAYLI rezervasyonuyla kesisen YENI TALEP
     daha talep aninda 409 ile reddedilir (bosuna beklemesin). BEKLEYEN
     talepler ust uste binebilir (karar yonetimde) — yalniz BIRI onaylanabilir.
  4. Onay ATOMIK: DB'deki partial EXCLUDE kisiti (migration 9z5 —
     btree_gist, tsrange &&, WHERE durum='onaylandi') onaya kaldirma
     UPDATE'inde devreye girer; es zamanli iki cakisan onaydan yalniz biri
     basarir, digeri 23P01 -> 409 (yaris durumu DB'de cozulur, uygulama
     kontrolune guvenilmez). Bitisik slotlar (bitis == diger.baslangic)
     cakisma SAYILMAZ (tsrange '[)').
  5. Push: talep -> yonetim (admin+yonetici); karar -> talebi acan sakin.
  6. Tam gecmis: alan, tarih/saat, daire, kisi, durum, talep eden, karar veren.

RBAC (auth.md §4): TALEP yalniz resident (yonetim talep ACMAZ — karar veren
taraf; complaints kanal deseni). KARAR yalniz admin+yonetici; zaten karar
verilmis kayda ikinci karar 409. OKUMA yonetim tenant'in tumu; resident
YALNIZ kendi dairelerinin rezervasyonlari (es de gorur — daire bazli);
security/tesis_gorevlisi ERISMEZ (403) — rezervasyon sakin<->yonetim akisi.
"""
from __future__ import annotations

import uuid
from datetime import date as date_type

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from ..crud_helpers import is_exclusion_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, OrtakAlan, Rezervasyon, Unit, UnitResident
from ..scheduler.notify import dispatch_external
from ..schemas import (
    RezervasyonCreate,
    RezervasyonDurum,
    RezervasyonListResponse,
    RezervasyonOut,
    RezervasyonUpdate,
)

router = APIRouter(prefix="/reservations", tags=["rezervasyon"])

# TALEP yalniz sakin: rezervasyon dairenin hakki; yonetim karar veren taraf.
_REQUESTER = require_role("resident")
# KARAR yalniz yonetim.
_MANAGER = require_role("admin", "yonetici")
# OKUMA: yonetim tumu; sakin kendi daireleri. Saha rolleri ERISMEZ (403).
_READER = require_role("admin", "yonetici", "resident")

# Yeni talep push'u YONETIME gider (complaints kanal deseni).
_MANAGEMENT_ROLES: tuple[str, ...] = ("admin", "yonetici")

_TALEP_EDEN = aliased(AppUser)
_ONAYLAYAN = aliased(AppUser)


def _out(row) -> RezervasyonOut:
    obj, alan_ad, unit_no, talep_eden_ad, onaylayan_ad = row
    out = RezervasyonOut.model_validate(obj)
    out.alan_ad = alan_ad
    out.unit_no = unit_no
    out.talep_eden_ad = talep_eden_ad
    out.onaylayan_ad = onaylayan_ad
    return out


def _base_stmt():
    """Liste/detay ortak SELECT'i: alan adi + daire no + kisi adlari join'li."""
    return (
        select(Rezervasyon, OrtakAlan.ad, Unit.no, _TALEP_EDEN.ad, _ONAYLAYAN.ad)
        .join(OrtakAlan, OrtakAlan.id == Rezervasyon.alan_id)
        .join(Unit, Unit.id == Rezervasyon.unit_id)
        .join(_TALEP_EDEN, _TALEP_EDEN.id == Rezervasyon.talep_eden_user_id)
        .outerjoin(_ONAYLAYAN, _ONAYLAYAN.id == Rezervasyon.onaylayan_user_id)
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
    """resident yalniz KENDI dairelerinin rezervasyonlarini gorur (es dahil —
    daire bazli); yonetim tenant'in tumunu (RLS zaten tenant'i daraltir)."""
    if user.role == "resident":
        return stmt.where(Rezervasyon.unit_id.in_(unit_ids or []))
    return stmt


def _cakisma_kosulu(alan_id: uuid.UUID, tarih, baslangic, bitis):
    """Ayni alanin ONAYLI rezervasyonlariyla kesisme: yari-acik aralik
    (baslangic < diger.bitis AND bitis > diger.baslangic) — DB'deki tsrange
    '[)' kisitiyla birebir ayni tanim (bitisik slot cakisma degil)."""
    return (
        (Rezervasyon.alan_id == alan_id)
        & (Rezervasyon.tarih == tarih)
        & (Rezervasyon.durum == "onaylandi")
        & (Rezervasyon.baslangic < bitis)
        & (Rezervasyon.bitis > baslangic)
    )


# ------------------------------- talep -------------------------------------- #
@router.post("", response_model=RezervasyonOut, status_code=201)
async def create_reservation(
    body: RezervasyonCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_REQUESTER),
) -> RezervasyonOut:
    alan = (
        await db.execute(select(OrtakAlan).where(OrtakAlan.id == body.alan_id))
    ).scalar_one_or_none()
    if alan is None or not alan.aktif:
        raise APIError(422, "invalid_reference", "Alan bulunamadi veya aktif degil.")

    # MUSAITLIK: talep edilen aralik alanin [acilis, kapanis] penceresinde
    # olmali (slot izgara hizasi UX isi; cakismasizligi EXCLUDE saglar).
    if body.baslangic < alan.acilis or body.bitis > alan.kapanis:
        raise APIError(
            422, "validation_error",
            "Secilen aralik alanin musaitlik saatleri (acilis-kapanis) disinda.",
        )

    # Daire: sakinin aktif dairelerinden; unit_id verildiyse KENDI dairesi
    # olmali (baska daire adina talep acilamaz), verilmediyse tek/ilk daire.
    unit_ids = await _aktif_daire_ids(db, user)
    if not unit_ids:
        raise APIError(422, "invalid_reference", "Aktif daire baglantiniz yok.")
    if body.unit_id is not None:
        if body.unit_id not in unit_ids:
            raise APIError(422, "invalid_reference", "unit_id kendi daireniz olmali.")
        unit_id = body.unit_id
    else:
        unit_id = unit_ids[0]

    # Talep aninda cakisma uyarisi/engeli: ONAYLI bir rezervasyonla kesisen
    # talep bosuna kuyruga girmesin — 409. (Bekleyenlerle kesisme SERBEST;
    # nihai guvence onay anindaki DB EXCLUDE kisiti.)
    onayli_cakisan = (
        await db.execute(
            select(Rezervasyon.id).where(
                _cakisma_kosulu(body.alan_id, body.tarih, body.baslangic, body.bitis)
            ).limit(1)
        )
    ).scalar_one_or_none()
    if onayli_cakisan is not None:
        raise APIError(
            409, "conflict",
            "Secilen aralik bu alanda onaylanmis bir rezervasyonla cakisiyor.",
        )

    obj = Rezervasyon(
        tenant_id=user.tenant_id,
        alan_id=body.alan_id,
        unit_id=unit_id,
        talep_eden_user_id=user.id,
        tarih=body.tarih,
        baslangic=body.baslangic,
        bitis=body.bitis,
        kisi_sayisi=body.kisi_sayisi,
        notlar=body.notlar,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)

    unit_no = (
        await db.execute(select(Unit.no).where(Unit.id == unit_id))
    ).scalar_one()
    # EK push: yeni talep yonetime bildirilir (hatasi kaydi kirmaz).
    dispatch_external(
        f"Rezervasyon talebi: {alan.ad} — {body.tarih.isoformat()} "
        f"{body.baslangic.strftime('%H:%M')}-{body.bitis.strftime('%H:%M')} ({unit_no})",
        tenant_id=user.tenant_id,
        target_roles=_MANAGEMENT_ROLES,
        title="Rezervasyon",
        data={"tip": "rezervasyon", "rezervasyon_id": str(obj.id)},
    )
    return _out((obj, alan.ad, unit_no, user.ad, None))


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=RezervasyonListResponse)
async def list_reservations(
    durum: RezervasyonDurum | None = Query(None),
    alan_id: uuid.UUID | None = Query(None),
    tarih: date_type | None = Query(None, description="Gun filtresi (YYYY-MM-DD)"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> RezervasyonListResponse:
    stmt = _base_stmt()
    if durum is not None:
        stmt = stmt.where(Rezervasyon.durum == durum)
    if alan_id is not None:
        stmt = stmt.where(Rezervasyon.alan_id == alan_id)
    if tarih is not None:
        stmt = stmt.where(Rezervasyon.tarih == tarih)
    unit_ids = await _aktif_daire_ids(db, user) if user.role == "resident" else None
    stmt = _scope(stmt, user, unit_ids)

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            stmt.order_by(Rezervasyon.created_at.desc()).limit(limit).offset(offset)
        )
    ).all()
    return RezervasyonListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(r) for r in rows],
    )


@router.get("/{reservation_id}", response_model=RezervasyonOut)
async def get_reservation(
    reservation_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> RezervasyonOut:
    unit_ids = await _aktif_daire_ids(db, user) if user.role == "resident" else None
    row = (
        await db.execute(
            _scope(_base_stmt().where(Rezervasyon.id == reservation_id), user, unit_ids)
        )
    ).first()
    if row is None:
        # Baska dairenin/tenant'in kaydi 404 — varligi da sizdirilmaz.
        raise APIError(404, "not_found", "Kayit bulunamadi")
    return _out(row)


# ------------------------------- karar -------------------------------------- #
@router.patch("/{reservation_id}", response_model=RezervasyonOut)
async def decide_reservation(
    reservation_id: uuid.UUID,
    body: RezervasyonUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> RezervasyonOut:
    row = (
        await db.execute(
            select(Rezervasyon, OrtakAlan.ad, Unit.no)
            .join(OrtakAlan, OrtakAlan.id == Rezervasyon.alan_id)
            .join(Unit, Unit.id == Rezervasyon.unit_id)
            .where(Rezervasyon.id == reservation_id)
        )
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    obj, alan_ad, unit_no = row

    # Tek karar: durum='bekliyor' kosullu atomik UPDATE. ONAY yolunda ayrica
    # DB EXCLUDE kisiti calisir — ayni alanin onayli rezervasyonuyla kesisen
    # onay 23P01 firlatir (es zamanli iki cakisan bekleyenden yalniz biri
    # onaylanabilir; yaris durumu DB'de cozulur).
    try:
        res = await db.execute(
            update(Rezervasyon)
            .where(Rezervasyon.id == reservation_id, Rezervasyon.durum == "bekliyor")
            .values(
                durum=body.durum,
                onaylayan_user_id=user.id,
                karar_zamani=func.now(),
            )
        )
    except IntegrityError as exc:
        if is_exclusion_violation(exc):
            raise APIError(
                409, "conflict",
                "Onaylanamadi: aralik bu alanda onaylanmis baska bir "
                "rezervasyonla cakisiyor.",
            )
        raise translate_integrity(exc)
    if res.rowcount == 0:
        raise APIError(409, "conflict", "Talep zaten karara baglanmis.")
    await db.refresh(obj)

    # EK push: karar YALNIZ talebi acan sakine gider (kisi hedefli).
    karar = "onaylandi" if body.durum == "onaylandi" else "reddedildi"
    dispatch_external(
        f"Rezervasyonunuz {karar}: {alan_ad} — {obj.tarih.isoformat()} "
        f"{obj.baslangic.strftime('%H:%M')}-{obj.bitis.strftime('%H:%M')}",
        tenant_id=user.tenant_id,
        target_user_ids=(obj.talep_eden_user_id,),
        title="Rezervasyon karari",
        data={"tip": "rezervasyon_karar", "rezervasyon_id": str(obj.id)},
    )

    talep_eden_ad = (
        await db.execute(
            select(AppUser.ad).where(AppUser.id == obj.talep_eden_user_id)
        )
    ).scalar_one_or_none()
    return _out((obj, alan_ad, unit_no, talep_eden_ad, user.ad))
