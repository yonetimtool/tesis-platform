"""Daire sikayeti (D1 + D-viz Rev-1) — sakin -> HEDEF DAIRE.

GIZLILIK KADEMESI (Rev-2, auth.md §4):
  * yonetici/admin (YONETIM): daire-basi ACIK sayi + renk (harita) + daire
    detayinda kategori + not + durum gorur. SIKAYET EDEN kimligini (complainant)
    ARTIK GORMEZ — yalniz 'sikayet edildigini' gorur, KIMIN ettigini degil.
  * resident: bina yerlesimini gorur ama SAYI/RENK GORMEZ (hangi dairenin kac
    sikayeti oldugunu bilemez). Yalniz KENDI BLOGUNDAKI daireleri secip sikayet
    eder (blok disi -> 403). Sikayet eden kimligi hicbir role gosterilmez.
  * security/tesis_gorevlisi: YALNIZ blok/kat yapisi (sayi/renk/sikayet yok).
  * resident KENDI sikayetlerini GET /mine ile gorur (gitti mi geri bildirimi;
    yogunluk/renk/complainant YOK, yalniz kendi kayitlari).

Spam korumasi (Rev-1.1 — HAFTALIK + KATEGORI-BAZLI): ayni sakin ayni daireye
ayni KATEGORIDE 7 gunde en fazla 1 sikayet (farkli kategori serbest; durumdan
bagimsiz). advisory xact-lock + sliding 7-gun penceresi ile YARISSIZ -> 409.
Renk (ACIK sikayet sayisi) — P24'te DORT KADEMEYE cikti:
  0 yesil · 1-2 sari · 3-4 kirmizi · 5+ mor

Eskiden uc kademeydi (0-2 yesil, 3-4 sari, 5+ kirmizi) ve TEK sikayet almis
bir daire, hic sikayet almamis daireyle AYNI renkteydi — yonetim ilk sinyali
goremiyordu. Yeni skalada 0 ile 1 arasindaki fark GORUNUR.

ESIKLERIN OKUNUSU (Kerem'in "0=yesil, 1-2=sari, 3-4=kirmizi, 4+=mor"
ifadesinde 3-4 ile 4+ CAKISIYOR): cakismayan tek okuma 5+ = mor'dur ve oyle
uygulandi. Esikler `_ESIKLER` tablosunda TEK YERDE durur — P37'nin sifirlama
kurali sayaci sifirlayinca skala kendiliginden yesile doner ve tenant basina
yapilandirilabilir hale getirmek icin degistirilecek tek yer burasidir.
"""
from __future__ import annotations

import logging

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import and_, func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..gurultu_akisi import esik_kontrol
from ..errors import APIError
from ..models import AppUser, Unit, UnitComplaint, UnitComplaintOkuma, UnitResident
from ..schemas import (
    BuildingMapBlok,
    BuildingMapKat,
    BuildingMapResponse,
    BuildingMapUnit,
    UnitComplaintCreate,
    UnitComplaintDecision,
    UnitComplaintDurum,
    UnitComplaintKategori,
    UnitComplaintListResponse,
    UnitComplaintOut,
    UnitDensityItem,
    UnitDensityResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/unit-complaints", tags=["unit-complaints"])

# Sikayet ACMA yalniz sakin (kendi blogundaki daireyi bildirir).
_FILER = require_role("resident")
# Bina yapisi (harita) OKUMA — tum roller (yapi herkese; sayi/renk yalniz yonetim).
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
# Yogunluk/liste/kapatma — YONETIM (sayi/renk/complainant denetim gorunumu).
_MANAGER = require_role("admin", "yonetici")
# Yonetim rolleri: sayi + renk + complainant + not gorur.
_MANAGEMENT = {"admin", "yonetici"}


#: (ust sinir DAHIL, renk) — son satir yakalayici (None = sinirsiz).
#: Tek dogruluk kaynagi: istemci bunu TEKRARLAMAZ, rengi sunucudan alir.
_ESIKLER: tuple[tuple[int | None, str], ...] = (
    (0, "yesil"),
    (2, "sari"),
    (4, "kirmizi"),
    (None, "mor"),
)


def _color(count: int) -> str:
    """ACIK sikayet sayisindan renk (P24 — dort kademe).

    Sayim tabani ACIK sikayetlerdir (`durum='acik'`): kapatilan sikayet
    skalayi dusurur. P37 esige varinca sayaci SIFIRLAR — o zaman da bu ayni
    fonksiyon dogal olarak yesile doner; ayri bir "sifirlama rengi" yoktur.
    """
    for ust, renk in _ESIKLER:
        if ust is None or count <= ust:
            return renk
    return _ESIKLER[-1][1]


async def _resident_blocks(db: AsyncSession, user: AppUser) -> set[str | None]:
    """Sakinin AKTIF dairelerinin blok etiketleri (None dahil — blok-suz site).
    Own-block kurali: sakin yalniz bu bloklardaki daireleri gorebilir/sikayet
    edebilir. Aktif dairesi yoksa bos kume (hicbir yere sikayet edemez)."""
    rows = await db.execute(
        select(Unit.blok)
        .join(
            UnitResident,
            and_(
                UnitResident.unit_id == Unit.id,
                UnitResident.user_id == user.id,
                UnitResident.bitis.is_(None),
            ),
        )
    )
    return set(rows.scalars().all())


# ------------------------------- kayit -------------------------------------- #
@router.post("", response_model=UnitComplaintOut, status_code=201)
async def file_unit_complaint(
    body: UnitComplaintCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FILER),
) -> UnitComplaintOut:
    # Hedef daire ayni tenant'ta olmali (RLS + kontrol). Baska tenant/olmayan -> 422.
    unit = (
        await db.execute(select(Unit).where(Unit.id == body.target_unit_id))
    ).scalar_one_or_none()
    if unit is None:
        raise APIError(422, "invalid_reference", "hedef_daire_bulunamadi")

    # OWN-BLOCK (Rev-1): sakin yalniz KENDI blogundaki daireyi sikayet edebilir.
    my_blocks = await _resident_blocks(db, user)
    if unit.blok not in my_blocks:
        raise APIError(403, "forbidden", "sikayet_yalniz_kendi_blok")

    # SPAM KORUMASI (Rev-1.1 — HAFTALIK + KATEGORI-BAZLI, YARISSIZ):
    # ayni sikayetci ayni daireye ayni KATEGORIDE 7 gunde en fazla 1 (farkli
    # kategori serbest; durumdan bagimsiz). Es zamanli iki istek yarissa
    # cift kayit olusmasin diye (complainant,unit,kategori) icin transaction-
    # kapsamli advisory lock alinir; ardindan sliding 7-gun penceresi kontrol
    # edilir. Kilit transaction bitince (commit/rollback) otomatik birakilir.
    await db.execute(
        text("SELECT pg_advisory_xact_lock(hashtext(:k)::bigint)"),
        {"k": f"uc:{user.id}:{unit.id}:{body.kategori}"},
    )
    son = (
        await db.execute(
            select(UnitComplaint.id).where(
                UnitComplaint.complainant_user_id == user.id,
                UnitComplaint.target_unit_id == unit.id,
                UnitComplaint.kategori == body.kategori,
                UnitComplaint.created_at >= text("now() - interval '7 days'"),
            ).limit(1)
        )
    ).scalar_one_or_none()
    if son is not None:
        raise APIError(409, "conflict", "sikayet_haftalik_limit")

    obj = UnitComplaint(
        tenant_id=user.tenant_id,
        target_unit_id=unit.id,
        complainant_user_id=user.id,  # IC — resident'a donmez
        kategori=body.kategori,
        notlar=body.notlar,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # NOT: meta'da complainant kimligi YOK (anonimlik) — yalniz hedef daire.
    await audit_user(
        db, user, Action.UNIT_COMPLAINT_FILE, resource_type="unit_complaint",
        resource_id=obj.id, meta={"target_unit_id": str(obj.target_unit_id)},
    )
    # (P37) CAYDIRICI KANCASI: esik asildiysa uyari uretilir ve o dairenin
    # gurultu sayaci SIFIRLANIR. Sikayet kaydi bunun sonucuna BAGLI DEGILDIR
    # — caydiricinin basarisiz olmasi kullanicinin beyanini dusurmemeli.
    try:
        await esik_kontrol(db, tenant_id=user.tenant_id, unit=unit)
    except Exception:  # noqa: BLE001 — kanca ucu ASLA dusurmez
        logger.exception("gurultu caydiricisi basarisiz (sikayet kaydi durur)")

    # Sikayet acan kendi kaydini gorur (kendi notu) — complainant kimligini
    # tekrar donmeye gerek yok (kendisi zaten biliyor; residentta hep None).
    return UnitComplaintOut.from_model(obj, unit_no=unit.no, include_note=True)


# ------------------------------ yogunluk ------------------------------------ #
@router.get("/density", response_model=UnitDensityResponse)
async def unit_density(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> UnitDensityResponse:
    """Daire-basi ACIK sikayet sayisi + renk — YALNIZ YONETIM (denetim).
    residentlar sayilari GOREMEZ (Rev-1); bkz. /building-map (rol-farkinda)."""
    rows = (
        await db.execute(
            select(
                Unit.id,
                Unit.no,
                Unit.blok,
                func.count(UnitComplaint.id),
            )
            .select_from(Unit)
            .outerjoin(
                UnitComplaint,
                and_(
                    UnitComplaint.target_unit_id == Unit.id,
                    UnitComplaint.durum == "acik",
                ),
            )
            .group_by(Unit.id, Unit.no, Unit.blok)
            .order_by(Unit.no)
        )
    ).all()
    items = [
        UnitDensityItem(
            target_unit_id=r[0],
            unit_no=r[1],
            blok=r[2],
            acik_sayisi=r[3],
            renk=_color(r[3]),
        )
        for r in rows
    ]
    return UnitDensityResponse(items=items)


# --------------------------- sikayetlerim (resident) ------------------------ #
@router.get("/mine", response_model=UnitComplaintListResponse)
async def my_unit_complaints(
    durum: UnitComplaintDurum | None = Query(None),
    kategori: UnitComplaintKategori | None = Query(
        None, description="Kategori suzgeci (orn. gurultu) — ana ekran sayaci"
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FILER),
) -> UnitComplaintListResponse:
    """Sakinin KENDI actigi sikayetler (sikayet gitti mi geri bildirimi) —
    YALNIZ resident. Alanlar: hedef unit_no + kategori + tarih + durum. Baska
    sakinlerin kayitlari YOK; yogunluk/renk YOK; complainant (kendisi) OMITTED.
    Kendi notunu gorur.

    Ana ekran "Gurultu Sikayeti" sayaci (G6):
    `?kategori=gurultu&durum=acik&limit=1` -> `meta.total`."""
    base = (
        select(UnitComplaint, Unit.no)
        .join(Unit, Unit.id == UnitComplaint.target_unit_id)
        .where(UnitComplaint.complainant_user_id == user.id)
    )
    if durum is not None:
        base = base.where(UnitComplaint.durum == durum)
    if kategori is not None:
        base = base.where(UnitComplaint.kategori == kategori)

    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            base.order_by(UnitComplaint.created_at.desc(), UnitComplaint.id.desc()).limit(limit).offset(offset)
        )
    ).all()
    return UnitComplaintListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            # complainant OMITTED (kendisi) — include_complainant=False.
            UnitComplaintOut.from_model(obj, unit_no=no, include_note=True)
            for obj, no in rows
        ],
    )


# ------------------------------ bina haritasi ------------------------------- #
@router.get("/building-map", response_model=BuildingMapResponse)
async def building_map(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> BuildingMapResponse:
    """ROL-FARKINDA bina semasi (blok -> kat -> daire):
      * yonetici/admin: sayim + renk dolu (shows_density=True).
      * resident: YALNIZ KENDI blogundaki daireler; genel sayim/renk NULL (yapi —
        sikayet secici). AYRICA KENDI sikayet ettigi daireler isaretlenir
        (benim_sikayetim + benim_acik_sayisi — YALNIZ kendi kayitlarindan turer).
      * security/tesis_gorevlisi: TUM yapi; sayim/renk NULL.
    Sikayet eden verisi (baskalarinin) bu uctan ASLA donmez; genel yogunluk
    residenta sizmaz."""
    is_mgmt = user.role in _MANAGEMENT
    is_resident = user.role == "resident"
    resident_blocks: set[str | None] | None = None
    # resident: KENDI acik sikayetlerinin daire-basi sayisi (yalniz kendi
    # kayitlarindan; complainant == kendisi). Baskalarinin verisi ASLA girmez.
    own_open: dict[uuid.UUID, int] = {}
    if is_resident:
        resident_blocks = await _resident_blocks(db, user)
        own_rows = (
            await db.execute(
                select(
                    UnitComplaint.target_unit_id,
                    func.count(UnitComplaint.id),
                )
                .where(
                    UnitComplaint.complainant_user_id == user.id,
                    UnitComplaint.durum == "acik",
                )
                .group_by(UnitComplaint.target_unit_id)
            )
        ).all()
        own_open = {uid: n for uid, n in own_rows}

    rows = (
        await db.execute(
            select(
                Unit.id,
                Unit.no,
                Unit.blok,
                Unit.kat,
                Unit.sira,
                func.count(UnitComplaint.id),
            )
            .select_from(Unit)
            .outerjoin(
                UnitComplaint,
                and_(
                    UnitComplaint.target_unit_id == Unit.id,
                    UnitComplaint.durum == "acik",
                ),
            )
            .group_by(Unit.id, Unit.no, Unit.blok, Unit.kat, Unit.sira)
            .order_by(Unit.no)
        )
    ).all()

    unplaced: list[BuildingMapUnit] = []
    grouped: dict[str, dict[int, list[BuildingMapUnit]]] = {}
    for uid, no, blok, kat, sira, count in rows:
        # resident: yalniz kendi blogu (own-block picker kapsami).
        if resident_blocks is not None and blok not in resident_blocks:
            continue
        # resident: KENDI acik sikayet sayim (0 dahil); diger rollerde None.
        benim_acik = own_open.get(uid, 0) if is_resident else None
        item = BuildingMapUnit(
            unit_id=uid,
            unit_no=no,
            blok=blok,
            kat=kat,
            sira=sira,
            # Sayim + renk YALNIZ yonetime; digerinde None (yapi gorunumu).
            complaint_count=count if is_mgmt else None,
            color=_color(count) if is_mgmt else None,
            # KENDI sikayet isareti — yalniz resident icin (kendi kayitlarindan).
            benim_sikayetim=bool(benim_acik) if is_resident else False,
            benim_acik_sayisi=benim_acik,
        )
        if blok is None or kat is None:
            unplaced.append(item)
        else:
            grouped.setdefault(blok, {}).setdefault(kat, []).append(item)

    bloklar = [
        BuildingMapBlok(
            blok=blok,
            katlar=[
                BuildingMapKat(
                    kat=kat,
                    units=sorted(
                        units,
                        key=lambda u: (u.sira is None, u.sira or 0, u.unit_no),
                    ),
                )
                for kat, units in sorted(katlar.items())
            ],
        )
        for blok, katlar in sorted(grouped.items())
    ]
    return BuildingMapResponse(shows_density=is_mgmt, bloklar=bloklar, unplaced=unplaced)


# ------------------------------- liste -------------------------------------- #
@router.get("", response_model=UnitComplaintListResponse)
async def list_unit_complaints(
    target_unit_id: uuid.UUID | None = Query(None),
    durum: UnitComplaintDurum | None = Query(None),
    kategori: UnitComplaintKategori | None = Query(
        None, description="Kategori suzgeci (orn. gurultu)"
    ),
    okunmamis: bool | None = Query(
        None,
        description=(
            "true: YALNIZ isteyen yoneticinin okumadiklari (Yeni sekmesi). "
            "false: yalniz okuduklari. Bos: hepsi."
        ),
    ),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> UnitComplaintListResponse:
    """Daire sikayetleri — YALNIZ YONETIM. kategori + tarih + durum + not.
    SIKAYET EDEN kimligi (complainant) ARTIK DONMEZ (gizlilik: yonetim yalniz
    'sikayet edildigini' gorur, KIMIN ettigini degil). residentlar bu uca
    ERISEMEZ (403).

    `okunmamis` suzgeci ISTEYEN yoneticiye goredir (P24): okuma durumu kisi
    basinadir, bir yoneticinin okumasi digerinin kuyrugunu bosaltmaz. Rozet
    sayisi ayri bir uc gerektirmez — `?okunmamis=true&limit=1` cagrisinin
    `meta.total` degeri rozetin ta kendisidir.
    """
    # Okuma kaydini LEFT JOIN ile getir: `okundu` alanini doldurmak icin her
    # kosulda gerekli (suzgec verilmese de listede rozet gosterilir).
    okuma = (
        select(UnitComplaintOkuma.unit_complaint_id)
        .where(UnitComplaintOkuma.user_id == user.id)
        .subquery()
    )
    base = (
        select(UnitComplaint, Unit.no, okuma.c.unit_complaint_id)
        .join(Unit, Unit.id == UnitComplaint.target_unit_id)
        .join(okuma, okuma.c.unit_complaint_id == UnitComplaint.id, isouter=True)
    )
    if okunmamis is True:
        base = base.where(okuma.c.unit_complaint_id.is_(None))
    elif okunmamis is False:
        base = base.where(okuma.c.unit_complaint_id.is_not(None))
    if target_unit_id is not None:
        base = base.where(UnitComplaint.target_unit_id == target_unit_id)
    if durum is not None:
        base = base.where(UnitComplaint.durum == durum)
    if kategori is not None:
        base = base.where(UnitComplaint.kategori == kategori)

    total = (
        await db.execute(select(func.count()).select_from(base.subquery()))
    ).scalar_one()
    rows = (
        await db.execute(
            base.order_by(UnitComplaint.created_at.desc(), UnitComplaint.id.desc()).limit(limit).offset(offset)
        )
    ).all()
    return UnitComplaintListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            # complainant ARTIK DONMEZ (include_complainant=False, gizlilik).
            UnitComplaintOut.from_model(
                obj, unit_no=no, include_note=True, okundu=okundu_id is not None
            )
            for obj, no, okundu_id in rows
        ],
    )


@router.post("/{complaint_id}/okundu", response_model=UnitComplaintOut)
async def mark_unit_complaint_read(
    complaint_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> UnitComplaintOut:
    """Sikayeti ISTEYEN yonetici icin okundu isaretler (P24 triyaj).

    IDEMPOTENT: ikinci cagri 409 vermez, ayni sonucu doner (istemci listeyi
    tazelerken ayni satiri iki kez isaretleyebilir). Geri alma yoktur —
    "okunmamis" kuyrugu bir is listesidir, gecmis degil.
    """
    await get_or_404(db, UnitComplaint, complaint_id)  # tenant + varlik denetimi
    var = (
        await db.execute(
            select(UnitComplaintOkuma.id).where(
                and_(
                    UnitComplaintOkuma.unit_complaint_id == complaint_id,
                    UnitComplaintOkuma.user_id == user.id,
                )
            )
        )
    ).scalar_one_or_none()
    if var is None:
        db.add(
            UnitComplaintOkuma(
                tenant_id=user.tenant_id,
                unit_complaint_id=complaint_id,
                user_id=user.id,
            )
        )
        await db.flush()
    obj = await get_or_404(db, UnitComplaint, complaint_id)
    unit_no = (
        await db.execute(select(Unit.no).where(Unit.id == obj.target_unit_id))
    ).scalar_one_or_none()
    return UnitComplaintOut.from_model(
        obj, unit_no=unit_no, include_note=True, okundu=True
    )


# ------------------------------- kapatma ------------------------------------ #
@router.post("/{complaint_id}/withdraw", response_model=UnitComplaintOut)
async def withdraw_unit_complaint(
    complaint_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_FILER),
) -> UnitComplaintOut:
    """(P146) SIKAYET EDEN kendi sikayetini GERI CEKER — silmez.

    Gizlilik korunur: kayit `complainant_user_id`yi ZATEN ic alan olarak
    tutuyor (disari donmez); burada yalnizca ESLESME icin kullanilir.
    Baskasinin sikayeti icin 404 doner — varligi da sizdirilmaz.

    Yalniz `acik` sikayet geri alinir: yonetim kapattiktan sonra karar
    verilmis bir kaydi sahibi tek tarafli degistiremez.
    """
    obj = (
        await db.execute(
            select(UnitComplaint).where(
                and_(
                    UnitComplaint.id == complaint_id,
                    UnitComplaint.complainant_user_id == user.id,
                )
            )
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "kayit_bulunamadi")
    if obj.durum != "acik":
        raise APIError(
            422, "invalid_transition", "gecersiz_durum_gecisi",
            mevcut=obj.durum, hedef="geri_alindi",
        )
    obj.durum = "geri_alindi"
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.UNIT_COMPLAINT_WITHDRAW,
        resource_type="unit_complaint", resource_id=obj.id,
    )
    unit_no = (
        await db.execute(select(Unit.no).where(Unit.id == obj.target_unit_id))
    ).scalar_one_or_none()
    return UnitComplaintOut.from_model(obj, unit_no=unit_no, include_note=False)


@router.patch("/{complaint_id}", response_model=UnitComplaintOut)
async def close_unit_complaint(
    complaint_id: uuid.UUID,
    body: UnitComplaintDecision,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> UnitComplaintOut:
    """Yonetim durumu degistirir (kapali). Kapatma ACIK sayimi dusurur (renk
    feedback). Not doner; complainant kimligi ARTIK DONMEZ (gizlilik)."""
    obj = await get_or_404(db, UnitComplaint, complaint_id)
    obj.durum = body.durum
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.UNIT_COMPLAINT_CLOSE, resource_type="unit_complaint",
        resource_id=obj.id, meta={"durum": obj.durum},
    )
    unit_no = (
        await db.execute(
            select(Unit.no).where(Unit.id == obj.target_unit_id)
        )
    ).scalar_one_or_none()
    # Okuma durumu da donsun: istemci kapattigi satiri listede yerinde
    # tazeliyor; None donseydi okunmus satir tekrar OKUNMAMIS gorunurdu.
    okundu = (
        await db.execute(
            select(UnitComplaintOkuma.id).where(
                and_(
                    UnitComplaintOkuma.unit_complaint_id == obj.id,
                    UnitComplaintOkuma.user_id == user.id,
                )
            )
        )
    ).scalar_one_or_none() is not None
    return UnitComplaintOut.from_model(
        obj, unit_no=unit_no, include_note=True, okundu=okundu
    )
