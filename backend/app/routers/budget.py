"""Butce modulu (Wave 2A+2B) — dinamik kategoriler + gelir/gider defteri + ozet.

RBAC (auth.md §4): yonetim (admin + yonetici) TAM yetkili (kategori CRUD,
defter, ozet). SEFFAFLIK (Wave 2B): `GET /budget/summary` agregat oldugu icin
TUM rollere aciktir — sakin/saha sitenin toplam gelir/gider/kasasini gorur ama
defter SATIRLARINI ve kisi/daire bazli veriyi GOREMEZ (403).
Para HER YERDE integer KURUS (dues deseni; float asla). tenant token'dan; RLS.

Kategori silme stratejisi: SOFT-DELETE (PATCH aktif=false). Hard DELETE ucu
bilincli olarak YOK; hareketi olan kategori DB'de de FK RESTRICT ile korunur.
Pasif kategoriye YENI kayit yazilamaz; eski kayitlar kategorisini korur.

===========================================================================
(P192 §1) DEFTER ARTIK `budget_entry` DEGIL `finansal_hareket`
===========================================================================
`budget_entry` uçüncü bir para defteriydi: kasa bagi yoktu, DELETE
edilebiliyordu ve aidat odemesinden OTOMATIK bir kopya uretiyordu
(`ensure_dues_income_entry`). Ayni para hem orada hem `finansal_hareket`te
duruyor, seffaflik raporu ile finans ozeti ayni ayda farkli gider
gosterebiliyordu.

Bu modulun UCLARI ve YANIT BICIMI aynen durur; altlarindaki tablo
`finansal_hareket` oldu (goc 0083 manuel satirlari tasidi). Kategori
taksonomisi (`budget_category`) KORUNDU ve defter satirinda
`budget_category_id` olarak yasiyor.

IKI DAVRANIS DEGISTI ve ikisi de bilincli:
  * DELETE artik SATIR SILMEZ, TERS KAYIT yazar (defterde DELETE yetkisi
    goc 0047'de geri alindi). Yanit yine 204.
  * Her yazma DENETIME islenir (P192 §6.1): bu modulde tek bir
    `audit_user` cagrisi YOKTU ve seffaflik yayinini besleyen defter
    denetim izi olmadan yaziliyordu.
"""
from __future__ import annotations

import logging
import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..belge_no import belge_no_ata
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from .. import defter
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, BudgetCategory, ButceHedefi, FinansalHareket
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
    ButceHedefiCreate,
    ButceHedefiListResponse,
    ButceHedefiOut,
    ButceKarsilastirma,
    ButceKarsilastirmaSatiri,
)

log = logging.getLogger(__name__)

router = APIRouter(prefix="/budget", tags=["budget"])

_MANAGER = require_role("admin", "yonetici")
# (P128) Defter/kategori LISTELERI okunur; yazma _MANAGER'da kalir.
_DEFTER_OKUR = require_role("admin", "yonetici", "denetci")
# Ozet (agregat) Wave 2B'de SEFFAFLIK icin tum rollere acik — satir/kisi
# verisi icermez; defter + kategori yonetimi _MANAGER'da kalir.
_SUMMARY_READER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    # (P128) Denetci butce ozetini OKUR; defter/kategori YAZMA _MANAGER'da
    # kalir (denetci hicbir mutasyon ucunda yoktur).
    "denetci",
)

# (P192 §1) `AIDAT_KATEGORI_AD` buradan `app/defter.py`ye TASINDI: aidat
# tahsilati artik ayri bir butce satiri uretmiyor, TAHSILAT SATIRININ
# KENDISI o kategoriye ait. Sabiti burada birakmak, kimsenin okumadigi
# ikinci bir dogruluk kaynagi olurdu.

_CAT_CONFLICT = APIError(409, "conflict", "butce_kategori_ad_tip_var")


def date_filters(
    donem: str | None, baslangic: date | None, bitis: date | None
) -> list:
    """donem VEYA (baslangic/bitis) → tarih kosullari. donem oncelikli."""
    if donem is not None:
        first, last = defter.donem_araligi(donem)
        return [FinansalHareket.tarih >= first, FinansalHareket.tarih <= last]
    where = []
    if baslangic is not None:
        where.append(FinansalHareket.tarih >= baslangic)
    if bitis is not None:
        where.append(FinansalHareket.tarih <= bitis)
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
    _: AppUser = Depends(_DEFTER_OKUR),
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
            select(BudgetCategory).where(*where).order_by(BudgetCategory.ad, BudgetCategory.id).limit(limit).offset(offset)
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
#: Defterdeki hangi tipler butce defterinde gorunur. `tahsilat` GELIR
#: sayilir: eskiden aidat odemesi `budget_entry`e kaynak='aidat_odeme'
#: gelir satiri olarak yaziliyordu ve butce ozeti onu iceriyordu. Disarida
#: biraksaydik sitenin geliri bir gecede aidat kadar dusuk gorunurdu.
_DEFTER_TIPLERI = ("gelir", "gider", "tahsilat")


def _tip(h: FinansalHareket) -> str:
    return "gelir" if h.tip in ("gelir", "tahsilat") else "gider"


def _kaynak(h: FinansalHareket) -> str:
    """Satir elle mi girildi, aidat odemesinden mi geldi.

    `kaynak` bir SUTUN degil, TIPTEN TURETILIR: tek defterde aidat
    tahsilatinin kendisi zaten `tip='tahsilat'`tir ve ayrica bir kaynak
    etiketi tutmak, iki alanin gunun birinde ayrisma riskini acardi.
    """
    return "aidat_odeme" if h.tip == "tahsilat" else "manuel"


def _entry_out(h: FinansalHareket, kategori_ad: str | None) -> BudgetEntryOut:
    return BudgetEntryOut(
        id=h.id,
        kategori_id=h.budget_category_id,
        kategori_ad=kategori_ad,
        tip=_tip(h),
        tutar_kurus=h.tutar_kurus,
        tarih=h.tarih,
        aciklama=h.aciklama,
        kaynak=_kaynak(h),
        # Aidat satirinda "ilgili odeme" SATIRIN KENDISIDIR: odeme ile
        # gelir kaydi artik ayri iki satir degil.
        ilgili_payment_id=h.id if h.tip == "tahsilat" else None,
        created_by=h.kaydeden_user_id,
        created_at=h.created_at,
    )


async def _kategori_adlari(
    db: AsyncSession, satirlar: list[FinansalHareket]
) -> dict[uuid.UUID, str]:
    idler = {h.budget_category_id for h in satirlar if h.budget_category_id}
    if not idler:
        return {}
    return dict(
        (
            await db.execute(
                select(BudgetCategory.id, BudgetCategory.ad)
                .where(BudgetCategory.id.in_(idler))
            )
        ).all()
    )


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
        raise APIError(422, "invalid_reference", "butce_kategori_bulunamadi")
    if not cat.aktif:
        raise APIError(422, "invalid_reference", "butce_pasif_kategoriye_yazilamaz")

    obj = FinansalHareket(
        tenant_id=user.tenant_id,
        tip=cat.tip,  # kategoriden turetilir — uyusmazlik imkansiz
        # GELIR kasaya GIRER, GIDER kasadan CIKAR — yon istemciden alinmaz.
        yon="giris" if cat.tip == "gelir" else "cikis",
        tutar_kurus=body.tutar_kurus,
        tarih=body.tarih,
        # Kasasiz bir defter satiri hicbir kasa bakiyesinde gorunmezdi
        # (P192 §2.1); verilmediyse merkez kasa cozulur/acilir.
        kasa_id=await defter.kasa_coz(db, user.tenant_id),
        aciklama=body.aciklama,
        budget_category_id=cat.id,
        kaydeden_user_id=user.id,
        belge_no=await belge_no_ata(
            db, user.tenant_id, cat.tip, None, body.tarih
        ),
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # (P192 §6.1) Bu modulde denetim izi YOKTU.
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        resource_id=obj.id,
        meta={"kaynak": "butce", "tip": cat.tip, "tutar_kurus": obj.tutar_kurus,
              "kategori_id": str(cat.id)},
    )
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
    _: AppUser = Depends(_DEFTER_OKUR),
) -> BudgetEntryListResponse:
    where = date_filters(donem, baslangic, bitis)
    where.append(FinansalHareket.tip.in_(_DEFTER_TIPLERI))
    # Iptal edilmis satirlar ve iptal satirlarinin kendisi defterde
    # GORUNMEZ: butce defteri "gerceklesen" listesidir.
    where.append(FinansalHareket.durum == defter.GERCEKLESEN)
    where.append(FinansalHareket.id.notin_(defter.iptal_edilmis()))
    if tip is not None:
        where.append(
            FinansalHareket.tip.in_(("gelir", "tahsilat")) if tip == "gelir"
            else FinansalHareket.tip == "gider"
        )
    if kategori_id is not None:
        where.append(FinansalHareket.budget_category_id == kategori_id)
    if kaynak is not None:
        where.append(
            FinansalHareket.tip == "tahsilat" if kaynak == "aidat_odeme"
            else FinansalHareket.tip.in_(("gelir", "gider"))
        )

    total = (
        await db.execute(select(func.count()).select_from(FinansalHareket).where(*where))
    ).scalar_one()
    rows = list(
        (
            await db.execute(
                select(FinansalHareket)
                .where(*where)
                .order_by(FinansalHareket.tarih.desc(),
                          FinansalHareket.created_at.desc(),
                          FinansalHareket.id.desc())
                .limit(limit)
                .offset(offset)
            )
        ).scalars().all()
    )
    adlar = await _kategori_adlari(db, rows)
    return BudgetEntryListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_entry_out(h, adlar.get(h.budget_category_id)) for h in rows],
    )


async def _manual_entry_or_error(
    db: AsyncSession, entry_id: uuid.UUID
) -> FinansalHareket:
    obj = await get_or_404(db, FinansalHareket, entry_id)
    if obj.tip not in ("gelir", "gider"):
        # Otomatik aidat kaydi defterden elle oynanamaz — aidat mutabakati
        # bozulmasin (odeme iptali/duzeltmesi aidat modulunun isi).
        raise APIError(422, "invalid_reference", "butce_otomatik_aidat_kaydi")
    return obj


@router.patch("/entries/{entry_id}", response_model=BudgetEntryOut)
async def update_entry(
    entry_id: uuid.UUID,
    body: BudgetEntryUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> BudgetEntryOut:
    obj = await _manual_entry_or_error(db, entry_id)
    data = body.model_dump(exclude_unset=True)
    eski = {"tutar_kurus": obj.tutar_kurus, "tarih": str(obj.tarih),
            "kategori_id": str(obj.budget_category_id)}

    if "kategori_id" in data:
        cat = (
            await db.execute(
                select(BudgetCategory).where(BudgetCategory.id == data["kategori_id"])
            )
        ).scalar_one_or_none()
        if cat is None:
            raise APIError(422, "invalid_reference", "butce_kategori_bulunamadi")
        if not cat.aktif:
            raise APIError(422, "invalid_reference", "butce_pasif_kategoriye_tasinamaz")
        obj.tip = cat.tip  # tip kategoriyle birlikte guncellenir
        obj.yon = "giris" if cat.tip == "gelir" else "cikis"
        obj.budget_category_id = cat.id

    for key, value in data.items():
        if key == "kategori_id":
            continue
        setattr(obj, key, value)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # (P192 §6.1) ESKI/YENI deger denetime yazilir: defter satirinin tutari
    # degistiyse bunun izi kalmali.
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        resource_id=obj.id,
        meta={"kaynak": "butce_duzenleme", "eski": eski,
              "yeni": {"tutar_kurus": obj.tutar_kurus, "tarih": str(obj.tarih),
                       "kategori_id": str(obj.budget_category_id)}},
    )
    kategori_ad = (
        await db.execute(
            select(BudgetCategory.ad)
            .where(BudgetCategory.id == obj.budget_category_id)
        )
    ).scalar_one_or_none()
    return _entry_out(obj, kategori_ad)


@router.delete("/entries/{entry_id}", status_code=204)
async def delete_entry(
    entry_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    """Defter satirini KALDIR — ters kayitla (P192 §1).

    SATIR SILINMEZ: `finansal_hareket` uzerinde app_rw'nin DELETE yetkisi
    goc 0047'de geri alindi ve bu bilincli. Silme, "bu para nereye gitti"
    sorusunu cevapsiz birakirdi. Yerine TAM TUTARLI ters kayit yazilir;
    listeler iki satiri da gostermez cunku ikisi birbirini goturur.
    """
    obj = await _manual_entry_or_error(db, entry_id)
    zaten = (
        await db.execute(
            select(FinansalHareket.id)
            .where(FinansalHareket.ters_kayit_id == obj.id)
        )
    ).first()
    if zaten is not None:
        raise APIError(409, "conflict", "hareket_zaten_iptal")
    ters = FinansalHareket(
        tenant_id=obj.tenant_id,
        tip="iptal",
        yon="cikis" if obj.yon == "giris" else "giris",
        tutar_kurus=obj.tutar_kurus,
        tarih=obj.tarih,
        kasa_id=obj.kasa_id,
        budget_category_id=obj.budget_category_id,
        ters_kayit_id=obj.id,
        aciklama=obj.aciklama,
        kaydeden_user_id=user.id,
        belge_no=await belge_no_ata(db, obj.tenant_id, "iptal", None, obj.tarih),
    )
    db.add(ters)
    await db.flush()
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        resource_id=ters.id,
        meta={"kaynak": "butce_iptal", "iptal_edilen": str(obj.id),
              "tutar_kurus": obj.tutar_kurus},
    )
    return Response(status_code=204)


# -------------------------------- ozet -------------------------------------- #
@router.get("/summary", response_model=BudgetSummary)
async def budget_summary(
    donem: str | None = Query(None, description="'YYYY-MM' — ay bazli ozet"),
    baslangic: date | None = Query(None),
    bitis: date | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    # Seffaflik (Wave 2B): agregat ozet TUM rollere acik.
    _: AppUser = Depends(_SUMMARY_READER),
) -> BudgetSummary:
    if donem is not None:
        ilk, son = defter.donem_araligi(donem)
    else:
        ilk, son = baslangic, bitis

    # TEK KAYNAK (P192 §1): rapor, seffaflik ve panel ozeti de bunlari cagirir.
    gelir = await defter.gelir_toplami(db, baslangic=ilk, bitis=son)
    gider = await defter.gider_toplami(db, baslangic=ilk, bitis=son)

    # Kategori kirilimi — YALNIZ `budget_category` tasiyan satirlar.
    # Kategorisiz defter satirlarini uydurma bir kategoriye koymak, butce
    # kirilimini gercek olmayan bir kalemle doldururdu.
    where = date_filters(donem, baslangic, bitis)
    where += [
        FinansalHareket.budget_category_id.isnot(None),
        FinansalHareket.durum == defter.GERCEKLESEN,
        FinansalHareket.tip.in_(_DEFTER_TIPLERI),
        FinansalHareket.id.notin_(defter.iptal_edilmis()),
    ]
    cat_rows = (
        await db.execute(
            select(
                FinansalHareket.budget_category_id,
                BudgetCategory.ad,
                BudgetCategory.tip,
                func.sum(FinansalHareket.tutar_kurus),
            )
            .join(
                BudgetCategory,
                BudgetCategory.id == FinansalHareket.budget_category_id,
            )
            .where(*where)
            .group_by(FinansalHareket.budget_category_id, BudgetCategory.ad,
                      BudgetCategory.tip)
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


# =============== (P192 §5.4) BUTCE HEDEFI + KARSILASTIRMA =================== #
#
# ================================================================
# NEDEN YENI BIR KAVRAM
# ================================================================
# Uründe "butce" diye bir sey vardi ama o GERCEKLESEN defterdi.
# PLANLANAN tutari tutan hicbir yer yoktu; "butce ile gerceklesen yan
# yana, sapma gorunsun" sorusu cevaplanamiyordu cunku karsilastirilacak
# ikinci sayi YOKTU.
#
# Hedef DEFTERE yazilmadi (`butce_hedefi` ayri tablo): bir plan para
# degildir ve deftere yazilan bir hedef, kasa bakiyesine karisma riski
# tasirdi.


@router.get("/hedefler", response_model=ButceHedefiListResponse)
async def hedef_listesi(
    yil: int | None = Query(None, ge=2000, le=2100),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_DEFTER_OKUR),
) -> ButceHedefiListResponse:
    where = [] if yil is None else [ButceHedefi.yil == yil]
    rows = (
        await db.execute(
            select(ButceHedefi).where(*where)
            .order_by(ButceHedefi.yil.desc(), ButceHedefi.donem, ButceHedefi.id)
        )
    ).scalars().all()
    return ButceHedefiListResponse(items=list(rows))


@router.post("/hedefler", response_model=ButceHedefiOut, status_code=201)
async def hedef_yaz(
    body: ButceHedefiCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> ButceHedefi:
    """Bir kategori icin YILLIK ya da AYLIK hedef.

    AYNI HEDEF IKINCI KEZ YAZILIRSA GUNCELLENIR (upsert): butce revize
    edilen bir seydir ve kullaniciyi "once sil, sonra ekle" akisina
    sokmak, arada hedefsiz kalan bir an birakirdi.
    """
    cat = (
        await db.execute(
            select(BudgetCategory).where(BudgetCategory.id == body.kategori_id)
        )
    ).scalar_one_or_none()
    if cat is None:
        raise APIError(422, "invalid_reference", "butce_kategori_bulunamadi")

    mevcut = (
        await db.execute(
            select(ButceHedefi).where(
                ButceHedefi.yil == body.yil,
                ButceHedefi.kategori_id == body.kategori_id,
                ButceHedefi.donem.is_(None) if body.donem is None
                else ButceHedefi.donem == body.donem,
            )
        )
    ).scalar_one_or_none()
    if mevcut is not None:
        mevcut.tutar_kurus = body.tutar_kurus
        mevcut.aciklama = body.aciklama
        mevcut.updated_at = func.now()
        obj = mevcut
    else:
        obj = ButceHedefi(tenant_id=user.tenant_id, **body.model_dump())
        db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="butce_hedefi",
        resource_id=obj.id,
        meta={"yil": obj.yil, "donem": obj.donem, "tutar_kurus": obj.tutar_kurus},
    )
    return obj


@router.delete("/hedefler/{hedef_id}", status_code=204, response_model=None)
async def hedef_sil(
    hedef_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    """Hedefi sil. GERCEK DELETE: bir hedef para degil, bir NIYETTIR;
    silinmesi hicbir muhasebe kaydini degistirmez."""
    obj = await get_or_404(db, ButceHedefi, hedef_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="butce_hedefi",
        resource_id=hedef_id, meta={"islem": "sil"},
    )
    return Response(status_code=204)


@router.get("/karsilastirma", response_model=ButceKarsilastirma)
async def butce_karsilastirma(
    yil: int = Query(..., ge=2000, le=2100),
    donem: str | None = Query(None, description="'YYYY-MM'; bos = TUM YIL"),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_DEFTER_OKUR),
) -> ButceKarsilastirma:
    """Butce ile gerceklesen YAN YANA + sapma.

    AYLIK SORULDUYSA AYLIK HEDEF, yoksa YILLIK HEDEFIN AYA DUSEN PAYI
    kullanilir (yillik/12). Aylik hedefi olmayan bir kategoriyi "hedefsiz"
    saymak, yillik butcesi onaylanmis bir kalemi sapma tablosunda sifir
    hedefle gostermek olurdu.
    """
    if donem is not None:
        ilk, son = defter.donem_araligi(donem)
    else:
        ilk, son = date(yil, 1, 1), date(yil, 12, 31)

    hedefler = (
        await db.execute(
            select(ButceHedefi).where(ButceHedefi.yil == yil)
        )
    ).scalars().all()
    hedef_kurus: dict[uuid.UUID, int] = {}
    for h in hedefler:
        if donem is None:
            # YIL TOPLAMI: yillik hedef varsa o, yoksa aylik hedeflerin
            # toplami. Ikisini toplamak, ayni parayi iki kez saymak olurdu.
            if h.donem is None:
                hedef_kurus[h.kategori_id] = int(h.tutar_kurus)
            else:
                hedef_kurus.setdefault(h.kategori_id, 0)
                hedef_kurus[h.kategori_id] += int(h.tutar_kurus)
        elif h.donem == donem:
            hedef_kurus[h.kategori_id] = int(h.tutar_kurus)
    if donem is not None:
        for h in hedefler:
            if h.donem is None and h.kategori_id not in hedef_kurus:
                hedef_kurus[h.kategori_id] = int(h.tutar_kurus) // 12

    # GERCEKLESEN: kategori bazinda, TEK DEFTERDEN.
    rows = (
        await db.execute(
            select(
                FinansalHareket.budget_category_id,
                BudgetCategory.ad,
                BudgetCategory.tip,
                func.sum(FinansalHareket.tutar_kurus),
            )
            .join(
                BudgetCategory,
                BudgetCategory.id == FinansalHareket.budget_category_id,
            )
            .where(
                FinansalHareket.tarih >= ilk,
                FinansalHareket.tarih <= son,
                FinansalHareket.durum == defter.GERCEKLESEN,
                FinansalHareket.tip.in_(_DEFTER_TIPLERI),
                FinansalHareket.id.notin_(defter.iptal_edilmis()),
            )
            .group_by(
                FinansalHareket.budget_category_id, BudgetCategory.ad,
                BudgetCategory.tip,
            )
        )
    ).all()
    gerceklesen = {kid: int(toplam) for kid, _, _, toplam in rows}
    adlar = {kid: (ad, tip) for kid, ad, tip, _ in rows}

    # Hedefi olup HIC HAREKETI OLMAYAN kategori de tabloda olmali:
    # "butcelendim ama hic harcamadim" bir sapmadir ve gorunmelidir.
    eksik = [k for k in hedef_kurus if k not in adlar]
    if eksik:
        for kid, ad, tip in (
            await db.execute(
                select(BudgetCategory.id, BudgetCategory.ad, BudgetCategory.tip)
                .where(BudgetCategory.id.in_(eksik))
            )
        ).all():
            adlar[kid] = (ad, tip)

    items: list[ButceKarsilastirmaSatiri] = []
    for kid, (ad, tip) in sorted(adlar.items(), key=lambda kv: kv[1][0]):
        hedef = hedef_kurus.get(kid, 0)
        gercek = gerceklesen.get(kid, 0)
        items.append(
            ButceKarsilastirmaSatiri(
                kategori_id=kid, ad=ad, tip=tip,
                hedef_kurus=hedef, gerceklesen_kurus=gercek,
                sapma_kurus=gercek - hedef,
                sapma_yuzde=(
                    round(100 * (gercek - hedef) / hedef) if hedef else None
                ),
            )
        )
    return ButceKarsilastirma(
        donem=donem, yil=yil, items=items,
        hedef_gelir_kurus=sum(
            i.hedef_kurus for i in items if i.tip == "gelir"
        ),
        hedef_gider_kurus=sum(
            i.hedef_kurus for i in items if i.tip == "gider"
        ),
        gerceklesen_gelir_kurus=sum(
            i.gerceklesen_kurus for i in items if i.tip == "gelir"
        ),
        gerceklesen_gider_kurus=sum(
            i.gerceklesen_kurus for i in items if i.tip == "gider"
        ),
    )
