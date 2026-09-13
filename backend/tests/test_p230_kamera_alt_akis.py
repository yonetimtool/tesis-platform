"""(P230 §1) RTSP CANLI — ALT AKIS ADRESI.

===========================================================================
ZINCIR OLCULDU: SUNUCUDA KOPMUYOR
===========================================================================
  (b) API -> MediaMTX `/v3/paths/list` : HTTP 200
  (c) MediaMTX -> RTSP kaynagi         : `[RTSP source] ready: 1 track (H265)`
  (d) HLS uretimi                      : index.m3u8 200,
                                         CODECS="hvc1.4.10.L63.9e.8"
  (e) ISTEMCI COZME                    : KOPMA BURADA

Kamera H265 yayin yapiyor. Dordunku turda da "sunucuyu duzeltmek"
denenseydi hicbir sey degismezdi — sunucu zaten dogru calisiyor.

ALT AKIS ALANI bunun icin: kamera genelde H264 olan ikinci bir akis
verir; CANLI yol onu kullanir, KARE ve KAYIT ana akisi kullanmaya
devam eder (ffmpeg H265'i sorunsuz cozer).
"""
from __future__ import annotations

import uuid

import pytest


@pytest.fixture
def yon(client, world):
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["yonetici_a"]["email"],
        "password": world["yonetici_a"]["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


@pytest.fixture
def sakin(client, world):
    r = client.post("/auth/login", json={
        "tenant_slug": world["slug_a"],
        "email": world["resident_a"]["email"],
        "password": world["resident_a"]["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _kamera(client, yon, **k):
    govde = {
        "ad": f"P230 {uuid.uuid4().hex[:6]}",
        "stream_url": "rtsp://ana.ornek/cam1",
        "tur": "rtsp",
        "sakin_gorebilir": True,
    }
    govde.update(k)
    return client.post("/cameras", headers=yon, json=govde)


def test_ALT_AKIS_KAYDEDILIR_VE_DONER(client, yon):
    r = _kamera(client, yon, alt_stream_url="rtsp://ana.ornek/cam1_sub")
    assert r.status_code == 201, r.text
    assert r.json()["alt_stream_url"] == "rtsp://ana.ornek/cam1_sub"


def test_ANA_ADRES_DEGISMEZ(client, yon):
    """ALANIN VARLIK SEBEBI: `stream_url` KARE ve KAYIT icin kullaniliyor
    ve ffmpeg H265'i sorunsuz cozuyor. Alt akisi ana adrese yazmak,
    cozulmesi GEREKMEYEN bir yerde cozunurlugu dusururdu."""
    r = _kamera(client, yon, alt_stream_url="rtsp://ana.ornek/cam1_sub")
    assert r.json()["stream_url"] == "rtsp://ana.ornek/cam1"


def test_CANLI_YOL_ALT_AKISI_KULLANIR(client, yon, owner_conn):
    """Sunucu ici secim — MediaMTX yoluna ALT akis kaydedilmeli."""
    from app.models import Camera
    from app.routers.cameras import etkin_stream_url

    class _Sahte:
        stream_url = "rtsp://ana.ornek/cam1"
        alt_stream_url = "rtsp://ana.ornek/cam1_sub"
        stream_kullanici = None
        stream_parola_sifreli = None

    assert etkin_stream_url(_Sahte(), canli=True).endswith("cam1_sub")
    # KARE/KAYIT yolu ANA akisi kullanmaya devam eder.
    assert etkin_stream_url(_Sahte()).endswith("/cam1")
    assert Camera is not None


def test_ALT_AKIS_YOKSA_ANA_AKISA_DUSER(client, yon):
    """Alan bos birakan kameralar ESKISI GIBI calismali."""
    from app.routers.cameras import etkin_stream_url

    class _Sahte:
        stream_url = "rtsp://ana.ornek/cam1"
        alt_stream_url = None
        stream_kullanici = None
        stream_parola_sifreli = None

    assert etkin_stream_url(_Sahte(), canli=True).endswith("/cam1")


def test_ALT_AKIS_RTSP_OLMALI(client, yon):
    """Alana HLS adresi yazmak, sessizce ise yaramayan bir canli yol
    uretirdi (MediaMTX'e `rtspSource` olarak kaydediliyor)."""
    r = _kamera(client, yon, alt_stream_url="https://ornek/x.m3u8")
    assert r.status_code == 422, r.text


def test_ALT_AKIS_IZLEYICIYE_MASKELENIR(client, yon, sakin):
    """KIMLIK SIZINTISI: alt akis da `kul:par@` tasiyabilir. Maskelemeyi
    unutmak, ana adres icin kapatilan sizintiyi IKINCI bir alanla
    yeniden acmak olurdu."""
    r = _kamera(client, yon, alt_stream_url="rtsp://gizli:parola@ana.ornek/sub")
    assert r.status_code == 201, r.text
    kid = r.json()["id"]

    # TEKIL `GET /cameras/{id}` UCU YOK (olculdu: 405); gorunurluk
    # listeden okunur.
    liste = client.get("/cameras?limit=200", headers=sakin)
    assert liste.status_code == 200, liste.text
    bizim = next((c for c in liste.json()["items"] if c["id"] == kid), None)
    if bizim is None:
        pytest.skip("sakin bu kamerayi goremiyor")
    assert "parola" not in (bizim.get("alt_stream_url") or ""), bizim
    assert bizim.get("alt_stream_url") in (None, "rtsp://***"), bizim

    # (P213 §6b) PAROLA ADRESTE SAKLANMAZ — yoneticiye de.
    #
    # Ilk yazimda alt akis bu kuraldan GECMIYORDU ve parola veritabaninda
    # DUZ duruyordu: ana adres icin kapatilan sizinti ikinci bir alanla
    # yeniden acilmisti. Test onu yakaladi.
    yliste = client.get("/cameras?limit=200", headers=yon).json()["items"]
    ybizim = next(c for c in yliste if c["id"] == kid)
    assert "parola" not in ybizim["alt_stream_url"], ybizim
    assert ybizim["alt_stream_url"] == "rtsp://ana.ornek/sub", ybizim


def test_GUNCELLEME_ILE_ALT_AKIS_EKLENEBILIR(client, yon):
    """Mevcut kameralara sonradan eklenebilmeli — kullanicinin yapacagi
    islem tam olarak bu."""
    r = _kamera(client, yon)
    kid = r.json()["id"]
    g = client.patch(f"/cameras/{kid}", headers=yon,
                     json={"alt_stream_url": "rtsp://ana.ornek/sub"})
    assert g.status_code == 200, g.text
    assert g.json()["alt_stream_url"] == "rtsp://ana.ornek/sub"
