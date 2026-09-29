"""(P249 §2) TATBIKAT UCLARI — `/tatbikat`.

NEDEN `/panik/tatbikat` DEGIL: `/panik/{alarm_id}` yolu her tek parcayi
yakalar ve `alarm_id` UUID oldugu icin "tatbikat" 422 dondururdu. Ayri
onek, iki ailenin yollarini birbirine karistirmaz.

YETKI:
  * planla / baslat / bitir / iptal — YALNIZ yonetim (admin, yonetici),
  * liste + rapor + PDF — yonetim ve guvenlik (sayimi yapan onlardir).
"""
from __future__ import annotations

import datetime as dt
import uuid

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..hata_metinleri import istek_dili
from ..models import AppUser, PanikTatbikat
from ..panik_talimat import tatbikat_adi
from ..schemas import TatbikatOlustur, TatbikatOut, TatbikatRaporOut

router = APIRouter(prefix="/tatbikat", tags=["panik"])

_YONETIM = require_role("admin", "yonetici")
_OKUR = require_role("admin", "yonetici", "security", "guvenlik_amiri")

#: Plan ufku — bir yildan ileri tarih yazim hatasidir (2062 gibi).
PLAN_UFKU = dt.timedelta(days=366)


def _simdi() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _dil(request: Request) -> str:
    return istek_dili(request.headers.get("accept-language"))


async def _out(db: AsyncSession, t: PanikTatbikat, dil: str) -> TatbikatOut:
    from ..panik_tatbikat import alarmi

    out = TatbikatOut.model_validate(t)
    out.baslik = tatbikat_adi(t.kategori, dil)
    if t.olusturan_user_id:
        out.olusturan_ad = (
            await db.execute(select(AppUser.ad).where(AppUser.id == t.olusturan_user_id))
        ).scalar_one_or_none()
    alarm = await alarmi(db, t)
    out.alarm_id = alarm.id if alarm else None
    return out


@router.get("", response_model=list[TatbikatOut])
async def liste(
    request: Request,
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> list[TatbikatOut]:
    satirlar = (
        await db.execute(
            select(PanikTatbikat)
            .order_by(PanikTatbikat.created_at.desc(), PanikTatbikat.id)
            .limit(limit)
        )
    ).scalars().all()
    dil = _dil(request)
    return [await _out(db, t, dil) for t in satirlar]


@router.post("", response_model=TatbikatOut, status_code=201)
async def planla(
    body: TatbikatOlustur,
    request: Request,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> TatbikatOut:
    from .. import panik_tatbikat as T

    simdi = _simdi()
    hemen = body.planlanan_at is None
    if not hemen:
        an = body.planlanan_at
        if an.tzinfo is None:
            raise APIError(422, "validation_error", "tatbikat_zaman_dilimi")
        if an < simdi - dt.timedelta(minutes=1) or an > simdi + PLAN_UFKU:
            raise APIError(422, "validation_error", "tatbikat_zaman_gecersiz")
    if body.duyuru and hemen:
        # Duyuru "Sali 14:00'te" der; hemen baslayan tatbikatin
        # onceden duyurusu olamaz.
        raise APIError(422, "validation_error", "tatbikat_duyuru_plansiz")
    blok = (body.blok or "").strip() or None
    if body.kapsam == "blok":
        if not blok or not await T.blok_var_mi(db, blok):
            raise APIError(422, "validation_error", "tatbikat_blok_yok")
    else:
        blok = None
    if hemen:
        aktif = (
            await db.execute(
                select(PanikTatbikat.id).where(PanikTatbikat.durum == "aktif").limit(1)
            )
        ).scalar_one_or_none()
        if aktif is not None:
            raise APIError(409, "conflict", "tatbikat_zaten_aktif")

    t = PanikTatbikat(
        tenant_id=user.tenant_id,
        kategori=body.kategori,
        kapsam=body.kapsam,
        blok=blok,
        planlanan_at=body.planlanan_at,
        duyuru=body.duyuru,
        durum="planli",
        olusturan_user_id=user.id,
        aciklama=body.aciklama,
    )
    db.add(t)
    await db.flush()
    await audit_user(
        db, user, Action.TATBIKAT_PLAN, resource_type="panik_tatbikat",
        resource_id=t.id,
        meta={"kategori": body.kategori, "kapsam": body.kapsam, "blok": blok,
              "hemen": hemen, "duyuru": body.duyuru},
    )
    if body.duyuru:
        await T.duyuru_gonder(db, t)
    if hemen:
        await T.baslat(db, t)
        await audit_user(
            db, user, Action.TATBIKAT_BASLAT, resource_type="panik_tatbikat",
            resource_id=t.id,
        )
    return await _out(db, t, _dil(request))


@router.post("/{tatbikat_id}/baslat", response_model=TatbikatOut)
async def baslat(
    tatbikat_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> TatbikatOut:
    """Planli tatbikati ZAMANINDAN ONCE baslat (hava, katilim...)."""
    from .. import panik_tatbikat as T

    t = await get_or_404(db, PanikTatbikat, tatbikat_id)
    if t.durum != "planli":
        raise APIError(409, "conflict", "tatbikat_durum_uygun_degil")
    aktif = (
        await db.execute(
            select(PanikTatbikat.id).where(PanikTatbikat.durum == "aktif").limit(1)
        )
    ).scalar_one_or_none()
    if aktif is not None:
        raise APIError(409, "conflict", "tatbikat_zaten_aktif")
    await T.baslat(db, t)
    await audit_user(
        db, user, Action.TATBIKAT_BASLAT, resource_type="panik_tatbikat",
        resource_id=t.id,
    )
    return await _out(db, t, _dil(request))


@router.post("/{tatbikat_id}/bitir", response_model=TatbikatOut)
async def bitir(
    tatbikat_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> TatbikatOut:
    from .. import panik_tatbikat as T

    t = await get_or_404(db, PanikTatbikat, tatbikat_id)
    if t.durum != "aktif":
        raise APIError(409, "conflict", "tatbikat_durum_uygun_degil")
    await T.bitir(db, t, neden="elle")
    await audit_user(
        db, user, Action.TATBIKAT_BITIR, resource_type="panik_tatbikat",
        resource_id=t.id,
    )
    return await _out(db, t, _dil(request))


@router.post("/{tatbikat_id}/iptal", response_model=TatbikatOut)
async def iptal(
    tatbikat_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> TatbikatOut:
    """Yalniz PLANLI tatbikat iptal edilir; baslamis olan BITIRILIR."""
    t = await get_or_404(db, PanikTatbikat, tatbikat_id)
    if t.durum != "planli":
        raise APIError(409, "conflict", "tatbikat_durum_uygun_degil")
    t.durum = "iptal"
    t.bitti_at = _simdi()
    t.bitis_nedeni = "iptal"
    await db.flush()
    await audit_user(
        db, user, Action.TATBIKAT_IPTAL, resource_type="panik_tatbikat",
        resource_id=t.id,
    )
    return await _out(db, t, _dil(request))


async def _rapor(db: AsyncSession, t: PanikTatbikat, dil: str) -> TatbikatRaporOut:
    from .. import panik_tatbikat as T
    from ..panik_durum import durum_hesapla

    alarm = await T.alarmi(db, t)
    durum = await durum_hesapla(db, alarm) if alarm is not None else None
    denenen, gonderildi = await T.push_teslim(db, t)
    return TatbikatRaporOut(
        tatbikat=await _out(db, t, dil),
        durum=durum,
        push_denenen=denenen,
        push_gonderildi=gonderildi,
    )


@router.get("/{tatbikat_id}", response_model=TatbikatRaporOut)
async def rapor(
    tatbikat_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> TatbikatRaporOut:
    t = await get_or_404(db, PanikTatbikat, tatbikat_id)
    return await _rapor(db, t, _dil(request))


@router.get("/{tatbikat_id}/rapor.pdf")
async def rapor_pdf(
    tatbikat_id: uuid.UUID,
    request: Request,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> Response:
    from ..tatbikat_pdf import tatbikat_pdf

    t = await get_or_404(db, PanikTatbikat, tatbikat_id)
    dil = _dil(request)
    r = await _rapor(db, t, dil)
    from ..models import Tenant

    site = (
        await db.execute(select(Tenant.ad).where(Tenant.id == t.tenant_id))
    ).scalar_one_or_none() or ""
    govde = tatbikat_pdf(r, site, dil)
    await audit_user(
        db, user, Action.TATBIKAT_RAPOR,
        resource_type="panik_tatbikat", resource_id=t.id, meta={"bicim": "pdf"},
    )
    ad = f"tatbikat-{t.kategori}-{(t.basladi_at or t.created_at).date().isoformat()}.pdf"
    return Response(
        content=govde,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{ad}"'},
    )
