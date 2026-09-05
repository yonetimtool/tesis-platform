"""(P213 §2) CANLI YAYIN — GECIT API'SI VE TESHIS EDILEBILIR HATALAR.

===========================================================================
OLCULEN KOK NEDEN
===========================================================================
Izgaradaki kare calisiyor, tiklayinca canli yayin acilmiyordu. Zincir
sirayla surulunce kirilma noktasi bulundu:

    GET http://mediamtx:9997/v3/paths/list   ->  401

MediaMTX 1.9'un GOMULU varsayilan `authInternalUsers` ayarinda `api`
izni YALNIZ `127.0.0.1/::1`e verilmis. `api` servisi gecide docker
aginin IP'siyle (172.x) baglandigi icin TUM API cagrilari 401 aliyordu.
Eski kod POST'un 4xx'ini "yol zaten var" sayip PATCH deniyor, onun
sonucunu HIC OKUMUYORDU: akis sessizce devam ediyor, HLS istegi yol
olusmadigi icin 404 doner ve kullanici "yayin hazir degil" goruyordu —
yani KAMERAYA bakiyordu, oysa duzeltilecek yer SUNUCUYDU.

Kare calisiyordu cunku onu ffmpeg KAMERADAN DOGRUDAN cekiyor; MediaMTX'e
hic ugramiyor. Kullanicinin gozlemi bu ayrimin birebir yansimasi.

Cozum iki parcali:
  1. `infra/mediamtx.yml` — `api` izni ozel ag araliklarina acildi
     (API portu disari ACILMIYOR),
  2. burasi — 401/403 ARTIK YUTULMUYOR, ayri bir hata kimligiyle doner.

===========================================================================
BU DOSYA NE OLCER
===========================================================================
Gercek bir RTSP kamerasi yok; olculen sey UCUN DAVRANISI: gecit
reddettiginde/ulasilmadiginda hangi hata doner ve mesaj yoneticiyi
DOGRU yere gonderir mi. Zincirin kendisi (RTSP -> MediaMTX -> HLS ->
vekil) sentetik bir yayinla ELLE suruldu ve gectigi kararlar belgesine
yazildi (`docs/P213-kararlar.md` §2).
"""
from __future__ import annotations

import uuid

import httpx
import pytest

from app.hata_metinleri import METINLER


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def kamera(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/cameras", headers=h, json={
        "ad": f"P213 {uuid.uuid4().hex[:6]}", "tur": "rtsp",
        "stream_url": "rtsp://192.0.2.1:554/yok", "aktif": True})
    assert r.status_code == 201, r.text
    kid = r.json()["id"]
    yield h, kid
    client.delete(f"/cameras/{kid}", headers=h)


# ==================== 1) HATA METINLERI AYIRT EDIYOR ==================== #

def test_UC_AYRI_GECIT_HATASI_uc_ayri_metin(client):
    """"Ulasilamiyor", "reddetti" ve "yayin hazir degil" AYNI SEY DEGIL.

    Ucunu tek mesaja indirmek, yoneticiyi kamerayi kontrol etmeye
    gonderiyordu; oysa ilk ikisinde duzeltilecek yer SUNUCUDUR.
    """
    for kimlik in ("kamera_gecit_yok", "kamera_gecit_yetkisiz",
                   "kamera_gecit_yapilandirma", "kamera_yayin_hazir_degil"):
        assert kimlik in METINLER, f"{kimlik} metni YOK"
        assert set(METINLER[kimlik]) == {"tr", "en", "ar", "ru", "de", "fr", "es"}
    # Mesajlar BIRBIRINDEN FARKLI olmali (kopyala-yapistir kilidi).
    tr = {k: METINLER[k]["tr"] for k in
          ("kamera_gecit_yok", "kamera_gecit_yetkisiz",
           "kamera_gecit_yapilandirma", "kamera_yayin_hazir_degil")}
    assert len(set(tr.values())) == 4
    # Yetki hatasi SUNUCUYU isaret eder, kamerayi degil.
    assert "sunucu" in tr["kamera_gecit_yetkisiz"].lower()


# ==================== 2) 401 YUTULMUYOR ================================= #

# NOT: "uc 401'de ne doner" TESTI YAZILAMAZ — bu paketin testleri CANLI
# sunucuya gider (ayri surec) ve `monkeypatch` oraya islemez. 401 dali
# bunun yerine `_canli_yolu_kaydet` DOGRUDAN cagrilarak olculuyor
# (asagidaki iki test), ki kirilma noktasi da zaten orasiydi.


def _kaydet_sonucu(monkeypatch, durum: int, govde: str):
    """`_canli_yolu_kaydet`i sahte bir gecit yanitiyla dogrudan calistirir."""
    import asyncio
    from types import SimpleNamespace
    import uuid as _u

    from app.routers import cameras

    class _Yanit:
        status_code = durum
        text = govde

    class _Istemci:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def post(self, *a, **k):
            return _Yanit()

        async def patch(self, *a, **k):
            return _Yanit()

    monkeypatch.setattr(cameras.httpx, "AsyncClient", lambda **k: _Istemci())
    monkeypatch.setattr(cameras.settings, "mediamtx_api_url", "http://x:9997")
    obj = SimpleNamespace(id=_u.uuid4(), stream_url="rtsp://x/y")
    dongu = asyncio.get_event_loop_policy().new_event_loop()
    return dongu.run_until_complete(cameras._canli_yolu_kaydet(obj))


@pytest.mark.parametrize("durum", [401, 403])
def test_GECIT_YETKI_REDDI_ayri_kimlikle_doner(monkeypatch, durum):
    """KOK NEDENIN KILIDI.

    Eskiden POST'un 401'i "yol zaten var" sanilip PATCH'e gidiyor, onun
    401'i de OKUNMUYORDU: akis sessizce devam ediyordu. Artik AYRI bir
    kimlik doner — cunku duzeltilecek yer KAMERA DEGIL SUNUCUDUR.
    """
    from app.errors import APIError

    with pytest.raises(APIError) as h:
        _kaydet_sonucu(monkeypatch, durum, "unauthorized")
    assert h.value.mesaj == "kamera_gecit_yetkisiz"
    assert h.value.status_code == 502


def test_YOL_ZATEN_VARSA_hata_DEGIL(monkeypatch):
    """MediaMTX var olan yol icin 4xx + "already exists" doner; bu
    NORMALDIR (idempotent kayit) ve hataya cevrilmemeli."""
    import asyncio
    from types import SimpleNamespace

    from app.routers import cameras

    class _Yanit:
        status_code = 400
        text = "path already exists"

    class _Istemci:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def post(self, *a, **k):
            return _Yanit()

        async def patch(self, *a, **k):
            return _Yanit()

    monkeypatch.setattr(cameras.httpx, "AsyncClient", lambda **k: _Istemci())
    monkeypatch.setattr(cameras.settings, "mediamtx_api_url", "http://x:9997")
    obj = SimpleNamespace(id=uuid.uuid4(), stream_url="rtsp://x/y")
    # ISTISNA ATMAMALI.
    asyncio.get_event_loop_policy().new_event_loop().run_until_complete(
        cameras._canli_yolu_kaydet(obj)
    )


def test_YOL_KAYDI_BASKA_4xx_ISE_hata(monkeypatch):
    """"already exists" DISINDAKI 4xx gercek bir yapilandirma sorunudur."""
    import asyncio
    from types import SimpleNamespace

    from app.errors import APIError
    from app.routers import cameras

    class _Yanit:
        status_code = 400
        text = "invalid source"

    class _Istemci:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def post(self, *a, **k):
            return _Yanit()

        async def patch(self, *a, **k):
            return _Yanit()

    monkeypatch.setattr(cameras.httpx, "AsyncClient", lambda **k: _Istemci())
    monkeypatch.setattr(cameras.settings, "mediamtx_api_url", "http://x:9997")
    obj = SimpleNamespace(id=uuid.uuid4(), stream_url="rtsp://x/y")
    dongu = asyncio.get_event_loop_policy().new_event_loop()
    with pytest.raises(APIError) as h:
        dongu.run_until_complete(cameras._canli_yolu_kaydet(obj))
    assert h.value.mesaj == "kamera_gecit_yapilandirma"


# ==================== 3) YOL GUVENLIGI (gerileme) ======================= #

@pytest.mark.parametrize("dosya", [
    "../gizli.m3u8", "a/b.ts", "..%2Fx.m3u8", "index.m3u8.exe", "index",
])
def test_GEZINTI_denemeleri_404(client, kamera, dosya):
    """`dosya` gecit URL'ine dogrudan eklendigi icin serbest birakmak,
    baska kameranin yayinini cekmeye izin verirdi (IDOR)."""
    h, kid = kamera
    r = client.get(f"/cameras/{kid}/canli/{dosya}", headers=h)
    assert r.status_code in (404, 503), f"{dosya} -> {r.status_code}"
