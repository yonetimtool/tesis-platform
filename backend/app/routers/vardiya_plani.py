"""(P203 §4) VARDIYA PLANLAMA — haftalik plan, atama, anlik durum.

===========================================================================
NEDEN YENI BIR TABLO GEREKTI
===========================================================================
`shift_assignment` TARIH TASIMIYOR: soyledigi tek sey "Ali gece
vardiyasindadir". Haftalik plan, GUN ICI degisiklik ve cakisma
kontrolu — ucu de tarih ister (gerekce goc 0093 basliginda).

`shift_assignment` KALDI ve anlami netlesti: VARSAYILAN KADRO. Hafta,
ondan TOHUMLANIR (`haftayi-doldur`); sonra gun bazinda duzenlenir.

===========================================================================
YETKI
===========================================================================
OKUMA: yonetim + saha. Kendi vardiyasini gormek her gorevlinin hakki ve
"bir sonraki vardiyada kim var" sorusu tam da sahanin sorusudur.
YAZMA: admin + yonetici. Kim ne zaman calisacagina yonetici karar verir.
"""
from __future__ import annotations

import datetime as dt
import uuid
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Shift, ShiftAssignment, Tenant, VardiyaPlani
from ..schemas import (
    VardiyaAtamaIstek,
    VardiyaGunuOut,
    VardiyaHaftaOut,
    VardiyaKisiOut,
    VardiyaPlanOut,
    VardiyaSimdiOut,
    VardiyaSlotOut,
)
from ..vardiya import (
    GUNLUK_AZAMI_SAAT,
    HAFTALIK_NORMAL_SAAT,
    cakisiyor_mu,
    saat_farki,
    vardiya_araligi,
)

router = APIRouter(prefix="/vardiya-plani", tags=["vardiya"])

_OKUR = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "guvenlik_amiri"
)
_YAZAR = require_role("admin", "yonetici")

#: Haftalik gorunum EN FAZLA bu kadar gun cekebilir. Sinirsiz birakmak,
#: tek istekle yillik plani dokturmek olurdu (ve sayfa cizilemezdi).
AZAMI_GUN = 31


def _gun_tipi(gun: dt.date) -> str:
    """Takvim gunu -> `shift.gun_tipi` esdegeri.

    RESMI TATIL BURADA COZULMUYOR: tatil takvimi sistemde YOK ve
    uydurmak, yanlis gunu tatil sayip vardiyayi gizlemek olurdu.
    `resmi_tatil` sablonlari haftalik planda GORUNUR ama otomatik
    tohumlanmaz — yonetici elle ekler. Kayit altinda: tatil takvimi
    eklendiginde burasi guncellenmeli.
    """
    return "hafta_sonu" if gun.weekday() >= 5 else "hafta_ici"


def _sablon_gunde_gecerli(shift: Shift, gun: dt.date) -> bool:
    if shift.gun_tipi == "her_gun":
        return True
    return shift.gun_tipi == _gun_tipi(gun)


async def _cakisma_denetle(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
    tarih: dt.date,
    aralik: tuple[dt.datetime, dt.datetime],
    haric_id: uuid.UUID | None = None,
) -> list[str]:
    """Cakisma KESIN RED, haftalik asim UYARI.

    Komsu gunler de taranir: geceyi asan vardiya ERTESI GUNUN sabahiyla
    cakisir ve yalniz `tarih`e bakmak bunu kacirirdi.
    """
    komsu = [tarih - dt.timedelta(days=1), tarih, tarih + dt.timedelta(days=1)]
    satirlar = (
        await db.execute(
            select(VardiyaPlani, Shift)
            .join(Shift, Shift.id == VardiyaPlani.shift_id)
            .where(
                VardiyaPlani.user_id == user_id,
                VardiyaPlani.durum == "planli",
                VardiyaPlani.tarih.in_(komsu),
            )
        )
    ).all()

    gunluk = saat_farki(*aralik)
    for plan, shift in satirlar:
        if haric_id is not None and plan.id == haric_id:
            continue
        var = vardiya_araligi(plan.tarih, shift.baslangic_saat, shift.bitis_saat)
        if cakisiyor_mu(aralik, var):
            raise APIError(422, "validation_error", "vardiya_cakisiyor")
        if plan.tarih == tarih:
            gunluk += saat_farki(*var)

    uyarilar: list[str] = []
    if gunluk > GUNLUK_AZAMI_SAAT:
        # UYARI, RED DEGIL. Ilk yazimda kesin reddi vardi ve akis
        # calistirilinca goruldu ki 20:00-08:00 gece vardiyasi (12 saat)
        # TEK BASINA reddediliyor — guvenlik sektorunun STANDART
        # kalibi. Model ara dinlenmeyi bilmiyor; dogrulayamadigimiz bir
        # seyi "kanuna aykiri" diye reddetmek mesru bir plani imkansiz
        # kilardi (gerekce `app/vardiya.py` basliginda).
        uyarilar.append("gunluk_sinir_asildi")
    hafta_bas = tarih - dt.timedelta(days=tarih.weekday())
    haftalik = await _haftalik_saat(db, user_id, hafta_bas, haric_id=haric_id)
    if haftalik + saat_farki(*aralik) > HAFTALIK_NORMAL_SAAT:
        # 45 saat ustu FAZLA MESAIDIR: yasal (md. 41) ama MALIYETLI.
        # Engellemek, sistemin desteklemesi gereken mesru bir durumu
        # imkansiz kilardi — §5 bunu hesaplayip gidere yaziyor.
        uyarilar.append("haftalik_normal_asildi")
    return uyarilar


async def _haftalik_saat(
    db: AsyncSession,
    user_id: uuid.UUID,
    hafta_bas: dt.date,
    *,
    haric_id: uuid.UUID | None = None,
) -> float:
    hafta_son = hafta_bas + dt.timedelta(days=6)
    satirlar = (
        await db.execute(
            select(VardiyaPlani, Shift)
            .join(Shift, Shift.id == VardiyaPlani.shift_id)
            .where(
                VardiyaPlani.user_id == user_id,
                VardiyaPlani.durum == "planli",
                VardiyaPlani.tarih >= hafta_bas,
                VardiyaPlani.tarih <= hafta_son,
            )
        )
    ).all()
    toplam = 0.0
    for plan, shift in satirlar:
        if haric_id is not None and plan.id == haric_id:
            continue
        toplam += saat_farki(
            *vardiya_araligi(plan.tarih, shift.baslangic_saat, shift.bitis_saat)
        )
    return toplam


@router.get("", response_model=VardiyaHaftaOut)
async def hafta(
    baslangic: dt.date = Query(...),
    gun: int = Query(7, ge=1, le=AZAMI_GUN),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> VardiyaHaftaOut:
    """Haftalik plan — gun x vardiya izgarasi.

    BOS VARDIYALAR AYRI BIR ALAN DEGIL, `kisiler` listesinin BOS
    olmasidir; ama `bos` bayragi yine de doner: istemcinin "uzunluk 0"
    kontrolunu her cizim yerinde tekrarlamasi, birinde unutulmasi
    demekti (istek: "bos kalan vardiyalar BELIRGIN olsun").
    """
    gunler = [baslangic + dt.timedelta(days=i) for i in range(gun)]
    son = gunler[-1]

    sablonlar = (
        await db.execute(select(Shift).order_by(Shift.baslangic_saat, Shift.ad))
    ).scalars().all()
    satirlar = (
        await db.execute(
            select(VardiyaPlani, AppUser.ad, AppUser.role)
            .join(AppUser, AppUser.id == VardiyaPlani.user_id)
            .where(
                VardiyaPlani.tarih >= baslangic,
                VardiyaPlani.tarih <= son,
                VardiyaPlani.durum == "planli",
            )
            .order_by(AppUser.ad)
        )
    ).all()

    # (tarih, shift_id) -> kisiler
    dolu: dict[tuple[dt.date, uuid.UUID], list[VardiyaKisiOut]] = {}
    for plan, ad, rol in satirlar:
        dolu.setdefault((plan.tarih, plan.shift_id), []).append(
            VardiyaKisiOut(plan_id=plan.id, user_id=plan.user_id, ad=ad, rol=rol)
        )

    return VardiyaHaftaOut(
        baslangic=baslangic,
        bitis=son,
        gunler=[
            VardiyaGunuOut(
                tarih=g,
                slotlar=[
                    VardiyaSlotOut(
                        shift_id=s.id,
                        shift_ad=s.ad,
                        baslangic_saat=s.baslangic_saat,
                        bitis_saat=s.bitis_saat,
                        kisiler=dolu.get((g, s.id), []),
                        bos=not dolu.get((g, s.id)),
                    )
                    for s in sablonlar
                    if _sablon_gunde_gecerli(s, g)
                ],
            )
            for g in gunler
        ],
    )


@router.post("", response_model=VardiyaPlanOut, status_code=201)
async def ata(
    body: VardiyaAtamaIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaPlanOut:
    """Bir kisiyi bir vardiyaya BELIRLI BIR GUN icin ata."""
    shift = (
        await db.execute(select(Shift).where(Shift.id == body.shift_id))
    ).scalar_one_or_none()
    if shift is None:
        raise APIError(422, "validation_error", "vardiya_bulunamadi")
    hedef = (
        await db.execute(select(AppUser).where(AppUser.id == body.user_id))
    ).scalar_one_or_none()
    if hedef is None or not hedef.is_active:
        raise APIError(422, "validation_error", "personel_bulunamadi")

    # AYNI ATAMA KONTROLU CAKISMADAN ONCE: aksi hâlde kisi ayni
    # vardiyaya ikinci kez atanmaya calisildiginda cakisma denetimi
    # KENDI SATIRIYLA cakisiyor sanip "bu kisi ayni saatte baska bir
    # vardiyada" diyordu — YANLIS ve kafa karistirici bir mesaj.
    # Akis calistirilinca goruldu.
    mevcut = (
        await db.execute(
            select(VardiyaPlani).where(
                VardiyaPlani.shift_id == body.shift_id,
                VardiyaPlani.tarih == body.tarih,
                VardiyaPlani.user_id == body.user_id,
            )
        )
    ).scalar_one_or_none()
    if mevcut is not None and mevcut.durum == "planli":
        raise APIError(422, "validation_error", "vardiya_zaten_atanmis")

    aralik = vardiya_araligi(body.tarih, shift.baslangic_saat, shift.bitis_saat)
    uyarilar = await _cakisma_denetle(
        db, user_id=body.user_id, tarih=body.tarih, aralik=aralik,
        haric_id=mevcut.id if mevcut is not None else None,
    )

    # IPTAL EDILMIS ayni satir varsa YENIDEN CANLANDIR: yeni satir
    # acmak, ayni kisi-gun-vardiya ucusu icin gecmiste iki kayit
    # birakirdi ve denetim izi okunmaz olurdu.
    if mevcut is not None:
        mevcut.durum = "planli"
        mevcut.not_metni = body.not_metni
        plan = mevcut
    else:
        plan = VardiyaPlani(
            tenant_id=user.tenant_id,
            shift_id=body.shift_id,
            tarih=body.tarih,
            user_id=body.user_id,
            not_metni=body.not_metni,
        )
        db.add(plan)
    await db.flush()
    await db.refresh(plan)
    # (istek §4.3) DEGISIKLIK DENETIME YAZILIR.
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=plan.id,
        meta={
            "islem": "ata",
            "tarih": body.tarih.isoformat(),
            "shift_id": str(body.shift_id),
            "user_id": str(body.user_id),
            "not": body.not_metni,
        },
    )
    return VardiyaPlanOut(
        id=plan.id,
        shift_id=plan.shift_id,
        tarih=plan.tarih,
        user_id=plan.user_id,
        durum=plan.durum,
        not_metni=plan.not_metni,
        uyarilar=uyarilar,
    )


@router.delete("/{plan_id}", response_model=VardiyaPlanOut)
async def cikar(
    plan_id: uuid.UUID,
    not_metni: str | None = Query(None, max_length=500),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaPlanOut:
    """Atamayi kaldir — SILMEZ, `iptal` isaretler.

    Gun ici degisiklikler denetime yaziliyor; silinen bir satirin
    denetim kaydi "neyin degistigini" gosteremezdi. "Ali cikarildi,
    Veli eklendi" IKI AYRI SATIR olarak durmali.
    """
    plan = (
        await db.execute(select(VardiyaPlani).where(VardiyaPlani.id == plan_id))
    ).scalar_one_or_none()
    if plan is None:
        raise APIError(404, "not_found", "vardiya_plani_bulunamadi")
    plan.durum = "iptal"
    if not_metni:
        plan.not_metni = not_metni
    await db.flush()
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=plan.id,
        meta={
            "islem": "cikar",
            "tarih": plan.tarih.isoformat(),
            "shift_id": str(plan.shift_id),
            "user_id": str(plan.user_id),
            "not": not_metni,
        },
    )
    return VardiyaPlanOut(
        id=plan.id, shift_id=plan.shift_id, tarih=plan.tarih,
        user_id=plan.user_id, durum=plan.durum, not_metni=plan.not_metni,
        uyarilar=[],
    )


@router.post("/haftayi-doldur", response_model=VardiyaHaftaOut)
async def haftayi_doldur(
    baslangic: dt.date = Query(...),
    gun: int = Query(7, ge=1, le=AZAMI_GUN),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaHaftaOut:
    """VARSAYILAN KADRODAN haftayi tohumla.

    `shift_assignment` "kim normalde bu vardiyada calisir" sorusunun
    yanitidir. Onsuz yonetici her hafta yirmi kisilik ekibi tek tek
    atamak zorunda kalirdi.

    CAKISAN/SINIRI ASAN atama SESSIZCE ATLANIR, istek KIRILMAZ: bir
    kisinin kadro cakismasi yuzunden butun haftanin doldurulmamasi,
    aracin kendisini kullanilamaz yapardi. Atlananlar yanitta gorunur
    (bos slot olarak) ve yonetici elle duzeltir.
    """
    gunler = [baslangic + dt.timedelta(days=i) for i in range(gun)]
    kadro = (
        await db.execute(
            select(ShiftAssignment, Shift)
            .join(Shift, Shift.id == ShiftAssignment.shift_id)
        )
    ).all()
    for g in gunler:
        for atama, shift in kadro:
            if not _sablon_gunde_gecerli(shift, g):
                continue
            var = (
                await db.execute(
                    select(VardiyaPlani).where(
                        VardiyaPlani.shift_id == shift.id,
                        VardiyaPlani.tarih == g,
                        VardiyaPlani.user_id == atama.user_id,
                    )
                )
            ).scalar_one_or_none()
            if var is not None:
                # ZATEN PLANLI ya da BILINCLI IPTAL: ikisine de
                # dokunulmaz. Iptali geri getirmek, yoneticinin gun ici
                # kararini sessizce ezmek olurdu.
                continue
            aralik = vardiya_araligi(g, shift.baslangic_saat, shift.bitis_saat)
            try:
                await _cakisma_denetle(
                    db, user_id=atama.user_id, tarih=g, aralik=aralik
                )
            except APIError:
                continue
            db.add(
                VardiyaPlani(
                    tenant_id=user.tenant_id,
                    shift_id=shift.id,
                    tarih=g,
                    user_id=atama.user_id,
                )
            )
            await db.flush()
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=None,
        meta={"islem": "haftayi_doldur", "baslangic": baslangic.isoformat(), "gun": gun},
    )
    return await hafta(baslangic=baslangic, gun=gun, db=db, user=user)


@router.get("/simdi", response_model=VardiyaSimdiOut)
async def simdi(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> VardiyaSimdiOut:
    """(§4.2) SU AN kim gorevde, SIRADAKI vardiyada kim gelecek.

    =======================================================================
    SAAT TENANT'IN SAATIDIR
    =======================================================================
    `shift.baslangic_saat` bir GUN-ICI saattir ve tenant'in saat
    diliminde yorumlanir (model notu). Sunucunun UTC'sine gore
    hesaplamak, Turkiye'deki bir siteye gece 03:00'te "gunduz vardiyasi"
    dedirtirdi. `reservations_timing` ile AYNI kalip.

    =======================================================================
    "GELMEDI" NASIL ANLASILIYOR — ve SINIRI
    =======================================================================
    `basladi_mi` alani, gorevlinin vardiya BASLADIKTAN SONRA bir DEVRIYE
    OKUTMASI yapip yapmadigina bakar (`scan_event`). Bu bir VARIS
    KAYDI DEGILDIR ve oyleymis gibi sunulmuyor: alan adi `okutma_var`
    ve istemci "henuz okutma yok" der, "gelmedi" DEMEZ. Gercek bir
    giris-cikis kaydi (turnike/QR) sistemde YOK; uydurmak, gelmis bir
    gorevliyi "gelmedi" diye isaretlemek olurdu.
    """
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    tz = ZoneInfo(tenant.timezone or "Europe/Istanbul")
    simdi_yerel = dt.datetime.now(tz).replace(tzinfo=None)
    bugun = simdi_yerel.date()

    # DUN de taranir: geceyi asan vardiya SU AN devam ediyor olabilir.
    tarihler = [bugun - dt.timedelta(days=1), bugun, bugun + dt.timedelta(days=1)]
    satirlar = (
        await db.execute(
            select(VardiyaPlani, Shift, AppUser.ad, AppUser.role)
            .join(Shift, Shift.id == VardiyaPlani.shift_id)
            .join(AppUser, AppUser.id == VardiyaPlani.user_id)
            .where(
                VardiyaPlani.tarih.in_(tarihler),
                VardiyaPlani.durum == "planli",
            )
        )
    ).all()

    gorevde: list[VardiyaKisiOut] = []
    sirada: list[VardiyaKisiOut] = []
    sonraki_bas: dt.datetime | None = None
    aktif_slot: VardiyaSlotOut | None = None
    sonraki_slot: VardiyaSlotOut | None = None

    for plan, shift, ad, rol in satirlar:
        bas, son = vardiya_araligi(plan.tarih, shift.baslangic_saat, shift.bitis_saat)
        kisi = VardiyaKisiOut(
            plan_id=plan.id, user_id=plan.user_id, ad=ad, rol=rol
        )
        if bas <= simdi_yerel < son:
            gorevde.append(kisi)
            if aktif_slot is None:
                aktif_slot = VardiyaSlotOut(
                    shift_id=shift.id, shift_ad=shift.ad,
                    baslangic_saat=shift.baslangic_saat,
                    bitis_saat=shift.bitis_saat, kisiler=[], bos=False,
                )
        elif bas > simdi_yerel:
            # EN YAKIN gelecek vardiya: "bir sonraki" tek bir vardiyadir,
            # butun gelecek atamalar degil.
            if sonraki_bas is None or bas < sonraki_bas:
                sonraki_bas = bas
                sirada = [kisi]
                sonraki_slot = VardiyaSlotOut(
                    shift_id=shift.id, shift_ad=shift.ad,
                    baslangic_saat=shift.baslangic_saat,
                    bitis_saat=shift.bitis_saat, kisiler=[], bos=False,
                )
            elif bas == sonraki_bas:
                sirada.append(kisi)

    return VardiyaSimdiOut(
        zaman=simdi_yerel,
        gorevdeki_vardiya=aktif_slot,
        gorevdekiler=gorevde,
        sonraki_vardiya=sonraki_slot,
        sonrakiler=sirada,
        sonraki_baslangic=sonraki_bas,
    )
