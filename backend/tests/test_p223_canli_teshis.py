"""(P223 §2) CANLI YAYIN — YANLIS TESHIS DUZELTILDI.

===========================================================================
OLCULEN DAVRANIS (dev, gercek RTSP kaynagi `rtsp://testcam:8554/cam`)
===========================================================================
Eski kod playlist istegini 15 sn zaman asimiyla atiyordu ve
`sourceOnDemand` geregi MediaMTX istegi kaynak hazir olana kadar ASILI
tutuyordu. Olculen:

    istek 1: 502 (15 132 ms)  server_config   <- YANLIS TESHIS
    istek 2: 502 (15 117 ms)  server_config   <- YANLIS TESHIS
    istek 3: 200 (10 243 ms)  PLAYLIST

Yani ILK TIKLAMA HER ZAMAN BASARISIZDI ve ustune "canli yayin SUNUCU
tarafinda yapilandirilmamis" deniyordu — yonetici HICBIR SORUNU OLMAYAN
MediaMTX kurulumunu duzeltmeye gonderiliyordu.

Dogrudan MediaMTX'e olcum, tekrar denemenin COZUM DEGIL SEBEP oldugunu
gosterdi (her zaman asimi bekleyen istegi iptal edip on-demand dongusunu
sifirdan baslatiyor):

    dongu (12 sn x N) : 41.2 sn sonra 200
    TEK istek (60 sn) : 33.8 sn sonra 200

Duzeltme sonrasi UCTAN UCA: soguk baslangicta ILK TIKLAMA 200 (36.3 sn),
`content-type: application/vnd.apple.mpegurl`, alt playlist de 200.

BU DOSYA NE OLCER: teshis ayrimini. Zaman asiminda "gecit yok" (sunucu
yapilandirmasi) mi yoksa "henuz hazir degil" mi denecegi, GECIDE SORARAK
belirlenir — tahminle degil.
"""
from __future__ import annotations

import httpx
import pytest

from app.routers import cameras as kamera_modulu


@pytest.mark.asyncio
async def test_ZAMAN_ASIMINDA_GECIT_AYAKTAYSA_HAZIR_DEGIL_DENIR(monkeypatch):
    """Gecit cevap veriyorsa sebep "yapilandirma" DEGILDIR."""
    async def sahte_gecit_ayakta() -> bool:
        return True

    monkeypatch.setattr(kamera_modulu, "_gecit_ayakta", sahte_gecit_ayakta)

    class _Zamanasimli:
        async def __aenter__(self):
            return self
        async def __aexit__(self, *a):
            return False
        async def get(self, *a, **k):
            raise httpx.ReadTimeout("zaman asimi")

    monkeypatch.setattr(httpx, "AsyncClient", lambda **k: _Zamanasimli())

    import uuid
    from app.errors import APIError
    with pytest.raises(APIError) as hata:
        await kamera_modulu._playlist_bekle("http://gecit/x.m3u8", uuid.uuid4())
    assert hata.value.status_code == 502
    assert hata.value.code == "bad_gateway", hata.value.code
    assert hata.value.mesaj == "kamera_yayin_hazir_degil"


@pytest.mark.asyncio
async def test_ZAMAN_ASIMINDA_GECIT_YOKSA_YAPILANDIRMA_DENIR(monkeypatch):
    """Gecit gercekten ulasilamiyorsa teshis SUNUCU YAPILANDIRMASIDIR.

    Ters yon: duzeltmeyi "her zaman hazir degil de" diye yapmak,
    gercekten bozuk bir kurulumu gizlemek olurdu.
    """
    async def sahte_gecit_ayakta() -> bool:
        return False

    monkeypatch.setattr(kamera_modulu, "_gecit_ayakta", sahte_gecit_ayakta)

    class _Zamanasimli:
        async def __aenter__(self):
            return self
        async def __aexit__(self, *a):
            return False
        async def get(self, *a, **k):
            raise httpx.ConnectError("baglanti yok")

    monkeypatch.setattr(httpx, "AsyncClient", lambda **k: _Zamanasimli())

    import uuid
    from app.errors import APIError
    with pytest.raises(APIError) as hata:
        await kamera_modulu._playlist_bekle("http://gecit/x.m3u8", uuid.uuid4())
    assert hata.value.mesaj == "kamera_gecit_yok"


def test_PLAYLIST_BUTCESI_MEDIAMTX_BASLANGICINDAN_BUYUK():
    """Butce, OLCULEN soguk baslangictan (33.8 sn) buyuk olmali.

    Sayi kucultulurse olculen GERCEK davranis "hata" sayilir ve ilk
    tiklama yine basarisiz olur — bu testin tek isi o gerilemeyi
    yakalamak.
    """
    assert kamera_modulu._CANLI_HAZIRLIK_BUTCESI >= 35
