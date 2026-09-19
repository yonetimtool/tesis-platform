"""(P240 §1) PANIK YAYINI — bildirim + push + SMS + kamera isareti.

===========================================================================
UC KANAL, UC AYRI GEREKCE
===========================================================================
  * IN-APP bildirim  — kalici kayit; kullanici sonra da gorebilsin.
  * PUSH (sesli kanal) — telefonu cebinde olan kisiye ULASAN tek yol.
  * SMS — uygulamasi kapali/silinmis ya da interneti olmayan kisi icin
    SON CARE. Verimor saglayicisi hazir ama BASLIK ONAYI BEKLIYOR
    (`mesajlasma.VerimorSmsSaglayici`): onaysizken saglayici gonderimi
    DENEMEZ ve `basarisiz` yazar. Kod bugun yazildi, baslik gelince
    tek bir ayarla acilir — yayin yolunu sonradan eklemek, o gun
    yeniden test etmeyi gerektirirdi.

===========================================================================
SESLI ROBOT ARAMA BU TURDA YAZILMADI (degerlendirme docs'ta)
===========================================================================
`docs/P240-kararlar.md` §1 "Sesli arama" basligi: saglayicilar, yaklasik
maliyet ve neden bu turda yazilmadigi orada.

===========================================================================
KAMERA ISARETI
===========================================================================
Kayit KOPYALANMAZ. Alarma `camera_id` + `kayit_an` yazilir; oynatma
mevcut `/cameras/{id}/kayit/oynat` ucundan yapilir (P213). Saatlerce
video indirip saklamak, bir alarm icin depolama ve yasal saklama yuku
uretirdi.
"""
from __future__ import annotations

import datetime as dt
import logging
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from starlette.concurrency import run_in_threadpool

from .models import AppUser, Diyafon, Notification, PanikAlarm, PanikAlici, Unit
from .panik import ALICI_ROLLERI, kategori_alicilari
from .push_metinleri import push_govdesi
from .scheduler.notify import dispatch_external

logger = logging.getLogger(__name__)

#: Panik SMS'i YALNIZ bu rollere gider.
#:
#: `yonetici_anons` TUM siteye push atar ama SMS ATMAZ: 300 daireye SMS
#: gondermek hem maliyet hem de saglayici hiz siniri demektir ve anonsun
#: hedefi zaten "uygulamasi acik olan herkes"tir. Saha ekibi icin ise SMS
#: son caredir — onlarin ulasilabilirligi isin kendisidir.
SMS_ROLLERI = frozenset({"security", "guvenlik_amiri", "yonetici", "admin"})


def _simdi() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def kategori_kimligi(kategori: str | None) -> str:
    """(P243 §5c) Kategoriye gore push metni kimligi.

    Kategori YOKSA eski metin (`panik_alarm`) kullanilir: P240'ta
    yazilmis alarmlarin kategorisi yok ve onlara uydurma bir talimat
    yazmak, olmayan bir bilgiyi kullaniciya soylemek olurdu.
    """
    return f"panik_kategori_{kategori}" if kategori else "panik_alarm"


async def _alicilar(db: AsyncSession, alarm: PanikAlarm) -> list[AppUser]:
    # (P243 §5c) ALICI KUMESI KATEGORIDEN DE TURER: bina geneli
    # tehlikeler (deprem/yangin/gaz/tahliye) TUM SITEYE gider.
    roller = kategori_alicilari(alarm.tip, alarm.kategori)
    kisiler = list(
        (
            await db.execute(
                select(AppUser).where(
                    AppUser.is_active.is_(True), AppUser.role.in_(roller)
                )
            )
        ).scalars().all()
    )
    return [k for k in kisiler if k.id != alarm.olusturan_user_id]


async def _veri(db: AsyncSession, alarm: PanikAlarm) -> dict[str, str]:
    """Push/SMS sablon alanlari — KISA ve EYLEME DONUK.

    Bildirim metni bir rapor degildir: okuyan kisi UC saniyede "nereye
    gidecegim"i anlamali. Bu yuzden yalniz ad + yer.
    """
    ad = ""
    if alarm.olusturan_user_id:
        ad = (
            await db.execute(
                select(AppUser.ad).where(AppUser.id == alarm.olusturan_user_id)
            )
        ).scalar_one_or_none() or ""
    yer = ""
    if alarm.unit_id:
        birim = (
            await db.execute(select(Unit).where(Unit.id == alarm.unit_id))
        ).scalar_one_or_none()
        if birim is not None:
            yer = f"{birim.blok or ''} {birim.daire_no}".strip()
    if not yer and alarm.gps_lat is not None:
        yer = f"{alarm.gps_lat}, {alarm.gps_lng}"
    return {"ad": ad, "yer": yer or "-"}


async def yayinla_senkron(db: AsyncSession, alarm: PanikAlarm) -> int:
    """Alarmi alicilara yayinlar. Donus: alici sayisi.

    IDEMPOTENT: ayni alarm iki kez yayinlanirsa alici satirlari
    TEKRARLANMAZ (benzersiz kisit) ama push YENIDEN gider — "tekrar
    duyuru" akisi tam olarak bunu ister.
    """
    if alarm.durum in ("iptal", "kapandi", "yanlis_alarm"):
        return 0

    kisiler = await _alicilar(db, alarm)
    veri = await _veri(db, alarm)
    veri["tip"] = alarm.tip
    # METIN KIMLIGI KATEGORIDEN: deprem uyarisiyla gaz kacagi uyarisi
    # ayni cumleyi kullanamaz (goc 0146).
    kimlik = kategori_kimligi(alarm.kategori)

    for k in kisiler:
        var = (
            await db.execute(
                select(PanikAlici).where(
                    PanikAlici.alarm_id == alarm.id, PanikAlici.user_id == k.id
                )
            )
        ).scalar_one_or_none()
        if var is None:
            db.add(
                PanikAlici(
                    tenant_id=alarm.tenant_id, alarm_id=alarm.id, user_id=k.id
                )
            )
        db.add(
            Notification(
                tenant_id=alarm.tenant_id,
                user_id=k.id,
                tip="panik_alarm",
                mesaj=push_govdesi(kimlik, "tr", veri),
                # BILDIRIM TIPI HALA `panik_alarm`: okundu/sil akislari
                # ve yonlendirme ona bagli. Degisen sey METIN.
                mesaj_kimlik=kimlik,
                mesaj_veri=veri,
            )
        )

    if alarm.durum == "beklemede":
        alarm.durum = "acik"
        alarm.gonderildi_at = _simdi()
    await db.flush()

    dispatch_external(
        kimlik,
        tenant_id=alarm.tenant_id,
        target_user_ids=[k.id for k in kisiler],
        params=veri,
        data={"tip": "panik_alarm", "panik_id": str(alarm.id),
              "panik_tip": alarm.tip,
              "panik_kategori": alarm.kategori or ""},
    )
    _sms_gonder(alarm, kisiler, veri)
    await _diyafon_anons(db, alarm, veri)
    await _akilli_ev_senaryolari(db, alarm)
    return len(kisiler)


async def _akilli_ev_senaryolari(db: AsyncSession, alarm: PanikAlarm) -> None:
    """(P240 §3) Panik -> akilli ev senaryolari.

    KODDA SABIT EYLEM YOK: "isiklari yak" demiyoruz, "bu olaya bagli
    senaryolari calistir" diyoruz. Bir tesis kapiyi acmak (itfaiye
    girisi) isterken otekinin acmamasi tamamen bir VERI farkidir.

    SENARYO YOKSA SESSIZ: akilli ev yapilandirmasi olmayan tesiste
    panik AYNEN calisir.
    """
    from .akilli_ev_olay import senaryolari_calistir

    olay = {
        "sakin": "panik_sakin",
        "guvenlik": "panik_guvenlik",
        "yonetici_anons": "panik_anons",
    }.get(alarm.tip)
    if olay is None:
        return
    try:
        await senaryolari_calistir(db, alarm.tenant_id, olay)
    except Exception:
        # SENARYO HATASI ALARMI DUSURMEZ: push ve in-app zaten gitti.
        logger.warning("[panik] akilli ev senaryolari calismadi (%s)", alarm.id)


async def _diyafon_anons(db: AsyncSession, alarm: PanikAlarm, veri: dict) -> None:
    """(P240 §2) Diyafon yapilandirilmissa ANONS gonder.

    ===================================================================
    DIYAFON YOKSA SESSIZCE ATLANIR
    ===================================================================
    Istegin acik maddesi: "panik butonu diyafon olmadan da calismali".
    Yapilandirilmamis bir diyafon bir HATA DEGIL, bir SECIMDIR; alarmi
    dusurmek ya da yoneticiye hata gostermek yanlis olurdu.

    ===================================================================
    YALNIZ TUM-SITE ANONSUNDA
    ===================================================================
    `yonetici_anons` (tahliye, gaz, deprem) TUM siteye seslenir ve
    diyafon tam da bunun icin vardir. Bir SAKININ evindeki acil durumu
    (`sakin`) butun bloklara duyurmak, o kisinin sagligini herkese ilan
    etmek olurdu — KVKK bir yana, alarmin hedefi de o degil.
    """
    if alarm.tip != "yonetici_anons":
        return
    from .diyafon import saglayici, yetenekler

    kayitlar = list(
        (
            await db.execute(
                select(Diyafon).where(Diyafon.aktif.is_(True))
            )
        ).scalars().all()
    )
    if not kayitlar:
        return
    mesaj = push_govdesi("panik_alarm", "tr", veri)
    for kayit in kayitlar:
        if not yetenekler(kayit.yontem).metin_anons:
            # Kuru kontak ses/metin TASIYAMAZ — denemek bos bir istek
            # ve yaniltici bir hata kaydi uretirdi.
            continue
        try:
            await run_in_threadpool(saglayici(kayit).metin_anons, mesaj)
        except Exception:
            # ANONS BASARISIZLIGI ALARMI DUSURMEZ: push ve in-app zaten
            # gitti; diyafon bir EK kanaldir.
            logger.warning("[panik] diyafon anonsu basarisiz (%s)", kayit.id)


def _sms_gonder(alarm: PanikAlarm, kisiler: list[AppUser], veri: dict[str, str]) -> None:
    """SON CARE kanali. Basarisizlik alarmi DUSURMEZ, yalniz loglanir.

    Baslik onayi gelmeden Verimor saglayicisi `basarisiz` doner ve bu
    DOGRU davranistir: gonderilmemis bir SMS'i "gonderildi" yazmak,
    hukuki bir kaniti uydurmak olurdu (`LogSmsSaglayici` notu).
    """
    from .mesajlasma import sms_saglayicisi

    try:
        saglayici = sms_saglayicisi()
    except Exception:
        logger.warning("[panik] SMS saglayicisi kurulamadi")
        return
    govde = push_govdesi("panik_alarm", "tr", veri)
    for k in kisiler:
        if k.role not in SMS_ROLLERI:
            continue
        numara = (k.telefon or "").strip()
        if not numara:
            continue
        try:
            saglayici.gonder(numara, None, govde)
        except Exception:
            logger.warning("[panik] SMS gonderilemedi (alarm=%s)", alarm.id)


async def yanlis_alarm_duyur(db: AsyncSession, alarm: PanikAlarm) -> None:
    """Gonderildikten SONRA iptal -> rahatsiz edilenlere duzeltme gider.

    Duzeltme GITMEZSE alici sahaya gider ve kimseyi bulamaz; "yanlis
    alarmdi" demek, alarmin kendisi kadar zaman-kritiktir.
    """
    await _ikincil_duyuru(db, alarm, "panik_yanlis_alarm")


async def kapanis_duyur(db: AsyncSession, alarm: PanikAlarm) -> None:
    await _ikincil_duyuru(db, alarm, "panik_kapandi")


async def _ikincil_duyuru(db: AsyncSession, alarm: PanikAlarm, tip: str) -> None:
    alici_idler = list(
        (
            await db.execute(
                select(PanikAlici.user_id).where(PanikAlici.alarm_id == alarm.id)
            )
        ).scalars().all()
    )
    if not alici_idler:
        return
    veri = await _veri(db, alarm)
    for uid in alici_idler:
        db.add(
            Notification(
                tenant_id=alarm.tenant_id,
                user_id=uid,
                tip=tip,
                mesaj=push_govdesi(tip, "tr", veri),
                mesaj_kimlik=tip,
                mesaj_veri=veri,
            )
        )
    await db.flush()
    dispatch_external(
        tip,
        tenant_id=alarm.tenant_id,
        target_user_ids=alici_idler,
        params=veri,
        data={"tip": tip, "panik_id": str(alarm.id)},
    )
