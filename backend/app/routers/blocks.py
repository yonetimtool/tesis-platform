"""Bina blok CRUD (D-viz Rev-1) — yonetici/admin blok tanimlar.

Rev-2 gorsel editoru bloklari (kat/daire iskeletiyle) buradan yonetir. Blok
etiketi `unit.blok` (serbest metin) ile eslesir — zayif baglanti (hard FK yok),
boylece blok-suz ve blok-tabanli siteler birlikte desteklenir.

RBAC: admin + yonetici yonetir (bina yerlesimi yonetimidir); digerleri 403.
Silme guvenligi: bir blogu kullanan daire varsa silme reddedilir (409) — once
daireler tasinmali/silinmeli.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import delete, func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, BuildingBlock, Unit
from ..schemas import BlockCreate, BlockListResponse, BlockOut, BlockUpdate

router = APIRouter(prefix="/blocks", tags=["building"])

# Bina yerlesimi YAZMA: admin + yonetici (blok ekle/duzenle/sil).
_MANAGER = require_role("admin", "yonetici")
# Bina yerlesimi OKUMA: yonetim + saha (security/tesis_gorevlisi) — saha
# rolleri "Bina Duzenleme" ekranini SALT-OKUMA gorur (yazma yine 403).
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")


async def _unit_counts(db: AsyncSession) -> dict[str, int]:
    """Blok etiketi -> o etiketi tasiyan daire sayisi (silme guvenligi)."""
    rows = (
        await db.execute(
            select(Unit.blok, func.count(Unit.id))
            .where(Unit.blok.is_not(None))
            .group_by(Unit.blok)
        )
    ).all()
    return {blok: n for blok, n in rows}


def _out(obj: BuildingBlock, unit_sayisi: int) -> BlockOut:
    out = BlockOut.model_validate(obj)
    out.unit_sayisi = unit_sayisi
    return out


@router.get("", response_model=BlockListResponse)
async def list_blocks(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> BlockListResponse:
    counts = await _unit_counts(db)
    rows = (
        await db.execute(select(BuildingBlock).order_by(BuildingBlock.ad))
    ).scalars().all()
    return BlockListResponse(items=[_out(b, counts.get(b.ad, 0)) for b in rows])


@router.post("", response_model=BlockOut, status_code=201)
async def create_block(
    body: BlockCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> BlockOut:
    obj = BuildingBlock(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "Bu blok etiketi bu tesiste zaten kayitli.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(db, user, Action.BLOCK_CREATE, resource_type="building_block", resource_id=obj.id)
    counts = await _unit_counts(db)
    return _out(obj, counts.get(obj.ad, 0))


@router.patch("/{block_id}", response_model=BlockOut)
async def update_block(
    block_id: uuid.UUID,
    body: BlockUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> BlockOut:
    """Blogu YERINDE gunceller (ayni id). Etiket (ad) degisirse GERCEK
    yeniden-adlandirma: `unit.blok` zayif metin baglantidir (hard FK yok), bu
    yuzden ayni islemde bu blogun daireleri (blok == eski ad) YENI ada tasinir.
    Boylece daireler kopmaz ve eski etiketli "hayalet" blok kalmaz."""
    obj = await get_or_404(db, BuildingBlock, block_id)
    data = body.model_dump(exclude_unset=True)

    old_ad = obj.ad
    new_ad = data.get("ad")
    if new_ad is not None:
        new_ad = new_ad.strip()  # trimmed (pattern zaten bosluk yasaklar)
        data["ad"] = new_ad
        if new_ad != old_ad:
            # Tenant-ici benzersizlik on-kontrolu (RLS => yalniz bu tenant).
            dup = (
                await db.execute(
                    select(func.count())
                    .select_from(BuildingBlock)
                    .where(BuildingBlock.ad == new_ad, BuildingBlock.id != obj.id)
                )
            ).scalar_one()
            if dup:
                raise APIError(
                    422, "conflict", "Bu blok etiketi bu tesiste zaten kayitli."
                )

    for key, value in data.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()

    # Etiket degistiyse dairelerin zayif baglantisini ayni islemde tasi.
    if new_ad is not None and new_ad != old_ad:
        await db.execute(
            update(Unit)
            .where(Unit.blok == old_ad)
            .values(blok=new_ad, updated_at=func.now())
        )

    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):  # es zamanli yeniden-adlandirma yarisi
            raise APIError(409, "conflict", "Bu blok etiketi bu tesiste zaten kayitli.")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.BLOCK_UPDATE, resource_type="building_block",
        resource_id=obj.id, meta={"renamed": new_ad is not None and new_ad != old_ad},
    )
    counts = await _unit_counts(db)
    return _out(obj, counts.get(obj.ad, 0))


@router.delete("/{block_id}", status_code=204)
async def delete_block(
    block_id: uuid.UUID,
    cascade: bool = Query(
        False,
        description="true ise blogun daireleri (ve bagli kayitlari) da silinir.",
    ),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    """Blogu siler. Blogun daireleri varsa:
      * cascade=false (varsayilan) -> 409 (kaza korumasi; UI once onay ister).
      * cascade=true -> blogun daireleri (blok == ad) SILINIR; DB seviyesi
        ON DELETE CASCADE ile daireye bagli tum kayitlar da temizlenir
        (unit_resident, dues_assessment, dues_payment [budget_entry.ilgili_
        payment_id SET NULL], visitor, kargo, unit_access_permission,
        rezervasyon, unit_complaint). Tek islem/transaction; RLS => tenant-ici.
    RBAC: admin + yonetici (_MANAGER)."""
    obj = await get_or_404(db, BuildingBlock, block_id)
    kullanan = (
        await db.execute(
            select(func.count()).select_from(Unit).where(Unit.blok == obj.ad)
        )
    ).scalar_one()
    if kullanan and not cascade:
        raise APIError(
            409, "conflict",
            f"Bu blogu kullanan {kullanan} daire var; silmek icin onay gerekli.",
        )
    if kullanan:
        # Daireleri sil -> DB ON DELETE CASCADE bagli kayitlari temizler.
        await db.execute(delete(Unit).where(Unit.blok == obj.ad))
    await db.delete(obj)
    await db.flush()
    await audit_user(
        db, user, Action.BLOCK_DELETE, resource_type="building_block",
        resource_id=block_id, meta={"cascade": bool(cascade), "unit_count": kullanan},
    )
    return Response(status_code=204)
