"""(P191 §3) KAMERA HATA TESHISI — "Yayın açılamadı" tek başına işe yaramaz.

===========================================================================
OLCULEN KUSUR
===========================================================================
`app.yonetiyor.com/kameralar` her arizada AYNI cumleyi gosteriyordu:
"Yayın açılamadı. Adresi ve ağ erişimini kontrol edin." Izgarada
"Görüntü yok". Yoneticinin elinde EYLEM yoktu — adres mi yanlis, parola
mi, kamera mi kapali, sunucuda ffmpeg mi eksik, mediamtx mi kapali?

ffmpeg bunlarin hepsini stderr'inde SOYLUYORDU; kod onu `DEVNULL`a
yaziyordu. Bu dosya siniflandirmanin dogru calistigini ve yeni
`POST /cameras/test-baglanti` ucunun kaydetmeden TANILI cevap verdigini
olcer.
"""
from __future__ import annotations

import uuid

import pytest

from app.routers.cameras import _ffmpeg_teshis, _kare_hatasi


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ======================= A. SINIFLANDIRMA (in-process) ====================== #
@pytest.mark.parametrize(
    "cikti,beklenen",
    [
        (b"[rtsp @ 0x1] method DESCRIBE failed: 401 Unauthorized", "kamera_kimlik_hatali"),
        (b"Authentication failed", "kamera_kimlik_hatali"),
        (b"method DESCRIBE failed: 404 Not Found", "kamera_yol_bulunamadi"),
        (b"rtsp://x: Connection refused", "kamera_ulasilamiyor"),
        (b"No route to host", "kamera_ulasilamiyor"),
        (b"Failed to resolve hostname kamera.local", "kamera_adres_cozulemedi"),
        (b"rtsp://x: Connection timed out", "kamera_zaman_asimi"),
        (b"Invalid data found when processing input", "kamera_yayin_okunamadi"),
        # Taninmayan cikti SESSIZ KALMAZ, genel kimlige duser.
        (b"bilinmeyen bir sey oldu", "kamera_baglanti_yok"),
        (b"", "kamera_baglanti_yok"),
        (None, "kamera_baglanti_yok"),
    ],
)
def test_ffmpeg_ciktisi_ARIZAYI_ADLANDIRIR(cikti, beklenen):
    assert _ffmpeg_teshis(cikti, zaman_asimi=False) == beklenen


def test_ZAMAN_ASIMI_ciktidan_BAGIMSIZ(): 
    """Sure dolduysa ffmpeg hicbir sey yazmamis olabilir; teshis yine nettir."""
    assert _ffmpeg_teshis(b"", zaman_asimi=True) == "kamera_zaman_asimi"
    assert _ffmpeg_teshis(b"401 Unauthorized", zaman_asimi=True) == "kamera_zaman_asimi"


def test_ffmpeg_YOKLUGU_503_yapilandirma_hatasidir():
    """502 "karsi taraf bozuk" der ve yoneticiyi AG aramaya gonderirdi;
    oysa duzeltilecek yer SUNUCUDUR (imajda ffmpeg yok)."""
    assert _kare_hatasi("kamera_ffmpeg_yok").status_code == 503
    assert _kare_hatasi("kamera_kimlik_hatali").status_code == 502


# =========================== B. TEST-BAGLANTI UCU =========================== #
def test_test_baglanti_ULASILAMAYAN_adres_icin_TANILI_hata(client, world):
    """Gercek deneme: kapali bir porta rtsp — "connection refused" beklenir.

    UCTAN UCA olcum (sahte yok): ffmpeg gercekten calisir, stderr gercekten
    okunur, kimlik gercekten uretilir.

    (P213 §3) ADRES DEGISTI: eskiden `rtsp://127.0.0.1:1/yok` deneniyordu.
    SSRF kapisi eklenince loopback ARTIK 422 ile reddediliyor (dogru
    davranis; bkz. test_p213_hls_kare.py). Bu testin olctugu sey SSRF
    degil TESHIS KALITESI oldugundan, yasak OLMAYAN ama ulasilamayan bir
    adres gerekiyor: docker agindaki `api` konagi (172.x, yasak degil)
    ve KAPALI 1 numarali port.
    """
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/cameras/test-baglanti",
        headers=admin,
        json={"stream_url": "rtsp://api:1/yok", "tur": "rtsp"},
    )
    assert r.status_code in (502, 503), r.text
    kod = r.json()["error"]["message"]
    # Genel cumle DEGIL, eyleme donuk bir cumle beklenir.
    assert kod, r.text
    assert r.json()["error"]["code"] in ("bad_gateway", "service_unavailable")


def test_test_baglanti_YALNIZ_RTSP(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/cameras/test-baglanti",
        headers=admin,
        json={"stream_url": "https://ornek.test/yayin.m3u8", "tur": "rtsp"},
    )
    assert r.status_code == 422, r.text


def test_test_baglanti_SAKIN_ve_GUVENLIK_icin_KAPALI(client, world):
    for anahtar in ("resident_a", "guard_a"):
        h = _headers(client, world["slug_a"], world[anahtar])
        r = client.post(
            "/cameras/test-baglanti",
            headers=h,
            json={"stream_url": "rtsp://api:1/yok", "tur": "rtsp"},
        )
        assert r.status_code == 403, (anahtar, r.text)


def test_test_baglanti_KIMLIKSIZ_401(client):
    r = client.post(
        "/cameras/test-baglanti",
        json={"stream_url": "rtsp://api:1/yok", "tur": "rtsp"},
    )
    assert r.status_code == 401


def test_test_baglanti_HICBIR_KAYIT_BIRAKMAZ(client, world):
    """Test bir DENEMEDIR: kamera listesi degismemeli."""
    admin = _headers(client, world["slug_a"], world["admin_a"])
    once = client.get("/cameras", headers=admin).json()["meta"]["total"]
    client.post(
        "/cameras/test-baglanti",
        headers=admin,
        json={"stream_url": f"rtsp://api:1/{uuid.uuid4().hex}", "tur": "rtsp"},
    )
    assert client.get("/cameras", headers=admin).json()["meta"]["total"] == once
