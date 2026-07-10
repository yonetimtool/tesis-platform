"""GET /reports/financial-summary — cepten hizli finansal ozet (Wave 2B).

Rol-duyarli tek uc:
  * TUM roller (sakin/saha dahil — seffaflik): donem geliri/gideri/kasa +
    en yuksek gider kategorileri (agregat; kisi/daire verisi YOK).
  * Yalniz YONETIM (admin+yonetici): ek `tahsilat` blogu — donem tahakkuku,
    tahsilat, tahsilat orani ve geciken (tam odememis) daire sayisi.

Butce toplamlari budget modulundeki ozet matematigini yeniden kullanir
(date_filters). Aidat tarafi 'YYYY-MM' donem alanlari uzerinden hesaplanir
(dues_assessment.donem / dues_payment.donem); parametresiz cagri tum
zamanlari kapsar. Salt okuma; para integer KURUS.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_tenant_db, require_role
from ..models import AppUser, BudgetCategory, BudgetEntry, DuesAssessment, DuesPayment
from ..schemas import FinancialSummary, GiderKalemi, TahsilatOzet
from .budget import date_filters

router = APIRouter(prefix="/reports", tags=["reports"])

_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident"
)
_YONETIM = {"admin", "yonetici"}

#: Telefon ekranina uygun kompakt liste: en yuksek N gider kategorisi.
TOP_GIDER_LIMIT = 5


async def _tahsilat_ozet(db: AsyncSession, donem: str | None) -> TahsilatOzet:
    a_where = [] if donem is None else [DuesAssessment.donem == donem]
    p_where = [DuesPayment.durum == "basarili"]
    if donem is not None:
        p_where.append(DuesPayment.donem == donem)

    tahakkuk = (
        await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0)).where(*a_where)
        )
    ).scalar_one()
    tahsilat = (
        await db.execute(
            select(func.coalesce(func.sum(DuesPayment.tutar_kurus), 0)).where(*p_where)
        )
    ).scalar_one()

    # Geciken daire: donem tahakkuk toplami, basarili odeme toplamini asan
    # daireler (daire bazinda GROUP BY + correlated HAVING; satirlar cekilmez).
    geciken_sq = (
        select(DuesAssessment.unit_id)
        .where(*a_where)
        .group_by(DuesAssessment.unit_id)
        .having(
            func.sum(DuesAssessment.tutar_kurus)
            > func.coalesce(
                select(func.sum(DuesPayment.tutar_kurus))
                .where(DuesPayment.unit_id == DuesAssessment.unit_id, *p_where)
                .correlate(DuesAssessment)
                .scalar_subquery(),
                0,
            )
        )
        .subquery()
    )
    geciken = (
        await db.execute(select(func.count()).select_from(geciken_sq))
    ).scalar_one()

    orani = None
    if tahakkuk > 0:
        orani = round(100 * tahsilat / tahakkuk)

    return TahsilatOzet(
        tahakkuk_kurus=int(tahakkuk),
        tahsilat_kurus=int(tahsilat),
        tahsilat_orani_yuzde=orani,
        geciken_daire_sayisi=int(geciken),
    )


@router.get("/financial-summary", response_model=FinancialSummary)
async def financial_summary(
    donem: str | None = Query(None, description="'YYYY-MM'; bos = tum zamanlar"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> FinancialSummary:
    where = date_filters(donem, None, None)

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

    top_giderler = (
        await db.execute(
            select(BudgetCategory.ad, func.sum(BudgetEntry.tutar_kurus))
            .join(BudgetCategory, BudgetCategory.id == BudgetEntry.kategori_id)
            .where(BudgetEntry.tip == "gider", *where)
            .group_by(BudgetCategory.ad)
            .order_by(func.sum(BudgetEntry.tutar_kurus).desc())
            .limit(TOP_GIDER_LIMIT)
        )
    ).all()

    # Tahsilat blogu yalniz yonetimde dolar (sakin/saha: null — daire/kisi
    # duzeyinde bilgi sizdirilmaz, agregat seffaflik yeterli).
    tahsilat = (
        await _tahsilat_ozet(db, donem) if user.role in _YONETIM else None
    )

    return FinancialSummary(
        donem=donem,
        toplam_gelir_kurus=gelir,
        toplam_gider_kurus=gider,
        bakiye_kurus=gelir - gider,
        en_yuksek_giderler=[
            GiderKalemi(ad=ad, toplam_kurus=int(toplam)) for ad, toplam in top_giderler
        ],
        tahsilat=tahsilat,
    )
