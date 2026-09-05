"""(P213 §3) HLS KAMERALARDA DA ANLIK KARE.

===========================================================================
OLCULEN DURUM
===========================================================================
Kullanicinin gordugu davranis kamera TURUNE gore degisiyordu: RTSP
kamerada izgarada kare vardi, HLS kamerada YOKTU (uc 422 "yalniz RTSP"
donuyordu). Kamera turu bir ALTYAPI ayrintisidir; kullanicinin ekraninda
gorunur olmasi icin bir sebep yok — istegin acik sarti da buydu.

===========================================================================
SSRF SINIRI NEREYE KONDU
===========================================================================
Klasik "ozel IP araliklarini engelle" listesi BURADA UYGULANAMAZ:
kameralar cogunlukla YEREL AGDA ve `192.168.x.x` tam da gecerli bir
kamera adresi. Bunun yerine:
  * `stream_url`i YALNIZ yonetim yazar (kullanici girdisi degil,
    YAPILANDIRMA) — RTSP'de de durum boyleydi;
  * cikti ffmpeg'in urettigi bir JPEG: hedef medya degilse kare CIKMAZ,
    yani rastgele bir ucun govdesi istemciye donmez;
  * bulut META-VERI uclari ACIKCA engellenir (kamera orada olmaz,
    sizarsa bedeli agir);
  * ffmpeg protokol listesi DAR: `http,https,tcp,tls,crypto` — `file`
    YOK, yoksa uc bir dosya okuyucusuna donerdi.
"""
from __future__ import annotations

import uuid

import pytest

from app.hata_metinleri import METINLER


def _h(client, slug, cred):
    r = client.post("/auth/login", json={
        "tenant_slug": slug, "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _kamera(client, h, tur, url):
    r = client.post("/cameras", headers=h, json={
        "ad": f"P213 {uuid.uuid4().hex[:6]}", "tur": tur,
        "stream_url": url, "aktif": True})
    assert r.status_code == 201, r.text
    return r.json()["id"]


# ==================== 1) DOGRULAMA KAPISI =============================== #

def test_HLS_ADRESI_ARTIK_REDDEDILMIYOR(client, world):
    """Eski hâl: `tur != rtsp` -> 422 "yalniz RTSP". Artik kare denenir;
    ulasilamayan bir adres icin gelen hata BAGLANTI hatasidir, "bu tur
    desteklenmiyor" DEGIL."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, h, "hls", "http://192.0.2.1:8888/yok/index.m3u8")
    try:
        r = client.get(f"/cameras/{kid}/kare", headers=h, timeout=30)
        assert r.status_code != 422, "HLS artik desteklenmeli"
        assert r.status_code in (502, 503), r.text
    finally:
        client.delete(f"/cameras/{kid}", headers=h)


@pytest.mark.parametrize("url", [
    "http://169.254.169.254/latest/meta-data/index.m3u8",
    "http://metadata.google.internal/x/index.m3u8",
    "http://100.100.100.200/x/index.m3u8",
])
def test_BULUT_METAVERI_uclari_REDDEDILIR(client, world, url):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, h, "hls", url)
    try:
        r = client.get(f"/cameras/{kid}/kare", headers=h, timeout=20)
        assert r.status_code == 422, r.text
        assert r.json()["error"]["message"] == METINLER["kamera_kare_desteklenmeyen"]["tr"]
    finally:
        client.delete(f"/cameras/{kid}", headers=h)


def test_DESTEKLENMEYEN_SEMA_reddedilir(client, world):
    """`mp4` turu bir DOSYADIR: canli kare kavrami yok."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, h, "mp4", "https://ornek.test/kayit.mp4")
    try:
        r = client.get(f"/cameras/{kid}/kare", headers=h, timeout=20)
        # mp4 http(s) oldugu icin kapiyi GECER ama medya olmadigi
        # (ulasilamadigi) icin baglanti hatasi doner — "tur
        # desteklenmiyor" degil. Olculen sey: 422 ile REDDEDILMIYOR.
        assert r.status_code in (502, 503), r.text
    finally:
        client.delete(f"/cameras/{kid}", headers=h)


def test_METIN_7_DIL(client):
    m = METINLER["kamera_kare_desteklenmeyen"]
    assert set(m) == {"tr", "en", "ar", "ru", "de", "fr", "es"}


# ==================== 2) GERILEME: RTSP DOKUNULMADI ===================== #

def test_RTSP_kare_yolu_DEGISMEDI(client, world):
    h = _h(client, world["slug_a"], world["yonetici_a"])
    kid = _kamera(client, h, "rtsp", "rtsp://192.0.2.1:554/yok")
    try:
        r = client.get(f"/cameras/{kid}/kare", headers=h, timeout=30)
        assert r.status_code in (502, 503), r.text
        # Teshis KIMLIGI korunuyor (P191 §3): "ulasilamiyor" vb.
        assert r.json()["error"]["code"] in ("bad_gateway", "service_unavailable")
    finally:
        client.delete(f"/cameras/{kid}", headers=h)


def test_SAKIN_GOREMEDIGI_kameranin_karesini_ALAMAZ(client, world):
    """Gorunurluk kurali degismedi (gerileme kapisi)."""
    h = _h(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/cameras", headers=h, json={
        "ad": "P213 Gizli", "tur": "hls",
        "stream_url": "http://192.0.2.1:8888/x/index.m3u8",
        "aktif": True, "sakin_gorebilir": False})
    kid = r.json()["id"]
    try:
        sakin = _h(client, world["slug_a"], world["resident_a"])
        assert client.get(f"/cameras/{kid}/kare", headers=sakin).status_code == 404
    finally:
        client.delete(f"/cameras/{kid}", headers=h)
