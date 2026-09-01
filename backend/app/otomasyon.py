"""(P192 §4) FINANS OTOMASYONU — yoneticinin her ay elle yaptigi isler.

===========================================================================
OLCULEN KUSUR
===========================================================================
`docs/finans-analiz.md`: `beat_schedule`da aidat gorevi YOKTU. Yonetici
tahakkuku her ay ELLE calistiriyordu; unutursa o ay borc olusmuyordu. Borc
hatirlatmasi hic yoktu. Duzenli giderler (kapici maasi, asansor bakimi)
her ay elle giriliyordu.

===========================================================================
UC ORTAK KURAL
===========================================================================
1. HER OTOMASYON ACILIP KAPATILABILIR (`aktif`). Bir hatayi durdurmanin
   tek yolu kaydi silmek olmamali.
2. HER OTOMASYON IZ BIRAKIR (`otomasyon_gunlugu`). Bir gorevin CALISTIGI
   ancak urettigi kayda bakilarak anlasilabilseydi, HICBIR SEY URETMEDIGI
   durum — ki asil merak edilen odur — gorunmez kalirdi.
3. HER OTOMASYON IDEMPOTENTTIR. Gorev gunde birden cok kez kosar
   (beat sikligi bir DAGITIM detayidir, is kurali degil); ikinci kosum
   ayni isi TEKRAR YAPMAMALI.

Idempotency her otomasyonda AYNI DESENLE saglanir: yapilan is bir DAMGA
birakir (`aidat_plani.son_donem`, `duzenli_gider.sonraki_tarih`,
`hatirlatma_ayari.son_calisma`) ve gorev damgaya bakar. Tarihe bakip
"bugun ayin 5'i mi" demek YETMEZDI: gorev gun icinde birden cok kez kosar.

===========================================================================
TENANT BAGLAMI
===========================================================================
Fonksiyonlar TEK TENANT icin calisir ve RLS baglami cagiran tarafindan
kurulur (`tum_tenantlar_icin`). Owner baglantisiyla butun tesisleri tek
sorguda islemek daha hizli olurdu ama RLS'i BYPASS ederdi — otomasyonun
bir tesisin verisini digerine yazma ihtimali, kazandigi hizdan pahalidir.
"""
from __future__ import annotations

import calendar
import logging
import uuid
from dataclasses import dataclass
from datetime import date, timedelta

import psycopg
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from . import defter, gecikme
from .akis_metinleri import _tl
from .belge_no import belge_no_ata
from .config import settings
from .crud_helpers import is_unique_violation
from .db import SessionLocal
from .models import (
    AidatPlani,
    AppUser,
    DuesAssessment,
    DuzenliGider,
    FinansalHareket,
    GelirGiderTanim,
    HatirlatmaAyari,
    OtomasyonGunlugu,
    TransparencyPublication,
    UnitResident,
)
from .sakin_bildirimi import sakin_bildirimi_yaz
from .schemas import TopluBorcIstek, TopluBorcSuzgec
from .toplu_tahakkuk import tahakkuk_yaz, toplu_plan

log = logging.getLogger(__name__)

#: Yonetim rolleri — otomasyon bildirimlerinin alicisi.
_YONETIM_ROLLERI = ("admin", "yonetici")

#: `gider_periyot` -> ay sayisi. Tekrar SAKLANIR, genisletilmez.
PERIYOT_AY = {"aylik": 1, "uc_aylik": 3, "alti_aylik": 6, "yillik": 12}


def donem_metni(gun: date) -> str:
    return f"{gun.year}-{gun.month:02d}"


def ay_ekle(gun: date, ay: int) -> date:
    """Tarihe ay ekle; ayin son gununu ASMA.

    31 Ocak + 1 ay = 28/29 Subat. `timedelta(days=30)` kullanmak, her
    tekrarda tarihi birkac gun kaydirir ve bir yil sonra gider "ayin 20'si"
    olmaktan cikardi.
    """
    toplam = (gun.year * 12 + gun.month - 1) + ay
    yil, ay_no = divmod(toplam, 12)
    ay_no += 1
    return date(yil, ay_no, min(gun.day, calendar.monthrange(yil, ay_no)[1]))


async def _yonetim_idleri(db: AsyncSession) -> list[uuid.UUID]:
    return list(
        (
            await db.execute(
                select(AppUser.id).where(
                    AppUser.role.in_(_YONETIM_ROLLERI),
                    AppUser.is_active.is_(True),
                )
            )
        ).scalars().all()
    )


async def _gunluk_yaz(
    db: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    tur: str,
    donem: str | None = None,
    adet: int = 0,
    tutar_kurus: int = 0,
    sonuc: dict | None = None,
) -> None:
    db.add(
        OtomasyonGunlugu(
            tenant_id=tenant_id, tur=tur, donem=donem, adet=adet,
            tutar_kurus=tutar_kurus, sonuc=sonuc or {},
        )
    )
    await db.flush()


def _bildir(
    tip: str,
    *,
    tenant_id: uuid.UUID,
    aliciler,
    params: dict,
    govde: str | None = None,
) -> None:
    """Push GONDER (kalici satiri cagiran yazar).

    Import ICERIDE: `scheduler.notify` Celery'ye baglidir ve modulu
    ic-halkaya tasimak, testlerin bu modulu iceri almasini kuyruk
    altyapisina bagimli kilardi.

    `govde` verilirse (yoneticinin yazdigi hatirlatma metni) sablonun
    yerine gecer ve CEVRILMEZ.
    """
    from .scheduler.notify import dispatch_external

    if not aliciler:
        return
    dispatch_external(
        tip,
        tenant_id=tenant_id,
        target_user_ids=tuple(aliciler),
        params=params,
        data={"tip": tip},
        govde=govde,
    )


# --------------------------------------------------------------------------- #
#                     4.1  OTOMATIK AYLIK TAHAKKUK                             #
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class PlanOzeti:
    plan_id: uuid.UUID
    donem: str
    daire: int
    toplam_kurus: int
    atlanan: int


def _plan_istegi(plan: AidatPlani, donem: str, vade: date) -> TopluBorcIstek:
    """Plani, ELLE toplu tahakkukun kullandigi govdeye cevirir.

    Ayni govde OLMAK ZORUNDA: otomatik ve elle tahakkuk ayni cekirdegi
    (`toplu_tahakkuk.toplu_plan`) cagirir. Ikinci bir yol yazmak, iki
    tahakkukun gunun birinde farkli davranmasi demekti.
    """
    return TopluBorcIstek(
        donem=donem,
        gelir_gider_tanim_id=plan.gelir_gider_tanim_id,
        suzgec=TopluBorcSuzgec(),
        tutar_kurus=plan.tutar_kurus,
        toplam_tutar_kurus=plan.toplam_tutar_kurus,
        dagitim=plan.dagitim,
        kalem_tipi=plan.kalem_tipi,
        son_odeme_tarihi=vade,
        tarih=None,
        aciklama=plan.aciklama,
        gecikme_uygula=True,
    )


async def _plan_tanimi(db: AsyncSession, plan: AidatPlani) -> GelirGiderTanim | None:
    if plan.gelir_gider_tanim_id is None:
        return None
    return (
        await db.execute(
            select(GelirGiderTanim).where(
                GelirGiderTanim.id == plan.gelir_gider_tanim_id
            )
        )
    ).scalar_one_or_none()


async def aidat_planlari_isle(
    db: AsyncSession, tenant_id: uuid.UUID, bugun: date
) -> dict:
    """Gunu gelen planlari isler + onizleme bildirimi gonderir.

    IKI IS, TEK GOREV: onizleme ile tahakkuk ayni plani okur. Ayri gorevler
    olsaydi biri planin degisen tutarini gorup digeri gormeyebilirdi.
    """
    planlar = (
        await db.execute(
            select(AidatPlani).where(AidatPlani.aktif.is_(True))
            .order_by(AidatPlani.ad)
        )
    ).scalars().all()
    if not planlar:
        return {"plan": 0, "tahakkuk": 0, "onizleme": 0}

    donem = donem_metni(bugun)
    yonetim = await _yonetim_idleri(db)
    yazilan = 0
    onizlenen = 0

    for plan in planlar:
        tanim = await _plan_tanimi(db, plan)
        vade = bugun + timedelta(days=plan.vade_gun)
        istek = _plan_istegi(plan, donem, vade)

        # --- ONIZLEME: tahakkuktan `onizleme_gun` gun once ---------------- #
        onizleme_gunu = plan.tahakkuk_gunu - plan.onizleme_gun
        if (
            plan.onizleme_gun > 0
            and onizleme_gunu >= 1
            and bugun.day >= onizleme_gunu
            and bugun.day < plan.tahakkuk_gunu
            and plan.onizleme_donem != donem
            and plan.son_donem != donem
        ):
            satirlar = await toplu_plan(db, istek, tanim)
            islenecek = [s for s in satirlar if s.tutar_kurus and not s.atlama_nedeni]
            if islenecek:
                params = {
                    "gun": str(plan.tahakkuk_gunu - bugun.day),
                    "daire": str(len(islenecek)),
                    "tutar": _tl(sum(s.tutar_kurus or 0 for s in islenecek)),
                }
                _bildir(
                    "aidat_onizleme", tenant_id=tenant_id, aliciler=yonetim,
                    params=params,
                )
                sakin_bildirimi_yaz(
                    db, tenant_id=tenant_id, tip="aidat_onizleme",
                    user_ids=yonetim, veri=params,
                )
                await _gunluk_yaz(
                    db, tenant_id=tenant_id, tur="aidat_onizleme", donem=donem,
                    adet=len(islenecek),
                    tutar_kurus=sum(s.tutar_kurus or 0 for s in islenecek),
                    sonuc={"plan": str(plan.id)},
                )
                onizlenen += 1
            plan.onizleme_donem = donem

        # --- TAHAKKUK ----------------------------------------------------- #
        if bugun.day < plan.tahakkuk_gunu:
            continue
        if plan.son_donem == donem:
            continue  # IDEMPOTENCY: bu donem zaten islendi
        if plan.ertelenen_donem == donem:
            # ERTELEME PLANI KAPATMAZ: yalniz bu donemi atlar ve damga
            # yazilir ki gorev her kosumda tekrar bakmasin.
            plan.son_donem = donem
            await _gunluk_yaz(
                db, tenant_id=tenant_id, tur="aidat_tahakkuk", donem=donem,
                adet=0, sonuc={"plan": str(plan.id), "durum": "ertelendi"},
            )
            continue

        satirlar = await toplu_plan(db, istek, tanim)
        kalemler: list[tuple[uuid.UUID, uuid.UUID | None, str, int]] = []
        atlanan = 0
        toplam = 0
        for satir in satirlar:
            if satir.atlama_nedeni is not None or not satir.tutar_kurus:
                atlanan += 1
                continue
            ok = await tahakkuk_yaz(
                db, None,
                unit_id=satir.unit_id, donem=donem,
                tutar_kurus=satir.tutar_kurus,
                tanim_id=plan.gelir_gider_tanim_id,
                hedef_user_id=satir.hedef_user_id,
                son_odeme_tarihi=vade, tarih=bugun,
                aciklama=plan.aciklama, gecikme_uygula=True,
                kaynak="toplu", kalem_tipi=plan.kalem_tipi,
                tenant_id=tenant_id,
            )
            if ok:
                yazilan += 1
                toplam += satir.tutar_kurus
                kalemler.append(
                    (satir.unit_id, satir.hedef_user_id, donem, satir.tutar_kurus)
                )
            else:
                atlanan += 1
        plan.son_donem = donem
        await _gunluk_yaz(
            db, tenant_id=tenant_id, tur="aidat_tahakkuk", donem=donem,
            adet=len(kalemler), tutar_kurus=toplam,
            sonuc={"plan": str(plan.id), "atlanan": atlanan},
        )
        if kalemler:
            from .sakin_bildirimi import aidat_bildir

            await aidat_bildir(db, tenant_id=tenant_id, kalemler=kalemler)

    return {"plan": len(planlar), "tahakkuk": yazilan, "onizleme": onizlenen}


# --------------------------------------------------------------------------- #
#                     4.2  OTOMATIK BORC HATIRLATMA                            #
# --------------------------------------------------------------------------- #
async def borc_hatirlatmalari(
    db: AsyncSession, tenant_id: uuid.UUID, bugun: date
) -> dict:
    """Vadesi yaklasan/gecen borclar icin hatirlatma gonderir.

    ODEYENE GITMEZ: aday kumesi "kalan > 0" olan borclardir; kalan,
    defterdeki tahsilat etkisinden hesaplanir (P192 §1'in tek tanimi).
    Tahakkuk listesinden gitmek, odemis sakini de rahatsiz ederdi.

    GUNDE BIR KEZ: `son_calisma` damgasi. Gorev gunde on kez kossa da
    sakinin telefonu on kez otmez.
    """
    ayar = (
        await db.execute(select(HatirlatmaAyari))
    ).scalar_one_or_none()
    if ayar is None or not ayar.aktif:
        return {"gonderilen": 0, "durum": "kapali"}
    if ayar.son_calisma == bugun:
        return {"gonderilen": 0, "durum": "bugun_calisti"}

    # Hangi gunler hatirlatilir: vade oncesi tek gun + vade sonrasi
    # kademeler. Kume olarak tutulur; ayni gune iki kural denk gelirse
    # sakine iki bildirim gitmemeli.
    hedef_gunler: set[int] = set()
    if ayar.vade_oncesi_gun:
        hedef_gunler.add(-int(ayar.vade_oncesi_gun))
    hedef_gunler.update(int(k) for k in (ayar.kademeler or []) if k >= 0)

    borclar = (
        await db.execute(
            select(DuesAssessment)
            .where(
                DuesAssessment.son_odeme_tarihi.isnot(None),
                *defter.gecerli_tahakkuk(),
            )
        )
    ).scalars().all()
    ilgili = [
        b for b in borclar
        if (bugun - b.son_odeme_tarihi).days in hedef_gunler
    ]
    if not ilgili:
        ayar.son_calisma = bugun
        return {"gonderilen": 0, "durum": "hedef_yok"}

    odenen = await defter.tahakkuk_odenen(db, [b.id for b in ilgili])
    acik = [b for b in ilgili if b.tutar_kurus - odenen.get(b.id, 0) > 0]
    if not acik:
        ayar.son_calisma = bugun
        return {"gonderilen": 0, "durum": "acik_borc_yok"}

    # Daireye yazilmis (hedefsiz) borclarin alicilari TEK sorguda.
    hedefsiz = {b.unit_id for b in acik if b.hedef_user_id is None}
    daire_sakinleri: dict[uuid.UUID, list[uuid.UUID]] = {}
    if hedefsiz:
        rows = (
            await db.execute(
                select(UnitResident.unit_id, UnitResident.user_id).where(
                    UnitResident.unit_id.in_(hedefsiz),
                    UnitResident.bitis.is_(None),
                )
            )
        ).all()
        for unit_id, user_id in rows:
            daire_sakinleri.setdefault(unit_id, []).append(user_id)

    # KISI BASINA TEK BILDIRIM: uc ayri borcu olan sakine uc push gitmez.
    kisi: dict[uuid.UUID, tuple[int, date]] = {}
    for borc in acik:
        kalan = borc.tutar_kurus - odenen.get(borc.id, 0)
        aliciler = (
            [borc.hedef_user_id] if borc.hedef_user_id
            else daire_sakinleri.get(borc.unit_id, [])
        )
        for user_id in aliciler:
            onceki = kisi.get(user_id)
            kisi[user_id] = (
                (onceki[0] if onceki else 0) + kalan,
                min(onceki[1], borc.son_odeme_tarihi) if onceki
                else borc.son_odeme_tarihi,
            )

    for user_id, (kalan, vade) in kisi.items():
        params = {"tutar": _tl(kalan), "vade": vade.isoformat()}
        # (P192 §4.2) YONETICININ METNI VARSA O GIDER. `{tutar}`/`{vade}`
        # alanlari doldurulur; bilinmeyen bir alan yazilmissa metin OLDUGU
        # GIBI gonderilir — yoneticinin cumlesini bir bicimlendirme hatasi
        # yuzunden hic gondermemek, en kotu sonuc olurdu.
        ozel = None
        if ayar.metin:
            try:
                ozel = ayar.metin.format(**params)
            except (KeyError, IndexError, ValueError):
                ozel = ayar.metin
        _bildir(
            "aidat_hatirlatma", tenant_id=tenant_id, aliciler=[user_id],
            params=params, govde=ozel,
        )
        sakin_bildirimi_yaz(
            db, tenant_id=tenant_id, tip="aidat_hatirlatma",
            user_ids=[user_id],
            # Kalici satirda da ozel metin TASINIR: in-app liste ile push
            # ayni cumleyi gostermeli.
            veri={**params, **({"metin": ozel} if ozel else {})},
        )
    ayar.son_calisma = bugun
    await _gunluk_yaz(
        db, tenant_id=tenant_id, tur="borc_hatirlatma",
        donem=donem_metni(bugun), adet=len(kisi),
        tutar_kurus=sum(k for k, _ in kisi.values()),
    )
    return {"gonderilen": len(kisi), "durum": "gonderildi"}


# --------------------------------------------------------------------------- #
#                        4.5  DUZENLI GIDERLER                                 #
# --------------------------------------------------------------------------- #
async def duzenli_giderleri_isle(
    db: AsyncSession, tenant_id: uuid.UUID, bugun: date
) -> dict:
    """Vadesi gelen tekrar eden giderleri deftere yazar.

    VARSAYILAN ONAY BEKLEYEN: otomatik "odendi" yazmak, sistemin kimseye
    sormadan kasadan para cikarmasi olurdu. `otomatik_onay=true` diyen
    yonetici bunu ACIKCA secmistir.

    IDEMPOTENCY `sonraki_tarih` damgasindadir: yazma basarili olunca tarih
    bir periyot ileri atilir. Gorev tekrar kossa da vadesi gelmis kayit
    kalmaz.
    """
    giderler = (
        await db.execute(
            select(DuzenliGider).where(
                DuzenliGider.aktif.is_(True),
                DuzenliGider.sonraki_tarih <= bugun,
            ).order_by(DuzenliGider.sonraki_tarih, DuzenliGider.id)
        )
    ).scalars().all()
    if not giderler:
        return {"yazilan": 0}

    yonetim = await _yonetim_idleri(db)
    yazilan = 0
    toplam = 0
    for gider in giderler:
        kasa_id = await defter.kasa_coz(db, tenant_id, gider.kasa_id)
        hareket = FinansalHareket(
            tenant_id=tenant_id,
            tip="gider",
            yon="cikis",
            tutar_kurus=gider.tutar_kurus,
            tarih=gider.sonraki_tarih,
            kasa_id=kasa_id,
            firma_id=gider.firma_id,
            gelir_gider_tanim_id=gider.gelir_gider_tanim_id,
            durum="odendi" if gider.otomatik_onay else "onay_bekliyor",
            aciklama=gider.aciklama or gider.ad,
            belge_no=await belge_no_ata(
                db, tenant_id, "gider", None, gider.sonraki_tarih
            ),
            # Ayni gider ayni vade icin IKINCI KEZ yazilamaz.
            idempotency_key=f"duzenli:{gider.id}:{gider.sonraki_tarih.isoformat()}",
            idem_satir=0,
        )
        try:
            async with db.begin_nested():
                db.add(hareket)
                await db.flush()
        except IntegrityError as exc:
            try:
                db.expunge(hareket)
            except Exception:  # noqa: BLE001
                pass
            if not is_unique_violation(exc):
                raise
            # Zaten yazilmis — damgayi yine de ilerlet ki gorev takilmasin.
            gider.sonraki_tarih = ay_ekle(
                gider.sonraki_tarih, PERIYOT_AY[gider.periyot]
            )
            continue

        yazilan += 1
        toplam += gider.tutar_kurus
        if not gider.otomatik_onay:
            params = {"ad": gider.ad, "tutar": _tl(gider.tutar_kurus)}
            _bildir(
                "gider_onay", tenant_id=tenant_id, aliciler=yonetim, params=params
            )
            sakin_bildirimi_yaz(
                db, tenant_id=tenant_id, tip="gider_onay",
                user_ids=yonetim, veri=params,
            )
        gider.sonraki_tarih = ay_ekle(
            gider.sonraki_tarih, PERIYOT_AY[gider.periyot]
        )

    if yazilan:
        await _gunluk_yaz(
            db, tenant_id=tenant_id, tur="duzenli_gider",
            donem=donem_metni(bugun), adet=yazilan, tutar_kurus=toplam,
        )
    return {"yazilan": yazilan, "toplam_kurus": toplam}


# --------------------------------------------------------------------------- #
#                        4.6  AYLIK OZET RAPORU                                #
# --------------------------------------------------------------------------- #
async def aylik_ozet(db: AsyncSession, tenant_id: uuid.UUID, bugun: date) -> dict:
    """Ay basinda yoneticiye ONCEKI AYIN ozeti.

    AYIN 1'INDE degil "1'inde ya da sonra ve bu donem gonderilmediyse":
    gorev bir gun hic kosmazsa (bakim, kesinti) ozet TAMAMEN kaybolurdu.
    Damga `otomasyon_gunlugu`ndadir — ayri bir sutun acmaya gerek yok.
    """
    onceki = date(bugun.year, bugun.month, 1) - timedelta(days=1)
    donem = donem_metni(onceki)
    zaten = (
        await db.execute(
            select(func.count()).select_from(OtomasyonGunlugu).where(
                OtomasyonGunlugu.tur == "aylik_ozet",
                OtomasyonGunlugu.donem == donem,
            )
        )
    ).scalar_one()
    if zaten:
        return {"gonderildi": 0, "durum": "zaten"}

    ilk, son = defter.donem_araligi(donem)
    tahsilat = await defter.tahsilat_toplami(db, baslangic=ilk, bitis=son)
    tahakkuk = await defter.tahakkuk_toplami(db, donem=donem)
    gider = await defter.gider_toplami(db, baslangic=ilk, bitis=son)
    oran = round(100 * tahsilat / tahakkuk) if tahakkuk else 0

    yonetim = await _yonetim_idleri(db)
    params = {
        "donem": donem,
        "tahsilat": _tl(tahsilat),
        "gider": _tl(gider),
        "oran": str(oran),
    }
    _bildir("aylik_ozet", tenant_id=tenant_id, aliciler=yonetim, params=params)
    sakin_bildirimi_yaz(
        db, tenant_id=tenant_id, tip="aylik_ozet", user_ids=yonetim, veri=params,
    )

    # --- SAKINLERE SEFFAFLIK OZETI ------------------------------------- #
    #
    # YALNIZ O AY YAYINLANMISSA. Otomasyonun kendi kendine yayinlamasi,
    # yoneticinin gozden gecirmedigi mali veriyi butun siteye acmak
    # olurdu — yayin bir KARARDIR ve yoneticinindir. Burada yapilan sey
    # yalnizca "yayinlanmis olani duyurmak".
    yayinlandi = (
        await db.execute(
            select(TransparencyPublication.yayin).where(
                TransparencyPublication.ay == donem
            )
        )
    ).scalar_one_or_none()
    sakinler: list[uuid.UUID] = []
    if yayinlandi:
        sakinler = list(
            (
                await db.execute(
                    select(AppUser.id).where(
                        AppUser.role == "resident", AppUser.is_active.is_(True)
                    )
                )
            ).scalars().all()
        )
        if sakinler:
            _bildir(
                "aylik_ozet", tenant_id=tenant_id, aliciler=sakinler,
                params=params,
            )
            sakin_bildirimi_yaz(
                db, tenant_id=tenant_id, tip="aylik_ozet",
                user_ids=sakinler, veri=params,
            )
    await _gunluk_yaz(
        db, tenant_id=tenant_id, tur="aylik_ozet", donem=donem,
        adet=len(yonetim) + len(sakinler), tutar_kurus=tahsilat,
        sonuc={
            "tahakkuk_kurus": tahakkuk, "gider_kurus": gider, "oran": oran,
            "yonetim": len(yonetim), "sakin": len(sakinler),
            "seffaflik_yayinda": bool(yayinlandi),
        },
    )
    return {
        "gonderildi": len(yonetim) + len(sakinler),
        "donem": donem,
        "sakin": len(sakinler),
    }


# --------------------------------------------------------------------------- #
#                     3.1  GECIKME FAIZI (otomatik)                            #
# --------------------------------------------------------------------------- #
async def gecikme_faizi_otomatik(
    db: AsyncSession, tenant_id: uuid.UUID, bugun: date
) -> dict:
    """Birikmis faizi AYDA BIR yazar.

    Gunluk yazmak, her gun kurus mertebesinde yeni bir borc kalemi acmak
    olurdu; faiz zaten TAM AY uzerinden hesaplanir (bkz.
    `borclandirma.gecikme_kurus`) ve ay icinde degismez.
    """
    donem = gecikme.faiz_donemi(bugun)
    zaten = (
        await db.execute(
            select(func.count()).select_from(OtomasyonGunlugu).where(
                OtomasyonGunlugu.tur == "gecikme_faizi",
                OtomasyonGunlugu.donem == donem,
            )
        )
    ).scalar_one()
    if zaten:
        return {"yazilan": 0, "durum": "zaten"}

    satirlar = [s for s in await gecikme.hesapla(db, bugun=bugun) if s.fark_kurus > 0]
    yazilan = 0
    toplam = 0
    for satir in satirlar:
        kaynak = (
            await db.execute(
                select(DuesAssessment).where(
                    DuesAssessment.id == satir.assessment_id
                )
            )
        ).scalar_one_or_none()
        if kaynak is None:
            continue
        obj = DuesAssessment(
            tenant_id=tenant_id,
            unit_id=satir.unit_id,
            donem=donem,
            tutar_kurus=satir.fark_kurus,
            kalem_tipi="faiz",
            kaynak_assessment_id=satir.assessment_id,
            hedef_user_id=kaynak.hedef_user_id,
            aciklama=f"Gecikme faizi ({satir.donem})",
            gecikme_uygula=False,
            kaynak="toplu",
            tarih=bugun,
        )
        try:
            async with db.begin_nested():
                db.add(obj)
                await db.flush()
        except IntegrityError as exc:
            try:
                db.expunge(obj)
            except Exception:  # noqa: BLE001
                pass
            if not is_unique_violation(exc):
                raise
            continue
        yazilan += 1
        toplam += satir.fark_kurus

    await _gunluk_yaz(
        db, tenant_id=tenant_id, tur="gecikme_faizi", donem=donem,
        adet=yazilan, tutar_kurus=toplam,
    )
    return {"yazilan": yazilan, "toplam_kurus": toplam}


# --------------------------------------------------------------------------- #
#                          BEAT GIRIS NOKTASI                                  #
# --------------------------------------------------------------------------- #
def _tenant_idler() -> list[uuid.UUID]:
    """Tesis listesi OWNER baglantisiyla (RLS bootstrap).

    `gurultu_kuyruk` ile ayni desen: sayim owner'la, IS her tesis icin
    app_rw + tenant baglami altinda.
    """
    with psycopg.connect(
        settings.owner_dsn, autocommit=True, connect_timeout=10
    ) as conn:
        return [r[0] for r in conn.execute("SELECT id FROM tenant").fetchall()]


async def tum_tenantlar_icin(bugun: date | None = None) -> dict:
    """Butun tesisler icin gunluk finans otomasyonlarini kosar.

    BIR TESISIN HATASI DIGERLERINI DUSURMEZ: her tesis kendi islemi ve
    kendi try/except'i icinde. Aksi halde tek bir bozuk plan, butun
    musterilerin tahakkukunu durdururdu.
    """
    gun = bugun or date.today()
    ozet = {"tesis": 0, "tahakkuk": 0, "hatirlatma": 0, "gider": 0, "faiz": 0}
    for tenant_id in _tenant_idler():
        try:
            async with SessionLocal() as db:
                await db.execute(
                    text("SELECT set_config('app.current_tenant_id', :t, true)"),
                    {"t": str(tenant_id)},
                )
                plan = await aidat_planlari_isle(db, tenant_id, gun)
                hatirlatma = await borc_hatirlatmalari(db, tenant_id, gun)
                gider = await duzenli_giderleri_isle(db, tenant_id, gun)
                faiz = await gecikme_faizi_otomatik(db, tenant_id, gun)
                await aylik_ozet(db, tenant_id, gun)
                await db.commit()
            ozet["tesis"] += 1
            ozet["tahakkuk"] += plan["tahakkuk"]
            ozet["hatirlatma"] += hatirlatma["gonderilen"]
            ozet["gider"] += gider["yazilan"]
            ozet["faiz"] += faiz["yazilan"]
        except Exception as exc:  # noqa: BLE001
            log.warning("[otomasyon] tesis %s atlandi: %s", tenant_id, exc)
    return ozet
