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
from ..security import normalize_phone
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..hata_metinleri import hata_metni, istek_dili
from ..models import (
    AppUser,
    BuildingBlock,
    KararDefteri,
    KararUyesi,
    Tenant,
    TenantDokuman,
    Unit,
    UnitResident,
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
    SiteAktarIstek,
    SiteAktarSablonSatiri,
    SiteAktarSonuc,
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
_SABLON_BASLIKLAR = ["blok", "daire_no", "ad", "telefon", "rol_tipi"]


@router.get("/site-aktar/sablon", response_model=SiteAktarSablonSatiri)
async def aktar_sablonu(_: AppUser = Depends(_YONETIM)) -> SiteAktarSablonSatiri:
    """Indirilebilir sablonun BASLIKLARI + ornek satir.

    Sunucu XLSX URETMEZ: panel bu basliklardan dosyayi kendisi kurar. Boylece
    sablon ile kabul edilen bicim TEK KAYNAKTAN gelir ve "indirdigim sablon
    reddedildi" durumu olusmaz.
    """
    return SiteAktarSablonSatiri(
        basliklar=_SABLON_BASLIKLAR,
        ornek=["A", "A-1", "Ali Veli", "+905321112233", "malik"],
        aciklama=(
            "blok ve daire_no zorunludur. ad + telefon birlikte verilirse "
            "sakin de olusturulur; rol_tipi malik|kiraci (bos birakilabilir). "
            "Var olan blok/daire/kisi ATLANIR — dosya yeniden yuklenebilir."
        ),
    )


@router.post("/site-aktar", response_model=SiteAktarSonuc, status_code=201)
async def site_aktar(
    body: SiteAktarIstek,
    accept_language: str | None = None,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> SiteAktarSonuc:
    """Toplu site kurulumu: bloklar + daireler + kisiler.

    SATIR BAZLI HATA RAPORU (P28 ice aktarimiyla ayni gerekce): 300 satirlik
    bir dosyada 4 hatali satir yuzunden 296 dogru satiri reddetmek,
    kullaniciyi dosyayi elle ayiklamaya zorlardi.

    `yalniz_dogrula=true` HICBIR SEY YAZMAZ — kullanici once raporu gorup
    sonra isler. Kurulum tek seferlik ve GERI ALMASI ZOR bir islemdir; onizleme
    olmadan yapilmasi yanlis bir dosyayi 300 satir boyunca uygulamak olurdu.

    IDEMPOTENT: var olan blok/daire/kisi ATLANIR, yani dosya yeniden
    yuklenebilir.
    """
    dil = istek_dili(accept_language)
    sonuc = SiteAktarSonuc()

    mevcut_bloklar = set(
        (await db.execute(select(BuildingBlock.ad))).scalars().all()
    )
    mevcut_daireler = dict(
        (await db.execute(select(Unit.no, Unit.id))).all()
    )
    mevcut_telefonlar = set(
        (await db.execute(
            select(AppUser.telefon).where(AppUser.telefon.is_not(None))
        )).scalars().all()
    )

    for satir in body.satirlar:
        blok = (satir.blok or "").strip()
        daire = (satir.daire_no or "").strip()
        if not blok or not daire:
            sonuc.hatalar.append({
                "satir_no": satir.satir_no,
                "alan": "blok" if not blok else "daire_no",
                "hata": hata_metni("zorunlu_alan_eksik", dil),
            })
            sonuc.atlanan += 1
            continue

        if blok not in mevcut_bloklar:
            if not body.yalniz_dogrula:
                db.add(BuildingBlock(tenant_id=user.tenant_id, ad=blok))
                await db.flush()
            mevcut_bloklar.add(blok)
            sonuc.blok_olusan += 1

        unit_id = mevcut_daireler.get(daire)
        if unit_id is None:
            if body.yalniz_dogrula:
                sonuc.daire_olusan += 1
            else:
                u = Unit(tenant_id=user.tenant_id, no=daire, blok=blok)
                db.add(u)
                try:
                    await db.flush()
                except IntegrityError as exc:
                    raise translate_integrity(exc)
                mevcut_daireler[daire] = u.id
                unit_id = u.id
                sonuc.daire_olusan += 1

        ad = (satir.ad or "").strip()
        tel_ham = (satir.telefon or "").strip()
        if not ad or not tel_ham:
            # Kisi satiri OPSIYONELDIR: yalniz daire kurmak gecerli bir
            # kullanim (once yapi, sonra sakinler).
            continue
        try:
            telefon = normalize_phone(tel_ham)
        except ValueError:
            sonuc.hatalar.append({
                "satir_no": satir.satir_no, "alan": "telefon",
                "hata": hata_metni("telefon_bicimi", dil),
            })
            sonuc.atlanan += 1
            continue
        if telefon in mevcut_telefonlar:
            continue
        rol = (satir.rol_tipi or "").strip().lower() or None
        if rol not in (None, "malik", "kiraci"):
            sonuc.hatalar.append({
                "satir_no": satir.satir_no, "alan": "rol_tipi",
                "hata": hata_metni("gecersiz_rol_tipi", dil),
            })
            sonuc.atlanan += 1
            continue

        if not body.yalniz_dogrula:
            kisi = AppUser(
                tenant_id=user.tenant_id, ad=ad, telefon=telefon,
                role="resident", password_set=False,
                password_hash="!",  # parola BELIRLENMEMIS (gecici kod akisi)
            )
            db.add(kisi)
            try:
                await db.flush()
            except IntegrityError as exc:
                raise translate_integrity(exc)
            if unit_id is not None:
                db.add(UnitResident(
                    tenant_id=user.tenant_id, unit_id=unit_id,
                    user_id=kisi.id, rol_tipi=rol,
                ))
                await db.flush()
        mevcut_telefonlar.add(telefon)
        sonuc.kisi_olusan += 1

    if not body.yalniz_dogrula and (
        sonuc.blok_olusan or sonuc.daire_olusan or sonuc.kisi_olusan
    ):
        await audit_user(
            db, user, Action.SITE_AKTAR, resource_type="tenant",
            resource_id=user.tenant_id,
            meta={"blok": sonuc.blok_olusan, "daire": sonuc.daire_olusan,
                  "kisi": sonuc.kisi_olusan, "hatali": len(sonuc.hatalar)},
        )
    return sonuc
