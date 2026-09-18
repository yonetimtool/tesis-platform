"""(P240 §2) DIYAFON — uc yontem, tek soyutlama, yonetici yapilandirmasi.

RBAC: YALNIZ admin + yonetici (entegrasyon uclariyla ayni kapi).
Sifre write-only: GET'te ASLA donmez, yerine `sifre_set` (bool).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..crypto import encrypt_secret
from ..deps import get_tenant_db, require_role
from ..diyafon import saglayici, yetenekler
from ..entegrasyon_saglik import simdi as _simdi
from ..errors import APIError
from ..models import AppUser, Diyafon
from ..schemas import (
    DiyafonCreate,
    DiyafonEylemIn,
    DiyafonEylemOut,
    DiyafonListResponse,
    DiyafonOut,
    DiyafonUpdate,
    PageMetaOut,
)

router = APIRouter(prefix="/diyafon", tags=["diyafon"])

_MANAGER = require_role("admin", "yonetici")


async def _saglik_yaz(
    db: AsyncSession, obj: Diyafon, *, bagli: bool, kod: str | None, ayrinti: str | None
) -> None:
    """(P240 §4 deseni) Saglik alanlarini gunceller.

    Baglanti geri gelince `kopus_bildirildi_at` TEMIZLENIR; yoksa ikinci
    bir kopus sessiz kalirdi.
    """
    an = _simdi()
    obj.saglik = "bagli" if bagli else "hata"
    obj.son_kontrol_at = an
    if bagli:
        obj.son_basarili_at = an
        obj.son_hata_kod = None
        obj.son_hata_ayrinti = None
        obj.kopus_bildirildi_at = None
    else:
        obj.son_hata_kod = kod
        obj.son_hata_ayrinti = ayrinti
    await db.flush()


@router.post("", response_model=DiyafonOut, status_code=201)
async def olustur(
    body: DiyafonCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> DiyafonOut:
    veri = body.model_dump(exclude={"sifre"})
    obj = Diyafon(tenant_id=user.tenant_id, **veri)
    if body.sifre:
        obj.sifre_enc = encrypt_secret(body.sifre)
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.DIYAFON_YAZ, resource_type="diyafon", resource_id=obj.id,
        meta={"yontem": obj.yontem, "islem": "olustur"},
    )
    return DiyafonOut.from_model(obj)


@router.get("", response_model=DiyafonListResponse)
async def liste(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> DiyafonListResponse:
    toplam = int(
        (await db.execute(select(func.count()).select_from(Diyafon))).scalar_one()
    )
    satirlar = (
        await db.execute(
            select(Diyafon)
            .order_by(Diyafon.created_at.desc(), Diyafon.id)
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    return DiyafonListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=toplam),
        items=[DiyafonOut.from_model(o) for o in satirlar],
    )


@router.get("/{diyafon_id}", response_model=DiyafonOut)
async def detay(
    diyafon_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> DiyafonOut:
    return DiyafonOut.from_model(await get_or_404(db, Diyafon, diyafon_id))


@router.patch("/{diyafon_id}", response_model=DiyafonOut)
async def guncelle(
    diyafon_id: uuid.UUID,
    body: DiyafonUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> DiyafonOut:
    obj = await get_or_404(db, Diyafon, diyafon_id)
    veri = body.model_dump(exclude_unset=True)
    sifre = veri.pop("sifre", None)
    for k, v in veri.items():
        setattr(obj, k, v)
    if sifre:
        # BOS SIFRE "degistirme" DEMEKTIR, "sil" degil: yonetici formu
        # bos birakarak kaydettiginde mevcut sirri silmek, calisan bir
        # baglantiyi sessizce kirardi.
        obj.sifre_enc = encrypt_secret(sifre)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.DIYAFON_YAZ, resource_type="diyafon", resource_id=obj.id,
        meta={"islem": "guncelle", "alanlar": list(veri.keys())},
    )
    return DiyafonOut.from_model(obj)


@router.delete("/{diyafon_id}", status_code=204)
async def sil(
    diyafon_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    obj = await get_or_404(db, Diyafon, diyafon_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(
        db, user, Action.DIYAFON_YAZ, resource_type="diyafon",
        resource_id=diyafon_id, meta={"islem": "sil"},
    )
    return Response(status_code=204)


@router.post("/{diyafon_id}/saglik", response_model=DiyafonEylemOut)
async def saglik_kontrol(
    diyafon_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> DiyafonEylemOut:
    """BAGLANTI TESTI — cihazi CALISTIRMAZ.

    SIP'te `OPTIONS` (RFC 3261 §11: zil caldirmaz), kuru kontakta TCP
    baglantisi. "Test et" dugmesi bunu cagirir; zil/kapi eylemleri AYRI
    uclardir (P240 §4'un kurali: izleme, izledigi seyi calistirmaz).
    """
    obj = await get_or_404(db, Diyafon, diyafon_id)
    sonuc = await run_in_threadpool(saglayici(obj).saglik)
    await _saglik_yaz(
        db, obj, bagli=sonuc.ok, kod=sonuc.kod, ayrinti=sonuc.ayrinti
    )
    return DiyafonEylemOut(ok=sonuc.ok, kod=sonuc.kod)


@router.post("/{diyafon_id}/anons", response_model=DiyafonEylemOut)
async def anons(
    diyafon_id: uuid.UUID,
    body: DiyafonEylemIn,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> DiyafonEylemOut:
    """METIN anonsu (SIP MESSAGE). SESLI anons YOK — bkz. diyafon/taban.py."""
    obj = await get_or_404(db, Diyafon, diyafon_id)
    if not yetenekler(obj.yontem).metin_anons:
        # DESTEKLENMEYEN EYLEM 422: "denedim, olmadi" ile "bu yontem
        # bunu YAPAMAZ" ayri seylerdir ve arayuz ikisini ayri gostermeli.
        raise APIError(422, "validation_error", "diyafon_yontem_desteklemiyor")
    sonuc = await run_in_threadpool(saglayici(obj).metin_anons, body.mesaj)
    await _saglik_yaz(db, obj, bagli=sonuc.ok, kod=sonuc.kod, ayrinti=sonuc.ayrinti)
    await audit_user(
        db, user, Action.DIYAFON_EYLEM, resource_type="diyafon",
        resource_id=obj.id, meta={"eylem": "anons", "ok": sonuc.ok},
    )
    return DiyafonEylemOut(ok=sonuc.ok, kod=sonuc.kod)


@router.post("/{diyafon_id}/kapi-ac", response_model=DiyafonEylemOut)
async def kapi_ac(
    diyafon_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> DiyafonEylemOut:
    obj = await get_or_404(db, Diyafon, diyafon_id)
    if not yetenekler(obj.yontem).kapi_ac:
        raise APIError(422, "validation_error", "diyafon_yontem_desteklemiyor")
    sonuc = await run_in_threadpool(saglayici(obj).kapi_ac)
    await _saglik_yaz(db, obj, bagli=sonuc.ok, kod=sonuc.kod, ayrinti=sonuc.ayrinti)
    # KAPI ACMA HER ZAMAN DENETIM KAYDINDA: fiziksel erisim veren bir
    # eylem, kimin ne zaman yaptigi bilinmeden birakilamaz.
    await audit_user(
        db, user, Action.DIYAFON_EYLEM, resource_type="diyafon",
        resource_id=obj.id, meta={"eylem": "kapi_ac", "ok": sonuc.ok},
    )
    return DiyafonEylemOut(ok=sonuc.ok, kod=sonuc.kod)


@router.post("/{diyafon_id}/zil", response_model=DiyafonEylemOut)
async def zil_cal(
    diyafon_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> DiyafonEylemOut:
    obj = await get_or_404(db, Diyafon, diyafon_id)
    if not yetenekler(obj.yontem).zil_cal:
        raise APIError(422, "validation_error", "diyafon_yontem_desteklemiyor")
    sonuc = await run_in_threadpool(saglayici(obj).zil_cal)
    await _saglik_yaz(db, obj, bagli=sonuc.ok, kod=sonuc.kod, ayrinti=sonuc.ayrinti)
    await audit_user(
        db, user, Action.DIYAFON_EYLEM, resource_type="diyafon",
        resource_id=obj.id, meta={"eylem": "zil", "ok": sonuc.ok},
    )
    return DiyafonEylemOut(ok=sonuc.ok, kod=sonuc.kod)
