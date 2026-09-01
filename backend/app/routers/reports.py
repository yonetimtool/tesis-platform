"""GET /reports/financial-summary — cepten hizli finansal ozet (Wave 2B).

Rol-duyarli tek uc:
  * TUM roller (sakin/saha dahil — seffaflik): donem geliri/gideri/kasa +
    en yuksek gider kategorileri (agregat; kisi/daire verisi YOK).
  * Yalniz YONETIM (admin+yonetici): ek `tahsilat` blogu — donem tahakkuku,
    tahsilat, tahsilat orani ve geciken (tam odememis) daire sayisi.

(P192 §1) TUM rakamlar TEK DEFTERDEN (`app/defter.py`). Onceden gelir/gider
`budget_entry`ten, tahsilat `dues_payment`ten okunuyordu; ayni "tahsilat
orani" panelde `finansal_hareket`ten hesaplandigi icin IKI EKRAN IKI RAKAM
gosteriyordu. Artik ikisi de `defter.tahsilat_toplami()` cagiriyor.

Aidat tarafi 'YYYY-MM' donem alanlari uzerinden hesaplanir
(dues_assessment.donem / finansal_hareket.donem); parametresiz cagri tum
zamanlari kapsar. Salt okuma; para integer KURUS.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import defter
from ..deps import get_tenant_db, require_role
from ..models import AppUser, DuesAssessment
from ..roller import MALI_GORUNURLUK
from ..schemas import FinancialSummary, GiderKalemi, TahsilatOzet

router = APIRouter(prefix="/reports", tags=["reports"])

_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    # (P128) Denetci mali ozeti OKUR — gorevinin ta kendisi.
    "denetci",
)
#: (P133.6) Mali ozeti gorebilen roller — TEK KAYNAK `roller.py`de.
#: Pano da ayni kumeyi okur; ikisi ayrisirsa denetci raporlarda gorup
#: panoda goremez (ya da tersi) ve hicbir test dusmezdi.
_YONETIM = MALI_GORUNURLUK

#: Telefon ekranina uygun kompakt liste: en yuksek N gider kategorisi.
TOP_GIDER_LIMIT = 5


async def _tahsilat_ozet(db: AsyncSession, donem: str | None) -> TahsilatOzet:
    # (P192 §6.3) Ters kayit cifti borc DEGILDIR.
    a_where = list(defter.gecerli_tahakkuk())
    if donem is not None:
        a_where.append(DuesAssessment.donem == donem)

    tahakkuk = (
        await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0)).where(*a_where)
        )
    ).scalar_one()
    # TEK KAYNAK: panel ozeti, seffaflik ve mobil ana ekran da bunu cagirir.
    tahsilat = await defter.tahsilat_toplami(db, donem=donem)

    # Geciken daire: donem tahakkuk toplami, tahsilat toplamini asan
    # daireler. Karsilastirma PYTHON'da yapiliyor cunku "odenen" tanimi
    # (iade/iptal dusulmus, yalniz gerceklesmis satirlar) tek yerde
    # yasiyor; SQL'e ikinci bir kopyasini yazmak, bu turun duzelttigi
    # kusuru geri getirirdi.
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
    odenen = await defter.daire_odenen(
        db, [uid for uid, _ in tahakkuk_daire], donem=donem
    )
    geciken = sum(
        1 for uid, toplam in tahakkuk_daire if int(toplam) > odenen.get(uid, 0)
    )

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
    ilk, son = defter.donem_araligi(donem) if donem else (None, None)

    gelir = await defter.gelir_toplami(db, baslangic=ilk, bitis=son)
    gider = await defter.gider_toplami(db, baslangic=ilk, bitis=son)
    top_giderler = await defter.gider_kategori_kirilimi(
        db, baslangic=ilk, bitis=son, limit=TOP_GIDER_LIMIT
    )

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
