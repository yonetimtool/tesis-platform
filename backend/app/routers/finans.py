"""Tahsilat, kasa ve finansal hareketler (P29).

TEK DEFTER: tahsilat / gider / gelir / virman / iade / acilis ayni
`finansal_hareket` kaydinda `tip` ile ayrilir — "kasa bakiyesi = hareket
toplami" tutarliligi ancak TEK kaynak varken kanitlanabilir.

BAKIYE SAKLANMAZ, TURETILIR (`kasa.acilis_bakiye_kurus` + isaretli toplam):
saklanan bir bakiye her yazma yolunda elle guncellenmek zorunda kalir ve bir
yol unutuldugunda defterle bakiye sessizce ayrilir.

RBAC: yazma admin; okuma admin + yonetici. Saha/sakin ERISEMEZ.
"""
from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..finans import BankaSatiri, BorcAdayi, banka_eslestir, kasa_bakiye
from ..models import (
    AppUser,
    DuesAssessment,
    FinansalHareket,
    IcraDosyasi,
    Kasa,
)
from ..schemas import (
    AcilisFisi,
    BankaEslestirIstek,
    BankaEslestirOneri,
    BankaEslestirSonuc,
    FinansOzet,
    HareketListResponse,
    HareketOut,
    HareketToplu,
    IadeIstek,
    IcraDosyasiCreate,
    IcraDosyasiListResponse,
    IcraDosyasiOut,
    IcraDosyasiUpdate,
    KasaBakiye,
    KasaBakiyeResponse,
    TahsilatCreate,
    TopluTahsilatIstek,
    VirmanIstek,
)

router = APIRouter(tags=["finans"])

_ADMIN = require_role("admin")
_OKUMA = require_role("admin", "yonetici")


async def _kasa_var(db: AsyncSession, kasa_id: uuid.UUID) -> None:
    var = (
        await db.execute(select(Kasa.id).where(Kasa.id == kasa_id))
    ).scalar_one_or_none()
    if var is None:
        raise APIError(422, "invalid_reference", "kasa_bulunamadi")


async def _adlarla(
    db: AsyncSession, kayitlar: list[FinansalHareket]
) -> list[HareketOut]:
    """Kasa + kisi adlarini TEK sorguda coz (kayit basina N+1 yok)."""
    if not kayitlar:
        return []
    k_idler = {k.kasa_id for k in kayitlar if k.kasa_id}
    u_idler = {k.user_id for k in kayitlar if k.user_id}
    k_ad = dict(
        (await db.execute(select(Kasa.id, Kasa.ad).where(Kasa.id.in_(k_idler)))).all()
    ) if k_idler else {}
    u_ad = dict(
        (await db.execute(
            select(AppUser.id, AppUser.ad).where(AppUser.id.in_(u_idler))
        )).all()
    ) if u_idler else {}
    return [
        HareketOut.model_validate(k).model_copy(update={
            "kasa_ad": k_ad.get(k.kasa_id), "user_ad": u_ad.get(k.user_id),
        })
        for k in kayitlar
    ]


def _hareket(user: AppUser, **alanlar) -> FinansalHareket:
    tarih = alanlar.pop("tarih", None)
    obj = FinansalHareket(
        tenant_id=user.tenant_id, kaydeden_user_id=user.id, **alanlar
    )
    if tarih is not None:
        obj.tarih = tarih
    return obj


# =============================== TAHSILAT =================================== #
@router.post("/finans/tahsilat", response_model=HareketOut, status_code=201)
async def tahsilat(
    body: TahsilatCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> HareketOut:
    """Tekil tahsilat — kasaya GIRIS.

    `dues_payment` tablosuyla YARISMAZ: o tablo cevrimici odeme saglayicisi
    (idempotency, provider referansi) icindir; buradaki hareket VEZNE
    kaydidir ve kasayi etkiler. Ikisini birlestirmek, saglayici alanlarini
    her nakit tahsilatta bos birakmak demekti.
    """
    await _kasa_var(db, body.kasa_id)
    if body.assessment_id is not None:
        await get_or_404(db, DuesAssessment, body.assessment_id)
    obj = _hareket(
        user, tip="tahsilat", yon="giris", tutar_kurus=body.tutar_kurus,
        kasa_id=body.kasa_id, user_id=body.user_id, unit_id=body.unit_id,
        assessment_id=body.assessment_id, belge_no=body.belge_no,
        aciklama=body.aciklama, tarih=body.tarih,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        resource_id=obj.id, meta={"tip": "tahsilat", "tutar": obj.tutar_kurus},
    )
    return (await _adlarla(db, [obj]))[0]


@router.post("/finans/tahsilat/toplu", response_model=HareketListResponse, status_code=201)
async def toplu_tahsilat(
    body: TopluTahsilatIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> HareketListResponse:
    """Cok satirli tahsilat — TEK ISLEMDE ya hepsi ya hicbiri.

    Kismi basari, kullaniciya "kac satir gecti" diye saydirmak ve kalanlari
    elle tekrar girdirmek demekti; tahsilatta bu, ayni parayi iki kez
    kaydetme riskidir.
    """
    await _kasa_var(db, body.kasa_id)
    kayitlar = []
    for satir in body.satirlar:
        obj = _hareket(
            user, tip="tahsilat", yon="giris", tutar_kurus=satir.tutar_kurus,
            kasa_id=body.kasa_id, user_id=satir.user_id, unit_id=satir.unit_id,
            assessment_id=satir.assessment_id, aciklama=satir.aciklama,
            tarih=body.tarih,
        )
        db.add(obj)
        kayitlar.append(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    for o in kayitlar:
        await db.refresh(o)
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        meta={"tip": "tahsilat_toplu", "adet": len(kayitlar)},
    )
    return HareketListResponse(
        meta={"limit": len(kayitlar), "offset": 0, "total": len(kayitlar)},
        items=await _adlarla(db, kayitlar),
    )


# ========================= GIDER / GELIR HAREKETI =========================== #
@router.post("/finans/hareketler", response_model=HareketListResponse, status_code=201)
async def hareket_ekle(
    body: HareketToplu,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> HareketListResponse:
    """Cok satirli gider/gelir girisi ("Yeni Satır" akisi)."""
    kayitlar = []
    for satir in body.satirlar:
        await _kasa_var(db, satir.kasa_id)
        kayitlar.append(_hareket(
            user, tip=satir.tip,
            # GIDER kasadan CIKAR, GELIR kasaya GIRER — yon istemciden
            # alinmaz; alinsaydi "giris yonlu gider" gibi imkansiz bir
            # satir yazilabilirdi.
            yon="cikis" if satir.tip == "gider" else "giris",
            tutar_kurus=satir.tutar_kurus, kasa_id=satir.kasa_id,
            firma_id=satir.firma_id,
            gelir_gider_tanim_id=satir.gelir_gider_tanim_id,
            belge_no=satir.belge_no, aciklama=satir.aciklama, tarih=satir.tarih,
        ))
    for o in kayitlar:
        db.add(o)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    for o in kayitlar:
        await db.refresh(o)
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        meta={"adet": len(kayitlar)},
    )
    return HareketListResponse(
        meta={"limit": len(kayitlar), "offset": 0, "total": len(kayitlar)},
        items=await _adlarla(db, kayitlar),
    )


@router.get("/finans/hareketler", response_model=HareketListResponse)
async def hareket_listesi(
    tip: str | None = Query(None),
    kasa_id: uuid.UUID | None = Query(None),
    user_id: uuid.UUID | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUMA),
) -> HareketListResponse:
    q = select(FinansalHareket)
    if tip is not None:
        q = q.where(FinansalHareket.tip == tip)
    if kasa_id is not None:
        q = q.where(FinansalHareket.kasa_id == kasa_id)
    if user_id is not None:
        q = q.where(FinansalHareket.user_id == user_id)
    total = (
        await db.execute(select(func.count()).select_from(q.subquery()))
    ).scalar_one()
    rows = (
        (await db.execute(
            q.order_by(FinansalHareket.tarih.desc(),
                       FinansalHareket.created_at.desc())
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    return HareketListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _adlarla(db, list(rows)),
    )


# ================================ VIRMAN ==================================== #
@router.post("/finans/virman", response_model=HareketListResponse, status_code=201)
async def virman(
    body: VirmanIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> HareketListResponse:
    """Hesaplar arasi virman — IKI SATIR (cikis + giris), ayni gruba bagli.

    Tek satirla iki kasayi etkilemek, "bu kasadan ne cikti" sorgusunu kasa
    basina degil hareket basina cevaplamak zorunda birakirdi; bakiye
    turetimi de iki farkli kural isterdi.
    """
    await _kasa_var(db, body.kaynak_kasa_id)
    await _kasa_var(db, body.hedef_kasa_id)
    grup = uuid.uuid4()
    cikis = _hareket(
        user, tip="virman", yon="cikis", tutar_kurus=body.tutar_kurus,
        kasa_id=body.kaynak_kasa_id, virman_grup_id=grup,
        aciklama=body.aciklama, tarih=body.tarih,
    )
    giris = _hareket(
        user, tip="virman", yon="giris", tutar_kurus=body.tutar_kurus,
        kasa_id=body.hedef_kasa_id, virman_grup_id=grup,
        aciklama=body.aciklama, tarih=body.tarih,
    )
    db.add_all([cikis, giris])
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(cikis)
    await db.refresh(giris)
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        resource_id=cikis.id,
        meta={"tip": "virman", "grup": str(grup), "tutar": body.tutar_kurus},
    )
    return HareketListResponse(
        meta={"limit": 2, "offset": 0, "total": 2},
        items=await _adlarla(db, [cikis, giris]),
    )


# ================================= IADE ===================================== #
@router.post("/finans/iade", response_model=HareketOut, status_code=201)
async def iade(
    body: IadeIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> HareketOut:
    """Odeme iadesi — TERS YONLU yeni bir hareket.

    Orijinal kayit SILINMEZ ya da degistirilmez: defter APPEND-ONLY okunur,
    silinen bir tahsilat gecmis raporlari geriye donuk degistirirdi.
    Kismi iade serbest ama TOPLAM iade orijinali ASAMAZ.
    """
    orijinal = await get_or_404(db, FinansalHareket, body.hareket_id)
    if orijinal.tip == "iade":
        raise APIError(422, "validation_error", "iade_iade_edilemez")

    onceki = (
        await db.execute(
            select(func.coalesce(func.sum(FinansalHareket.tutar_kurus), 0))
            .where(FinansalHareket.iade_edilen_id == orijinal.id)
        )
    ).scalar_one()
    tutar = body.tutar_kurus or (orijinal.tutar_kurus - onceki)
    if tutar <= 0 or onceki + tutar > orijinal.tutar_kurus:
        raise APIError(422, "validation_error", "iade_tutari_asiyor")

    obj = _hareket(
        user, tip="iade",
        # TERS yon: giris olan bir tahsilatin iadesi kasadan CIKAR.
        yon="cikis" if orijinal.yon == "giris" else "giris",
        tutar_kurus=tutar, kasa_id=orijinal.kasa_id, user_id=orijinal.user_id,
        unit_id=orijinal.unit_id, iade_edilen_id=orijinal.id,
        aciklama=body.aciklama, tarih=body.tarih,
    )
    db.add(obj)
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        resource_id=obj.id, meta={"tip": "iade", "orijinal": str(orijinal.id)},
    )
    return (await _adlarla(db, [obj]))[0]


# ============================== ACILIS FISI ================================= #
@router.post("/finans/acilis", response_model=HareketOut, status_code=201)
async def acilis_fisi(
    body: AcilisFisi,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> HareketOut:
    """Acilis fisi — kisi/kasa baslangic bakiyesi defterde bir HAREKETTIR.

    Kasa tanimindaki `acilis_bakiye_kurus` KASANIN kendi acilisidir; bu fis
    ise KISI bazli acilis (devreden borc/alacak) icindir ve ikisi ayni
    toplama girer.
    """
    await _kasa_var(db, body.kasa_id)
    obj = _hareket(
        user, tip="acilis", yon=body.yon, tutar_kurus=body.tutar_kurus,
        kasa_id=body.kasa_id, user_id=body.user_id, aciklama=body.aciklama,
        tarih=body.tarih,
    )
    db.add(obj)
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.FINANS_HAREKET_CREATE, resource_type="finansal_hareket",
        resource_id=obj.id, meta={"tip": "acilis"},
    )
    return (await _adlarla(db, [obj]))[0]


# ============================== KASA BAKIYE ================================= #
@router.get("/finans/kasa-bakiyeleri", response_model=KasaBakiyeResponse)
async def kasa_bakiyeleri(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUMA),
) -> KasaBakiyeResponse:
    """Kasa bakiyeleri — SAKLANMAZ, defterden TURETILIR."""
    kasalar = (await db.execute(select(Kasa).order_by(Kasa.kod))).scalars().all()
    hareketler = (
        await db.execute(
            select(
                FinansalHareket.kasa_id,
                FinansalHareket.yon,
                func.sum(FinansalHareket.tutar_kurus),
            ).group_by(FinansalHareket.kasa_id, FinansalHareket.yon)
        )
    ).all()
    gruplu: dict[uuid.UUID, list[tuple[str, int]]] = {}
    for kid, yon, toplam in hareketler:
        if kid is not None:
            gruplu.setdefault(kid, []).append((yon, int(toplam)))

    items = []
    for k in kasalar:
        satirlar = gruplu.get(k.id, [])
        bakiye = kasa_bakiye(k.acilis_bakiye_kurus, satirlar)
        items.append(KasaBakiye(
            kasa_id=k.id, kod=k.kod, ad=k.ad,
            acilis_bakiye_kurus=k.acilis_bakiye_kurus,
            hareket_kurus=bakiye - k.acilis_bakiye_kurus,
            bakiye_kurus=bakiye,
        ))
    return KasaBakiyeResponse(
        items=items, genel_toplam_kurus=sum(i.bakiye_kurus for i in items)
    )


# ============================ BANKA ESLESTIRME ============================== #
@router.post("/finans/banka-eslestir", response_model=BankaEslestirSonuc)
async def banka_eslestirme(
    body: BankaEslestirIstek,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_ADMIN),
) -> BankaEslestirSonuc:
    """Banka ekstresi satirlarina ESLESTIRME ONERISI uret.

    ONERI'dir, otomatik tahsilat DEGILDIR: banka aciklamasi serbest metindir
    ve yanlis eslesen bir satir, baskasinin borcunu kapatip gercek borclunun
    borcunu acik birakirdi. Kullanici tek tikla onaylar.

    DOSYA AYRISTIRMA ISTEMCIDE (P28 ice aktarimla ayni gerekce: xlsx
    ayristirma bir saldiri yuzeyidir). BANKA API ENTEGRASYONU KOD DEGIL
    BELGE NOTUDUR (kapsam boyle diyor) — her bankanin ayri sozlesmesi ve
    kimlik akisi var; once bir banka secilmeli.
    """
    # Acik borclu adaylari: hedeflenmis borclar (P28) + kalan tutar.
    rows = (
        await db.execute(
            # NOT: ORNEK BIR `assessment_id` DONULMEZ. (a) Postgres'te
            # `min(uuid)` yoktur — bu sorgu 500 veriyordu; (b) daha onemlisi
            # oneri KISIYI hedefler: hangi borcun kapatilacagi tahsilat
            # ekraninin isidir, cunku bir odeme birden fazla borca yayilabilir.
            select(
                DuesAssessment.hedef_user_id,
                AppUser.ad,
                func.sum(DuesAssessment.tutar_kurus),
                # (P30) Havale kodu — aciklamada gecerse eslestirme KESIN.
                func.max(AppUser.odeme_kodu),
            )
            .join(AppUser, AppUser.id == DuesAssessment.hedef_user_id)
            .where(DuesAssessment.hedef_user_id.is_not(None))
            .group_by(DuesAssessment.hedef_user_id, AppUser.ad)
        )
    ).all()
    tahsil = dict(
        (
            await db.execute(
                select(
                    FinansalHareket.user_id,
                    func.sum(FinansalHareket.tutar_kurus),
                )
                .where(
                    FinansalHareket.tip == "tahsilat",
                    FinansalHareket.user_id.is_not(None),
                )
                .group_by(FinansalHareket.user_id)
            )
        ).all()
    )
    adaylar = []
    for uid, ad, borc, kod in rows:
        kalan = int(borc) - int(tahsil.get(uid, 0))
        if kalan > 0:
            adaylar.append(BorcAdayi(str(uid), ad, kalan, odeme_kodu=kod))

    oneriler = banka_eslestir(
        [BankaSatiri(s.satir_no, s.aciklama, s.tutar_kurus) for s in body.satirlar],
        adaylar,
    )
    adlar = {a.user_id: a.ad for a in adaylar}
    return BankaEslestirSonuc(oneriler=[
        BankaEslestirOneri(
            satir_no=o.satir_no,
            user_id=uuid.UUID(o.user_id) if o.user_id else None,
            user_ad=adlar.get(o.user_id) if o.user_id else None,
            assessment_id=uuid.UUID(o.assessment_id) if o.assessment_id else None,
            guven=o.guven, neden=o.neden,
        )
        for o in oneriler
    ])


# =============================== ICRA DOSYASI =============================== #
async def _icra_zenginlestir(
    db: AsyncSession, kayitlar: list[IcraDosyasi]
) -> list[IcraDosyasiOut]:
    """Kisi adi + ACIK BORC — borc dosyaya KOPYALANMAZ, anlik okunur.

    Iki yerde tutulan borc, biri guncellenip digeri unutuldugunda hangi
    rakamin dogru oldugunu belirsiz birakirdi.
    """
    if not kayitlar:
        return []
    idler = {k.user_id for k in kayitlar}
    adlar = dict(
        (await db.execute(
            select(AppUser.id, AppUser.ad).where(AppUser.id.in_(idler))
        )).all()
    )
    borclar = dict(
        (await db.execute(
            select(DuesAssessment.hedef_user_id,
                   func.sum(DuesAssessment.tutar_kurus))
            .where(DuesAssessment.hedef_user_id.in_(idler))
            .group_by(DuesAssessment.hedef_user_id)
        )).all()
    )
    tahsil = dict(
        (await db.execute(
            select(FinansalHareket.user_id,
                   func.sum(FinansalHareket.tutar_kurus))
            .where(FinansalHareket.tip == "tahsilat",
                   FinansalHareket.user_id.in_(idler))
            .group_by(FinansalHareket.user_id)
        )).all()
    )
    return [
        IcraDosyasiOut.model_validate(k).model_copy(update={
            "user_ad": adlar.get(k.user_id),
            "acik_borc_kurus": max(
                int(borclar.get(k.user_id, 0)) - int(tahsil.get(k.user_id, 0)), 0
            ),
        })
        for k in kayitlar
    ]


@router.get("/finans/icra-dosyalari", response_model=IcraDosyasiListResponse)
async def icra_listesi(
    durum: str | None = Query(None),
    user_id: uuid.UUID | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUMA),
) -> IcraDosyasiListResponse:
    q = select(IcraDosyasi)
    if durum is not None:
        q = q.where(IcraDosyasi.durum == durum)
    if user_id is not None:
        q = q.where(IcraDosyasi.user_id == user_id)
    total = (
        await db.execute(select(func.count()).select_from(q.subquery()))
    ).scalar_one()
    rows = (
        (await db.execute(
            q.order_by(IcraDosyasi.created_at.desc()).limit(limit).offset(offset)
        )).scalars().all()
    )
    return IcraDosyasiListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _icra_zenginlestir(db, list(rows)),
    )


@router.post("/finans/icra-dosyalari", response_model=IcraDosyasiOut, status_code=201)
async def icra_olustur(
    body: IcraDosyasiCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> IcraDosyasiOut:
    var = (
        await db.execute(select(AppUser.id).where(AppUser.id == body.user_id))
    ).scalar_one_or_none()
    if var is None:
        raise APIError(422, "invalid_reference", "kullanici_bulunamadi_veya_pasif")
    obj = IcraDosyasi(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.ICRA_DOSYA_CREATE, resource_type="icra_dosyasi",
        resource_id=obj.id, meta={"dosya_no": obj.dosya_no},
    )
    return (await _icra_zenginlestir(db, [obj]))[0]


@router.patch("/finans/icra-dosyalari/{dosya_id}", response_model=IcraDosyasiOut)
async def icra_guncelle(
    dosya_id: uuid.UUID,
    body: IcraDosyasiUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> IcraDosyasiOut:
    obj = await get_or_404(db, IcraDosyasi, dosya_id)
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.ICRA_DOSYA_UPDATE, resource_type="icra_dosyasi",
        resource_id=obj.id, meta={"alanlar": sorted(veri)},
    )
    return (await _icra_zenginlestir(db, [obj]))[0]


# ================================ OZET ====================================== #
@router.get("/finans/ozet", response_model=FinansOzet)
async def finans_ozet(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUMA),
) -> FinansOzet:
    """Panel ozet kartlari — hepsi DEFTERDEN okunur, hicbiri saklanmaz."""
    bugun = datetime.now(timezone.utc).date()
    ay_basi = date(bugun.year, bugun.month, 1)

    borclandirilan = (
        await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0))
            .where(DuesAssessment.tarih >= ay_basi)
        )
    ).scalar_one()
    tahsil_ay = (
        await db.execute(
            select(func.coalesce(func.sum(FinansalHareket.tutar_kurus), 0))
            .where(FinansalHareket.tip == "tahsilat",
                   FinansalHareket.tarih >= ay_basi)
        )
    ).scalar_one()
    toplam_borc = (
        await db.execute(
            select(func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0))
        )
    ).scalar_one()
    toplam_tahsil = (
        await db.execute(
            select(func.coalesce(func.sum(FinansalHareket.tutar_kurus), 0))
            .where(FinansalHareket.tip == "tahsilat")
        )
    ).scalar_one()
    bakiyeler = await kasa_bakiyeleri(db=db, _=None)  # type: ignore[arg-type]
    icra_acik = (
        await db.execute(
            select(func.count()).select_from(IcraDosyasi)
            .where(IcraDosyasi.durum.in_(["acik", "takipte"]))
        )
    ).scalar_one()
    return FinansOzet(
        borclandirilan_ay_kurus=int(borclandirilan),
        tahsil_edilen_ay_kurus=int(tahsil_ay),
        acik_borc_kurus=max(int(toplam_borc) - int(toplam_tahsil), 0),
        kasa_toplam_kurus=bakiyeler.genel_toplam_kurus,
        icra_acik_dosya=int(icra_acik),
    )
