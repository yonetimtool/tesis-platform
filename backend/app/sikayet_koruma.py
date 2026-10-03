"""(P253 §D) Daire sikayeti — KOTUYE KULLANIMA KARSI KORUMA.

Gizlilik karari: sikayet edenin kimligi HICBIR site rolune donmez (yonetici
dahil). Kimlik gizli kalinca tek bir kisinin sistemi bir komsuya karsi
silah gibi kullanmasi kolaylasir; bu modul o kapiyi KIMLIK ACMADAN kapatir:

1. ESIK FARKLI KAYNAK DAIRE SAYAR (`kaynak_ifadesi`): bir kisinin bes
   sikayeti esigi dolduramaz, bes farkli daireden gelen bes sikayet
   doldurur. Kaynak = sikayetin geldigi daire (`kaynak_unit_id`); eski,
   dairesi bulunamayan satirda kisinin kendisi.

2. GUNLUK SINIRLAR (`olusturma_siniri`) — varsayilanlar ve gerekcesi:
     * ayni kisi -> ayni daire 24 saatte en fazla 2 (`GUNLUK_DAIRE_SINIRI`):
       bir gecede iki ayri olay (aksam + gece yarisi) olagandir; ucuncusu
       artik bildirim degil baskidir.
     * ayni kisi 24 saatte toplam en fazla 5 (`GUNLUK_TOPLAM_SINIRI`):
       bir sakinin bir gunde bes farkli daireyle sorun yasamasi nadirdir;
       siniri gercek kullaniciya degil toplu atisa koyar.
   Mevcut kural (ayni daire + ayni kategori 7 gunde 1) aynen durur.

3. "ASILSIZ" ISARETI kademesi — kisi basina, son 90 gun (`PENCERE_GUN`):
     * ESIK DISI: en az 2 asilsiz VE sikayetlerinin en az yarisi asilsiz.
       Sikayeti kaydedilir, listede gorunur ama ESIGE SAYILMAZ. Tek bir
       hatali isaret kimseyi susturmaz (2), cok sikayet edip birkaci
       asilsiz cikan gercek magdur da etkilenmez (oran).
     * ASKIDA: en az 4 asilsiz VE oran en az %60 -> son isaretten 14 gun
       (`ASKI_GUN`) yeni sikayet acamaz. Iki hafta, "bir sonraki hafta
       sonu partisi"ni kapsar ama kisiyi kalici olarak sistemden atmaz.
   Durum SAKLANMAZ, her seferinde HESAPLANIR: isaret geri alinca ya da
   pencere gecince kisitlama KENDILIGINDEN kalkar; elle kaldirilacak bir
   bayrak, unutulacak bir bayraktir.

Yonetim KIMIN oldugunu bu moduldan de ogrenmez: kaynak ozeti yalniz SAYI
ve "tek kaynak yogun" isareti verir — "Kaynak A" gibi etiket bile yok
(etiket, iki ozet arasinda kisiyi izlemeye yeterdi).
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .errors import APIError
from .models import AppUser, Unit, UnitComplaint, UnitResident

GUNLUK_DAIRE_SINIRI = 2
GUNLUK_TOPLAM_SINIRI = 5
PENCERE_GUN = 90
ESIK_DISI_ASILSIZ = 2
ESIK_DISI_ORAN = 0.5
ASKI_ASILSIZ = 4
ASKI_ORAN = 0.6
ASKI_GUN = 14
#: Yonetimin gordugu oruntu penceresi ve "tek kaynak yogun" kurali:
#: en az 4 sikayet VE en az %75'i tek kaynaktan.
OZET_GUN = 30
TEK_KAYNAK_ASGARI = 4
TEK_KAYNAK_ORAN = 0.75


def kaynak_ifadesi():
    """Sikayetin KAYNAGI: daire; eski satirda dairesi yoksa kisi."""
    return func.coalesce(UnitComplaint.kaynak_unit_id, UnitComplaint.complainant_user_id)


@dataclass(frozen=True)
class KaynakDurumu:
    toplam: int
    asilsiz: int
    son_asilsiz: datetime | None

    @property
    def oran(self) -> float:
        return self.asilsiz / self.toplam if self.toplam else 0.0

    @property
    def esik_disi(self) -> bool:
        return self.asilsiz >= ESIK_DISI_ASILSIZ and self.oran >= ESIK_DISI_ORAN

    def askida_bitis(self, simdi: datetime) -> datetime | None:
        if self.asilsiz < ASKI_ASILSIZ or self.oran < ASKI_ORAN or self.son_asilsiz is None:
            return None
        bitis = self.son_asilsiz + timedelta(days=ASKI_GUN)
        return bitis if bitis > simdi else None


def _pencere_basi(simdi: datetime | None = None) -> datetime:
    return (simdi or datetime.now(tz=timezone.utc)) - timedelta(days=PENCERE_GUN)


async def kaynak_durumu(db: AsyncSession, user_id: uuid.UUID) -> KaynakDurumu:
    """Kisinin son 90 gundeki sikayet/asilsiz sayilari (geri cekilenler haric)."""
    toplam, asilsiz, son = (
        await db.execute(
            select(
                func.count(UnitComplaint.id),
                func.count(UnitComplaint.asilsiz_at),
                func.max(UnitComplaint.asilsiz_at),
            ).where(
                UnitComplaint.complainant_user_id == user_id,
                UnitComplaint.created_at >= _pencere_basi(),
                UnitComplaint.durum != "geri_alindi",
            )
        )
    ).one()
    return KaynakDurumu(toplam=int(toplam), asilsiz=int(asilsiz), son_asilsiz=son)


def esik_disi_kisiler():
    """ESIGE SAYILMAYAN kisiler (alt sorgu) — `KaynakDurumu.esik_disi` ile AYNI kural."""
    asilsiz = func.count(UnitComplaint.asilsiz_at)
    return (
        select(UnitComplaint.complainant_user_id)
        .where(
            UnitComplaint.created_at >= _pencere_basi(),
            UnitComplaint.durum != "geri_alindi",
        )
        .group_by(UnitComplaint.complainant_user_id)
        .having(
            and_(
                asilsiz >= ESIK_DISI_ASILSIZ,
                # oran >= ESIK_DISI_ORAN, tamsayi aritmetigiyle:
                asilsiz * 100 >= func.count(UnitComplaint.id) * int(ESIK_DISI_ORAN * 100),
            )
        )
    )


def esige_sayilir_kosullari() -> list:
    """Esik sayacinin ve gorunur sayimin ORTAK suzgeci: asilsiz isaretli
    sikayet ve esik disi kisinin sikayeti SAYILMAZ."""
    return [
        UnitComplaint.asilsiz_at.is_(None),
        UnitComplaint.complainant_user_id.not_in(esik_disi_kisiler()),
    ]


async def kaynak_dairesi(
    db: AsyncSession, user: AppUser, hedef: Unit
) -> uuid.UUID | None:
    """Sikayetin geldigi daire: kisinin AKTIF dairelerinden hedefin
    blogundaki ilki (deterministik — ayni kisi hep ayni kaynak)."""
    return (
        await db.execute(
            select(UnitResident.unit_id)
            .join(Unit, Unit.id == UnitResident.unit_id)
            .where(UnitResident.user_id == user.id, UnitResident.bitis.is_(None))
            .order_by(
                case((Unit.blok.is_not_distinct_from(hedef.blok), 0), else_=1),
                UnitResident.unit_id,
            )
            .limit(1)
        )
    ).scalar_one_or_none()


async def olusturma_siniri(
    db: AsyncSession, user: AppUser, hedef_unit_id: uuid.UUID
) -> None:
    """Yeni sikayetten ONCE (cagiran kisi-basi kilidi tutarken) cagrilir.
    Sinir asilirsa 429 — metinler kibar, hata gibi degil (hata_metinleri)."""
    simdi = datetime.now(tz=timezone.utc)
    durum = await kaynak_durumu(db, user.id)
    bitis = durum.askida_bitis(simdi)
    if bitis is not None:
        raise APIError(429, "rate_limited", "sikayet_askida", tarih=bitis.date().isoformat())
    gun_basi = simdi - timedelta(hours=24)
    toplam, ayni = (
        await db.execute(
            select(
                func.count(UnitComplaint.id),
                func.count(UnitComplaint.id).filter(
                    UnitComplaint.target_unit_id == hedef_unit_id
                ),
            ).where(
                UnitComplaint.complainant_user_id == user.id,
                UnitComplaint.created_at >= gun_basi,
            )
        )
    ).one()
    if ayni >= GUNLUK_DAIRE_SINIRI:
        raise APIError(429, "rate_limited", "sikayet_daire_gunluk_sinir", sayi=GUNLUK_DAIRE_SINIRI)
    if toplam >= GUNLUK_TOPLAM_SINIRI:
        raise APIError(429, "rate_limited", "sikayet_gunluk_sinir", sayi=GUNLUK_TOPLAM_SINIRI)


async def kaynak_ozeti(db: AsyncSession, unit_id: uuid.UUID) -> dict:
    """Yonetimin gordugu ORUNTU: son 30 gun, sayi + farkli kaynak + tek
    kaynak uyarisi. Kaynak ETIKETI yok."""
    sinir = datetime.now(tz=timezone.utc) - timedelta(days=OZET_GUN)
    kaynak = kaynak_ifadesi().label("kaynak")
    alt = (
        select(kaynak, func.count(UnitComplaint.id).label("n"))
        .where(
            UnitComplaint.target_unit_id == unit_id,
            UnitComplaint.created_at >= sinir,
            UnitComplaint.durum != "geri_alindi",
            UnitComplaint.asilsiz_at.is_(None),
        )
        .group_by(kaynak_ifadesi())
        .subquery()
    )
    sayi, farkli, en_cok = (
        await db.execute(
            select(
                func.coalesce(func.sum(alt.c.n), 0),
                func.count(),
                func.coalesce(func.max(alt.c.n), 0),
            ).select_from(alt)
        )
    ).one()
    asilsiz = (
        await db.execute(
            select(func.count(UnitComplaint.id)).where(
                UnitComplaint.target_unit_id == unit_id,
                UnitComplaint.created_at >= sinir,
                UnitComplaint.asilsiz_at.is_not(None),
            )
        )
    ).scalar_one()
    sayi, farkli, en_cok = int(sayi), int(farkli), int(en_cok)
    return {
        "gun": OZET_GUN,
        "sikayet_sayisi": sayi,
        "farkli_kaynak": farkli,
        "tek_kaynak_yogun": sayi >= TEK_KAYNAK_ASGARI and en_cok >= sayi * TEK_KAYNAK_ORAN,
        "asilsiz_sayisi": int(asilsiz),
    }


__all__ = [
    "ASKI_GUN", "GUNLUK_DAIRE_SINIRI", "GUNLUK_TOPLAM_SINIRI", "KaynakDurumu",
    "esige_sayilir_kosullari", "kaynak_dairesi", "kaynak_durumu", "kaynak_ifadesi",
    "kaynak_ozeti", "olusturma_siniri",
]
