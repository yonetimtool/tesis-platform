"""(P202) ZORUNLU / ONERILEN GUNCELLEME — sunucu karar verir.

===========================================================================
NEDEN KARARI SUNUCU VERIR
===========================================================================
Politika, YENI SURUM YAYINLAMADAN degistirilebilmeli. Karari uygulama
verseydi, "1.2.0'in altini kilitle" demek icin once 1.2.0'i yayinlamak
ve kullanicilarin onu ALMASINI beklemek gerekirdi — yani tam da
ulasamadigimiz kullanicilar icin ise yaramazdi. Uygulama SORAR, sunucu
KARAR VERIR.

===========================================================================
KONTROL UCU PUBLIC — VE BU ZORUNLU
===========================================================================
Kontrol GIRISTEN ONCE calisir. Sebebi tam da ozelligin varlik sebebi:
kirici bir API degisikligi yapildiysa eski istemci GIRIS BILE
YAPAMAYABILIR. Kimlik arkasina koysaydik, en cok ihtiyac duyulan
durumda ekran hic gosterilemezdi.

SIZDIRDIGI BILGI: magazadaki en son surum numaralari — yani zaten
herkese acik olan sayilar. Tesis, kullanici ya da kisisel veri yok.

===========================================================================
YANIT MAGAZA ADRESINI DE TASIR
===========================================================================
Adres istemcide sabitlenseydi, magaza baglantisi degistiginde (paket adi,
App Store id) eski istemciler KIRIK bir dugmeye basardi — hem de tam
"guncelle" demeye calisirken. Adres `settings`ten gelir.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Header
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..ceviri import DESTEKLENEN_DILLER, dil_sec
from ..config import settings
from ..db import SessionLocal
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, SurumPolitikasi
from ..schemas import (
    SurumKontrolIstek,
    SurumKontrolYanit,
    SurumPolitikasiListesi,
    SurumPolitikasiOut,
    SurumPolitikasiUpdate,
)
from ..surum import karar

router = APIRouter(tags=["surum"])

_ADMIN = require_role("admin")

#: Politika PLATFORM GENELIDIR: `tenant_id` tasimaz, RLS'i yoktur.
PLATFORMLAR = ("ios", "android")


def _magaza_url(platform: str) -> str | None:
    """Platforma gore magaza adresi. BOS ise `None` — uydurma/kirik bir
    baglanti hic baglanti gondermemekten kotudur (`config.py` ayni
    kurali tasiyor)."""
    url = settings.app_store_url if platform == "ios" else settings.play_store_url
    return url.strip() or None


@router.post("/surum/kontrol", response_model=SurumKontrolYanit)
async def kontrol(
    body: SurumKontrolIstek,
    accept_language: str | None = Header(default=None, alias="Accept-Language"),
) -> SurumKontrolYanit:
    """Uygulama acilista ve on plana gelince cagirir.

    KIMLIK GEREKTIRMEZ (bkz. modul basligi).

    KENDI OTURUMUNU ACAR (`get_tenant_db` DEGIL): istek pre-auth'tur,
    tenant baglami YOKTUR ve tablo zaten tenant-disidir.
    """
    platform = body.platform if body.platform in PLATFORMLAR else None
    if platform is None:
        # Bilinmeyen platform (web, masaustu, gelecekteki bir yuzey):
        # POLITIKA YOK demektir, HATA degil. Hata dondurmek, istemcinin
        # hata dalina duserek... hicbir sey yapmamasina yol acardi —
        # ayni sonuc, ama gurultulu.
        return SurumKontrolYanit(durum="guncel")

    async with SessionLocal() as session:
        satir = (
            await session.execute(
                select(SurumPolitikasi).where(
                    SurumPolitikasi.platform == platform
                )
            )
        ).scalar_one_or_none()

    asgari = satir.asgari_surum if satir else None
    onerilen = satir.onerilen_surum if satir else None
    sonuc = karar(body.surum, asgari, onerilen)
    if sonuc == "guncel":
        # Guncel istemciye mesaj/adres GONDERILMEZ: gereksiz veri, ve
        # istemcinin yanlislikla ekran cizmesine zemin hazirlar.
        return SurumKontrolYanit(durum="guncel")

    mesaj = None
    if satir and satir.mesaj:
        dil = dil_sec(
            accept_language=accept_language,
            kaynak_dil="tr",
        )
        # Secilen dil yoksa TR'ye, o da yoksa NONE'a duser: metin
        # zorunlu degil (uygulamanin kendi yerellestirilmis metni var).
        metin = satir.mesaj.get(dil) or satir.mesaj.get("tr")
        mesaj = (metin or "").strip() or None

    return SurumKontrolYanit(
        durum=sonuc,
        mesaj=mesaj,
        magaza_url=_magaza_url(platform),
        asgari_surum=asgari,
        onerilen_surum=onerilen,
    )


# ============================ PANEL YONETIMI ================================ #
@router.get("/surum-politikasi", response_model=SurumPolitikasiListesi)
async def politika_listesi(
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> SurumPolitikasiListesi:
    """Iki platformun politikasi — PLATFORM ADMINI (panel.*)."""
    satirlar = (
        await db.execute(
            select(SurumPolitikasi).order_by(SurumPolitikasi.platform)
        )
    ).scalars().all()
    return SurumPolitikasiListesi(
        ogeler=[SurumPolitikasiOut.model_validate(s) for s in satirlar]
    )


@router.put("/surum-politikasi/{platform}", response_model=SurumPolitikasiOut)
async def politika_guncelle(
    platform: str,
    body: SurumPolitikasiUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> SurumPolitikasiOut:
    """Esikleri ve mesaji guncelle.

    SEMA DOGRULAMASI (`SurumPolitikasiUpdate`) gecersiz bir surum
    metnini BURADA reddeder. Sessizce kabul edip `surum.py`nin
    "gecersiz esik = yok say" davranisina birakmak, operatore
    "kaydedildi" deyip politikayi calistirmamak olurdu.
    """
    if platform not in PLATFORMLAR:
        raise APIError(422, "validation_error", "platform_gecersiz")
    satir = (
        await db.execute(
            select(SurumPolitikasi).where(SurumPolitikasi.platform == platform)
        )
    ).scalar_one_or_none()
    if satir is None:
        satir = SurumPolitikasi(platform=platform)
        db.add(satir)
    veri = body.model_dump(exclude_unset=True)
    for k, v in veri.items():
        setattr(satir, k, v)
    await db.flush()
    await db.refresh(satir)
    await audit_user(
        db, user, Action.PLATFORM_AYAR_UPDATE, resource_type="surum_politikasi",
        resource_id=None, meta={"platform": platform, "degisen": sorted(veri)},
    )
    return SurumPolitikasiOut.model_validate(satir)


#: Panelin dil secicisiyle AYNI kume — mesaj alani bu dilleri kabul eder.
MESAJ_DILLERI = DESTEKLENEN_DILLER
