"""Aidat — tahakkuk + odeme + bakiye — /contracts/openapi.yaml.

RBAC: tahakkuk/odeme YAZMA admin; rapor okuma (GET) admin/yonetici; resident yalniz GET /me/dues (kendi).
Bakiye = SUM(tahakkuk.tutar_kurus) - SUM(odeme.tutar_kurus WHERE durum='basarili').
Tutarlar KURUS (integer). Odeme idempotent (scan SAVEPOINT deseni). Gercek tahsilat
yok — soyut PaymentProvider (app/payments.py).
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, Query
from fastapi.responses import JSONResponse
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..sakin_bildirimi import aidat_bildir
from ..borclandirma import Bag, gecikme_kurus, hedef_sec
from ..models import (
    AppUser,
    DuesAssessment,
    DuesPayment,
    GelirGiderTanim,
    Tenant,
    Unit,
    UnitResident,
)
from ..payments import get_payment_provider
from .budget import ensure_dues_income_entry
from ..schemas import (
    DuesAssessmentCreate,
    DuesAssessmentListResponse,
    DuesAssessmentOut,
    DuesAssessmentResult,
    DuesPaymentCreate,
    DuesPaymentListResponse,
    DuesPaymentOut,
    MeDuesResponse,
    UnitDuesStatus,
)

router = APIRouter(tags=["aidat"])

_ADMIN = require_role("admin")

# (P167) TAHAKKUK URETME — admin + YONETICI.
#
# ================================================================
# NEDEN ACILDI
# ================================================================
# Aidat yazmak site yoneticisinin ASIL isidir; bunu platform adminine
# birakmak, her donem basinda musteriyi bize bagimli kilardi. Kusur
# P166'da kurulum sihirbazi taranirken gorunur oldu: sihirbaz sekizinci
# adimda ("Aidat tahakkuku") yoneticiyi `/dues`a yolluyor, yonetici toplu
# tahakkuk dugmesine basinca 403 aliyordu — yani sihirbaz onu
# YAPAMAYACAGI bir ise gonderiyordu.
#
# ================================================================
# TAHSILAT ACILMADI ve bu bilincli
# ================================================================
# `POST /dues/payments` `_ADMIN`de KALDI. Tahakkuk bir BORC YAZMAKTIR ve
# yanlissa duzeltilebilir/silinir; tahsilat ise PARA ALINDI beyanidir ve
# muhasebe kaydini kapatir. Ikisini tek kararla acmak, istenmeyen bir
# yetkiyi istenenin yanina iliştirmek olurdu.
#
# ================================================================
# TENANT IZOLASYONU — YETKI DEGISTI, KAPSAM DEGISMEDI
# ================================================================
# Yonetici yalnizca KENDI tesisinin dairelerine yazabilir ve bu YENI bir
# kontrol gerektirmiyor; uc zaten uc yerden birden kapali:
#   1. `get_tenant_db` oturumu token'daki tenant'a RLS ile baglar —
#      baska tesisin `unit` satiri sorguda HIC gorunmez.
#   2. Tekil modda `unit_id` bulunamaz -> 422 `invalid_reference`;
#      liste modunda eksik kimlikler -> 422 `daire_listesi_bulunamadi`;
#      suzgecsiz modda hedef kumesi zaten RLS'in dondugu dairelerdir.
#   3. Kayit `tenant_id=user.tenant_id` ile yazilir — istekten GELMEZ.
# `test_dues.py::test_yonetici_tahakkuk_tenant_izolasyonu` uc yolu da
# ayri ayri kilitler.
_TAHAKKUK = require_role("admin", "yonetici")

# (P128) Tahakkuk/tahsilat OKUMA — denetcinin "tahakkuk vs tahsilat"
# karsilastirmasi bu iki listeden cikar. Odeme ALMA `_ADMIN`de kalir.
_REPORT = require_role("admin", "yonetici", "denetci")
_RESIDENT = require_role("resident")


async def _tanim_coz(db: AsyncSession, tanim_id) -> GelirGiderTanim | None:
    """(P28) Borclandirma turunu coz ve DOGRULA.

    Alan OPSIYONELDIR: verilmezse eski davranis (tursuz tahakkuk) aynen
    surer, yani mevcut cagiranlar (mobil, panel, testler) bozulmaz.
    """
    if tanim_id is None:
        return None
    obj = (
        await db.execute(
            select(GelirGiderTanim).where(GelirGiderTanim.id == tanim_id)
        )
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(422, "invalid_reference", "gelir_gider_tanim_yok")
    if obj.tip == "gelir":
        # Bir GELIR kalemi BORCLANDIRILMAZ; tahsil edilir.
        raise APIError(422, "validation_error", "gelir_kalemi_borclandirilmaz")
    return obj


async def _hedef_coz(db: AsyncSession, unit_id, tanim: GelirGiderTanim | None):
    """(P28) Borcun KIME yazilacagini P23 bag verisinden coz.

    Tanim yoksa hedef de yoktur: tursuz bir tahakkuk ESKI DAVRANISTIR ve
    daireye yazilir.
    """
    if tanim is None:
        return None
    rows = (
        await db.execute(
            select(UnitResident.user_id, UnitResident.rol_tipi).where(
                UnitResident.unit_id == unit_id, UnitResident.bitis.is_(None)
            )
        )
    ).all()
    secilen = hedef_sec([Bag(str(u), r) for u, r in rows], tanim.hedef_kurali)
    return uuid.UUID(secilen) if secilen else None


async def _zenginlestir(
    db: AsyncSession, kayitlar: list[DuesAssessment]
) -> list[DuesAssessmentOut]:
    """(P28) Tahakkuklari TUR ADI + HEDEF ADI + GECIKME ile serilestir.

    GECIKME ANLIK HESAPLANIR, SAKLANMAZ: oran degistiginde gecmis kayitlar da
    yeni orana gore okunur. Saklansaydi ayni borc listede ve tahsilatta iki
    farkli tutar gosterirdi.

    Adlar TEK sorguda cozulur (kayit basina iki istek, 200 satirlik listede
    400 ek sorgu demekti).
    """
    if not kayitlar:
        return []
    oran = (
        await db.execute(select(Tenant.gecikme_aylik_yuzde))
    ).scalar_one_or_none() or 0
    bugun = datetime.now(timezone.utc).date()

    t_idler = {k.gelir_gider_tanim_id for k in kayitlar if k.gelir_gider_tanim_id}
    h_idler = {k.hedef_user_id for k in kayitlar if k.hedef_user_id}
    t_ad = dict(
        (await db.execute(
            select(GelirGiderTanim.id, GelirGiderTanim.ad)
            .where(GelirGiderTanim.id.in_(t_idler))
        )).all()
    ) if t_idler else {}
    h_ad = dict(
        (await db.execute(
            select(AppUser.id, AppUser.ad).where(AppUser.id.in_(h_idler))
        )).all()
    ) if h_idler else {}

    return [
        DuesAssessmentOut.model_validate(k).model_copy(update={
            "gelir_gider_tanim_ad": t_ad.get(k.gelir_gider_tanim_id),
            "hedef_ad": h_ad.get(k.hedef_user_id),
            "gecikme_kurus": gecikme_kurus(
                k.tutar_kurus, k.son_odeme_tarihi, bugun, oran,
                uygula=k.gecikme_uygula,
            ),
        })
        for k in kayitlar
    ]


async def _unit_status(db: AsyncSession, unit: Unit) -> UnitDuesStatus:
    assessments = (
        await db.execute(
            select(DuesAssessment)
            .where(DuesAssessment.unit_id == unit.id)
            .order_by(DuesAssessment.donem)
        )
    ).scalars().all()
    payments = (
        await db.execute(
            select(DuesPayment)
            .where(DuesPayment.unit_id == unit.id)
            .order_by(DuesPayment.odeme_zamani)
        )
    ).scalars().all()
    toplam_tahakkuk = sum(a.tutar_kurus for a in assessments)
    toplam_odenen = sum(p.tutar_kurus for p in payments if p.durum == "basarili")
    return UnitDuesStatus(
        unit_id=unit.id,
        no=unit.no,
        toplam_tahakkuk_kurus=toplam_tahakkuk,
        toplam_odenen_kurus=toplam_odenen,
        bakiye_kurus=toplam_tahakkuk - toplam_odenen,
        assessments=[DuesAssessmentOut.model_validate(a) for a in assessments],
        payments=[DuesPaymentOut.model_validate(p) for p in payments],
    )


# ------------------------------ tahakkuk ----------------------------------- #
@router.post("/dues/assessments", response_model=DuesAssessmentResult, status_code=201)
async def create_assessments(
    body: DuesAssessmentCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_TAHAKKUK),
) -> DuesAssessmentResult:
    tanim = await _tanim_coz(db, body.gelir_gider_tanim_id)
    common = dict(
        donem=body.donem,
        tutar_kurus=body.tutar_kurus,
        son_odeme_tarihi=body.son_odeme_tarihi,
        aciklama=body.aciklama,
        # (P28) Hepsi OPSIYONEL — verilmezse eski davranis.
        gelir_gider_tanim_id=body.gelir_gider_tanim_id,
        gecikme_uygula=body.gecikme_uygula,
    )
    if body.tarih is not None:
        common["tarih"] = body.tarih

    # TEK daire modu: unit_id verildi -> dup donem 409
    if body.unit_id is not None:
        if (await db.execute(select(Unit.id).where(Unit.id == body.unit_id))).scalar_one_or_none() is None:
            raise APIError(422, "invalid_reference", "daire_bulunamadi")
        hedef = await _hedef_coz(db, body.unit_id, tanim)
        obj = DuesAssessment(
            tenant_id=user.tenant_id, unit_id=body.unit_id,
            hedef_user_id=hedef, **common,
        )
        db.add(obj)
        try:
            await db.flush()
        except IntegrityError as exc:
            if is_unique_violation(exc):
                raise APIError(409, "conflict", "tahakkuk_zaten_var")
            raise translate_integrity(exc)
        await db.refresh(obj)
        await audit_user(
            db, user, Action.DUES_ASSESSMENT_CREATE, resource_type="dues_assessment",
            resource_id=obj.id, meta={"unit_id": str(body.unit_id)},
        )
        # (P191 §2) Borç yazıldı -> hedefe bildirim (push + in-app).
        await aidat_bildir(
            db,
            tenant_id=user.tenant_id,
            kalemler=[(obj.unit_id, obj.hedef_user_id, obj.donem, obj.tutar_kurus)],
        )
        return DuesAssessmentResult(
            created=await _zenginlestir(db, [obj]), atlanan=0
        )

    # TOPLU mod: unit_ids verildiyse dogrula, yoksa tum aktif daireler
    if body.unit_ids is not None:
        found = set(
            (await db.execute(select(Unit.id).where(Unit.id.in_(body.unit_ids)))).scalars().all()
        )
        missing = [str(u) for u in body.unit_ids if u not in found]
        if missing:
            raise APIError(
                422,
                "invalid_reference",
                "daire_listesi_bulunamadi",
                eksik=", ".join(missing),
            )
        targets = list(dict.fromkeys(body.unit_ids))
    else:
        targets = list(
            (await db.execute(select(Unit.id).where(Unit.aktif.is_(True)))).scalars().all()
        )

    created: list[DuesAssessmentOut] = []
    atlanan = 0
    for uid in targets:
        obj = DuesAssessment(
            tenant_id=user.tenant_id, unit_id=uid,
            hedef_user_id=await _hedef_coz(db, uid, tanim), **common,
        )
        try:
            async with db.begin_nested():
                db.add(obj)
                await db.flush()
        except IntegrityError as exc:
            try:
                db.expunge(obj)
            except Exception:
                pass
            if is_unique_violation(exc):
                atlanan += 1
                continue
            raise translate_integrity(exc)
        await db.refresh(obj)
        created.append(DuesAssessmentOut.model_validate(obj))
    if created:
        await audit_user(
            db, user, Action.DUES_ASSESSMENT_CREATE, resource_type="dues_assessment",
            meta={"count": len(created), "skipped": atlanan},
        )
        # (P191 §2) KISI BASINA TEK bildirim (tutarlar toplanir).
        await aidat_bildir(
            db,
            tenant_id=user.tenant_id,
            kalemler=[
                (c.unit_id, c.hedef_user_id, c.donem, c.tutar_kurus) for c in created
            ],
        )
    return DuesAssessmentResult(created=created, atlanan=atlanan)


@router.get("/dues/assessments", response_model=DuesAssessmentListResponse)
async def list_assessments(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    unit_id: uuid.UUID | None = Query(None),
    donem: str | None = Query(None),
    gelir_gider_tanim_id: uuid.UUID | None = Query(
        None, description="(P28) Borclandirma turune gore suzgec"
    ),
    hedef_user_id: uuid.UUID | None = Query(
        None, description="(P28) Borcun yazildigi kisiye gore suzgec"
    ),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_REPORT),
) -> DuesAssessmentListResponse:
    where = []
    if unit_id is not None:
        where.append(DuesAssessment.unit_id == unit_id)
    if donem is not None:
        where.append(DuesAssessment.donem == donem)
    if gelir_gider_tanim_id is not None:
        where.append(DuesAssessment.gelir_gider_tanim_id == gelir_gider_tanim_id)
    if hedef_user_id is not None:
        where.append(DuesAssessment.hedef_user_id == hedef_user_id)
    total = (await db.execute(select(func.count()).select_from(DuesAssessment).where(*where))).scalar_one()
    rows = (
        await db.execute(
            select(DuesAssessment).where(*where).order_by(DuesAssessment.created_at.desc(), DuesAssessment.id.desc()).limit(limit).offset(offset)
        )
    ).scalars().all()
    return DuesAssessmentListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _zenginlestir(db, list(rows)),
    )


# ------------------------------- odeme ------------------------------------- #
def _same_payment(existing: DuesPayment, *, unit_id, assessment_id, tutar_kurus, yontem, makbuz_no, kaydeden, donem) -> bool:
    return (
        existing.unit_id == unit_id
        and existing.assessment_id == assessment_id
        and existing.tutar_kurus == tutar_kurus
        and existing.yontem == yontem
        and existing.makbuz_no == makbuz_no
        and existing.kaydeden_user_id == kaydeden
        and existing.donem == donem
    )


@router.post("/dues/payments")
async def create_payment(
    body: DuesPaymentCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> JSONResponse:
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "idempotency_key_zorunlu")
    if (await db.execute(select(Unit.id).where(Unit.id == body.unit_id))).scalar_one_or_none() is None:
        raise APIError(422, "invalid_reference", "daire_bulunamadi")
    assessment_donem: str | None = None
    if body.assessment_id is not None:
        assessment_donem = (
            await db.execute(select(DuesAssessment.donem).where(DuesAssessment.id == body.assessment_id))
        ).scalar_one_or_none()
        if assessment_donem is None:
            raise APIError(422, "invalid_reference", "tahakkuk_bulunamadi")

    # donem: acikca verilen > assessment'tan tureyen > NULL (serbest odeme; rapor atfi).
    donem = body.donem if body.donem is not None else assessment_donem

    cmp = dict(
        unit_id=body.unit_id, assessment_id=body.assessment_id, tutar_kurus=body.tutar_kurus,
        yontem=body.yontem, makbuz_no=body.makbuz_no, kaydeden=user.id, donem=donem,
    )
    existing = (
        await db.execute(select(DuesPayment).where(DuesPayment.idempotency_key == idempotency_key))
    ).scalar_one_or_none()
    if existing is not None:
        if _same_payment(existing, **cmp):
            return JSONResponse(status_code=200, content=DuesPaymentOut.model_validate(existing).model_dump(mode="json"))
        raise APIError(409, "conflict", "idempotency_key_govde_farkli")

    # Odeme baslat: aktif saglayici (env). Manuel -> anlik 'basarili'; kart -> 'bekliyor'
    # + provider_ref + odeme URL (kullanici saglayiciya yonlenir, otorite WEBHOOK'tan gelir).
    provider = get_payment_provider(body.yontem)
    init = provider.init_payment(
        tutar_kurus=body.tutar_kurus, unit_id=body.unit_id, idempotency_key=idempotency_key
    )

    obj = DuesPayment(
        tenant_id=user.tenant_id,
        unit_id=body.unit_id,
        assessment_id=body.assessment_id,
        tutar_kurus=body.tutar_kurus,
        donem=donem,
        yontem=body.yontem,
        durum=init.durum,
        makbuz_no=body.makbuz_no,
        provider=provider.name,
        provider_ref=init.provider_ref,
        kaydeden_user_id=user.id,
        idempotency_key=idempotency_key,
    )
    if body.odeme_zamani is not None:
        obj.odeme_zamani = body.odeme_zamani
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        try:
            db.expunge(obj)
        except Exception:
            pass
        if is_unique_violation(exc):
            again = (
                await db.execute(select(DuesPayment).where(DuesPayment.idempotency_key == idempotency_key))
            ).scalar_one()
            if _same_payment(again, **cmp):
                return JSONResponse(status_code=200, content=DuesPaymentOut.model_validate(again).model_dump(mode="json"))
            raise APIError(409, "conflict", "idempotency_key_govde_farkli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    # OTOMATIK butce entegrasyonu: basarili odeme 'Aidat' gelir kaydi uretir
    # (ayni transaction; idempotent; butce aksakligi odemeyi DUSURMEZ).
    # Kartli odeme 'bekliyor' baslar — geliri webhook 'basarili' yapinca yazilir.
    await ensure_dues_income_entry(db, obj)
    await audit_user(
        db, user, Action.DUES_PAYMENT_RECORD, resource_type="dues_payment",
        resource_id=obj.id, meta={"unit_id": str(obj.unit_id), "yontem": obj.yontem},
    )
    content = DuesPaymentOut.model_validate(obj).model_dump(mode="json")
    if init.redirect_url:  # kart: saglayici odeme sayfasi URL'i
        content["odeme_url"] = init.redirect_url
    return JSONResponse(status_code=201, content=content)


@router.get("/dues/payments", response_model=DuesPaymentListResponse)
async def list_payments(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    unit_id: uuid.UUID | None = Query(None),
    donem: str | None = Query(None, description="'YYYY-MM' — donem bazli rapor filtresi"),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_REPORT),
) -> DuesPaymentListResponse:
    where = [] if unit_id is None else [DuesPayment.unit_id == unit_id]
    if donem is not None:
        where.append(DuesPayment.donem == donem)
    total = (await db.execute(select(func.count()).select_from(DuesPayment).where(*where))).scalar_one()
    rows = (
        await db.execute(
            select(DuesPayment).where(*where).order_by(DuesPayment.odeme_zamani.desc(), DuesPayment.id.desc()).limit(limit).offset(offset)
        )
    ).scalars().all()
    return DuesPaymentListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=list(rows))


# ------------------------------ borc durumu -------------------------------- #
@router.get("/units/{unit_id}/dues", response_model=UnitDuesStatus)
async def unit_dues(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_REPORT),
) -> UnitDuesStatus:
    unit = await get_or_404(db, Unit, unit_id)
    return await _unit_status(db, unit)


@router.get("/me/dues", response_model=MeDuesResponse)
async def me_dues(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RESIDENT),
) -> MeDuesResponse:
    # Sakinin AKTIF dairelerinin borc durumu (yalniz kendi daireleri).
    unit_ids = (
        await db.execute(
            select(UnitResident.unit_id).where(
                UnitResident.user_id == user.id, UnitResident.bitis.is_(None)
            )
        )
    ).scalars().all()
    items = []
    if unit_ids:
        units = (
            await db.execute(select(Unit).where(Unit.id.in_(list(unit_ids))).order_by(Unit.no))
        ).scalars().all()
        for u in units:
            items.append(await _unit_status(db, u))
    return MeDuesResponse(items=items)
