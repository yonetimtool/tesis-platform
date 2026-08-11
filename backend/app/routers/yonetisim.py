"""Yonetisim modulleri (P33) — karar defteri, dokuman arsivi, site aktarim.

IS TAKIBI icin AYRI UC YOK: denetim omurganin ZATEN VAR OLDUGUNU gosterdi
(`complaint` = Talep/Ariza, `task` = Is Emri, Ticketing v1'de bagli). Yapilan
sey birlestirme degil GENISLETMEDIR — `complaint` uc alan kazandi
(`unit_id`, `oncelik`, `atanan_personel_id`) ve mevcut `/complaints` uclari
bunlari tasiyor. `unit_complaint` ile birlestirmek P22(e)'nin BILINCLI
ayrimini bozardi.

RBAC: admin + yonetici. Karar defteri ve site aktarimi yonetim islemleridir.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    KararDefteri,
    KararUyesi,
    Tenant,
    TenantDokuman,
)
from ..rapor_ciktilari import metin_pdf
from ..schemas import (
    DokumanCreate,
    DokumanListResponse,
    DokumanOut,
    KararDefteriCreate,
    KararDefteriListResponse,
    KararDefteriOut,
    KararDefteriUpdate,
    KararUyesiIn,
)

router = APIRouter(tags=["yonetisim"])

_YONETIM = require_role("admin", "yonetici")


# ============================== KARAR DEFTERI =============================== #
async def _uyeler(
    db: AsyncSession, karar_idler: list[uuid.UUID]
) -> dict[uuid.UUID, list[KararUyesiIn]]:
    if not karar_idler:
        return {}
    rows = (
        await db.execute(
            select(KararUyesi.karar_id, KararUyesi.ad, KararUyesi.gorev)
            .where(KararUyesi.karar_id.in_(karar_idler))
            .order_by(KararUyesi.ad)
        )
    ).all()
    sonuc: dict[uuid.UUID, list[KararUyesiIn]] = {}
    for kid, ad, gorev in rows:
        sonuc.setdefault(kid, []).append(KararUyesiIn(ad=ad, gorev=gorev))
    return sonuc


async def _karar_cikti(
    db: AsyncSession, kayitlar: list[KararDefteri]
) -> list[KararDefteriOut]:
    uyeler = await _uyeler(db, [k.id for k in kayitlar])
    return [
        KararDefteriOut.model_validate(k).model_copy(
            update={"uyeler": uyeler.get(k.id, [])}
        )
        for k in kayitlar
    ]


@router.get("/karar-defteri", response_model=KararDefteriListResponse)
async def karar_listesi(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> KararDefteriListResponse:
    total = (
        await db.execute(select(func.count()).select_from(KararDefteri))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            select(KararDefteri).order_by(KararDefteri.tarih.desc(), KararDefteri.id.desc())
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    return KararDefteriListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _karar_cikti(db, list(kayitlar)),
    )


@router.post("/karar-defteri", response_model=KararDefteriOut, status_code=201)
async def karar_olustur(
    body: KararDefteriCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> KararDefteriOut:
    veri = body.model_dump(exclude={"uyeler"})
    if veri.get("tarih") is None:
        veri.pop("tarih", None)
    obj = KararDefteri(tenant_id=user.tenant_id, **veri)
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    for u in body.uyeler:
        db.add(KararUyesi(
            tenant_id=user.tenant_id, karar_id=obj.id, ad=u.ad, gorev=u.gorev
        ))
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.KARAR_UPSERT, resource_type="karar_defteri",
        resource_id=obj.id, meta={"karar_no": obj.karar_no},
    )
    return (await _karar_cikti(db, [obj]))[0]


@router.patch("/karar-defteri/{karar_id}", response_model=KararDefteriOut)
async def karar_guncelle(
    karar_id: uuid.UUID,
    body: KararDefteriUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> KararDefteriOut:
    obj = await get_or_404(db, KararDefteri, karar_id)
    veri = body.model_dump(exclude_unset=True, exclude={"uyeler"})
    for alan, deger in veri.items():
        if deger is not None or alan in ("baskan_ad",):
            setattr(obj, alan, deger)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)

    if body.uyeler is not None:
        # UYE LISTESI TAMAMEN DEGISTIRILIR: kismi ekleme/cikarma, "uyeyi
        # cikardim mi ekledim mi" belirsizligini istemciye birakirdi.
        mevcut = (
            await db.execute(
                select(KararUyesi).where(KararUyesi.karar_id == obj.id)
            )
        ).scalars().all()
        for m in mevcut:
            await db.delete(m)
        await db.flush()
        for u in body.uyeler:
            db.add(KararUyesi(
                tenant_id=user.tenant_id, karar_id=obj.id, ad=u.ad, gorev=u.gorev
            ))
        await db.flush()

    await db.refresh(obj)
    await audit_user(
        db, user, Action.KARAR_UPSERT, resource_type="karar_defteri",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return (await _karar_cikti(db, [obj]))[0]


@router.delete("/karar-defteri/{karar_id}", status_code=204, response_model=None)
async def karar_sil(
    karar_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    obj = await get_or_404(db, KararDefteri, karar_id)
    await audit_user(
        db, user, Action.KARAR_SIL, resource_type="karar_defteri",
        resource_id=obj.id, meta={"karar_no": obj.karar_no},
    )
    await db.delete(obj)
    await db.flush()


@router.get("/karar-defteri/{karar_id}/pdf")
async def karar_pdf(
    karar_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
):
    """Karar metni PDF — P31'in METIN sablonuyla.

    Tablo sablonu KULLANILMADI: karar bir YAZIDIR, sutunlu liste degil;
    tablo sablonuna sikistirmak metni hucrelere bolerdi.
    """
    obj = await get_or_404(db, KararDefteri, karar_id)
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    uyeler = (await _uyeler(db, [obj.id])).get(obj.id, [])
    govde = (
        f"Karar No: {obj.karar_no}\n"
        f"Tarih: {obj.tarih.isoformat()}\n"
        f"Konu: {obj.konu}\n\n"
        f"{obj.metin}\n\n"
        f"Başkan: {obj.baskan_ad or '—'}\n"
        "Katılan Üyeler:\n"
        + ("\n".join(
            f"  · {u.ad}" + (f" ({u.gorev})" if u.gorev else "") for u in uyeler
        ) or "  —")
    )
    icerik = metin_pdf(f"Karar Defteri — {obj.karar_no}", govde, tenant.ad)
    return Response(
        content=icerik, media_type="application/pdf",
        headers={
            "Content-Disposition":
                f'attachment; filename="karar-{obj.karar_no}.pdf"',
        },
    )


# ============================== DOKUMAN ARSIVI ============================== #
@router.get("/dokumanlar", response_model=DokumanListResponse)
async def dokuman_listesi(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> DokumanListResponse:
    total = (
        await db.execute(select(func.count()).select_from(TenantDokuman))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            select(TenantDokuman).order_by(TenantDokuman.created_at.desc(), TenantDokuman.id.desc())
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    idler = {k.yukleyen_user_id for k in kayitlar if k.yukleyen_user_id}
    adlar = dict(
        (await db.execute(
            select(AppUser.id, AppUser.ad).where(AppUser.id.in_(idler))
        )).all()
    ) if idler else {}
    return DokumanListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[
            DokumanOut.model_validate(k).model_copy(
                update={"yukleyen_ad": adlar.get(k.yukleyen_user_id)}
            )
            for k in kayitlar
        ],
    )


@router.post("/dokumanlar", response_model=DokumanOut, status_code=201)
async def dokuman_kaydet(
    body: DokumanCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> DokumanOut:
    """Dokuman KAYDI olustur (dosya presign ile ayrica yuklenir).

    Sunucu dosyayi PROXYLEMEZ: mevcut `/uploads/presign` akisi kullanilir ve
    dosya dogrudan MinIO'ya gider — proxylemek, 25 MB'lik bir yuklemeyi
    uygulama surecinin bellegine sokardi.
    """
    obj = TenantDokuman(
        tenant_id=user.tenant_id, yukleyen_user_id=user.id, **body.model_dump()
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.DOKUMAN_EKLE, resource_type="tenant_dokuman",
        resource_id=obj.id, meta={"ad": obj.ad},
    )
    # Yukleyen ADI yanitta da doner: istemci listeyi yeniden cekmeden yeni
    # satiri yerinde cizebilsin (liste ucu de ayni alani dolduruyor).
    return DokumanOut.model_validate(obj).model_copy(
        update={"yukleyen_ad": user.ad}
    )


@router.delete("/dokumanlar/{dokuman_id}", status_code=204, response_model=None)
async def dokuman_sil(
    dokuman_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> None:
    """Kaydi siler.

    MinIO OBJESI BURADAN SILINMEZ: nesne yasam dongusu depolama tarafinin
    isidir ve senkron silme, depolama erisilemezken kayit silmeyi de
    engellerdi. Kayit gidince obje erisilemez hale gelir (listede yok) ve
    yasam dongusu kurali temizler.
    """
    obj = await get_or_404(db, TenantDokuman, dokuman_id)
    await audit_user(
        db, user, Action.DOKUMAN_SIL, resource_type="tenant_dokuman",
        resource_id=obj.id, meta={"ad": obj.ad, "anahtar": obj.obje_anahtari},
    )
    await db.delete(obj)
    await db.flush()


# =============================== SITE AKTAR ================================= #
# (P154 / Asama 8) KALDIRILDI — ICE AKTARIM CATISINA devredildi.
#
# Brief'in cakisma notu acikti: "Apsiyon 'Excel ile Site Aktar' + Asama 5
# sakin yukleme + Apsiyon kisi/daire aktarimi — HEPSI tek framework
# uzerinden." Ikinci bir ice aktarim ucu tutmak, ONIZLEME + HATA RAPORU +
# ISLEM SINIRI mantigini iki yerde tutmak ve birine GERI ALMA eklerken
# otekini unutmak olurdu.
#
# KARSILIGI: `POST /ice-aktarim/daire` + `POST /ice-aktarim/kisi`.
#
# DAVRANIS FARKI DURUSTCE: eski uc TEK SATIRDA blok+daire+kisi
# yaratiyordu; cati bunlari AYRI TURLERE boluyor (brief'in kapsam listesi
# de "daireler/bloklar" ve "kisiler/sakinler" diye ayiriyor). Kisi turu
# `daire_no` alani ile var olan daireye baglanir, yani ayni sonuc IKI
# GECISTE elde edilir — ve ikinci gecis, ilkini geri almadan
# yinelenebilir.
