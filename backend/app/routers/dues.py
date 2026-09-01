"""Aidat — tahakkuk + odeme + bakiye — /contracts/openapi.yaml.

RBAC: tahakkuk/odeme YAZMA admin; rapor okuma (GET) admin/yonetici; resident yalniz GET /me/dues (kendi).
Tutarlar KURUS (integer). Odeme idempotent. Gercek tahsilat yok — soyut
PaymentProvider (app/payments.py).

===========================================================================
(P192 §1) ODEME ARTIK `dues_payment`E YAZILMAZ
===========================================================================
Bu ucun yazdigi ve okudugu TEK defter `finansal_hareket`tir (bkz.
`app/defter.py`). Onceden `dues_payment`e yazilirdi ve o tablonun kasa
bagi yoktu: `/dues/payments` ile girilen bir odeme sakinin borcunu
kapatiyor ama KASA BAKIYESINI ARTIRMIYORDU. Ayni sebeple vezneden
(`/finans/tahsilat`) girilen tahsilat kasayi artirip BORCU KAPATMIYORDU.

Yanit BICIMI degismedi (`DuesPaymentOut`): mobil ve panel istemcileri
kirilmasin diye defter satiri bu bicime CEVRILIR (`_odeme_out`).
`dues_payment` tablosu YERINDE durur (gecmis kayitlar goc 0083'te
deftere tasindi) ama ARTIK YAZILMAZ.

Bakiye = SUM(tahakkuk) - SUM(defterdeki tahsilat etkisi).
"""
from __future__ import annotations

import uuid
from datetime import datetime, time, timezone

from fastapi import APIRouter, Depends, Header, Query
from fastapi.responses import JSONResponse
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..belge_no import belge_no_ata
from ..crud_helpers import get_or_404, is_unique_violation, translate_integrity
from .. import defter
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..sakin_bildirimi import aidat_bildir
from ..borclandirma import Bag, gecikme_kurus, hedef_sec
from ..models import (
    AppUser,
    DuesAssessment,
    FinansalHareket,
    GelirGiderTanim,
    Tenant,
    Unit,
    UnitResident,
)
from ..payments import get_payment_provider
from ..schemas import (
    DuesAssessmentCreate,
    DuesAssessmentListResponse,
    DuesAssessmentOut,
    DuesAssessmentResult,
    DuesPaymentCreate,
    DuesPaymentListResponse,
    DuesPaymentOut,
    MeDuesResponse,
    TahakkukAtlanan,
    TahakkukTersKayitIstek,
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
    # (P192 §3.1) Tesis faiz UYGULAMIYORSA oran ne olursa olsun 0 gosterilir.
    ayar = (
        await db.execute(select(Tenant.gecikme_uygula, Tenant.gecikme_aylik_yuzde))
    ).first()
    uygula = bool(ayar[0]) if ayar else False
    oran = (ayar[1] if ayar else 0) or 0
    bugun = datetime.now(timezone.utc).date()

    # (P192 §3.1) YAZILMIS faiz kalemleri gosterilen "gecikme"den DUSULUR:
    # yoksa ayni faiz hem bu alanda hem ayri bir borc kalemi olarak IKI KEZ
    # gorunur ve sakin borcunu iki kat sanardi.
    yazilmis_faiz: dict[uuid.UUID, int] = {}
    if uygula:
        kaynaklar = [k.id for k in kayitlar]
        yazilmis_faiz = dict(
            (
                await db.execute(
                    select(
                        DuesAssessment.kaynak_assessment_id,
                        func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0),
                    )
                    .where(
                        DuesAssessment.kalem_tipi == "faiz",
                        DuesAssessment.kaynak_assessment_id.in_(kaynaklar),
                        DuesAssessment.ters_kayit_id.is_(None),
                    )
                    .group_by(DuesAssessment.kaynak_assessment_id)
                )
            ).all()
        )

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
            "gecikme_kurus": max(
                gecikme_kurus(
                    k.tutar_kurus, k.son_odeme_tarihi, bugun, oran,
                    uygula=uygula and k.gecikme_uygula,
                ) - int(yazilmis_faiz.get(k.id, 0)),
                0,
            ),
        })
        for k in kayitlar
    ]


# --------------------------------------------------------------------------- #
#            (P192 §1) DEFTER SATIRI -> ESKI ODEME BICIMI                      #
# --------------------------------------------------------------------------- #
#
# Yanit bicimi KORUNDU: mobil `DuesPayment` modeli ve panelin tablosu bu
# alanlari bekliyor. Defteri tek kaynak yapmak bir IC karardir; istemciyi
# ayni turda kirmak, degisimi gereksizce riskli kilardi.
_DURUM_ESLEME = {
    "odendi": "basarili",
    "bekliyor": "bekliyor",
    # Onay bekleyen bir hareket sakin acisindan "henuz gerceklesmedi"dir.
    "onay_bekliyor": "bekliyor",
    "iptal": "iptal",
}


def _odeme_zamani(h: FinansalHareket) -> datetime:
    """Odemenin ANI.

    `finansal_hareket.tarih` bir GUNDUR (fis tarihi), `created_at` ise
    kaydin yazildigi andir. Ayni gunse tam an bilinir ve o dondurulur;
    GERIYE TARIHLI bir fiste ise kayit ani yanlis olurdu — o gunun
    baslangici dondurulur.
    """
    if h.created_at is not None and h.created_at.date() == h.tarih:
        return h.created_at
    return datetime.combine(h.tarih, time.min, tzinfo=timezone.utc)


def _odeme_out(h: FinansalHareket) -> DuesPaymentOut:
    return DuesPaymentOut(
        id=h.id,
        unit_id=h.unit_id,
        assessment_id=h.assessment_id,
        tutar_kurus=h.tutar_kurus,
        odeme_zamani=_odeme_zamani(h),
        donem=h.donem,
        # Defterde `yontem` NULL olabilir (vezne kaydi yontem sormuyor);
        # sozlesme bos birakmiyor, en genel deger dondurulur.
        yontem=h.yontem or "diger",
        durum=_DURUM_ESLEME.get(h.durum, "bekliyor"),
        # MAKBUZ NO = BELGE NO. Iki ayri numara tutmak, "hangisi gecerli"
        # sorusunu dogururdu (bkz. `app/belge_no.py`).
        makbuz_no=h.belge_no,
        provider=h.provider,
        provider_ref=h.provider_ref,
        kaydeden_user_id=h.kaydeden_user_id,
        idempotency_key=h.idempotency_key,
        created_at=h.created_at,
    )


async def _daire_tahsilatlari(
    db: AsyncSession, unit_id: uuid.UUID
) -> list[FinansalHareket]:
    """Dairenin defterdeki tahsilat satirlari (iade/iptal DAHIL).

    Iade ve iptal satirlari da listelenir: sakinin gecmisinde "odendi sonra
    iade edildi" gorunmezse, bakiye ile liste birbirini tutmaz.
    """
    return list(
        (
            await db.execute(
                select(FinansalHareket)
                .where(
                    FinansalHareket.unit_id == unit_id,
                    FinansalHareket.tip.in_(("tahsilat", "iade", "iptal")),
                )
                .order_by(FinansalHareket.tarih, FinansalHareket.created_at,
                          FinansalHareket.id)
            )
        ).scalars().all()
    )


async def _unit_status(db: AsyncSession, unit: Unit) -> UnitDuesStatus:
    assessments = (
        await db.execute(
            select(DuesAssessment)
            .where(DuesAssessment.unit_id == unit.id, *defter.gecerli_tahakkuk())
            .order_by(DuesAssessment.donem)
        )
    ).scalars().all()
    satirlar = await _daire_tahsilatlari(db, unit.id)
    # (P192 §6.3) Ters kayit CIFTI zaten sorguda disarida (bkz.
    # `defter.gecerli_tahakkuk`); toplam listedeki satirlarla TUTAR.
    toplam_tahakkuk = sum(a.tutar_kurus for a in assessments)
    # TEK TANIM: "odenen" hesabi `defter.py`de; burada TEKRARLANMAZ.
    toplam_odenen = (await defter.daire_odenen(db, [unit.id])).get(unit.id, 0)
    return UnitDuesStatus(
        unit_id=unit.id,
        no=unit.no,
        toplam_tahakkuk_kurus=toplam_tahakkuk,
        toplam_odenen_kurus=toplam_odenen,
        bakiye_kurus=toplam_tahakkuk - toplam_odenen,
        assessments=[DuesAssessmentOut.model_validate(a) for a in assessments],
        payments=[_odeme_out(h) for h in satirlar],
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
        # (P192 §3.2) Borc NEYIN borcu. Ayni aya birden cok kalem
        # yazilabildigi icin tip olmadan kalemler ayirt edilemezdi.
        kalem_tipi=body.kalem_tipi,
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
    atlananlar: list[TahakkukAtlanan] = []
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
                # (P192 §3.2) `UNIQUE (tenant, unit, donem)` KALKTI; buraya
                # dusmek artik beklenmez. Yine de sessizce gecilmez:
                # atlanan daire DOKUMLU dondurulur.
                atlananlar.append(TahakkukAtlanan(
                    unit_id=uid, neden="benzersizlik_carpismasi"
                ))
                continue
            raise translate_integrity(exc)
        await db.refresh(obj)
        created.append(DuesAssessmentOut.model_validate(obj))
    if created:
        await audit_user(
            db, user, Action.DUES_ASSESSMENT_CREATE, resource_type="dues_assessment",
            meta={"count": len(created), "skipped": len(atlananlar)},
        )
        # (P191 §2) KISI BASINA TEK bildirim (tutarlar toplanir).
        await aidat_bildir(
            db,
            tenant_id=user.tenant_id,
            kalemler=[
                (c.unit_id, c.hedef_user_id, c.donem, c.tutar_kurus) for c in created
            ],
        )
    return DuesAssessmentResult(
        created=created, atlanan=len(atlananlar), atlananlar=atlananlar
    )


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
    # (P192 §6.3) Ters kayitlanmis borclar ve duzeltme satirlari LISTEDE
    # GORUNMEZ: toplamdan dustukleri halde listede durmalari, "toplam
    # neden satirlari tutmuyor" sorusunu dogururdu.
    where = list(defter.gecerli_tahakkuk())
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


# --------------------- (P192 §6.3) TAHAKKUK DUZELTME ----------------------- #
#
# ================================================================
# NEDEN ACILDI
# ================================================================
# `docs/finans-analiz.md`: yanlis tahakkuk edilirse ne olacagi
# BELIRSIZDI. Silme ucu yoktu (ve olmamali) ama duzeltme yolu da yoktu;
# yonetici yanlis bir borcu ancak veritabanindan elle silerek
# duzeltebilirdi.
#
# ================================================================
# COZUM DEFTERDEKININ AYNISI: TERS KAYIT
# ================================================================
# Satir SILINMEZ. `ters_kayit_id` tasiyan yeni bir satir yazilir; bakiye
# onu EKSI sayar (bkz. `defter.tahakkuk_etkisi`). Ikisinin toplami
# sifirdir — borc "hic yazilmamis" hale gelmez, DUZELTILMIS olur ve
# duzeltmenin kendisi gorunur.
#
# ================================================================
# ODENMIS BORC TERS KAYITLANAMAZ
# ================================================================
# Uzerine tahsilat yazilmis bir borcu ters kayitlamak, alinmis parayi
# karsiliksiz birakirdi (daire alacakli gorunurdu). Once tahsilat iade
# edilir/iptal edilir, sonra borc duzeltilir. 409 ile reddedilir.


@router.post(
    "/dues/assessments/{assessment_id}/ters-kayit",
    response_model=DuesAssessmentOut,
    status_code=201,
)
async def tahakkuk_ters_kayit(
    assessment_id: uuid.UUID,
    body: TahakkukTersKayitIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_TAHAKKUK),
) -> DuesAssessmentOut:
    """Yanlis tahakkuku TERS KAYITLA duzelt (silme YOK)."""
    asil = await get_or_404(db, DuesAssessment, assessment_id)
    if asil.ters_kayit_id is not None:
        raise APIError(422, "validation_error", "ters_kayit_ters_kayitlanamaz")
    zaten = (
        await db.execute(
            select(DuesAssessment.id)
            .where(DuesAssessment.ters_kayit_id == asil.id)
        )
    ).first()
    if zaten is not None:
        raise APIError(409, "conflict", "tahakkuk_zaten_ters_kayitli")
    odenen = (await defter.tahakkuk_odenen(db, [asil.id])).get(asil.id, 0)
    if odenen > 0:
        raise APIError(409, "conflict", "tahakkuk_odenmis_ters_kayitlanamaz")

    ters = DuesAssessment(
        tenant_id=user.tenant_id,
        unit_id=asil.unit_id,
        donem=asil.donem,
        tutar_kurus=asil.tutar_kurus,
        kalem_tipi=asil.kalem_tipi,
        gelir_gider_tanim_id=asil.gelir_gider_tanim_id,
        hedef_user_id=asil.hedef_user_id,
        ters_kayit_id=asil.id,
        # Ters kayda FAIZ ISLEMEZ: bir duzeltme gecikmez.
        gecikme_uygula=False,
        aciklama=body.aciklama or f"Duzeltme: {asil.donem}",
        kaynak=asil.kaynak,
    )
    db.add(ters)
    # Orijinal ARTIK BORC DEGIL. Bayrak AYNI ISLEMDE yazilir; ayri bir
    # islemde yazilsaydi defter ile bayrak arasinda bir an icin fark
    # olusabilirdi.
    asil.iptal_edildi = True
    try:
        await db.flush()
    except IntegrityError as exc:
        if is_unique_violation(exc):
            raise APIError(409, "conflict", "tahakkuk_zaten_ters_kayitli")
        raise translate_integrity(exc)
    await db.refresh(ters)
    await audit_user(
        db, user, Action.DUES_ASSESSMENT_CREATE, resource_type="dues_assessment",
        resource_id=ters.id,
        meta={"islem": "ters_kayit", "duzeltilen": str(asil.id),
              "tutar_kurus": asil.tutar_kurus, "sebep": body.aciklama},
    )
    return (await _zenginlestir(db, [ters]))[0]


# ------------------------------- odeme ------------------------------------- #
def _ayni_odeme(
    mevcut: FinansalHareket, *, unit_id, assessment_id, tutar_kurus, yontem,
    kaydeden, donem,
) -> bool:
    """Tekrar gelen istek AYNI isi mi istiyor?

    Serbest metinler (belge/aciklama) DISARIDA: kullanici tekrar denerken
    makbuz numarasini duzeltmis olabilir; para hareketinin kendisi aynıysa
    bu AYNI islemdir (vezne ucundaki `_imza` ile ayni ilke).
    """
    return (
        mevcut.unit_id == unit_id
        and mevcut.assessment_id == assessment_id
        and mevcut.tutar_kurus == tutar_kurus
        and (mevcut.yontem or "diger") == yontem
        and mevcut.kaydeden_user_id == kaydeden
        and mevcut.donem == donem
    )


async def _idem_bul(db: AsyncSession, anahtar: str) -> FinansalHareket | None:
    return (
        await db.execute(
            select(FinansalHareket).where(
                FinansalHareket.idempotency_key == anahtar,
                FinansalHareket.tip == "tahsilat",
            )
        )
    ).scalar_one_or_none()


@router.post("/dues/payments")
async def create_payment(
    body: DuesPaymentCreate,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> JSONResponse:
    """Aidat tahsilati — DEFTERE yazar (P192 §1).

    ATOMIK: borc kapanisi (`assessment_id` bagi), defter kaydi ve kasa
    hareketi TEK satirdir ve TEK islemde yazilir. Uc ayri tabloya uc ayri
    yazma yapildiginda biri basarisiz olursa defter ile bakiye sessizce
    ayrilirdi; artik ayrilamaz cunku ucu de AYNI satirdan turetiliyor.
    """
    if not idempotency_key or not idempotency_key.strip():
        raise APIError(400, "bad_request", "idempotency_key_zorunlu")
    anahtar = idempotency_key.strip()
    if (await db.execute(select(Unit.id).where(Unit.id == body.unit_id))).scalar_one_or_none() is None:
        raise APIError(422, "invalid_reference", "daire_bulunamadi")
    assessment_donem: str | None = None
    hedef_user_id = None
    if body.assessment_id is not None:
        satir = (
            await db.execute(
                select(DuesAssessment.donem, DuesAssessment.hedef_user_id)
                .where(DuesAssessment.id == body.assessment_id)
            )
        ).first()
        if satir is None:
            raise APIError(422, "invalid_reference", "tahakkuk_bulunamadi")
        assessment_donem, hedef_user_id = satir

    # donem: acikca verilen > assessment'tan tureyen > NULL (serbest odeme).
    donem = body.donem if body.donem is not None else assessment_donem

    cmp = dict(
        unit_id=body.unit_id, assessment_id=body.assessment_id,
        tutar_kurus=body.tutar_kurus, yontem=body.yontem, kaydeden=user.id,
        donem=donem,
    )
    mevcut = await _idem_bul(db, anahtar)
    if mevcut is not None:
        if _ayni_odeme(mevcut, **cmp):
            return JSONResponse(
                status_code=200,
                content=_odeme_out(mevcut).model_dump(mode="json"),
            )
        raise APIError(409, "conflict", "idempotency_key_govde_farkli")

    # Odeme baslat: aktif saglayici (env). Manuel -> anlik 'basarili'; kart ->
    # 'bekliyor' + provider_ref + odeme URL (otorite WEBHOOK'tan gelir).
    provider = get_payment_provider(body.yontem)
    init = provider.init_payment(
        tutar_kurus=body.tutar_kurus, unit_id=body.unit_id,
        idempotency_key=anahtar,
    )

    # KASA ZORUNLU DEGIL, ama NULL DA BIRAKILMAZ: kasasiz bir tahsilat
    # defterde gorunur, hicbir kasa bakiyesinde gorunmezdi (P192 §2.1'in
    # duzelttigi kusur). Verilmediyse havale/kart BANKA hesabina, elden
    # odeme MERKEZ KASAYA yazilir; hicbiri yoksa acilir.
    kasa_id = await defter.kasa_coz(
        db, user.tenant_id, body.kasa_id,
        banka=body.yontem in ("havale", "kart"),
    )

    obj = FinansalHareket(
        tenant_id=user.tenant_id,
        tip="tahsilat",
        yon="giris",
        tutar_kurus=body.tutar_kurus,
        kasa_id=kasa_id,
        unit_id=body.unit_id,
        user_id=hedef_user_id,
        assessment_id=body.assessment_id,
        donem=donem,
        yontem=body.yontem,
        durum="odendi" if init.durum == "basarili" else "bekliyor",
        provider=provider.name,
        provider_ref=init.provider_ref,
        kaydeden_user_id=user.id,
        idempotency_key=anahtar,
        idem_satir=0,
        # Butce kiriliminda "Aidat" basligi altinda gorunsun (eskiden
        # `ensure_dues_income_entry` ayni kategoriye ayri bir satir
        # yazardi; artik satirin KENDISI o kategoriye ait).
        budget_category_id=await defter.aidat_kategori_id(db, user.tenant_id),
        belge_no=await belge_no_ata(
            db, user.tenant_id, "tahsilat", body.makbuz_no,
            body.odeme_zamani.date() if body.odeme_zamani else None,
        ),
    )
    if body.odeme_zamani is not None:
        obj.tarih = body.odeme_zamani.date()
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
            # YARIS: ayni anahtarla ikinci istek arada yazdi.
            again = await _idem_bul(db, anahtar)
            if again is not None and _ayni_odeme(again, **cmp):
                return JSONResponse(
                    status_code=200,
                    content=_odeme_out(again).model_dump(mode="json"),
                )
            raise APIError(409, "conflict", "idempotency_key_govde_farkli")
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.DUES_PAYMENT_RECORD, resource_type="finansal_hareket",
        resource_id=obj.id,
        meta={"unit_id": str(obj.unit_id), "yontem": body.yontem,
              "tutar_kurus": obj.tutar_kurus},
    )
    content = _odeme_out(obj).model_dump(mode="json")
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
    """Tahsilat listesi — DEFTERDEN.

    Vezneden (`/finans/tahsilat`) girilen tahsilatlar da BURADA gorunur:
    ayni defterden okundugu icin "aidat tahsilati" ile "vezne tahsilati"
    diye iki ayri gercek kalmadi.
    """
    where = [FinansalHareket.tip == "tahsilat"]
    if unit_id is not None:
        where.append(FinansalHareket.unit_id == unit_id)
    if donem is not None:
        where.append(FinansalHareket.donem == donem)
    total = (
        await db.execute(
            select(func.count()).select_from(FinansalHareket).where(*where)
        )
    ).scalar_one()
    rows = (
        await db.execute(
            select(FinansalHareket).where(*where)
            .order_by(FinansalHareket.tarih.desc(),
                      FinansalHareket.created_at.desc(),
                      FinansalHareket.id.desc())
            .limit(limit).offset(offset)
        )
    ).scalars().all()
    return DuesPaymentListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_odeme_out(h) for h in rows],
    )


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
