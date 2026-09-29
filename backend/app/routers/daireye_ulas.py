"""(P249 §3) GUVENLIKTEN DAIREYE ULASMA — "daireye ulas" ekraninin uclari.

Saha sorunu: ev sahibi evde degil, biri kapiya gelip "beni bekliyor" diyor,
guvenlik dogrulayamiyor. Basamaklar (docs/P249-kararlar.md §3.0):
  1. ziyaretci onay talebi   — `routers/visitors.py` (`onay_iste`),
  2. sesli mesaj             — bu dosya,
  3. uygulama ici arama      — ONERI (kod yok),
  4. telefon yedegi          — bu dosya, yalniz sakin izin verdiyse.

YETKI: guvenlik, amir, yonetim ("daireye ulasma" saha isidir; yonetim de
kapidaki durumu cozebilmeli). Sakin kendi dairesine gelen mesaji dinler
ve siler.

TELEFON NUMARASI HICBIR LISTEDE DONMEZ. Daire ozeti yalniz "bu sakin
telefonla aranabilir mi" (evet/hayir) doner; numara `POST .../telefon` ile
TEK sakin icin, izin aciksa ve DENETIM KAYDIYLA acilir.
"""
from __future__ import annotations

import datetime as dt
import uuid

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, DaireSesliMesaj, Unit, UnitResident
from ..sakin_bildirimi import sakin_bildirimi_yaz
from ..scheduler.notify import dispatch_external

router = APIRouter(tags=["daireye-ulas"])

_ULASAN = require_role("security", "guvenlik_amiri", "yonetici", "admin")
#: Sesli mesaji okuyan/silen: sakin (dairesine gelen) ya da gonderen. Denetci
#: (salt-okuma mali gozetim) bu yuzeye HIC girmez; asil erisim kontrolu
#: handler'da (`_mesaj_ve_erisim`).
_KATILIMCI = require_role("resident", "security", "guvenlik_amiri", "yonetici", "admin")

#: (P249 §3b) SESLI MESAJ SINIRLARI — mobil kaydedici ayni sayilari kullanir.
SES_AZAMI_MS = 60_000
#: 60 sn AAC 32 kbps ~ 240 KB; 1 MB bol pay birakir, sesi degil gurultuyu keser.
SES_AZAMI_BAYT = 1_048_576
SES_TURLERI = frozenset({"audio/mp4", "audio/aac", "audio/m4a", "audio/x-m4a"})
#: KVKK saklama suresi — gece imha gorevi bundan eskiyi siler.
SES_SAKLAMA_GUN = 7


def _simdi() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


async def _aktif_sakinler(db: AsyncSession, unit_id: uuid.UUID) -> list[AppUser]:
    return list(
        (
            await db.execute(
                select(AppUser)
                .join(UnitResident, UnitResident.user_id == AppUser.id)
                .where(
                    UnitResident.unit_id == unit_id,
                    UnitResident.bitis.is_(None),
                    AppUser.is_active.is_(True),
                )
                .order_by(AppUser.ad)
            )
        ).scalars().unique().all()
    )


def _daire_adi(unit: Unit) -> str:
    no, blok = unit.no or "", unit.blok or ""
    return no if (not blok or no.startswith(blok)) else f"{blok} {no}"


# ------------------------------- semalar ----------------------------------- #
class UlasSakin(BaseModel):
    user_id: uuid.UUID
    ad: str
    #: Sakin "Yonetim beni bu numaradan arayabilir" dediyse True. NUMARA YOK.
    telefonla_aranabilir: bool


class DaireUlasOut(BaseModel):
    unit_id: uuid.UUID
    daire: str
    sakinler: list[UlasSakin]


class TelefonIstek(BaseModel):
    user_id: uuid.UUID


class TelefonOut(BaseModel):
    telefon: str


class SesYuklemeIstek(BaseModel):
    icerik_turu: str = Field("audio/mp4", max_length=40)
    boyut: int = Field(..., gt=0, le=SES_AZAMI_BAYT)


class SesYuklemeOut(BaseModel):
    anahtar: str
    url: str
    gecerlilik_sn: int


class SesGonder(BaseModel):
    anahtar: str = Field(..., max_length=300)
    sure_ms: int = Field(..., gt=0, le=SES_AZAMI_MS)
    boyut: int = Field(..., gt=0, le=SES_AZAMI_BAYT)
    icerik_turu: str = Field("audio/mp4", max_length=40)


class SesliMesajOut(BaseModel):
    id: uuid.UUID
    unit_id: uuid.UUID
    daire: str = ""
    gonderen_ad: str | None = None
    sure_ms: int
    dinlendi_at: dt.datetime | None = None
    silindi_at: dt.datetime | None = None
    created_at: dt.datetime


class DinleOut(BaseModel):
    url: str
    gecerlilik_sn: int


# --------------------------- daire ozeti + telefon --------------------------- #
@router.get("/units/{unit_id}/ulas", response_model=DaireUlasOut)
async def daire_ulas(
    unit_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ULASAN),
) -> DaireUlasOut:
    unit = await get_or_404(db, Unit, unit_id)
    sakinler = await _aktif_sakinler(db, unit.id)
    return DaireUlasOut(
        unit_id=unit.id,
        daire=_daire_adi(unit),
        sakinler=[
            UlasSakin(
                user_id=s.id,
                ad=s.ad or "",
                telefonla_aranabilir=bool(s.yonetim_arayabilir and (s.telefon or "").strip()),
            )
            for s in sakinler
        ],
    )


@router.post("/units/{unit_id}/ulas/telefon", response_model=TelefonOut)
async def daire_telefon(
    unit_id: uuid.UUID,
    body: TelefonIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ULASAN),
) -> TelefonOut:
    """(P249 §3e) TEK sakinin numarasi — YALNIZ izin aciksa, DENETIM KAYDIYLA.

    Izin kapaliysa 403 ve numara HIC donmez. E2E turunda amirin sakin
    telefonlarini listede gormesi kapatildi; bu uc o kuralin ONAYLI ve
    KAYITLI istisnasidir — liste degil, tek kisi; sessiz degil, kayitli.
    """
    unit = await get_or_404(db, Unit, unit_id)
    sakin = next((s for s in await _aktif_sakinler(db, unit.id) if s.id == body.user_id), None)
    if sakin is None:
        raise APIError(404, "not_found", "daire_sakini_bulunamadi")
    telefon = (sakin.telefon or "").strip()
    if not sakin.yonetim_arayabilir or not telefon:
        raise APIError(403, "forbidden", "telefon_izni_yok")
    await audit_user(
        db, user, Action.DAIRE_TELEFON_GOSTER, resource_type="unit",
        resource_id=unit.id, meta={"sakin_user_id": str(sakin.id)},
    )
    return TelefonOut(telefon=telefon)


# ------------------------------- sesli mesaj -------------------------------- #
def _ses_anahtari(tenant_id: uuid.UUID, unit_id: uuid.UUID) -> str:
    return f"{tenant_id}/sesli-mesaj/{unit_id}/{uuid.uuid4().hex}.m4a"


@router.post("/units/{unit_id}/sesli-mesaj/yukleme", response_model=SesYuklemeOut)
async def ses_yukleme_adresi(
    unit_id: uuid.UUID,
    body: SesYuklemeIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ULASAN),
) -> SesYuklemeOut:
    """Imzali yukleme adresi — dosya API'den GECMEZ (depo kurali)."""
    from ..storage import presign_put_anahtar

    if body.icerik_turu not in SES_TURLERI:
        raise APIError(422, "validation_error", "ses_turu_gecersiz")
    unit = await get_or_404(db, Unit, unit_id)
    anahtar, url, sn = presign_put_anahtar(
        _ses_anahtari(user.tenant_id, unit.id), body.icerik_turu
    )
    return SesYuklemeOut(anahtar=anahtar, url=url, gecerlilik_sn=sn)


@router.post("/units/{unit_id}/sesli-mesaj", response_model=SesliMesajOut, status_code=201)
async def ses_gonder(
    unit_id: uuid.UUID,
    body: SesGonder,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ULASAN),
) -> SesliMesajOut:
    """Yuklenen sesi daireye GONDER — dairenin aktif sakinlerine bildirim."""
    unit = await get_or_404(db, Unit, unit_id)
    # ANAHTAR BU TESISIN BU DAIRESINE AIT OLMALI: baska bir dairenin
    # (ya da tesisin) dosyasini "gonderilmis" gibi baglamak engellenir.
    if not body.anahtar.startswith(f"{user.tenant_id}/sesli-mesaj/{unit.id}/"):
        raise APIError(422, "validation_error", "ses_anahtari_gecersiz")
    if body.icerik_turu not in SES_TURLERI:
        raise APIError(422, "validation_error", "ses_turu_gecersiz")
    # DOSYA GERCEKTEN YUKLENMIS OLMALI ve 1 MB'i asmamali: imzali adres
    # PUT boyutunu denetlemez; beyan edilen boyuta guvenmek, 1 MB siniri
    # bir istemci sozune indirmek olurdu.
    from ..storage import obje_boyutu

    gercek = obje_boyutu(body.anahtar)
    if gercek is None or gercek > SES_AZAMI_BAYT:
        raise APIError(422, "validation_error", "ses_dosyasi_yok")
    sakinler = await _aktif_sakinler(db, unit.id)
    if not sakinler:
        raise APIError(409, "conflict", "dairede_sakin_yok")
    m = DaireSesliMesaj(
        tenant_id=user.tenant_id,
        unit_id=unit.id,
        gonderen_user_id=user.id,
        depo_anahtari=body.anahtar,
        sure_ms=body.sure_ms,
        boyut=gercek,
        icerik_turu=body.icerik_turu,
    )
    db.add(m)
    await db.flush()
    veri = {"daire": _daire_adi(unit)}
    sakin_bildirimi_yaz(
        db, tenant_id=user.tenant_id, tip="sesli_mesaj",
        user_ids=tuple(s.id for s in sakinler), veri=veri,
    )
    dispatch_external(
        "sesli_mesaj",
        tenant_id=user.tenant_id,
        target_user_ids=[s.id for s in sakinler],
        params=veri,
        data={"tip": "sesli_mesaj", "sesli_mesaj_id": str(m.id)},
    )
    await audit_user(
        db, user, Action.SESLI_MESAJ_GONDER, resource_type="unit",
        resource_id=unit.id, meta={"mesaj_id": str(m.id), "sure_ms": body.sure_ms},
    )
    return SesliMesajOut(
        id=m.id, unit_id=unit.id, daire=veri["daire"], gonderen_ad=user.ad,
        sure_ms=m.sure_ms, created_at=m.created_at or _simdi(),
    )


async def _mesaj_ve_erisim(
    db: AsyncSession, mesaj_id: uuid.UUID, user: AppUser
) -> tuple[DaireSesliMesaj, bool]:
    """(mesaj, sakin_mi). Erisim: dairenin aktif sakini ya da gonderen.

    Baska rollerin (yonetim dahil) dinlemesi YOK: ses kisisel veridir ve
    mesajin muhatabi dairedir. Gonderen kendi mesajini geri alabilir.
    """
    m = await get_or_404(db, DaireSesliMesaj, mesaj_id)
    if m.silindi_at is not None:
        raise APIError(404, "not_found", "sesli_mesaj_bulunamadi")
    sakin = user.id in {s.id for s in await _aktif_sakinler(db, m.unit_id)}
    if not sakin and m.gonderen_user_id != user.id:
        raise APIError(404, "not_found", "sesli_mesaj_bulunamadi")
    return m, sakin


@router.get("/sesli-mesaj", response_model=list[SesliMesajOut])
async def sesli_mesajlarim(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_KATILIMCI),
) -> list[SesliMesajOut]:
    """Sakin: dairesine gelenler. Guvenlik/yonetim: GONDERDIKLERI (dinlendi mi)."""
    daireler = list(
        (
            await db.execute(
                select(UnitResident.unit_id).where(
                    UnitResident.user_id == user.id, UnitResident.bitis.is_(None)
                )
            )
        ).scalars().all()
    )
    kosul = DaireSesliMesaj.gonderen_user_id == user.id
    if daireler:
        kosul = kosul | DaireSesliMesaj.unit_id.in_(daireler)
    satirlar = (
        await db.execute(
            select(DaireSesliMesaj, Unit, AppUser.ad)
            .join(Unit, Unit.id == DaireSesliMesaj.unit_id)
            .outerjoin(AppUser, AppUser.id == DaireSesliMesaj.gonderen_user_id)
            .where(kosul, DaireSesliMesaj.silindi_at.is_(None))
            .order_by(DaireSesliMesaj.created_at.desc(), DaireSesliMesaj.id)
            .limit(50)
        )
    ).all()
    return [
        SesliMesajOut(
            id=m.id, unit_id=m.unit_id, daire=_daire_adi(u), gonderen_ad=ad,
            sure_ms=m.sure_ms, dinlendi_at=m.dinlendi_at, created_at=m.created_at,
        )
        for m, u, ad in satirlar
    ]


@router.get("/sesli-mesaj/{mesaj_id}/dinle", response_model=DinleOut)
async def sesli_mesaj_dinle(
    mesaj_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_KATILIMCI),
) -> DinleOut:
    """Kisa omurlu imzali adres. Ilk SAKIN dinlemesi kaydedilir."""
    from ..config import settings
    from ..storage import presign_get

    m, sakin = await _mesaj_ve_erisim(db, mesaj_id, user)
    if sakin and m.dinlendi_at is None:
        m.dinlendi_at = _simdi()
        m.dinleyen_user_id = user.id
        await db.flush()
        await audit_user(
            db, user, Action.SESLI_MESAJ_DINLE, resource_type="unit",
            resource_id=m.unit_id, meta={"mesaj_id": str(m.id)},
        )
    return DinleOut(url=presign_get(m.depo_anahtari or ""),
                    gecerlilik_sn=settings.minio_url_expire_seconds)


@router.delete("/sesli-mesaj/{mesaj_id}", status_code=204)
async def sesli_mesaj_sil(
    mesaj_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_KATILIMCI),
) -> Response:
    """Sakin ya da gonderen siler: DOSYA silinir, satir "silindi" isaretlenir
    (denetim izi kalir, icerik kalmaz)."""
    from ..storage import delete_objects

    m, _ = await _mesaj_ve_erisim(db, mesaj_id, user)
    if m.depo_anahtari:
        try:
            delete_objects([m.depo_anahtari])
            m.depo_anahtari = None
        except Exception:  # noqa: BLE001
            # Depo o an erisilemezse ANAHTAR KALIR: gece imha gorevi
            # "silindi ama dosyasi duran" satirlari tekrar dener.
            pass
    m.silindi_at = _simdi()
    await db.flush()
    await audit_user(
        db, user, Action.SESLI_MESAJ_SIL, resource_type="unit",
        resource_id=m.unit_id, meta={"mesaj_id": str(m.id)},
    )
    return Response(status_code=204)
