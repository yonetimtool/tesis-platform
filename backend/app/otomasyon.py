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
from .finans import tarih_metni, tl_metni
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
from .borclandirma import Bag, hedef_sec
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


def onceki_donem(donem: str) -> str:
    yil, ay = int(donem[:4]), int(donem[5:7])
    return f"{yil - 1}-12" if ay == 1 else f"{yil}-{ay - 1:02d}"


def sonraki_donem(donem: str) -> str:
    yil, ay = int(donem[:4]), int(donem[5:7])
    return f"{yil + 1}-01" if ay == 12 else f"{yil}-{ay + 1:02d}"


def islenecek_donem(plan: AidatPlani, bugun: date) -> str | None:
    """Bu kosumda islenecek DONEM — yoksa `None`.

    ===================================================================
    GECMIS DONEM TELAFISI
    ===================================================================
    Gorev bir gun kosmazsa (bakim, kesinti, kuyruk tikanikligi) o ayin
    tahakkuku SESSIZCE KAYBOLURDU: ertesi ay `bugun.day` yeni ayin
    tahakkuk gununden kucuk olur ve gecmis ay bir daha hic bakilmaz.
    Oysa bu bolumun tum amaci "yonetici unutursa borc olusmasin"i
    ortadan kaldirmakti; sistemin unutmasi da ayni sonucu verirdi.

    Bu yuzden atlanmis donem TELAFI EDILIR — ama KOSUM BASINA BIR TANE.
    Uc aylik bir kesintiden sonra butun tahakkuklari tek seferde yazmak,
    yoneticiye aciklanamayan bir borc yiginini bir sabah gostermek
    olurdu; gunluk kosum uc gunde toparlar ve her adim gunlukte gorunur.

    YENI PLAN GECMISI BORCLANDIRMAZ (`son_donem is None`): bir plan
    tanimlamak, gecmis aylarin aidatini bir anda yazmak anlamina
    gelmemeli.
    """
    su_an = donem_metni(bugun)
    if plan.son_donem is None:
        return su_an if bugun.day >= plan.tahakkuk_gunu else None
    if plan.son_donem >= su_an:
        return None
    sonraki = sonraki_donem(plan.son_donem)
    if sonraki == su_an:
        return su_an if bugun.day >= plan.tahakkuk_gunu else None
    return sonraki


def tahakkuk_tarihi(donem: str, gun: int) -> date:
    """Donemin tahakkuk gunu. Telafi edilen donemde de DOGRU tarih.

    `date.today()` kullanmak, gecmis bir donemin tahakkukunu bugunun
    tarihiyle yazmak olurdu; o zaman "Mart tahakkuku" Haziran'da
    gorunur ve donemsel raporlar yanlis cikardi.
    """
    yil, ay = int(donem[:4]), int(donem[5:7])
    return date(yil, ay, min(gun, calendar.monthrange(yil, ay)[1]))


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

    su_an = donem_metni(bugun)
    yonetim = await _yonetim_idleri(db)
    yazilan = 0
    onizlenen = 0

    for plan in planlar:
        tanim = await _plan_tanimi(db, plan)
        # ONIZLEME her zaman ICINDE BULUNULAN ay icindir; tahakkuk ise
        # telafi ediliyorsa GECMIS bir ay olabilir.
        onizleme_vadesi = tahakkuk_tarihi(su_an, plan.tahakkuk_gunu) + timedelta(
            days=plan.vade_gun
        )
        istek = _plan_istegi(plan, su_an, onizleme_vadesi)

        # --- ONIZLEME: tahakkuktan `onizleme_gun` gun once ---------------- #
        onizleme_gunu = plan.tahakkuk_gunu - plan.onizleme_gun
        if (
            plan.onizleme_gun > 0
            and onizleme_gunu >= 1
            and bugun.day >= onizleme_gunu
            and bugun.day < plan.tahakkuk_gunu
            and plan.onizleme_donem != su_an
            and plan.son_donem != su_an
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
                    db, tenant_id=tenant_id, tur="aidat_onizleme", donem=su_an,
                    adet=len(islenecek),
                    tutar_kurus=sum(s.tutar_kurus or 0 for s in islenecek),
                    sonuc={"plan": str(plan.id)},
                )
                onizlenen += 1
            plan.onizleme_donem = su_an

        # --- TAHAKKUK ----------------------------------------------------- #
        #
        # Hangi donem islenecek: bu ay ya da ATLANMIS bir gecmis ay
        # (kosum basina bir tane; gerekce `islenecek_donem`de).
        donem = islenecek_donem(plan, bugun)
        if donem is None:
            continue
        if plan.ertelenen_donem == donem:
            # ERTELEME PLANI KAPATMAZ: yalniz bu donemi atlar ve damga
            # yazilir ki gorev her kosumda tekrar bakmasin.
            plan.son_donem = donem
            await _gunluk_yaz(
                db, tenant_id=tenant_id, tur="aidat_tahakkuk", donem=donem,
                adet=0, sonuc={"plan": str(plan.id), "durum": "ertelendi"},
            )
            continue

        tarih = tahakkuk_tarihi(donem, plan.tahakkuk_gunu)
        vade = tarih + timedelta(days=plan.vade_gun)
        if plan.son_donem is None:
            # (E2E 2026-09, FINANS-18) AY ORTASINDA ACILAN PLANIN ILK DONEMI
            # vadesi GECMIS dogmaz: 23 Eylul'de acilan plan (gun 1, vade 10)
            # Eylul'u "son odeme 11.09" ile yaziyordu — borc dogdugu anda 12
            # gun gecikmis ve faiz aciksa ilk kosumda faize giriyordu.
            vade = max(vade, bugun + timedelta(days=plan.vade_gun))
        satirlar = await toplu_plan(db, _plan_istegi(plan, donem, vade), tanim)
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
                son_odeme_tarihi=vade, tarih=tarih,
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
async def hatirlatma_hedefleri(
    db: AsyncSession,
    *,
    vade_oncesi_gun: int,
    kademeler: list[int],
    bugun: date,
) -> tuple[str, dict[uuid.UUID, tuple[int, date]], dict[uuid.UUID, set[str]], int]:
    """BUGUN kime hatirlatma gider — YAZMA YOK.

    (P250 §9) Gonderim ile onizleme ("bu kural bugun calissaydi ...")
    AYNI hesabi kullanir: iki ayri sorgu bir gun ayrisir ve onizleme
    gercekte gitmeyecek bir sayiyi gosterirdi.

    Doner: (durum, kisi -> (kalan kurus, en erken vade), kisi -> donemler,
    kurala uyan alicisi olmayan borc sayisi). `durum` "var" degilse
    gonderilecek kimse yoktur.
    """
    # Hangi gunler hatirlatilir: vade oncesi tek gun + vade sonrasi
    # kademeler. Kume olarak tutulur; ayni gune iki kural denk gelirse
    # sakine iki bildirim gitmemeli.
    hedef_gunler: set[int] = set()
    if vade_oncesi_gun:
        hedef_gunler.add(-int(vade_oncesi_gun))
    hedef_gunler.update(int(k) for k in (kademeler or []) if k >= 0)

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
        return "hedef_yok", {}, {}, 0

    odenen = await defter.tahakkuk_odenen(db, [b.id for b in ilgili])
    acik = [b for b in ilgili if b.tutar_kurus - odenen.get(b.id, 0) > 0]
    if not acik:
        return "acik_borc_yok", {}, {}, 0

    # (P250 §7) KIM ODER KURALI — daireye yazilmis (hedefsiz) borc.
    #
    # ONCEDEN dairedeki AKTIF HERKESE gidiyordu: malikin bakim borcu
    # kiraciya, kiracinin isletme borcu oturmayan malike de hatirlatiliyordu.
    # Artik borcun tanimindaki kural (P218: malik / oturan oncelikli)
    # hatirlatma aninda da uygulanir — tahakkukta hangi kural kisiyi
    # secerdiyse hatirlatma da ONA gider. Kurala uyan kimse yoksa daireye
    # hatirlatma GITMEZ (yanlis kisiye borc hatirlatmak, hic gondermemekten
    # kotudur) ve sayisi gunluge yazilir.
    hedefsiz = {b.unit_id for b in acik if b.hedef_user_id is None}
    daire_baglari: dict[uuid.UUID, list[Bag]] = {}
    if hedefsiz:
        rows = (
            await db.execute(
                select(
                    UnitResident.unit_id, UnitResident.user_id,
                    UnitResident.rol_tipi, UnitResident.oturuyor,
                ).where(
                    UnitResident.unit_id.in_(hedefsiz),
                    UnitResident.bitis.is_(None),
                )
            )
        ).all()
        for unit_id, user_id, rol_tipi, oturuyor in rows:
            daire_baglari.setdefault(unit_id, []).append(
                Bag(user_id=str(user_id), rol_tipi=rol_tipi, oturuyor=bool(oturuyor))
            )
    tanim_idleri = {b.gelir_gider_tanim_id for b in acik if b.gelir_gider_tanim_id}
    kurallar: dict[uuid.UUID, str | None] = dict(
        (
            await db.execute(
                select(GelirGiderTanim.id, GelirGiderTanim.hedef_kurali).where(
                    GelirGiderTanim.id.in_(tanim_idleri)
                )
            )
        ).all()
    ) if tanim_idleri else {}

    # KISI BASINA TEK BILDIRIM: uc ayri borcu olan sakine uc push gitmez.
    kisi: dict[uuid.UUID, tuple[int, date]] = {}
    kisi_donemleri: dict[uuid.UUID, set[str]] = {}
    alicisiz = 0
    for borc in acik:
        kalan = borc.tutar_kurus - odenen.get(borc.id, 0)
        if borc.hedef_user_id:
            aliciler = [borc.hedef_user_id]
        else:
            secilen = hedef_sec(
                daire_baglari.get(borc.unit_id, []),
                kurallar.get(borc.gelir_gider_tanim_id) if borc.gelir_gider_tanim_id else None,
            )
            aliciler = [uuid.UUID(secilen)] if secilen else []
            if not aliciler:
                alicisiz += 1
        for user_id in aliciler:
            onceki = kisi.get(user_id)
            kisi[user_id] = (
                (onceki[0] if onceki else 0) + kalan,
                min(onceki[1], borc.son_odeme_tarihi) if onceki
                else borc.son_odeme_tarihi,
            )
            kisi_donemleri.setdefault(user_id, set()).add(borc.donem)

    return "var", kisi, kisi_donemleri, alicisiz


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

    durum, kisi, kisi_donemleri, alicisiz = await hatirlatma_hedefleri(
        db, vade_oncesi_gun=ayar.vade_oncesi_gun, kademeler=ayar.kademeler or [],
        bugun=bugun,
    )
    if durum != "var":
        ayar.son_calisma = bugun
        return {"gonderilen": 0, "durum": durum}

    for user_id, (kalan, vade) in kisi.items():
        # (E2E 2026-09, BILDIRIM-14) Turkce tutar ve gun.ay.yil tarih —
        # elle gonderilen hatirlatmayla (finans_gosterge) AYNI bicim.
        params = {"tutar": tl_metni(kalan), "vade": tarih_metni(vade)}
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
    # (P250 §7) E-POSTA — push'un yaninda, ayar aciksa.
    eposta = {"kuyruga": 0, "atlanan": 0}
    if getattr(ayar, "eposta", False) and kisi:
        eposta = await _hatirlatma_epostalari(
            db, tenant_id=tenant_id, kisi=kisi, donemler=kisi_donemleri,
        )
    ayar.son_calisma = bugun
    await _gunluk_yaz(
        db, tenant_id=tenant_id, tur="borc_hatirlatma",
        donem=donem_metni(bugun), adet=len(kisi),
        tutar_kurus=sum(k for k, _ in kisi.values()),
        sonuc={"eposta": eposta["kuyruga"], "eposta_atlanan": eposta["atlanan"],
               "alicisiz_daire": alicisiz},
    )
    return {"gonderilen": len(kisi), "durum": "gonderildi",
            "eposta": eposta["kuyruga"], "alicisiz": alicisiz}


#: (P250 §7) `mesaj_gonderim.tur` degeri.
AIDAT_HATIRLATMA_TUR = "aidat_hatirlatma"


async def _hatirlatma_epostalari(
    db: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    kisi: dict[uuid.UUID, tuple[int, date]],
    donemler: dict[uuid.UUID, set[str]],
) -> dict:
    """Borclu kisilere aidat hatirlatma e-postasi KUYRUGA yazar.

    KUYRUK: `mesaj_kuyruk` dakikada bir, e-postalar arasinda aralik
    birakarak gonderir (P250 §2) — yuz borclu bir gece gorevinde tek seferde
    saglayiciya yuklenmez. Teslim durumu (P234) gecmiste gorunur.

    TERCIHE UYAR: e-posta bildirimlerini kapatan kisiye GITMEZ. Aidat
    hatirlatmasi yasal bir tebligat DEGILDIR (KMK'daki ihtar ayri ve
    yazilidir); kisinin tercihini ezmenin gerekcesi yok. Push ve uygulama
    ici bildirim kendi tercihleriyle (bildirim_mobil) gitmeye devam eder.
    """
    from . import islem_epostasi
    from .aidat_hatirlatma_eposta import aidat_hatirlatma_eposta
    from .models import AppUser, Kasa, Tenant
    from .odeme_kodu import uret as kod_uret

    kisiler = (
        await db.execute(select(AppUser).where(AppUser.id.in_(list(kisi))))
    ).scalars().all()
    tenant = (await db.execute(select(Tenant).where(Tenant.id == tenant_id))).scalar_one()
    kasa = (
        await db.execute(
            select(Kasa)
            .where(Kasa.banka_mi.is_(True), Kasa.aktif.is_(True), Kasa.iban.is_not(None))
            .order_by(Kasa.kod, Kasa.id)
            .limit(1)
        )
    ).scalar_one_or_none()
    diller = await islem_epostasi.alici_dili(db, [k.id for k in kisiler], "tr")
    from .tesis_saati import tesis_bugun

    yil = (await tesis_bugun(db, tenant_id)).year
    kuyruga = atlanan = 0
    for k in kisiler:
        if islem_epostasi.gonderilemez_sebebi(k):
            atlanan += 1
            continue
        # Kodu olmayan sakine kod uretilir (tembel uretim, P193 §7).
        if not k.odeme_kodu and k.role == "resident":
            for _ in range(5):
                k.odeme_kodu = kod_uret()
                try:
                    async with db.begin_nested():
                        await db.flush()
                    break
                except IntegrityError:
                    k.odeme_kodu = None
        kalan, vade = kisi[k.id]
        konu, metin, html = aidat_hatirlatma_eposta(
            dil=diller[k.id], tesis_ad=tenant.ad, ad=k.ad,
            tutar=tl_metni(kalan), donemler=sorted(donemler.get(k.id, set())),
            vade=tarih_metni(vade), odeme_kodu=k.odeme_kodu,
            banka_adi=kasa.banka_adi if kasa else None,
            iban=kasa.iban if kasa else None, yil=yil,
        )
        islem_epostasi.kuyruga_al(
            db, tenant_id=tenant_id, kisi=k, tur=AIDAT_HATIRLATMA_TUR,
            konu=konu, metin=metin, html=html, gonderen_id=None,
        )
        kuyruga += 1
    await db.flush()
    return {"kuyruga": kuyruga, "atlanan": atlanan}


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
    islenen_giderler: list[str] = []
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
        islenen_giderler.append(str(gider.id))
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
            # (P250 §9) Kural basina "son calisma" icin.
            sonuc={"giderler": islenen_giderler},
        )
    return {"yazilan": yazilan, "toplam_kurus": toplam}


# --------------------------------------------------------------------------- #
#                  (P252) PERSONEL MAASLARI                                    #
# --------------------------------------------------------------------------- #
async def maas_otomasyonu(db: AsyncSession, tenant_id: uuid.UUID, bugun: date) -> dict:
    """Odeme gunu gelen maaslari gidere yazar; gunluk + DONEM basina ozet.

    Hesap ve idempotency `app/maas.py`de. Bildirim DONEM basina tek:
    "Ekim 2026 maaslari gidere yazildi: 4 personel, toplam 92.000 TL" —
    telafi kosumunda (birden cok ay) her ay ayri cumle.
    """
    from . import maas

    sonuc = await maas.maaslari_isle(db, tenant_id, bugun)
    if not sonuc.yazilan:
        return {"yazilan": 0, "toplam_kurus": 0}
    await _gunluk_yaz(
        db, tenant_id=tenant_id, tur="maas", donem=donem_metni(bugun),
        adet=sonuc.yazilan, tutar_kurus=sonuc.toplam_kurus,
        sonuc={
            "kartlar": sonuc.kartlar,
            "donemler": sonuc.donemler,
            "onay_bekleyen": sonuc.onay_bekleyen,
        },
    )
    yonetim = await _yonetim_idleri(db)
    for d, (adet, tutar) in sorted(sonuc.donemler.items()):
        params = {"donem": maas.donem_adi(d), "adet": adet, "tutar": _tl(tutar)}
        _bildir("maas_yazildi", tenant_id=tenant_id, aliciler=yonetim, params=params)
        sakin_bildirimi_yaz(
            db, tenant_id=tenant_id, tip="maas_yazildi", user_ids=yonetim, veri=params,
        )
    return {
        "yazilan": sonuc.yazilan,
        "toplam_kurus": sonuc.toplam_kurus,
        "onay_bekleyen": sonuc.onay_bekleyen,
        "donemler": sonuc.donemler,
    }


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
    # (P253 §E) Verilmediyse tesis basina dongude cozulur (tesisin gunu).
    gun = bugun
    ozet = {"tesis": 0, "tahakkuk": 0, "hatirlatma": 0, "gider": 0, "faiz": 0}
    for tenant_id in _tenant_idler():
        try:
            async with SessionLocal() as db:
                await db.execute(
                    text("SELECT set_config('app.current_tenant_id', :t, true)"),
                    {"t": str(tenant_id)},
                )
                # (P253 §E) Verilmediyse HER TESISIN kendi gunu: gorev 06:00
                # Istanbul'da kosar ama tesis baska saat diliminde olabilir.
                if bugun is None:
                    from .tesis_saati import tesis_bugun

                    gun = await tesis_bugun(db, tenant_id)
                plan = await aidat_planlari_isle(db, tenant_id, gun)
                hatirlatma = await borc_hatirlatmalari(db, tenant_id, gun)
                gider = await duzenli_giderleri_isle(db, tenant_id, gun)
                # (P252) Ayni gorev, ayri zamanlayici YOK.
                maas_ = await maas_otomasyonu(db, tenant_id, gun)
                faiz = await gecikme_faizi_otomatik(db, tenant_id, gun)
                await aylik_ozet(db, tenant_id, gun)
                await db.commit()
            ozet["tesis"] += 1
            ozet["tahakkuk"] += plan["tahakkuk"]
            ozet["hatirlatma"] += hatirlatma["gonderilen"]
            ozet["gider"] += gider["yazilan"]
            ozet["maas"] = ozet.get("maas", 0) + maas_["yazilan"]
            ozet["faiz"] += faiz["yazilan"]
        except Exception as exc:  # noqa: BLE001
            log.warning("[otomasyon] tesis %s atlandi: %s", tenant_id, exc)
    return ozet
