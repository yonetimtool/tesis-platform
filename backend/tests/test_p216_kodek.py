"""(P216) H265 KAMERALAR — HLS varyanti, kodek teshisi, yol yarisi.

===========================================================================
OLCULEN KUSUR (prod)
===========================================================================
    INF [RTSP source] ready: 1 track (H265)
    INF [HLS] muxer destroyed: the MPEG-TS variant of HLS supports
        H264 video only
    -> HLS 404 -> backend 502 -> "Yayin acilamadi, adresi kontrol edin"

Kamera saglamdi; sorun HLS VARYANTIYDI. Guvenlik kameralarinda H265 artik
varsayilan, yani bu nadir bir durum degil.

OLCUM (dev, sentetik H265 kaynak):
    mpegts + H265 -> muxer destroyed, 404
    fmp4   + H265 -> 200, CODECS="hvc1.4.10.L63.9e.8"
    fmp4   + H264 -> 200, CODECS="avc1.f40016"     (bozulmadi)

===========================================================================
BU DOSYA NE OLCER, NE OLCEMEZ
===========================================================================
OLCER: varyant kilidi, kodek tespiti (gercek ffprobe), test-baglanti
raporu, yol kaydinin idempotent oldugu.

OLCEMEZ: "H265 tarayicida oynuyor mu" — o karar ISTEMCIDE, kullanicinin
kendi tarayicisinda (`MediaSource.isTypeSupported`) verilir; sunucu
yalnizca yayini SUNAR. Web tarafi:
`admin-web/tests/p216-kodek.dom.test.ts`.
"""
from __future__ import annotations

import os
import pathlib
import re

import httpx
import pytest

#: Sentetik kaynaklar (dev). Yoksa ilgili testler ATLANIR — ama atlama
#: SEBEBI yazilir; sessizce gecen bir test hicbir sey korumaz.
H265_KAYNAK = os.environ.get("TEST_RTSP_H265", "rtsp://testcam:8554/cam265")
H264_KAYNAK = os.environ.get("TEST_RTSP_H264", "rtsp://testcam:8554/cam")
_API = os.environ.get("MEDIAMTX_API_URL", "")


def _infra() -> pathlib.Path:
    for k in ("/infra", "infra", "../infra"):
        d = pathlib.Path(k)
        if (d / "mediamtx.yml").exists():
            return d
    pytest.skip("infra/ bu kosumda yok — yapisal kilit ATLANDI")


# ==================== VARYANT KILIDI ===================================== #

def test_HLS_VARYANTI_H265_DESTEKLEYEN_bir_deger():
    """`mpegts` H265'i REDDEDER. Varyant geri alinirsa H265 kameralarin
    tamami sessizce yayin veremez hale gelir — ve belirti yine genel bir
    502 olur, yani kok neden bir daha gizlenir."""
    metin = (_infra() / "mediamtx.yml").read_text(encoding="utf-8")
    m = re.search(r"^hlsVariant:\s*(\S+)\s*$", metin, re.M)
    assert m, "hlsVariant bulunamadi"
    assert m.group(1) in ("fmp4", "lowLatency"), (
        f"hlsVariant={m.group(1)} — `mpegts` YALNIZ H264 destekler ve H265 "
        "kameralarda muxer aninda yok edilir (P216 kok nedeni)."
    )


@pytest.mark.skipif(not _API, reason="MEDIAMTX_API_URL yok — gecit kapali")
def test_CALISAN_gecit_de_ayni_varyanti_kullaniyor():
    """Dosyayi degistirmek YETMEZ: konteyner ortam degiskeni tasiyorsa
    dosyayi EZER ve `restart` env'i guncellemez (`--force-recreate`
    gerekir). P216'da tam olarak bu yasandi: dosyada `fmp4` yaziyordu
    ama calisan gecit hâlâ `mpegts` idi."""
    dosya = re.search(r"^hlsVariant:\s*(\S+)\s*$",
                      (_infra() / "mediamtx.yml").read_text(encoding="utf-8"), re.M)
    yanit = httpx.get(f"{_API.rstrip('/')}/v3/config/global/get", timeout=5)
    assert yanit.status_code == 200, yanit.text
    calisan = yanit.json().get("hlsVariant")
    assert calisan == dosya.group(1), (
        f"dosya `{dosya.group(1)}` diyor ama gecit `{calisan}` calistiriyor — "
        "konteyner yeniden yaratilmali (`up -d --force-recreate mediamtx`)."
    )


# ==================== KODEK TESPITI (gercek ffprobe) ===================== #

@pytest.mark.asyncio
async def test_KODEK_TESPITI_H265_ve_H264_ayirir():
    from app.routers.cameras import TARAYICI_DISI_KODEKLER, kodek_tespit

    h265 = await kodek_tespit(H265_KAYNAK)
    h264 = await kodek_tespit(H264_KAYNAK)
    if h265 is None and h264 is None:
        pytest.skip("sentetik RTSP kaynaklari bu kosumda yok")
    assert h265 == "hevc", f"H265 kaynak `{h265}` gorundu"
    assert h264 == "h264", f"H264 kaynak `{h264}` gorundu"
    assert h265 in TARAYICI_DISI_KODEKLER
    assert h264 not in TARAYICI_DISI_KODEKLER


@pytest.mark.asyncio
async def test_KODEK_TESPITI_ULASILAMAYAN_adreste_None():
    """Teshis bir KOLAYLIKTIR: basarisiz olunca kamera eklemeyi
    engellememeli, `None` donmeli."""
    from app.routers.cameras import kodek_tespit

    assert await kodek_tespit("rtsp://api:1/yok") is None


# ==================== TEST-BAGLANTI RAPORU =============================== #

def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_TEST_BAGLANTI_kodegi_RAPORLAR(client, world):
    """Istegin birebir karsiligi: "yonetici kaydetmeden once bu kameranin
    izlenip izlenemeyecegini bilsin".

    "Kare geldi" YETMEZ: kareyi sunucudaki ffmpeg ceker ve H265'te de
    calisir. Tarayicida oynatma AYRI bir sorudur ve yonetici bunu eskiden
    ancak kamerayi kaydedip ana ekrana koyduktan sonra, ilk tiklamada
    ogreniyordu.
    """
    h = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/cameras/test-baglanti", headers=h,
                    json={"stream_url": H265_KAYNAK, "tur": "rtsp"}, timeout=60)
    if r.status_code != 200:
        pytest.skip(f"sentetik H265 kaynak yok ({r.status_code})")
    d = r.json()
    assert d["basarili"] is True and d["kare_bayt"] > 0
    assert d["kodek"] == "hevc"
    assert d["tarayicida_oynatilir"] is False


def test_TEST_BAGLANTI_H264_icin_OYNATILIR_der(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/cameras/test-baglanti", headers=h,
                    json={"stream_url": H264_KAYNAK, "tur": "rtsp"}, timeout=60)
    if r.status_code != 200:
        pytest.skip(f"sentetik H264 kaynak yok ({r.status_code})")
    d = r.json()
    assert d["kodek"] == "h264"
    assert d["tarayicida_oynatilir"] is True


# ==================== YOL KAYDI: "already exists" YARISI ================= #

@pytest.mark.skipif(not _API, reason="MEDIAMTX_API_URL yok — gecit kapali")
@pytest.mark.asyncio
async def test_YOL_KAYDI_TEKRARLANABILIR_ve_GEREKSIZ_RELOAD_yapmaz():
    """"path already exists" HATA DEGIL.

    Eski akis her istekte koru korune `add` deniyor, MediaMTX bunu
    `ERR [API] path already exists` diye gunluge yaziyor ve biz de
    arkasindan gereksiz bir `patch` atip YAPILANDIRMAYI YENIDEN
    YUKLETIYORDUK — izleyen varken. Dogru sira: VAR MI -> yoksa ekle,
    varsa ve kaynak AYNI ise DOKUNMA.

    Olculen sey: ayni cagri uc kez yapildiginda hata cikmamasi VE
    ikinci/ucuncu cagrilarin yapilandirmayi degistirmemesi.
    """
    from app.routers.cameras import _mediamtx_yol_kaydet

    yol = "p216yarisdenemesi"
    api = _API.rstrip("/")
    try:
        for _ in range(3):
            await _mediamtx_yol_kaydet(yol, H264_KAYNAK)  # istisna ATMAMALI
        y = httpx.get(f"{api}/v3/config/paths/get/{yol}", timeout=5)
        assert y.status_code == 200, y.text
        assert y.json()["source"] == H264_KAYNAK
    finally:
        httpx.post(f"{api}/v3/config/paths/delete/{yol}", timeout=5)


@pytest.mark.skipif(not _API, reason="MEDIAMTX_API_URL yok — gecit kapali")
@pytest.mark.asyncio
async def test_KAYNAK_DEGISIRSE_yol_GUNCELLENIR():
    """"Dokunma" kurali fazla genis olmamali: kaynak degistiyse yol
    GUNCELLENMELI, yoksa kamera adresi degistirildiginde eski yayin
    sonsuza dek yasardi."""
    from app.routers.cameras import _mediamtx_yol_kaydet

    yol = "p216kaynakdegisimi"
    api = _API.rstrip("/")
    try:
        await _mediamtx_yol_kaydet(yol, H264_KAYNAK)
        await _mediamtx_yol_kaydet(yol, H265_KAYNAK)
        y = httpx.get(f"{api}/v3/config/paths/get/{yol}", timeout=5)
        assert y.json()["source"] == H265_KAYNAK
    finally:
        httpx.post(f"{api}/v3/config/paths/delete/{yol}", timeout=5)


# ==================== UCTAN UCA ========================================== #

@pytest.mark.skipif(not _API, reason="MEDIAMTX_API_URL yok — gecit kapali")
def test_H265_KAMERA_CANLI_YAYIN_URETIR(client, world):
    """KOK NEDENIN BIREBIR KILIDI: H265 bir kamerada canli yayin
    playlist'i GERCEKTEN uretiliyor mu?

    Varyant `mpegts`e donerse bu test duser — ve dusmesi gerekir:
    o durumda H265 kameralarin hepsi sessizce yayin veremez hale gelir.
    """
    import asyncio
    import uuid

    from app.routers.cameras import kodek_tespit

    # OLCUMUN GECERLILIK KOSULU: kaynak GERCEKTEN H265 yayinliyor mu?
    # Ilk yazimda 200 gelmeyince `skip` ediyordum ve varyanti `mpegts`e
    # cevirdigimde test DUSMEK yerine ATLANDI — yani kok nedenin kilidi
    # olmasi gereken test, tam da o kok neden geri geldiginde susuyordu.
    if asyncio.get_event_loop().run_until_complete(
            kodek_tespit(H265_KAYNAK)) != "hevc":
        pytest.skip("sentetik H265 kaynak bu kosumda yok")

    h = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/cameras", headers=h, json={
        "ad": f"P216-{uuid.uuid4().hex[:6]}", "stream_url": H265_KAYNAK,
        "tur": "rtsp"})
    assert r.status_code == 201, r.text
    kid = r.json()["id"]
    try:
        y = client.get(f"/cameras/{kid}/canli/index.m3u8", headers=h, timeout=60)
        # KAYNAK VAR (yukarida olculdu) — bu noktada 200 ZORUNLU.
        assert y.status_code == 200, (
            f"H265 kaynak yayinda ama canli yayin uretilmedi ({y.status_code}): "
            f"{y.text[:160]} — HLS varyanti `mpegts`e mi dondu?"
        )
        assert "hvc1" in y.text, f"H265 kodegi playlist'te yok: {y.text[:120]!r}"
    finally:
        client.delete(f"/cameras/{kid}", headers=h)
