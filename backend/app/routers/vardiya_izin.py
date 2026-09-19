"""(P241 §2) IZIN — yillik, mazeret, hastalik, ucretsiz, resmi tatil.

===========================================================================
NEDEN AYRI TABLO VE AYRI UC
===========================================================================
Izni `vardiya_plani`ya bir "tur" olarak yazmak kolay gorunurdu ve
mesai hesabini SESSIZCE bozardi: `routers/mesai.py` `durum='planli'`
satirlari okuyor ve izinli gunu CALISMA sayip fazla mesai yazardi.
Ayrintili gerekce goc 0145 basliginda.

===========================================================================
ONAY: KIM OLUSTURDUYSA ONA GORE
===========================================================================
Istek sordu: "Onay gerekir mi? Kim onaylar?"

  * YONETIM (admin/yonetici) ya da amir kendi ekibi icin izin girerse
    kayit DOGRUDAN `onaylandi` acilir — onaylayacak makam ZATEN odur;
    kendi girdigi kaydi ayrica onaylatmak bos bir tiklama olurdu.
  * PERSONEL KENDISI icin girerse `onay_bekliyor` acilir: bu bir
    TALEPTIR. Baskasi adina izin giremez (403).

Onaylayan: admin/yonetici her zaman; guvenlik amiri YALNIZ guvenlik
personeli icin (P231 §2 ile ayni sinir, `gorunur_roller` tek kaynak).

===========================================================================
IZINLI GUNE VARDIYA ATANAMAZ
===========================================================================
Istegin acik maddesi. Kapi `vardiya_plani`nin BUTUN yazma yollarinda
(`ata`, `toplu`, `kalip-uygula`, `haftayi-doldur`) tek bir yardimciyla
zorlanir — tek yolda kontrol etmek, otekilerden sessizce gecilmesi
demekti.

REDDEDILEN ve ONAY BEKLEYEN izin ENGELLEMEZ: yalnizca `onaylandi`.
Bekleyen bir talep henuz bir gercek degildir; onu engel saymak,
yoneticiyi kendi onaylamadigi bir seyle bagli tutardi.
"""
from __future__ import annotations

import datetime as dt
import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, VardiyaIzin
from ..roller import gorunur_roller
from ..schemas import (
    PageMetaOut,
    VardiyaIzinCreate,
    VardiyaIzinListResponse,
    VardiyaIzinOut,
)

router = APIRouter(prefix="/vardiya-izin", tags=["vardiya"])

#: Izin GOREN roller — vardiya planini gorenlerle AYNI kume.
#: Farkli olsaydi izgarada "izinli" yazan bir hucreyi acikladigi kaydi
#: goremeyen bir kullanici olurdu.
_OKUR = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "guvenlik_amiri"
)
#: Izin GIREBILEN roller. Personel YALNIZ KENDISI icin girer (asagida).
_YAZAR = require_role(
    "admin", "yonetici", "guvenlik_amiri", "security", "tesis_gorevlisi"
)
#: ONAYLAYAN roller.
_ONAYLAYAN = require_role("admin", "yonetici", "guvenlik_amiri")

YONETIM = ("admin", "yonetici")


async def izinli_mi(
    db: AsyncSession, user_id: uuid.UUID, tarih: dt.date
) -> bool:
    """O gun ONAYLI ve TUM GUN izin var mi.

    SAATLIK IZIN ENGELLEMEZ: iki saatlik bir mazeret izni, o gunku
    vardiyayi imkansiz kilmaz — kisi izinden sonra ise gelir. Saatlik
    izni de engel saymak, mesru bir plani reddederdi.
    """
    satir = (
        await db.execute(
            select(VardiyaIzin.id).where(
                VardiyaIzin.user_id == user_id,
                VardiyaIzin.durum == "onaylandi",
                VardiyaIzin.tum_gun.is_(True),
                VardiyaIzin.baslangic <= tarih,
                VardiyaIzin.bitis >= tarih,
            ).limit(1)
        )
    ).first()
    return satir is not None


def _cikti(izin: VardiyaIzin, ad: str | None = None) -> VardiyaIzinOut:
    return VardiyaIzinOut(
        id=izin.id, user_id=izin.user_id, kisi_ad=ad, tur=izin.tur,
        baslangic=izin.baslangic, bitis=izin.bitis, tum_gun=izin.tum_gun,
        baslangic_saat=izin.baslangic_saat, bitis_saat=izin.bitis_saat,
        durum=izin.durum, not_metni=izin.not_metni,
        onaylayan_user_id=izin.onaylayan_user_id, onay_at=izin.onay_at,
    )


def _hedef_gorunur(user: AppUser, hedef_rol: str | None) -> None:
    gorunur = gorunur_roller(user.role)
    if gorunur is not None and (hedef_rol is None or hedef_rol not in gorunur):
        raise APIError(403, "forbidden", "vardiya_yalniz_kendi_ekibin")


@router.get("", response_model=VardiyaIzinListResponse)
async def liste(
    baslangic: dt.date | None = Query(None),
    bitis: dt.date | None = Query(None),
    user_id: uuid.UUID | None = Query(None),
    durum: str | None = Query(None, pattern="^(onay_bekliyor|onaylandi|reddedildi)$"),
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> VardiyaIzinListResponse:
    """Izinler — tarih araligi KESISIMI ile suzulur.

    Kesisim (`baslangic <= bitis_sorgu AND bitis >= baslangic_sorgu`)
    sart: "1-20 Agustos" izni, 10-16 Agustos haftasini soran bir
    izgarada GORUNMELI. Yalniz baslangica bakmak onu kacirirdi.
    """
    kosullar = []
    if baslangic is not None:
        kosullar.append(VardiyaIzin.bitis >= baslangic)
    if bitis is not None:
        kosullar.append(VardiyaIzin.baslangic <= bitis)
    if user_id is not None:
        kosullar.append(VardiyaIzin.user_id == user_id)
    if durum is not None:
        kosullar.append(VardiyaIzin.durum == durum)

    # (P231 §2) AMIR YALNIZ KENDI EKIBINI GORUR — vardiya planiyla ayni
    # kural ve ayni kaynak. Kendi iznini her zaman gorur.
    gorunur = gorunur_roller(user.role)
    if gorunur is not None:
        kosullar.append(
            or_(AppUser.role.in_(tuple(gorunur)), VardiyaIzin.user_id == user.id)
        )

    temel = select(VardiyaIzin, AppUser.ad).join(
        AppUser, AppUser.id == VardiyaIzin.user_id
    ).where(*kosullar)
    toplam = int(
        (
            await db.execute(
                select(func.count()).select_from(temel.subquery())
            )
        ).scalar_one()
    )
    satirlar = (
        await db.execute(
            temel.order_by(VardiyaIzin.baslangic.desc(), VardiyaIzin.id)
            .limit(limit)
            .offset(offset)
        )
    ).all()
    return VardiyaIzinListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=toplam),
        items=[_cikti(i, ad) for i, ad in satirlar],
    )


@router.post("", response_model=VardiyaIzinOut, status_code=201)
async def ekle(
    body: VardiyaIzinCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaIzinOut:
    hedef = (
        await db.execute(select(AppUser).where(AppUser.id == body.user_id))
    ).scalar_one_or_none()
    if hedef is None or not hedef.is_active:
        raise APIError(422, "validation_error", "personel_bulunamadi")

    kendisi = body.user_id == user.id
    yonetim = user.role in YONETIM or user.role == "guvenlik_amiri"
    if not yonetim and not kendisi:
        # Personel BASKASI adina izin giremez. Sessizce kendi adina
        # yazmak daha da kotu olurdu: kayit gorunur, ama yanlis kisiye.
        raise APIError(403, "forbidden", "izin_baskasi_adina_giremez")
    if yonetim and not kendisi:
        _hedef_gorunur(user, hedef.role)

    onayli = yonetim
    izin = VardiyaIzin(
        tenant_id=user.tenant_id,
        user_id=body.user_id,
        tur=body.tur,
        baslangic=body.baslangic,
        bitis=body.bitis,
        tum_gun=body.tum_gun,
        baslangic_saat=body.baslangic_saat,
        bitis_saat=body.bitis_saat,
        not_metni=body.not_metni,
        olusturan_user_id=user.id,
        durum="onaylandi" if onayli else "onay_bekliyor",
        onaylayan_user_id=user.id if onayli else None,
        onay_at=func.now() if onayli else None,
    )
    db.add(izin)
    await db.flush()
    await db.refresh(izin)
    await audit_user(
        db, user, Action.VARDIYA_IZIN, resource_type="vardiya_izin",
        resource_id=izin.id,
        meta={
            "islem": "ekle", "user_id": str(body.user_id), "tur": body.tur,
            "baslangic": body.baslangic.isoformat(),
            "bitis": body.bitis.isoformat(), "durum": izin.durum,
        },
    )
    return _cikti(izin, hedef.ad)


async def _karar(
    izin_id: uuid.UUID, db: AsyncSession, user: AppUser, yeni_durum: str
) -> VardiyaIzinOut:
    izin = (
        await db.execute(select(VardiyaIzin).where(VardiyaIzin.id == izin_id))
    ).scalar_one_or_none()
    if izin is None:
        raise APIError(404, "not_found", "izin_bulunamadi")
    hedef = (
        await db.execute(select(AppUser).where(AppUser.id == izin.user_id))
    ).scalar_one_or_none()
    _hedef_gorunur(user, hedef.role if hedef else None)
    if izin.durum != "onay_bekliyor":
        # KARAR VERILMIS bir talebi yeniden karara baglamak, kaydi
        # sessizce degistirmekti. Geri alma AYRI bir eylem olmali.
        raise APIError(409, "conflict", "izin_karar_verilmis")
    izin.durum = yeni_durum
    izin.onaylayan_user_id = user.id
    izin.onay_at = func.now()
    izin.updated_at = func.now()
    await db.flush()
    await db.refresh(izin)
    await audit_user(
        db, user, Action.VARDIYA_IZIN, resource_type="vardiya_izin",
        resource_id=izin.id, meta={"islem": yeni_durum},
    )
    return _cikti(izin, hedef.ad if hedef else None)


@router.post("/{izin_id}/onayla", response_model=VardiyaIzinOut)
async def onayla(
    izin_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ONAYLAYAN),
) -> VardiyaIzinOut:
    return await _karar(izin_id, db, user, "onaylandi")


@router.post("/{izin_id}/reddet", response_model=VardiyaIzinOut)
async def reddet(
    izin_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ONAYLAYAN),
) -> VardiyaIzinOut:
    return await _karar(izin_id, db, user, "reddedildi")


@router.delete("/{izin_id}", status_code=204)
async def sil(
    izin_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> Response:
    """Yonetim her izni siler; personel YALNIZ kendi BEKLEYEN talebini.

    Onaylanmis bir izni personelin kendi silmesi, yoneticinin verdigi
    karari sessizce geri almasi olurdu.
    """
    izin = (
        await db.execute(select(VardiyaIzin).where(VardiyaIzin.id == izin_id))
    ).scalar_one_or_none()
    if izin is None:
        raise APIError(404, "not_found", "izin_bulunamadi")
    yonetim = user.role in YONETIM or user.role == "guvenlik_amiri"
    if not yonetim:
        if izin.user_id != user.id or izin.durum != "onay_bekliyor":
            raise APIError(403, "forbidden", "yetkiniz_yok")
    else:
        hedef = (
            await db.execute(select(AppUser).where(AppUser.id == izin.user_id))
        ).scalar_one_or_none()
        _hedef_gorunur(user, hedef.role if hedef else None)
    await audit_user(
        db, user, Action.VARDIYA_IZIN, resource_type="vardiya_izin",
        resource_id=izin.id, meta={"islem": "sil", "durum": izin.durum},
    )
    await db.delete(izin)
    return Response(status_code=204)
