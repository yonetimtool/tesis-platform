"""Seffaflik Panosu (Transparency Board) — aylik ANONIM finansal ozet.

  * GET  /transparency            — ay listesi (sakin: yayinlanmis; yonetim: aday+durum)
  * GET  /transparency/{ay}       — aylik ozet (sakin: yayinlanmis; yonetim: onizleme=her ay)
  * PUT  /transparency/{ay}/publish — yayinla/geri-al (yonetici+admin)

STRICT ANONIMLIK: yanit YALNIZ agregat tutar/sayi/yuzde ve KATEGORI ADLARI icerir.
Ad, daire etiketi, bireysel tutar ASLA donmez. `geciken_daire_sayisi` yalniz SAYI.

(P192 §1) Hesap TEK DEFTERDEN: `finansal_hareket` (gelir/gider/tahsilat,
tarih->ay) + `dues_assessment` (donem == ay). Onceden gelir/gider
`budget_entry`ten, tahsilat `dues_payment`ten okunuyordu ve ayni aya ait
"tahsilat" panelde farkli cikabiliyordu. Bos ay = sifir (cokme yok).
"""
from __future__ import annotations

import re

from fastapi import APIRouter, Depends
from sqlalchemy import func, literal_column, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from .. import defter
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    DuesAssessment,
    FinansalHareket,
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

router = APIRouter(prefix="/transparency", tags=["transparency"])

_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    # (P128) Seffaflik panosu zaten anonim ozet; denetci de OKUR.
    "denetci",
)
_MANAGER = require_role("admin", "yonetici")
_YONETIM = {"admin", "yonetici"}

_AY_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")
_TOP_N = 6  # gider dagiliminda en yuksek N kategori; kalan "Diğer"
_LIST_LIMIT = 24


def _valid_ay(ay: str) -> str:
    if not _AY_RE.match(ay):
        raise APIError(422, "validation_error", "ay_bicimi")
    return ay


def _prev_month(ay: str) -> str:
    y, m = int(ay[:4]), int(ay[5:7])
    return f"{y - 1}-12" if m == 1 else f"{y}-{m - 1:02d}"


def _pct(part: int, whole: int) -> int | None:
    return round(100 * part / whole) if whole > 0 else None


async def _month_gelir_gider(db: AsyncSession, ay: str) -> tuple[int, int]:
    ilk, son = defter.donem_araligi(ay)
    return (
        await defter.gelir_toplami(db, baslangic=ilk, bitis=son),
        await defter.gider_toplami(db, baslangic=ilk, bitis=son),
    )


async def _aidat(db: AsyncSession, ay: str) -> TransparencyAidat:
    # (P192 §6.3) Ters kayit cifti borc DEGILDIR.
    a_where = [DuesAssessment.donem == ay, *defter.gecerli_tahakkuk()]
    tahakkuk = int(
        (await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0)).where(*a_where)
        )).scalar_one()
    )
    # TEK KAYNAK (P192 §1): rapor ve panel ozeti de bunu cagirir.
    tahsilat = await defter.tahsilat_toplami(db, donem=ay)
    # Geciken (tam odenmemis) daire: SAYI ONLY (hangi daire ASLA cekilmez).
    tahakkuk_daire = (
        await db.execute(
            select(
                DuesAssessment.unit_id,
                func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0),
            )
            .where(*a_where)
            .group_by(DuesAssessment.unit_id)
        )
    ).all()
    toplam_daire = len(tahakkuk_daire)
    odenen = await defter.daire_odenen(
        db, [uid for uid, _ in tahakkuk_daire], donem=ay
    )
    geciken = sum(
        1 for uid, toplam in tahakkuk_daire if int(toplam) > odenen.get(uid, 0)
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

    ilk, son = defter.donem_araligi(ay)
    # (P108) Kararli kuyruk: `defter.gider_kategori_kirilimi` toplam sonra
    # ada gore siralar — bu pano SAKINE aciktir ve esit tutarli iki
    # kategorinin sirasi her yenilemede degisseydi, degismeyen bir veri
    # degisiyormus gibi gorunurdu.
    top = await defter.gider_kategori_kirilimi(
        db, baslangic=ilk, bitis=son, limit=_TOP_N
    )
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
        # Kategorisiz hareketler zaten "Diğer" adiyla gelebilir; ikinci bir
        # "Diğer" satiri yazmak, ayni etiketi iki kez gostermek olurdu.
        mevcut = next((k for k in dagilim if k.ad == defter.KATEGORISIZ), None)
        if mevcut is not None:
            mevcut.toplam_kurus += diger
            mevcut.yuzde = _pct(mevcut.toplam_kurus, gider) or 0
        else:
            dagilim.append(
                TransparencyKategoriKalemi(
                    ad=defter.KATEGORISIZ, toplam_kurus=diger,
                    yuzde=_pct(diger, gider) or 0,
                )
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
    ay_col = func.to_char(FinansalHareket.tarih, literal_column("'YYYY-MM'"))
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
    #: Liste NET degeri icin ay bazli tek gruplu sorgu (N+1 yok). Ayrinti
    #: sayfasindan farkli olarak iptal/iade satirlari da `yon` isaretiyle
    #: dogru yonde toplanir.
    net_rows = (
        await db.execute(
            select(
                ay_col,
                func.sum(defter.isaret() * FinansalHareket.tutar_kurus),
            )
            .where(FinansalHareket.durum == defter.GERCEKLESEN)
            .group_by(ay_col)
        )
    ).all()
    net_by = {m: int(toplam) for m, toplam in net_rows}

    items = [
        TransparencyAyOzet(
            ay=m,
            yayinlandi=pubs.get(m, False),
            net_kurus=net_by.get(m, 0),
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
        raise APIError(404, "not_found", "seffaflik_yayin_yok")
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
