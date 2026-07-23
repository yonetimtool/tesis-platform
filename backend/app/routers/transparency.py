"""Seffaflik Panosu (Transparency Board) — aylik ANONIM finansal ozet.

  * GET  /transparency            — ay listesi (sakin: yayinlanmis; yonetim: aday+durum)
  * GET  /transparency/{ay}       — aylik ozet (sakin: yayinlanmis; yonetim: onizleme=her ay)
  * PUT  /transparency/{ay}/publish — yayinla/geri-al (yonetici+admin)

STRICT ANONIMLIK: yanit YALNIZ agregat tutar/sayi/yuzde ve KATEGORI ADLARI icerir.
Ad, daire etiketi, bireysel tutar ASLA donmez. `geciken_daire_sayisi` yalniz SAYI.

Hesap: budget_entry (gelir/gider, tarih->ay) + dues (donem == ay). Bos ay = sifir
(cokme yok). Butce matematigi budget.date_filters ile paylasilir.
"""
from __future__ import annotations

import re

from fastapi import APIRouter, Depends
from sqlalchemy import func, literal_column, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    BudgetCategory,
    BudgetEntry,
    DuesAssessment,
    DuesPayment,
    TransparencyPublication,
)
from ..schemas import (
    TransparencyAidat,
    TransparencyAyOzet,
    TransparencyBoardOut,
    TransparencyKategoriKalemi,
    TransparencyListResponse,
    TransparencyPublishRequest,
)
from .budget import date_filters

router = APIRouter(prefix="/transparency", tags=["transparency"])

_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
_MANAGER = require_role("admin", "yonetici")
_YONETIM = {"admin", "yonetici"}

_AY_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")
_TOP_N = 6  # gider dagiliminda en yuksek N kategori; kalan "Diğer"
_LIST_LIMIT = 24


def _valid_ay(ay: str) -> str:
    if not _AY_RE.match(ay):
        raise APIError(422, "validation_error", "ay 'YYYY-MM' formatinda olmali.")
    return ay


def _prev_month(ay: str) -> str:
    y, m = int(ay[:4]), int(ay[5:7])
    return f"{y - 1}-12" if m == 1 else f"{y}-{m - 1:02d}"


def _pct(part: int, whole: int) -> int | None:
    return round(100 * part / whole) if whole > 0 else None


async def _month_gelir_gider(db: AsyncSession, ay: str) -> tuple[int, int]:
    rows = (
        await db.execute(
            select(BudgetEntry.tip, func.coalesce(func.sum(BudgetEntry.tutar_kurus), 0))
            .where(*date_filters(ay, None, None))
            .group_by(BudgetEntry.tip)
        )
    ).all()
    t = {tip: int(v) for tip, v in rows}
    return t.get("gelir", 0), t.get("gider", 0)


async def _aidat(db: AsyncSession, ay: str) -> TransparencyAidat:
    a_where = [DuesAssessment.donem == ay]
    p_where = [DuesPayment.durum == "basarili", DuesPayment.donem == ay]
    tahakkuk = int(
        (await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0)).where(*a_where)
        )).scalar_one()
    )
    tahsilat = int(
        (await db.execute(
            select(func.coalesce(func.sum(DuesPayment.tutar_kurus), 0)).where(*p_where)
        )).scalar_one()
    )
    toplam_daire = int(
        (await db.execute(
            select(func.count(func.distinct(DuesAssessment.unit_id))).where(*a_where)
        )).scalar_one()
    )
    # Geciken (tam odenmemis) daire: SAYI ONLY (hangi daire ASLA cekilmez).
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
    geciken = int(
        (await db.execute(select(func.count()).select_from(geciken_sq))).scalar_one()
    )
    odeyen = toplam_daire - geciken
    return TransparencyAidat(
        tahakkuk_kurus=tahakkuk,
        tahsilat_kurus=tahsilat,
        tutar_orani_yuzde=_pct(tahsilat, tahakkuk),
        toplam_daire=toplam_daire,
        odeyen_daire=odeyen,
        daire_orani_yuzde=_pct(odeyen, toplam_daire),
        geciken_daire_sayisi=geciken,
    )


async def _board(db: AsyncSession, ay: str, yayinlandi: bool) -> TransparencyBoardOut:
    gelir, gider = await _month_gelir_gider(db, ay)

    top = (
        await db.execute(
            select(BudgetCategory.ad, func.sum(BudgetEntry.tutar_kurus))
            .join(BudgetCategory, BudgetCategory.id == BudgetEntry.kategori_id)
            .where(BudgetEntry.tip == "gider", *date_filters(ay, None, None))
            .group_by(BudgetCategory.ad)
            .order_by(func.sum(BudgetEntry.tutar_kurus).desc())
            .limit(_TOP_N)
        )
    ).all()
    dagilim: list[TransparencyKategoriKalemi] = []
    top_sum = 0
    for ad, toplam in top:
        toplam = int(toplam)
        top_sum += toplam
        dagilim.append(
            TransparencyKategoriKalemi(ad=ad, toplam_kurus=toplam, yuzde=_pct(toplam, gider) or 0)
        )
    diger = gider - top_sum
    if diger > 0:
        dagilim.append(
            TransparencyKategoriKalemi(ad="Diğer", toplam_kurus=diger, yuzde=_pct(diger, gider) or 0)
        )

    prev = _prev_month(ay)
    pg, pgd = await _month_gelir_gider(db, prev)
    onceki_net = (pg - pgd) if (pg or pgd) else None  # veri yoksa None

    return TransparencyBoardOut(
        ay=ay,
        yayinlandi=yayinlandi,
        toplam_gelir_kurus=gelir,
        toplam_gider_kurus=gider,
        net_kurus=gelir - gider,
        gider_dagilimi=dagilim,
        aidat=await _aidat(db, ay),
        onceki_ay_net_kurus=onceki_net,
    )


async def _is_published(db: AsyncSession, ay: str) -> bool:
    return bool(
        (
            await db.execute(
                select(TransparencyPublication.yayin).where(
                    TransparencyPublication.ay == ay
                )
            )
        ).scalar_one_or_none()
    )


# ------------------------------- endpoints --------------------------------- #
@router.get("", response_model=TransparencyListResponse)
async def list_months(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> TransparencyListResponse:
    """Ay listesi. Sakin/saha: YALNIZ yayinlanmis aylar. Yonetim: finansal verisi
    olan TUM aday aylar + yayin durumu (ac/kapa listesi). Her ay icin net (agregat)."""
    is_mgmt = user.role in _YONETIM

    # Yayin durumlari.
    pubs = {
        p.ay: p.yayin
        for p in (
            await db.execute(select(TransparencyPublication))
        ).scalars().all()
    }
    # Aday aylar: butce (tarih->ay) + aidat (donem) + yayin kayitlari.
    # NOT: to_char format'i literal_column ile INLINE verilir; bind-param olsaydi
    # SELECT ($1) ve GROUP BY ($2) ayni gorunmez -> GroupingError.
    ay_col = func.to_char(BudgetEntry.tarih, literal_column("'YYYY-MM'"))
    b_months = set(
        (await db.execute(select(func.distinct(ay_col)))).scalars().all()
    )
    d_months = set(
        (await db.execute(select(func.distinct(DuesAssessment.donem)))).scalars().all()
    )
    months = b_months | d_months | set(pubs.keys())
    if not is_mgmt:
        months = {m for m in months if pubs.get(m)}
    ordered = sorted((m for m in months if m), reverse=True)[:_LIST_LIMIT]

    # Net (agregat) toplu hesap — tek gruplu sorgu (N+1 yok).
    net_rows = (
        await db.execute(
            select(ay_col, BudgetEntry.tip, func.sum(BudgetEntry.tutar_kurus))
            .group_by(ay_col, BudgetEntry.tip)
        )
    ).all()
    net_by: dict[str, dict[str, int]] = {}
    for m, tip, toplam in net_rows:
        net_by.setdefault(m, {})[tip] = int(toplam)

    items = [
        TransparencyAyOzet(
            ay=m,
            yayinlandi=pubs.get(m, False),
            net_kurus=net_by.get(m, {}).get("gelir", 0) - net_by.get(m, {}).get("gider", 0),
        )
        for m in ordered
    ]
    return TransparencyListResponse(items=items)


@router.get("/{ay}", response_model=TransparencyBoardOut)
async def get_board(
    ay: str,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> TransparencyBoardOut:
    """Aylik anonim ozet. Sakin/saha: YALNIZ yayinlanmis (aksi 404 — varligi da
    sizdirmaz). Yonetim: her ay (yayinlanmamis = ONIZLEME; yayinlandi bayragi durumu)."""
    _valid_ay(ay)
    published = await _is_published(db, ay)
    if user.role not in _YONETIM and not published:
        raise APIError(404, "not_found", "Bu ay icin yayinlanmis ozet yok.")
    return await _board(db, ay, yayinlandi=published)


@router.put("/{ay}/publish", response_model=TransparencyBoardOut)
async def set_publish(
    ay: str,
    body: TransparencyPublishRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> TransparencyBoardOut:
    """Ayi yayinla/geri-al (yonetici+admin). Upsert (tenant, ay). Denetime yazilir."""
    _valid_ay(ay)
    stmt = (
        pg_insert(TransparencyPublication)
        .values(tenant_id=user.tenant_id, ay=ay, yayin=body.yayin, updated_at=func.now())
        .on_conflict_do_update(
            constraint="uq_transparency_tenant_ay",
            set_={"yayin": body.yayin, "updated_at": func.now()},
        )
    )
    await db.execute(stmt)
    await db.flush()
    await audit_user(
        db,
        user,
        Action.TRANSPARENCY_PUBLISH if body.yayin else Action.TRANSPARENCY_UNPUBLISH,
        resource_type="transparency_publication",
        resource_id=ay,
        meta={"ay": ay, "yayin": body.yayin},
    )
    return await _board(db, ay, yayinlandi=body.yayin)
