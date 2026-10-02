"""(P240 §1) PANIK BUTONU — tetikle, iptal et, gor, mudahale et, kapat.

===========================================================================
SATIR ONCE, BILDIRIM SONRA
===========================================================================
`POST /panik` alarm satirini HEMEN yazar (`durum='beklemede'`) ve
bildirimleri `IPTAL_PENCERESI_SN` saniye SONRAYA planlar. Iptal penceresi
icinde `POST /panik/{id}/iptal` gelirse durum `iptal` olur ve gecikmeli
gorev HICBIR SEY GONDERMEZ.

Ters sira (once gonder, sonra iptal) mumkun DEGIL: alicinin telefonunda
calmis bir alarm geri alinamaz.

===========================================================================
BROKER YOKSA DA ALARM GITMELI
===========================================================================
Gecikmeli gonderim Celery ile planlanir. Broker erisilemezse gonderim
SENKRON yapilir — iptal penceresi KAYBEDILIR ama alarm GIDER. Tersi
(broker yoksa alarm hic gitmesin) bir guvenlik ozelliginde kabul
edilemez; iptal penceresi bir KOLAYLIK, alarmin kendisi ise ISIN TA
KENDISIDIR.

===========================================================================
SUISTIMAL: REDDETME YOK, TEKRAR DUYURU VAR
===========================================================================
Ayni kisinin ayni tipte ACIK alarmi varken tekrar basmasi YENI alarm
uretmez; var olani yeniden duyurur. Gercek acil durumda ikinci kez basan
kisi "duyulmadi" diye dusunuyordur; istegi reddetmek tam o anda alarmi
susturmak olurdu.
"""
from __future__ import annotations

import datetime as dt
import uuid

from fastapi import APIRouter, Depends, Query, Request, Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import girdi_siniri as _G
from ..audit import Action, audit_user
from ..celery_app import celery_app
from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    PANIK_DURUM,
    AppUser,
    Checkpoint,
    PanikAlarm,
    PanikAlici,
    Unit,
    UnitResident,
)
from ..hata_metinleri import istek_dili
from ..panik import (
    ALICI_ROLLERI,
    IPTAL_PENCERESI_SN,
    LISTE_ROLLERI,
    TEKRAR_DUYURU_ARALIGI_SN,
    aski_aktif,
    tetikleyebilir_mi,
)
from ..panik_talimat import baslik as talimat_basligi
from ..panik_talimat import talimat as talimat_adimlari
from ..panik_talimat import toplu_mu
from ..schemas import (
    PanikAlarmOut,
    PanikDurumOut,
    PanikAliciOut,
    PanikAskiIn,
    PanikAskiOut,
    PanikKapat,
    PanikListResponse,
    PanikOzetOut,
    PanikOlustur,
    PageMetaOut,
)

router = APIRouter(prefix="/panik", tags=["panik"])

#: Tetikleme HERKESE acik degil ama rol kapisi TIP BASINA (`panik.py`);
#: buradaki kapi yalniz "oturum acmis ve sahada bir rol" filtresidir.
_TETIKLEYEN = require_role(
    "resident", "security", "guvenlik_amiri", "tesis_gorevlisi", "yonetici", "admin"
)
_OKUR = require_role(
    "resident", "security", "guvenlik_amiri", "tesis_gorevlisi", "yonetici", "admin"
)
_YONETIM = require_role("admin", "yonetici")


def _istek_dili(request: Request) -> str:
    """(P249 §1b) Talimat ve baslik ISTEGIN dilinde (hata metinleriyle ayni
    ayristirici)."""
    return istek_dili(request.headers.get("accept-language"))


def _simdi() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


async def _alicilari_bul(
    db: AsyncSession, tenant_id: uuid.UUID, tip: str, haric: uuid.UUID | None
) -> list[AppUser]:
    """Alarmi ALACAK kullanicilar.

    Tetikleyen KENDI alarminin alicisi DEGILDIR: kendi telefonunda calan
    alarm ona yeni bir bilgi vermez ve "kim gordu" olcusunu kirletirdi.
    """
    roller = ALICI_ROLLERI[tip]
    sorgu = select(AppUser).where(AppUser.is_active.is_(True), AppUser.role.in_(roller))
    kisiler = list((await db.execute(sorgu)).scalars().all())
    return [k for k in kisiler if k.id != haric]


#: (P247 §6) Alarmi basanin TELEFONUNU gorebilen roller.
_TELEFON_GORUR = frozenset({"admin", "yonetici", "security", "guvenlik_amiri"})


async def _govde(
    db: AsyncSession, alarm: PanikAlarm, izleyen: AppUser, dil: str = "tr"
) -> PanikAlarmOut:
    """Alarm -> yanit govdesi (adlar, daire, konum adi, sayaclar)."""
    out = PanikAlarmOut.model_validate(alarm)
    out.iptal_penceresi_sn = IPTAL_PENCERESI_SN
    # (P249 §1b) IKI DENEYIM + TEK KAYNAK METIN.
    toplu = toplu_mu(alarm.kategori)
    out.toplu = toplu
    # (P249 §2) TATBIKAT: baslik "TATBIKAT — ..." ile baslar (her dilde).
    out.tatbikat = alarm.tatbikat_id is not None
    out.baslik = talimat_basligi(alarm.kategori, dil, tatbikat=out.tatbikat)
    out.talimat = talimat_adimlari(alarm.kategori, dil)

    if alarm.olusturan_user_id:
        kisi = (
            await db.execute(
                select(AppUser).where(AppUser.id == alarm.olusturan_user_id)
            )
        ).scalar_one_or_none()
        if kisi is not None:
            out.olusturan_ad = kisi.ad
            # TELEFON ACIL DURUMDA GOSTERILIR ve bu, `/call-target`
            # kapisindan AYRI bir karardir: orada "gunluk iletisim" icin
            # riza araniyor; burada alarmi BASAN kisiye ULASMAK sozkonusu.
            # Alici kumesi zaten guvenlik+yonetim ile sinirli ve her
            # gosterim denetim kaydinda.
            #
            # (P247 §6) YALNIZ MUDAHALE EDEN ROLLER: P243 §5c ile bina geneli
            # kategoriler (deprem, yangin, gaz, tahliye) TUM SITEYE gidiyor;
            # sakin alicilar alarmi basan komsunun telefonunu goruyordu.
            if izleyen.role in _TELEFON_GORUR or izleyen.id == kisi.id:
                out.olusturan_telefon = kisi.telefon
        # (P249 §1b) YANLIS ALARM SAYACI YALNIZ MUDAHALE EDENE ve YALNIZ
        # YARDIM CAGRISINDA. Deprem uyarisinin altinda "yanlis alarm"
        # yazisi, insanlarin uyariyi ciddiye almamasina yol acar; sakin bu
        # bilgiyle yapacak bir sey de yoktur. Sayac bir GUVENLIK
        # baglamidir: "bu kisi bugun iki kez yanlislikla basti".
        if kisi is not None and not toplu and izleyen.role in _TELEFON_GORUR:
            out.son_24s_yanlis_alarm = int(
                (
                    await db.execute(
                        select(func.count())
                        .select_from(PanikAlarm)
                        .where(
                            PanikAlarm.olusturan_user_id == kisi.id,
                            # (P249 §2) TATBIKAT SAYACA GIRMEZ.
                            PanikAlarm.tatbikat_id.is_(None),
                            PanikAlarm.durum.in_(("iptal", "yanlis_alarm")),
                            PanikAlarm.created_at
                            >= _simdi() - dt.timedelta(hours=24),
                        )
                    )
                ).scalar_one()
            )

    if alarm.unit_id:
        birim = (
            await db.execute(select(Unit).where(Unit.id == alarm.unit_id))
        ).scalar_one_or_none()
        if birim is not None:
            out.daire_no = birim.no
            out.blok = birim.blok

    if alarm.checkpoint_id:
        nokta = (
            await db.execute(
                select(Checkpoint).where(Checkpoint.id == alarm.checkpoint_id)
            )
        ).scalar_one_or_none()
        if nokta is not None:
            out.checkpoint_ad = nokta.ad

    if alarm.gonderildi_at and alarm.mudahale_at:
        out.mudahale_suresi_sn = int(
            (alarm.mudahale_at - alarm.gonderildi_at).total_seconds()
        )

    satirlar = (
        await db.execute(
            select(PanikAlici, AppUser.ad, AppUser.role)
            .join(AppUser, AppUser.id == PanikAlici.user_id)
            .where(PanikAlici.alarm_id == alarm.id)
        )
    ).all()
    for a, _ad, _rol in satirlar:
        if a.user_id == izleyen.id:
            out.benim_yanitim = a.yanit
    # (P249 §1) ALICI LISTESI YALNIZ TAKIP EDENE (ve alarmi basana).
    #
    # OLCULEN SIZINTI: toplu uyari TUM SITEYE gidiyor ve yanit govdesi her
    # aliciya OTEKI ALICILARIN adlarini ve rollerini donduruyordu — deprem
    # alarmini acan bir sakin sitedeki herkesin adini goruyordu.
    if izleyen.role in LISTE_ROLLERI or izleyen.id == alarm.olusturan_user_id:
        out.alicilar = [
            PanikAliciOut(
                user_id=a.user_id,
                ad=ad,
                rol=rol,
                bildirildi_at=a.bildirildi_at,
                goruldu_at=a.goruldu_at,
                mudahale_at=a.mudahale_at,
                yanit=a.yanit,
                yanit_at=a.yanit_at,
            )
            for a, ad, rol in satirlar
        ]
    return out


def _yayin_planla(alarm_id: uuid.UUID, tenant_id: uuid.UUID, gecikme: int) -> bool:
    """Gecikmeli yayin gorevi. Donus: planlanabildi mi.

    Planlanamazsa cagiran SENKRON yayina duser — broker yoklugu bir
    guvenlik ozelligini susturamaz.
    """
    try:
        celery_app.send_task(
            "panik.yayinla",
            args=[str(alarm_id), str(tenant_id)],
            countdown=gecikme,
        )
        return True
    except Exception:
        return False


@router.post("", response_model=PanikAlarmOut, status_code=201)
async def tetikle(
    body: PanikOlustur,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_TETIKLEYEN),
    dil: str = Depends(_istek_dili),
) -> PanikAlarmOut:
    if not tetikleyebilir_mi(user.role, body.tip):
        raise APIError(403, "forbidden", "panik_tipi_yetkisiz")

    # TEKRAR BASMA -> YENI ALARM DEGIL, YENIDEN DUYURU.
    acik = (
        await db.execute(
            select(PanikAlarm)
            .where(
                PanikAlarm.olusturan_user_id == user.id,
                PanikAlarm.tip == body.tip,
                PanikAlarm.durum.in_(("beklemede", "acik", "mudahale")),
            )
            .order_by(PanikAlarm.created_at.desc(), PanikAlarm.id)
            .limit(1)
        )
    ).scalar_one_or_none()
    if acik is not None:
        yeterince_eski = (
            acik.gonderildi_at is not None
            and (_simdi() - acik.gonderildi_at).total_seconds()
            >= TEKRAR_DUYURU_ARALIGI_SN
        )
        if yeterince_eski:
            _yayin_planla(acik.id, user.tenant_id, 0)
        return await _govde(db, acik, user, dil)

    unit_id = body.unit_id
    if body.tip == "sakin" and unit_id is None:
        # Sakinin dairesini SUNUCU bulur: istemcinin daire kimligini
        # bilmesi gerekmez ve bilmesini istemek, acil durumda fazladan
        # bir istek demekti.
        unit_id = (
            await db.execute(
                select(UnitResident.unit_id)
                .where(
                    UnitResident.user_id == user.id,
                    # AKTIF SAKINLIK = `bitis` bos (depo deseni).
                    UnitResident.bitis.is_(None),
                )
                .limit(1)
            )
        ).scalar_one_or_none()

    alarm = PanikAlarm(
        tenant_id=user.tenant_id,
        tip=body.tip,
        kategori=body.kategori,
        durum="beklemede",
        olusturan_user_id=user.id,
        unit_id=unit_id,
        checkpoint_id=body.checkpoint_id,
        gps_lat=body.gps_lat,
        gps_lng=body.gps_lng,
        camera_id=body.camera_id,
        # KAYIT ISARETI: kaydin kendisi NVR'da; burada yalniz AN yazilir.
        kayit_an=_simdi() if body.camera_id else None,
        aciklama=body.aciklama,
    )
    db.add(alarm)
    await db.flush()

    await audit_user(
        db, user, Action.PANIK_TETIK, resource_type="panik_alarm",
        resource_id=alarm.id,
        meta={"tip": body.tip, "konum": "nfc" if body.checkpoint_id else
              ("gps" if body.gps_lat is not None else "yok")},
    )

    # ASKIDAKI KULLANICI: satir YAZILIR, yayin YAPILMAZ.
    if aski_aktif(user.panik_askida_bitis):
        alarm.durum = "iptal"
        alarm.iptal_at = _simdi()
        await db.flush()
        return await _govde(db, alarm, user, dil)

    if not _yayin_planla(alarm.id, user.tenant_id, IPTAL_PENCERESI_SN):
        # Broker yok -> SENKRON yayin. Iptal penceresi kaybedilir ama
        # alarm GIDER.
        from ..panik_yayin import yayinla_senkron

        await yayinla_senkron(db, alarm)

    return await _govde(db, alarm, user, dil)


@router.post("/{alarm_id}/iptal", response_model=PanikAlarmOut)
async def iptal(
    alarm_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_TETIKLEYEN),
    dil: str = Depends(_istek_dili),
) -> PanikAlarmOut:
    alarm = await get_or_404(db, PanikAlarm, alarm_id)
    # IPTAL YALNIZ BASANA AIT: baskasinin alarmini iptal etmek, gercek
    # bir acili susturmanin en kolay yolu olurdu. Yonetim KAPATIR
    # (`/kapat`) — kapatma "sonuclandi" demektir, "hic olmadi" degil.
    if alarm.olusturan_user_id != user.id:
        raise APIError(403, "forbidden", "panik_iptal_yetkisiz")
    if alarm.durum in ("kapandi", "iptal", "yanlis_alarm"):
        raise APIError(409, "conflict", "panik_zaten_kapali")

    gonderilmisti = alarm.durum != "beklemede"
    alarm.durum = "yanlis_alarm" if gonderilmisti else "iptal"
    alarm.iptal_at = _simdi()
    await db.flush()
    await audit_user(
        db, user, Action.PANIK_IPTAL, resource_type="panik_alarm",
        resource_id=alarm.id, meta={"gonderilmisti": gonderilmisti},
    )
    if gonderilmisti:
        # Rahatsiz edilenlere "yanlis alarm" gider; iptal penceresi
        # icinde iptal edilene KIMSE rahatsiz edilmedigi icin gitmez.
        from ..panik_yayin import yanlis_alarm_duyur

        await yanlis_alarm_duyur(db, alarm)
    return await _govde(db, alarm, user, dil)


@router.post("/{alarm_id}/gordum", response_model=PanikAlarmOut)
async def gordum(
    alarm_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
    dil: str = Depends(_istek_dili),
) -> PanikAlarmOut:
    alarm = await get_or_404(db, PanikAlarm, alarm_id)
    satir = (
        await db.execute(
            select(PanikAlici).where(
                PanikAlici.alarm_id == alarm.id, PanikAlici.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if satir is None:
        # ALICI OLMAYAN "gordum" DIYEMEZ: olcum "alarmi alanlarin kaci
        # gordu" sorusudur; alici olmayan biri o paydayi bozardi.
        raise APIError(403, "forbidden", "panik_alicisi_degil")
    if satir.goruldu_at is None:
        satir.goruldu_at = _simdi()
        await db.flush()
        await audit_user(
            db, user, Action.PANIK_GORULDU, resource_type="panik_alarm",
            resource_id=alarm.id,
        )
    return await _govde(db, alarm, user, dil)


@router.post("/{alarm_id}/mudahale", response_model=PanikAlarmOut)
async def mudahale(
    alarm_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
    dil: str = Depends(_istek_dili),
) -> PanikAlarmOut:
    alarm = await get_or_404(db, PanikAlarm, alarm_id)
    satir = (
        await db.execute(
            select(PanikAlici).where(
                PanikAlici.alarm_id == alarm.id, PanikAlici.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if satir is None:
        raise APIError(403, "forbidden", "panik_alicisi_degil")
    if alarm.durum in ("kapandi", "iptal", "yanlis_alarm"):
        raise APIError(409, "conflict", "panik_zaten_kapali")

    simdi = _simdi()
    if satir.mudahale_at is None:
        satir.mudahale_at = simdi
        # "Gidiyorum" demek GORMEYI de kapsar; ayri dokunus istemek,
        # acil durumda iki adim demekti.
        satir.goruldu_at = satir.goruldu_at or simdi
    # ALARMIN mudahale ani ILK "gidiyorum"dur: sonrakiler sureyi
    # uzatirsa olcu anlamsizlasir.
    if alarm.mudahale_at is None:
        alarm.mudahale_at = simdi
        alarm.durum = "mudahale"
    await db.flush()
    await audit_user(
        db, user, Action.PANIK_MUDAHALE, resource_type="panik_alarm",
        resource_id=alarm.id,
    )
    return await _govde(db, alarm, user, dil)


@router.post("/{alarm_id}/kapat", response_model=PanikAlarmOut)
async def kapat(
    alarm_id: uuid.UUID,
    body: PanikKapat,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
    dil: str = Depends(_istek_dili),
) -> PanikAlarmOut:
    alarm = await get_or_404(db, PanikAlarm, alarm_id)
    if alarm.durum in ("kapandi", "iptal", "yanlis_alarm"):
        raise APIError(409, "conflict", "panik_zaten_kapali")
    # KAPATMA ALICILARA ve YONETIME ACIK: olaya giden kisi kapatir.
    if user.role not in LISTE_ROLLERI:
        satir = (
            await db.execute(
                select(PanikAlici).where(
                    PanikAlici.alarm_id == alarm.id, PanikAlici.user_id == user.id
                )
            )
        ).scalar_one_or_none()
        if satir is None:
            raise APIError(403, "forbidden", "panik_kapatma_yetkisiz")

    alarm.durum = "kapandi"
    alarm.kapandi_at = _simdi()
    alarm.kapatan_user_id = user.id
    alarm.kapanis_notu = body.kapanis_notu
    await db.flush()
    await audit_user(
        db, user, Action.PANIK_KAPAT, resource_type="panik_alarm",
        resource_id=alarm.id, meta={"notlu": bool(body.kapanis_notu)},
    )
    from ..panik_yayin import kapanis_duyur

    await kapanis_duyur(db, alarm)
    return await _govde(db, alarm, user, dil)


async def _toplu_yanit(
    db: AsyncSession, alarm_id: uuid.UUID, user: AppUser, yanit: str
) -> PanikAlarm:
    """(P249 §1b) Toplu uyarida "guvendeyim" / "yardima ihtiyacim var".

    YALNIZ ALICI: sayim "alarmi ALANLARIN kaci guvende" sorusudur.
    YALNIZ TOPLU UYARI: yardim cagrisinda (saglik vb.) "guvendeyim"
    anlamsizdir — orada karar "gordum"/"gidiyorum"dur.
    YANIT DEGISEBILIR: "guvendeyim" dedikten sonra enkaz altinda kalan
    ya da yarali olan kisi "yardim"a gecebilmeli; tersi de (yardim geldi).
    """
    alarm = await get_or_404(db, PanikAlarm, alarm_id)
    # ALICILIK ONCE: alici olmayana alarmin turu ya da durumu hakkinda
    # bilgi sizmasin (IDOR taramasi: once 409 "toplu degil" donuyordu).
    satir = (
        await db.execute(
            select(PanikAlici).where(
                PanikAlici.alarm_id == alarm.id, PanikAlici.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if satir is None:
        raise APIError(403, "forbidden", "panik_alicisi_degil")
    if not toplu_mu(alarm.kategori):
        raise APIError(409, "conflict", "panik_toplu_degil")
    if alarm.durum in ("kapandi", "iptal", "yanlis_alarm"):
        raise APIError(409, "conflict", "panik_zaten_kapali")
    onceki = satir.yanit
    simdi = _simdi()
    satir.yanit = yanit
    satir.yanit_at = simdi
    # Yanit vermek GORMEYI de kapsar: tam ekran kapanir.
    satir.goruldu_at = satir.goruldu_at or simdi
    await db.flush()
    await audit_user(
        db, user,
        Action.PANIK_GUVENDE if yanit == "guvende" else Action.PANIK_YARDIM,
        resource_type="panik_alarm", resource_id=alarm.id,
    )
    if yanit == "yardim" and onceki != "yardim":
        from ..panik_yayin import yardim_talebi_duyur

        await yardim_talebi_duyur(db, alarm, user)
    return alarm


@router.post("/{alarm_id}/guvendeyim", response_model=PanikAlarmOut)
async def guvendeyim(
    alarm_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
    dil: str = Depends(_istek_dili),
) -> PanikAlarmOut:
    alarm = await _toplu_yanit(db, alarm_id, user, "guvende")
    return await _govde(db, alarm, user, dil)


@router.post("/{alarm_id}/yardim", response_model=PanikAlarmOut)
async def yardim_istiyorum(
    alarm_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
    dil: str = Depends(_istek_dili),
) -> PanikAlarmOut:
    alarm = await _toplu_yanit(db, alarm_id, user, "yardim")
    return await _govde(db, alarm, user, dil)


@router.get("/{alarm_id}/durum", response_model=PanikDurumOut)
async def durum(
    alarm_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(require_role(*sorted(LISTE_ROLLERI))),
) -> PanikDurumOut:
    """(P249 §1b) DAIRE BAZINDA DURUM — yonetim ve guvenlik icin.

    Sakin bu tabloyu GORMEZ: hangi dairenin yanit vermedigi, o dairenin
    bos olabilecegini soyler — kisisel veri ve guvenlik bilgisidir.
    """
    from ..panik_durum import durum_hesapla

    alarm = await get_or_404(db, PanikAlarm, alarm_id)
    return await durum_hesapla(db, alarm)


@router.get("/aktif", response_model=list[PanikAlarmOut])
async def aktifler(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
    dil: str = Depends(_istek_dili),
) -> list[PanikAlarmOut]:
    """BANA gelen, KAPANMAMIS ve HENUZ GORMEDIGIM alarmlar.

    Tam ekran uyarinin kaynagi. Uc suzgec de gerekli:

      * `beklemede` DAHIL DEGIL — henuz kimseye gonderilmemis bir alarmi
        gostermek, iptal penceresini anlamsiz kilardi.
      * KAPANMIS DAHIL DEGIL — biten bir olay icin ekran kaplamak.
      * GORDUGUM DAHIL DEGIL — "gordum" dedikten sonra ekranin geri
        gelmesi, kapatilamaz bir uyariyi SONSUZ bir engele cevirirdi.
        Alarm listede (takip ekraninda) durmaya devam eder; kaybolan
        yalniz EKRANI KAPLAYAN uyaridir.
    """
    sorgu = (
        select(PanikAlarm)
        .join(PanikAlici, PanikAlici.alarm_id == PanikAlarm.id)
        .where(
            PanikAlici.user_id == user.id,
            PanikAlici.goruldu_at.is_(None),
            PanikAlarm.durum.in_(("acik", "mudahale")),
        )
        # (P249 §2) GERCEK ALARM ONCE: istemci ilk ogeyi tam ekran cizer;
        # tatbikat surerken gelen gercek alarm onun ARKASINDA kalmamali.
        # KARARLI SIRALAMA: ayni salisede (ayni `created_at`) sira
        # sorgudan sorguya degisirse sayfalar arasinda kayit atlanir
        # ya da tekrarlanir (`test_sayfalama_siralamasi`).
        .order_by(
            PanikAlarm.tatbikat_id.is_not(None),
            PanikAlarm.created_at.desc(),
            PanikAlarm.id,
        )
        .limit(20)
    )
    return [await _govde(db, a, user, dil) for a in (await db.execute(sorgu)).scalars().all()]


@router.get("", response_model=PanikListResponse)
async def liste(
    limit: int = Query(25, ge=1, le=200),
    offset: int = Query(0, ge=0),
    durum: str | None = Query(None, max_length=_G.KOD),
    tatbikat: bool | None = Query(
        None, description="(P251 §1) true: yalniz tatbikat, false: yalniz gercek"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
    dil: str = Depends(_istek_dili),
) -> PanikListResponse:
    kapsam = []
    if user.role not in LISTE_ROLLERI:
        # SAKIN LISTEYI GORMEZ: baska dairelerin acil durumlari kisisel
        # veridir. Yalniz KENDI actiklarini gorur.
        kapsam.append(PanikAlarm.olusturan_user_id == user.id)
    kosullar = list(kapsam)
    if durum:
        # (P251 §1) Bilinmeyen durum 422 — enum disi deger veritabaninda
        # tur hatasina (500) donusuyordu.
        if durum not in PANIK_DURUM.enums:
            raise APIError(422, "validation_error", "gecersiz_durum")
        kosullar.append(PanikAlarm.durum == durum)
    if tatbikat is not None:
        kosullar.append(
            PanikAlarm.tatbikat_id.is_not(None) if tatbikat
            else PanikAlarm.tatbikat_id.is_(None)
        )

    toplam = int(
        (
            await db.execute(
                select(func.count()).select_from(PanikAlarm).where(*kosullar)
            )
        ).scalar_one()
    )
    satirlar = (
        await db.execute(
            select(PanikAlarm)
            .where(*kosullar)
            .order_by(PanikAlarm.created_at.desc(), PanikAlarm.id)
            .limit(limit)
            .offset(offset)
        )
    ).scalars().all()
    return PanikListResponse(
        meta=PageMetaOut(limit=limit, offset=offset, total=toplam),
        items=[await _govde(db, a, user, dil) for a in satirlar],
        durumlar=list(PANIK_DURUM.enums),
        ozet=await _ozet(db, user, kapsam),
    )


#: (P251 §1) "Acik" TEK TANIM — sonuclanmamis her durum.
ACIK_DURUMLAR = ("beklemede", "acik", "mudahale")


async def _ozet(db: AsyncSession, user: AppUser, kapsam: list) -> PanikOzetOut:
    """Takip ekraninin serit sayilari (durum/tatbikat suzgecinden bagimsiz)."""
    from zoneinfo import ZoneInfo

    from ..models import Tenant

    tz_adi = (
        await db.execute(select(Tenant.timezone).where(Tenant.id == user.tenant_id))
    ).scalar_one_or_none() or "Europe/Istanbul"
    try:
        tz = ZoneInfo(tz_adi)
    except Exception:  # noqa: BLE001 - bozuk tz adi sayilari dusurmesin
        tz = ZoneInfo("Europe/Istanbul")
    bugun_basi = dt.datetime.now(tz).replace(hour=0, minute=0, second=0, microsecond=0)

    satirlar = (
        await db.execute(
            select(PanikAlarm.durum, PanikAlarm.tatbikat_id.is_not(None), func.count())
            .where(*kapsam)
            .group_by(PanikAlarm.durum, PanikAlarm.tatbikat_id.is_not(None))
        )
    ).all()
    ozet = PanikOzetOut()
    for durum, tatbikat_mi, adet in satirlar:
        if tatbikat_mi:
            ozet.tatbikat += adet
            continue
        if durum in ACIK_DURUMLAR:
            ozet.acik += adet
        else:
            ozet.kapanan += adet
            if durum == "yanlis_alarm":
                ozet.yanlis_alarm += adet
            elif durum == "iptal":
                ozet.iptal += adet
    ozet.bugun = int(
        (
            await db.execute(
                select(func.count()).select_from(PanikAlarm).where(
                    *kapsam,
                    PanikAlarm.tatbikat_id.is_(None),
                    PanikAlarm.created_at >= bugun_basi,
                )
            )
        ).scalar_one()
    )
    return ozet


@router.get("/{alarm_id}", response_model=PanikAlarmOut)
async def detay(
    alarm_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OKUR),
    dil: str = Depends(_istek_dili),
) -> PanikAlarmOut:
    alarm = await get_or_404(db, PanikAlarm, alarm_id)
    if user.role not in LISTE_ROLLERI and alarm.olusturan_user_id != user.id:
        alici = (
            await db.execute(
                select(PanikAlici.id).where(
                    PanikAlici.alarm_id == alarm.id, PanikAlici.user_id == user.id
                )
            )
        ).scalar_one_or_none()
        if alici is None:
            raise APIError(404, "not_found", "panik_bulunamadi")
    return await _govde(db, alarm, user, dil)
