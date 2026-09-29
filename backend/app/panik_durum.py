"""(P249 §1b) DAIRE BAZINDA DURUM — kim guvende, kim yardim istiyor, kim sessiz.

Depremde yoneticinin en degerli bilgisi budur. Ayni hesap tatbikat
raporunun da temelidir (§2): tatbikat, gercek alarmin PROVASIDIR ve
raporu gercek olayda gorulecek tabloyla ayni olmali.

SIRALAMA: once `yardim` (birinin gitmesi gereken daireler), sonra
`yanitsiz` (sayimin acik kalan kismi), en son `guvende`. Ayni durumda
blok + daire no sirasi.
"""
from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import AppUser, PanikAlarm, PanikAlici, Unit, UnitResident
from .schemas import PanikDurumDaire, PanikDurumKisi, PanikDurumOut

_DURUM_SIRASI = {"yardim": 0, "yanitsiz": 1, "guvende": 2}


def _sure(alarm: PanikAlarm, a: PanikAlici) -> int | None:
    if a.yanit_at is None or alarm.gonderildi_at is None:
        return None
    return max(0, int((a.yanit_at - alarm.gonderildi_at).total_seconds()))


def daire_durumu(kisiler: list[PanikDurumKisi]) -> str:
    if any(k.yanit == "yardim" for k in kisiler):
        return "yardim"
    if any(k.yanit == "guvende" for k in kisiler):
        return "guvende"
    return "yanitsiz"


async def durum_hesapla(db: AsyncSession, alarm: PanikAlarm) -> PanikDurumOut:
    satirlar = (
        await db.execute(
            select(PanikAlici, AppUser.ad, AppUser.role)
            .join(AppUser, AppUser.id == PanikAlici.user_id)
            .where(PanikAlici.alarm_id == alarm.id)
        )
    ).all()
    kullanicilar = [a.user_id for a, _, _ in satirlar]
    # AKTIF SAKINLIK (`bitis` bos). Bir kisi iki dairede oturuyorsa ILK
    # daire alinir: ayni insani iki dairede "yanitsiz" saymak, sayimi
    # sisirirdi.
    daire_of: dict[uuid.UUID, Unit] = {}
    if kullanicilar:
        for uid, birim in (
            await db.execute(
                select(UnitResident.user_id, Unit)
                .join(Unit, Unit.id == UnitResident.unit_id)
                .where(
                    UnitResident.user_id.in_(kullanicilar),
                    UnitResident.bitis.is_(None),
                )
                .order_by(Unit.blok, Unit.no)
            )
        ).all():
            daire_of.setdefault(uid, birim)

    daireler: dict[uuid.UUID, tuple[Unit, list[PanikDurumKisi]]] = {}
    personel: list[PanikDurumKisi] = []
    sureler: list[int] = []
    sayac = {"goruldu": 0, "guvende": 0, "yardim": 0}
    for a, ad, rol in satirlar:
        kisi = PanikDurumKisi(
            user_id=a.user_id,
            ad=ad or "",
            rol=str(rol),
            goruldu_at=a.goruldu_at,
            yanit=a.yanit,
            yanit_at=a.yanit_at,
            yanit_suresi_sn=_sure(alarm, a),
        )
        if a.goruldu_at is not None:
            sayac["goruldu"] += 1
        if a.yanit in ("guvende", "yardim"):
            sayac[a.yanit] += 1
        if kisi.yanit_suresi_sn is not None:
            sureler.append(kisi.yanit_suresi_sn)
        birim = daire_of.get(a.user_id)
        if birim is None:
            personel.append(kisi)
        else:
            daireler.setdefault(birim.id, (birim, []))[1].append(kisi)

    daire_listesi = [
        PanikDurumDaire(
            unit_id=birim.id,
            blok=birim.blok,
            daire_no=birim.no,
            durum=daire_durumu(kisiler),
            kisiler=kisiler,
        )
        for birim, kisiler in daireler.values()
    ]
    daire_listesi.sort(
        key=lambda d: (_DURUM_SIRASI[d.durum], d.blok or "", d.daire_no or "")
    )
    toplam = len(satirlar)
    return PanikDurumOut(
        alarm_id=alarm.id,
        alici=toplam,
        goruldu=sayac["goruldu"],
        guvende=sayac["guvende"],
        yardim=sayac["yardim"],
        yanitsiz=toplam - sayac["guvende"] - sayac["yardim"],
        ortalama_yanit_sn=(round(sum(sureler) / len(sureler)) if sureler else None),
        daireler=daire_listesi,
        personel=personel,
    )
