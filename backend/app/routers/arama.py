"""(P154 / Asama 6.3) GLOBAL ARAMA — tek uc, cok kaynak.

===========================================================================
EN ONEMLI KURAL: ARAMA YENI BIR YETKI YUZEYI ACMAZ
===========================================================================
Brief: "Tenant izolasyonu ve rol yetkisi arama sonuclarinda da gecerli —
kullanici goremeyecegi bir kaydi arama sonucunda GORMEMELI."

Bu, arama uclarinin klasik sizinti sinifidir: liste uclari rol kapili
yazilir, sonra arama "hepsini tarayan" tek bir sorgu olarak eklenir ve
sessizce herkesi her seye ulastirir. Burada iki katman var:

  1. TENANT — `get_tenant_db` + RLS. Her sorgu zaten tenant'a kapali;
     bu katman icin BURADA ek bir sey yapilmiyor (yapilsaydi ikinci bir
     dogruluk kaynagi olurdu).

  2. ROL — `KAYNAKLAR` tablosundaki rol kumeleri, ilgili ROUTER'IN kendi
     `require_role` kumesinden OKUNUR, yeniden yazilmaz. `users._READER`
     degistiginde arama da kendiliginden degisir; iki liste ayrisamaz.
     `test_arama.py::test_rol_kumeleri_ROUTERLARLA_AYNI` bunu kilitler.

  3. SATIR KAPSAMI — rol kumesi yetmez. `complaint`te saha ve sakin
     roller YALNIZ KENDI actiklarini gorur (`complaints._own_scope`).
     Arama bunu tekrar etmek zorunda; etmeseydi bir sakin, komsusunun
     talebini arama kutusundan okurdu.

===========================================================================
NEDEN TEK UC, NEDEN HER EKRANA AYRI ARAMA DEGIL
===========================================================================
Brief: "Merkezi kur, her ekrana ayri arama yazma." Ayri yazilsaydi yetki
kurali sekiz yerde tekrar edilirdi ve biri unutuldugunda sizinti SESSIZ
olurdu — arama sonucu "fazladan" bir kayit gostermek hicbir hata
uretmez, yalnizca gormemesi gereken birine gosterir.
"""
from __future__ import annotations

import uuid
from typing import Callable, NamedTuple

from fastapi import APIRouter, Depends, Query
from sqlalchemy import Select, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_current_user, get_tenant_db
from ..models import (
    AppUser,
    Announcement,
    BuildingBlock,
    Complaint,
    FinansalHareket,
    Firma,
    Task,
    Unit,
)
from ..schemas import AramaSonucu, AramaVurusu

# Rol kumeleri ILGILI ROUTERDAN import edilir — kopyalanmaz.
from .announcements import _READER as _DUYURU_ROLLERI
from .blocks import _READER as _BLOK_ROLLERI
from .complaints import _OWN_SCOPED_ROLES, _READER as _TALEP_ROLLERI
from .finans import _OKUMA as _FINANS_ROLLERI
from .muhasebe_tanimlari import _TANIM_OKUR as _FIRMA_ROLLERI
from .tasks import _READER as _GOREV_ROLLERI
from .units import _LAYOUT_READER as _DAIRE_ROLLERI
from .users import _READER as _KISI_ROLLERI

router = APIRouter(tags=["arama"])

#: Kaynak basina en fazla vurus. Sinirsiz birakmak, tek harflik bir
#: aramanin butun tesisi cekmesi demekti.
_KAYNAK_SINIRI = 5


class Kaynak(NamedTuple):
    ad: str
    roller: frozenset[str]
    #: (aranan, kullanici) -> SELECT. Kullanici SATIR KAPSAMI icin gerekli.
    sorgu: Callable[[str, AppUser], Select]


def _rol_kumesi(bagimlilik) -> frozenset[str]:
    """`require_role(...)` bagimligindan izinli rolleri OKUR.

    `require_role` kumeyi zaten `izinli_roller` OZNITELIGI olarak aciyor
    (P41 — "yetki matrisini KODUN KENDISINDEN uretebilmek"). Burada onu
    okumak, ayni gercegi ikinci bir yerden yazmamak demek: bir routerin
    rol kumesi degistiginde arama kendiliginden ayni degisimi alir.
    """
    roller = getattr(bagimlilik, "izinli_roller", None)
    if not roller:
        raise RuntimeError("rol kumesi okunamadi: `izinli_roller` yok")
    return frozenset(roller)


def _kisi(q: str, _u: AppUser) -> Select:
    return (
        select(AppUser.id, AppUser.ad, AppUser.telefon)
        .where(or_(AppUser.ad.ilike(q), AppUser.email.ilike(q), AppUser.telefon.ilike(q)))
        .order_by(AppUser.ad, AppUser.id)
    )


def _daire(q: str, _u: AppUser) -> Select:
    return (
        select(Unit.id, Unit.no, Unit.blok)
        .where(or_(Unit.no.ilike(q), Unit.blok.ilike(q)))
        .order_by(Unit.no, Unit.id)
    )


def _blok(q: str, _u: AppUser) -> Select:
    return (
        select(BuildingBlock.id, BuildingBlock.ad, BuildingBlock.ad)
        .where(BuildingBlock.ad.ilike(q))
        .order_by(BuildingBlock.ad, BuildingBlock.id)
    )


def _firma(q: str, _u: AppUser) -> Select:
    return (
        select(Firma.id, Firma.ad, Firma.telefon)
        .where(or_(Firma.ad.ilike(q), Firma.telefon.ilike(q)))
        .order_by(Firma.ad, Firma.id)
    )


def _gorev(q: str, _u: AppUser) -> Select:
    return (
        select(Task.id, Task.ad, Task.aciklama)
        .where(or_(Task.ad.ilike(q), Task.aciklama.ilike(q)))
        .order_by(Task.ad, Task.id)
    )


def _duyuru(q: str, _u: AppUser) -> Select:
    return (
        select(Announcement.id, Announcement.baslik, Announcement.govde)
        .where(or_(Announcement.baslik.ilike(q), Announcement.govde.ilike(q)))
        .order_by(Announcement.created_at.desc(), Announcement.id)
    )


def _talep(q: str, user: AppUser) -> Select:
    s = (
        select(Complaint.id, Complaint.baslik, Complaint.mesaj)
        .where(or_(Complaint.baslik.ilike(q), Complaint.mesaj.ilike(q)))
        .order_by(Complaint.created_at.desc(), Complaint.id)
    )
    # SATIR KAPSAMI — `complaints._own_scope` ile AYNI kural. Rol kumesi
    # tek basina yetmez: `resident` talepleri "gorebilir" ama YALNIZ
    # kendininkileri. Bu satir olmadan sakin, komsusunun talebini arama
    # kutusundan okurdu.
    if user.role in _OWN_SCOPED_ROLES:
        s = s.where(Complaint.acan_user_id == user.id)
    return s


def _finans(q: str, _u: AppUser) -> Select:
    return (
        select(FinansalHareket.id, FinansalHareket.aciklama, FinansalHareket.belge_no)
        .where(
            or_(
                FinansalHareket.aciklama.ilike(q),
                FinansalHareket.belge_no.ilike(q),
            )
        )
        .order_by(FinansalHareket.created_at.desc(), FinansalHareket.id)
    )


KAYNAKLAR: tuple[Kaynak, ...] = (
    Kaynak("kisi", _rol_kumesi(_KISI_ROLLERI), _kisi),
    Kaynak("daire", _rol_kumesi(_DAIRE_ROLLERI), _daire),
    Kaynak("blok", _rol_kumesi(_BLOK_ROLLERI), _blok),
    Kaynak("firma", _rol_kumesi(_FIRMA_ROLLERI), _firma),
    Kaynak("gorev", _rol_kumesi(_GOREV_ROLLERI), _gorev),
    Kaynak("duyuru", _rol_kumesi(_DUYURU_ROLLERI), _duyuru),
    Kaynak("talep", _rol_kumesi(_TALEP_ROLLERI), _talep),
    Kaynak("finans", _rol_kumesi(_FINANS_ROLLERI), _finans),
)


@router.get("/arama", response_model=AramaSonucu)
async def arama(
    q: str = Query(min_length=2, max_length=100),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> AramaSonucu:
    """Cok kaynakli arama — YALNIZ kullanicinin gorebilecegi kayitlar.

    EN AZ IKI KARAKTER: tek harf butun tesisi tarar ve sonuc kullaniciya
    da bir sey anlatmaz.

    ROL KAPISI UC DUZEYINDE YOK ve bu bilincli: her tesis rolu en az bir
    kaynak gorebiliyor (duyuru herkese acik). Kapiyi uca koymak, sakinin
    duyuru aramasini da kapatirdi. Suzgec KAYNAK duzeyinde.
    """
    desen = f"%{q.strip()}%"
    vuruslar: list[AramaVurusu] = []

    for kaynak in KAYNAKLAR:
        if user.role not in kaynak.roller:
            continue
        satirlar = (
            await db.execute(kaynak.sorgu(desen, user).limit(_KAYNAK_SINIRI))
        ).all()
        for r in satirlar:
            kimlik: uuid.UUID = r[0]
            vuruslar.append(
                AramaVurusu(
                    kaynak=kaynak.ad,
                    id=kimlik,
                    baslik=str(r[1] or "—"),
                    # IKINCIL alan bos gecilebilir; `None` yazmak
                    # kullaniciya "None" metnini gostermek olurdu.
                    ayrinti=str(r[2]) if r[2] else None,
                )
            )

    return AramaSonucu(q=q, items=vuruslar)
