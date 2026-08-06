"""(P148.2) Sakin kayit BASVURULARI — yonetici onay kapisi.

Telefonu dogrulanmis basvuru burada bekler ve hicbir veriye erisimi
YOKTUR. Hesap ancak onaydan sonra acilir.

NEDEN VAR: tesis kodu P148.1'de akilda kalici yapildi ve TAHMIN EDILEBILIR
oldu (adin ilk 4 harfi + kayit tarihi). Kod tek denetim olsaydi site adini
bilen herkes herhangi bir daireye girebilirdi; onay adimi bu acigi kapatir.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select

from ..audit import Action, audit_user
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, KayitDogrulama, Unit, UnitResident
from ..schemas import KayitBasvuruListesi, KayitBasvuruOut, PageMetaOut
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/kayit-basvurulari", tags=["kayit"])

# Onay YONETIM isidir. `security` bu listeyi GORMEZ: basvuru telefon
# numarasi ve daire eslesmesi tasir (kisisel veri).
_MANAGER = require_role("admin", "yonetici")


async def _bekleyen(db: AsyncSession, basvuru_id: uuid.UUID) -> KayitDogrulama:
    obj = (
        await db.execute(
            select(KayitDogrulama).where(
                KayitDogrulama.id == basvuru_id,
                KayitDogrulama.durum == "onay_bekliyor",
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    return obj


@router.get("", response_model=KayitBasvuruListesi)
async def list_basvurular(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> KayitBasvuruListesi:
    """Yalniz ONAY BEKLEYENLER. Telefonu dogrulanmamis basvuru burada
    gorunmez — yonetici, sahibi olmayan bir numarayi onaylamamali."""
    kosul = KayitDogrulama.durum == "onay_bekliyor"
    total = (
        await db.execute(
            select(func.count()).select_from(KayitDogrulama).where(kosul)
        )
    ).scalar_one()
    rows = (
        await db.execute(
            select(KayitDogrulama, Unit.no)
            .join(Unit, Unit.id == KayitDogrulama.unit_id)
            .where(kosul)
            .order_by(KayitDogrulama.created_at.asc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return KayitBasvuruListesi(
        items=[
            KayitBasvuruOut(
                id=r[0].id, ad=r[0].ad, telefon=r[0].telefon,
                daire=r[1], created_at=r[0].created_at,
            )
            for r in rows
        ],
        meta=PageMetaOut(total=total, limit=limit, offset=offset),
    )


@router.post("/{basvuru_id}/onayla", status_code=201)
async def onayla(
    basvuru_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> dict[str, str]:
    """HESAP BURADA ACILIR — parolasiz, daireye bagli."""
    obj = await _bekleyen(db, basvuru_id)
    yeni = AppUser(
        tenant_id=user.tenant_id,
        ad=(obj.ad or "").strip() or obj.telefon,
        telefon=obj.telefon,
        role="resident",
        # PAROLA YOK — kimlik dogrulanmis telefondur.
        password_hash=None,
        password_set=False,
        is_active=True,
    )
    db.add(yeni)
    await db.flush()
    db.add(
        UnitResident(tenant_id=user.tenant_id, unit_id=obj.unit_id, user_id=yeni.id)
    )
    obj.durum = "onaylandi"
    obj.karar_at = datetime.now(timezone.utc)
    obj.user_id = yeni.id
    await db.flush()
    await audit_user(
        db, user, Action.KAYIT_ONAY, resource_type="app_user",
        resource_id=yeni.id, meta={"basvuru_id": str(obj.id)},
    )
    return {"user_id": str(yeni.id)}


@router.post("/{basvuru_id}/reddet", status_code=200)
async def reddet(
    basvuru_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> dict[str, str]:
    """Basvuru SILINMEZ, reddedilir: iz kalir ve ayni numara yeniden
    basvurabilir (acik-basvuru kismi indeksi buna izin verir)."""
    obj = await _bekleyen(db, basvuru_id)
    obj.durum = "reddedildi"
    obj.karar_at = datetime.now(timezone.utc)
    await db.flush()
    await audit_user(
        db, user, Action.KAYIT_RED, resource_type="kayit_dogrulama",
        resource_id=obj.id,
    )
    return {"durum": "reddedildi"}
