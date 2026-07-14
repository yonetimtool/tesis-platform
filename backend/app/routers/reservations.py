"""Ortak alan rezervasyonu — sakin BOS slotu ANINDA rezerve eder (onay YOK).

Akis (urun sahibi sabit):
  1. Yonetici ortak alanlari tanimlar (bkz. common_areas.py).
  2. Sakin bos bir slotu rezerve eder: alan + tarih + saat araligi + kisi (+not);
     daire kimliginden turetilir. ONAY YOK — talep dogrudan durum='onaylandi'.
  3. CAKISMA ENGELI: ayni alanin ONAYLI rezervasyonuyla kesisen slot alinamaz.
     Nihai guvence INSERT anindaki DB EXCLUDE kisiti (migration 9z5 — btree_gist,
     tsrange &&, WHERE durum='onaylandi'): es zamanli iki cakisan talepten yalniz
     biri basarir, digeri 23P01 -> 409. Bitisik slotlar (bitis == diger.baslangic)
     cakisma SAYILMAZ (tsrange '[)').
  4. ZAMANLAMA (app/reservations_timing.py — slot baslangicina gore, tenant tz):
       (a) 24s penceresi: slota <24s kala rezerve edilebilir (erken -> 422).
       (b) gunde bir: sakin, slot-gunune denk 1 aktif rezervasyon tutar (2. -> 409).
       (c) son dakika: <10 dk kala BOS slot gunluk kotayi baypas eder.
  5. Iptal: sakin KENDI rezervasyonunu, yonetim herhangi birini iptal eder
     (durum='iptal'); slot bosalir (EXCLUDE disi). Push: rezerve edene onay
     bildirimi (kendi cihazi); iptalde ek push yok.

RBAC (auth.md §4): REZERVE ETME yalniz resident. IPTAL: rezerve eden sakin
(kendi) + admin+yonetici. OKUMA yonetim tenant'in tumu; resident YALNIZ kendi
dairelerinin rezervasyonlari (es de gorur — daire bazli); security/tesis_gorevlisi
ERISMEZ (403) — rezervasyon sakin<->yonetim alani.
"""
from __future__ import annotations

import uuid
from datetime import date as date_type

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from .. import reservations_timing as rtiming
from ..crud_helpers import is_exclusion_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, OrtakAlan, Rezervasyon, Tenant, Unit, UnitResident
from ..scheduler.notify import dispatch_external
from ..schemas import (
    RezervasyonCreate,
    RezervasyonDurum,
    RezervasyonListResponse,
    RezervasyonOut,
)

router = APIRouter(prefix="/reservations", tags=["rezervasyon"])

# REZERVE ETME yalniz sakin: ortak alan dairenin hakki.
_REQUESTER = require_role("resident")
# IPTAL: rezerve eden sakin (kendi) + yonetim.
_CANCELLER = require_role("resident", "admin", "yonetici")
# OKUMA: yonetim tumu; sakin kendi daireleri. Saha rolleri ERISMEZ (403).
_READER = require_role("admin", "yonetici", "resident")

_TALEP_EDEN = aliased(AppUser)
_IPTAL_EDEN = aliased(AppUser)


def _out(row) -> RezervasyonOut:
    obj, alan_ad, unit_no, talep_eden_ad, iptal_eden_ad = row
    out = RezervasyonOut.model_validate(obj)
    out.alan_ad = alan_ad
    out.unit_no = unit_no
    out.talep_eden_ad = talep_eden_ad
    out.iptal_eden_ad = iptal_eden_ad
    return out


def _base_stmt():
    """Liste/detay ortak SELECT'i: alan adi + daire no + kisi adlari join'li."""
    return (
        select(Rezervasyon, OrtakAlan.ad, Unit.no, _TALEP_EDEN.ad, _IPTAL_EDEN.ad)
        .join(OrtakAlan, OrtakAlan.id == Rezervasyon.alan_id)
        .join(Unit, Unit.id == Rezervasyon.unit_id)
        .join(_TALEP_EDEN, _TALEP_EDEN.id == Rezervasyon.talep_eden_user_id)
        .outerjoin(_IPTAL_EDEN, _IPTAL_EDEN.id == Rezervasyon.iptal_eden_user_id)
    )


async def _tenant_tz(db: AsyncSession, tenant_id: uuid.UUID) -> str:
    """Tenant yerel saat dilimi (zamanlama kurallari bu tz'de olculur)."""
    tz = (
        await db.execute(select(Tenant.timezone).where(Tenant.id == tenant_id))
    ).scalar_one_or_none()
    return tz or "Europe/Istanbul"


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


# Zamanlama sebep kodu -> (status, code, message).
_REASON_ERRORS: dict[str, tuple[int, str, str]] = {
    "dolu": (409, "conflict",
             "Secilen aralik bu alanda onaylanmis bir rezervasyonla cakisiyor."),
    "gecti": (422, "validation_error", "Slot baslangic saati gecti."),
    "cok_erken": (422, "validation_error",
                  "Rezervasyon en erken 24 saat kala yapilabilir."),
    "gunluk": (409, "conflict", "Bu gun icin zaten bir rezervasyonunuz var."),
}


# ------------------------------- rezerve et -------------------------------- #
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

    # Cakisma (dolu) on-kontrolu: ONAYLI bir rezervasyonla kesisiyor mu.
    dolu = (
        await db.execute(
            select(Rezervasyon.id).where(
                _cakisma_kosulu(body.alan_id, body.tarih, body.baslangic, body.bitis)
            ).limit(1)
        )
    ).scalar_one_or_none() is not None

    # Gunluk kota: sakinin AYNI slot-gunune denk AKTIF (onayli) rezervasyonu var mi.
    kota_dolu = (
        await db.execute(
            select(Rezervasyon.id).where(
                Rezervasyon.talep_eden_user_id == user.id,
                Rezervasyon.tarih == body.tarih,
                Rezervasyon.durum == "onaylandi",
            ).limit(1)
        )
    ).scalar_one_or_none() is not None

    # Zamanlama + cakisma + kota kurallari TEK kaynaktan (reservations_timing):
    # dolu -> gecti -> cok_erken -> gunluk (son-dakika istisnasi kotayi baypas eder).
    tzname = await _tenant_tz(db, user.tenant_id)
    sebep = rtiming.booking_reason(
        tzname, body.tarih, body.baslangic, dolu=dolu, kota_dolu=kota_dolu
    )
    if sebep is not None:
        status_code, code, message = _REASON_ERRORS[sebep]
        raise APIError(status_code, code, message)

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
        durum="onaylandi",
    )
    db.add(obj)
    # INSERT aninda DB EXCLUDE kisiti: es zamanli iki cakisan talepten yalniz
    # biri basarir; kaybeden 23P01 -> 409 (yaris DB'de cozulur).
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_exclusion_violation(exc):
            raise APIError(
                409, "conflict",
                "Secilen aralik bu alanda onaylanmis bir rezervasyonla cakisiyor.",
            )
        raise translate_integrity(exc)
    await db.refresh(obj)

    unit_no = (
        await db.execute(select(Unit.no).where(Unit.id == unit_id))
    ).scalar_one()
    # EK push: rezerve edene onay bildirimi (hatasi kaydi kirmaz).
    dispatch_external(
        f"Rezervasyonunuz onaylandi: {alan.ad} — {body.tarih.isoformat()} "
        f"{body.baslangic.strftime('%H:%M')}-{body.bitis.strftime('%H:%M')} ({unit_no})",
        tenant_id=user.tenant_id,
        target_user_ids=(user.id,),
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


# ------------------------------- iptal -------------------------------------- #
@router.post("/{reservation_id}/cancel", response_model=RezervasyonOut)
async def cancel_reservation(
    reservation_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_CANCELLER),
) -> RezervasyonOut:
    """Rezervasyonu iptal eder (durum='iptal'); slot bosalir. Sakin YALNIZ
    KENDI rezervasyonunu, yonetim herhangi birini iptal edebilir. Zaten
    iptal edilmis kayda ikinci iptal 409."""
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

    # Sakin yalniz KENDI rezervasyonunu iptal eder (varligi sizdirmadan 404).
    if user.role == "resident" and obj.talep_eden_user_id != user.id:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    if obj.durum != "onaylandi":
        raise APIError(409, "conflict", "Rezervasyon zaten iptal edilmis.")

    obj.durum = "iptal"
    obj.iptal_eden_user_id = user.id
    obj.iptal_zamani = func.now()
    await db.flush()
    await db.refresh(obj)

    talep_eden_ad = (
        await db.execute(
            select(AppUser.ad).where(AppUser.id == obj.talep_eden_user_id)
        )
    ).scalar_one_or_none()
    return _out((obj, alan_ad, unit_no, talep_eden_ad, user.ad))
