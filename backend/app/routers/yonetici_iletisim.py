"""GET /yonetici-iletisim — tenant'in yonetici iletisim dizini.

GIZLILIK ISTISNASI (contracts/auth.md): C1a'nin UC KAPISI (YON + RIZA + NUMARA
VARLIGI) ve "listede numara YOK" kurali burada BILINCLI olarak delinir.

GEREKCE: `yonetici` bir HIZMET rolüdür (kisisel iletisim degil); numarayi admin
tesis olusturulurken BILEREK girer; sahadaki personelin ve sakinin yonetime
ulasabilmesi urun geregidir.

KAPSAM (dar): YALNIZ bu uc, YALNIZ role='yonetici' kullanicilar, YALNIZ
ad_soyad + telefon. `aranabilir` rizasi bu ucta YOKSAYILIR — yonetici rizayi
kaldirsa bile kartta listelenir.

DEGISMEYENLER: C1a modeli baska HER SEY icin aynen gecerlidir — /call-target uc
kapili kalir; GET /users numara tasimaz; PATCH /me/contact rizasi diger roller
icin baglayicidir.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_current_user, get_tenant_db
from ..errors import APIError
from ..models import AppUser, Tenant
from ..schemas import YoneticiIletisimOut, YoneticiKart

router = APIRouter(tags=["yonetici-iletisim"])


@router.get("/yonetici-iletisim", response_model=YoneticiIletisimOut)
async def yonetici_iletisim(
    _user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> YoneticiIletisimOut:
    """Tenant'in TUM aktif yoneticileri (BIRINCIL ilk) + tenant yonetim maili.

    RBAC: tenant'in HERHANGI bir kimlikli uyesi (rol kapisi YOK); izolasyon RLS
    ile. `aranabilir` YOKSAYILIR — bkz. modul docstring'i.
    """
    rows = (
        (
            await db.execute(
                select(AppUser)
                .where(AppUser.role == "yonetici", AppUser.is_active.is_(True))
                .order_by(AppUser.birincil.desc(), AppUser.created_at.asc())
            )
        )
        .scalars()
        .all()
    )

    # RLS: yalnizca current tenant'in satiri gorunur.
    t = (await db.execute(select(Tenant))).scalar_one_or_none()
    if t is None:
        raise APIError(404, "not_found", "Tenant bulunamadi.")

    return YoneticiIletisimOut(
        yoneticiler=[
            YoneticiKart(user_id=u.id, ad_soyad=u.ad, telefon=u.telefon) for u in rows
        ],
        yonetim_email=t.yonetim_email,
    )
