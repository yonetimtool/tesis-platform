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

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..hiz_siniri import DISA_AKTARIM_SINIRI
from ..audit import Action, audit_user
from ..deps import get_tenant_db, require_role
from ..roller import gorunur_roller
from ..sakin_bildirimi import sakin_bildirimi_yaz
from ..scheduler.notify import dispatch_external
from ..push_metinleri import push_govdesi
from ..errors import APIError
from ..hata_metinleri import hata_metni
from ..models import (
    AppUser,
    Notification,
    BuildingBlock,
    Shift,
    ShiftAssignment,
    Tenant,
    VardiyaDonguAtama,
    VardiyaIzin,
    VardiyaKalibi,
    VardiyaPlani,
)
from ..schemas import (
    VardiyaAtamaIstek,
    VardiyaHaftaKopyalaIstek,
    VardiyaHaftaKopyalaSonuc,
    VardiyaIzinBlokOut,
    VardiyaKopyaGunOut,
    VardiyaMolaOneriOut,
    VardiyaIceAktarimIstek,
    VardiyaIceAktarimSatirSonuc,
    VardiyaIceAktarimSonuc,
    VardiyaYayinOzet,
    VardiyaYayinSonuc,
    VardiyaDilim,
    VardiyaDonguAtamaListResponse,
    VardiyaDonguAtamaOut,
    VardiyaDonguSonlandirIstek,
    VardiyaDonguSonlandirSonuc,
    VardiyaDonguSonuc,
    VardiyaDonguUygulaIstek,
    VardiyaKapsamaAralik,
    VardiyaKapsamaGun,
    VardiyaKalibiCreate,
    VardiyaKalibiListResponse,
    VardiyaKalibiOut,
    VardiyaKalipGunDilim,
    VardiyaKalipSonuc,
    VardiyaKalipUygulaIstek,
    VardiyaPartiGeriAlSonuc,
    VardiyaBlokOut,
    VardiyaCizelgeKisiOut,
    VardiyaCizelgeOut,
    VardiyaGuncelleIstek,
    VardiyaTopluGunOut,
    VardiyaTopluIstek,
    VardiyaTopluOut,
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
    dongu_adimi,
    gece_asiyor_mu,
    kapsama_bosluklari,
    mola_dakika,
    plan_araligi,
    plan_saat,
    saat_farki,
    vardiya_araligi,
    yasal_mola_dakika,
)
from .vardiya_izin import izinli_mi

router = APIRouter(prefix="/vardiya-plani", tags=["vardiya"])

_OKUR = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "guvenlik_amiri"
)
# (P231 §2) AMIR GUVENLIK VARDIYALARINI DUZENLER.
#
# =========================================================================
# `/shifts` ILE `/vardiya-plani` AYRI SEYLER — ve kapilari da ayri
# =========================================================================
# `/shifts` VARDIYA SABLONUDUR ("Gece 00:00-08:00"): sitenin calisma
# duzenini tanimlar ve P35'te SAHIPLIGI `guvenlik_modu` belirler
# (dis_sirket -> amir, yonetim_ici -> yonetici). O tasarim testli,
# dokunulmadi.
#
# `/vardiya-plani` KIM NE ZAMAN CALISIYOR sorusudur — ekip yonetimi.
# Sahada vardiya degisimini amir yonetir; her degisiklik icin yoneticiye
# gitmek gecikme uretir. Bu yuzden amir burada TAM yetkilidir
# (ekle/degistir/sil/toplu planla) ama YALNIZ `security` rolundeki
# kisiler icin — hedef kisi `_hedef_gorunur` ile denetlenir.
_YAZAR = require_role("admin", "yonetici", "guvenlik_amiri")


def _hedef_gorunur(user: AppUser, hedef_rol: str | None) -> None:
    """(P231 §2) Amir, GOREMEDIGI bir kisinin vardiyasina dokunamaz.

    `gorunur_roller` TEK KAYNAK: personel listesinde kimi goruyorsa
    vardiyasini da ancak onun icin duzenleyebilir. Ayri bir kume yazmak,
    birinin guncellenip otekinin eskimesi demekti.
    """
    gorunur = gorunur_roller(user.role)
    if gorunur is not None and (hedef_rol is None or hedef_rol not in gorunur):
        raise APIError(403, "forbidden", "vardiya_yalniz_kendi_ekibin")

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


async def _izin_denetle(
    db: AsyncSession, user_id: uuid.UUID, tarih: dt.date
) -> None:
    """(P241 §2) IZINLI GUNE VARDIYA ATANAMAZ — istegin acik maddesi.

    KAPI BURADA, TEK YERDE: `ata`, `toplu`, `kalip-uygula`,
    `haftayi-doldur` ve `haftadan-kopyala` hepsi bunu cagirir. Tek
    yolda kontrol etmek, otekilerden sessizce gecilmesi demekti — ve
    izinli bir kisiye vardiya yazmak, o gun kimsenin gelmedigi bir
    nobet birakir.
    """
    if await izinli_mi(db, user_id, tarih):
        raise APIError(422, "validation_error", "vardiya_izinli_gun")


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
            # (P205 §2) OUTER JOIN: sablonsuz (serbest) vardiyalar da
            # cakismaya girer. `join` birakilsaydi serbest vardiyalar
            # denetimin DISINDA kalir — yani "ayni anda iki yerde"
            # tam da yeni yolda mumkun olurdu.
            select(VardiyaPlani, Shift)
            .outerjoin(Shift, Shift.id == VardiyaPlani.shift_id)
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
        var = plan_araligi(plan, shift)
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
            .outerjoin(Shift, Shift.id == VardiyaPlani.shift_id)
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
        toplam += saat_farki(*plan_araligi(plan, shift))
    return toplam


def _rol_kosulu(user: AppUser) -> list:
    """(P231 §2) Cagiranin gorebilecegi personel rolleri icin WHERE parcasi.

    Bos liste = SINIRSIZ (yonetim rolleri). Uc ayri sorguda ayni kurali
    tekrar yazmak yerine tek yerden uretilir.
    """
    gorunur = gorunur_roller(user.role)
    return [AppUser.role.in_(tuple(gorunur))] if gorunur is not None else []


def _plan_kosulu(user: AppUser) -> list:
    """`_rol_kosulu`nun JOIN'SIZ bicimi — dogrudan `VardiyaPlani` sorgulari icin.

    (E2E 2026-09) OLCULEN KUSUR: amirin kapsami yalniz EKLEYEN uclarda
    (`ata`, `toplu`, `kalip-uygula`, `ice-aktar`) denetleniyordu. Silme,
    duzenleme, yayinlama, geri alma ve kopyalama/temizleme uclari hedef
    kisinin rolune BAKMIYORDU: amir tesis gorevlisinin vardiyasini iptal
    edebiliyor, yayinlayip ona bildirim gonderebiliyordu (P231 §3 "tam
    yetki, YALNIZ guvenlik").
    """
    gorunur = gorunur_roller(user.role)
    if gorunur is None:
        return []
    return [
        VardiyaPlani.user_id.in_(
            select(AppUser.id).where(AppUser.role.in_(tuple(gorunur)))
        )
    ]


async def _plan_getir(db: AsyncSession, user: AppUser, plan_id: uuid.UUID) -> VardiyaPlani:
    """Tekil satir — kapsam disi satir YOK sayilir (404, varligi sizmaz)."""
    plan = (
        await db.execute(
            select(VardiyaPlani).where(
                VardiyaPlani.id == plan_id, *_plan_kosulu(user)
            )
        )
    ).scalar_one_or_none()
    if plan is None:
        raise APIError(404, "not_found", "vardiya_plani_bulunamadi")
    return plan


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
                # (P231 §2) Haftalik gorunum de suzulur — `cizelge` ile
                # AYNI kural. Birini suzup otekini acik birakmak, amire
                # ayni bilgiyi ikinci bir ekrandan vermek olurdu.
                *_rol_kosulu(user),
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
    _hedef_gorunur(user, hedef.role)

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

    await _izin_denetle(db, body.user_id, body.tarih)
    aralik = vardiya_araligi(body.tarih, shift.baslangic_saat, shift.bitis_saat)
    uyarilar = await _cakisma_denetle(
        db, user_id=body.user_id, tarih=body.tarih, aralik=aralik,
        haric_id=mevcut.id if mevcut is not None else None,
    )

    # IPTAL EDILMIS ayni satir varsa YENIDEN CANLANDIR: yeni satir
    # acmak, ayni kisi-gun-vardiya ucusu icin gecmiste iki kayit
    # birakirdi ve denetim izi okunmaz olurdu.
    molalar = [m.model_dump(mode="json") for m in (body.molalar or [])]
    if mevcut is not None:
        mevcut.durum = "planli"
        mevcut.not_metni = body.not_metni
        mevcut.molalar = molalar
        mevcut.vardiya_rolu = body.vardiya_rolu
        mevcut.blok_id = body.blok_id
        mevcut.alan = body.alan
        mevcut.updated_at = func.now()
        plan = mevcut
    else:
        # (P241 §2) YENI SATIR TASLAK ACILIR (`yayinlandi_at` NULL).
        # Personel onu gormez; yonetici "Yayinla" deyince gorur.
        plan = VardiyaPlani(
            tenant_id=user.tenant_id,
            shift_id=body.shift_id,
            tarih=body.tarih,
            user_id=body.user_id,
            not_metni=body.not_metni,
            molalar=molalar,
            vardiya_rolu=body.vardiya_rolu,
            blok_id=body.blok_id,
            alan=body.alan,
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
        yayinlandi_at=plan.yayinlandi_at,
        molalar=list(plan.molalar or []),
        vardiya_rolu=plan.vardiya_rolu,
        blok_id=plan.blok_id,
        alan=plan.alan,
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
    plan = await _plan_getir(db, user, plan_id)
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
            .join(AppUser, AppUser.id == ShiftAssignment.user_id)
            .where(*_rol_kosulu(user))
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
                # (P241 §2) Izinli gun ATLANIR — tohumlama, izne cikmis
                # birine sessizce vardiya yazmamali.
                await _izin_denetle(db, atama.user_id, g)
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


# ===================== (P205 §2) ZAMAN CIZELGESI ============================ #
#
# ===========================================================================
# NEDEN AYRI BIR UC — `GET ""` DURUYOR
# ===========================================================================
# Haftalik izgara (`GET ""`) GUN x VARDIYA sorusunu yanitliyor ve mobil
# ekran onu kullaniyor. Cizelge BASKA bir soruyu yanitlar: KISI x SAAT.
# Ayni yanittan ikisini de turetmek mumkun degil, cunku izgarada kisiler
# slotun ICINDE ve saatler SABLONDAN; cizelgede kisi SATIRDIR ve saatler
# blok basinadir.
#
# SABLONSUZ VARDIYALAR izgarada GORUNMEZ (bagli olduklari slot yok) —
# yeni ucun ikinci varlik sebebi de bu.
@router.get("/cizelge", response_model=VardiyaCizelgeOut)
async def cizelge(
    baslangic: dt.date = Query(...),
    gun: int = Query(7, ge=1, le=AZAMI_GUN),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> VardiyaCizelgeOut:
    """Kisi x saat cizelgesi — bloklar COZULMUS saatlerle doner."""
    son = baslangic + dt.timedelta(days=gun - 1)
    # (P231 §2) ROL BAZLI GORUNURLUK. Amir YALNIZ guvenlik personelinin
    # cizelgesini gorur; tesis gorevlisinin vardiyasi onun isi degil ve
    # kim ne zaman calisiyor bilgisi KVKK acisindan da gereksiz.
    gorunur = gorunur_roller(user.role)
    rol_kosulu = _rol_kosulu(user)
    # GECEYI ASAN VARDIYA: bir onceki gunun 22:00-05:00'i, gorunen
    # araligin ILK gunune tasar. Sorguyu bir gun geriye acmazsak o blok
    # cizelgede HIC gorunmezdi.
    satirlar = (
        await db.execute(
            select(VardiyaPlani, Shift, AppUser.ad, AppUser.role, BuildingBlock.ad)
            .outerjoin(Shift, Shift.id == VardiyaPlani.shift_id)
            .join(AppUser, AppUser.id == VardiyaPlani.user_id)
            .outerjoin(
                BuildingBlock, BuildingBlock.id == VardiyaPlani.blok_id
            )
            .where(
                VardiyaPlani.tarih >= baslangic - dt.timedelta(days=1),
                VardiyaPlani.tarih <= son,
                VardiyaPlani.durum == "planli",
                # (P241 §2) PERSONEL YALNIZ YAYINLANMIS PLANI GORUR.
                # Yonetim taslagi da gorur — planlamayi o yapiyor.
                *([] if user.role in ("admin", "yonetici", "guvenlik_amiri")
                  else [VardiyaPlani.yayinlandi_at.isnot(None)]),
                *rol_kosulu,
            )
            .order_by(AppUser.ad, VardiyaPlani.tarih)
        )
    ).all()

    kisiler: dict[uuid.UUID, VardiyaCizelgeKisiOut] = {}
    for plan, shift, ad, rol, blok_ad in satirlar:
        bas, biter = plan_araligi(plan, shift)
        if biter.date() < baslangic or bas.date() > son:
            continue
        k = kisiler.setdefault(
            plan.user_id,
            VardiyaCizelgeKisiOut(user_id=plan.user_id, ad=ad, rol=rol),
        )
        calisma = plan_saat(plan, shift)
        k.bloklar.append(
            VardiyaBlokOut(
                plan_id=plan.id,
                tarih=plan.tarih,
                baslar=bas,
                biter=biter,
                shift_ad=shift.ad if shift else None,
                not_metni=plan.not_metni,
                gece_asiyor=bas.date() != biter.date(),
                vardiya_rolu=plan.vardiya_rolu,
                blok_ad=blok_ad,
                alan=plan.alan,
                calisma_saat=round(calisma, 2),
                mola_dakika=mola_dakika(plan.molalar),
                yayinlandi_at=plan.yayinlandi_at,
                yayin_bekliyor=(
                    plan.yayinlandi_at is not None
                    and plan.updated_at is not None
                    and plan.updated_at > plan.yayinlandi_at
                ),
            )
        )
        # TOPLAM SUNUCUDA: mola kuralini web ve mobilde ayri ayri
        # yazmak, birinde unutuldugunda "izgarada 40, bordroda 44 saat"
        # gibi bir ayrisma uretirdi.
        k.toplam_saat = round(k.toplam_saat + calisma, 2)

    # VARDIYASI OLMAYAN PERSONEL DE LISTEDE: cizelgenin isi "kim
    # calisiyor" kadar "kim BOSTA" sorusunu da yanitlamak. Bos satir
    # olmasaydi yonetici, atamak istedigi kisiyi ekranda goremezdi.
    # BOS SATIRLAR DA SUZULUR: yalniz bloklari suzup personel listesini
    # acik birakmak, amire tesis gorevlisinin ADINI yine gosterirdi —
    # "vardiyasi yok" satiri olarak.
    atanabilir = ["security", "tesis_gorevlisi", "guvenlik_amiri", "yonetici"]
    if gorunur is not None:
        atanabilir = [r for r in atanabilir if r in gorunur]
    personel = (
        await db.execute(
            select(AppUser)
            .where(
                AppUser.is_active.is_(True),
                AppUser.role.in_(atanabilir),
            )
            .order_by(AppUser.ad)
        )
    ).scalars().all()
    for p in personel:
        kisiler.setdefault(
            p.id, VardiyaCizelgeKisiOut(user_id=p.id, ad=p.ad, rol=p.role)
        )

    # (P243 §2) VARDIYA DUZENINE DAHIL OLANLAR — "Atanmamis"in olcutu.
    #
    # Donem disindaki satirlar da sayilir: bu hafta vardiyasi olmayan
    # ama gecen hafta calismis biri TAM DA "atanmamis" olandir. Yalniz
    # donem icine bakmak, olcutu tanimin kendisiyle celistirirdi.
    duzendekiler = set(
        (
            await db.execute(select(VardiyaPlani.user_id).distinct())
        ).scalars().all()
    ) | set(
        (
            await db.execute(select(ShiftAssignment.user_id).distinct())
        ).scalars().all()
    )
    for uid, k in kisiler.items():
        k.vardiya_duzeninde = uid in duzendekiler

    # (P241 §2) IZIN KATMANI — bloklarla AYNI listeye konmaz.
    #
    # `bloklar` mesai hesabinin de okudugu sekildir; izni oraya koymak,
    # izinli gunu calisma saymaya giden ilk adim olurdu (goc 0145).
    izinler = (
        await db.execute(
            select(VardiyaIzin)
            .where(
                VardiyaIzin.durum == "onaylandi",
                VardiyaIzin.bitis >= baslangic,
                VardiyaIzin.baslangic <= son,
            )
            .order_by(VardiyaIzin.baslangic)
        )
    ).scalars().all()
    for iz in izinler:
        k = kisiler.get(iz.user_id)
        if k is None:
            continue  # goremedigi bir kisinin izni (rol suzgeci)
        k.izinler.append(
            VardiyaIzinBlokOut(
                izin_id=iz.id, tur=iz.tur, baslangic=iz.baslangic,
                bitis=iz.bitis, tum_gun=iz.tum_gun,
                baslangic_saat=iz.baslangic_saat, bitis_saat=iz.bitis_saat,
            )
        )

    # HEDEF SAAT: donemdeki HAFTA SAYISI x haftalik normal sure.
    # Sabit 45 yazmak, iki haftalik bir gorunumde hedefi yari yariya
    # yanlis gosterirdi.
    hedef = round(HAFTALIK_NORMAL_SAAT * (gun / 7.0), 2)
    for k in kisiler.values():
        k.hedef_saat = hedef

    return VardiyaCizelgeOut(
        baslangic=baslangic,
        bitis=son,
        personel=sorted(kisiler.values(), key=lambda k: k.ad.lower()),
    )


@router.post("/toplu", response_model=VardiyaTopluOut)
async def toplu_ekle(
    body: VardiyaTopluIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaTopluOut:
    """(§2.2) Tarih araligindaki HER GUN icin vardiya olustur.

    =======================================================================
    CAKISAN GUNLER SESSIZCE ATLANMAZ
    =======================================================================
    Istegin acik sarti: kullaniciya HANGI gunlerde cakisma oldugu
    soylensin ve KARARI O VERSIN. Bu yuzden iki asamali:

      1. `cakisanlari_atla=false` (varsayilan) ve cakisma VARSA:
         HICBIR SEY YAZILMAZ, 409 doner ve cakisan gunler listelenir.
      2. Kullanici "cakisanlar haric ekle" derse istemci bayragi acar;
         o zaman cakisanlar ATLANIR ve yanitta gun gun ne olduğu yazar.

    Sessizce atlamak, yoneticinin "on dort gun ekledim" saniip yedi gun
    eklemesi demekti — ve eksik gunu ancak sahada fark ederdi.
    """
    # (P229 §2) IKI GIRIS BICIMI, TEK KURAL KUMESI.
    #
    # `gunler` verilirse KEYFI (bitisik olmayan) secim; verilmezse
    # ARALIK. Ikisi de ayni denetimlerden gecer — cakisma, "hepsi ya da
    # hicbiri", azami gun, denetim kaydi. Ayrintili gerekce semada.
    if body.gunler is not None:
        if not body.gunler:
            raise APIError(422, "validation_error", "vardiya_gun_secilmedi")
        # TEKRARLAR ELENIR: istemci ayni gunu iki kez gonderirse sessizce
        # iki vardiya yazmak, kullanicinin gormedigi bir cakisma uretirdi.
        gunler = sorted(set(body.gunler))
        if len(gunler) > AZAMI_GUN:
            raise APIError(422, "validation_error", "vardiya_aralik_cok_uzun")
    else:
        if body.bitis_tarih < body.baslangic_tarih:
            raise APIError(422, "validation_error", "vardiya_tarih_araligi_ters")
        gun_sayisi = (body.bitis_tarih - body.baslangic_tarih).days + 1
        if gun_sayisi > AZAMI_GUN:
            raise APIError(422, "validation_error", "vardiya_aralik_cok_uzun")
        gunler = [
            body.baslangic_tarih + dt.timedelta(days=i) for i in range(gun_sayisi)
        ]

    hedef = (
        await db.execute(select(AppUser).where(AppUser.id == body.user_id))
    ).scalar_one_or_none()
    if hedef is None or not hedef.is_active:
        raise APIError(422, "validation_error", "personel_bulunamadi")
    _hedef_gorunur(user, hedef.role)

    # ============ 1. GECIS: YALNIZ OLC, HICBIR SEY YAZMA ============
    # Once denetleyip sonra yazmak SART: "hepsi ya da hicbiri"
    # kuralini, yazdiktan sonra geri almaya calisarak saglamak,
    # yarim yazilmis bir plan birakma riski tasirdi.
    cakisanlar: list[dt.date] = []
    uygun: list[dt.date] = []
    for g in gunler:
        aralik = vardiya_araligi(g, body.baslangic_saat, body.bitis_saat)
        try:
            # IZIN DE "cakisma" sayilir: kullaniciya gun gun gosterilen
            # listede sebep ayrimi yapmak yerine ayni kapidan gecirmek,
            # "hepsi ya da hicbiri" kuralini bozmadan izni de kapsar.
            await _izin_denetle(db, body.user_id, g)
            await _cakisma_denetle(db, user_id=body.user_id, tarih=g, aralik=aralik)
        except APIError:
            cakisanlar.append(g)
            continue
        uygun.append(g)

    if cakisanlar and not body.cakisanlari_atla:
        # HATA DEGIL, SORU. Bir `APIError` atsaydik cakisan GUNLERIN
        # LISTESI yanita sigmazdi (hata zarfi sozlesmede sabittir ve
        # serbest bir dizi tasimaz) — kullaniciya "bir yerde cakisma
        # var" deyip onu tek tek aramaya gondermek olurdu.
        #
        # HICBIR SEY YAZILMADI: `uygulandi=false`. Istemci gunleri
        # gosterir, kullanici karar verir, istek `cakisanlari_atla`
        # ile TEKRARLANIR.
        return VardiyaTopluOut(
            uygulandi=False,
            eklenen=0,
            cakisan=len(cakisanlar),
            gunler=[
                VardiyaTopluGunOut(
                    tarih=g,
                    durum="cakisma" if g in cakisanlar else "eklenebilir",
                )
                for g in gunler
            ],
        )

    sonuc: list[VardiyaTopluGunOut] = []
    parti_id = uuid.uuid4()
    uyarilar: set[str] = set()
    for g in gunler:
        if g in cakisanlar:
            sonuc.append(VardiyaTopluGunOut(tarih=g, durum="cakisma"))
            continue
        aralik = vardiya_araligi(g, body.baslangic_saat, body.bitis_saat)
        # IKINCI DENETIM: ilk gecisten sonra BU DONGUDE eklenen
        # satirlar da cakisabilir (ayni gunun icinde iki kez ayni
        # araligi eklemek gibi). Ilk gecisin sonucuna guvenmek,
        # kendi yazdigimiz satirla cakismayi gormemek olurdu.
        try:
            await _izin_denetle(db, body.user_id, g)
            uyarilar.update(
                await _cakisma_denetle(
                    db, user_id=body.user_id, tarih=g, aralik=aralik
                )
            )
        except APIError:
            sonuc.append(VardiyaTopluGunOut(tarih=g, durum="cakisma"))
            continue
        plan = VardiyaPlani(
            tenant_id=user.tenant_id,
            shift_id=None,
            tarih=g,
            user_id=body.user_id,
            # (E2E 2026-09) TOPLU ISLEM PARTI TASIR: kalip-uygula gibi tek
            # adimda geri alinabilsin (onceden parti_id NULL'du; 30 gunluk
            # yanlis ekleme tek tek silinmek zorundaydi).
            parti_id=parti_id,
            baslangic_saat=body.baslangic_saat,
            bitis_saat=body.bitis_saat,
            not_metni=body.not_metni,
            molalar=[m.model_dump(mode="json") for m in (body.molalar or [])],
            vardiya_rolu=body.vardiya_rolu,
            blok_id=body.blok_id,
            alan=body.alan,
        )
        db.add(plan)
        await db.flush()
        sonuc.append(
            VardiyaTopluGunOut(tarih=g, durum="eklendi", plan_id=plan.id)
        )

    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=None,
        meta={
            "islem": "toplu_ekle",
            "user_id": str(body.user_id),
            "baslangic": body.baslangic_tarih.isoformat(),
            "bitis": body.bitis_tarih.isoformat(),
            "saat": f"{body.baslangic_saat}-{body.bitis_saat}",
            "gece_asiyor": gece_asiyor_mu(body.baslangic_saat, body.bitis_saat),
            "eklenen": sum(1 for x in sonuc if x.durum == "eklendi"),
            "cakisan": sum(1 for x in sonuc if x.durum == "cakisma"),
        },
    )
    return VardiyaTopluOut(
        uygulandi=True,
        parti_id=parti_id if any(x.durum == "eklendi" for x in sonuc) else None,
        eklenen=sum(1 for x in sonuc if x.durum == "eklendi"),
        cakisan=sum(1 for x in sonuc if x.durum == "cakisma"),
        gunler=sonuc,
        uyarilar=sorted(uyarilar),
    )


# ==================== (P207 §1) VARDIYA KALIBI ============================== #
#
# ===========================================================================
# NEDEN KALIP
# ===========================================================================
# "Gunu kac vardiyaya bolecegim" sorusu her ay AYNI yanitlanir: 2
# vardiya (08-20 / 20-08) ya da 3 vardiya (08-16 / 16-24 / 00-08).
# Bunu her ay basinda elle girmek, yirmi kisilik bir ekipte yuzlerce
# tiklama demek — ve her tekrarda bir saat yanlis yazilabilir.
@router.get("/kaliplar", response_model=VardiyaKalibiListResponse)
async def kaliplar(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> VardiyaKalibiListResponse:
    satirlar = (
        await db.execute(
            select(VardiyaKalibi).order_by(VardiyaKalibi.ad)
        )
    ).scalars().all()
    return VardiyaKalibiListResponse(
        items=[VardiyaKalibiOut.model_validate(k) for k in satirlar]
    )


@router.post("/kaliplar", response_model=VardiyaKalibiOut, status_code=201)
async def kalip_olustur(
    body: VardiyaKalibiCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaKalibiOut:
    var = (
        await db.execute(select(VardiyaKalibi).where(VardiyaKalibi.ad == body.ad))
    ).scalar_one_or_none()
    if var is not None:
        raise APIError(409, "conflict", "vardiya_kalibi_ad_kullanimda")
    kalip = VardiyaKalibi(
        tenant_id=user.tenant_id,
        ad=body.ad,
        dilimler=[d.model_dump(mode="json") for d in body.dilimler],
        aktif=body.aktif,
        adimlar=body.adimlar,
    )
    db.add(kalip)
    await db.flush()
    await db.refresh(kalip)
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_kalibi",
        resource_id=kalip.id,
        meta={"islem": "kalip_olustur", "ad": body.ad,
              "dilim": len(body.dilimler)},
    )
    return VardiyaKalibiOut.model_validate(kalip)


@router.delete("/kaliplar/{kalip_id}", status_code=204, response_model=None)
async def kalip_sil(
    kalip_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> None:
    kalip = (
        await db.execute(select(VardiyaKalibi).where(VardiyaKalibi.id == kalip_id))
    ).scalar_one_or_none()
    if kalip is None:
        raise APIError(404, "not_found", "vardiya_kalibi_bulunamadi")
    # (P247 §1) ETKIN DONGU ATAMASI VARSA SILINMEZ: beat kayan ufku bu
    # kaliptan uretiyor. Silinseydi ekip ertesi aydan itibaren SESSIZCE
    # plansiz kalirdi. Once atamalar sonlandirilir/geri alinir.
    if await _etkin_atama_var(db, kalip_id):
        raise APIError(409, "conflict", "vardiya_kalibi_kullanimda")
    # KALIP SILINIR, OLUSMUS PLANLAR KALIR: kalip bir SABLONDUR, plan
    # satirlarinin ona bagli bir yasami yok (`parti_id` ile geri alinir).
    await db.delete(kalip)
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_kalibi",
        resource_id=kalip_id, meta={"islem": "kalip_sil"},
    )


def _rotasyonlu_atama(
    atamalar: dict[int, list[uuid.UUID]],
    dilim_sayisi: int,
    hafta: int,
) -> dict[int, list[uuid.UUID]]:
    """(§1.3) HAFTALIK ROTASYON — ekipler dilimler arasinda kayar.

    =======================================================================
    ROTASYON NEDEN DESTEKLENDI
    =======================================================================
    Guvenlik sektorunun STANDART kalibi: A ekibi bu hafta gunduz, gelecek
    hafta gece. Desteklemezsek yonetici ayni ayi IKI kez planlamak
    (once A gunduz, sonra B gunduz) ya da her hafta elle degistirmek
    zorunda kalir — ve elle degistirilen her hafta, bir haftanin
    atlanma ihtimalidir.
    =======================================================================
    NEDEN YALNIZ "HAFTALIK" VE NEDEN TEK KAYDIRMA
    =======================================================================
    Ucler/dortluler, ileri/geri rotasyon, "iki gun calis bir gun izin"
    gibi desenler VAR ama her biri BASKA bir kural. Hepsini bir
    parametreye sigdirmak, kullanicinin anlamadigi bir kutu uretirdi.
    Buradaki soz NET: her hafta atamalar BIR DILIM ILERI kayar. Otekiler
    icin kalip iki kez uygulanir (ayri partiler, ayri geri alma).
    """
    if dilim_sayisi <= 1:
        return atamalar
    kaydir = hafta % dilim_sayisi
    return {
        (i + kaydir) % dilim_sayisi: kisiler
        for i, kisiler in atamalar.items()
    }


async def _gruplari_coz(
    db: AsyncSession, body
) -> list[tuple[list[dt.date], list[VardiyaDilim], dict[int, list[uuid.UUID]]]]:
    """(P232) Istegi (gunler, dilimler, atamalar) UCLULERINE cevirir.

    TEK BICIM, IKI GIRIS: cok gruplu istek de tekil istek de burada ayni
    sekle indirgenir; asagidaki dongu tek bir kod yolu kullanir. Iki ayri
    dongu yazmak, catisma kuralinin ya da rotasyonun birinde guncellenip
    otekinde eskimesi demekti.
    """
    async def _dilimler(kalip_id, dilimler) -> list[VardiyaDilim]:
        if kalip_id is None:
            return list(dilimler or [])
        kalip = (
            await db.execute(
                select(VardiyaKalibi).where(VardiyaKalibi.id == kalip_id)
            )
        ).scalar_one_or_none()
        if kalip is None:
            raise APIError(422, "validation_error", "vardiya_kalibi_bulunamadi")
        if kalip.adimlar is not None:
            # (P247 §1) DONGU KALIBI buradan UYGULANMAZ: bu uc her secili
            # gune TUM dilimleri yazar; bir dongude o gun hangi dilimin
            # (ya da tatilin) gelecegini bilmez ve 2-2-2 dongusunu "her gun
            # gece + gunduz" diye yazardi. Dongu `/dongu-uygula`dan gider.
            raise APIError(422, "validation_error", "vardiya_kalibi_dongu")
        return [VardiyaDilim.model_validate(d) for d in kalip.dilimler]

    if body.gruplar:
        return [
            (sorted(set(g.gunler)), await _dilimler(g.kalip_id, g.dilimler),
             g.atamalar)
            for g in body.gruplar
        ]
    return [
        (sorted(set(body.gunler)),
         await _dilimler(body.kalip_id, body.dilimler),
         body.atamalar)
    ]


@router.post("/kalip-uygula", response_model=VardiyaKalipSonuc)
async def kalip_uygula(
    body: VardiyaKalipUygulaIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaKalipSonuc:
    """(§1.1-§1.3) SECILI GUNLERE kalibi uygula — onizleme + geri alinabilir.

    =======================================================================
    ONIZLEME AYRI BIR UC DEGIL
    =======================================================================
    `kuru=true` hicbir sey yazmaz ve AYNI hesabi dondurur. Ayri bir
    "onizleme" ucu yazmak, iki kod yolunun ayrisma riski demekti: sonuc
    onizlemede baska, kaydetmede baska cikardi — ve kullanici buna ancak
    yazdiktan sonra guvenmeyi birakirdi.

    =======================================================================
    CAKISMA SESSIZCE ATLANMAZ (P205 KURALI KORUNDU)
    =======================================================================
    Cakisma varsa ve `cakisanlari_atla=false` ise HICBIR SEY YAZILMAZ;
    yanit hangi gun/dilim/kisi cakistigini SATIR SATIR soyler.

    =======================================================================
    GERI ALINABILIR
    =======================================================================
    Yazilan her satir AYNI `parti_id`yi tasir. "30 gunluk yanlis plan"
    tek istekle geri alinir (`POST /vardiya-plani/parti/{id}/geri-al`).
    """
    # (P232) COK GRUPLU: "pazartesi gunduz, sali-carsamba gece".
    gruplar = await _gruplari_coz(db, body)

    kisi_idler = {
        u for _, _, atamalar in gruplar
        for liste in atamalar.values() for u in liste
    }
    if not kisi_idler:
        raise APIError(422, "validation_error", "vardiya_atama_bos")
    kisiler = {
        k.id: k
        for k in (
            await db.execute(select(AppUser).where(AppUser.id.in_(kisi_idler)))
        ).scalars().all()
    }
    eksik = kisi_idler - set(kisiler)
    if eksik or any(not k.is_active for k in kisiler.values()):
        # TESIS IZOLASYONU: baska tesisin kullanicisi RLS'te GORUNMEZ,
        # yani "bulunamadi" olur. Yetki genisledi, kapsam genislemedi.
        raise APIError(422, "validation_error", "personel_bulunamadi")
    # (P231 §2) AMIR YALNIZ KENDI EKIBINI PLANLAR — cok gruplu istekte de.
    for k in kisiler.values():
        _hedef_gorunur(user, k.role)

    parti_id = uuid.uuid4()
    satirlar: list[VardiyaKalipGunDilim] = []
    yazilacak: list[tuple[dt.date, VardiyaDilim, uuid.UUID]] = []
    uyarilar: set[str] = set()

    # TEK PARTI: gruplar ayri ayri yazilsaydi geri alma birden cok istek
    # olurdu — kullanici acisindan tek karar, sistemde birden cok iz.
    for gunler, dilimler, atamalar in gruplar:
        if not gunler or not dilimler:
            continue
        ilk_gun = gunler[0]
        for gun in gunler:
            # (P243 §1e) DONEM INDISI: haftalikta gun farkindan, aylikta
            # TAKVIM AYI farkindan. Aylik icin de "28 gunde bir" saymak,
            # rotasyonu ayin ortasinda kaydirirdi (bkz. sema gerekcesi).
            if body.rotasyon == "aylik":
                donem = (gun.year - ilk_gun.year) * 12 + (gun.month - ilk_gun.month)
            else:
                donem = (gun - ilk_gun).days // 7
            atama = (
                _rotasyonlu_atama(atamalar, len(dilimler), donem)
                if body.rotasyon in ("haftalik", "aylik")
                else atamalar
            )
            for sira, dilim in enumerate(dilimler):
                for kisi_id in atama.get(sira, []):
                    aralik = vardiya_araligi(gun, dilim.baslangic, dilim.bitis)
                    # AYNI SATIR ZATEN VAR MI: kalibi ikinci kez uygulamak
                    # (or. bir gun ekleyip yeniden calistirmak) mevcut
                    # satirlari "cakisma" diye raporlamamali — bu, dogru bir
                    # islemi hata gibi gostermek olurdu.
                    mevcut = (
                        await db.execute(
                            select(VardiyaPlani).where(
                                VardiyaPlani.tarih == gun,
                                VardiyaPlani.user_id == kisi_id,
                                VardiyaPlani.durum == "planli",
                                VardiyaPlani.baslangic_saat == dilim.baslangic,
                                VardiyaPlani.bitis_saat == dilim.bitis,
                            )
                        )
                    ).scalar_one_or_none()
                    if mevcut is not None:
                        satirlar.append(VardiyaKalipGunDilim(
                            tarih=gun, dilim=dilim.ad, baslangic=dilim.baslangic,
                            bitis=dilim.bitis, user_id=kisi_id,
                            ad=kisiler[kisi_id].ad, durum="zaten_var"))
                        continue
                    try:
                        # (P241 §2) Izinli gun de "cakisma" satiri olarak
                        # RAPORLANIR — kullanici NEDEN yazilmadigini
                        # onizlemede gorur, sessizce atlanmaz.
                        await _izin_denetle(db, kisi_id, gun)
                        uyarilar.update(await _cakisma_denetle(
                            db, user_id=kisi_id, tarih=gun, aralik=aralik))
                    except APIError:
                        satirlar.append(VardiyaKalipGunDilim(
                            tarih=gun, dilim=dilim.ad, baslangic=dilim.baslangic,
                            bitis=dilim.bitis, user_id=kisi_id,
                            ad=kisiler[kisi_id].ad, durum="cakisma"))
                        continue
                    satirlar.append(VardiyaKalipGunDilim(
                        tarih=gun, dilim=dilim.ad, baslangic=dilim.baslangic,
                        bitis=dilim.bitis, user_id=kisi_id,
                        ad=kisiler[kisi_id].ad, durum="eklenecek"))
                    yazilacak.append((gun, dilim, kisi_id))

    cakisan = sum(1 for r in satirlar if r.durum == "cakisma")
    zaten = sum(1 for r in satirlar if r.durum == "zaten_var")

    # ONIZLEME ya da "cakisma var ama kullanici karar vermedi": YAZMA.
    if body.kuru or (cakisan and not body.cakisanlari_atla):
        return VardiyaKalipSonuc(
            uygulandi=False, eklenecek=len(yazilacak), cakisan=cakisan,
            zaten_var=zaten, satirlar=satirlar, uyarilar=sorted(uyarilar),
        )

    for gun, dilim, kisi_id in yazilacak:
        db.add(VardiyaPlani(
            tenant_id=user.tenant_id,
            shift_id=None,
            tarih=gun,
            user_id=kisi_id,
            baslangic_saat=dilim.baslangic,
            bitis_saat=dilim.bitis,
            not_metni=body.not_metni,
            # (P243 §1) MOLALAR bu yoldan da yazilir: web modali artik
            # TEK YOLDAN buraya geliyor.
            molalar=[m.model_dump(mode="json") for m in (body.molalar or [])],
            parti_id=parti_id,
        ))
    await db.flush()
    for r in satirlar:
        if r.durum == "eklenecek":
            r.durum = "eklendi"
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=None,
        meta={
            "islem": "kalip_uygula",
            "parti_id": str(parti_id),
            "gun": len(gunler),
            "dilim": len(dilimler),
            "rotasyon": body.rotasyon,
            "eklenen": len(yazilacak),
            "cakisan": cakisan,
        },
    )
    return VardiyaKalipSonuc(
        uygulandi=True, parti_id=parti_id, eklenen=len(yazilacak),
        cakisan=cakisan, zaten_var=zaten, satirlar=satirlar,
        uyarilar=sorted(uyarilar),
    )


@router.post("/parti/{parti_id}/geri-al", response_model=VardiyaPartiGeriAlSonuc)
async def parti_geri_al(
    parti_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaPartiGeriAlSonuc:
    """(§1 KRITIK) TOPLU ISLEMI GERI AL.

    "30 gunluk yanlis plan olusturan yonetici tek tek silmek zorunda
    kalmasin" — istegin acik sarti.

    SILMEZ, `iptal` ISARETLER: P203'ten beri gecerli kural. Silmek,
    denetim kaydini "neyin degistigini" gosteremez hâle getirirdi.

    YALNIZ HÂLÂ `planli` OLAN SATIRLAR: parti sonrasi elle degistirilmis
    (cikarilmis) satirlari yeniden ellemek, yoneticinin ARADAKI kararini
    sessizce ezmek olurdu.
    """
    satirlar = (
        await db.execute(
            select(VardiyaPlani).where(
                VardiyaPlani.parti_id == parti_id,
                VardiyaPlani.durum == "planli",
                *_plan_kosulu(user),
            )
        )
    ).scalars().all()
    # (P247 §1) DONGU PARTISI: satirlarla birlikte ATAMALAR da geri alinir.
    # Yalniz satirlari iptal etmek yetmezdi — beat ertesi gece kayan ufku
    # ayni atamadan YENIDEN doldururdu ve "geri al" bir gun surerdi.
    atamalar = (
        await db.execute(
            select(VardiyaDonguAtama).where(
                VardiyaDonguAtama.parti_id == parti_id,
                VardiyaDonguAtama.iptal_at.is_(None),
                *_atama_kosulu(user),
            )
        )
    ).scalars().all()
    if not satirlar and not atamalar:
        raise APIError(404, "not_found", "vardiya_partisi_bulunamadi")
    for plan in satirlar:
        plan.durum = "iptal"
        plan.updated_at = func.now()
    for a in atamalar:
        a.iptal_at = func.now()
        a.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=None,
        meta={"islem": "parti_geri_al", "parti_id": str(parti_id),
              "iptal_edilen": len(satirlar), "dongu_atama": len(atamalar)},
    )
    return VardiyaPartiGeriAlSonuc(
        parti_id=parti_id, iptal_edilen=len(satirlar)
    )


# =========================================================================== #
# (P247 §1) VARDIYA ROTASYONU — DONGU KALIPLARI
# =========================================================================== #
#
# ===========================================================================
# OLCUM: BUGUNE KADAR NE VARDI
# ===========================================================================
# P207 haftalik, P243 aylik "rotasyon" getirdi: ikisi de dilim ATAMALARINI
# donem basina bir KAYDIRIR (A ekibi bu hafta gunduz, gelecek hafta gece).
# Sahadaki dongulerin hicbiri bu kaliba uymuyordu: "2 gece-2 gunduz-2
# tatil" bir GUN dizisidir (haftaya bolunmez: 6 gunluk dongu her hafta
# baska gune duser), 12/36 ise GUN ASIRI calismadir ve "her gun tum
# dilimler" diyen kalip onu anlatamaz. Ustelik ikisi de bir kerelik
# PARTI uretiyordu: donguyu surdurmek icin yonetici her ay bastan
# uygulamak ve ofseti (kim hangi gunde) elle tutturmak zorundaydi —
# tutturamadigi ay nobet delinir.
#
# ===========================================================================
# MODEL: GUN UZUNLUGUNDA ADIM DIZISI (kalibin `adimlar`i)
# ===========================================================================
# Her adim o gun calisilan DILIMLERIN sira numaralari, bos = tatil.
# 12/36 bu dizinin OZEL HALIDIR: [[gece],[]] — 20:00-08:00 calis, ertesi
# 08:00'den sonraki gun 20:00'e kadar 36 saat dinlen. Saat tabanli bir
# model (calis N saat, dinlen M saat) AYRICA yazilmadi: plan satiri zaten
# GUNE bagli (`vardiya_plani.tarih` + saat + gece asma) ve periyodu 24'un
# kati olmayan her oran (12/24 = 36 saat) iki-uc gunluk bir adim dizisine
# acilir. Iki model, ayni satiri iki farkli yoldan ureten iki kod yolu
# demekti.
#
# ===========================================================================
# UFUK: SURESIZ ATAMA + KAYAN URETIM
# ===========================================================================
# Atama suresizdir; satirlar `bugun + DONGU_UFUK_GUN`e kadar uretilir ve
# beat her gece ufku bir gun ileri tasir. 62 gun: her an bir sonraki TAM
# takvim ayi uretilmis olur (ayin 1'inde bile ertesi ayin sonu 61 gun
# ileride) — yonetici gelecek ayi gorup YAYINLAYABILIR. Daha uzun ufuk,
# gozden gecirilmemis taslak yigini ve izin/ayrilik durumunda iptal
# edilecek satir demekti.
#
# ===========================================================================
# IZIN / TATIL / ELLE DEGISIKLIK — DONGU KAYMAZ
# ===========================================================================
# * Adim TAKVIMDEN hesaplanir (`dongu_adimi`), sayactan degil: izinli
#   gunde satir uretilmez ama dongu ilerler; ertesi gun kisi yerindedir.
# * Uretici `uretildi_kadar` FILIGRANININ gerisine DONMEZ: elle
#   duzenlenen ya da iptal edilen satir sonraki uretimde ezilmez/geri
#   gelmez. Tek gunluk degisiklik yalniz o gunu etkiler.
# * Resmi tatil: sistemde tatil takvimi YOK (`_gun_tipi` notu). Dongu
#   tatilde de doner — nobet tatilde de tutulur; kisinin tatil izni
#   `vardiya_izin` (tur=resmi_tatil) ile girilir ve izin kuralina tabidir.

#: Kayan ufuk (gun) — gerekce yukarida.
DONGU_UFUK_GUN = 62
#: Atama basina saklanan son atlanan gun sayisi (sessiz atlama yok, ama
#: sinirsiz buyuyen bir JSON de yok).
_ATLANAN_UST = 60


def _atama_kosulu(user: AppUser) -> list:
    """`_plan_kosulu`nun atama karsiligi — amir yalniz kendi ekibi."""
    gorunur = gorunur_roller(user.role)
    if gorunur is None:
        return []
    return [
        VardiyaDonguAtama.user_id.in_(
            select(AppUser.id).where(AppUser.role.in_(tuple(gorunur)))
        )
    ]


async def _etkin_atama_var(db: AsyncSession, kalip_id: uuid.UUID) -> bool:
    satir = (
        await db.execute(
            select(VardiyaDonguAtama.id).where(
                VardiyaDonguAtama.kalip_id == kalip_id,
                VardiyaDonguAtama.iptal_at.is_(None),
                (VardiyaDonguAtama.bitis.is_(None))
                | (VardiyaDonguAtama.uretildi_kadar.is_(None))
                | (VardiyaDonguAtama.uretildi_kadar < VardiyaDonguAtama.bitis),
            ).limit(1)
        )
    ).first()
    return satir is not None


async def tesis_bugunu(db: AsyncSession, tenant_id: uuid.UUID) -> dt.date:
    """Tesisin YEREL bugunu (`simdi` ile ayni kural)."""
    tz_ad = (
        await db.execute(select(Tenant.timezone).where(Tenant.id == tenant_id))
    ).scalar_one_or_none()
    return dt.datetime.now(ZoneInfo(tz_ad or "Europe/Istanbul")).date()


def _dongu_tanimi(kalip: VardiyaKalibi) -> tuple[list[VardiyaDilim], list[list[int]]]:
    if kalip.adimlar is None:
        raise APIError(422, "validation_error", "vardiya_kalibi_dongu_degil")
    return (
        [VardiyaDilim.model_validate(d) for d in kalip.dilimler],
        [list(a) for a in kalip.adimlar],
    )


async def _dongu_plani(
    db: AsyncSession,
    *,
    dilimler: list[VardiyaDilim],
    adimlar: list[list[int]],
    kisi_id: uuid.UUID,
    referans: dt.date,
    bas: dt.date,
    son: dt.date,
) -> tuple[list[tuple[dt.date, VardiyaDilim, str]], set[str]]:
    """Bir kisinin [bas, son] araliginda dongu satirlari + her birinin durumu.

    Denetimler `kalip-uygula` ile AYNI yardimcilardan gecer
    (`_izin_denetle`, `_cakisma_denetle`) — dongu icin ayri bir cakisma
    kurali yazmak, iki kuralin ayrismasi demekti.
    """
    sonuc: list[tuple[dt.date, VardiyaDilim, str]] = []
    uyarilar: set[str] = set()
    # AYNI ISTEKTE URETILEN satirlar birbiriyle de cakisabilir (dongu
    # 20:00-08:00 gecesinin ertesi gunune 06:00 baslayan bir dilim koymus
    # olabilir). Satirlar sonda yazildigi icin veritabani denetimi onlari
    # GORMEZ; burada bellekte tutulur.
    bekleyen: list[tuple[dt.datetime, dt.datetime]] = []
    gun = bas
    while gun <= son:
        adim = adimlar[dongu_adimi(gun, referans, len(adimlar))]
        for sira in adim:
            dilim = dilimler[sira]
            aralik = vardiya_araligi(gun, dilim.baslangic, dilim.bitis)
            mevcut = (
                await db.execute(
                    select(VardiyaPlani.id).where(
                        VardiyaPlani.tarih == gun,
                        VardiyaPlani.user_id == kisi_id,
                        VardiyaPlani.durum == "planli",
                        VardiyaPlani.baslangic_saat == dilim.baslangic,
                        VardiyaPlani.bitis_saat == dilim.bitis,
                    ).limit(1)
                )
            ).first()
            if mevcut is not None:
                sonuc.append((gun, dilim, "zaten_var"))
                continue
            try:
                await _izin_denetle(db, kisi_id, gun)
            except APIError:
                # IZIN CAKISMA DEGILDIR: beklenen bir bosluktur ve karar
                # gerektirmez (dongu sayaci yine ilerler). Ayri durum.
                sonuc.append((gun, dilim, "izinli"))
                continue
            try:
                uyarilar.update(
                    await _cakisma_denetle(db, user_id=kisi_id, tarih=gun, aralik=aralik)
                )
                if any(cakisiyor_mu(aralik, b) for b in bekleyen):
                    raise APIError(422, "validation_error", "vardiya_cakisiyor")
            except APIError:
                sonuc.append((gun, dilim, "cakisma"))
                continue
            bekleyen.append(aralik)
            sonuc.append((gun, dilim, "eklenecek"))
        gun += dt.timedelta(days=1)
    return sonuc, uyarilar


def _plan_satiri(
    *, tenant_id, gun: dt.date, dilim: VardiyaDilim, kisi_id, parti_id,
    atama_id, molalar, not_metni,
) -> VardiyaPlani:
    # (P241 §2) TASLAK ACILIR (`yayinlandi_at` NULL): uretilen dongu de
    # bir plandir; personel yonetici yayinlayinca gorur.
    return VardiyaPlani(
        tenant_id=tenant_id,
        shift_id=None,
        tarih=gun,
        user_id=kisi_id,
        baslangic_saat=dilim.baslangic,
        bitis_saat=dilim.bitis,
        not_metni=not_metni,
        molalar=list(molalar or []),
        parti_id=parti_id,
        dongu_atama_id=atama_id,
    )


def _atlanan_ekle(atama: VardiyaDonguAtama, satirlar) -> None:
    yeni = [
        {"tarih": g.isoformat(), "dilim": d.ad, "sebep": durum}
        for g, d, durum in satirlar
        if durum in ("izinli", "cakisma")
    ]
    if yeni:
        atama.atlanan = (list(atama.atlanan or []) + yeni)[-_ATLANAN_UST:]


async def _kapsama(
    db: AsyncSession,
    user: AppUser,
    roller: set[str],
    bas: dt.date,
    son: dt.date,
    ekler: list[tuple[dt.datetime, dt.datetime]],
) -> list[VardiyaKapsamaGun]:
    """(P247 §1) SAAT BAZINDA KAPSAMA — "24 saatin hangi dilimleri kimsesiz".

    KAPSAM: secilen kisilerin ROLLERINDEKI tum personelin planli satirlari
    (+ onizlemedeki yeni satirlar). Yalniz secilen kisilere bakmak, ayni
    nobeti tutan ekip disi bir gorevlinin gecesini "bos" gosterirdi; tum
    rollere bakmak ise tesis gorevlisinin gunduzunu guvenlik nobeti
    sanardi.
    """
    araliklar = list(ekler)
    satirlar = (
        await db.execute(
            select(VardiyaPlani, Shift)
            .outerjoin(Shift, Shift.id == VardiyaPlani.shift_id)
            .join(AppUser, AppUser.id == VardiyaPlani.user_id)
            .where(
                VardiyaPlani.durum == "planli",
                VardiyaPlani.tarih >= bas - dt.timedelta(days=1),
                VardiyaPlani.tarih <= son,
                AppUser.role.in_(tuple(roller)),
                *_rol_kosulu(user),
            )
        )
    ).all()
    for plan, shift in satirlar:
        try:
            araliklar.append(plan_araligi(plan, shift))
        except ValueError:
            continue
    gunler: list[VardiyaKapsamaGun] = []
    gun = bas
    while gun <= son:
        bosluk = kapsama_bosluklari(gun, araliklar)
        gunler.append(
            VardiyaKapsamaGun(
                tarih=gun,
                bos_dakika=int(sum((b - a).total_seconds() for a, b in bosluk) // 60),
                bosluklar=[
                    VardiyaKapsamaAralik(baslangic=a.time(), bitis=b.time())
                    for a, b in bosluk
                ],
            )
        )
        gun += dt.timedelta(days=1)
    return gunler


@router.post("/dongu-uygula", response_model=VardiyaDonguSonuc)
async def dongu_uygula(
    body: VardiyaDonguUygulaIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaDonguSonuc:
    """(P247 §1) Donguyu kisilere/ekibe ata — onizleme + suresiz uretim.

    `kalip-uygula` ile AYNI sozlesme: `kuru=true` hicbir sey yazmaz ve ayni
    hesabi doner; cakisma varsa ve `cakisanlari_atla=false` ise HICBIR SEY
    yazilmaz; yazilan her satir ayni `parti_id`yi tasir ve
    `/parti/{id}/geri-al` satirlari VE atamalari birlikte geri alir.
    """
    kalip = (
        await db.execute(select(VardiyaKalibi).where(VardiyaKalibi.id == body.kalip_id))
    ).scalar_one_or_none()
    if kalip is None:
        raise APIError(422, "validation_error", "vardiya_kalibi_bulunamadi")
    dilimler, adimlar = _dongu_tanimi(kalip)

    kisiler = {
        k.id: k
        for k in (
            await db.execute(select(AppUser).where(AppUser.id.in_(body.kisiler)))
        ).scalars().all()
    }
    if set(body.kisiler) - set(kisiler) or any(not k.is_active for k in kisiler.values()):
        raise APIError(422, "validation_error", "personel_bulunamadi")
    for k in kisiler.values():
        _hedef_gorunur(user, k.role)

    bugun = await tesis_bugunu(db, user.tenant_id)
    # GECMISE UZUN URETIM YOK: bir aydan eski bir baslangic, gecmisi
    # "planlanmis" gosterip mesai hesabini bozardi.
    if body.baslangic < bugun - dt.timedelta(days=31):
        raise APIError(422, "validation_error", "vardiya_aralik_cok_uzun")
    son = max(bugun, body.baslangic) + dt.timedelta(days=DONGU_UFUK_GUN - 1)

    # AYNI KISIYE IKI ETKIN DONGU OLMAZ: iki dongu ayni kisiye ayni
    # geceyi iki kez yazmaya calisir ve beat her gece "cakisma" uretirdi.
    # Once eskisi sonlandirilir (acik eylem, sessiz devir degil).
    cakisan_atama = (
        await db.execute(
            select(VardiyaDonguAtama.id).where(
                VardiyaDonguAtama.user_id.in_(body.kisiler),
                VardiyaDonguAtama.iptal_at.is_(None),
                (VardiyaDonguAtama.bitis.is_(None))
                | (VardiyaDonguAtama.bitis >= body.baslangic),
            ).limit(1)
        )
    ).first()
    if cakisan_atama is not None:
        raise APIError(409, "conflict", "vardiya_dongu_zaten_var")

    ofsetler = body.ofsetler or [i * body.kaydirma for i in range(len(body.kisiler))]
    planlar: list[tuple[uuid.UUID, dt.date, list]] = []
    uyarilar: set[str] = set()
    for kisi_id, ofset in zip(body.kisiler, ofsetler):
        referans = body.baslangic + dt.timedelta(days=ofset)
        satirlar, u = await _dongu_plani(
            db, dilimler=dilimler, adimlar=adimlar, kisi_id=kisi_id,
            referans=referans, bas=body.baslangic, son=son,
        )
        uyarilar |= u
        planlar.append((kisi_id, referans, satirlar))

    cikti = [
        VardiyaKalipGunDilim(
            tarih=g, dilim=d.ad, baslangic=d.baslangic, bitis=d.bitis,
            user_id=kisi_id, ad=kisiler[kisi_id].ad, durum=durum,
        )
        for kisi_id, _, satirlar in planlar
        for g, d, durum in satirlar
    ]
    say = lambda durum: sum(1 for r in cikti if r.durum == durum)  # noqa: E731
    cakisan = say("cakisma")
    eklenecek = say("eklenecek")
    kapsama = await _kapsama(
        db, user, {k.role for k in kisiler.values()}, body.baslangic, son,
        [
            vardiya_araligi(g, d.baslangic, d.bitis)
            for _, _, satirlar in planlar
            for g, d, durum in satirlar
            if durum == "eklenecek"
        ],
    )
    ortak = dict(
        baslangic=body.baslangic, bitis=son, eklenecek=eklenecek, cakisan=cakisan,
        zaten_var=say("zaten_var"), izinli=say("izinli"), kapsama=kapsama,
        ofsetler={str(k): o for k, o in zip(body.kisiler, ofsetler)},
        uyarilar=sorted(uyarilar),
    )
    if body.kuru or (cakisan and not body.cakisanlari_atla):
        return VardiyaDonguSonuc(uygulandi=False, satirlar=cikti, **ortak)

    parti_id = uuid.uuid4()
    molalar = [m.model_dump(mode="json") for m in (body.molalar or [])]
    for kisi_id, referans, satirlar in planlar:
        atama = VardiyaDonguAtama(
            tenant_id=user.tenant_id, kalip_id=kalip.id, user_id=kisi_id,
            referans=referans, baslangic=body.baslangic, uretildi_kadar=son,
            parti_id=parti_id, molalar=molalar, not_metni=body.not_metni,
            olusturan_user_id=user.id,
        )
        _atlanan_ekle(atama, satirlar)
        db.add(atama)
        await db.flush()
        for g, d, durum in satirlar:
            if durum == "eklenecek":
                db.add(_plan_satiri(
                    tenant_id=user.tenant_id, gun=g, dilim=d, kisi_id=kisi_id,
                    parti_id=parti_id, atama_id=atama.id, molalar=molalar,
                    not_metni=body.not_metni,
                ))
    await db.flush()
    for r in cikti:
        if r.durum == "eklenecek":
            r.durum = "eklendi"
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=None,
        meta={
            "islem": "dongu_uygula", "parti_id": str(parti_id),
            "kalip_id": str(kalip.id), "kisi": len(body.kisiler),
            "baslangic": body.baslangic.isoformat(), "bitis": son.isoformat(),
            "ofsetler": ofsetler, "eklenen": eklenecek, "cakisan": cakisan,
        },
    )
    return VardiyaDonguSonuc(
        uygulandi=True, parti_id=parti_id, eklenen=eklenecek, satirlar=cikti,
        **ortak,
    )


def _atama_durumu(a: VardiyaDonguAtama, bugun: dt.date) -> str:
    if a.iptal_at is not None:
        return "geri_alindi"
    if a.bitis is not None and a.bitis < bugun:
        return "sonlandi"
    return "aktif"


@router.get("/dongu-atamalari", response_model=VardiyaDonguAtamaListResponse)
async def dongu_atamalari(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> VardiyaDonguAtamaListResponse:
    """(P247 §1) Etkin ve sonlanmis dongu atamalari (geri alinanlar HARIC).

    Okuma sahaya da acik (kalip okumasi gibi): "bir sonraki gecem ne
    zaman" sorusu sahanin sorusudur. Rol suzgeci `_atama_kosulu`.
    """
    bugun = await tesis_bugunu(db, user.tenant_id)
    kosul = list(_atama_kosulu(user))
    if user.role in ("security", "tesis_gorevlisi"):
        # SAHA YALNIZ KENDI DONGUSUNU gorur — ekip arkadasinin izin/atlama
        # kaydi onun isi degil.
        kosul.append(VardiyaDonguAtama.user_id == user.id)
    satirlar = (
        await db.execute(
            select(VardiyaDonguAtama, AppUser.ad, VardiyaKalibi.ad)
            .join(AppUser, AppUser.id == VardiyaDonguAtama.user_id)
            .outerjoin(VardiyaKalibi, VardiyaKalibi.id == VardiyaDonguAtama.kalip_id)
            .where(VardiyaDonguAtama.iptal_at.is_(None), *kosul)
            .order_by(VardiyaDonguAtama.created_at.desc(), AppUser.ad)
        )
    ).all()
    return VardiyaDonguAtamaListResponse(
        ufuk_gun=DONGU_UFUK_GUN,
        items=[
            VardiyaDonguAtamaOut(
                id=a.id, kalip_id=a.kalip_id, kalip_ad=kalip_ad, user_id=a.user_id,
                ad=ad, referans=a.referans, baslangic=a.baslangic, bitis=a.bitis,
                uretildi_kadar=a.uretildi_kadar, parti_id=a.parti_id,
                durum=_atama_durumu(a, bugun), atlanan=list(a.atlanan or []),
            )
            for a, ad, kalip_ad in satirlar
        ],
    )


@router.post(
    "/dongu-atamalari/{atama_id}/sonlandir",
    response_model=VardiyaDonguSonlandirSonuc,
)
async def dongu_sonlandir(
    atama_id: uuid.UUID,
    body: VardiyaDonguSonlandirIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaDonguSonlandirSonuc:
    """(P247 §1) Bir kisinin dongusunu `tarih`ten itibaren bitir.

    Ekibin partisini geri almaktan FARKLI: kisi ayrildi/baska ekibe gecti,
    otekilerin dongusu surer. Yalniz BU atamanin `tarih` ve sonrasindaki
    planli satirlari iptal edilir (SILINMEZ — P203 kurali).
    """
    atama = (
        await db.execute(
            select(VardiyaDonguAtama).where(
                VardiyaDonguAtama.id == atama_id,
                VardiyaDonguAtama.iptal_at.is_(None),
                *_atama_kosulu(user),
            )
        )
    ).scalar_one_or_none()
    if atama is None:
        raise APIError(404, "not_found", "vardiya_dongu_atamasi_bulunamadi")
    # Baslangictan once bitirmek anlamsiz: en erken baslangic gunu (dongu
    # hic calismamis olur).
    tarih = max(body.tarih, atama.baslangic)
    bitis = tarih - dt.timedelta(days=1)
    if atama.bitis is not None and atama.bitis < bitis:
        bitis = atama.bitis  # daha once erken bitirilmis; uzatma bu uc degil
    atama.bitis = bitis
    atama.updated_at = func.now()
    satirlar = (
        await db.execute(
            select(VardiyaPlani).where(
                VardiyaPlani.dongu_atama_id == atama.id,
                VardiyaPlani.durum == "planli",
                VardiyaPlani.tarih > bitis,
            )
        )
    ).scalars().all()
    for p in satirlar:
        p.durum = "iptal"
        p.updated_at = func.now()
    await db.flush()
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_dongu_atama",
        resource_id=atama.id,
        meta={"islem": "dongu_sonlandir", "bitis": bitis.isoformat(),
              "iptal_edilen": len(satirlar)},
    )
    return VardiyaDonguSonlandirSonuc(
        id=atama.id, bitis=bitis, iptal_edilen=len(satirlar)
    )


async def dongu_ufkunu_doldur(
    db: AsyncSession, tenant_id: uuid.UUID, bugun: dt.date | None = None
) -> dict:
    """(P247 §1) BEAT: tesisin etkin atamalarinin kayan ufkunu doldur.

    Filigranin (`uretildi_kadar`) GERISINE DONMEZ — elle degistirilen,
    iptal edilen ya da izin yuzunden bos kalan gun yeniden yazilmaz.
    Cakisan/izinli gun SESSIZCE kaybolmaz: atamanin `atlanan` listesine
    yazilir (dongu listesinde gorunur) ve onizlemedeki kapsama boslugu
    olarak zaten isaretlidir.

    Satir kilidi (`FOR UPDATE SKIP LOCKED`): ayni anda kosan iki beat ya da
    beat + atama istegi ayni gunu iki kez uretmesin.
    """
    gun = bugun or await tesis_bugunu(db, tenant_id)
    ufuk = gun + dt.timedelta(days=DONGU_UFUK_GUN - 1)
    atamalar = (
        await db.execute(
            select(VardiyaDonguAtama)
            .where(
                VardiyaDonguAtama.iptal_at.is_(None),
                VardiyaDonguAtama.kalip_id.is_not(None),
                (VardiyaDonguAtama.uretildi_kadar.is_(None))
                | (VardiyaDonguAtama.uretildi_kadar < ufuk),
                (VardiyaDonguAtama.bitis.is_(None))
                | (VardiyaDonguAtama.uretildi_kadar.is_(None))
                | (VardiyaDonguAtama.uretildi_kadar < VardiyaDonguAtama.bitis),
            )
            .with_for_update(skip_locked=True)
        )
    ).scalars().all()
    ozet = {"atama": 0, "eklenen": 0, "atlanan": 0}
    for atama in atamalar:
        kisi = (
            await db.execute(select(AppUser).where(AppUser.id == atama.user_id))
        ).scalar_one_or_none()
        if kisi is None or not kisi.is_active:
            continue  # pasif hesaba nobet yazilmaz; atama yerinde kalir
        kalip = (
            await db.execute(
                select(VardiyaKalibi).where(VardiyaKalibi.id == atama.kalip_id)
            )
        ).scalar_one_or_none()
        if kalip is None or kalip.adimlar is None:
            continue
        dilimler, adimlar = _dongu_tanimi(kalip)
        bas = (
            atama.uretildi_kadar + dt.timedelta(days=1)
            if atama.uretildi_kadar is not None
            else atama.baslangic
        )
        bas = max(bas, atama.baslangic)
        son = min(ufuk, atama.bitis) if atama.bitis is not None else ufuk
        if bas > son:
            continue
        satirlar, _ = await _dongu_plani(
            db, dilimler=dilimler, adimlar=adimlar, kisi_id=atama.user_id,
            referans=atama.referans, bas=bas, son=son,
        )
        for g, d, durum in satirlar:
            if durum == "eklenecek":
                db.add(_plan_satiri(
                    tenant_id=tenant_id, gun=g, dilim=d, kisi_id=atama.user_id,
                    parti_id=atama.parti_id, atama_id=atama.id,
                    molalar=atama.molalar, not_metni=atama.not_metni,
                ))
                ozet["eklenen"] += 1
            elif durum in ("izinli", "cakisma"):
                ozet["atlanan"] += 1
        _atlanan_ekle(atama, satirlar)
        atama.uretildi_kadar = son
        atama.updated_at = func.now()
        ozet["atama"] += 1
        await db.flush()
    return ozet


@router.patch("/{plan_id}", response_model=VardiyaPlanOut)
async def guncelle(
    plan_id: uuid.UUID,
    body: VardiyaGuncelleIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaPlanOut:
    """(§2.3) Blogun saatini/gununu degistir — DENETIME YAZILIR.

    =======================================================================
    (P232) "YALNIZ BU GUNU" / "TUM SERIYI"
    =======================================================================
    `kapsam="seri"` ayni `parti_id`yi tasiyan TUM satirlari gunceller.

    TARIH SERIDE DEGISTIRILEMEZ ve bu kural sert: serideki her satirin
    KENDI tarihi var; hepsini tek bir tarihe cekmek, otuz gunluk bir
    plani tek gune YIGMAK olurdu — kullanicinin "saati duzeltiyorum"
    derken kaybedecegi bir sey. 422 ile reddedilir.

    PARTISI OLMAYAN satirda `seri` ANLAMSIZDIR (tekil ekleme): sessizce
    "tek" gibi davranmak, kullaniciya yaptigini sandigi seyi YAPMAMIS
    olmak olurdu. Acikca reddedilir.
    """
    plan = await _plan_getir(db, user, plan_id)
    shift = (
        None
        if plan.shift_id is None
        else (
            await db.execute(select(Shift).where(Shift.id == plan.shift_id))
        ).scalar_one_or_none()
    )
    onceki = plan_araligi(plan, shift)

    if body.kapsam == "seri":
        if body.tarih is not None:
            raise APIError(422, "validation_error", "vardiya_seride_tarih_degismez")
        if plan.parti_id is None:
            raise APIError(422, "validation_error", "vardiya_seri_yok")
        if plan.dongu_atama_id is not None:
            # (P247 §1) DONGU SATIRINDA "TUM SERI" YOK: dongu partisi EKIBIN
            # tum gece ve gunduzlerini tasir; hepsini tek saate cekmek
            # dongunun kendisini silmek olurdu — ve beat ertesi gece yeni
            # gunleri kalibin ESKI saatiyle uretmeye devam ederdi. Tek gun
            # duzenlenir; kalip degisecekse atama sonlandirilip yeniden
            # atanir.
            raise APIError(422, "validation_error", "vardiya_dongu_seri_desteklenmez")

    yeni_tarih = body.tarih or plan.tarih
    yeni_bas = body.baslangic_saat or onceki[0].time()
    yeni_son = body.bitis_saat or onceki[1].time()
    aralik = vardiya_araligi(yeni_tarih, yeni_bas, yeni_son)
    # KENDI SATIRI HARIC: aksi hâlde her duzenleme "bu kisi ayni saatte
    # baska bir vardiyada" derdi — P203'te ayni tuzaga bir kez
    # dusulmustu (bkz. `ata`).
    uyarilar = await _cakisma_denetle(
        db, user_id=plan.user_id, tarih=yeni_tarih, aralik=aralik,
        haric_id=plan.id,
    )

    plan.tarih = yeni_tarih
    # SAATLER SATIRA YAZILIR: sablonlu bir satirin saati degistiginde
    # SABLON DEGISMEZ. Sablonu guncellemek, o vardiyadaki HERKESIN
    # saatini sessizce degistirmek olurdu.
    plan.baslangic_saat = yeni_bas
    plan.bitis_saat = yeni_son
    if body.not_metni is not None:
        plan.not_metni = body.not_metni
    # (P241 §2) `updated_at` ELLE YAZILIR: sutunda `onupdate` YOK ve
    # "yayinlanmis satir degisti mi" sorusu tam da bu damgadan
    # okunuyor. Yazilmasaydi yayin sayaci degisiklikleri GORMEZDI —
    # yani yonetici duzeltir, personel eski hali gorurdu.
    plan.updated_at = func.now()

    # (P232) TUM SERI: ayni partideki DIGER satirlar da guncellenir.
    #
    # YALNIZ SAAT VE NOT tasinir — tarih yukarida zaten reddedildi.
    # Cakisma denetimi satir satir YAPILMAZ ve bu bilincli: seri
    # duzenleme "bu vardiyanin saati degisti" demek ve her satir icin
    # ayri bir 409 uretmek, kullaniciyi otuz kez ayni karari vermeye
    # zorlardi. Cakisan satirlar `uyarilar`da doner.
    seri_guncellenen = 0
    if body.kapsam == "seri":
        digerleri = (
            await db.execute(
                select(VardiyaPlani).where(
                    VardiyaPlani.parti_id == plan.parti_id,
                    VardiyaPlani.id != plan.id,
                    VardiyaPlani.durum == "planli",
                    *_plan_kosulu(user),
                )
            )
        ).scalars().all()
        for d in digerleri:
            if body.baslangic_saat is not None:
                d.baslangic_saat = body.baslangic_saat
            if body.bitis_saat is not None:
                d.bitis_saat = body.bitis_saat
            if body.not_metni is not None:
                d.not_metni = body.not_metni
            d.updated_at = func.now()
            seri_guncellenen += 1
    await db.flush()
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=plan.id,
        meta={
            "islem": "guncelle",
            "onceki": f"{onceki[0].isoformat()}/{onceki[1].isoformat()}",
            "yeni": f"{aralik[0].isoformat()}/{aralik[1].isoformat()}",
            # KAPSAM DENETIME YAZILIR: "otuz vardiyam neden degisti"
            # sorusunun yaniti burada aranir.
            "kapsam": body.kapsam,
            "seri_guncellenen": seri_guncellenen,
        },
    )
    await db.refresh(plan)
    return VardiyaPlanOut(
        id=plan.id, shift_id=plan.shift_id, tarih=plan.tarih,
        user_id=plan.user_id, durum=plan.durum, not_metni=plan.not_metni,
        yayinlandi_at=plan.yayinlandi_at, molalar=list(plan.molalar or []),
        vardiya_rolu=plan.vardiya_rolu, blok_id=plan.blok_id, alan=plan.alan,
        uyarilar=uyarilar,
    )


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
            # (E2E 2026-09) OUTER JOIN + SATIRIN KENDI SAATI (`plan_araligi`).
            # INNER JOIN sablonsuz satirlari (hizli ekle, kalip, Excel —
            # sahadaki cogunluk) karttan dusuruyordu; sablonlu satirda da
            # satirin kendi saati degil sablon saati kullaniliyordu.
            # TASLAK GOREVDE SAYILMAZ: personele henuz yayinlanmamis bir
            # plan "su an gorevde" olamaz (P241 §2.4).
            select(VardiyaPlani, Shift, AppUser.ad, AppUser.role)
            .outerjoin(Shift, Shift.id == VardiyaPlani.shift_id)
            .join(AppUser, AppUser.id == VardiyaPlani.user_id)
            .where(
                VardiyaPlani.tarih.in_(tarihler),
                VardiyaPlani.durum == "planli",
                VardiyaPlani.yayinlandi_at.is_not(None),
            )
        )
    ).all()

    gorevde: list[VardiyaKisiOut] = []
    sirada: list[VardiyaKisiOut] = []
    sonraki_bas: dt.datetime | None = None
    aktif_slot: VardiyaSlotOut | None = None
    sonraki_slot: VardiyaSlotOut | None = None

    def _slot(plan, shift, bas: dt.datetime, son: dt.datetime) -> VardiyaSlotOut:
        return VardiyaSlotOut(
            shift_id=shift.id if shift else None,
            shift_ad=(shift.ad if shift else None) or plan.vardiya_rolu or "",
            baslangic_saat=bas.time(), bitis_saat=son.time(),
            kisiler=[], bos=False,
        )

    for plan, shift, ad, rol in satirlar:
        try:
            bas, son = plan_araligi(plan, shift)
        except ValueError:
            continue  # saati cozulemeyen satir (goc 0096 CHECK engelliyor)
        kisi = VardiyaKisiOut(
            plan_id=plan.id, user_id=plan.user_id, ad=ad, rol=rol
        )
        if bas <= simdi_yerel < son:
            gorevde.append(kisi)
            if aktif_slot is None:
                aktif_slot = _slot(plan, shift, bas, son)
        elif bas > simdi_yerel:
            # EN YAKIN gelecek vardiya: "bir sonraki" tek bir vardiyadir,
            # butun gelecek atamalar degil.
            if sonraki_bas is None or bas < sonraki_bas:
                sonraki_bas = bas
                sirada = [kisi]
                sonraki_slot = _slot(plan, shift, bas, son)
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


# =========================================================================== #
# (P241 §2) YAYIN — TASLAK / YAYINLANDI
# =========================================================================== #
#
# ===========================================================================
# BU BUGUNKU DAVRANISI DEGISTIRIYOR — OLCULDU VE BILINCLI
# ===========================================================================
# BUGUNE KADAR: yonetici bir vardiya ekler eklemez personel onu gorurdu.
# Yani yarim kalmis bir plan (once ekle, sonra duzelt) SAHAYA ANINDA
# yansiyordu ve gorevli, bir saat sonra degisecek bir vardiyayi gorup
# ona gore program yapabiliyordu.
#
# BUNDAN SONRA: yeni satirlar TASLAK acilir, personel gormez; yonetici
# "Yayinla" deyince gorunur ve bildirim gider.
#
# MEVCUT SATIRLAR YAYINLANMIS SAYILDI (goc 0145): aksi halde goc
# calistigi anda sahadaki herkesin plani ekrandan kaybolurdu.
#
# YAYINLANMIS SATIRIN DEGISIKLIGI: satir personelden GIZLENMEZ (eski
# hali kaybolmasin), ama "yayin bekliyor" olarak isaretlenir ve sayaca
# girer. Gizlemek, "vardiyam kayboldu" telefonlarini uretirdi.
#
# MESAI HESABI ETKILENMEZ: `routers/mesai.py` `durum='planli'` okur ve
# taslak da bir plandir — yoneticinin yaptigi is, yayinlanmamis olsa da
# maliyet ongorusudur. Bunu degistirmek P214'un kapsamiydi.


async def _yayin_kosullari(user: AppUser, baslangic: dt.date, son: dt.date):
    return [
        VardiyaPlani.tarih >= baslangic,
        VardiyaPlani.tarih <= son,
        VardiyaPlani.durum == "planli",
        *_plan_kosulu(user),
    ]


@router.get("/yayin-ozeti", response_model=VardiyaYayinOzet)
async def yayin_ozeti(
    baslangic: dt.date = Query(...),
    gun: int = Query(7, ge=1, le=AZAMI_GUN),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaYayinOzet:
    """Yayinla dugmesindeki SAYI — kac satir yayinlanmayi bekliyor."""
    son = baslangic + dt.timedelta(days=gun - 1)
    satirlar = (
        await db.execute(
            select(VardiyaPlani.yayinlandi_at, VardiyaPlani.updated_at)
            .where(*await _yayin_kosullari(user, baslangic, son))
        )
    ).all()
    taslak = sum(1 for y, _ in satirlar if y is None)
    degisen = sum(
        1 for y, u in satirlar if y is not None and u is not None and u > y
    )
    return VardiyaYayinOzet(
        bekleyen=taslak + degisen, taslak=taslak, degisen=degisen
    )


@router.post("/yayinla", response_model=VardiyaYayinSonuc)
async def yayinla(
    baslangic: dt.date = Query(...),
    gun: int = Query(7, ge=1, le=AZAMI_GUN),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaYayinSonuc:
    """Donemdeki taslak ve degismis satirlari YAYINLA + personele bildir."""
    son = baslangic + dt.timedelta(days=gun - 1)
    satirlar = (
        await db.execute(
            select(VardiyaPlani).where(*await _yayin_kosullari(user, baslangic, son))
        )
    ).scalars().all()
    an = dt.datetime.now(dt.timezone.utc)
    yayinlanan = 0
    # KISI BASINA: kac vardiya ve HANGI TARIH ARALIGI. Toplam sayiyi
    # herkese ayni gondermek ("18 vardiya yayinlandi") kisiye kendi
    # planiyla ilgisiz bir sayi vermek olurdu.
    kisiler: dict[uuid.UUID, dict] = {}
    for plan in satirlar:
        bekliyor = plan.yayinlandi_at is None or (
            plan.updated_at is not None and plan.updated_at > plan.yayinlandi_at
        )
        if not bekliyor:
            continue
        plan.yayinlandi_at = an
        yayinlanan += 1
        kayit = kisiler.setdefault(
            plan.user_id, {"adet": 0, "ilk": plan.tarih, "son": plan.tarih}
        )
        kayit["adet"] += 1
        kayit["ilk"] = min(kayit["ilk"], plan.tarih)
        kayit["son"] = max(kayit["son"], plan.tarih)
    await db.flush()

    bildirilen = 0
    for uid, kayit in kisiler.items():
        if await _yayin_bildir(db, user, uid, kayit, an):
            bildirilen += 1

    if yayinlanan:
        await audit_user(
            db, user, Action.VARDIYA_YAYIN, resource_type="vardiya_plani",
            resource_id=None,
            meta={
                "baslangic": baslangic.isoformat(), "gun": gun,
                "yayinlanan": yayinlanan, "kisi": len(kisiler),
                "bildirilen": bildirilen,
            },
        )
    return VardiyaYayinSonuc(yayinlanan=yayinlanan, bildirilen_kisi=bildirilen)


# =========================================================================== #
# (P241 §2e) YAYIN BILDIRIMI
# =========================================================================== #
#
# ===========================================================================
# BILDIRIM OLMADAN TASLAK/YAYIN AYRIMI ISLEVSIZ
# ===========================================================================
# Ayrimin amaci personelin plandan HABERDAR OLMASI. Yonetici "Yayinla"
# deyip kimse gormezse, ayrim yalnizca bir gecikme katmani olurdu.
#
# ===========================================================================
# BILDIRIM YORGUNLUGU: GUNLUK OZET DEGIL, PATLAMA BIRLESTIRME
# ===========================================================================
# Istek sordu: "her yayinlamada mi, gunde bir mi?"
#
# GUNDE BIR OZET REDDEDILDI: yayin ELLE yapilan bir eylemdir ve bilgi
# ZAMANA DUYARLIDIR — "yarin 08:00 nobetin var" haberini aksama
# ertelemek, ozelligin varlik sebebini gotururdu. (Bakim hatirlatmasi
# farkliydi: orada tarih gun cozunurluklu ve bekleyebilir.)
#
# AMA HER YAYINLAMADA KOSULSUZ GONDERMEK DE YANLIS: yonetici plani
# duzenlerken bes dakikada uc kez "Yayinla"ya basabilir ve ayni kisiye
# uc bildirim gider.
#
# COZUM — PATLAMA BIRLESTIRME: ayni kisinin AYNI TIPTEKI OKUNMAMIS
# bildirimi son `YAYIN_BIRLESTIRME_DK` dakika icinde yazilmissa YENI
# SATIR ACILMAZ; var olan satir GUNCELLENIR (sayi toplanir, tarih
# araligi genisler) ve IKINCI PUSH GONDERILMEZ.
#
# NEDEN "OKUNMAMIS" SARTI: okunmus bir bildirimi degistirmek, kisinin
# gordugu metni arkasindan degistirmek olurdu. Okunmussa yeni satir
# acilir — cunku kisi artik ilkini "islemis" sayilir.
#
# BILGI KAYBI YOK: birlestirme sayilari TOPLAR ve araligi GENISLETIR.

#: Ayni kisiye pes pese yayin bildirimi gonderme penceresi (dakika).
YAYIN_BIRLESTIRME_DK = 15


async def _yayin_bildir(
    db: AsyncSession,
    user: AppUser,
    hedef_id: uuid.UUID,
    kayit: dict,
    an: dt.datetime,
) -> bool:
    """Bir kisiye yayin bildirimi yaz/birlestir. Donus: PUSH gitti mi."""
    aralik = (
        kayit["ilk"].isoformat()
        if kayit["ilk"] == kayit["son"]
        else f"{kayit['ilk'].isoformat()} — {kayit['son'].isoformat()}"
    )
    veri = {"n": str(kayit["adet"]), "aralik": aralik}

    esik = an - dt.timedelta(minutes=YAYIN_BIRLESTIRME_DK)
    onceki = (
        await db.execute(
            select(Notification)
            .where(
                Notification.user_id == hedef_id,
                Notification.tip == "vardiya_yayinlandi",
                Notification.okundu.is_(False),
                Notification.silindi_at.is_(None),
                Notification.created_at >= esik,
            )
            .order_by(Notification.created_at.desc())
            .limit(1)
        )
    ).scalars().first()

    if onceki is not None:
        # BIRLESTIR: sayi toplanir, aralik genisler.
        eski = dict(onceki.mesaj_veri or {})
        try:
            toplam = int(eski.get("n", 0)) + kayit["adet"]
        except (TypeError, ValueError):
            toplam = kayit["adet"]
        eski_aralik = str(eski.get("aralik") or "")
        genis = aralik
        if eski_aralik:
            parcalar = sorted(
                {p.strip() for p in eski_aralik.split("—")}
                | {kayit["ilk"].isoformat(), kayit["son"].isoformat()}
            )
            genis = (
                parcalar[0]
                if len(parcalar) == 1
                else f"{parcalar[0]} — {parcalar[-1]}"
            )
        yeni_veri = {"n": str(toplam), "aralik": genis}
        onceki.mesaj_veri = yeni_veri
        onceki.mesaj = push_govdesi("vardiya_yayinlandi", "tr", yeni_veri)
        await db.flush()
        return False

    sakin_bildirimi_yaz(
        db,
        tenant_id=user.tenant_id,
        tip="vardiya_yayinlandi",
        user_ids=(hedef_id,),
        veri=veri,
    )
    await db.flush()
    # PUSH KISIYE: rol uzerinden gonderilseydi TUM guvenlik ekibi,
    # plani degismeyenler dahil, ayni haberi alirdi.
    dispatch_external(
        "vardiya_yayinlandi",
        tenant_id=user.tenant_id,
        target_user_ids=(hedef_id,),
        params=veri,
        data={"tip": "vardiya_yayinlandi"},
    )
    return True


@router.get("/mola-onerisi", response_model=VardiyaMolaOneriOut)
async def mola_onerisi(
    baslangic_saat: dt.time = Query(...),
    bitis_saat: dt.time = Query(...),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> VardiyaMolaOneriOut:
    """(4857 md. 68) Vardiya suresine gore ONERILEN ara dinlenme.

    SUNUCUDA: kanunun kademelerini web ve mobilde ayri ayri yazmak,
    birinin guncellenip otekinin eskimesi demekti — ve yanlis oneri,
    yoneticinin hukuki dayanagini bozar.
    """
    bas, biter = vardiya_araligi(dt.date(2000, 1, 1), baslangic_saat, bitis_saat)
    sure = saat_farki(bas, biter)
    return VardiyaMolaOneriOut(
        sure_saat=round(sure, 2), onerilen_dakika=yasal_mola_dakika(sure)
    )


@router.post("/haftadan-kopyala", response_model=VardiyaHaftaKopyalaSonuc)
async def haftadan_kopyala(
    body: VardiyaHaftaKopyalaIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaHaftaKopyalaSonuc:
    """Gecen haftanin planini bu haftaya kopyala.

    =======================================================================
    SESSIZ ATLAMA YOK (P205 kurali)
    =======================================================================
    Kopyalanamayan her satirin SEBEBI yanitta doner: cakisma, izin,
    zaten var. "37 satirdan 31'i kopyalandi" deyip gerisini yutmak,
    eksigi ancak sahada fark ettirirdi.

    =======================================================================
    KOPYA TASLAK GELIR
    =======================================================================
    Kopyalanan satirlar `yayinlandi_at=NULL` acilir: yonetici once
    bakar, duzeltir, sonra yayinlar. Kaynak satir yayinlanmis olsa bile
    — kopya BASKA BIR HAFTANIN plani ve onun da gozden gecirilmesi
    gerekir.
    """
    kaynak_gunler = [body.kaynak_baslangic + dt.timedelta(days=i) for i in range(7)]
    kaynak_son = kaynak_gunler[-1]
    kaydirma = (body.hedef_baslangic - body.kaynak_baslangic).days
    if kaydirma == 0:
        raise APIError(422, "validation_error", "vardiya_kopya_ayni_hafta")

    satirlar = (
        await db.execute(
            select(VardiyaPlani, AppUser.role)
            .join(AppUser, AppUser.id == VardiyaPlani.user_id)
            .where(
                VardiyaPlani.tarih >= body.kaynak_baslangic,
                VardiyaPlani.tarih <= kaynak_son,
                VardiyaPlani.durum == "planli",
                *_rol_kosulu(user),
            )
            .order_by(VardiyaPlani.tarih)
        )
    ).all()

    if body.hedefi_temizle:
        # YIKICI ve bu yuzden VARSAYILAN DEGIL: hedefteki satirlar
        # SILINMEZ, `iptal` isaretlenir (P203 kurali: silinen satirin
        # denetim kaydi neyin degistigini gosteremez).
        hedef_son = body.hedef_baslangic + dt.timedelta(days=6)
        mevcutlar = (
            await db.execute(
                select(VardiyaPlani).where(
                    VardiyaPlani.tarih >= body.hedef_baslangic,
                    VardiyaPlani.tarih <= hedef_son,
                    VardiyaPlani.durum == "planli",
                    *_plan_kosulu(user),
                )
            )
        ).scalars().all()
        for m in mevcutlar:
            m.durum = "iptal"
        await db.flush()

    gun_sayaci: dict[dt.date, VardiyaKopyaGunOut] = {}
    sebepler: set[str] = set()
    eklenen = atlanan = 0
    for plan, hedef_rol in satirlar:
        yeni_tarih = plan.tarih + dt.timedelta(days=kaydirma)
        sayac = gun_sayaci.setdefault(
            yeni_tarih, VardiyaKopyaGunOut(tarih=yeni_tarih, eklenen=0, atlanan=0)
        )
        shift = None
        if plan.shift_id is not None:
            shift = (
                await db.execute(select(Shift).where(Shift.id == plan.shift_id))
            ).scalar_one_or_none()
        bas, biter = plan_araligi(plan, shift)
        aralik = vardiya_araligi(
            yeni_tarih, bas.time(), biter.time()
        )
        try:
            await _izin_denetle(db, plan.user_id, yeni_tarih)
        except APIError:
            atlanan += 1
            sayac.atlanan += 1
            sebepler.add("izin")
            continue
        try:
            await _cakisma_denetle(
                db, user_id=plan.user_id, tarih=yeni_tarih, aralik=aralik
            )
        except APIError:
            atlanan += 1
            sayac.atlanan += 1
            sebepler.add("cakisma")
            continue
        db.add(
            VardiyaPlani(
                tenant_id=user.tenant_id,
                shift_id=plan.shift_id,
                tarih=yeni_tarih,
                user_id=plan.user_id,
                baslangic_saat=plan.baslangic_saat,
                bitis_saat=plan.bitis_saat,
                not_metni=plan.not_metni,
                molalar=list(plan.molalar or []),
                vardiya_rolu=plan.vardiya_rolu,
                blok_id=plan.blok_id,
                alan=plan.alan,
            )
        )
        await db.flush()
        eklenen += 1
        sayac.eklenen += 1

    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=None,
        meta={
            "islem": "haftadan_kopyala",
            "kaynak": body.kaynak_baslangic.isoformat(),
            "hedef": body.hedef_baslangic.isoformat(),
            "eklenen": eklenen, "atlanan": atlanan,
            "hedefi_temizle": body.hedefi_temizle,
        },
    )
    return VardiyaHaftaKopyalaSonuc(
        uygulandi=True,
        eklenen=eklenen,
        atlanan=atlanan,
        gunler=sorted(gun_sayaci.values(), key=lambda g: g.tarih),
        sebepler=sorted(sebepler),
    )


# =========================================================================== #
# (P241 §2) EXCEL — DISA / ICE AKTARIM
# =========================================================================== #
#
# ===========================================================================
# DONGU KAPALI OLMALI: indirdigini geri yukleyebilmelisin
# ===========================================================================
# Disa aktarilan dosyanin kolonlari ile ornek sablonunkiler ve ice
# aktarimin bekledikleri AYNI listeden (`vardiya_excel.KOLONLAR`)
# uretiliyor. Ayri ayri yazilsalardi kullanici kendi indirdigi dosyayi
# geri yukleyemezdi — ve bunu ancak deneyince anlardi.
#
# ===========================================================================
# SESSIZ ATLAMA YOK (P205 kurali burada da gecerli)
# ===========================================================================
# Her satir icin durum doner: `eklenecek` / `eklendi` / `hata` + SEBEP.
# "40 satirdan 33'u aktarildi" deyip gerisini yutmak, eksigi sahada
# fark ettirirdi.

_EXCEL_TIP = (
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
)


@router.get("/ornek-sablon")
async def ornek_sablon_indir(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> Response:
    """Bos sablon + BIR ornek satir (P234 deseni)."""
    from ..vardiya_excel import ornek_sablon

    return Response(
        content=ornek_sablon(),
        media_type=_EXCEL_TIP,
        headers={
            "Content-Disposition": 'attachment; filename="vardiya-sablon.xlsx"'
        },
    )


#: Plani YAZABILEN roller (moda gore amir/yonetici) — disa aktarimda
#: taslak ve e-posta yalniz onlara.
_PLANLAYAN_ROLLER: frozenset[str] = _YAZAR.izinli_roller  # type: ignore[attr-defined]


@router.get("/disa-aktar", dependencies=[Depends(DISA_AKTARIM_SINIRI)])
async def disa_aktar(
    baslangic: dt.date = Query(...),
    gun: int = Query(7, ge=1, le=AZAMI_GUN),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
) -> Response:
    """Donemin planini XLSX olarak indir."""
    from ..vardiya_excel import plan_disa_aktar

    son = baslangic + dt.timedelta(days=gun - 1)
    planlayan = user.role in _PLANLAYAN_ROLLER
    satirlar = (
        await db.execute(
            select(VardiyaPlani, Shift, AppUser.ad, AppUser.email, BuildingBlock.ad)
            .outerjoin(Shift, Shift.id == VardiyaPlani.shift_id)
            .join(AppUser, AppUser.id == VardiyaPlani.user_id)
            .outerjoin(BuildingBlock, BuildingBlock.id == VardiyaPlani.blok_id)
            .where(
                VardiyaPlani.tarih >= baslangic,
                VardiyaPlani.tarih <= son,
                VardiyaPlani.durum == "planli",
                *_rol_kosulu(user),
                # (E2E 2026-09) PLANLAMAYAN ROL TASLAGI GORMEZ — cizelgeyle
                # AYNI kural. Onceden guvenlik/tesis gorevlisi dosyadan
                # yayinlanmamis plani okuyabiliyordu.
                *([] if planlayan else [VardiyaPlani.yayinlandi_at.is_not(None)]),
            )
            .order_by(VardiyaPlani.tarih, AppUser.ad)
        )
    ).all()
    tenant_ad = (
        await db.execute(select(Tenant.ad).where(Tenant.id == user.tenant_id))
    ).scalar_one_or_none() or ""
    kayitlar = []
    for plan, shift, ad, eposta, blok_ad in satirlar:
        bas, biter = plan_araligi(plan, shift)
        kayitlar.append(
            {
                "tarih": plan.tarih.isoformat(),
                # E-posta ICE AKTARIMIN anahtaridir — yalniz plani yazan
                # rol icin anlamli. Personele ekip arkadaslarinin
                # adreslerini dagitmak KVKK acisindan gereksizdi.
                "eposta": (eposta or "") if planlayan else "",
                "ad": ad,
                "baslangic_saat": bas.strftime("%H:%M"),
                "bitis_saat": biter.strftime("%H:%M"),
                "mola_dakika": mola_dakika(plan.molalar) or "",
                "vardiya_rolu": plan.vardiya_rolu or "",
                "alan": blok_ad or plan.alan or "",
                "not": plan.not_metni or "",
            }
        )
    return Response(
        content=plan_disa_aktar(kayitlar, tenant_ad),
        media_type=_EXCEL_TIP,
        headers={
            "Content-Disposition": (
                f'attachment; filename="vardiya-{baslangic.isoformat()}.xlsx"'
            )
        },
    )


@router.post("/ice-aktar", response_model=VardiyaIceAktarimSonuc)
async def ice_aktar(
    body: VardiyaIceAktarimIstek,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZAR),
) -> VardiyaIceAktarimSonuc:
    """Excel'den plan yukle — ONIZLEME varsayilan.

    `yalniz_dogrula=true` (varsayilan) HICBIR SEY YAZMAZ: yanlis bir
    dosyayi yuzlerce satir boyunca uygulamak, geri almasi pahali bir
    hatadir.
    """
    from ..vardiya_excel import saat_coz, tarih_coz

    # Personel BIR KEZ okunur: satir basina sorgu, 2000 satirlik bir
    # dosyada 2000 gidis-donus demekti.
    personel = {
        (e or "").lower(): (uid, ad, rol)
        for uid, ad, e, rol in (
            await db.execute(
                select(AppUser.id, AppUser.ad, AppUser.email, AppUser.role).where(
                    AppUser.is_active.is_(True)
                )
            )
        ).all()
    }

    sonuclar: list[VardiyaIceAktarimSatirSonuc] = []
    yazilacak: list[dict] = []
    for satir in body.satirlar:
        d = {k: (v or "").strip() for k, v in satir.degerler.items()}
        tarih = tarih_coz(d.get("tarih", ""))
        bas = saat_coz(d.get("baslangic_saat", ""))
        bit = saat_coz(d.get("bitis_saat", ""))
        kisi = personel.get(d.get("eposta", "").lower())

        def _hata(kimlik: str) -> None:
            sonuclar.append(
                VardiyaIceAktarimSatirSonuc(
                    satir_no=satir.satir_no, durum="hata",
                    mesaj=hata_metni(kimlik, "tr"), tarih=tarih,
                    kisi_ad=kisi[1] if kisi else None,
                )
            )

        if tarih is None:
            _hata("vardiya_ice_tarih_gecersiz")
            continue
        if kisi is None:
            _hata("vardiya_ice_personel_yok")
            continue
        if bas is None or bit is None:
            _hata("vardiya_ice_saat_gecersiz")
            continue
        try:
            _hedef_gorunur(user, kisi[2])
        except APIError:
            _hata("vardiya_yalniz_kendi_ekibin")
            continue
        try:
            await _izin_denetle(db, kisi[0], tarih)
        except APIError:
            _hata("vardiya_izinli_gun")
            continue
        aralik = vardiya_araligi(tarih, bas, bit)
        try:
            await _cakisma_denetle(db, user_id=kisi[0], tarih=tarih, aralik=aralik)
        except APIError:
            _hata("vardiya_cakisiyor")
            continue

        try:
            dk = int(d.get("mola_dakika") or 0)
        except ValueError:
            dk = 0
        yazilacak.append(
            {
                "tarih": tarih, "user_id": kisi[0], "bas": bas, "bit": bit,
                "mola": dk, "rol": d.get("vardiya_rolu") or None,
                "alan": d.get("alan") or None, "not": d.get("not") or None,
                "satir_no": satir.satir_no, "ad": kisi[1],
            }
        )
        sonuclar.append(
            VardiyaIceAktarimSatirSonuc(
                satir_no=satir.satir_no, durum="eklenecek", tarih=tarih,
                kisi_ad=kisi[1],
            )
        )

    hatali = sum(1 for s in sonuclar if s.durum == "hata")
    if body.yalniz_dogrula:
        return VardiyaIceAktarimSonuc(
            uygulandi=False, toplam=len(body.satirlar),
            basarili=len(yazilacak), hatali=hatali, satirlar=sonuclar,
        )

    parti_id = uuid.uuid4()  # (E2E 2026-09) ice aktarim da geri alinabilir
    for y in yazilacak:
        db.add(
            VardiyaPlani(
                tenant_id=user.tenant_id,
                shift_id=None,
                tarih=y["tarih"],
                user_id=y["user_id"],
                parti_id=parti_id,
                baslangic_saat=y["bas"],
                bitis_saat=y["bit"],
                molalar=[{"tur": "yasal", "dakika": y["mola"]}] if y["mola"] else [],
                vardiya_rolu=y["rol"],
                alan=y["alan"],
                not_metni=y["not"],
            )
        )
        await db.flush()
    for s in sonuclar:
        if s.durum == "eklenecek":
            s.durum = "eklendi"
    await audit_user(
        db, user, Action.VARDIYA_PLAN_UPDATE, resource_type="vardiya_plani",
        resource_id=None,
        meta={"islem": "ice_aktar", "eklenen": len(yazilacak), "hatali": hatali},
    )
    return VardiyaIceAktarimSonuc(
        uygulandi=True, toplam=len(body.satirlar), basarili=len(yazilacak),
        hatali=hatali, satirlar=sonuclar,
        parti_id=parti_id if yazilacak else None,
    )
