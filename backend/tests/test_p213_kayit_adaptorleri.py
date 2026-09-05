"""(P213 §6) GECMIS KAYIT ADAPTORLERI — istek/yanit duzeyinde olcum.

===========================================================================
TAKLIT NEREYE KONDU ve NEDEN
===========================================================================
Taklit, httpx'in TASIMA katmanina (`MockTransport`) konuyor: adaptorun
KENDISI gercek `httpx.AsyncClient` ile calisiyor, gercek istegi kuruyor,
gercek yaniti cozuyor. Olculen sey "adaptor dogru adresi mi cagirdi,
dogru govdeyi mi gonderdi, yaniti dogru mu cozdu".

P200 DERSI: adaptoru taklit edip "listeyi dondurdu" demek, olculmek
istenen katmanin TAM KENDISINI atlamak olurdu — o testler protokol
degisince de yesil kalirdi.

ELIMDE CIHAZ YOK: yanit govdeleri satici belgelerinden kuruldu. Bu
testler "protokolu dogru uyguluyoruz" der; "bu cihazda calisiyor"
DEMEZ. Gercek dogrulama saha denemesiyle olacak (analiz belgesi §5).
"""
from __future__ import annotations

import datetime as dt

import httpx
import pytest

from app.kamera_kayit import AramaDesteklenmiyor, saglayici_kur
from app.kamera_kayit.dahua import DahuaSaglayici
from app.kamera_kayit.hikvision import HikvisionSaglayici
from app.kamera_kayit.sablon import SablonSaglayici

BAS = dt.datetime(2026, 9, 5, 14, 0, tzinfo=dt.timezone.utc)
BIT = dt.datetime(2026, 9, 5, 15, 0, tzinfo=dt.timezone.utc)


def _istemci(islev) -> httpx.AsyncClient:
    return httpx.AsyncClient(transport=httpx.MockTransport(islev))


# ==================== SABLON ============================================== #

@pytest.mark.asyncio
async def test_sablon_ZAMANI_yerine_koyar():
    s = SablonSaglayici(
        "rtsp://nvr/play?ch={kanal}&s={bas}&e={bit}", kanal="3"
    )
    assert await s.oynatma_adresi(BAS, BIT) == (
        "rtsp://nvr/play?ch=3&s=20260905T140000Z&e=20260905T150000Z"
    )


@pytest.mark.asyncio
async def test_sablon_TUM_yer_tutucular():
    s = SablonSaglayici(
        "x/{bas_tarih}/{bas_saat}/{bit_tarih}/{bit_saat}/{bas_unix}/{bit_unix}"
    )
    assert await s.oynatma_adresi(BAS, BIT) == (
        f"x/2026-09-05/14:00:00/2026-09-05/15:00:00/"
        f"{int(BAS.timestamp())}/{int(BIT.timestamp())}"
    )


@pytest.mark.asyncio
async def test_sablon_ARAMAYI_bos_liste_ile_YANILTMAZ():
    """En onemli sablon iddiasi: "arayamiyorum" ile "kayit yok" AYRI.

    Bos liste donseydi arayuz "bu gun kayit yok" derdi; oysa kayit VAR ve
    kullanici saati elle secip izleyebilir.
    """
    with pytest.raises(AramaDesteklenmiyor):
        await SablonSaglayici("rtsp://x").araliklari_listele(BAS, BIT)


# ==================== HIKVISION =========================================== #

_HIK_YANIT = """<?xml version="1.0" encoding="UTF-8"?>
<CMSearchResult xmlns="http://www.hikvision.com/ver20/XMLSchema">
  <searchID>1</searchID><numOfMatches>2</numOfMatches>
  <matchList>
    <searchMatchItem>
      <timeSpan><startTime>2026-09-05T14:03:11Z</startTime>
                <endTime>2026-09-05T14:21:40Z</endTime></timeSpan>
      <mediaSegmentDescriptor>
        <playbackURI>rtsp://10.0.0.2/Streaming/tracks/101?starttime=20260905T140311Z&amp;endtime=20260905T142140Z</playbackURI>
      </mediaSegmentDescriptor>
    </searchMatchItem>
    <searchMatchItem>
      <timeSpan><startTime>2026-09-05T14:30:00Z</startTime>
                <endTime>2026-09-05T15:00:00Z</endTime></timeSpan>
    </searchMatchItem>
  </matchList>
</CMSearchResult>"""


def _hik(yanit_uret):
    return HikvisionSaglayici(
        _istemci(yanit_uret), "http://10.0.0.2", "10.0.0.2:554", "101", "op", "p"
    )


@pytest.mark.asyncio
async def test_hikvision_ARAMA_dogru_ucu_ve_govdeyi_cagirir():
    gorulen: dict = {}

    def islev(istek: httpx.Request) -> httpx.Response:
        gorulen["url"] = str(istek.url)
        gorulen["govde"] = istek.content.decode()
        return httpx.Response(200, text=_HIK_YANIT)

    araliklar = await _hik(islev).araliklari_listele(BAS, BIT)
    assert gorulen["url"] == "http://10.0.0.2/ISAPI/ContentMgmt/search"
    # Govde ISAPI'nin bekledigi alanlari TASIMALI — protokol iddiasi budur.
    assert "<trackID>101</trackID>" in gorulen["govde"]
    assert "<startTime>2026-09-05T14:00:00Z</startTime>" in gorulen["govde"]
    assert len(araliklar) == 2
    assert araliklar[0].bas == dt.datetime(2026, 9, 5, 14, 3, 11, tzinfo=dt.timezone.utc)
    assert araliklar[1].bit == BIT


@pytest.mark.asyncio
async def test_hikvision_AD_ALANI_onekli_XML_cozulur():
    """Cihazlar XML'i ad alani onekiyle doner; oneki atmayan bir cozucu
    HICBIR aralik bulamaz ve "kayit yok" der — sessiz ve yaniltici."""
    araliklar = await _hik(
        lambda i: httpx.Response(200, text=_HIK_YANIT)
    ).araliklari_listele(BAS, BIT)
    assert araliklar, "ad alani oneki cozumu bozuk"


@pytest.mark.asyncio
async def test_hikvision_BOS_sonuc_kayit_yok_demektir():
    bos = ('<?xml version="1.0"?><CMSearchResult>'
           "<numOfMatches>0</numOfMatches><matchList/></CMSearchResult>")
    assert await _hik(
        lambda i: httpx.Response(200, text=bos)
    ).araliklari_listele(BAS, BIT) == []


@pytest.mark.asyncio
async def test_hikvision_401_TANILI_hata_verir():
    """Kimlik hatasi "kayit yok" ile karistirilmamali."""
    from app.kamera_kayit.hikvision import KayitCozumlenemedi

    with pytest.raises(KayitCozumlenemedi, match="kimlik"):
        await _hik(lambda i: httpx.Response(401)).araliklari_listele(BAS, BIT)


@pytest.mark.asyncio
async def test_hikvision_OYNATMA_cihazin_URISINI_tercih_eder():
    """Cihazin urettigi adres, elle kurulan sablondan DAHA DOGRUDUR."""
    adres = await _hik(
        lambda i: httpx.Response(200, text=_HIK_YANIT)
    ).oynatma_adresi(BAS, BIT)
    assert adres.startswith("rtsp://10.0.0.2/Streaming/tracks/101?starttime=20260905T140311Z")


@pytest.mark.asyncio
async def test_hikvision_ARAMA_COKERSE_oynatma_SABLONA_duser():
    """Arama API'si kapali olabilir; oynatma bundan VAZGECMEZ."""
    adres = await _hik(lambda i: httpx.Response(500)).oynatma_adresi(BAS, BIT)
    assert adres == (
        "rtsp://10.0.0.2:554/Streaming/tracks/101"
        "?starttime=20260905T140000Z&endtime=20260905T150000Z"
    )


# ==================== DAHUA =============================================== #

_DAHUA_LISTE = (
    "found=2\r\n"
    "items[0].Channel=1\r\n"
    "items[0].StartTime=2026-09-05 14:03:11\r\n"
    "items[0].EndTime=2026-09-05 14:21:40\r\n"
    "items[1].StartTime=2026-09-05 14:30:00\r\n"
    "items[1].EndTime=2026-09-05 15:00:00\r\n"
)


def _dahua_islev(gorulen: list):
    def islev(istek: httpx.Request) -> httpx.Response:
        gorulen.append(str(istek.url))
        if "factory.create" in istek.url.query.decode():
            return httpx.Response(200, text="result=8842\r\n")
        if "findNextFile" in istek.url.query.decode():
            return httpx.Response(200, text=_DAHUA_LISTE)
        return httpx.Response(200, text="OK\r\n")
    return islev


def _dahua(islev):
    return DahuaSaglayici(
        _istemci(islev), "http://10.0.0.3", "10.0.0.3:554", "1", "admin", "p"
    )


@pytest.mark.asyncio
async def test_dahua_UC_ADIMLI_arama_ve_cozum():
    gorulen: list = []
    araliklar = await _dahua(_dahua_islev(gorulen)).araliklari_listele(BAS, BIT)
    assert len(araliklar) == 2
    assert araliklar[0].bas == dt.datetime(2026, 9, 5, 14, 3, 11, tzinfo=dt.timezone.utc)
    # Adimlarin SIRASI protokolun kendisi: create -> findFile -> findNextFile
    assert "factory.create" in gorulen[0]
    assert "action=findFile" in gorulen[1] and "object=8842" in gorulen[1]
    assert "findNextFile" in gorulen[2]


@pytest.mark.asyncio
async def test_dahua_BULUCUYU_kapatir():
    """Kapatilmayan bulucular cihazda birikir ve bir sure sonra arama
    TAMAMEN calismaz olur — bu satir olculmezse kimse fark etmez."""
    gorulen: list = []
    await _dahua(_dahua_islev(gorulen)).araliklari_listele(BAS, BIT)
    assert any("action=close" in u and "object=8842" in u for u in gorulen)


@pytest.mark.asyncio
async def test_dahua_HATA_DA_OLSA_bulucu_kapatilir():
    gorulen: list = []

    def islev(istek: httpx.Request) -> httpx.Response:
        gorulen.append(str(istek.url))
        q = istek.url.query.decode()
        if "factory.create" in q:
            return httpx.Response(200, text="result=99\r\n")
        if "findNextFile" in q:
            return httpx.Response(500)
        return httpx.Response(200, text="OK")

    with pytest.raises(Exception):
        await _dahua(islev).araliklari_listele(BAS, BIT)
    assert any("action=close" in u for u in gorulen), "bulucu SIZDI"


@pytest.mark.asyncio
async def test_dahua_401_TANILI():
    from app.kamera_kayit.dahua import KayitCozumlenemedi

    with pytest.raises(KayitCozumlenemedi, match="kimlik"):
        await _dahua(lambda i: httpx.Response(401)).araliklari_listele(BAS, BIT)


@pytest.mark.asyncio
async def test_dahua_OYNATMA_ALT_CIZGILI_zaman_kullanir():
    """Dahua'nin zaman bicimi Hikvision'inkinden FARKLI; karistirmak
    sessizce bos bir oynatma verirdi."""
    adres = await _dahua(lambda i: httpx.Response(200)).oynatma_adresi(BAS, BIT)
    assert adres == (
        "rtsp://10.0.0.3:554/cam/playback?channel=1"
        "&starttime=2026_09_05_14_00_00&endtime=2026_09_05_15_00_00"
    )


# ==================== FABRIKA (SECIM) ===================================== #

class _Kam:
    def __init__(self, **kw):
        self.stream_url = "rtsp://10.0.0.4:554/s"
        self.kayit_saglayici = None
        self.kayit_adres = None
        self.kayit_kanal = None
        self.kayit_kullanici = None
        self.kayit_parola_sifreli = None
        self.__dict__.update(kw)


def test_TANINMAYAN_saglayici_REDDEDILIR():
    """Fail-closed: varsayilan bir adaptore dusmek, yanlis markaya yanlis
    istekler gondermek ve teshisi cok zor bir hata sinifi uretmek olurdu."""
    from app.kamera_kayit import SaglayiciTaninmiyor

    ist = _istemci(lambda i: httpx.Response(200))
    for deger in (None, "", "onvif", "hikvison"):
        with pytest.raises(SaglayiciTaninmiyor):
            saglayici_kur(_Kam(kayit_saglayici=deger), ist)


def test_TABAN_bossa_KAMERA_KONAGI_kullanilir():
    from app.kamera_kayit import kayit_tabani

    assert kayit_tabani(_Kam()) == "http://10.0.0.4"
    assert kayit_tabani(_Kam(kayit_adres="http://nvr:81")) == "http://nvr:81"


def test_PAROLA_rtsp_adresine_KACISLI_gomulur():
    """NVR parolasi `@` ya da `/` iceriyorsa adres bozulmamali."""
    from app.kamera_kimlik import parola_sakla

    s = saglayici_kur(
        _Kam(kayit_saglayici="dahua", kayit_kullanici="ad@min",
             kayit_parola_sifreli=parola_sakla("a/b@c")),
        _istemci(lambda i: httpx.Response(200)),
    )
    assert s._rtsp_konak.startswith("ad%40min:a%2Fb%40c@")
