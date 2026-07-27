"""Etkinlik + RSVP — yonetici duyurur, sakinler katilim beyan eder.

Akis (urun sahibi sabit):
  1. Yonetici etkinlik olusturur (baslik + aciklama + tarih + opsiyonel konum;
     orn. cenaze, mac izleme).
  2. TUM SAKINLERE push denenir ("Yeni etkinlik: ...") — hedef kitle sakinler
     (etkinlik site topluluguna yonelik; personel push almaz ama OKUR — karar
     auth.md §4'te belirtildi).
  3. Sakin RSVP verir: katiliyorum | katilmiyorum. Kullanici basina TEK kayit
     (UNIQUE) ve KILITLI — ilk beyandan sonra DEGISTIRILEMEZ (secim kesin).
     Mevcut beyan varsa tekrar PUT 409 doner; ON CONFLICT DO NOTHING ile
     es zamanli iki ilk-PUT'ta da cift kayit imkansiz (ilki kazanir).
  4. SAYILAR SEFFAF: katiliyorum/katilmiyorum sayilarini TUM roller gorur.
     Kim-katiliyor listesi URUN GEREGI paylasilmaz — kimlik degil yalniz sayi
     (benim_durumum yalniz istekteki kullanicinin KENDI beyanidir).

Opsiyonel gorsel: olusturma/duzenlemede /uploads/presign ile yuklenmis
foto_key kabul edilir (duyuru + site kurali ile AYNI mekanizma: ayni depo,
ayni boyut/tur limitleri, tenant-namespace IDOR kontrolu); okumada kisa
omurlu presigned GET `foto_url` doner.

Yaklasan/aktif suzgeci: `?aktif=true` -> `COALESCE(bitis_zamani, tarih) >=
now()`. Etkinlik BITISI gecene kadar listede kalir; bitis verilmemisse
etkinlik anliktir (bitis = baslangic). aktif=true siralamasi YAKLASAN
(ASC — en yakin once); suzgecsiz liste EN YENI once (DESC, geriye uyumlu).

RBAC (auth.md §4): OLUSTUR/DUZENLE/SIL admin+yonetici (duyuru deseni).
OKUMA TUM roller (sayilar dahil — seffaflik). RSVP YALNIZ resident —
etkinligin muhatabi sakinlerdir; personel katilim beyani vermez (karar).
Tenant token'dan; RLS izole. Push EK gonderimdir — hatasi kaydi kirmaz.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Header, Query, Response
from sqlalchemy import case, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .. import ceviri
from ..ceviri_api import (
    ceviri_isaretle_ve_kuyrukla,
    ceviri_uygula,
    yerel_harita,
)
from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Etkinlik, EtkinlikKatilim
from ..scheduler.notify import dispatch_external
from ..storage import presign_get
from ..schemas import (
    EtkinlikCreate,
    EtkinlikListResponse,
    EtkinlikOut,
    EtkinlikRsvp,
    EtkinlikUpdate,
)

router = APIRouter(prefix="/events", tags=["etkinlik"])

# Etkinligi site yonetimi duyurur (duyuru/announcement deseni).
_MANAGER = require_role("admin", "yonetici")
# Okuma + seffaf sayilar TUM roller.
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
# RSVP yalniz sakin: etkinligin muhatabi site sakinleri (karar auth.md §4).
_RSVP = require_role("resident")

# Yeni etkinlik push'u SAKINLERE gider (hedef kitle).
_AUDIENCE_ROLES: tuple[str, ...] = ("resident",)


def _validate_foto_key(foto_key: str | None, tenant_id: uuid.UUID) -> None:
    """foto_key kendi tenant namespace'inde olmali (duyuru/site kurali ile ayni
    IDOR korumasi: okumada bu anahtara presigned GET imzalanir)."""
    if foto_key is not None and not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key tenant alani disinda")


#: Ceviri kaydindaki tip adi (bkz. app/ceviri.py TIPLER).
_TIP = "etkinlik"


def _out(
    obj: Etkinlik, olusturan_ad, katiliyor, katilmiyor, benim,
    yerel: ceviri.Yerel | None = None,
) -> EtkinlikOut:
    out = EtkinlikOut.model_validate(obj)
    out.olusturan_ad = olusturan_ad
    out.katiliyorum_sayisi = int(katiliyor or 0)
    out.katilmiyorum_sayisi = int(katilmiyor or 0)
    out.benim_durumum = benim
    # Metin alanlarini istenen dile cevir + ceviri bayraklarini doldur.
    ceviri_uygula(out, tip_ad=_TIP, yerel=yerel, kaynak_dil=obj.kaynak_dil)
    if obj.foto_key:
        try:
            out.foto_url = presign_get(obj.foto_key)
        except APIError:
            # Depo yapilandirilmamissa okuma akisi kirilmasin (duyuru deseni).
            out.foto_url = None
    return out


def _bitis_ifadesi():
    """Etkinligin BITIS ani — bitis verilmemisse baslangic (anlik etkinlik)."""
    return func.coalesce(Etkinlik.bitis_zamani, Etkinlik.tarih)


def _base_stmt(user: AppUser):
    """Liste/detay ortak SELECT'i: olusturan adi + SEFFAF sayilar (agregat) +
    istekteki kullanicinin kendi RSVP'si. Kimlikler donmez — yalniz sayi."""
    sayilar = (
        select(
            EtkinlikKatilim.etkinlik_id.label("eid"),
            func.count(
                case((EtkinlikKatilim.durum == "katiliyorum", 1))
            ).label("katiliyor"),
            func.count(
                case((EtkinlikKatilim.durum == "katilmiyorum", 1))
            ).label("katilmiyor"),
        )
        .group_by(EtkinlikKatilim.etkinlik_id)
        .subquery()
    )
    benim = (
        select(
            EtkinlikKatilim.etkinlik_id.label("eid"),
            EtkinlikKatilim.durum.label("durum"),
        )
        .where(EtkinlikKatilim.user_id == user.id)
        .subquery()
    )
    return (
        select(
            Etkinlik,
            AppUser.ad,
            sayilar.c.katiliyor,
            sayilar.c.katilmiyor,
            benim.c.durum,
        )
        .join(AppUser, AppUser.id == Etkinlik.olusturan_user_id)
        .outerjoin(sayilar, sayilar.c.eid == Etkinlik.id)
        .outerjoin(benim, benim.c.eid == Etkinlik.id)
    )


async def _load_out(
    db: AsyncSession,
    user: AppUser,
    etkinlik_id: uuid.UUID,
    *,
    accept_language: str | None = None,
    istek_dil: str | None = None,
) -> EtkinlikOut:
    row = (
        await db.execute(_base_stmt(user).where(Etkinlik.id == etkinlik_id))
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    yereller = await yerel_harita(
        db,
        tip_ad=_TIP,
        objeler=[row[0]],
        accept_language=accept_language,
        istek_dil=istek_dil,
    )
    return _out(*row, yereller.get(row[0].id))


# ------------------------------- yonetim ------------------------------------ #
@router.post("", response_model=EtkinlikOut, status_code=201)
async def create_event(
    body: EtkinlikCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> EtkinlikOut:
    _validate_foto_key(body.foto_key, user.tenant_id)
    obj = Etkinlik(
        tenant_id=user.tenant_id,
        baslik=body.baslik,
        aciklama=body.aciklama,
        tarih=body.tarih,
        bitis_zamani=body.bitis_zamani,
        konum=body.konum,
        foto_key=body.foto_key,
        olusturan_user_id=user.id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # 7 dile ceviri (hata/kuyruk erisilemezligi kaydi DUSURMEZ).
    await ceviri_isaretle_ve_kuyrukla(
        db,
        tip_ad=_TIP,
        entity_id=obj.id,
        tenant_id=user.tenant_id,
        orijinal={"baslik": obj.baslik, "aciklama": obj.aciklama},
        kaynak_dil=obj.kaynak_dil,
    )
    # EK push: tum sakinlerin cihazlarina duyurulur (hatasi kaydi kirmaz).
    dispatch_external(
        f"Yeni etkinlik: {body.baslik} — {body.tarih.strftime('%d.%m.%Y %H:%M')}",
        tenant_id=user.tenant_id,
        target_roles=_AUDIENCE_ROLES,
        title="Etkinlik",
        data={"tip": "etkinlik", "etkinlik_id": str(obj.id)},
    )
    return _out(obj, user.ad, 0, 0, None)


@router.patch("/{event_id}", response_model=EtkinlikOut)
async def update_event(
    event_id: uuid.UUID,
    body: EtkinlikUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> EtkinlikOut:
    obj = (
        await db.execute(select(Etkinlik).where(Etkinlik.id == event_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    alanlar = body.model_dump(exclude_unset=True)
    if "foto_key" in alanlar:
        _validate_foto_key(alanlar["foto_key"], user.tenant_id)
    # Aralik dogrulamasi MEVCUT kayitla birlesik: yalniz `tarih` ya da yalniz
    # `bitis_zamani` gonderildiginde de ters aralik olusamaz (DB'deki
    # ck_etkinlik_bitis ayni kurali son savunma olarak zorlar).
    yeni_tarih = alanlar.get("tarih", obj.tarih)
    yeni_bitis = alanlar.get("bitis_zamani", obj.bitis_zamani)
    if yeni_bitis is not None and yeni_bitis <= yeni_tarih:
        raise APIError(
            422, "invalid_bitis_zamani", "bitis_zamani baslangictan sonra olmali"
        )
    for k, v in alanlar.items():
        setattr(obj, k, v)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    # Kaynak metin degistiyse ceviriler gecersiz; elle duzeltmeler yalniz
    # kaynak AYNI kaldiysa korunur (app/ceviri.py [korunur_mu]).
    await ceviri_isaretle_ve_kuyrukla(
        db,
        tip_ad=_TIP,
        entity_id=obj.id,
        tenant_id=obj.tenant_id,
        orijinal={"baslik": obj.baslik, "aciklama": obj.aciklama},
        kaynak_dil=obj.kaynak_dil,
    )
    return await _load_out(db, user, event_id)


@router.delete("/{event_id}", status_code=204)
async def delete_event(
    event_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> Response:
    obj = (
        await db.execute(select(Etkinlik).where(Etkinlik.id == event_id))
    ).scalar_one_or_none()
    if obj is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    # RSVP'ler FK CASCADE ile silinir.
    await db.delete(obj)
    await db.flush()
    return Response(status_code=204)


# ------------------------------- okuma -------------------------------------- #
@router.get("", response_model=EtkinlikListResponse)
async def list_events(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    aktif: bool | None = Query(
        None,
        description=(
            "true: BITISI gecmemis (yaklasan/suren) etkinlikler — "
            "COALESCE(bitis_zamani, tarih) >= now(), YAKLASAN siralamasi "
            "(en yakin once). false: bitmis etkinlikler (en yeni once). "
            "Verilmezse tumu (en yeni once)."
        ),
    ),
    dil: str | None = Query(
        None,
        description="Accept-Language'i EZER. Dil kodu (tr/en/ar/ru/de/fr/es) "
        "ya da 'orijinal' (kaynak dil).",
    ),
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> EtkinlikListResponse:
    sayim = select(func.count()).select_from(Etkinlik)
    stmt = _base_stmt(user)
    if aktif is not None:
        kosul = (
            _bitis_ifadesi() >= func.now()
            if aktif
            else _bitis_ifadesi() < func.now()
        )
        sayim = sayim.where(kosul)
        stmt = stmt.where(kosul)
    # aktif=true ana ekranin "yaklasan" bolumu: en YAKIN once (ASC).
    # Diger durumlarda geriye uyumlu: en YENI once (DESC).
    stmt = stmt.order_by(
        _bitis_ifadesi().asc() if aktif else Etkinlik.tarih.desc()
    )
    total = (await db.execute(sayim)).scalar_one()
    rows = (await db.execute(stmt.limit(limit).offset(offset))).all()
    yereller = await yerel_harita(
        db,
        tip_ad=_TIP,
        objeler=[r[0] for r in rows],
        accept_language=accept_language,
        istek_dil=dil,
    )
    return EtkinlikListResponse(
        meta={"limit": limit, "offset": offset, "total": total},
        items=[_out(*r, yereller.get(r[0].id)) for r in rows],
    )


@router.get("/{event_id}", response_model=EtkinlikOut)
async def get_event(
    event_id: uuid.UUID,
    dil: str | None = Query(None, description="Accept-Language'i ezer (bkz. liste)."),
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> EtkinlikOut:
    return await _load_out(
        db, user, event_id, accept_language=accept_language, istek_dil=dil
    )


# -------------------------------- RSVP -------------------------------------- #
@router.put("/{event_id}/rsvp", response_model=EtkinlikOut)
async def rsvp_event(
    event_id: uuid.UUID,
    body: EtkinlikRsvp,
    # RSVP yanitini SAKIN alir (mobil) — bu yuzden okuma uclari gibi
    # Accept-Language'a uyar; PATCH/POST yanitlari ise icerigi YAZANA gider
    # ve bilincli olarak ORIJINAL metni dondurur.
    dil: str | None = Query(None, description="Accept-Language'i ezer (bkz. liste)."),
    accept_language: str | None = Header(None, alias="Accept-Language"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RSVP),
) -> EtkinlikOut:
    exists = (
        await db.execute(select(Etkinlik.id).where(Etkinlik.id == event_id))
    ).scalar_one_or_none()
    if exists is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")

    # Beyan KILITLI: kullanici basina etkinlik icin TEK kayit, DEGISTIRILEMEZ.
    # Mevcut beyan varsa 409 — tekrar oy yok (secim kesin, urun karari).
    already = (
        await db.execute(
            select(EtkinlikKatilim.durum).where(
                EtkinlikKatilim.etkinlik_id == event_id,
                EtkinlikKatilim.user_id == user.id,
            )
        )
    ).scalar_one_or_none()
    if already is not None:
        raise APIError(
            409,
            "already_answered",
            "Katilim beyaniniz kaydedildi; degistirilemez.",
        )

    # Ilk beyan: ON CONFLICT DO NOTHING — es zamanli iki ilk-PUT yarissa da
    # cift kayit olusmaz (ilki kazanir; kaybeden beyani sessizce yok sayilir,
    # kilit yine korunur). Sonrasi hep 409 yukaridaki kontrolle doner.
    stmt = pg_insert(EtkinlikKatilim).values(
        tenant_id=user.tenant_id,
        etkinlik_id=event_id,
        user_id=user.id,
        durum=body.durum,
    ).on_conflict_do_nothing(
        constraint="uq_katilim_tenant_etkinlik_user",
    )
    try:
        await db.execute(stmt)
    except IntegrityError as exc:
        raise translate_integrity(exc)
    # Guncel seffaf sayilar + kendi beyaniyla etkinligi don (UI aninda gorur).
    return await _load_out(
        db, user, event_id, accept_language=accept_language, istek_dil=dil
    )
