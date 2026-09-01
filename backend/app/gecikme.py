"""(P192 §3.1) GECIKME FAIZI — hesaplanan degil, YAZILAN borc.

===========================================================================
OLCULEN KUSUR
===========================================================================
`docs/finans-analiz.md`: gecikme faizi iki yerde hesaplaniyordu
(`routers/dues.py` liste zenginlestirmesi ve `rapor_motoru`) ama HICBIR
YERE YAZILMIYORDU. Sonuc: sakin ana borcunu odeyince faiz buharlasiyordu.
Tahsil edilebilir bir kalem degildi, ekranda gorunen bir sayiydi.

===========================================================================
KARAR: FAIZ AYRI BIR TAHAKKUK KALEMIDIR
===========================================================================
Faiz `dues_assessment`e `kalem_tipi='faiz'` bir satir olarak yazilir ve
hangi borctan dogdugunu `kaynak_assessment_id` ile tasir. Boylece:

  * bakiyeye girer (bakiye = tahakkuk - odenen),
  * tahsil edilebilir (tahsilat `assessment_id`ye baglanir),
  * affedilebilir (ters kayit; bkz. §6.3) ve affin izi kalir,
  * "bu ay ne kadar faiz tahakkuk etti" sorusu cevaplanabilir.

Alternatif "ana borcun tutarini artirmak"ti; o zaman ana para ile faiz
ayirt edilemez, kismi odeme hangisine sayildi belirsiz kalir ve faiz affi
imkansizlasirdi.

===========================================================================
IDEMPOTENCY — GOREV IKI KEZ KOSARSA
===========================================================================
Faiz kalemi DONEM basina tekildir: `uq_assessment_faiz_donem`
(tenant, kaynak_assessment_id, donem) kismi indeksi. Ayni ay icin ikinci
bir faiz kalemi acilamaz.

Her kosum FARKI yazar: o ana kadar birikmis toplam faiz eksi daha once
yazilmis faiz. Boylece aylik kosum faizi ARTIRARAK ilerler, tekrarli
kosum ise 0 fark bulur ve hicbir sey yazmaz.

===========================================================================
FAIZE FAIZ ISLEMEZ
===========================================================================
Yazilan faiz kalemi `gecikme_uygula=False` tasir. Aksi halde bir sonraki
kosum faizin faizini hesaplar ve BASIT faiz kurali (bkz.
`borclandirma.gecikme_kurus`) sessizce BILESIGE donerdi.
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from . import defter
from .borclandirma import gecikme_kurus
from .models import DuesAssessment, Tenant, Unit

#: Faiz HESAPLANMAYAN kalemler. Faizin kendisi listede: faize faiz islemez.
HARIC_KALEMLER = ("faiz",)


@dataclass(frozen=True)
class FaizSatiri:
    """Bir borc icin hesaplanan faiz durumu."""

    assessment_id: uuid.UUID
    unit_id: uuid.UUID
    unit_no: str
    donem: str
    son_odeme_tarihi: date | None
    kalan_kurus: int
    #: O ana kadar BIRIKMIS toplam faiz.
    toplam_faiz_kurus: int
    #: Daha once yazilmis faiz kalemlerinin toplami.
    yazilmis_kurus: int

    @property
    def fark_kurus(self) -> int:
        """Bu kosumda YAZILACAK tutar."""
        return max(self.toplam_faiz_kurus - self.yazilmis_kurus, 0)


async def ayarlar(db: AsyncSession) -> tuple[bool, float]:
    """(uygula_mi, aylik_yuzde) — tesis ayari."""
    satir = (
        await db.execute(select(Tenant.gecikme_uygula, Tenant.gecikme_aylik_yuzde))
    ).first()
    if satir is None:
        return False, 0.0
    return bool(satir[0]), float(satir[1] or 0)


async def hesapla(
    db: AsyncSession, *, bugun: date | None = None
) -> list[FaizSatiri]:
    """Gecikmis her borc icin faiz durumunu hesapla (YAZMAZ).

    Onizleme ve isleme AYNI hesabi kullanir: yoneticiye gosterilen ile
    yazilan ayrilirsa, onizlemenin hicbir degeri kalmaz.
    """
    uygula, oran = await ayarlar(db)
    if not uygula or oran <= 0:
        return []
    bugun = bugun or date.today()

    borclar = (
        await db.execute(
            select(DuesAssessment, Unit.no)
            .join(Unit, Unit.id == DuesAssessment.unit_id)
            .where(
                DuesAssessment.gecikme_uygula.is_(True),
                DuesAssessment.son_odeme_tarihi.isnot(None),
                DuesAssessment.son_odeme_tarihi < bugun,
                DuesAssessment.kalem_tipi.notin_(HARIC_KALEMLER),
                # Ters kayitlanmis ve ters kayit olan satirlar borc DEGIL.
                *defter.gecerli_tahakkuk(),
            )
            .order_by(DuesAssessment.son_odeme_tarihi, DuesAssessment.id)
        )
    ).all()
    if not borclar:
        return []

    odenen = await defter.tahakkuk_odenen(
        db, [b.DuesAssessment.id for b in borclar]
    )
    yazilmis = dict(
        (
            await db.execute(
                select(
                    DuesAssessment.kaynak_assessment_id,
                    func.coalesce(func.sum(DuesAssessment.tutar_kurus), 0),
                )
                .where(
                    DuesAssessment.kalem_tipi == "faiz",
                    DuesAssessment.kaynak_assessment_id.isnot(None),
                    # AFFEDILMIS faiz "yazilmis" sayilmaz: affedilen tutar
                    # yeniden tahakkuk edebilmeli, aksi halde af bir daha
                    # geri alinamayan bir karar olurdu.
                    *defter.gecerli_tahakkuk(),
                )
                .group_by(DuesAssessment.kaynak_assessment_id)
            )
        ).all()
    )

    sonuc: list[FaizSatiri] = []
    for satir in borclar:
        borc: DuesAssessment = satir.DuesAssessment
        kalan = borc.tutar_kurus - odenen.get(borc.id, 0)
        if kalan <= 0:
            # KAPANMIS borca faiz ISLEMEZ (bu kosumdan sonrasi icin).
            # Gecmiste birikmis faiz zaten kalem olarak yazilidir ve
            # ayakta kalir — borcun kapanmasi faizi silmez.
            continue
        toplam = gecikme_kurus(
            kalan, borc.son_odeme_tarihi, bugun, oran,
            uygula=borc.gecikme_uygula,
        )
        sonuc.append(
            FaizSatiri(
                assessment_id=borc.id,
                unit_id=borc.unit_id,
                unit_no=satir.no,
                donem=borc.donem,
                son_odeme_tarihi=borc.son_odeme_tarihi,
                kalan_kurus=kalan,
                toplam_faiz_kurus=toplam,
                yazilmis_kurus=int(yazilmis.get(borc.id, 0)),
            )
        )
    return sonuc


def faiz_donemi(bugun: date) -> str:
    """Faiz kaleminin yazilacagi MUHASEBE DONEMI = icinde bulunulan ay.

    Borcun kendi donemi DEGIL: Ocak aidatinin Mart'ta isleyen faizi Mart'in
    geliridir. Borcun donemine yazsaydik gecmis aylarin raporlari her
    kosumda geriye donuk degisirdi.
    """
    return f"{bugun.year}-{bugun.month:02d}"
