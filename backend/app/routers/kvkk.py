"""KVKK aydinlatma + onay + pazarlama izinleri (P36).

SUNUCU NAVIGASYONU KILITLEMEZ, KAPIYI ISTEMCI KURAR — ama kararin girdisi
buradan gelir (`GET /kvkk/durum` -> `onay_gerekli`). Gerekce: onay vermemis
bir kullanici METNI OKUYABILMELI, cikis yapabilmeli ve dilini
degistirebilmelidir; sunucunun her ucu 403'lemesi, metni gostermeyi de
imkansiz kilar ve kullaniciyi kapali bir kapiya kilitlerdi.

RIZANIN GERCEK ZORLAMASI GONDERIM UCUNDADIR (P32): `amac='pazarlama'`
mesajlar yalniz o kanala izin vermis kisilere gider. Kapinin asilmasi
mesaji gondermez — kapi UX'tir, riza denetimi KODDADIR.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import translate_integrity
from ..deps import get_current_user, get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, KvkkMetin, KvkkOnay
from ..schemas import (
    KvkkDurumOut,
    KvkkMetinCreate,
    KvkkMetinOut,
    KvkkOnayIstek,
    PazarlamaTercihleri,
    PazarlamaTercihUpdate,
)

router = APIRouter(tags=["kvkk"])

_YAYINCI = require_role("admin", "yonetici")


async def _guncel(db: AsyncSession) -> KvkkMetin | None:
    return (
        await db.execute(
            # (P108) KUYRUK GEREKMEZ: `(tenant_id, surum)` BENZERSIZDIR
            # (`uq_kvkk_metin_surum`), yani tenant icinde iki satir ayni
            # `surum`u tasiyamaz ve siralama zaten kararlidir. Buraya `id`
            # eklemek, var olmayan bir esitligi cozmek olurdu.
            select(KvkkMetin).order_by(KvkkMetin.surum.desc()).limit(1)
        )
    ).scalar_one_or_none()


# ============================== METIN ======================================= #
@router.get("/kvkk/metin", response_model=KvkkMetinOut)
async def guncel_metin(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(get_current_user),
) -> KvkkMetinOut:
    """Tenant'in GUNCEL aydinlatma metni — BILINEN TUM ROLLERE acik.

    Rol suzgeci YOK: metin kullanicinin KENDI verisi hakkindadir; okuyamamak
    aydinlatmanin kendisini imkansiz kilardi.
    """
    metin = await _guncel(db)
    if metin is None:
        raise APIError(404, "not_found", "kvkk_metni_yayinlanmamis")
    return KvkkMetinOut.model_validate(metin)


@router.get("/kvkk/metinler", response_model=list[KvkkMetinOut])
async def surum_gecmisi(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YAYINCI),
) -> list[KvkkMetinOut]:
    """Tum surumler (yonetim). Eski surumler SILINMEZ: onay kayitlari
    onlara referans verir ve "hangi metne onay verildi" sorusu
    yanitlanabilir kalmalidir."""
    kayitlar = (
        await db.execute(select(KvkkMetin).order_by(KvkkMetin.surum.desc()))
    ).scalars().all()
    return [KvkkMetinOut.model_validate(k) for k in kayitlar]


@router.post("/kvkk/metin", response_model=KvkkMetinOut, status_code=201)
async def metin_yayinla(
    body: KvkkMetinCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAYINCI),
) -> KvkkMetinOut:
    """YENI SURUM yayinla — mevcut surumu DUZENLEME UCU YOKTUR.

    Yerinde duzenlemeye izin verilseydi, dun onay vermis bir kullanicinin
    onayi bugun BASKA BIR METNE ait gorunurdu. Surum artmasi TUM
    kullanicilarda yeniden onay ister; bu METNIN DEGISTIGINI kullaniciya
    soylemenin tek durust yoludur.

    AYNI GOVDE YENIDEN YAYINLANMAZ (409): degismemis bir metin icin herkesi
    yeniden onaya zorlamak, onayi anlamsiz bir tikla dondururdu.
    """
    mevcut = await _guncel(db)
    if mevcut is not None and mevcut.govde.strip() == body.govde.strip():
        raise APIError(409, "conflict", "kvkk_metni_degismedi")

    sonraki = ((mevcut.surum if mevcut else 0) or 0) + 1
    obj = KvkkMetin(
        tenant_id=user.tenant_id,
        surum=sonraki,
        baslik=body.baslik,
        govde=body.govde,
        yayinlayan_user_id=user.id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    await audit_user(
        db, user, Action.KVKK_YAYIN, resource_type="kvkk_metin",
        resource_id=obj.id, meta={"surum": obj.surum},
    )
    return KvkkMetinOut.model_validate(obj)


# ============================== DURUM + ONAY ================================ #
@router.get("/kvkk/durum", response_model=KvkkDurumOut)
async def durum(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> KvkkDurumOut:
    """Istemcinin onay kapisini kurmasi icin gereken TEK cagri."""
    metin = await _guncel(db)
    if metin is None:
        # Tenant metin yayinlamadiysa kapi KURULMAZ. Metinsiz bir kapi,
        # kullaniciya okumadan onaylatmak olurdu.
        return KvkkDurumOut(metin_var=False, onay_gerekli=False)

    onay = (
        await db.execute(
            select(KvkkOnay).where(
                KvkkOnay.user_id == user.id, KvkkOnay.surum == metin.surum
            )
        )
    ).scalar_one_or_none()
    return KvkkDurumOut(
        metin_var=True,
        guncel_surum=metin.surum,
        onayladigi_surum=onay.surum if onay else None,
        onay_at=onay.onay_at if onay else None,
        onay_gerekli=onay is None,
    )


@router.post("/kvkk/onay", response_model=KvkkDurumOut, status_code=201)
async def onayla(
    body: KvkkOnayIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> KvkkDurumOut:
    """Ekranda GORULEN surumu onayla.

    Surum govdede tasinir ve guncel surumle KARSILASTIRILIR: kullanici metni
    okurken yonetim yeni surum yayinladiysa, onayi ESKI METNE aitti — sessizce
    yeni surume yazmak, okumadigi bir metni onaylatmak olurdu (409).

    IDEMPOTENT: ayni surum icin ikinci cagri yeni satir uretmez (cift
    dokunus/ag tekrari onayi cogaltmasin).
    """
    metin = await _guncel(db)
    if metin is None:
        raise APIError(404, "not_found", "kvkk_metni_yayinlanmamis")
    if body.surum != metin.surum:
        raise APIError(409, "conflict", "kvkk_surumu_degisti")

    var = (
        await db.execute(
            select(KvkkOnay.id).where(
                KvkkOnay.user_id == user.id, KvkkOnay.surum == metin.surum
            )
        )
    ).scalar_one_or_none()
    if var is None:
        db.add(KvkkOnay(
            tenant_id=user.tenant_id, user_id=user.id,
            kvkk_metin_id=metin.id, surum=metin.surum,
        ))
        await db.flush()
        await audit_user(
            db, user, Action.KVKK_ONAY, resource_type="kvkk_metin",
            resource_id=metin.id, meta={"surum": metin.surum},
        )
    return await durum(db=db, user=user)


# ============================ PAZARLAMA IZINLERI ============================ #
@router.get("/me/pazarlama-tercihleri", response_model=PazarlamaTercihleri)
async def tercihler(
    user: AppUser = Depends(get_current_user),
) -> PazarlamaTercihleri:
    return PazarlamaTercihleri(
        eposta=user.pazarlama_eposta,
        sms=user.pazarlama_sms,
        arama=user.pazarlama_arama,
        guncelleme_at=user.pazarlama_guncelleme_at,
    )


@router.patch("/me/pazarlama-tercihleri", response_model=PazarlamaTercihleri)
async def tercih_guncelle(
    body: PazarlamaTercihUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> PazarlamaTercihleri:
    """Kanallar BAGIMSIZ guncellenir; gonderilmeyen kanal DEGISMEZ.

    Tercih HER ZAMAN KENDISI icindir — baskasinin rizasini kimse veremez
    (bu yuzden `/users/{id}` altinda bir ikizi YOKTUR).
    """
    veri = body.model_dump(exclude_unset=True)
    for alan, deger in veri.items():
        setattr(user, f"pazarlama_{alan}", deger)
    user.pazarlama_guncelleme_at = func.now()
    await db.flush()
    await db.refresh(user)
    # KVKK: ispat yukumlulugu veri sorumlusundadir — riza degisimi
    # append-only denetim kaydina yazilir.
    await audit_user(
        db, user, Action.PAZARLAMA_RIZA, resource_type="app_user",
        resource_id=user.id,
        meta={k: str(v) for k, v in veri.items()},
    )
    return PazarlamaTercihleri(
        eposta=user.pazarlama_eposta,
        sms=user.pazarlama_sms,
        arama=user.pazarlama_arama,
        guncelleme_at=user.pazarlama_guncelleme_at,
    )
