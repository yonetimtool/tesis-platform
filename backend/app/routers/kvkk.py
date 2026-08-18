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

from fastapi import APIRouter, Depends, Query
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


#: (P168 §5) Brief'in bes metni — SIRA brief'in sirasi.
KVKK_TURLER: tuple[str, ...] = (
    "aydinlatma", "acik_riza", "gizlilik", "kullanim_kosullari", "cerez",
)
VARSAYILAN_TUR = "aydinlatma"


def _cikti(metin: KvkkMetin, *, yururlukte: bool) -> KvkkMetinOut:
    """`KvkkMetinOut` + TURETILEN `yururlukte` bayragi."""
    return KvkkMetinOut.model_validate(metin).model_copy(
        update={"yururlukte": yururlukte}
    )


async def _guncel(db: AsyncSession, tur: str = VARSAYILAN_TUR) -> KvkkMetin | None:
    """Bir TURUN yururlukteki metni.

    (P168 §5) YURURLUKTE OLAN = O TURUN EN YUKSEK SURUMU. Ayri bir
    `yururlukte` kolonu ACILMADI: iki satirin ayni anda yururlukte olmasi
    ya da hicbirinin olmamasi mumkun hale gelirdi ve bu, "hangi metni
    onayliyorum" sorusunu cevapsiz birakirdi. Turetilen bir deger
    tutarsiz olamaz.
    """
    return (
        await db.execute(
            # (P108) KUYRUK GEREKMEZ: `(tenant_id, tur, surum)`
            # BENZERSIZDIR (`uq_kvkk_metin_surum`), yani ayni tur icinde
            # iki satir ayni `surum`u tasiyamaz ve siralama kararlidir.
            select(KvkkMetin)
            .where(KvkkMetin.tur == tur)
            .order_by(KvkkMetin.surum.desc())
            .limit(1)
        )
    ).scalar_one_or_none()


# ============================== METIN ======================================= #
@router.get("/kvkk/metin", response_model=KvkkMetinOut)
async def guncel_metin(
    tur: str = Query(VARSAYILAN_TUR),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(get_current_user),
) -> KvkkMetinOut:
    """Tenant'in GUNCEL aydinlatma metni — BILINEN TUM ROLLERE acik.

    Rol suzgeci YOK: metin kullanicinin KENDI verisi hakkindadir; okuyamamak
    aydinlatmanin kendisini imkansiz kilardi.
    """
    if tur not in KVKK_TURLER:
        raise APIError(422, "validation_error", "kvkk_turu_gecersiz")
    metin = await _guncel(db, tur)
    if metin is None:
        raise APIError(404, "not_found", "kvkk_metni_yayinlanmamis")
    return _cikti(metin, yururlukte=True)


@router.get("/kvkk/metinler", response_model=list[KvkkMetinOut])
async def surum_gecmisi(
    tur: str | None = Query(None),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_YAYINCI),
) -> list[KvkkMetinOut]:
    """Tum surumler (yonetim). Eski surumler SILINMEZ: onay kayitlari
    onlara referans verir ve "hangi metne onay verildi" sorusu
    yanitlanabilir kalmalidir."""
    q = select(KvkkMetin).order_by(KvkkMetin.tur, KvkkMetin.surum.desc())
    if tur is not None:
        if tur not in KVKK_TURLER:
            raise APIError(422, "validation_error", "kvkk_turu_gecersiz")
        q = q.where(KvkkMetin.tur == tur)
    kayitlar = (await db.execute(q)).scalars().all()
    # YURURLUKTE olan TUR BASINA en yuksek surumdur ve TURETILIR.
    en_yuksek: dict[str, int] = {}
    for k in kayitlar:
        en_yuksek[k.tur] = max(en_yuksek.get(k.tur, 0), k.surum)
    return [_cikti(k, yururlukte=k.surum == en_yuksek[k.tur]) for k in kayitlar]


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
    # (P168 §5) SURUM TUR BASINA ilerler: gizlilik politikasi yayinlamak
    # aydinlatma metninin surum numarasini ATLATMAMALI.
    mevcut = await _guncel(db, body.tur)
    if mevcut is not None and mevcut.govde.strip() == body.govde.strip():
        raise APIError(409, "conflict", "kvkk_metni_degismedi")

    sonraki = ((mevcut.surum if mevcut else 0) or 0) + 1
    obj = KvkkMetin(
        tenant_id=user.tenant_id,
        tur=body.tur,
        surum=sonraki,
        baslik=body.baslik,
        govde=body.govde,
        yeniden_onay_gerekir=body.yeniden_onay_gerekir,
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
        resource_id=obj.id,
        meta={"tur": obj.tur, "surum": obj.surum,
              "yeniden_onay": obj.yeniden_onay_gerekir},
    )
    return _cikti(obj, yururlukte=True)


# ============================== DURUM + ONAY ================================ #
@router.get("/kvkk/durum", response_model=KvkkDurumOut)
async def durum(
    tur: str = Query(VARSAYILAN_TUR),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> KvkkDurumOut:
    """Istemcinin onay kapisini kurmasi icin gereken TEK cagri."""
    if tur not in KVKK_TURLER:
        raise APIError(422, "validation_error", "kvkk_turu_gecersiz")
    metin = await _guncel(db, tur)
    if metin is None:
        # Tenant metin yayinlamadiysa kapi KURULMAZ. Metinsiz bir kapi,
        # kullaniciya okumadan onaylatmak olurdu.
        return KvkkDurumOut(metin_var=False, onay_gerekli=False)

    # KULLANICININ BU TURDEKI EN SON ONAYI (guncel surum olmak zorunda
    # degil): "yeniden onay gerekmez" bayragi tam olarak bu farki
    # kullanir.
    onay = (
        await db.execute(
            select(KvkkOnay)
            .where(KvkkOnay.user_id == user.id, KvkkOnay.tur == tur)
            # KIRICI OLARAK `id`: `uq_kvkk_onay` (tenant, user, tur, surum)
            # zaten iki satirin ayni surumu tasimasini engelliyor, yani
            # siralama kisit sayesinde kararli. Yine de `id` ekleniyor —
            # kararliligin bir KISITA bagli olmasi, o kisit bir gun
            # degistiginde SESSIZCE bozulmasi demekti ve
            # `test_sayfalama_siralamasi` bu sinifi tam da bu yuzden
            # tariyor. Bedeli yok.
            .order_by(KvkkOnay.surum.desc(), KvkkOnay.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    # (P168 §5) YENIDEN ONAY KURALI.
    #
    # Guncel surumu onaylamis -> gerek yok.
    # Hic onaylamamis -> GEREKLI (metni hic gormedi).
    # Eski bir surumu onaylamis -> GUNCEL SURUMUN BAYRAGI karar verir:
    #   bir yazim hatasi duzeltmesi 200 sakini yeniden onay ekranina
    #   sokmamali; esasa iliskin bir degisiklik SOKMALI.
    if onay is None:
        gerekli = True
    elif onay.surum >= metin.surum:
        gerekli = False
    else:
        gerekli = metin.yeniden_onay_gerekir

    return KvkkDurumOut(
        metin_var=True,
        guncel_surum=metin.surum,
        onayladigi_surum=onay.surum if onay else None,
        onay_at=onay.onay_at if onay else None,
        onay_gerekli=gerekli,
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
    tur = body.tur
    if tur not in KVKK_TURLER:
        raise APIError(422, "validation_error", "kvkk_turu_gecersiz")
    metin = await _guncel(db, tur)
    if metin is None:
        raise APIError(404, "not_found", "kvkk_metni_yayinlanmamis")
    if body.surum != metin.surum:
        raise APIError(409, "conflict", "kvkk_surumu_degisti")

    var = (
        await db.execute(
            select(KvkkOnay.id).where(
                KvkkOnay.user_id == user.id,
                KvkkOnay.tur == tur,
                KvkkOnay.surum == metin.surum,
            )
        )
    ).scalar_one_or_none()
    if var is None:
        db.add(KvkkOnay(
            tenant_id=user.tenant_id, user_id=user.id,
            kvkk_metin_id=metin.id, tur=tur, surum=metin.surum,
        ))
        await db.flush()
        await audit_user(
            db, user, Action.KVKK_ONAY, resource_type="kvkk_metin",
            resource_id=metin.id, meta={"tur": tur, "surum": metin.surum},
        )
    return await durum(tur=tur, db=db, user=user)


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
