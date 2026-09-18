"""(P240 §3) AKILLI EV OLAY ISLEME — senaryo calistirma + bildirim.

===========================================================================
SENARYO KODDA SABIT DEGIL
===========================================================================
Istegin acik maddesi: "Hangi eylemin hangi senaryoda tetiklenecegi
YAPILANDIRILABILIR olsun, kodda sabit olmasin."

Bu modul "isiklari yak" DEMEZ; "bu olaya bagli senaryolari calistir"
der. Bir tesis kacakta vanayi kapatmak, otekisi yalniz bildirim almak
isteyebilir — ikisi de ayni kodla, farkli VERIYLE calisir.

===========================================================================
ALICI KUMESI OLAYA GORE — istegin §4 ve §9 maddeleri
===========================================================================
  * DAIRE ICI kacak  -> o dairenin SAKINLERI + yonetim
  * ORTAK ALAN kacak -> guvenlik + yonetim (sakinler DEGIL: kazan
    dairesi onlarin isi degil ve her daireye bildirim gondermek
    paniklemeye yol acardi)
  * YANGIN            -> guvenlik + amir + yonetim (her iki konumda da:
    duman her zaman saha mudahalesi gerektirir)

===========================================================================
SENARYO HATASI BILDIRIMI DUSURMEZ
===========================================================================
Vana kapatilamadiysa bile SAKIN HABERDAR OLMALI. Ters sira (once
senaryo, hata varsa bildirim yok) bir kacagi sessiz birakirdi.
"""
from __future__ import annotations

import datetime as dt
import logging
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from .akilli_ev import kopru
from .models import (
    AkilliEvCihaz,
    AkilliEvKopru,
    AkilliEvSenaryo,
    AppUser,
    Notification,
    Unit,
    UnitResident,
)
from .push_metinleri import push_govdesi
from .scheduler.notify import dispatch_external

logger = logging.getLogger(__name__)

#: Olay -> bildirim tipi.
BILDIRIM_TIPI = {
    "su_kacagi": "akilli_ev_kacak",
    "gaz_kacagi": "akilli_ev_kacak",
    "yangin": "akilli_ev_yangin",
}

#: Ortak alan olaylarinin gittigi roller.
ORTAK_ROLLER = ("security", "guvenlik_amiri", "yonetici", "admin")
#: Yangin HER ZAMAN sahaya gider.
YANGIN_ROLLERI = ("security", "guvenlik_amiri", "yonetici", "admin")


async def senaryolari_calistir(
    db: AsyncSession, tenant_id: uuid.UUID, olay: str
) -> int:
    """Olaya bagli AKTIF senaryolari calistirir. Donus: denenen adet.

    HATA YUTULUR ve loglanir: bir cihaz yanit vermediginde digerleri
    calismaya devam etmeli — acil durumda "hepsi ya da hicbiri" yanlis
    bir kural olurdu.
    """
    satirlar = (
        await db.execute(
            select(AkilliEvSenaryo, AkilliEvCihaz)
            .join(AkilliEvCihaz, AkilliEvCihaz.id == AkilliEvSenaryo.cihaz_id)
            .where(
                AkilliEvSenaryo.olay == olay,
                AkilliEvSenaryo.aktif.is_(True),
                AkilliEvCihaz.aktif.is_(True),
            )
        )
    ).all()
    if not satirlar:
        return 0

    koprular: dict[uuid.UUID, AkilliEvKopru] = {}
    adet = 0
    for senaryo, cihaz in satirlar:
        kayit = koprular.get(cihaz.kopru_id)
        if kayit is None:
            kayit = (
                await db.execute(
                    select(AkilliEvKopru).where(AkilliEvKopru.id == cihaz.kopru_id)
                )
            ).scalar_one_or_none()
            if kayit is None:
                continue
            koprular[cihaz.kopru_id] = kayit
        try:
            await run_in_threadpool(
                kopru(kayit).komut, cihaz.dis_kimlik, senaryo.eylem, cihaz.tip
            )
            adet += 1
        except Exception:
            logger.warning(
                "[akilli-ev] senaryo calismadi (cihaz=%s eylem=%s)",
                cihaz.id,
                senaryo.eylem,
            )
    return adet


async def olay_isle(
    db: AsyncSession, tenant_id: uuid.UUID, cihaz: AkilliEvCihaz, olay: str
) -> int:
    """Sensor olayi: BILDIRIM once, senaryo sonra.

    Sira bilincli: vana kapatilamadiysa bile sakin haberdar olmali.
    """
    veri = {
        "cihaz": cihaz.ad,
        "yer": cihaz.alan or "",
    }
    if cihaz.unit_id is not None:
        birim = (
            await db.execute(select(Unit).where(Unit.id == cihaz.unit_id))
        ).scalar_one_or_none()
        if birim is not None:
            veri["yer"] = f"{birim.blok or ''} {birim.no}".strip()

    tip = BILDIRIM_TIPI.get(olay, "akilli_ev_kacak")
    alici_idler: list[uuid.UUID] = []

    if olay != "yangin" and cihaz.unit_id is not None:
        # DAIRE ICI KACAK: o dairenin sakinleri + yonetim.
        alici_idler = list(
            (
                await db.execute(
                    select(UnitResident.user_id).where(
                        UnitResident.unit_id == cihaz.unit_id,
                        UnitResident.bitis.is_(None),
                    )
                )
            ).scalars().all()
        )
        for uid in alici_idler:
            db.add(
                Notification(
                    tenant_id=tenant_id, user_id=uid, tip=tip,
                    mesaj=push_govdesi(tip, "tr", veri),
                    mesaj_kimlik=tip, mesaj_veri=veri,
                )
            )

    # YONETIM ALARMI (user_id NULL): ortak alan olaylari ve yangin
    # KISISEL degil TESISE aittir — `notifications._kapsam` yonetim
    # rollerine yalniz bu satirlari gosterir (P240 §4'te olculdu).
    db.add(
        Notification(
            tenant_id=tenant_id, user_id=None, tip=tip,
            mesaj=push_govdesi(tip, "tr", veri),
            mesaj_kimlik=tip, mesaj_veri=veri,
        )
    )
    await db.flush()

    roller = YANGIN_ROLLERI if olay == "yangin" else ORTAK_ROLLER
    dispatch_external(
        tip,
        tenant_id=tenant_id,
        target_roles=list(roller),
        params=veri,
        data={"tip": tip, "cihaz_id": str(cihaz.id), "olay": olay},
    )
    if alici_idler:
        dispatch_external(
            tip,
            tenant_id=tenant_id,
            target_user_ids=alici_idler,
            params=veri,
            data={"tip": tip, "cihaz_id": str(cihaz.id), "olay": olay},
        )

    return await senaryolari_calistir(db, tenant_id, olay)


def simdi() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)
