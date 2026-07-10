"""Butce modulu (Wave 2A) — dinamik kategoriler + gelir/gider defteri + ozet.

RBAC (auth.md §4): yonetim (admin + yonetici) TAM yetkili; saha/sakin 403
(sakin SEFFAFLIK okumasi Wave 2B'de eklenecek — endpoint'ler ona gore ayrik).
Para HER YERDE integer KURUS (dues deseni; float asla). tenant token'dan; RLS.

Kategori silme stratejisi: SOFT-DELETE (PATCH aktif=false). Hard DELETE ucu
bilincli olarak YOK; hareketi olan kategori DB'de de FK RESTRICT ile korunur.
Pasif kategoriye YENI kayit yazilamaz; eski kayitlar kategorisini korur.

Otomatik aidat→gelir: basarili aidat odemesi 'Aidat' gelir kategorisine
kaynak='aidat_odeme' kaydi uretir (bkz. ensure_dues_income_entry) —
UNIQUE (tenant_id, ilgili_payment_id) ile idempotent.
"""
from __future__ import annotations

import calendar
import logging
import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, BudgetCategory, BudgetEntry, DuesPayment
from ..schemas import (
    BudgetCategoryCreate,
    BudgetCategoryListResponse,
    BudgetCategoryOut,
    BudgetCategorySummary,
    BudgetCategoryUpdate,
    BudgetEntryCreate,
    BudgetEntryListResponse,
    BudgetEntryOut,
    BudgetEntryUpdate,
    BudgetKaynak,
    BudgetSummary,
    BudgetTip,
)

log = logging.getLogger(__name__)

router = APIRouter(prefix="/budget", tags=["budget"])

_MANAGER = require_role("admin", "yonetici")

# Otomatik aidat gelirlerinin toplandigi varsayilan kategori adi (seed'de de
# olusturulur; yoksa ilk odemede get-or-create ile acilir).
AIDAT_KATEGORI_AD = "Aidat"

_CAT_CONFLICT = APIError(409, "conflict", "Bu ad ve tipte kategori zaten var.")


def _donem_range(donem: str) -> tuple[date, date]:
    """'YYYY-MM' -> (ayin ilk gunu, ayin son gunu). Bicim hatasi -> 422."""
    try:
        y, m = donem.split("-")
        year, month = int(y), int(m)
        first = date(year, month, 1)
    except (ValueError, TypeError):
        raise APIError(422, "validation_error", "donem 'YYYY-MM' biciminde olmali.")
    last = date(year, month, calendar.monthrange(year, month)[1])
    return first, last


def _date_filters(
    donem: str | None, baslangic: date | None, bitis: date | None
) -> list:
    """donem VEYA (baslangic/bitis) → tarih kosullari. donem oncelikli."""
    if donem is not None:
        first, last = _donem_range(donem)
        return [BudgetEntry.tarih >= first, BudgetEntry.tarih <= last]
    where = []
    if baslangic is not None:
        where.append(BudgetEntry.tarih >= baslangic)
    if bitis is not None:
        where.append(BudgetEntry.tarih <= bitis)
    return where


# ----------------------------- kategoriler --------------------------------- #
@router.post("/categories", response_model=BudgetCategoryOut, status_code=201)
async def create_category(
    body: BudgetCategoryCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> BudgetCategory:
    obj = BudgetCategory(tenant_id=user.tenant_id, ad=body.ad, tip=body.tip)
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _CAT_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


@router.get("/categories", response_model=BudgetCategoryListResponse)
async def list_categories(
    tip: BudgetTip | None = Query(None),
    aktif: bool | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> BudgetCategoryListResponse:
    where = []
    if tip is not None:
        where.append(BudgetCategory.tip == tip)
    if aktif is not None:
        where.append(BudgetCategory.aktif == aktif)
    total = (
        await db.execute(select(func.count()).select_from(BudgetCategory).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(BudgetCategory).where(*where).order_by(BudgetCategory.ad).limit(limit).offset(offset)
        )
    ).scalars().all()
    return BudgetCategoryListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=list(rows)
    )


@router.patch("/categories/{category_id}", response_model=BudgetCategoryOut)
async def update_category(
    category_id: uuid.UUID,
    body: BudgetCategoryUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> BudgetCategory:
    obj = await get_or_404(db, BudgetCategory, category_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise _CAT_CONFLICT
        raise translate_integrity(exc)
    await db.refresh(obj)
    return obj


# ------------------------------- defter ------------------------------------ #
def _entry_out(obj: BudgetEntry, kategori_ad: str | None) -> BudgetEntryOut:
    out = BudgetEntryOut.model_validate(obj)
    out.kategori_ad = kategori_ad
    return out


@router.post("/entries", response_model=BudgetEntryOut, status_code=201)
async def create_entry(
    body: BudgetEntryCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> BudgetEntryOut:
    cat = (
        await db.execute(select(BudgetCategory).where(BudgetCategory.id == body.kategori_id))
    ).scalar_one_or_none()
    if cat is None:
        raise APIError(422, "invalid_reference", "kategori_id bu tenant'ta bulunamadi.")
    if not cat.aktif:
        raise APIError(
            422, "invalid_reference",
            "Pasif kategoriye yeni kayit yazilamaz (kategoriyi aktiflestirin).",
        )

    obj = BudgetEntry(
        tenant_id=user.tenant_id,
        kategori_id=cat.id,
        tip=cat.tip,  # kategoriden turetilir — uyusmazlik imkansiz
        tutar_kurus=body.tutar_kurus,
        tarih=body.tarih,
        aciklama=body.aciklama,
        kaynak="manuel",
        created_by=user.id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return _entry_out(obj, cat.ad)


@router.get("/entries", response_model=BudgetEntryListResponse)
async def list_entries(
    tip: BudgetTip | None = Query(None),
    kategori_id: uuid.UUID | None = Query(None),
    kaynak: BudgetKaynak | None = Query(None),
    donem: str | None = Query(None, description="'YYYY-MM' — ay filtresi"),
    baslangic: date | None = Query(None),
    bitis: date | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> BudgetEntryListResponse:
    where = _date_filters(donem, baslangic, bitis)
    if tip is not None:
        where.append(BudgetEntry.tip == tip)
    if kategori_id is not None:
        where.append(BudgetEntry.kategori_id == kategori_id)
    if kaynak is not None:
        where.append(BudgetEntry.kaynak == kaynak)

    total = (
        await db.execute(select(func.count()).select_from(BudgetEntry).where(*where))
    ).scalar_one()
    rows = (
        await db.execute(
            select(BudgetEntry, BudgetCategory.ad)
            .join(BudgetCategory, BudgetCategory.id == BudgetEntry.kategori_id)
            .where(*where)
            .order_by(BudgetEntry.tarih.desc(), BudgetEntry.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return BudgetEntryListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_entry_out(e, ad) for e, ad in rows],
    )


async def _manual_entry_or_error(db: AsyncSession, entry_id: uuid.UUID) -> BudgetEntry:
    obj = await get_or_404(db, BudgetEntry, entry_id)
    if obj.kaynak != "manuel":
        # Otomatik aidat kaydi defterden elle oynanamaz — aidat mutabakati
        # bozulmasin (odeme iptali/duzeltmesi aidat modulunun isi).
        raise APIError(
            422, "invalid_reference",
            "Otomatik aidat kaydi duzenlenemez/silinemez; aidat modulunden yonetilir.",
        )
    return obj


@router.patch("/entries/{entry_id}", response_model=BudgetEntryOut)
async def update_entry(
    entry_id: uuid.UUID,
    body: BudgetEntryUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> BudgetEntryOut:
    obj = await _manual_entry_or_error(db, entry_id)
    data = body.model_dump(exclude_unset=True)

    if "kategori_id" in data:
        cat = (
            await db.execute(
                select(BudgetCategory).where(BudgetCategory.id == data["kategori_id"])
            )
        ).scalar_one_or_none()
        if cat is None:
            raise APIError(422, "invalid_reference", "kategori_id bu tenant'ta bulunamadi.")
        if not cat.aktif:
            raise APIError(422, "invalid_reference", "Pasif kategoriye tasinabilir degil.")
        obj.tip = cat.tip  # tip kategoriyle birlikte guncellenir

    for key, value in data.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    kategori_ad = (
        await db.execute(select(BudgetCategory.ad).where(BudgetCategory.id == obj.kategori_id))
    ).scalar_one_or_none()
    return _entry_out(obj, kategori_ad)


@router.delete("/entries/{entry_id}", status_code=204)
async def delete_entry(
    entry_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> Response:
    obj = await _manual_entry_or_error(db, entry_id)
    await db.delete(obj)
    await db.flush()
    return Response(status_code=204)


# -------------------------------- ozet -------------------------------------- #
@router.get("/summary", response_model=BudgetSummary)
async def budget_summary(
    donem: str | None = Query(None, description="'YYYY-MM' — ay bazli ozet"),
    baslangic: date | None = Query(None),
    bitis: date | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> BudgetSummary:
    where = _date_filters(donem, baslangic, bitis)

    # tip toplamlari (KURUS; SUM SQL'de — satirlar cekilmez).
    rows = (
        await db.execute(
            select(BudgetEntry.tip, func.coalesce(func.sum(BudgetEntry.tutar_kurus), 0))
            .where(*where)
            .group_by(BudgetEntry.tip)
        )
    ).all()
    totals = {tip: int(toplam) for tip, toplam in rows}
    gelir = totals.get("gelir", 0)
    gider = totals.get("gider", 0)

    # kategori kirilimi
    cat_rows = (
        await db.execute(
            select(
                BudgetEntry.kategori_id,
                BudgetCategory.ad,
                BudgetEntry.tip,
                func.sum(BudgetEntry.tutar_kurus),
            )
            .join(BudgetCategory, BudgetCategory.id == BudgetEntry.kategori_id)
            .where(*where)
            .group_by(BudgetEntry.kategori_id, BudgetCategory.ad, BudgetEntry.tip)
            .order_by(BudgetCategory.ad)
        )
    ).all()

    return BudgetSummary(
        toplam_gelir_kurus=gelir,
        toplam_gider_kurus=gider,
        bakiye_kurus=gelir - gider,  # kasa; negatif olabilir
        kategoriler=[
            BudgetCategorySummary(
                kategori_id=kid, ad=ad, tip=tip, toplam_kurus=int(toplam)
            )
            for kid, ad, tip, toplam in cat_rows
        ],
    )


# ---------------------- OTOMATIK aidat -> gelir ----------------------------- #
async def ensure_dues_income_entry(db: AsyncSession, payment: DuesPayment) -> None:
    """Basarili aidat odemesi icin TEK otomatik gelir kaydini garanti et.

    * IDEMPOTENT: UNIQUE (tenant_id, ilgili_payment_id) — ayni odeme ikinci
      kaydi URETEMEZ; cakisma sessizce yutulur.
    * Kategori: '{AIDAT_KATEGORI_AD}' (gelir) — yoksa olusturulur (get-or-create).
    * Odeme kaydini ASLA dusurmez: butce tarafindaki her aksaklik loglanip
      yutulur (normalde basarilidir; kacan kayit sonradan mutabakatla gorulur).
    * Tarih = odemenin gerceklestigi gun (nakit esasi), tahakkuk donemi degil.
    * Cagiran, odeme ile AYNI transaction icindedir (get_tenant_db /webhook
      session'i) — odeme commit'lenirse kayit da commit'lenir.
    """
    if payment.durum != "basarili":
        return
    try:
        async with db.begin_nested():
            cat = (
                await db.execute(
                    select(BudgetCategory).where(
                        BudgetCategory.ad == AIDAT_KATEGORI_AD,
                        BudgetCategory.tip == "gelir",
                    )
                )
            ).scalar_one_or_none()
            if cat is None:
                cat = BudgetCategory(
                    tenant_id=payment.tenant_id, ad=AIDAT_KATEGORI_AD, tip="gelir"
                )
                db.add(cat)
                await db.flush()

            aciklama = "Aidat odemesi (otomatik)"
            if payment.donem:
                aciklama = f"Aidat odemesi {payment.donem} (otomatik)"
            db.add(
                BudgetEntry(
                    tenant_id=payment.tenant_id,
                    kategori_id=cat.id,
                    tip="gelir",
                    tutar_kurus=payment.tutar_kurus,  # odemeyle BIREBIR
                    tarih=payment.odeme_zamani.date(),
                    aciklama=aciklama,
                    kaynak="aidat_odeme",
                    ilgili_payment_id=payment.id,
                    created_by=payment.kaydeden_user_id,
                )
            )
            await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            # Ayni odemenin kaydi zaten var (yaris/tekrar) — idempotent, sorun yok.
            return
        log.warning("aidat->butce gelir kaydi yazilamadi (payment=%s): %s", payment.id, exc)
    except Exception as exc:  # noqa: BLE001 — odeme butce hatasina kurban edilmez
        log.warning("aidat->butce gelir kaydi yazilamadi (payment=%s): %s", payment.id, exc)
