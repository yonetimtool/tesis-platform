"""(P249 §2) TATBIKAT — planla, duyur, baslat, bitir, raporla.

===========================================================================
GERCEK YOLUN PROVASI
===========================================================================
Tatbikat baslayinca bir `panik_alarm` satiri acilir ve GERCEK yayin yolu
(`panik_yayin.yayinla_senkron`) calisir: ayni push, ayni alarm kanali,
ayni tam ekran, ayni "Guvendeyim". Provada ayri bir yol kullanmak,
gercek gunde calisacak yolu sinamamak olurdu.

Farklar (hepsi `panik_alarm.tatbikat_id` uzerinden):
  * metin `panik_tatbikat_<k>`: basligin ONUNDE "TATBIKAT", govdenin
    basinda "Bu bir tatbikattir." — her dilde,
  * SMS, diyafon anonsu, akilli ev senaryosu YOK,
  * yanlis alarm sayacina girmez,
  * gercek alarm her zaman once; gercek TOPLU alarm aktif tatbikati durdurur.

===========================================================================
SES — GERCEK ALARMLA AYNI (karar, docs §2)
===========================================================================
Provanin amaci insanlara GERCEK sesi tanitmaktir: deprem gecesi ilk kez
duyulan bir ses, ne oldugu anlasilmadan kapatilir. Karistirilmayi onleyen
sey ses degil METINDIR: "TATBIKAT" basligin ilk kelimesi, tam ekranda
ayrica serit, ve (istege bagli) onceden duyuru.

===========================================================================
SAKIN TATBIKATI KAPATAMAZ (karar, docs §2)
===========================================================================
Tatbikatin olcusu "alarm kime ULASTI". Kapatilabilseydi rapor, ulasilamayan
kisiyi degil kapatan kisiyi "yanitsiz" gosterirdi. Sikligi yonetim
belirler; rahatsizligin cozumu tatbikati SEYREK yapmaktir, kapatma
dugmesi degil.
"""
from __future__ import annotations

import datetime as dt
import logging
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import (
    AppUser,
    BuildingBlock,
    Notification,
    PanikAlarm,
    PanikTatbikat,
    PushGonderim,
    Tenant,
    Unit,
)
from .panik_talimat import toplu_mu
from .push_metinleri import push_govdesi
from .scheduler.notify import dispatch_external

logger = logging.getLogger(__name__)

#: Tatbikatin zaman gosterimi — duyuru metni TESISIN saatinde okunmali.
TESIS_SAAT_DILIMI = ZoneInfo("Europe/Istanbul")

#: Tatbikati alan PERSONEL rolleri — blok kapsaminda da hepsi alir
#: (sayimi yapacak olan onlardir).
PERSONEL_ROLLERI = ("security", "guvenlik_amiri", "tesis_gorevlisi", "yonetici", "admin")


def _simdi() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def zaman_metni(an: dt.datetime) -> str:
    """"29.09.2026 14:00" — dilden bagimsiz sayisal bicim, tesis saatiyle."""
    return an.astimezone(TESIS_SAAT_DILIMI).strftime("%d.%m.%Y %H:%M")


async def blok_var_mi(db: AsyncSession, blok: str) -> bool:
    kayitli = (
        await db.execute(
            select(BuildingBlock.id).where(func.lower(BuildingBlock.ad) == blok.lower()).limit(1)
        )
    ).scalar_one_or_none()
    if kayitli is not None:
        return True
    return (
        await db.execute(select(Unit.id).where(Unit.blok == blok).limit(1))
    ).scalar_one_or_none() is not None


async def yer_metni(db: AsyncSession, t: PanikTatbikat) -> str:
    """Kapsamin okunur adi: blok adi ya da tesis adi (ozel ad, cevrilmez)."""
    if t.kapsam == "blok" and t.blok:
        return t.blok
    return (
        await db.execute(select(Tenant.ad).where(Tenant.id == t.tenant_id))
    ).scalar_one_or_none() or ""


async def hedef_kisiler(db: AsyncSession, t: PanikTatbikat) -> list[AppUser]:
    """Tatbikati ALACAK kisiler.

    SITE: tum site (gercek toplu uyariyla AYNI kume).
    BLOK: o bloktaki AKTIF sakinler + TUM personel. Personeli bloga gore
    suzmek anlamsiz: sayimi yapacak ve raporu okuyacak olan onlardir.
    """
    from .models import UnitResident
    from .panik import KATEGORI_ALICI

    roller = KATEGORI_ALICI[t.kategori]
    kisiler = list(
        (
            await db.execute(
                select(AppUser).where(AppUser.is_active.is_(True), AppUser.role.in_(roller))
            )
        ).scalars().all()
    )
    if t.kapsam != "blok":
        return kisiler
    bloktakiler = set(
        (
            await db.execute(
                select(UnitResident.user_id)
                .join(Unit, Unit.id == UnitResident.unit_id)
                .where(UnitResident.bitis.is_(None), Unit.blok == t.blok)
            )
        ).scalars().all()
    )
    return [
        k for k in kisiler
        if k.role in PERSONEL_ROLLERI or k.id in bloktakiler
    ]


async def duyuru_gonder(db: AsyncSession, t: PanikTatbikat) -> int:
    """(P249 §2) ONCEDEN DUYURU — "Sali 14:00'te A blokta deprem tatbikati".

    Alarm KANALINDAN DEGIL, genel kanaldan: duyuru bir hatirlatmadir;
    alarm sesiyle calmasi, provadan once bir "yanlis alarm" uretmek olurdu.
    """
    if t.planlanan_at is None:
        return 0
    kisiler = await hedef_kisiler(db, t)
    # KIMLIK `panik_tatbikat_` ile BASLAMAZ: o onek ALARM sinifidir
    # (`push_kanal.alarm_mi`) ve duyuru alarm sesiyle calardi.
    kimlik = f"tatbikat_duyuru_{t.kategori}"
    veri = {"zaman": zaman_metni(t.planlanan_at), "yer": await yer_metni(db, t)}
    for k in kisiler:
        db.add(
            Notification(
                tenant_id=t.tenant_id,
                user_id=k.id,
                tip="panik_tatbikat_duyuru",
                mesaj=push_govdesi(kimlik, "tr", veri),
                mesaj_kimlik=kimlik,
                mesaj_veri=veri,
            )
        )
    t.duyuru_gonderildi_at = _simdi()
    await db.flush()
    dispatch_external(
        kimlik,
        tenant_id=t.tenant_id,
        target_user_ids=[k.id for k in kisiler],
        params=veri,
        data={"tip": "panik_tatbikat_duyuru", "tatbikat_id": str(t.id)},
    )
    return len(kisiler)


async def baslat(db: AsyncSession, t: PanikTatbikat) -> PanikAlarm:
    """Tatbikati BASLAT: alarm satiri ac ve GERCEK yolla yayinla.

    IPTAL PENCERESI YOK: tatbikat planlanmis bir eylemdir; yanlislikla
    basmayi onleyen 5 sn pencere burada yalniz gecikme olurdu.
    """
    from .panik_yayin import yayinla_senkron

    alarm = PanikAlarm(
        tenant_id=t.tenant_id,
        tip="yonetici_anons",
        kategori=t.kategori,
        durum="beklemede",
        olusturan_user_id=t.olusturan_user_id,
        tatbikat_id=t.id,
        aciklama=t.aciklama,
    )
    db.add(alarm)
    t.durum = "aktif"
    t.basladi_at = _simdi()
    await db.flush()
    await yayinla_senkron(db, alarm)
    return alarm


async def bitir(db: AsyncSession, t: PanikTatbikat, neden: str = "elle") -> None:
    """Tatbikati BITIR: alarm kapanir, tam ekranlar kalkar.

    KAPANIS PUSH'U GITMEZ: gercek alarmda "alarm kapandi" sahaya donen
    kisiye bilgi verir; provada herkes zaten toplanma alanindadir ve bir
    bildirim daha gurultudur. Rapor bu andan sonra DONAR.
    """
    t.durum = "bitti"
    t.bitti_at = _simdi()
    t.bitis_nedeni = neden
    alarm = await alarmi(db, t)
    if alarm is not None and alarm.durum in ("beklemede", "acik", "mudahale"):
        alarm.durum = "kapandi"
        alarm.kapandi_at = t.bitti_at
    await db.flush()


async def alarmi(db: AsyncSession, t: PanikTatbikat) -> PanikAlarm | None:
    return (
        await db.execute(select(PanikAlarm).where(PanikAlarm.tatbikat_id == t.id))
    ).scalar_one_or_none()


async def gercek_alarm_tatbikati_durdurur(db: AsyncSession, alarm: PanikAlarm) -> int:
    """(P249 §2) GERCEK TOPLU ALARM -> aktif tatbikat DURUR.

    Ayni anda iki "deprem" ekrani (biri prova) karisiklik yaratir; gercek
    olan her seyin onune gecer. Yardim cagrisi (saglik vb.) tatbikati
    DURDURMAZ — gercek alarm yine ONCE gosterilir (`/panik/aktif` sirasi).
    """
    if alarm.tatbikat_id is not None or not toplu_mu(alarm.kategori):
        return 0
    aktifler = list(
        (
            await db.execute(
                select(PanikTatbikat).where(PanikTatbikat.durum == "aktif")
            )
        ).scalars().all()
    )
    for t in aktifler:
        await bitir(db, t, neden="gercek_alarm")
    return len(aktifler)


async def push_teslim(db: AsyncSession, t: PanikTatbikat) -> tuple[int, int]:
    """(denenen, gonderildi) — tatbikat push'unun teshis satirlarindan.

    "Kac kisiye ULASTI" sorusunun olculebilir kismi: FCM'in kabul ettigi
    jeton sayisi. Telefonun ekranina dustugu BURADAN olculemez (teslim
    raporu yok); onun olcusu "gordu" sayisidir.
    """
    if t.basladi_at is None:
        return 0, 0
    bitis = t.bitti_at or _simdi()
    satirlar = (
        await db.execute(
            select(PushGonderim.durum, func.count())
            .where(
                PushGonderim.kimlik == f"panik_tatbikat_{t.kategori}",
                PushGonderim.created_at >= t.basladi_at - dt.timedelta(seconds=5),
                PushGonderim.created_at <= bitis,
            )
            .group_by(PushGonderim.durum)
        )
    ).all()
    denenen = sum(n for _, n in satirlar)
    gonderildi = sum(n for d, n in satirlar if d == "gonderildi")
    return denenen, gonderildi


async def zamani_gelenleri_baslat(db: AsyncSession) -> int:
    """Beat: planlanan zamani gelmis tatbikatlari baslat (tesis baglaminda)."""
    gelenler = list(
        (
            await db.execute(
                select(PanikTatbikat).where(
                    PanikTatbikat.durum == "planli",
                    PanikTatbikat.planlanan_at <= _simdi(),
                )
            )
        ).scalars().all()
    )
    for t in gelenler:
        # AYNI ANDA IKI TATBIKAT YOK: biri aktifse sonraki bekler.
        aktif = (
            await db.execute(
                select(PanikTatbikat.id).where(PanikTatbikat.durum == "aktif").limit(1)
            )
        ).scalar_one_or_none()
        if aktif is not None:
            break
        await baslat(db, t)
    return len(gelenler)


def tum_tenantlar_icin() -> dict:
    """Beat girisi: yalniz ZAMANI GELMIS tatbikati olan tesisleri tarar.

    4000+ tesisi tek tek dolasmak yerine sahip baglantisiyla (RLS disi) tek
    sorgu: hangi tesislerde is var. Is tesisin KENDI baglaminda yapilir.
    """
    import psycopg
    from sqlalchemy import text

    from .config import settings
    from .db import SessionLocal

    with psycopg.connect(settings.owner_dsn, autocommit=True, connect_timeout=10) as conn:
        tesisler = [
            r[0]
            for r in conn.execute(
                "SELECT DISTINCT tenant_id FROM panik_tatbikat "
                "WHERE durum = 'planli' AND planlanan_at <= now()"
            ).fetchall()
        ]

    async def _is() -> dict:
        ozet = {"tesis": 0, "baslatilan": 0}
        for tid in tesisler:
            try:
                async with SessionLocal() as db:
                    await db.execute(
                        text("SELECT set_config('app.current_tenant_id', :t, true)"),
                        {"t": str(tid)},
                    )
                    n = await zamani_gelenleri_baslat(db)
                    await db.commit()
                ozet["tesis"] += 1
                ozet["baslatilan"] += n
            except Exception:
                logger.exception("[tatbikat] baslatilamadi (tesis=%s)", tid)
        return ozet

    from .tasks import _async_calistir

    return _async_calistir(_is) if tesisler else {"tesis": 0, "baslatilan": 0}

