"""Site web portali + anket (P38).

IKI YUZ, TEK ROUTER:
  * `/public/{slug}/...` — KIMLIK YOK. Icerigin tamami BILINCLI secilmistir:
    sakin listesi, daire sayisi, finans ve personel BURADA YOKTUR. Duyurunun
    yalniz OZETI cikar — tam govde site ICINE yoneliktir ve tamamini
    internete acmak, sakinlere yazilmis bir metni herkese yayinlamak olurdu.
  * `/portal/...` ve `/anketler/...` — kimlikli yonetim/sakin uclari.

YAYIN KAPISI: `tenant_portal.yayinda` false ise PUBLIC uc **404** doner —
403 degil. 403, "bu tesis var ama kapali" bilgisini sizdirirdi; slug
tahminiyle tesis envanteri cikarilabilirdi.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..db import SessionLocal, set_tenant
from ..deps import get_current_user, get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    Announcement,
    Anket,
    AnketOy,
    AnketSecenek,
    AppUser,
    IletisimMesaji,
    PortalGaleri,
    Tenant,
    TenantPortal,
)
from ..schemas import (
    AnketCreate,
    AnketListResponse,
    AnketOut,
    AnketOyIstek,
    AnketUpdate,
    GaleriCreate,
    GaleriOut,
    IletisimMesajIstek,
    IletisimMesajListResponse,
    IletisimMesajOut,
    PortalAnketSecenek,
    PortalDuyuruOzet,
    PortalIcerikOut,
    PortalIcerikUpdate,
    PortalPublicOut,
)
from ..scheduler.notify import dispatch_external
from ..storage import presign_get

router = APIRouter(tags=["portal"])

_YONETIM = require_role("admin", "yonetici")
#: Anket okuma/oy: bilinen TUM roller okur, oyu YALNIZ sakin verir —
#: anket sakinlerin karar aracidir; personelin oyu site kararina girmez.
_ANKET_OKUR = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    "guvenlik_amiri",
)
_OY_VEREN = require_role("resident")

#: Duyuru ozeti bu uzunlukta kesilir (tam govde public'e cikmaz).
_OZET_UZUNLUK = 240


def _sign(key: str) -> str | None:
    try:
        return presign_get(key)
    except APIError:
        # Depo yapilandirilmamissa portal yine cizilsin; gorsel bos kalir.
        return None


def _acik_mi(anket: Anket, simdi: datetime) -> bool:
    if not anket.aktif:
        return False
    return anket.kapanis_at is None or anket.kapanis_at > simdi


async def _anket_ciktilari(
    db: AsyncSession,
    anketler: list[Anket],
    *,
    user_id: uuid.UUID | None,
    sonuc_gorunur: bool,
) -> list[AnketOut]:
    """Secenekleri + (kosullu) sayimlari TEK sorguda doldurur.

    SONUC KAPANANA KADAR GIZLI: acik bir ankette guncel dagilimi gostermek
    sonraki oy verenleri etkiler (surusel etki). Yonetim sonucu HER ZAMAN
    gorur — kararin sahibi odur.
    """
    if not anketler:
        return []
    idler = [a.id for a in anketler]
    secenekler = (
        (await db.execute(
            select(AnketSecenek).where(AnketSecenek.anket_id.in_(idler))
            .order_by(AnketSecenek.sira, AnketSecenek.metin)
        )).scalars().all()
    )
    sayim = dict(
        (await db.execute(
            select(AnketOy.secenek_id, func.count())
            .where(AnketOy.anket_id.in_(idler))
            .group_by(AnketOy.secenek_id)
        )).all()
    )
    verdiklerim: set[uuid.UUID] = set()
    if user_id is not None:
        verdiklerim = set(
            (await db.execute(
                select(AnketOy.anket_id).where(
                    AnketOy.anket_id.in_(idler), AnketOy.user_id == user_id
                )
            )).scalars().all()
        )

    simdi = datetime.now(tz=timezone.utc)
    cikti: list[AnketOut] = []
    for a in anketler:
        acik = _acik_mi(a, simdi)
        goster = sonuc_gorunur or not acik
        kendi = [s for s in secenekler if s.anket_id == a.id]
        cikti.append(AnketOut(
            id=a.id, baslik=a.baslik, aciklama=a.aciklama,
            kapanis_at=a.kapanis_at, aktif=a.aktif, acik=acik,
            oy_verdim=(a.id in verdiklerim) if user_id is not None else None,
            toplam_oy=(sum(sayim.get(s.id, 0) for s in kendi) if goster else None),
            secenekler=[
                PortalAnketSecenek(
                    id=s.id, metin=s.metin, sira=s.sira,
                    oy=sayim.get(s.id, 0) if goster else None,
                )
                for s in kendi
            ],
            created_at=a.created_at,
        ))
    return cikti


# ================================ PUBLIC ==================================== #
@router.get("/public/{slug}", response_model=PortalPublicOut)
async def public_portal(slug: str) -> PortalPublicOut:
    """Tesisin PUBLIC sayfasi — kimlik YOK.

    Tenant baglami slug'dan kurulur (`tenant_id_by_slug`, RLS bootstrap
    SECURITY DEFINER — auth/login ile ayni desen). Yayinda degilse 404:
    403 "bu tesis var ama kapali" bilgisini sizdirir ve slug tahminiyle
    tesis envanteri cikarilabilirdi.
    """
    async with SessionLocal() as db:
        async with db.begin():
            tenant_id = (
                await db.execute(
                    text("SELECT public.tenant_id_by_slug(:s)"), {"s": slug}
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise APIError(404, "not_found", "portal_bulunamadi")
            await set_tenant(db, tenant_id)

            portal = (
                await db.execute(select(TenantPortal))
            ).scalar_one_or_none()
            if portal is None or not portal.yayinda:
                raise APIError(404, "not_found", "portal_bulunamadi")

            tenant = (await db.execute(select(Tenant))).scalar_one()
            galeri = (
                (await db.execute(
                    select(PortalGaleri).order_by(PortalGaleri.sira)
                )).scalars().all()
            )
            duyurular = (
                (await db.execute(
                    select(Announcement)
                    .order_by(Announcement.created_at.desc(), Announcement.id.desc()).limit(5)
                )).scalars().all()
            )
            anketler = (
                (await db.execute(
                    select(Anket).where(Anket.aktif.is_(True))
                    .order_by(Anket.created_at.desc(), Anket.id.desc()).limit(5)
                )).scalars().all()
            )
            # PUBLIC uc kimlik BILMEZ: `oy_verdim` None doner ve acik
            # anketin sonucu GIZLIDIR (surusel etki).
            anket_cikti = await _anket_ciktilari(
                db, list(anketler), user_id=None, sonuc_gorunur=False
            )
            return PortalPublicOut(
                slug=slug,
                tesis_adi=tenant.ad,
                hero_baslik=portal.hero_baslik,
                hero_alt=portal.hero_alt,
                hakkimizda=portal.hakkimizda,
                iletisim_adres=portal.iletisim_adres,
                iletisim_telefon=portal.iletisim_telefon,
                iletisim_email=portal.iletisim_email,
                konum_lat=float(tenant.konum_lat),
                konum_lon=float(tenant.konum_lon),
                galeri=[
                    GaleriOut.model_validate(g).model_copy(
                        update={"foto_url": _sign(g.obje_anahtari)}
                    )
                    for g in galeri
                ],
                duyurular=[
                    PortalDuyuruOzet(
                        id=d.id, baslik=d.baslik,
                        ozet=(d.govde or "")[:_OZET_UZUNLUK],
                        created_at=d.created_at,
                    )
                    for d in duyurular
                ],
                anketler=anket_cikti,
            )


@router.post("/public/{slug}/iletisim", status_code=201, response_model=dict)
async def public_iletisim(slug: str, body: IletisimMesajIstek) -> dict:
    """Iletisim formu — KAYIT ONCE, BILDIRIM SONRA.

    Mesaji dogrudan e-postaya cevirmek, SMTP yapilandirilmamis bir sitede
    mesajin SESSIZCE KAYBOLMASI demekti. Once tenant'a yazilir (yonetim
    panelden gorur), sonra push denenir — push hatasi kaydi ETKILEMEZ.
    """
    async with SessionLocal() as db:
        async with db.begin():
            tenant_id = (
                await db.execute(
                    text("SELECT public.tenant_id_by_slug(:s)"), {"s": slug}
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                raise APIError(404, "not_found", "portal_bulunamadi")
            await set_tenant(db, tenant_id)
            portal = (await db.execute(select(TenantPortal))).scalar_one_or_none()
            if portal is None or not portal.yayinda:
                raise APIError(404, "not_found", "portal_bulunamadi")

            db.add(IletisimMesaji(
                tenant_id=tenant_id, ad=body.ad, telefon=body.telefon,
                email=body.email, mesaj=body.mesaj,
            ))
            await db.flush()
    dispatch_external(
        "portal_iletisim",
        tenant_id=tenant_id,
        target_roles=("admin", "yonetici"),
        params={"ad": body.ad},
        data={"tip": "portal_iletisim"},
    )
    return {"ok": True}


# ============================== YONETIM ===================================== #
@router.get("/portal", response_model=PortalIcerikOut)
async def portal_getir(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> PortalIcerikOut:
    portal = (await db.execute(select(TenantPortal))).scalar_one_or_none()
    return PortalIcerikOut.model_validate(portal) if portal else PortalIcerikOut()


@router.patch("/portal", response_model=PortalIcerikOut)
async def portal_guncelle(
    body: PortalIcerikUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> PortalIcerikOut:
    """Icerik + yayin anahtari. Satir YOKSA ilk yazmada olusur (tenant
    olusturmada bos bir satir acmak, hic kullanilmayacak tesislerde
    gereksiz satir birakirdi)."""
    portal = (await db.execute(select(TenantPortal))).scalar_one_or_none()
    if portal is None:
        portal = TenantPortal(tenant_id=user.tenant_id)
        db.add(portal)
        await db.flush()
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        setattr(portal, alan, deger)
    portal.updated_at = func.now()
    await db.flush()
    await db.refresh(portal)
    if "yayinda" in veri:
        # Yayin acma/kapama DENETLENIR: tesisin adi ve adresi internete
        # cikiyor — kimin ne zaman actigi sonradan sorulabilmeli.
        await audit_user(
            db, user, Action.PORTAL_YAYIN, resource_type="tenant_portal",
            resource_id=user.tenant_id, meta={"yayinda": str(veri["yayinda"])},
        )
    return PortalIcerikOut.model_validate(portal)


@router.get("/portal/galeri", response_model=list[GaleriOut])
async def galeri_listesi(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> list[GaleriOut]:
    kayitlar = (
        (await db.execute(select(PortalGaleri).order_by(PortalGaleri.sira)))
        .scalars().all()
    )
    return [
        GaleriOut.model_validate(g).model_copy(
            update={"foto_url": _sign(g.obje_anahtari)}
        )
        for g in kayitlar
    ]


@router.post("/portal/galeri", response_model=GaleriOut, status_code=201)
async def galeri_ekle(
    body: GaleriCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> GaleriOut:
    if not body.obje_anahtari.startswith(f"{user.tenant_id}/"):
        # Baska tenant'in objesini kendi galerisine koymak IDOR olurdu.
        raise APIError(422, "invalid_foto_key", "foto_key_alan_disi")
    obj = PortalGaleri(
        tenant_id=user.tenant_id, obje_anahtari=body.obje_anahtari,
        baslik=body.baslik, sira=body.sira,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    return GaleriOut.model_validate(obj).model_copy(
        update={"foto_url": _sign(obj.obje_anahtari)}
    )


@router.delete("/portal/galeri/{galeri_id}", status_code=204, response_model=None)
async def galeri_sil(
    galeri_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> None:
    obj = await get_or_404(db, PortalGaleri, galeri_id)
    await db.delete(obj)
    await db.flush()


@router.get("/portal/iletisim", response_model=IletisimMesajListResponse)
async def iletisim_listesi(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YONETIM),
) -> IletisimMesajListResponse:
    total = (
        await db.execute(select(func.count()).select_from(IletisimMesaji))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            select(IletisimMesaji).order_by(IletisimMesaji.created_at.desc(), IletisimMesaji.id.desc())
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    return IletisimMesajListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[IletisimMesajOut.model_validate(k) for k in kayitlar],
    )


# =============================== ANKET ====================================== #
@router.get("/anketler", response_model=AnketListResponse)
async def anket_listesi(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ANKET_OKUR),
) -> AnketListResponse:
    total = (
        await db.execute(select(func.count()).select_from(Anket))
    ).scalar_one()
    kayitlar = (
        (await db.execute(
            select(Anket).order_by(Anket.created_at.desc(), Anket.id.desc())
            .limit(limit).offset(offset)
        )).scalars().all()
    )
    return AnketListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=await _anket_ciktilari(
            db, list(kayitlar), user_id=user.id,
            sonuc_gorunur=user.role in ("admin", "yonetici"),
        ),
    )


@router.post("/anketler", response_model=AnketOut, status_code=201)
async def anket_olustur(
    body: AnketCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> AnketOut:
    obj = Anket(
        tenant_id=user.tenant_id, baslik=body.baslik,
        aciklama=body.aciklama, kapanis_at=body.kapanis_at,
    )
    db.add(obj)
    await db.flush()
    for s in body.secenekler:
        db.add(AnketSecenek(
            tenant_id=user.tenant_id, anket_id=obj.id,
            metin=s.metin, sira=s.sira,
        ))
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.ANKET_OLUSTUR, resource_type="anket",
        resource_id=obj.id, meta={"baslik": obj.baslik},
    )
    return (await _anket_ciktilari(
        db, [obj], user_id=user.id, sonuc_gorunur=True))[0]


@router.patch("/anketler/{anket_id}", response_model=AnketOut)
async def anket_guncelle(
    anket_id: uuid.UUID,
    body: AnketUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> AnketOut:
    """SECENEKLER DEGISTIRILEMEZ: oy verilmis bir anketin seceneklerini
    degistirmek, verilmis oylari BASKA BIR SORUYA tasimak olurdu."""
    obj = await get_or_404(db, Anket, anket_id)
    for alan, deger in body.model_dump(exclude_unset=True).items():
        setattr(obj, alan, deger)
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    return (await _anket_ciktilari(
        db, [obj], user_id=user.id, sonuc_gorunur=True))[0]


@router.post("/anketler/{anket_id}/oy", response_model=AnketOut, status_code=201)
async def oy_ver(
    anket_id: uuid.UUID,
    body: AnketOyIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OY_VEREN),
) -> AnketOut:
    """TEK OY, DEGISTIRILEMEZ.

    "Oyumu degistireyim" akisi BILINCLI OLARAK YOK: degistirilebilir oy,
    kapanis anina kadar sonucun anlamsiz olmasi ve kimin ne zaman dondugunun
    kayda gecmesi demekti. Ikinci oy **409**.
    """
    anket = await get_or_404(db, Anket, anket_id)
    if not _acik_mi(anket, datetime.now(tz=timezone.utc)):
        raise APIError(409, "conflict", "anket_kapali")
    secenek = (
        await db.execute(
            select(AnketSecenek).where(
                AnketSecenek.id == body.secenek_id,
                AnketSecenek.anket_id == anket_id,
            )
        )
    ).scalar_one_or_none()
    if secenek is None:
        # Baska anketin secenegi de buraya duser — "yanlis anket" ile
        # "olmayan secenek" ayrimi istemciye bir sey katmaz.
        raise APIError(422, "invalid_reference", "anket_secenegi_bulunamadi")

    db.add(AnketOy(
        tenant_id=user.tenant_id, anket_id=anket_id,
        secenek_id=secenek.id, user_id=user.id,
    ))
    try:
        await db.flush()
    except IntegrityError as exc:
        raise APIError(409, "conflict", "anket_zaten_oy_verdiniz") from exc
    # Oy verdikten SONRA bile acik anketin sonucu GIZLIDIR: kendi oyunu
    # gormek baskasinin oyunu gormek degildir.
    return (await _anket_ciktilari(
        db, [anket], user_id=user.id, sonuc_gorunur=False))[0]
