"""(P240 §3) AKILLI EV — kopru, cihaz, bolum anahtarlari, senaryolar, olaylar.

===========================================================================
GUVENLIK SINIRI: SAKIN YALNIZ KENDI DAIRESINI GORUR
===========================================================================
Istegin acik maddesi: "Sakin yalniz kendi dairesinin cihazlarini gorsun
ve kontrol etsin — bu bir guvenlik siniri, sunucuda zorla, IDOR testi
yaz."

Sinir UC YERDE birden zorlanir ve ucu de gerekli:
  1. LISTE — sakinin sorgusuna `unit_id IN (kendi daireleri)` eklenir.
  2. DETAY/KOMUT — cihaz kimligi ELLE yazilsa bile sahiplik denetlenir
     (IDOR'un asil kapisi burasidir).
  3. ORTAK ALAN — `unit_id IS NULL` cihazlar sakine HIC gorunmez:
     kazan dairesinin vanasi sakinin isi degildir.

===========================================================================
HER KOMUT DENETIM KAYDINDA
===========================================================================
Istegin maddesi: "Tum cihaz komutlari denetim kaydina (kim, ne zaman,
hangi cihaz)". Kapi acan, vana kapatan bir sistemde bu pazarlik konusu
degil.
"""
from __future__ import annotations

import hashlib
import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from ..audit import Action, audit_user
from ..akilli_ev import TIP_EYLEM, eylem_gecerli, kopru
from ..crud_helpers import get_or_404, translate_integrity
from ..crypto import encrypt_secret
from ..db import SessionLocal, set_tenant
from ..deps import get_tenant_db, require_role
from ..entegrasyon_saglik import simdi as _simdi
from ..errors import APIError
from ..models import (
    AkilliEvBolumAyari,
    AkilliEvCihaz,
    AkilliEvKopru,
    AkilliEvSenaryo,
    AppUser,
    Unit,
    UnitResident,
)
from ..schemas import (
    AkilliEvBolumIn,
    AkilliEvBolumOut,
    AkilliEvCihazCreate,
    AkilliEvCihazListResponse,
    AkilliEvCihazOut,
    AkilliEvCihazUpdate,
    AkilliEvKomutIn,
    AkilliEvKomutOut,
    AkilliEvKopruCreate,
    AkilliEvKopruListResponse,
    AkilliEvKopruOut,
    AkilliEvKopruUpdate,
    AkilliEvOlayIn,
    AkilliEvOlayOut,
    AkilliEvSenaryoCreate,
    AkilliEvSenaryoListResponse,
    AkilliEvSenaryoOut,
    PageMetaOut,
)

router = APIRouter(prefix="/akilli-ev", tags=["akilli-ev"])

_MANAGER = require_role("admin", "yonetici")
#: Cihaz LISTESI daha genis: sakin kendi dairesini, guvenlik ortak
#: alani gorur. Kapsam sorguda daraltilir.
_OKUR = require_role(
    "admin", "yonetici", "guvenlik_amiri", "security", "tesis_gorevlisi", "resident"
)

#: Dokuz bolum — gocun aynasi.
BOLUMLER: tuple[str, ...] = (
    "protokol", "panik", "ziyaretci", "kacak", "enerji",
    "ortak_alan", "isitma", "kapi", "yangin",
)


def _jeton_hash(jeton: str) -> str:
    """Olay jetonu DUZ METIN tutulmaz (giris kodlariyla ayni kural)."""
    return hashlib.sha256(jeton.encode("utf-8")).hexdigest()


async def _sakin_daireleri(db: AsyncSession, user: AppUser) -> list[uuid.UUID]:
    return list(
        (
            await db.execute(
                select(UnitResident.unit_id).where(
                    UnitResident.user_id == user.id,
                    UnitResident.bitis.is_(None),
                )
            )
        ).scalars().all()
    )


def _cihaz_out(c: AkilliEvCihaz, daire_no: str | None = None) -> AkilliEvCihazOut:
    return AkilliEvCihazOut(
        id=c.id, kopru_id=c.kopru_id, ad=c.ad, tip=c.tip, unit_id=c.unit_id,
        daire_no=daire_no, alan=c.alan, dis_kimlik=c.dis_kimlik,
        son_durum=c.son_durum, son_veri_at=c.son_veri_at, aktif=c.aktif,
        eylemler=sorted(TIP_EYLEM.get(c.tip, frozenset())),
    )


# ============================== KOPRU ===================================== #
@router.post("/koprular", response_model=AkilliEvKopruOut, status_code=201)
async def kopru_olustur(
    body: AkilliEvKopruCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> AkilliEvKopruOut:
    obj = AkilliEvKopru(
        tenant_id=user.tenant_id, **body.model_dump(exclude={"token"})
    )
    if body.token:
        obj.token_enc = encrypt_secret(body.token)
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_kopru",
        resource_id=obj.id, meta={"islem": "olustur", "tur": obj.tur},
    )
    return AkilliEvKopruOut.from_model(obj)


@router.get("/koprular", response_model=AkilliEvKopruListResponse)
async def kopru_liste(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> AkilliEvKopruListResponse:
    toplam = int(
        (
            await db.execute(select(func.count()).select_from(AkilliEvKopru))
        ).scalar_one()
    )
    satirlar = (
        await db.execute(
            select(AkilliEvKopru)
            .order_by(AkilliEvKopru.created_at.desc(), AkilliEvKopru.id)
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    return AkilliEvKopruListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=toplam),
        items=[AkilliEvKopruOut.from_model(o) for o in satirlar],
    )


@router.patch("/koprular/{kopru_id}", response_model=AkilliEvKopruOut)
async def kopru_guncelle(
    kopru_id: uuid.UUID,
    body: AkilliEvKopruUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> AkilliEvKopruOut:
    obj = await get_or_404(db, AkilliEvKopru, kopru_id)
    veri = body.model_dump(exclude_unset=True)
    token = veri.pop("token", None)
    for k, v in veri.items():
        setattr(obj, k, v)
    if token:
        # BOS JETON "degistirme" DEMEKTIR, "sil" degil (diyafondaki
        # ayni karar): formu bos birakan yonetici baglantiyi kirmamali.
        obj.token_enc = encrypt_secret(token)
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_kopru",
        resource_id=obj.id, meta={"islem": "guncelle"},
    )
    return AkilliEvKopruOut.from_model(obj)


@router.delete("/koprular/{kopru_id}", status_code=204)
async def kopru_sil(
    kopru_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    obj = await get_or_404(db, AkilliEvKopru, kopru_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_kopru",
        resource_id=kopru_id, meta={"islem": "sil"},
    )
    return Response(status_code=204)


@router.post("/koprular/{kopru_id}/saglik", response_model=AkilliEvKomutOut)
async def kopru_saglik(
    kopru_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> AkilliEvKomutOut:
    """BAGLANTI KONTROLU — CIHAZ CALISTIRMAZ (`GET /api/`)."""
    obj = await get_or_404(db, AkilliEvKopru, kopru_id)
    sonuc = await run_in_threadpool(kopru(obj).saglik)
    an = _simdi()
    obj.saglik = "bagli" if sonuc.ok else "hata"
    obj.son_kontrol_at = an
    if sonuc.ok:
        obj.son_basarili_at = an
        obj.son_hata_kod = None
        obj.son_hata_ayrinti = None
        obj.kopus_bildirildi_at = None
    else:
        obj.son_hata_kod = sonuc.kod
        obj.son_hata_ayrinti = sonuc.ayrinti
    await db.flush()
    return AkilliEvKomutOut(ok=sonuc.ok, kod=sonuc.kod)


@router.post("/koprular/{kopru_id}/olay-jetonu", response_model=dict)
async def olay_jetonu_uret(
    kopru_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> dict:
    """Hub'in BIZE olay gonderirken kullanacagi jetonu uretir.

    JETON YALNIZ BIR KEZ GORUNUR: veritabaninda HASH'i durur. Duz metin
    saklamak, bir dokumun tum tesislere olay yazma hakki vermesi
    demekti.
    """
    obj = await get_or_404(db, AkilliEvKopru, kopru_id)
    jeton = uuid.uuid4().hex + uuid.uuid4().hex
    obj.olay_jetonu_hash = _jeton_hash(jeton)
    obj.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_kopru",
        resource_id=obj.id, meta={"islem": "olay_jetonu"},
    )
    return {"olay_jetonu": jeton}


# ============================== CIHAZ ===================================== #
@router.post("/cihazlar", response_model=AkilliEvCihazOut, status_code=201)
async def cihaz_olustur(
    body: AkilliEvCihazCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> AkilliEvCihazOut:
    if body.tip not in TIP_EYLEM:
        raise APIError(422, "validation_error", "akilli_ev_gecersiz_tip")
    # KOPRU AYNI TESISTE OLMALI: RLS sorguyu suzer ama FK'yi degil.
    await get_or_404(db, AkilliEvKopru, body.kopru_id)
    obj = AkilliEvCihaz(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_cihaz",
        resource_id=obj.id, meta={"islem": "olustur", "tip": obj.tip},
    )
    return _cihaz_out(obj)


@router.get("/cihazlar", response_model=AkilliEvCihazListResponse)
async def cihaz_liste(
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> AkilliEvCihazListResponse:
    kosullar = []
    if user.role == "resident":
        # SAKIN: YALNIZ KENDI DAIRESI. Ortak alan cihazlari (unit_id
        # NULL) DAHIL DEGIL — kazan dairesinin vanasi sakinin isi degil.
        daireler = await _sakin_daireleri(db, user)
        if not daireler:
            return AkilliEvCihazListResponse(
                meta=PageMetaOut(limit=limit, offset=offset, total=0), items=[]
            )
        kosullar.append(AkilliEvCihaz.unit_id.in_(daireler))

    toplam = int(
        (
            await db.execute(
                select(func.count()).select_from(AkilliEvCihaz).where(*kosullar)
            )
        ).scalar_one()
    )
    satirlar = (
        await db.execute(
            select(AkilliEvCihaz, Unit.no)
            .join(Unit, Unit.id == AkilliEvCihaz.unit_id, isouter=True)
            .where(*kosullar)
            .order_by(AkilliEvCihaz.created_at.desc(), AkilliEvCihaz.id)
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return AkilliEvCihazListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=toplam),
        items=[_cihaz_out(c, daire_no) for c, daire_no in satirlar],
    )


async def _cihaza_erisebilir(
    db: AsyncSession, user: AppUser, cihaz: AkilliEvCihaz
) -> bool:
    """IDOR KAPISI — kimlik elle yazilsa bile burada durur."""
    if user.role != "resident":
        return True
    if cihaz.unit_id is None:
        return False
    return cihaz.unit_id in await _sakin_daireleri(db, user)


@router.patch("/cihazlar/{cihaz_id}", response_model=AkilliEvCihazOut)
async def cihaz_guncelle(
    cihaz_id: uuid.UUID,
    body: AkilliEvCihazUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> AkilliEvCihazOut:
    obj = await get_or_404(db, AkilliEvCihaz, cihaz_id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    obj.updated_at = func.now()
    await db.flush()
    await db.refresh(obj)
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_cihaz",
        resource_id=obj.id, meta={"islem": "guncelle"},
    )
    return _cihaz_out(obj)


@router.delete("/cihazlar/{cihaz_id}", status_code=204)
async def cihaz_sil(
    cihaz_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    obj = await get_or_404(db, AkilliEvCihaz, cihaz_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_cihaz",
        resource_id=cihaz_id, meta={"islem": "sil"},
    )
    return Response(status_code=204)


@router.post("/cihazlar/{cihaz_id}/komut", response_model=AkilliEvKomutOut)
async def cihaz_komut(
    cihaz_id: uuid.UUID,
    body: AkilliEvKomutIn,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> AkilliEvKomutOut:
    """Cihaza komut — HER CAGRI DENETIM KAYDINDA.

    Kapi acan, vana kapatan bir sistemde "kim, ne zaman, hangi cihaz"
    pazarlik konusu degildir.
    """
    cihaz = await get_or_404(db, AkilliEvCihaz, cihaz_id)
    if not await _cihaza_erisebilir(db, user, cihaz):
        # 404 DEGIL 403: cihaz VAR ama bu kisinin degil. 404 donmek,
        # yoneticinin "sildim mi?" diye aramasina yol acardi.
        raise APIError(403, "forbidden", "akilli_ev_cihaz_yetkisiz")
    if not eylem_gecerli(cihaz.tip, body.eylem):
        raise APIError(422, "validation_error", "akilli_ev_eylem_desteklenmiyor")

    kayit = await get_or_404(db, AkilliEvKopru, cihaz.kopru_id)
    sonuc = await run_in_threadpool(
        kopru(kayit).komut, cihaz.dis_kimlik, body.eylem, cihaz.tip
    )
    await audit_user(
        db, user, Action.AKILLI_EV_KOMUT, resource_type="akilli_ev_cihaz",
        resource_id=cihaz.id,
        meta={"eylem": body.eylem, "tip": cihaz.tip, "ok": sonuc.ok},
    )
    return AkilliEvKomutOut(ok=sonuc.ok, kod=sonuc.kod)


# ============================ BOLUMLER ==================================== #
@router.get("/bolumler", response_model=list[AkilliEvBolumOut])
async def bolum_liste(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_OKUR),
) -> list[AkilliEvBolumOut]:
    """Dokuz bolumun acik/kapali hali. YOKLUK = KAPALI."""
    satirlar = {
        r.bolum: r.acik
        for r in (await db.execute(select(AkilliEvBolumAyari))).scalars().all()
    }
    return [AkilliEvBolumOut(bolum=b, acik=satirlar.get(b, False)) for b in BOLUMLER]


@router.put("/bolumler", response_model=list[AkilliEvBolumOut])
async def bolum_yaz(
    body: AkilliEvBolumIn,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> list[AkilliEvBolumOut]:
    """TOPLU yazim — dokuz anahtar icin dokuz istek attirmak yanlis olurdu."""
    mevcut = {
        r.bolum: r
        for r in (await db.execute(select(AkilliEvBolumAyari))).scalars().all()
    }
    for satir in body.bolumler:
        if satir.bolum not in BOLUMLER:
            raise APIError(422, "validation_error", "akilli_ev_gecersiz_bolum")
        if satir.bolum in mevcut:
            mevcut[satir.bolum].acik = satir.acik
        else:
            db.add(
                AkilliEvBolumAyari(
                    tenant_id=user.tenant_id, bolum=satir.bolum, acik=satir.acik
                )
            )
    await db.flush()
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_bolum",
        meta={"bolumler": [b.bolum for b in body.bolumler if b.acik]},
    )
    return await bolum_liste(db=db, _=user)


# ============================ SENARYOLAR ================================== #
@router.get("/senaryolar", response_model=AkilliEvSenaryoListResponse)
async def senaryo_liste(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_MANAGER),
) -> AkilliEvSenaryoListResponse:
    satirlar = (
        await db.execute(
            select(AkilliEvSenaryo, AkilliEvCihaz.ad)
            .join(AkilliEvCihaz, AkilliEvCihaz.id == AkilliEvSenaryo.cihaz_id)
            .order_by(AkilliEvSenaryo.created_at.desc(), AkilliEvSenaryo.id)
        )
    ).all()
    return AkilliEvSenaryoListResponse(
        meta=PageMetaOut(limit=len(satirlar), offset=0, total=len(satirlar)),
        items=[
            AkilliEvSenaryoOut(
                id=s.id, olay=s.olay, cihaz_id=s.cihaz_id, cihaz_ad=ad,
                eylem=s.eylem, aktif=s.aktif,
            )
            for s, ad in satirlar
        ],
    )


@router.post("/senaryolar", response_model=AkilliEvSenaryoOut, status_code=201)
async def senaryo_olustur(
    body: AkilliEvSenaryoCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> AkilliEvSenaryoOut:
    cihaz = await get_or_404(db, AkilliEvCihaz, body.cihaz_id)
    if not eylem_gecerli(cihaz.tip, body.eylem):
        # SENARYO KURULURKEN DOGRULANIR: gecersiz bir eylem, acil
        # durumda SESSIZCE calismayan bir senaryo demekti — ve o an
        # kimse hata mesaji okumuyor.
        raise APIError(422, "validation_error", "akilli_ev_eylem_desteklenmiyor")
    obj = AkilliEvSenaryo(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_senaryo",
        resource_id=obj.id, meta={"olay": obj.olay, "eylem": obj.eylem},
    )
    return AkilliEvSenaryoOut(
        id=obj.id, olay=obj.olay, cihaz_id=obj.cihaz_id, cihaz_ad=cihaz.ad,
        eylem=obj.eylem, aktif=obj.aktif,
    )


@router.delete("/senaryolar/{senaryo_id}", status_code=204)
async def senaryo_sil(
    senaryo_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    obj = await get_or_404(db, AkilliEvSenaryo, senaryo_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(
        db, user, Action.AKILLI_EV_YAZ, resource_type="akilli_ev_senaryo",
        resource_id=senaryo_id, meta={"islem": "sil"},
    )
    return Response(status_code=204)


# ============================== OLAY ====================================== #
@router.post("/olay", response_model=AkilliEvOlayOut)
async def olay_al(body: AkilliEvOlayIn) -> AkilliEvOlayOut:
    """Hub'dan gelen SENSOR OLAYI — su/gaz kacagi, yangin.

    ===================================================================
    OTURUM YOK, JETON VAR
    ===================================================================
    Cagiran bir KULLANICI degil sitedeki HUB'dir; JWT tasiyamaz. Kimlik
    `olay_jetonu` ile dogrulanir ve jeton veritabaninda HASH olarak
    durur (dokum tek basina yetki vermez).

    TENANT BAGLAMI JETONDAN TURER: SECURITY DEFINER cozucu ile kopru
    bulunur, sonra baglam ELLE kurulur. Istemcinin gonderdigi bir
    tenant kimligine GUVENILMEZ.
    """
    from sqlalchemy import text as _text

    from ..akilli_ev_olay import olay_isle

    # KENDI OTURUMUNU ACAR (odeme webhook'undaki desen): istegin
    # `get_tenant_db` bagimliligi YOK, cunku baglam ancak jetondan
    # cozulerek kurulabilir.
    async with SessionLocal() as db:
        async with db.begin():
            tenant_id = (
                await db.execute(
                    _text(
                        "SELECT public.akilli_ev_tenant_by_olay_jetonu(:h)"
                    ),
                    {"h": _jeton_hash(body.olay_jetonu)},
                )
            ).scalar_one_or_none()
            if tenant_id is None:
                # 403: jeton YANLIS. Ayrintili mesaj, gecerli bir
                # jetonun varligini sizdirirdi.
                raise APIError(403, "forbidden", "akilli_ev_jeton_gecersiz")

            await set_tenant(db, tenant_id)

            kayit = (
                await db.execute(
                    select(AkilliEvKopru).where(
                        AkilliEvKopru.olay_jetonu_hash
                        == _jeton_hash(body.olay_jetonu)
                    )
                )
            ).scalar_one_or_none()
            if kayit is None:
                raise APIError(403, "forbidden", "akilli_ev_jeton_gecersiz")

            cihaz = (
                await db.execute(
                    select(AkilliEvCihaz).where(
                        AkilliEvCihaz.kopru_id == kayit.id,
                        AkilliEvCihaz.dis_kimlik == body.dis_kimlik,
                    )
                )
            ).scalar_one_or_none()
            if cihaz is None:
                raise APIError(404, "not_found", "akilli_ev_cihaz_bulunamadi")

            cihaz.son_durum = {"olay": body.olay, "deger": body.deger}
            cihaz.son_veri_at = _simdi()
            await db.flush()

            adet = await olay_isle(db, kayit.tenant_id, cihaz, body.olay)
    return AkilliEvOlayOut(ok=True, senaryo=adet)
