"""Sakin ana ekran ICERIGI (WP-H) — tek yerde dogrulanan sozlesme.

Mobil ana ekranin sakin bolumleri UC listeden beslenir; hepsi resident'a
ACIK, `limit` ile kisitlanabilir, gorsel tasiyabilir ve ana ekran icin dogru
sirada doner:

  * duyurular       -> GET /announcements?limit=N   (en YENI once, foto_url)
  * site kurallari  -> GET /site-rules?limit=N      (sira ASC, foto_url)
  * yaklasan etkinlikler -> GET /events?aktif=true&limit=N
                           (en YAKIN once, foto_url)

Bu test tek tek modullerin kendi testlerini TEKRARLAMAZ; ana ekran icin
gereken BILESIK sozlesmeyi (rol + limit + siralama + gorsel) kilitler.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone


def _iso(**delta) -> str:
    return (datetime.now(timezone.utc) + timedelta(**delta)).isoformat()


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _foto_key(client, headers) -> str:
    r = client.post("/uploads/presign", headers=headers,
                    json={"content_type": "image/jpeg"})
    assert r.status_code == 200, r.text
    return r.json()["foto_key"]


def test_sakin_ana_ekran_uc_bolumu_gorselleriyle_okur(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    tag = uuid.uuid4().hex[:6]

    duyuru = client.post("/announcements", headers=yonetici, json={
        "baslik": f"Duyuru {tag}", "govde": "Gorselli duyuru govdesi.",
        "foto_key": _foto_key(client, yonetici),
    })
    assert duyuru.status_code == 201, duyuru.text

    kural = client.post("/site-rules", headers=yonetici, json={
        "baslik": f"Kural {tag}", "icerik": "Gorselli kural metni.",
        "sira": 1, "foto_key": _foto_key(client, yonetici),
    })
    assert kural.status_code == 201, kural.text

    etkinlik = client.post("/events", headers=yonetici, json={
        "baslik": f"Etkinlik {tag}", "aciklama": "Gorselli etkinlik.",
        "tarih": _iso(days=2), "bitis_zamani": _iso(days=2, hours=3),
        "konum": "Site bahçesi", "foto_key": _foto_key(client, yonetici),
    })
    assert etkinlik.status_code == 201, etkinlik.text

    # 1) Duyurular: en yeni once -> limit=1 az once yayinlanani verir.
    r = client.get("/announcements", headers=resident, params={"limit": 1})
    assert r.status_code == 200
    ilk = r.json()["items"][0]
    assert ilk["id"] == duyuru.json()["id"]
    assert "X-Amz-Signature" in ilk["foto_url"]

    # 2) Site kurallari: sira ASC + gorsel.
    r = client.get("/site-rules", headers=resident, params={"limit": 200})
    assert r.status_code == 200
    kayit = next(i for i in r.json()["items"] if i["id"] == kural.json()["id"])
    assert "X-Amz-Signature" in kayit["foto_url"]
    siralar = [i["sira"] for i in r.json()["items"]]
    assert siralar == sorted(siralar)

    # 3) Yaklasan etkinlikler: aktif=true + gorsel + en yakin once.
    r = client.get("/events", headers=resident,
                   params={"aktif": "true", "limit": 200})
    assert r.status_code == 200
    kayit = next(i for i in r.json()["items"] if i["id"] == etkinlik.json()["id"])
    assert "X-Amz-Signature" in kayit["foto_url"]
    assert kayit["konum"] == "Site bahçesi"
    bitisler = [i["bitis_zamani"] or i["tarih"] for i in r.json()["items"]]
    assert bitisler == sorted(bitisler), "aktif=true en YAKIN once siralanmali"


def test_sakin_ana_ekran_kamera_seridi_yalniz_acik_kameralar(client, world):
    """Kamera seridi de ayni ana ekranda: sakin YALNIZ yonetimin actigi
    kameralari gorur (aktif + sakin_gorebilir)."""
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    tag = uuid.uuid4().hex[:6]

    acik = client.post("/cameras", headers=yonetici, json={
        "ad": f"Sakine acik {tag}", "konum": "Ana Kapı",
        "stream_url": "https://nvr.example.com/hls/ana.m3u8",
        "tur": "hls", "sakin_gorebilir": True,
    })
    assert acik.status_code == 201, acik.text
    gizli = client.post("/cameras", headers=yonetici, json={
        "ad": f"Gizli {tag}", "stream_url": "https://nvr.example.com/hls/havuz.m3u8",
    })
    assert gizli.status_code == 201

    r = client.get("/cameras", headers=resident, params={"limit": 200})
    assert r.status_code == 200
    ids = [i["id"] for i in r.json()["items"]]
    assert acik.json()["id"] in ids
    assert gizli.json()["id"] not in ids
    # Serit oynatilabilirligi bilir (rtsp gelirse dugme pasiflenir).
    assert all("oynatilabilir" in i for i in r.json()["items"])
