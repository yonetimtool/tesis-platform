"""Unit (daire) CRUD + sakin atama — /contracts/openapi.yaml.

RBAC (D-viz Rev-1): daire CRUD + yerlesim (list/get/create/update/delete/layout)
admin + YONETICI (bina yerlesimi yonetimi). Sakin atama (residents alt-kaynagi)
ile aidat YALNIZ admin (yonetim/muhasebe islemi).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitGrup, UnitResident, UnitTip
from ..schemas import (
    ResidentAssign,
    UnitBulkCreate,
    UnitBulkResult,
    UnitCreate,
    UnitLayoutUpdate,
    UnitListResponse,
    UnitOut,
    UnitResidentBriefOut,
    UnitResidentOut,
    UnitUpdate,
)

router = APIRouter(prefix="/units", tags=["aidat"])


async def _tanim_dogrula(
    db: AsyncSession, tip_id: uuid.UUID | None, grup_id: uuid.UUID | None
) -> None:
    """Verilen tip/grup BU TENANT'ta var mi (P26).

    Bilesik FK zaten baska tenant'in tanimina baglanmayi engelliyor, ama o
    ihlal bir IntegrityError uretir ve kullaniciya "veri butunlugu" gibi
    okunur. Burada ONCEDEN olculur ve 422 `invalid_reference` doner.
    """
    for kimlik, model, metin in (
        (tip_id, UnitTip, "daire_tipi_bulunamadi"),
        (grup_id, UnitGrup, "daire_grubu_bulunamadi"),
    ):
        if kimlik is None:
            continue
        var = (
            await db.execute(select(model.id).where(model.id == kimlik))
        ).scalar_one_or_none()
        if var is None:
            raise APIError(422, "invalid_reference", metin)


async def _adlarla(db: AsyncSession, unitler: list[Unit]) -> list[UnitOut]:
    """Daireleri tip/grup ADLARIYLA birlikte serilestir (P26).

    Adlar TEK sorguda cozulur: liste basina daire x 2 istek (N+1) yapmak,
    200 daire cizen panelde 400 ek sorgu demekti. Ad yoksa (siniflandirmasiz
    ya da tanim silinmis daire) `null` doner — uydurma etiket YOK.
    """
    tip_idler = {u.unit_tip_id for u in unitler if u.unit_tip_id}
    grup_idler = {u.unit_grup_id for u in unitler if u.unit_grup_id}
    tip_ad: dict[uuid.UUID, str] = {}
    grup_ad: dict[uuid.UUID, str] = {}
    if tip_idler:
        tip_ad = dict(
            (await db.execute(
                select(UnitTip.id, UnitTip.ad).where(UnitTip.id.in_(tip_idler))
            )).all()
        )
    if grup_idler:
        grup_ad = dict(
            (await db.execute(
                select(UnitGrup.id, UnitGrup.ad).where(UnitGrup.id.in_(grup_idler))
            )).all()
        )
    return [
        UnitOut.model_validate(u).model_copy(update={
            "unit_tip_ad": tip_ad.get(u.unit_tip_id),
            "unit_grup_ad": grup_ad.get(u.unit_grup_id),
        })
        for u in unitler
    ]

_ADMIN = require_role("admin")
# Fiziksel yerlesim (blok/kat/sira) girisi — yonetim: admin + yonetici.
# (Genel daire CRUD admin-only kalir; yalniz yerlesim yonetici'ye acilir.)
_LAYOUT_EDITOR = require_role("admin", "yonetici")
# Yerlesim OKUMA: yonetim + saha (security/tesis_gorevlisi) — "Bina Duzenleme"
# ekranini SALT-OKUMA gorurler (yazma yine _LAYOUT_EDITOR = 403).
_LAYOUT_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")
# SAKIN-DAIRE BAGI (P23a) — admin + yonetici.
#
# Gerekce: sakin CRUD'u (`/residents`) ZATEN admin+yonetici. "Kim nerede
# oturuyor" ayni sinif veridir; bagi admin-only birakmak, mobilde sakin
# yoneten yoneticinin var olan bir sakine daire ATAYAMAMASI demekti — yani
# P23(a) uygulamadan ULASILAMAZ kaliyordu. Genel daire CRUD'u admin-only
# KALIR; acilan yalniz bagdir.
_BAG_YONETICI = require_role("admin", "yonetici")
# Hedef sakin secicisi (guvenlik ziyaretci kaydinda kullanir) — okuma
# guvenlik + yonetim; sakin komsularini LISTELEYEMEZ (403).
_RESIDENT_LISTER = require_role("security", "admin", "yonetici")


@router.get("", response_model=UnitListResponse)
async def list_units(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    blok: str | None = Query(None),
    aktif: bool | None = Query(None),
    unit_tip_id: uuid.UUID | None = Query(
        None, description="(P26) Tipe gore suzgec"
    ),
    unit_grup_id: uuid.UUID | None = Query(
        None, description="(P26) Gruba gore suzgec"
    ),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_READER),
) -> UnitListResponse:
    where = []
    if blok is not None:
        where.append(Unit.blok == blok)
    if aktif is not None:
        where.append(Unit.aktif == aktif)
    if unit_tip_id is not None:
        where.append(Unit.unit_tip_id == unit_tip_id)
    if unit_grup_id is not None:
        where.append(Unit.unit_grup_id == unit_grup_id)
    total = (await db.execute(select(func.count()).select_from(Unit).where(*where))).scalar_one()
    rows = (
        await db.execute(select(Unit).where(*where).order_by(Unit.no).limit(limit).offset(offset))
    ).scalars().all()
    return UnitListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _adlarla(db, list(rows)),
    )


@router.get("/{unit_id}", response_model=UnitOut)
async def get_unit(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_READER),
) -> UnitOut:
    obj = await get_or_404(db, Unit, unit_id)
    return (await _adlarla(db, [obj]))[0]


@router.get("/by-no/{unit_no}/residents", response_model=list[UnitResidentBriefOut])
async def list_unit_residents_by_no(
    unit_no: str,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_RESIDENT_LISTER),
) -> list[UnitResidentBriefOut]:
    """Bir dairenin AKTIF sakinleri (user_id + ad) — hedef sakin secicisi.

    Guvenlik daire NUMARASINI bilir (unit_id yetkisi yok); unit_no tenant
    icinde cozulur (RLS), bulunamazsa 404. Yalniz AKTIF baglantilar
    (bitis IS NULL). RBAC: security + admin + yonetici; resident 403.
    """
    unit = (
        await db.execute(select(Unit).where(Unit.no == unit_no))
    ).scalar_one_or_none()
    if unit is None:
        raise APIError(404, "not_found", "daire_bulunamadi")
    rows = (
        await db.execute(
            select(AppUser.id, AppUser.ad)
            .join(UnitResident, UnitResident.user_id == AppUser.id)
            .where(UnitResident.unit_id == unit.id, UnitResident.bitis.is_(None))
            .order_by(AppUser.ad)
        )
    ).all()
    return [UnitResidentBriefOut(user_id=r.id, ad=r.ad) for r in rows]


@router.post("", response_model=UnitOut, status_code=201)
async def create_unit(
    body: UnitCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> UnitOut:
    await _tanim_dogrula(db, body.unit_tip_id, body.unit_grup_id)
    obj = Unit(tenant_id=user.tenant_id, **body.model_dump(exclude_unset=True))
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "daire_no_zaten_kayitli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(db, user, Action.UNIT_CREATE, resource_type="unit", resource_id=obj.id)
    return (await _adlarla(db, [obj]))[0]


@router.post("/bulk", response_model=UnitBulkResult, status_code=201)
async def bulk_create_units(
    body: UnitBulkCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> UnitBulkResult:
    """Toplu daire olustur: kat_sayisi × kat_basi_daire adet, baslangic_no'dan
    ARDISIK (kat kat dolar). no = blok varsa '{blok}-{n}' yoksa '{n}'; zaten var
    olan no'lar ATLANIR (kalanlar olusturulur). Katlar 1..kat_sayisi, sira
    1..kat_basi_daire. RBAC admin+yonetici (create ile ayni).

    (P26) `unit_tip_id` / `unit_grup_id` verilirse PARTININ TAMAMINA uygulanir:
    toplu olusturmada daire basina tip secmek anlamsizdir, bir blok genelde
    tek tiptir. Daire basi istisnalar sonradan PATCH ile duzeltilir."""
    await _tanim_dogrula(db, body.unit_tip_id, body.unit_grup_id)
    # Plani kur: (no, kat, sira) — kat kat, ardisik numaralandirma.
    plan: list[tuple[str, int, int]] = []
    n = body.baslangic_no
    for kat in range(1, body.kat_sayisi + 1):
        for sira in range(1, body.kat_basi_daire + 1):
            no = f"{body.blok}-{n}"  # blok ZORUNLU (schema) => her zaman prefix'li
            plan.append((no, kat, sira))
            n += 1

    # Zaten var olan no'lari bul (RLS -> tenant-ici); onlari atla.
    nolar = [p[0] for p in plan]
    mevcut = set(
        (await db.execute(select(Unit.no).where(Unit.no.in_(nolar)))).scalars().all()
    )

    olusturulan: list[Unit] = []
    atlanan: list[str] = []
    for no, kat, sira in plan:
        if no in mevcut:
            atlanan.append(no)
            continue
        obj = Unit(
            tenant_id=user.tenant_id, no=no, blok=body.blok, kat=kat, sira=sira,
            unit_tip_id=body.unit_tip_id, unit_grup_id=body.unit_grup_id,
        )
        db.add(obj)
        olusturulan.append(obj)

    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            # es zamanli baska istek ayni no'lari eklemis olabilir.
            raise APIError(409, "conflict", "daire_no_cakismasi")
        raise translate_integrity(exc)
    for obj in olusturulan:
        await db.refresh(obj)

    return UnitBulkResult(
        olusturulan=await _adlarla(db, olusturulan),
        atlanan=atlanan,
        bitis_no=body.bitis_no,
    )


@router.patch("/{unit_id}", response_model=UnitOut)
async def update_unit(
    unit_id: uuid.UUID,
    body: UnitUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_EDITOR),
) -> UnitOut:
    obj = await get_or_404(db, Unit, unit_id)
    veri = body.model_dump(exclude_unset=True)
    # `null` GONDERILDIYSE siniflandirma KALDIRILIR; gonderilmediyse dokunulmaz
    # (`exclude_unset` ikisini ayirir). Dogrulama yalniz DOLU degerler icin.
    await _tanim_dogrula(db, veri.get("unit_tip_id"), veri.get("unit_grup_id"))
    for key, value in veri.items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "daire_no_zaten_kayitli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    return (await _adlarla(db, [obj]))[0]


@router.patch("/{unit_id}/layout", response_model=UnitOut)
async def update_unit_layout(
    unit_id: uuid.UUID,
    body: UnitLayoutUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_LAYOUT_EDITOR),
) -> Unit:
    """Daire fiziksel yerlesimini (blok/kat/sira) gunceller — bina semasi girisi.
    RBAC: admin + yonetici (digerleri 403). Yerlesim anonimligi etkilemez."""
    obj = await get_or_404(db, Unit, unit_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    return obj


@router.delete("/{unit_id}", status_code=204)
async def delete_unit(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_LAYOUT_EDITOR),
) -> Response:
    obj = await get_or_404(db, Unit, unit_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.UNIT_DELETE, resource_type="unit", resource_id=unit_id)
    return Response(status_code=204)


# ------------------------------ sakinler ----------------------------------- #
@router.get("/{unit_id}/residents", response_model=list[UnitResidentOut])
async def list_residents(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_BAG_YONETICI),
) -> list[UnitResident]:
    await get_or_404(db, Unit, unit_id)
    rows = (
        await db.execute(
            select(UnitResident)
            .where(UnitResident.unit_id == unit_id)
            .order_by(UnitResident.created_at)
        )
    ).scalars().all()
    return list(rows)


@router.post("/{unit_id}/residents", response_model=UnitResidentOut, status_code=201)
async def assign_resident(
    unit_id: uuid.UUID,
    body: ResidentAssign,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_BAG_YONETICI),
) -> UnitResident:
    await get_or_404(db, Unit, unit_id)
    target = (
        await db.execute(select(AppUser).where(AppUser.id == body.user_id))
    ).scalar_one_or_none()
    if target is None:
        raise APIError(422, "invalid_reference", "user_id_bulunamadi")
    if target.role != "resident":
        raise APIError(422, "invalid_reference", "atanacak_kullanici_resident_olmali")

    obj = UnitResident(
        tenant_id=user.tenant_id,
        unit_id=unit_id,
        user_id=body.user_id,
        rol_tipi=body.rol_tipi,
        baslangic=body.baslangic,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "kullanici_daireye_zaten_bagli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.RESIDENT_ASSIGN, resource_type="app_user",
        resource_id=body.user_id, meta={"unit_id": str(unit_id)},
    )
    return obj


@router.delete("/{unit_id}/residents/{user_id}", status_code=204)
async def remove_resident(
    unit_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_BAG_YONETICI),
) -> Response:
    await get_or_404(db, Unit, unit_id)
    binding = (
        await db.execute(
            select(UnitResident).where(
                UnitResident.unit_id == unit_id,
                UnitResident.user_id == user_id,
                UnitResident.bitis.is_(None),
            )
        )
    ).scalar_one_or_none()
    if binding is None:
        raise APIError(404, "not_found", "aktif_sakin_baglantisi_yok")
    binding.bitis = datetime.now(tz=timezone.utc)
    await db.flush()
    await audit_user(
        db, user, Action.RESIDENT_UNASSIGN, resource_type="app_user",
        resource_id=user_id, meta={"unit_id": str(unit_id)},
    )
    return Response(status_code=204)
