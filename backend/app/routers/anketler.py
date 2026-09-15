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
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    Anket,
    AnketKatilim,
    AnketOy,
    AnketSecenek,
    AppUser,
    Unit,
    UnitResident,
)
from ..schemas import (
    AnketCreate,
    AnketListResponse,
    AnketOut,
    AnketOyIstek,
    AnketOyKimListResponse,
    AnketOyKimOut,
    AnketUpdate,
    PortalAnketSecenek,
)
from ..storage import presign_get
from ..sakin_bildirimi import sakin_bildirimi_yaz
from ..scheduler.notify import dispatch_external

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
    # (P237 §3) BASLANGIC DA KAPI: ileri tarihli bir anket LISTEDE gorunur
    # (yaklasan oylama duyurudur) ama oy KABUL ETMEZ.
    if anket.baslangic_at is not None and anket.baslangic_at > simdi:
        return False
    return anket.kapanis_at is None or anket.kapanis_at > simdi


def _hedefte_mi(anket: Anket, user: AppUser, sakin_tipi: str | None) -> bool:
    """(P237 §3) Bu kullanici anketin HEDEF KITLESINDE mi?

    Yonetim HER ZAMAN gorur: anketi yoneten taraf, hedeflemedigi bir
    anketi de yonetebilmeli (kapatma, sonuc okuma). Hedefleme OY VERME
    ve BILDIRIM icin bir kapidir, yonetim gorunurlugu icin degil.
    """
    if user.role in ("admin", "yonetici"):
        return True
    roller = anket.hedef_roller or []
    if roller and user.role not in roller:
        return False
    if anket.hedef_sakin_tipi and user.role == "resident":
        return sakin_tipi == anket.hedef_sakin_tipi
    return True


async def _sakin_tipi(db: AsyncSession, user: AppUser) -> str | None:
    """`unit_resident.rol_tipi` -> 'malik' | 'kiraci' | None.

    P218: `oturuyor` MULKIYETTEN AYRI bir bayrak; malik/kiraci ayrimi
    `rol_tipi`de duruyor. Birden cok dairesi olan kisi icin MALIKLIK
    AGIR BASAR: bir dairesinde malik olan kisi "malikler" anketinin
    disinda kalmamali.
    """
    if user.role != "resident":
        return None
    tipler = set(
        (await db.execute(
            select(UnitResident.rol_tipi).where(
                UnitResident.user_id == user.id, UnitResident.bitis.is_(None)
            )
        )).scalars().all()
    )
    if "malik" in tipler:
        return "malik"
    if "kiraci" in tipler:
        return "kiraci"
    return None


async def _hedef_kisi_sayisi(db: AsyncSession, anket: Anket) -> int:
    """(P237 §3) KATILIM ORANININ PAYDASI — "kac kisiye gitti".

    Rol suzgeci SQL'de; malik/kiraci ayrimi ayri bir alt sorguyla.
    Yalniz AKTIF hesaplar sayilir: kapatilmis bir hesabi paydaya koymak,
    katilim oranini kalici olarak dusuk gosterirdi.
    """
    kosullar = [AppUser.is_active.is_(True)]
    roller = anket.hedef_roller or []
    if roller:
        kosullar.append(AppUser.role.in_(roller))
    if anket.hedef_sakin_tipi:
        sakinler = (
            select(UnitResident.user_id)
            .where(
                UnitResident.rol_tipi == anket.hedef_sakin_tipi,
                UnitResident.bitis.is_(None),
            )
            .scalar_subquery()
        )
        # Ayrim YALNIZ sakinlere uygulanir: hedefte personel de varsa
        # onlar `rol_tipi` tasimadigi icin elenmemeli.
        kosullar.append(
            or_(AppUser.role != "resident", AppUser.id.in_(sakinler))
        )
    return (
        await db.execute(select(func.count()).select_from(AppUser).where(*kosullar))
    ).scalar_one()


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
        # (P237 §3) KATILIM DEFTERINDEN okunur, oy defterinden DEGIL:
        # anonim ankette oy satirinda kimlik YOK. Tek kaynak kullanmak,
        # "oy verdim mi" sorusunun iki anket turunde ayrisan iki kod
        # yolundan yanitlanmasini engelliyor.
        verdiklerim = set(
            (await db.execute(
                select(AnketKatilim.anket_id).where(
                    AnketKatilim.anket_id.in_(idler),
                    AnketKatilim.user_id == user_id,
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
            gorsel_url=(presign_get(a.gorsel_key) if a.gorsel_key else None),
            baslangic_at=a.baslangic_at,
            kapanis_at=a.kapanis_at, aktif=a.aktif, acik=acik,
            hedef_roller=list(a.hedef_roller or []),
            hedef_sakin_tipi=a.hedef_sakin_tipi,
            anonim=a.anonim,
            oy_verdim=(a.id in verdiklerim) if user_id is not None else None,
            toplam_oy=(sum(sayim.get(s.id, 0) for s in kendi) if goster else None),
            # KATILIM ORANININ PAYDASI yalniz yonetime: "kac kisiye gitti"
            # bilgisi oy verenin karari icin bir girdi degil.
            hedef_kisi=(await _hedef_kisi_sayisi(db, a)) if sonuc_gorunur else None,
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
        aciklama=body.aciklama,
        gorsel_key=body.gorsel_key,
        baslangic_at=body.baslangic_at,
        kapanis_at=body.kapanis_at,
        hedef_roller=(body.hedef_roller or None),
        hedef_sakin_tipi=body.hedef_sakin_tipi,
        # ANONIMLIK YALNIZ BURADA BELIRLENIR. `AnketUpdate` bu alani
        # tasimiyor (extra="forbid") ve veritabani tetikleyicisi de
        # degisimi reddediyor — iki katman, cunku biri ANLASILIR hata,
        # oteki MUTLAK garanti.
        anonim=body.anonim,
    )
    db.add(obj)
    await db.flush()
    for sec in body.secenekler:
        db.add(AnketSecenek(
            tenant_id=user.tenant_id, anket_id=obj.id,
            metin=sec.metin, sira=sec.sira,
        ))
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.ANKET_OLUSTUR, resource_type="anket",
        resource_id=obj.id,
        meta={"baslik": obj.baslik, "anonim": obj.anonim},
    )
    await _anket_bildir(db, obj, user)
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

    =======================================================================
    OY DEGISTIRME — YINE YOK, AMA ARTIK IKI SEBEPLE
    =======================================================================
    (P38) Ilk sebep: degistirilebilir oy, kapanis anina kadar sonucun
    anlamsiz olmasi ve kimin ne zaman dondugunun kayda gecmesi demekti.

    (P237 §3) Ikinci sebep ANONIMLIK: anonim ankette oy satirinda kimlik
    YOK — "benim oyumu bul ve degistir" fiziksel olarak yapilamaz. Bir
    tur icin acip oteki icin kapatmak, ayni dugmenin iki ankette farkli
    davranmasi olurdu.

    =======================================================================
    ANONIMDE KIMLIK NEREYE YAZILIR
    =======================================================================
    `anket_katilim`a — KIMIN oy verdigi, NEYE oy verdigi DEGIL. Oy satiri
    `user_id = NULL` ile yazilir ve bunu veritabani ZORLAR
    (`ck_anket_oy_anonim_kimliksiz`).
    """
    anket = await get_or_404(db, Anket, anket_id)
    if not _acik_mi(anket, datetime.now(tz=timezone.utc)):
        raise APIError(409, "conflict", "anket_kapali")
    # (P237 §3) HEDEF KITLE KAPISI: hedeflenmemis kisi oy VEREMEZ.
    # Gorunurluk kapisi degil OY kapisi — sakin bir anketi listede
    # gorebilir (site genelinde ne konusuldugu bilgi degeridir) ama
    # hedefte degilse oyu sayilmaz.
    if not _hedefte_mi(anket, user, await _sakin_tipi(db, user)):
        raise APIError(403, "forbidden", "anket_hedef_disinda")
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

    # KATILIM DEFTERI ONCE: tek-oy kuralini zorlayan yapi budur ve her
    # iki anket turunde de AYNI sekilde calisir.
    db.add(AnketKatilim(
        tenant_id=user.tenant_id, anket_id=anket_id, user_id=user.id,
        gun=datetime.now(tz=timezone.utc).date(),
    ))
    db.add(AnketOy(
        tenant_id=user.tenant_id, anket_id=anket_id,
        secenek_id=secenek.id,
        user_id=None if anket.anonim else user.id,
        anonim=anket.anonim,
    ))
    try:
        await db.flush()
    except IntegrityError as exc:
        raise APIError(409, "conflict", "anket_zaten_oy_verdiniz") from exc
    # Oy verdikten SONRA bile acik anketin sonucu GIZLIDIR: kendi oyunu
    # gormek baskasinin oyunu gormek degildir.
    return (await _anket_ciktilari(
        db, [anket], user_id=user.id, sonuc_gorunur=False))[0]


@router.get(
    "/anketler/{anket_id}/oylar", response_model=AnketOyKimListResponse
)
async def oy_dokumu(
    anket_id: uuid.UUID,
    limit: int = Query(200, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETIM),
) -> AnketOyKimListResponse:
    """(P237 §3) KIM NEYE OY VERDI — YALNIZ ADLI ankette.

    ANONIM ANKETTE 409 DONER ve donecek veri de YOKTUR: kimlik
    veritabaninda durmuyor. Bu uc "yoneticiye gosterme" kararini degil,
    verinin VARLIGINI yansitir — 403 donmek "veri var ama vermiyorum"
    izlenimi yaratirdi.
    """
    anket = await get_or_404(db, Anket, anket_id)
    if anket.anonim:
        raise APIError(409, "conflict", "anket_anonim_dokum_yok")
    toplam = (
        await db.execute(
            select(func.count()).select_from(AnketOy).where(
                AnketOy.anket_id == anket_id
            )
        )
    ).scalar_one()
    satirlar = (
        await db.execute(
            select(AnketOy, AnketSecenek.metin, AppUser.ad)
            .join(AnketSecenek, AnketSecenek.id == AnketOy.secenek_id)
            .join(AppUser, AppUser.id == AnketOy.user_id, isouter=True)
            .where(AnketOy.anket_id == anket_id)
            .order_by(AnketOy.created_at, AnketOy.id)
            .limit(limit).offset(offset)
        )
    ).all()
    return AnketOyKimListResponse(
        meta={"limit": limit, "offset": offset, "total": toplam},
        items=[
            AnketOyKimOut(
                user_id=oy.user_id,
                ad=ad,
                secenek_id=oy.secenek_id,
                secenek_metin=metin,
                created_at=oy.created_at,
            )
            for oy, metin, ad in satirlar
        ],
    )


async def _anket_bildir(db, anket: Anket, user: AppUser) -> None:
    """(P237 §3) ANKET ACILINCA HEDEF KITLEYE BILDIRIM.

    TEK SEFERLIK: anket olusturuldugunda gider. Ileri tarihli baslangicta
    da SIMDI gider — "12 Ekim'de oylama var" haberinin degeri o tarihte
    degil, ONCESINDE.
    """
    kosullar = [
        AppUser.is_active.is_(True),
        AppUser.id != user.id,
    ]
    roller = anket.hedef_roller or []
    if roller:
        kosullar.append(AppUser.role.in_(roller))
    if anket.hedef_sakin_tipi:
        sakinler = (
            select(UnitResident.user_id)
            .where(
                UnitResident.rol_tipi == anket.hedef_sakin_tipi,
                UnitResident.bitis.is_(None),
            )
            .scalar_subquery()
        )
        kosullar.append(
            or_(AppUser.role != "resident", AppUser.id.in_(sakinler))
        )
    hedefler = [
        r for (r,) in (await db.execute(select(AppUser.id).where(*kosullar))).all()
    ]
    if not hedefler:
        return
    veri = {"baslik": anket.baslik}
    dispatch_external(
        "anket_acildi",
        tenant_id=anket.tenant_id,
        target_user_ids=tuple(hedefler),
        params=veri,
        data={"tip": "anket_acildi", "anket_id": str(anket.id)},
    )
    sakin_bildirimi_yaz(
        db,
        tenant_id=anket.tenant_id,
        tip="anket_acildi",
        user_ids=tuple(hedefler),
        veri=veri,
    )
