"""(P154 / Asama 6.4) NOT VE EK — tek uc, her varlik.

===========================================================================
YETKI: EK, ANA KAYDIN YETKISINI MIRAS ALIR
===========================================================================
Bir ekin gizliligi ana kaydinkiyle AYNIDIR. Daireye yazilmis bir not,
daireyi gorebilenlere aciktir; icra dosyasina yazilmis not ise yalnizca
finans okuyabilenlere. Ek sistemine KENDI rol kumesini yazmak, iki
gercek arasinda sessiz bir ayrisma uretirdi: ana kaydin yetkisi
degistiginde ekinki degismezdi.

Bu yuzden `VARLIKLAR` tablosu her varlik tipi icin ILGILI ROUTERIN kendi
`require_role` kumesini OKUR (6.3'teki arama ile ayni desen).

===========================================================================
UST KAYIT DOGRULANIR — polimorfik bagin bedeli burada odenir
===========================================================================
FK olmadigi icin veritabani "boyle bir daire var mi" diye soramaz. Uc
soruyor: ek yazilmadan once ust kayit AYNI TENANT'ta aranir (RLS zaten
tenant'a kapali) ve bulunamazsa 404. Bu kontrol olmasaydi:
  * rastgele bir UUID'ye ek takilabilir, hicbir ekranda gorunmeyen
    kayitlar birikirdi,
  * daha kotusu, ek YAZMAK bir VARLIK SORGUSU aracina donerdi ("bu id
    var mi" sorusu 201/404 farkindan okunurdu).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_current_user, get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    BuildingBlock,
    Complaint,
    Firma,
    IcraDosyasi,
    Task,
    TenantDokuman,
    Unit,
    VarlikEki,
)
from ..schemas import EkCreate, EkListResponse, EkOut

# Rol kumeleri ILGILI ROUTERDAN okunur — kopyalanmaz (bkz. modul basligi).
from .blocks import _MANAGER as _BLOK_YAZAR, _READER as _BLOK_OKUR
from .complaints import _MANAGER as _TALEP_YAZAR, _READER as _TALEP_OKUR
# (P206 §1) `_ADMIN` -> `_YAZMA`: finansal yazma yoneticiye acildi
# ve icra EKI de o kumeyi izler (kume ILGILI ROUTERDAN okunur,
# kopyalanmaz — modul basligindaki kural).
from .finans import _YAZMA as _ICRA_YAZAR, _OKUMA as _ICRA_OKUR
from .muhasebe_tanimlari import _TANIM_OKUR as _FIRMA_OKUR, _YONETIM as _FIRMA_YAZAR
from .tasks import _READER as _GOREV_OKUR, _WRITER as _GOREV_YAZAR
from .units import _LAYOUT_EDITOR as _DAIRE_YAZAR, _LAYOUT_READER as _DAIRE_OKUR
from .users import _READER as _KISI_OKUR, _USER_CREATOR as _KISI_YAZAR

router = APIRouter(prefix="/ekler", tags=["ekler"])

_YOK = APIError(404, "not_found", "kayit_bulunamadi")
_YETKI = APIError(403, "forbidden", "yetkiniz_yok")


def _roller(bagimlilik) -> frozenset[str]:
    """`require_role` bagimligindan izinli rolleri OKUR (P41 `izinli_roller`)."""
    roller = getattr(bagimlilik, "izinli_roller", None)
    if not roller:
        raise RuntimeError("rol kumesi okunamadi")
    return frozenset(roller)


class _Varlik:
    __slots__ = ("model", "okur", "yazar")

    def __init__(self, model, okur, yazar) -> None:
        self.model = model
        self.okur = _roller(okur)
        self.yazar = _roller(yazar)


#: Varlik tipi -> (model, okuma rolleri, yazma rolleri).
#: Anahtarlar goc 0043'teki `ck_varlik_eki_tipi` CHECK kumesiyle AYNI
#: olmali; `test_ekler.py::test_varlik_tipleri_GOCLE_AYNI` bunu kilitler.
VARLIKLAR: dict[str, _Varlik] = {
    "unit": _Varlik(Unit, _DAIRE_OKUR, _DAIRE_YAZAR),
    "app_user": _Varlik(AppUser, _KISI_OKUR, _KISI_YAZAR),
    "task": _Varlik(Task, _GOREV_OKUR, _GOREV_YAZAR),
    "icra_dosyasi": _Varlik(IcraDosyasi, _ICRA_OKUR, _ICRA_YAZAR),
    "tenant_dokuman": _Varlik(TenantDokuman, _BLOK_OKUR, _BLOK_YAZAR),
    "complaint": _Varlik(Complaint, _TALEP_OKUR, _TALEP_YAZAR),
    "firma": _Varlik(Firma, _FIRMA_OKUR, _FIRMA_YAZAR),
    "building_block": _Varlik(BuildingBlock, _BLOK_OKUR, _BLOK_YAZAR),
}


#: YAZMA UCLARININ ROL KAPISI — sekiz varligin yazar kumelerinin BIRLESIMI.
#:
#: Asil karar per-varlik verilir (`_ust_kaydi_dogrula`); bu kapi onun yerine
#: GECMEZ, ONUNDE durur. Neden gerekli: rol kapisi OLMAYAN bir uc, yonlendirme
#: katmaninda HERKESE aciktir ve korunmasi yalnizca govdedeki mantiga kalir —
#: `test_denetci_salt_okuma::test_ROL_KAPISI_OLMAYAN_mutasyon_uclari` bunu
#: (hakli olarak) kusur sayar. Denetci hicbir yazar kumesinde olmadigi icin
#: kapi onu burada, sorgu bile yapilmadan durdurur.
#:
#: BIRLESIM ELLE YAZILMADI: `VARLIKLAR`tan turetiliyor. Elle yazilsaydi bir
#: routerin yazar kumesi degistiginde burasi eskir ve ya fazladan rol gecer
#: ya da mesru bir rol kapida kalirdi.
_YAZABILENLER: frozenset[str] = frozenset().union(
    *(v.yazar for v in VARLIKLAR.values())
)
_YAZMA_KAPISI = require_role(*sorted(_YAZABILENLER))


async def _ust_kaydi_dogrula(
    db: AsyncSession, varlik_tipi: str, varlik_id: uuid.UUID, user: AppUser, yazma: bool
) -> None:
    """Varlik tipi taninir mi, rol yeter mi, ust kayit VAR mi.

    SIRA ONEMLI: rol kapisi VARLIK SORGUSUNDAN ONCE. Once sorgulasaydik,
    yetkisiz bir cagiran 403 ile 404 farkindan "boyle bir kayit var mi"
    sorusunu yanitlayabilirdi.
    """
    v = VARLIKLAR.get(varlik_tipi)
    if v is None:
        raise APIError(422, "validation_error", "varlik_tipi_gecersiz")
    if user.role not in (v.yazar if yazma else v.okur):
        raise _YETKI
    # RLS tenant'i zaten kapatiyor; burada YALNIZ varlik sorgulaniyor.
    varmi = (
        await db.execute(select(v.model.id).where(v.model.id == varlik_id))
    ).first()
    if varmi is None:
        raise _YOK


@router.get("", response_model=EkListResponse)
async def listele(
    varlik_tipi: str = Query(...),
    varlik_id: uuid.UUID = Query(...),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> EkListResponse:
    """Bir varligin notlari + dosyalari — TEK zaman cizgisi, eskiden yeniye."""
    await _ust_kaydi_dogrula(db, varlik_tipi, varlik_id, user, yazma=False)
    satirlar = (
        await db.execute(
            select(VarlikEki, AppUser.ad)
            .join(AppUser, AppUser.id == VarlikEki.olusturan_user_id, isouter=True)
            .where(
                VarlikEki.varlik_tipi == varlik_tipi,
                VarlikEki.varlik_id == varlik_id,
            )
            .order_by(VarlikEki.created_at.asc(), VarlikEki.id)
        )
    ).all()
    return EkListResponse(
        items=[
            EkOut(
                id=e.id,
                tur=e.tur,
                metin=e.metin,
                dosya_key=e.dosya_key,
                dosya_adi=e.dosya_adi,
                olusturan_ad=ad,
                created_at=e.created_at,
            )
            for e, ad in satirlar
        ]
    )


@router.post("", response_model=EkOut, status_code=201)
async def ekle(
    body: EkCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA_KAPISI),
) -> EkOut:
    """Not ya da dosya ekler.

    DOSYA YUKLEME BURADA YAPILMAZ: istemci once `POST /uploads/presign`
    ile imzali URL alir, dosyayi DOGRUDAN depoya koyar, sonra donen
    anahtari buraya yazar. Ikinci bir yukleme yolu yazmak, boyut/tur
    dogrulamasini iki yerde tutmak olurdu.
    """
    await _ust_kaydi_dogrula(db, body.varlik_tipi, body.varlik_id, user, yazma=True)
    obj = VarlikEki(
        tenant_id=user.tenant_id,
        varlik_tipi=body.varlik_tipi,
        varlik_id=body.varlik_id,
        tur=body.tur,
        metin=body.metin,
        dosya_key=body.dosya_key,
        dosya_adi=body.dosya_adi,
        olusturan_user_id=user.id,
    )
    db.add(obj)
    await db.flush()
    await db.refresh(obj)
    return EkOut(
        id=obj.id,
        tur=obj.tur,
        metin=obj.metin,
        dosya_key=obj.dosya_key,
        dosya_adi=obj.dosya_adi,
        olusturan_ad=user.ad,
        created_at=obj.created_at,
    )


@router.delete("/{ek_id}", status_code=204)
async def sil(
    ek_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YAZMA_KAPISI),
):
    """Eki siler.

    KIM SILEBILIR: ekin SAHIBI ya da ana kayda YAZMA yetkisi olan. Yalniz
    sahibe birakmak, isten ayrilan bir personelin notlarini kalici
    kilardi; yalniz yoneticiye birakmak ise kisinin kendi yazdigi notu
    duzeltmesini engellerdi.
    """
    obj = (
        await db.execute(select(VarlikEki).where(VarlikEki.id == ek_id))
    ).scalar_one_or_none()
    if obj is None:
        raise _YOK
    v = VARLIKLAR.get(obj.varlik_tipi)
    if v is None:
        raise _YOK
    if obj.olusturan_user_id != user.id and user.role not in v.yazar:
        raise _YETKI
    await db.delete(obj)
    return Response(status_code=204)
