"""Anket (P38) — sakinlerin karar araci.

===========================================================================
NEDEN PORTALDAN AYRILDI (P154 / Asama 7.2)
===========================================================================
Brief: "WEB: 'Site sayfasi' kaldirilacak — ozel domain hizmeti sunmuyoruz.
Rota, menu, arka uc uclari temizlensin, olu kod kalmasin."

Anket ile portal AYNI ROUTERDA yasiyordu (`routers/portal.py`) ve panelde
AYNI SAYFADAN yonetiliyordu. Portali oldugu gibi silmek, CALISAN bir
ozelligi — uctan uca isleyen, mobil karsiligi da olan anketi — birlikte
goturecekti. Mobil anket ekrani BILEREK salt-okumadir ("olusturma/kapatma
YONETIM isidir ve panele"), yani panel yuzeyi gidince anket ACILAMAZ
hâle gelirdi.

Bu yuzden once ayrildi, sonra portal kaldirildi. Uclarin YOLU ve
DAVRANISI DEGISMEDI (`/anketler...`) — mobil ve panel istemcileri icin bu
bir tasima, bir sozlesme degisikligi degil.

===========================================================================
SONUC KAPANANA KADAR GIZLI
===========================================================================
Acik bir ankette guncel dagilimi gostermek sonraki oy verenleri etkiler
(surusel etki). Yonetim sonucu HER ZAMAN gorur — kararin sahibi odur.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import Anket, AnketOy, AnketSecenek, AppUser
from ..schemas import (
    AnketCreate,
    AnketListResponse,
    AnketOut,
    AnketOyIstek,
    AnketUpdate,
    PortalAnketSecenek,
)

router = APIRouter(tags=["anket"])

_YONETIM = require_role("admin", "yonetici")
#: Anket okuma/oy: bilinen TUM roller okur, oyu YALNIZ sakin verir —
#: anket sakinlerin karar aracidir; personelin oyu site kararina girmez.
_ANKET_OKUR = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
    "guvenlik_amiri",
)
_OY_VEREN = require_role("resident")


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
