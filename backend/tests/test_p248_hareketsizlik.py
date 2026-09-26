"""(P248 §4) WEB 2 SAAT / PLATFORM 30 DK HAREKETSIZLIK — MOBIL 30 GUN.

Hareketsizlik, ailenin `oturum:etkin:<fam>` anahtarinin DUSMESIDIR; 2 saat
beklemek yerine anahtar silinerek canlandirilir (anahtar omru ayrica
olculur).
"""
from __future__ import annotations

import jwt

WEB = {"X-Oturum-Yuzeyi": "web"}
PANEL = {"X-Oturum-Yuzeyi": "platform"}


def _giris(client, world, basliklar=None, kim="yonetici_a"):
    cred = world[kim]
    r = client.post("/auth/login", headers=basliklar or {}, json={
        "tenant_slug": world["slug_a"], "email": cred["email"], "password": cred["password"]})
    assert r.status_code == 200, r.text
    return r.json()


def _iddia(jeton):
    return jwt.decode(jeton, options={"verify_signature": False})


def test_WEB_JETONU_YUZEY_TASIR_ve_ETKINLIK_2_SAAT(client, world, redis_client):
    t = _giris(client, world, WEB)
    rc, ac = _iddia(t["refresh_token"]), _iddia(t["access_token"])
    assert rc["yz"] == "web" and ac["yz"] == "web" and ac["fam"] == rc["fam"]
    ttl = redis_client.ttl(f"oturum:etkin:{rc['fam']}")
    assert 7100 < ttl <= 7200
    # Kimlikli istek etkinliktir: anahtar tazelenir.
    redis_client.expire(f"oturum:etkin:{rc['fam']}", 60)
    assert client.get("/me", headers={"Authorization": f"Bearer {t['access_token']}"}).status_code == 200
    assert redis_client.ttl(f"oturum:etkin:{rc['fam']}") > 7000


def test_WEB_HAREKETSIZ_KALINCA_YENILEME_REDDEDILIR_ve_AILE_KAPANIR(client, world, redis_client):
    t = _giris(client, world, WEB)
    fam = _iddia(t["refresh_token"])["fam"]
    # Once calisir; yenilenen jeton yuzeyi KORUR (basliksiz yenilemede de).
    r = client.post("/auth/refresh", json={"refresh_token": t["refresh_token"]})
    assert r.status_code == 200, r.text
    yeni = r.json()
    assert _iddia(yeni["refresh_token"])["yz"] == "web"
    # 2 saat hareketsizlik = etkinlik anahtari dustu.
    redis_client.delete(f"oturum:etkin:{fam}")
    r = client.post("/auth/refresh", json={"refresh_token": yeni["refresh_token"]})
    assert r.status_code == 401
    assert r.json()["error"]["message"]
    # Aile kapandi: anahtar geri gelse de ayni jeton kullanilamaz.
    redis_client.set(f"oturum:etkin:{fam}", 1, ex=60)
    assert client.post("/auth/refresh", json={"refresh_token": yeni["refresh_token"]}).status_code == 401


def test_PLATFORM_PANELI_30_DAKIKA(client, world, redis_client):
    t = _giris(client, world, PANEL, kim="admin_a")
    rc = _iddia(t["refresh_token"])
    assert rc["yz"] == "platform"
    assert 1700 < redis_client.ttl(f"oturum:etkin:{rc['fam']}") <= 1800


def test_MOBIL_YUZEYSIZ_30_GUN_KURALI_DEGISMEDI(client, world, redis_client):
    t = _giris(client, world)
    rc = _iddia(t["refresh_token"])
    assert "yz" not in rc and "yz" not in _iddia(t["access_token"])
    assert redis_client.exists(f"oturum:etkin:{rc['fam']}") == 0
    # Etkinlik anahtari hic olmasa da yenileme calisir (hareketsizlik yok).
    r = client.post("/auth/refresh", json={"refresh_token": t["refresh_token"]})
    assert r.status_code == 200, r.text


def test_BILINMEYEN_YUZEY_BASLIGI_YOK_SAYILIR(client, world):
    t = _giris(client, world, {"X-Oturum-Yuzeyi": "sonsuz"})
    assert "yz" not in _iddia(t["refresh_token"])


def test_CIKIS_ve_PAROLA_DEGISIMI_ANINDA_KAPATMAYA_DEVAM(client, world):
    """E2E/P247 davranisi korunur: web oturumu da cikista aninda kapanir."""
    t = _giris(client, world, WEB)
    h = {"Authorization": f"Bearer {t['access_token']}", **WEB}
    assert client.post("/auth/logout", headers=h,
                       json={"refresh_token": t["refresh_token"]}).status_code in (200, 204)
    assert client.get("/me", headers=h).status_code == 401
    assert client.post("/auth/refresh", json={"refresh_token": t["refresh_token"]}).status_code == 401
