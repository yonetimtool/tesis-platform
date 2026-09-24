"""Duyuru — yonetimden tum tesise — /contracts/openapi.yaml.

RBAC (auth.md §4): OLUSTURMA yonetici (mobil) + admin (platform/panel);
duzenleme/silme admin+yonetici; OKUMA tum roller
(resident dahil — sakinin ilk operasyon-disi kaynagi). tenant token'dan; RLS
izole. Olusturmada HEDEF KITLENIN aktif cihazlarina push denenir (EK
gonderim — hatasi duyuru kaydini kirmaz); olusturan haric.

(E2E 2026-09, BILDIRIM-12) Hedef kitle (rol / malik-kiraci / blok): okuma
kapsami da hedefe baglidir — karar ve gerekcesi `duyuru_okuma_kosulu` ustunde.

Opsiyonel gorsel: olusturmada /uploads/presign ile yuklenmis foto_key kabul
edilir; okumada goruntuleme icin kisa omurlu presigned GET foto_url doner.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Header, Query, Response
from sqlalchemy import and_, any_, cast, exists, func, or_, select
from sqlalchemy import Text as _Text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .. import ceviri
from ..ceviri_api import (
    ceviri_isaretle_ve_kuyrukla,
    ceviri_uygula,
    yerel_harita,
)
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import Announcement, AppUser, Unit, UnitResident
from ..scheduler.notify import dispatch_external
from ..storage import presign_get
from ..schemas import (
    AnnouncementCreate,
    AnnouncementListResponse,
    AnnouncementOut,
    AnnouncementUpdate,
)

router = APIRouter(prefix="/announcements", tags=["announcements"])

# OLUSTURMA: yonetici (site yonetiminin agzi, mobil) + admin (platform
# tarafi, panel) — canli test kesin kurali, auth.md §4. Saha rolleri +
# resident 403. Duzenleme/silme de admin+yonetici.
_CREATOR = require_role("yonetici", "admin")
_SENDER = require_role("admin", "yonetici")
_READER = require_role(
    "admin", "yonetici", "security", "guvenlik_amiri", "tesis_gorevlisi", "resident"
)

# Hedefsiz duyurunun push'u bu rollere gider (okuma bu rollere acik).
_ALL_ROLES: tuple[str, ...] = (
    "admin", "yonetici", "security", "guvenlik_amiri", "tesis_gorevlisi",
    "resident",
)


def _validate_foto_key(foto_key: str | None, tenant_id: uuid.UUID) -> None:
    """foto_key kendi tenant namespace'inde olmali (make_foto_key oneki).

    Okumada bu anahtara presigned GET imzalanir — dogrulanmazsa baska
    tenant'in objesi duyuru gorseli diye sizdirilabilir (IDOR).
    """
    if foto_key is not None and not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key_alan_disi")


#: Ceviri kaydindaki tip adi (bkz. app/ceviri.py TIPLER).
_TIP = "duyuru"

#: Hedef kitleden bagimsiz her duyuruyu goren roller.
_YONETIM_ROLLERI = ("admin", "yonetici")


# ------------------------------------------------------------------------- #
# (E2E 2026-09, BILDIRIM-12) HEDEF KITLE
#
# OKUMA KAPSAMI KARARI: hedef disindaki kullanici duyuruyu LISTEDE GORMEZ
# (tekil GET 404). Anket bunun tersini yapar (herkes listede gorur, hedef
# yalniz oy + bildirim kapisidir) — cunku anketin VARLIGI bir sakinlik
# bilgisidir: "hangi konuda oylama yapildi" seffaflik geregi herkese acik.
# Duyurunun ise tek islevi OKUNMAKTIR; hedef secmek "bunu kim okusun"
# demektir. Iki somut sonuc: (1) yalniz personele yazilan is duyurusu
# ("X dairesine kapida hatirlatma yapin") sakinlere sizmaz; (2) "yalniz A
# blok su kesintisi" B blogun panosunu kirletmez. Yonetim (admin/yonetici)
# kendi duyurularini yonetebilmek icin HER ZAMAN hepsini gorur.
#
# Sakin tipi ve blok YALNIZ sakinlere uygulanir (personelin dairesi yok).
# Ikisi AYNI dairede birlikte aranir: A'da kiraci, B'de malik biri "A blok
# malikleri" duyurusunun hedefinde DEGILDIR.
# ------------------------------------------------------------------------- #
def _bos(kolon):
    return or_(kolon.is_(None), func.cardinality(kolon) == 0)


def duyuru_okuma_kosulu(user: AppUser):
    """Kullanicinin okuyabilecegi duyurular icin WHERE ifadesi (None = hepsi)."""
    if user.role in _YONETIM_ROLLERI:
        return None
    rol_uyar = or_(
        _bos(Announcement.hedef_roller),
        Announcement.hedef_roller.any(user.role),
    )
    if user.role != "resident":
        return rol_uyar
    dairem_uyar = exists(
        select(UnitResident.id)
        .join(Unit, Unit.id == UnitResident.unit_id)
        .where(
            UnitResident.user_id == user.id,
            UnitResident.bitis.is_(None),
            or_(
                Announcement.hedef_sakin_tipi.is_(None),
                cast(UnitResident.rol_tipi, _Text) == Announcement.hedef_sakin_tipi,
            ),
            or_(
                _bos(Announcement.hedef_bloklar),
                Unit.blok == any_(Announcement.hedef_bloklar),
            ),
        )
    )
    return and_(
        rol_uyar,
        or_(
            and_(
                Announcement.hedef_sakin_tipi.is_(None),
                _bos(Announcement.hedef_bloklar),
            ),
            dairem_uyar,
        ),
    )


async def _push_alicilari(
    db: AsyncSession, obj: Announcement, olusturan: AppUser
) -> list[uuid.UUID]:
    """Hedef kitledeki AKTIF kullanicilar — OLUSTURAN HARIC.

    (BILDIRIM-12) Eskiden push rol listesine gidiyordu ve duyuruyu yazan
    yonetici kendi duyurusunun bildirimini aliyordu.
    """
    roller = list(obj.hedef_roller or []) or list(_ALL_ROLES)
    kosullar = [
        AppUser.is_active.is_(True),
        AppUser.id != olusturan.id,
        AppUser.role.in_(roller),
    ]
    if obj.hedef_sakin_tipi or obj.hedef_bloklar:
        daire_kosul = [UnitResident.bitis.is_(None)]
        if obj.hedef_sakin_tipi:
            daire_kosul.append(
                cast(UnitResident.rol_tipi, _Text) == obj.hedef_sakin_tipi
            )
        if obj.hedef_bloklar:
            daire_kosul.append(Unit.blok.in_(list(obj.hedef_bloklar)))
        sakinler = (
            select(UnitResident.user_id)
            .join(Unit, Unit.id == UnitResident.unit_id)
            .where(*daire_kosul)
            .scalar_subquery()
        )
        kosullar.append(
            or_(AppUser.role != "resident", AppUser.id.in_(sakinler))
        )
    return [
        r for (r,) in (await db.execute(select(AppUser.id).where(*kosullar))).all()
    ]


def _out(
    obj: Announcement,
    olusturan_ad: str | None,
    yerel: ceviri.Yerel | None = None,
) -> AnnouncementOut:
    out = AnnouncementOut.model_validate(obj)
    out.olusturan_ad = olusturan_ad
    # Metin alanlarini istenen dile cevir + ceviri bayraklarini doldur.
    ceviri_uygula(out, tip_ad=_TIP, yerel=yerel, kaynak_dil=obj.kaynak_dil)
    if obj.foto_key:
        try:
            out.foto_url = presign_get(obj.foto_key)
        except APIError:
            # Depo yapilandirilmamissa okuma akisi kirilmasin; foto_url bos kalir.
            out.foto_url = None
    return out


@router.get("", response_model=AnnouncementListResponse)
async def list_announcements(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    dil: str | None = Query(
        None,
        description="Accept-Language'i EZER. Dil kodu (tr/en/ar/ru/de/fr/es) "
        "ya da 'orijinal' (kaynak dil).",
    ),
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> AnnouncementListResponse:
    kosul = duyuru_okuma_kosulu(user)
    kosullar = [kosul] if kosul is not None else []
    total = (
        await db.execute(
            select(func.count()).select_from(Announcement).where(*kosullar)
        )
    ).scalar_one()
    rows = (
        await db.execute(
            select(Announcement, AppUser.ad)
            .join(AppUser, AppUser.id == Announcement.olusturan_user_id)
            .where(*kosullar)
            .order_by(Announcement.created_at.desc(), Announcement.id.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()
    yereller = await yerel_harita(
        db,
        tip_ad=_TIP,
        objeler=[a for a, _ad in rows],
        accept_language=accept_language,
        istek_dil=dil,
    )
    return AnnouncementListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(a, ad, yereller.get(a.id)) for a, ad in rows],
    )


@router.get("/{announcement_id}", response_model=AnnouncementOut)
async def get_announcement(
    announcement_id: uuid.UUID,
    dil: str | None = Query(None, description="Accept-Language'i ezer (bkz. liste)."),
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> AnnouncementOut:
    obj = await get_or_404(db, Announcement, announcement_id)
    kosul = duyuru_okuma_kosulu(user)
    if kosul is not None:
        # (BILDIRIM-12) Hedef disi: VARLIGI da sizmasin -> 404 (403 degil).
        gorur = (
            await db.execute(
                select(Announcement.id).where(
                    Announcement.id == obj.id, kosul
                )
            )
        ).scalar_one_or_none()
        if gorur is None:
            raise APIError(404, "not_found", "kayit_bulunamadi")
    ad = (
        await db.execute(select(AppUser.ad).where(AppUser.id == obj.olusturan_user_id))
    ).scalar_one_or_none()
    yereller = await yerel_harita(
        db,
        tip_ad=_TIP,
        objeler=[obj],
        accept_language=accept_language,
        istek_dil=dil,
    )
    return _out(obj, ad, yereller.get(obj.id))


@router.post("", response_model=AnnouncementOut, status_code=201)
async def create_announcement(
    body: AnnouncementCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_CREATOR),
) -> AnnouncementOut:
    _validate_foto_key(body.foto_key, user.tenant_id)
    obj = Announcement(
        tenant_id=user.tenant_id,
        baslik=body.baslik,
        govde=body.govde,
        foto_key=body.foto_key,
        olusturan_user_id=user.id,
        hedef_roller=(body.hedef_roller or None),
        hedef_sakin_tipi=body.hedef_sakin_tipi,
        hedef_bloklar=(body.hedef_bloklar or None),
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # 7 dile ceviri: hedef diller 'bekliyor' acilir + is kuyruklanir. Ceviri
    # hatasi/kuyruk erisilemezligi duyuru kaydini DUSURMEZ (bkz. ceviri_service).
    await ceviri_isaretle_ve_kuyrukla(
        db,
        tip_ad=_TIP,
        entity_id=obj.id,
        tenant_id=user.tenant_id,
        orijinal={"baslik": obj.baslik, "govde": obj.govde},
        kaynak_dil=obj.kaynak_dil,
    )
    # EK push (in-app kaydi duyurunun kendisi; push hatasi akisi kirmaz).
    # (BILDIRIM-12) Rol listesi degil HEDEF KITLE; olusturan haric.
    alicilar = await _push_alicilari(db, obj, user)
    if alicilar:
        dispatch_external(
            "duyuru",
            tenant_id=user.tenant_id,
            target_user_ids=tuple(alicilar),
            params={"baslik": body.baslik},
            data={"tip": "duyuru", "announcement_id": str(obj.id)},
        )
    return _out(obj, user.ad)


@router.patch("/{announcement_id}", response_model=AnnouncementOut)
async def update_announcement(
    announcement_id: uuid.UUID,
    body: AnnouncementUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_SENDER),
) -> AnnouncementOut:
    _validate_foto_key(body.foto_key, user.tenant_id)
    obj = await get_or_404(db, Announcement, announcement_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # Yeniden ceviri: kaynak metin degistiyse eski ceviriler GECERSIZ. Elle
    # duzeltilmis ceviriler yalniz kaynak metin AYNI kaldiysa korunur
    # (kural: app/ceviri.py [korunur_mu]).
    await ceviri_isaretle_ve_kuyrukla(
        db,
        tip_ad=_TIP,
        entity_id=obj.id,
        tenant_id=obj.tenant_id,
        orijinal={"baslik": obj.baslik, "govde": obj.govde},
        kaynak_dil=obj.kaynak_dil,
    )
    ad = (
        await db.execute(select(AppUser.ad).where(AppUser.id == obj.olusturan_user_id))
    ).scalar_one_or_none()
    return _out(obj, ad)


@router.delete("/{announcement_id}", status_code=204)
async def delete_announcement(
    announcement_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_SENDER),
) -> Response:
    obj = await get_or_404(db, Announcement, announcement_id)
    await db.delete(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    return Response(status_code=204)
