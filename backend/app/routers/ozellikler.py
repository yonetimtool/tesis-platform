"""(P221) GENEL OZELLIK BAYRAKLARI — istemcinin acilista okudugu yuzey.

===========================================================================
NEDEN AYRI BIR UC
===========================================================================
Bir ozelligi acmak/kapatmak SUNUCUNUN karari olmali. Bayrak uygulamanin
icinde olsaydi, acmak icin YENI SURUM ve MAGAZA TURU gerekirdi — ve
magaza incelemesi gunler surer. Yayinlanmis bir sekmeyi ayni gun acmak
ancak sunucudan mumkun.

`POST /surum/kontrol`a EKLENMEDI: o uc "surumun guncel mi" sorusunu
yanitliyor ve yanitini bir POLITIKA TABLOSUNDAN aliyor. Ozellik
bayraklari ortam yapilandirmasindan geliyor; iki farkli kaynagi tek
yanitta toplamak, birinin degismesi digerinin onbellegini de bozmasi
demekti.

===========================================================================
KIMLIK GEREKTIRMEZ — VE BU BILINCLI
===========================================================================
Istemci bu ucu OTURUM ACMADAN, acilista cagiriyor: hangi sekmelerin
gorunecegi giris ekranindan once belli olmali. Yanit hicbir tesise ya da
kisiye ozel veri TASIMIYOR — yalniz "su ozellik acik mi".

===========================================================================
VARSAYILAN KAPALI
===========================================================================
Yanit uretilemezse (ag hatasi, uc yok, eski sunucu) istemci KAPALI
varsayar. Bu, ozelligin sessizce acilmasindan iyidir: hazir olmayan bir
yuzeyi kullaniciya gostermektense gostermemek yeglenir.
"""
from __future__ import annotations

from fastapi import APIRouter

from ..config import settings
from ..schemas import OzellikBayraklari

router = APIRouter(tags=["ozellikler"])


@router.get("/ozellikler", response_model=OzellikBayraklari)
async def ozellikler() -> OzellikBayraklari:
    """Istemcinin acilista okudugu ozellik bayraklari.

    Doner: `{"dukkan": bool}`

    YENI BAYRAK EKLERKEN: alani `OzellikBayraklari`ya VARSAYILANIYLA
    ekleyin. Eski istemciler bilmedikleri alani yok sayar; yeni
    istemciler eski sunucudan alani almadiginda kendi varsayilanini
    kullanir. Iki yonde de kirilma olmaz.
    """
    return OzellikBayraklari(dukkan=settings.dukkan_mobil_acik)
